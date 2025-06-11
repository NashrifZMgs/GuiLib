--[[
    Nexus-Lua: Unified GUI System v1.0
    All modules (Engine, WindowManager, Renderer, SettingsPanel, Main) are combined into this single file.
    This script implements a clipboard-based saving system for mobile executor compatibility.
]]

-- Roblox Services & Global Utilities
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")

-- Helper function to create instances, used by multiple modules
local function create(instanceType, properties)
    local inst = Instance.new(instanceType)
    for prop, value in pairs(properties or {}) do
        inst[prop] = value
    end
    return inst
end

-- Wait for the game to be ready before initializing the GUI
if not game:IsLoaded() then
    game.Loaded:Wait()
end

----------------------------------------------------------------------------------
-- MODULE DEFINITION START
-- All previously separate files are now defined as local tables here.
----------------------------------------------------------------------------------

-- ////////////////////////////////////////////////////////////////////////////////
-- // Phase 1: The Core Engine
-- // The brain of the GUI system. Manages state, API, and code execution.
-- ////////////////////////////////////////////////////////////////////////////////

local Engine = {}
do
    -- Internal Signal System
    local Signal = {}
    Signal.__index = Signal
    function Signal.new()
        return setmetatable({ _connections = {} }, Signal)
    end
    function Signal:Connect(func)
        local connection = { _func = func, _signal = self, Connected = true }
        table.insert(self._connections, connection)
        function connection:Disconnect()
            if not self.Connected then return end
            for i, conn in ipairs(self._signal._connections) do
                if conn == self then
                    table.remove(self._signal._connections, i)
                    self.Connected = false
                    break
                end
            end
        end
        return connection
    end
    function Signal:Fire(...)
        for _, connection in ipairs(self._connections) do
            if connection.Connected then
                task.spawn(connection._func, ...)
            end
        end
    end

    -- State and Registry
    Engine.Registry = { Tabs = {}, Elements = {} }
    Engine.Signals = {
        TabAdded = Signal.new(),
        TabRemoved = Signal.new(),
        ElementAdded = Signal.new(),
        ElementUpdated = Signal.new(),
        ElementRemoved = Signal.new(),
        ElementValueChanged = Signal.new(),
        NotificationRequested = Signal.new(),
        SaveToClipboard = Signal.new()
    }

    -- API for User-Written Lua
    local API = {}
    function API.GetValue(id)
        local el = Engine.Registry.Elements[id]
        return el and el.value or nil
    end
    function API.SetValue(id, val)
        local el = Engine.Registry.Elements[id]
        if not el then return end
        el.value = val
        Engine.Signals.ElementValueChanged:Fire(id, val)
        Engine.ExecuteCode(id)
    end
    function API.Trigger(id)
        if not Engine.Registry.Elements[id] then return end
        Engine.ExecuteCode(id)
    end
    function API.Notify(title, content)
        Engine.Signals.NotificationRequested:Fire(tostring(title), tostring(content))
    end
    function API.GetProperties(id)
        local el = Engine.Registry.Elements[id]
        return el and table.clone(el.properties) or nil
    end

    -- Registry Management
    function Engine.GetElement(id) return Engine.Registry.Elements[id] end
    function Engine.AddElement(data)
        if Engine.Registry.Elements[data.uniqueID] then return end
        data.value = data.properties.defaultValue
        Engine.Registry.Elements[data.uniqueID] = data
        Engine.Signals.ElementAdded:Fire(data)
    end
    function Engine.RemoveElement(id)
        if not Engine.Registry.Elements[id] then return end
        Engine.Registry.Elements[id] = nil
        Engine.Signals.ElementRemoved:Fire(id)
    end
    function Engine.UpdateElement(id, newData)
        if not Engine.Registry.Elements[id] then return end
        Engine.Registry.Elements[id] = newData
        Engine.Signals.ElementUpdated:Fire(id, newData)
    end
    function Engine.AddTab(data)
        table.insert(Engine.Registry.Tabs, data)
        Engine.Signals.TabAdded:Fire(data)
    end
    function Engine.RemoveTab(id)
        for i, tab in ipairs(Engine.Registry.Tabs) do
            if tab.uniqueID == id then
                table.remove(Engine.Registry.Tabs, i)
                Engine.Signals.TabRemoved:Fire(id)
                for elID, elData in pairs(Engine.Registry.Elements) do
                    if elData.targetTabID == id then Engine.RemoveElement(elID) end
                end
                return
            end
        end
    end

    -- Sandboxed Code Execution
    function Engine.ExecuteCode(id)
        local element = Engine.Registry.Elements[id]
        if not (element and element.luaCode and element.luaCode:match("%S")) then return end
        local env = {
            API = API,
            self = { Value = element.value, Properties = table.clone(element.properties) },
            print = print, warn = warn, task = task, game = game,
        }
        local func, err = loadstring(element.luaCode)
        if not func then
            API.Notify("Lua Error: "..element.label, "Syntax: " .. tostring(err))
            return
        end
        setfenv(func, env)
        local success, execErr = pcall(func)
        if not success then
            API.Notify("Lua Error: "..element.label, "Runtime: " .. tostring(execErr))
        end
    end

    -- Load from string (for clipboard)
    function Engine.LoadConfigurationFromString(jsonString)
        local success, decodedData = pcall(function() return HttpService:JSONDecode(jsonString) end)
        if success and decodedData and decodedData.Registry then
            local tabsCopy = table.clone(Engine.Registry.Tabs)
            for _, tab in ipairs(tabsCopy) do
                Engine.RemoveTab(tab.uniqueID)
            end

            for _, tabData in ipairs(decodedData.Registry.Tabs) do Engine.AddTab(tabData) end
            for _, elementData in pairs(decodedData.Registry.Elements) do Engine.AddElement(elementData) end
            API.Notify("System", "Configuration Imported!")
        else
            API.Notify("Error", "Failed to import. Invalid format.")
        end
    end
end

-- ////////////////////////////////////////////////////////////////////////////////
-- // Phase 2: The Window & Layout Manager
-- // Creates all primary visual containers and handles window behavior.
-- ////////////////////////////////////////////////////////////////////////////////
local WindowManager = {}
do
    local ZINDEX_BASE, WINDOW_MIN_SIZE = 500, Vector2.new(520, 350)
    local SIDEBAR_WIDTH, HEADER_HEIGHT = 150, 40

    local gui, window, header, sidebar, contentArea, resizeHandle
    local isSidebarVisible = true
    local isDragging, isResizing = false, false
    local dragStart, originalPosition, resizeStart, originalSize

    local function tween(instance, goal, duration)
        local t = TweenService:Create(instance, TweenInfo.new(duration or 0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), goal)
        t:Play()
        return t
    end

    local function onInputBegan(obj, input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
        if obj == header then
            isDragging, dragStart, originalPosition = true, input.Position, window.Position
        elseif obj == resizeHandle then
            isResizing, resizeStart, originalSize = true, input.Position, window.AbsoluteSize
        end
        window.ZIndex = ZINDEX_BASE + 10
    end
    
    local function onInputChanged(input)
        if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
        if isDragging then
            local delta = input.Position - dragStart
            window.Position = UDim2.fromOffset(originalPosition.X.Offset + delta.X, originalPosition.Y.Offset + delta.Y)
        elseif isResizing then
            local delta = input.Position - resizeStart
            local newSize = originalSize + delta
            window.Size = UDim2.fromOffset(math.max(WINDOW_MIN_SIZE.X, newSize.X), math.max(WINDOW_MIN_SIZE.Y, newSize.Y))
        end
    end

    local function onInputEnded(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
        isDragging, isResizing, window.ZIndex = false, false, ZINDEX_BASE
    end

    function WindowManager.ToggleSidebar()
        isSidebarVisible = not isSidebarVisible
        local sidebarPos = isSidebarVisible and UDim2.new(0, 0, 0, HEADER_HEIGHT) or UDim2.new(0, -SIDEBAR_WIDTH, 0, HEADER_HEIGHT)
        local contentPos = isSidebarVisible and UDim2.new(0, SIDEBAR_WIDTH, 0, HEADER_HEIGHT) or UDim2.new(0, 0, 0, HEADER_HEIGHT)
        local contentSize = isSidebarVisible and UDim2.new(1, -SIDEBAR_WIDTH, 1, -HEADER_HEIGHT) or UDim2.new(1, 0, 1, -HEADER_HEIGHT)
        tween(sidebar, { Position = sidebarPos })
        tween(contentArea, { Position = contentPos, Size = contentSize })
    end

    function WindowManager.Destroy()
        if gui then gui:Destroy() gui = nil end
    end
    
    function WindowManager.ShowNotification(title, content)
        local notifFrame = create("Frame", {
            Name = "Notification",
            Parent = gui,
            Size = UDim2.new(0, 250, 0, 60),
            Position = UDim2.new(1, -270, 1, 0),
            BackgroundColor3 = Color3.fromRGB(30,30,30),
            BackgroundTransparency = 0.2,
            BorderSizePixel = 0,
            ZIndex = ZINDEX_BASE + 100,
        })
        create("UICorner", {Parent = notifFrame, CornerRadius = UDim.new(0, 5)})
        create("UIPadding", {Parent = notifFrame, PaddingLeft = UDim.new(0,10), PaddingRight = UDim.new(0,10), PaddingTop = UDim.new(0,5), PaddingBottom = UDim.new(0,5)})
        create("TextLabel", {Name = "Title", Parent = notifFrame, Size = UDim2.new(1,0,0,20), Text = title, Font = Enum.Font.SourceSansBold, TextColor3 = Color3.fromRGB(255,255,255), TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1})
        create("TextLabel", {Name = "Content", Parent = notifFrame, Size = UDim2.new(1,0,1,-25), Position = UDim2.new(0,0,0,25), Text = content, Font = Enum.Font.SourceSans, TextColor3 = Color3.fromRGB(220,220,220), TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, BackgroundTransparency = 1})

        tween(notifFrame, {Position = UDim2.new(1, -270, 1, -80)}, 0.3)
        task.delay(4, function()
            if notifFrame and notifFrame.Parent then
                tween(notifFrame, {Position = UDim2.new(1, -270, 1, 0)}, 0.3)
                task.wait(0.3)
                notifFrame:Destroy()
            end
        end)
    end

    function WindowManager.Init(engineRef)
        Engine.Signals.NotificationRequested:Connect(WindowManager.ShowNotification)

        gui = create("ScreenGui", { Name = "NexusGUISystem", Parent = CoreGui, ZIndexBehavior = Enum.ZIndexBehavior.Global, ResetOnSpawn = false })
        window = create("Frame", { Name = "Window", Parent = gui, BackgroundColor3 = Color3.fromRGB(45, 45, 45), BorderSizePixel = 0, Active = true, Size = UDim2.fromOffset(600, 400), Position = UDim2.new(0.5, -300, 0.5, -200), ClipsDescendants = true, ZIndex = ZINDEX_BASE })
        create("UICorner", { Parent = window, CornerRadius = UDim.new(0, 6) })

        header = create("Frame", { Name = "Header", Parent = window, BackgroundColor3 = Color3.fromRGB(35, 35, 35), BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, HEADER_HEIGHT), ZIndex = ZINDEX_BASE + 2 })
        header.InputBegan:Connect(function(i) onInputBegan(header, i) end)
        create("TextButton", { Name = "SidebarToggle", Parent = header, Size = UDim2.fromOffset(40, 40), Text = "≡", TextColor3 = Color3.fromRGB(220, 220, 220), TextSize = 30, BackgroundTransparency = 1, ZIndex = ZINDEX_BASE + 3 }).MouseButton1Click:Connect(WindowManager.ToggleSidebar)
        create("TextLabel", { Name = "Title", Parent = header, Size = UDim2.new(1, -120, 1, 0), Position = UDim2.new(0, 40, 0, 0), Text = "Nexus-Lua GUI", TextColor3 = Color3.fromRGB(255, 255, 255), Font = Enum.Font.SourceSansSemibold, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1, ZIndex = ZINDEX_BASE + 3 })
        local exitBtn = create("TextButton", { Name = "Exit", Parent = header, Size = UDim2.fromOffset(40, 40), Position = UDim2.new(1, -40, 0, 0), Text = "X", TextColor3 = Color3.fromRGB(220, 220, 220), TextSize = 20, BackgroundTransparency = 1, ZIndex = ZINDEX_BASE + 3 })
        local settingsBtn = create("TextButton", { Name = "Settings", Parent = header, Size = UDim2.fromOffset(40, 40), Position = UDim2.new(1, -80, 0, 0), Text = "⚙", TextColor3 = Color3.fromRGB(220, 220, 220), TextSize = 24, BackgroundTransparency = 1, ZIndex = ZINDEX_BASE + 3 })
        exitBtn.MouseButton1Click:Connect(WindowManager.Destroy)

        sidebar = create("ScrollingFrame", { Name = "Sidebar", Parent = window, BackgroundColor3 = Color3.fromRGB(55, 55, 55), BorderSizePixel = 0, Size = UDim2.new(0, SIDEBAR_WIDTH, 1, -HEADER_HEIGHT), Position = UDim2.new(0, 0, 0, HEADER_HEIGHT), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = ZINDEX_BASE + 1, ScrollBarImageColor3 = Color3.fromRGB(120,120,120), ScrollBarThickness=4 })
        create("UIListLayout", { Name = "TabListLayout", Parent = sidebar, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 5), HorizontalAlignment = Enum.HorizontalAlignment.Center })
        create("UIPadding", {Parent = sidebar, PaddingTop = UDim.new(0,5)})

        contentArea = create("Frame", { Name = "ContentArea", Parent = window, BackgroundColor3 = Color3.fromRGB(40,40,40), BorderSizePixel=0, Size = UDim2.new(1, -SIDEBAR_WIDTH, 1, -HEADER_HEIGHT), Position = UDim2.new(0, SIDEBAR_WIDTH, 0, HEADER_HEIGHT), ClipsDescendants = true, ZIndex = ZINDEX_BASE + 1 })
        local contentFrame = create("Frame", { Name = "ContentFrame", Parent = contentArea, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0) })
        local settingsFrame = create("Frame", { Name = "SettingsFrame", Parent = contentArea, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Visible = false })
        
        resizeHandle = create("Frame", { Name = "ResizeHandle", Parent = window, BackgroundTransparency = 1, Size = UDim2.fromOffset(20, 20), Position = UDim2.new(1, -20, 1, -20), ZIndex = ZINDEX_BASE + 3 })
        resizeHandle.InputBegan:Connect(function(i) onInputBegan(resizeHandle, i) end)

        UserInputService.InputChanged:Connect(onInputChanged)
        UserInputService.InputEnded:Connect(onInputEnded)
        
        return { tabContainer = sidebar, contentContainer = contentFrame, settingsContainer = settingsFrame, settingsButton = settingsBtn }
    end
end

-- ////////////////////////////////////////////////////////////////////////////////
-- // Phase 3: The Element Renderer
-- // Creates the visual representation of elements.
-- ////////////////////////////////////////////////////////////////////////////////
local ElementRenderer = {}
do
    local ELEMENT_HEIGHT, ELEMENT_PADDING = 40, 10
    local contentContainer, renderedElements = nil, {}

    local function createBaseElementFrame(data)
        local frame = create("Frame", { Name = data.uniqueID, BackgroundColor3 = Color3.fromRGB(60, 60, 60), BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, ELEMENT_HEIGHT) })
        create("UICorner", { Parent = frame, CornerRadius = UDim.new(0, 4) })
        create("TextLabel", { Name = "Label", Parent = frame, Size = UDim2.new(0.4, 0, 1, 0), Position = UDim2.new(0, ELEMENT_PADDING, 0, 0), Text = data.label, TextColor3 = Color3.fromRGB(240, 240, 240), Font = Enum.Font.SourceSans, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency=1 })
        return frame
    end

    local function renderButton(data)
        local frame = createBaseElementFrame(data)
        local button = create("TextButton", { Name = "ButtonControl", Parent = frame, Size = UDim2.new(0.5, -ELEMENT_PADDING, 1, -10), Position = UDim2.new(0.5, 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = Color3.fromRGB(80, 80, 80), Text = data.label, TextColor3 = Color3.fromRGB(255, 255, 255), Font = Enum.Font.SourceSansSemibold, TextSize = 16 })
        create("UICorner", { Parent = button, CornerRadius = UDim.new(0, 4) })
        frame.Label.Visible = false
        button.MouseButton1Click:Connect(function() Engine.ExecuteCode(data.uniqueID) end)
        return frame
    end
    
    local function renderToggle(data)
        local frame = createBaseElementFrame(data)
        local switch = create("TextButton", { Name = "ToggleControl", Parent = frame, Size = UDim2.new(0, 60, 0, ELEMENT_HEIGHT - 16), Position = UDim2.new(1, -ELEMENT_PADDING - 60, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), BackgroundColor3 = Color3.fromRGB(40, 40, 40), Text = "" })
        create("UICorner", { Parent = switch, CornerRadius = UDim.new(1, 0) })
        local knob = create("Frame", { Name = "Knob", Parent = switch, Size = UDim2.new(0, 24, 0, 24), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.fromRGB(200, 200, 200), BorderSizePixel = 0 })
        create("UICorner", { Parent = knob, CornerRadius = UDim.new(1, 0) })
        local function updateVisuals(value, animate)
            local pos = value and UDim2.new(1, -15, 0.5, 0) or UDim2.new(0, 15, 0.5, 0)
            local color = value and Color3.fromRGB(70, 180, 90) or Color3.fromRGB(150, 150, 150)
            if animate then
                local t = TweenService:Create(knob, TweenInfo.new(0.2), {Position = pos, BackgroundColor3 = color})
                t:Play()
            else
                knob.Position, knob.BackgroundColor3 = pos, color
            end
        end
        switch.MouseButton1Click:Connect(function()
            local el = Engine.GetElement(data.uniqueID)
            el.value = not el.value
            updateVisuals(el.value, true)
            Engine.ExecuteCode(data.uniqueID)
        end)
        updateVisuals(data.value, false)
        renderedElements[data.uniqueID] = { instance = frame, updateFunc = updateVisuals }
        return frame
    end

    local function renderSlider(data)
        local frame = createBaseElementFrame(data)
        local props = data.properties
        local valueLabel = create("TextLabel", { Name = "ValueLabel", Parent = frame, Size = UDim2.new(0, 60, 1, 0), Position = UDim2.new(1, -ELEMENT_PADDING - 60, 0, 0), BackgroundTransparency = 1, Font = Enum.Font.SourceSans, TextSize = 15, TextColor3 = Color3.fromRGB(200, 200, 200) })
        local track = create("Frame", { Name = "Track", Parent = frame, Size = UDim2.new(0.6, -ELEMENT_PADDING - 60, 0, 8), Position = UDim2.new(0.4, 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = Color3.fromRGB(40, 40, 40) })
        create("UICorner", { Parent = track, CornerRadius = UDim.new(1, 0) })
        local progress = create("Frame", { Name = "Progress", Parent = track, BackgroundColor3 = Color3.fromRGB(85, 125, 255) })
        create("UICorner", { Parent = progress, CornerRadius = UDim.new(1, 0) })
        local isDragging = false
        local function updateVisuals(value)
            local percentage = (value - props.minValue) / (props.maxValue - props.minValue)
            progress.Size = UDim2.new(percentage, 0, 1, 0)
            local roundedValue = math.floor((value / props.increment) + 0.5) * props.increment
            valueLabel.Text = tostring(roundedValue) .. (props.suffix or "")
        end
        local function onInput(input)
            local percentage = math.clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
            local rawValue = props.minValue + (props.maxValue - props.minValue) * percentage
            local steppedValue = math.clamp(math.floor(rawValue / props.increment + 0.5) * props.increment, props.minValue, props.maxValue)
            if Engine.GetElement(data.uniqueID).value ~= steppedValue then
                Engine.GetElement(data.uniqueID).value = steppedValue
                updateVisuals(steppedValue)
                Engine.ExecuteCode(data.uniqueID)
            end
        end
        track.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then isDragging = true onInput(i) end end)
        UserInputService.InputChanged:Connect(function(i) if isDragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then onInput(i) end end)
        UserInputService.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then isDragging = false end end)
        updateVisuals(data.value)
        renderedElements[data.uniqueID] = { instance = frame, updateFunc = updateVisuals }
        return frame
    end
    
    local renderDispatch = { Button = renderButton, Toggle = renderToggle, Slider = renderSlider }
    
    function ElementRenderer.CreateContentPage(tabData)
        if contentContainer:FindFirstChild(tabData.uniqueID) then return end
        local page = create("Frame", { Name = tabData.uniqueID, Parent = contentContainer, Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Visible = false })
        local scrollingFrame = create("ScrollingFrame", { Name = "LayoutFrame", Parent = page, Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, CanvasSize = UDim2.new(), AutomaticCanvasSize=Enum.AutomaticSize.Y, BorderSizePixel = 0, ScrollBarImageColor3=Color3.fromRGB(150,150,150), ScrollBarThickness=6 })
        create("UIListLayout", { Parent = scrollingFrame, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, ELEMENT_PADDING), HorizontalAlignment = Enum.HorizontalAlignment.Center })
        create("UIPadding", {Parent=scrollingFrame, PaddingLeft=UDim.new(0,10), PaddingRight=UDim.new(0,10), PaddingTop=UDim.new(0,10)})
        return page
    end
    function ElementRenderer.DestroyContentPage(tabID)
        local page = contentContainer and contentContainer:FindFirstChild(tabID)
        if page then page:Destroy() end
    end
    
    local function onElementAdded(data)
        local page = contentContainer:FindFirstChild(data.targetTabID)
        if not page then return end
        local renderFunc = renderDispatch[data.type]
        if renderFunc then
            local instance = renderFunc(data)
            instance.Parent = page.LayoutFrame
            if not renderedElements[data.uniqueID] then renderedElements[data.uniqueID] = { instance = instance } end
        end
    end
    local function onElementRemoved(id)
        if renderedElements[id] then renderedElements[id].instance:Destroy() renderedElements[id] = nil end
    end
    local function onElementValueChanged(id, val)
        local rendered = renderedElements[id]
        if rendered and rendered.updateFunc then rendered.updateFunc(val, true) end
    end

    function ElementRenderer.Init(engineRef, containers)
        Engine, contentContainer = engineRef, containers.contentContainer
        for _, tabData in ipairs(Engine.Registry.Tabs) do ElementRenderer.CreateContentPage(tabData) end
        Engine.Signals.ElementAdded:Connect(onElementAdded)
        Engine.Signals.ElementRemoved:Connect(onElementRemoved)
        Engine.Signals.ElementValueChanged:Connect(onElementValueChanged)
    end
end

-- ////////////////////////////////////////////////////////////////////////////////
-- // Phase 4: The Settings Panel
-- // Builds the UI for creating/managing tabs and elements.
-- ////////////////////////////////////////////////////////////////////////////////
local SettingsPanel = {}
do
    local settingsContainer, activeEditElementID, editPanel
    
    local function createSection(name, order, parent)
        local frame = create("Frame", { Name = name.."Section", Parent = parent, BackgroundTransparency = 1, Size = UDim2.new(1, -20, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order })
        local layout = create("UIListLayout", { Parent = frame, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 5) })
        create("TextLabel", { Name = "Header", Parent = frame, LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 25), Text = name, Font = Enum.Font.SourceSansBold, TextSize = 20, TextColor3 = Color3.fromRGB(255, 255, 255), TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency=1 })
        return frame, layout
    end

    local function createTextButton(text, parent, order)
        local btn = create("TextButton", { Name = text, Parent = parent, LayoutOrder = order, Size = UDim2.new(1, 0, 0, 35), BackgroundColor3 = Color3.fromRGB(80, 80, 80), Text = text, TextColor3 = Color3.fromRGB(255, 255, 255), Font = Enum.Font.SourceSansSemibold, TextSize = 16 })
        create("UICorner", { Parent = btn, CornerRadius = UDim.new(0, 4) })
        return btn
    end

    local function createTextInput(placeholder, parent, order, height)
        local frame = create("Frame", { Name = placeholder .. "InputFrame", Parent = parent, LayoutOrder = order, Size = UDim2.new(1, 0, 0, height or 30), BackgroundColor3 = Color3.fromRGB(30, 30, 30) })
        create("UICorner", { Parent = frame, CornerRadius = UDim.new(0, 4) })
        local textBox = create("TextBox", { Name = "Input", Parent = frame, Size = UDim2.new(1, -10, 1, -10), Position = UDim2.new(0.5, 0, 0.5, 0), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, PlaceholderText = placeholder, PlaceholderColor3 = Color3.fromRGB(150, 150, 150), Text = "", TextColor3 = Color3.fromRGB(220, 220, 220), Font = Enum.Font.SourceSans, TextSize = 14, ClearTextOnFocus = false })
        return frame, textBox
    end

    local function clearEditPanel()
        for i, child in ipairs(editPanel:GetChildren()) do if i > 1 then child:Destroy() end end
        editPanel.Visible = false
        activeEditElementID = nil
    end

    local function populateEditPanel(data)
        clearEditPanel()
        data = data or {}
        local _, nameInput = createTextInput("Display Name", editPanel, 2)
        local _, idInput = createTextInput("Unique ID (no spaces)", editPanel, 3)
        local _, tabInput = createTextInput("Target Tab ID", editPanel, 4)
        local _, typeInput = createTextInput("Type (Button, Toggle, Slider)", editPanel, 5)
        local luaFrame, luaInput = createTextInput("Lua Code...", editPanel, 6, 120)
        luaInput.MultiLine, luaInput.TextXAlignment, luaInput.TextYAlignment = true, Enum.TextXAlignment.Left, Enum.TextYAlignment.Top
        nameInput.Text, idInput.Text, tabInput.Text, typeInput.Text, luaInput.Text = data.label or "", data.uniqueID or "", data.targetTabID or "", data.type or "", data.luaCode or ""
        
        local saveBtn = createTextButton("Save Element", editPanel, 7)
        local cancelBtn = createTextButton("Cancel", editPanel, 8)
        cancelBtn.BackgroundColor3 = Color3.fromRGB(120, 60, 60)
        cancelBtn.MouseButton1Click:Connect(clearEditPanel)
        saveBtn.MouseButton1Click:Connect(function()
            local newData = {
                label=nameInput.Text, uniqueID=idInput.Text, targetTabID=tabInput.Text, type=typeInput.Text, luaCode=luaInput.Text,
                properties = {
                    defaultValue = (typeInput.Text == "Toggle" and false) or (typeInput.Text == "Slider" and 50) or nil,
                    minValue = 0, maxValue = 100, increment = 1, suffix = "",
                }
            }
            if activeEditElementID then Engine.UpdateElement(activeEditElementID, newData) else Engine.AddElement(newData) end
            clearEditPanel()
        end)
        editPanel.Visible = true
    end

    function SettingsPanel.Init(engineRef, containers)
        Engine, settingsContainer = engineRef, containers.settingsContainer
        local mainLayout = create("UIListLayout", { Parent = settingsContainer, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 15), HorizontalAlignment = Enum.HorizontalAlignment.Center })
        create("UIPadding", {Parent=settingsContainer, PaddingLeft=UDim.new(0,10), PaddingRight=UDim.new(0,10), PaddingTop=UDim.new(0,10)})

        -- Configuration Manager
        local configSection, _ = createSection("Configuration", 1, settingsContainer)
        local _, importBox = createTextInput("Paste config here...", configSection, 2, 80)
        importBox.MultiLine, importBox.TextXAlignment, importBox.TextYAlignment = true, Enum.TextXAlignment.Left, Enum.TextYAlignment.Top
        local importBtn = createTextButton("Import from Clipboard", configSection, 3)
        local exportBtn = createTextButton("Export to Clipboard", configSection, 4)
        importBtn.MouseButton1Click:Connect(function()
            if getclipboard then importBox.Text = getclipboard() end
            if importBox.Text and #importBox.Text > 0 then Engine.LoadConfigurationFromString(importBox.Text) end
        end)
        exportBtn.MouseButton1Click:Connect(function() Engine.Signals.SaveToClipboard:Fire() end)

        -- Tab Manager
        local tabSection, _ = createSection("Tabs", 2, settingsContainer)
        local _, tabNameInput = createTextInput("New Tab Name", tabSection, 2)
        local addTabBtn = createTextButton("Add New Tab", tabSection, 3)
        addTabBtn.MouseButton1Click:Connect(function()
            if tabNameInput.Text:match("%S") then Engine.AddTab({ uniqueID = tabNameInput.Text:lower():gsub("%s+", "_"), label = tabNameInput.Text }) tabNameInput.Text = "" end
        end)

        -- Element Manager
        local elementSection, _ = createSection("Elements", 3, settingsContainer)
        editPanel, _ = createSection("Create/Edit Element", 4, settingsContainer)
        editPanel.Visible = false
        local createBtn = createTextButton("Create New Element", elementSection, 3)
        createBtn.MouseButton1Click:Connect(function() activeEditElementID = nil; populateEditPanel() end)
    end
end

----------------------------------------------------------------------------------
-- MODULE DEFINITION END
-- MAIN SCRIPT LOGIC (INITIALIZATION AND WIRING)
----------------------------------------------------------------------------------
do
    print("Nexus-Lua: Initializing Unified GUI System...")

    -- 1. Initialize Modules in Order
    local containers = WindowManager.Init(Engine)
    ElementRenderer.Init(Engine, containers)
    SettingsPanel.Init(Engine, containers)

    -- 2. Connect System Together
    local isSettingsVisible = false
    local function toggleSettingsView()
        isSettingsVisible = not isSettingsVisible
        containers.settingsContainer.Visible = isSettingsVisible
        containers.contentContainer.Visible = not isSettingsVisible
    end
    containers.settingsButton.MouseButton1Click:Connect(toggleSettingsView)

    local activeTabButton = nil
    Engine.Signals.TabAdded:Connect(function(tabData)
        local page = ElementRenderer.CreateContentPage(tabData)
        local sidebar = containers.tabContainer
        local tabButton = create("TextButton", { Name = tabData.uniqueID, Parent = sidebar, Size = UDim2.new(1, -10, 0, 35), BackgroundColor3 = Color3.fromRGB(65, 65, 65), Text = tabData.label, TextColor3 = Color3.fromRGB(230, 230, 230), Font = Enum.Font.SourceSansSemibold, TextSize = 16 })
        create("UICorner", { Parent = tabButton, CornerRadius = UDim.new(0, 4) })
        tabButton.MouseButton1Click:Connect(function()
            for _, child in ipairs(containers.contentContainer:GetChildren()) do child.Visible = false end
            page.Visible = true
            if isSettingsVisible then toggleSettingsView() end
            if activeTabButton then activeTabButton.BackgroundColor3 = Color3.fromRGB(65, 65, 65) end
            tabButton.BackgroundColor3 = Color3.fromRGB(85, 125, 255)
            activeTabButton = tabButton
        end)
        -- Auto-select the first tab created
        if not activeTabButton then tabButton:Invoke("MouseButton1Click") end
    end)
    Engine.Signals.TabRemoved:Connect(function(tabID)
        ElementRenderer.DestroyContentPage(tabID)
        local button = containers.tabContainer:FindFirstChild(tabID)
        if button then
            if activeTabButton == button then activeTabButton = nil end
            button:Destroy()
        end
    end)

    -- 3. Implement Save to Clipboard Functionality
    Engine.Signals.SaveToClipboard:Connect(function()
        local dataToSave = { Registry = Engine.Registry }
        local success, encodedData = pcall(function() return HttpService:JSONEncode(dataToSave) end)
        if success and setclipboard then
            setclipboard(encodedData)
            Engine.API.Notify("System", "Configuration copied to clipboard!")
        else
            Engine.API.Notify("Error", "Failed to export configuration.")
        end
    end)
    
    print("GUI System: Inter-module connections established.")

    -- 4. Create Default Setup if no config is loaded/exists
    if #Engine.Registry.Tabs == 0 then
        print("GUI System: No config loaded. Creating a default setup.")
        Engine.AddTab({ uniqueID = "main", label = "Main" })
        Engine.AddElement({
            uniqueID = "welcome_button", label = "Welcome!", type = "Button", targetTabID = "main", properties = {},
            luaCode = [[ API.Notify("Welcome", "This is a button created in the default setup.") ]]
        })
    end
    
    print("Nexus-Lua: GUI System launch complete.")
end
