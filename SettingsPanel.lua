--[[
    Nexus-Lua GUI System | Phase 3: The Element Renderer
    Purpose: Creates the visual representation of elements (Buttons, Toggles, etc.).
    Connects UI events to the Engine and updates visuals based on state changes.
]]

local ElementRenderer = {}

-- Roblox Services
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

-- Module State
local Engine
local contentPagesContainer -- The parent frame for all content pages, from WindowManager
local renderedElements = {} -- Stores GUI objects and update functions, indexed by elementID

-- Configuration
local ELEMENT_HEIGHT = 40
local ELEMENT_PADDING = 10
local THEME_DEFAULTS = {
    Element = Color3.fromRGB(60, 60, 60),
    Text = Color3.fromRGB(240, 240, 240),
    Accent = Color3.fromRGB(85, 125, 255),
    Inactive = Color3.fromRGB(90, 90, 90),
    Subtle = Color3.fromRGB(40, 40, 40)
}

-- //////////////////////////////////////////////////////////////////////////////////
-- // 1. UTILITIES
-- //////////////////////////////////////////////////////////////////////////////////

local function create(instanceType, properties)
    local inst = Instance.new(instanceType)
    for prop, value in pairs(properties or {}) do
        inst[prop] = value
    end
    return inst
end

local function tween(instance, goal, duration)
    duration = duration or 0.2
    local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
    local t = TweenService:Create(instance, tweenInfo, goal)
    t:Play()
    return t
end

-- //////////////////////////////////////////////////////////////////////////////////
-- // 2. BASE ELEMENT FRAME & RENDERER FUNCTIONS
-- //////////////////////////////////////////////////////////////////////////////////

local function createBaseElementFrame(elementData)
    local frame = create("Frame", {
        Name = elementData.uniqueID,
        BackgroundColor3 = THEME_DEFAULTS.Element,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, ELEMENT_HEIGHT),
        LayoutOrder = os.time(),
    })
    create("UICorner", { CornerRadius = UDim.new(0, 4), Parent = frame })
    
    create("UIPadding", {
        Parent = frame,
        PaddingLeft = UDim.new(0, ELEMENT_PADDING),
        PaddingRight = UDim.new(0, ELEMENT_PADDING)
    })

    create("TextLabel", {
        Name = "Label",
        Parent = frame,
        Size = UDim2.new(0.5, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = elementData.label,
        TextColor3 = THEME_DEFAULTS.Text,
        Font = Enum.Font.SourceSans,
        TextSize = 16,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    
    return frame
end

local function renderButton(elementData)
    local frame = createBaseElementFrame(elementData)
    
    local button = create("TextButton", {
        Name = "ButtonControl",
        Parent = frame,
        Size = UDim2.new(0.4, 0, 1, -10),
        Position = UDim2.new(1, 0, 0.5, 0),
        AnchorPoint = Vector2.new(1, 0.5),
        BackgroundColor3 = THEME_DEFAULTS.Accent,
        Text = "Execute",
        TextColor3 = Color3.fromRGB(255, 255, 255),
        Font = Enum.Font.SourceSansSemibold,
        TextSize = 16,
    })
    create("UICorner", { CornerRadius = UDim.new(0, 4), Parent = button })
    
    button.MouseButton1Click:Connect(function()
        tween(button, {Size = UDim2.new(0.38, 0, 1, -12)}, 0.1):Completed:Wait()
        tween(button, {Size = UDim2.new(0.4, 0, 1, -10)}, 0.1)
        Engine.ExecuteCode(elementData.uniqueID)
    end)
    
    return frame
end

local function renderToggle(elementData)
    local frame = createBaseElementFrame(elementData)
    
    local switch = create("TextButton", {
        Name = "ToggleControl",
        Parent = frame,
        Size = UDim2.new(0, 50, 0, ELEMENT_HEIGHT - 16),
        Position = UDim2.new(1, 0, 0.5, 0),
        AnchorPoint = Vector2.new(1, 0.5),
        BackgroundColor3 = THEME_DEFAULTS.Subtle,
        Text = "",
    })
    create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = switch })
    
    local knob = create("Frame", {
        Name = "Knob",
        Parent = switch,
        Size = UDim2.new(0, 20, 0, 20),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Color3.fromRGB(200, 200, 200),
        BorderSizePixel = 0,
    })
    create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = knob })

    local function updateVisuals(value, withAnimation)
        local goalPos = value and UDim2.new(1, -12, 0.5, 0) or UDim2.new(0, 12, 0.5, 0)
        local switchColor = value and THEME_DEFAULTS.Accent or THEME_DEFAULTS.Subtle
        
        if withAnimation then
            tween(knob, { Position = goalPos })
            tween(switch, { BackgroundColor3 = switchColor })
        else
            knob.Position = goalPos
            switch.BackgroundColor3 = switchColor
        end
    end
    
    switch.MouseButton1Click:Connect(function()
        local element = Engine.GetElement(elementData.uniqueID)
        element.value = not element.value
        updateVisuals(element.value, true)
        Engine.ExecuteCode(elementData.uniqueID)
    end)
    
    updateVisuals(elementData.value, false)
    
    renderedElements[elementData.uniqueID] = { instance = frame, updateFunc = updateVisuals }
    return frame
end

local function renderSlider(elementData)
    local frame = createBaseElementFrame(elementData)
    local props = elementData.properties
    
    local valueLabel = create("TextLabel", {
        Name = "ValueLabel",
        Parent = frame,
        Size = UDim2.new(0, 60, 1, 0),
        Position = UDim2.new(1, 0, 0, 0),
        AnchorPoint = Vector2.new(1, 0),
        BackgroundTransparency = 1,
        Font = Enum.Font.SourceSans,
        TextSize = 15,
        TextColor3 = THEME_DEFAULTS.Text,
    })
    
    local track = create("Frame", {
        Name = "Track",
        Parent = frame,
        Size = UDim2.new(1, -80, 0, 6),
        Position = UDim2.new(0, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = THEME_DEFAULTS.Subtle,
        BorderSizePixel = 0,
    })
    create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = track })
    
    local progress = create("Frame", { Name = "Progress", Parent = track, BackgroundColor3 = THEME_DEFAULTS.Accent })
    create("UICorner", { Parent = progress })
    
    local knob = create("Frame", { Name = "Knob", Parent = track, Size = UDim2.fromOffset(16,16), AnchorPoint = Vector2.new(0.5,0.5), BackgroundColor3 = Color3.fromRGB(255,255,255) })
    create("UICorner", {CornerRadius = UDim.new(1,0), Parent = knob})

    local isDragging = false
    
    local function updateVisuals(value, withAnimation)
        local percentage = (value - props.minValue) / (props.maxValue - props.minValue)
        local goal = {
            Size = UDim2.new(percentage, 0, 1, 0),
            Position = UDim2.new(percentage, 0, 0.5, 0) -- For the knob
        }
        
        if withAnimation then
            tween(progress, {Size = goal.Size})
            tween(knob, {Position = goal.Position})
        else
            progress.Size = goal.Size
            knob.Position = goal.Position
        end
        
        local roundedValue = math.floor(value / props.increment + 0.5) * props.increment
        valueLabel.Text = tostring(roundedValue) .. (props.suffix or "")
    end
    
    local function onInput(input)
        local percentage = (input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X
        percentage = math.clamp(percentage, 0, 1)
        
        local rawValue = props.minValue + (props.maxValue - props.minValue) * percentage
        local steppedValue = math.clamp(math.floor(rawValue / props.increment + 0.5) * props.increment, props.minValue, props.maxValue)

        local element = Engine.GetElement(elementData.uniqueID)
        if element.value ~= steppedValue then
            element.value = steppedValue
            updateVisuals(steppedValue, false) -- No animation while dragging
            Engine.ExecuteCode(elementData.uniqueID)
        end
    end
    
    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isDragging = true
            onInput(input)
        end
    end)
    
    local inputChangedConn, inputEndedConn
    inputChangedConn = UserInputService.InputChanged:Connect(function(input)
        if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            onInput(input)
        end
    end)
    inputEndedConn = UserInputService.InputEnded:Connect(function(input)
        if isDragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
            isDragging = false
        end
    end)
    
    frame.Destroying:Connect(function()
        if inputChangedConn then inputChangedConn:Disconnect() end
        if inputEndedConn then inputEndedConn:Disconnect() end
    end)

    updateVisuals(elementData.value, false)

    frame.Label.Size = UDim2.new(0.5, -70, 1, 0)
    track.Size = UDim2.new(0.5, -10, 0, 6)
    track.Position = UDim2.new(0.5, -60, 0.5, 0)

    renderedElements[elementData.uniqueID] = { instance = frame, updateFunc = updateVisuals }
    return frame
end


local function renderDropdown(elementData)
    local frame = createBaseElementFrame(elementData)
    local props = elementData.properties
    local isOpen = false

    local dropdownButton = create("TextButton", {
        Name = "DropdownButton",
        Parent = frame,
        Size = UDim2.new(0.5, 0, 1, -10),
        Position = UDim2.new(1, 0, 0.5, 0),
        AnchorPoint = Vector2.new(1, 0.5),
        BackgroundColor3 = THEME_DEFAULTS.Subtle,
        Text = tostring(elementData.value),
        TextColor3 = THEME_DEFAULTS.Text,
        Font = Enum.Font.SourceSans,
        TextSize = 14,
    })
    create("UICorner", { Parent = dropdownButton })

    local optionsList = create("ScrollingFrame", {
        Name = "OptionsList",
        Parent = frame,
        Visible = false,
        Size = UDim2.new(0.5, 0, 0, 120),
        Position = UDim2.new(1, 0, 1, 5),
        AnchorPoint = Vector2.new(1, 0),
        BackgroundColor3 = THEME_DEFAULTS.Subtle,
        BorderSizePixel = 0,
        ZIndex = frame.ZIndex + 1,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 4,
    })
    create("UICorner", { Parent = optionsList })
    create("UIListLayout", { Parent = optionsList, Padding = UDim.new(0,2) })

    local function updateOptions()
        optionsList:ClearAllChildren()
        create("UIListLayout", { Parent = optionsList, Padding = UDim.new(0,2) }) -- Re-add layout
        for _, optionText in ipairs(props.options or {}) do
            local optionButton = create("TextButton", {
                Name = optionText,
                Parent = optionsList,
                Size = UDim2.new(1, 0, 0, 25),
                BackgroundColor3 = THEME_DEFAULTS.Subtle,
                Text = optionText,
                TextColor3 = THEME_DEFAULTS.Text,
                Font = Enum.Font.SourceSans,
                TextSize = 14,
            })
            optionButton.MouseEnter:Connect(function() optionButton.BackgroundColor3 = THEME_DEFAULTS.Element end)
            optionButton.MouseLeave:Connect(function() optionButton.BackgroundColor3 = THEME_DEFAULTS.Subtle end)
            
            optionButton.MouseButton1Click:Connect(function()
                local element = Engine.GetElement(elementData.uniqueID)
                element.value = optionText
                dropdownButton.Text = optionText
                isOpen = false
                tween(frame, { Size = UDim2.new(1, 0, 0, ELEMENT_HEIGHT) })
                optionsList.Visible = false
                Engine.ExecuteCode(elementData.uniqueID)
            end)
        end
    end
    
    dropdownButton.MouseButton1Click:Connect(function()
        isOpen = not isOpen
        if isOpen then
            updateOptions()
            optionsList.Visible = true
            local listHeight = optionsList.AbsoluteContentSize.Y + 4
            tween(frame, { Size = UDim2.new(1, 0, 0, ELEMENT_HEIGHT + listHeight + 5) })
        else
            tween(frame, { Size = UDim2.new(1, 0, 0, ELEMENT_HEIGHT) })
            task.wait(0.2)
            optionsList.Visible = false
        end
    end)
    
    updateOptions()

    renderedElements[elementData.uniqueID] = { instance = frame }
    return frame
end


-- //////////////////////////////////////////////////////////////////////////////////
-- // 3. CORE LOGIC & INITIALIZATION
-- //////////////////////////////////////////////////////////////////////////////////

local renderDispatch = {
    Button = renderButton,
    Toggle = renderToggle,
    Slider = renderSlider,
    Dropdown = renderDropdown
}

local function onElementAdded(elementData)
    local tabID = elementData.targetTabID
    local contentPage = contentPagesContainer:FindFirstChild(tabID)
    if not contentPage then
        warn("[Renderer] Could not find content page for tab ID:", tabID)
        return
    end

    local renderFunc = renderDispatch[elementData.type]
    if renderFunc then
        local elementInstance = renderFunc(elementData)
        elementInstance.Parent = contentPage:FindFirstChild("LayoutFrame")
        
        if not renderedElements[elementData.uniqueID] then
             renderedElements[elementData.uniqueID] = { instance = elementInstance }
        end
    else
        warn("[Renderer] No render function found for element type:", elementData.type)
    end
end

local function onElementRemoved(elementID)
    if renderedElements[elementID] and renderedElements[elementID].instance then
        renderedElements[elementID].instance:Destroy()
        renderedElements[elementID] = nil
    end
end

local function onElementValueChanged(elementID, newValue)
    local rendered = renderedElements[elementID]
    if rendered and rendered.updateFunc then
        rendered.updateFunc(newValue, true) -- Update with animation
    end
end

local function onElementUpdated(elementID, elementData)
    onElementRemoved(elementID)
    onElementAdded(elementData)
end

function ElementRenderer.Init(engineRef, containers)
    Engine = engineRef
    contentPagesContainer = containers.contentPagesContainer
    
    -- Connect to Engine signals
    Engine.Signals.ElementAdded:Connect(onElementAdded)
    Engine.Signals.ElementRemoved:Connect(onElementRemoved)
    Engine.Signals.ElementUpdated:Connect(onElementUpdated)
    Engine.Signals.ElementValueChanged:Connect(onElementValueChanged)
end

-- This function will be called by the main script when a tab is created.
function ElementRenderer.CreateContentPage(tabData)
    local existing = contentPagesContainer:FindFirstChild(tabData.uniqueID)
    if existing then return existing end

    local page = create("Frame", {
        Name = tabData.uniqueID,
        Parent = contentPagesContainer,
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Visible = false,
    })

    local scrollingFrame = create("ScrollingFrame", {
        Name = "LayoutFrame",
        Parent = page,
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        BorderSizePixel = 0,
        ScrollBarImageColor3 = Color3.fromRGB(150, 150, 150),
        ScrollBarThickness = 5,
    })

    create("UIListLayout", {
        Parent = scrollingFrame,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 5),
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
    })
    create("UIPadding", {
        Parent = scrollingFrame,
        PaddingLeft = UDim.new(0,10),
        PaddingRight = UDim.new(0,10),
    })
    
    return page
end

function ElementRenderer.DestroyContentPage(tabID)
    local page = contentPagesContainer:FindFirstChild(tabID)
    if page then
        page:Destroy()
    end
end

return ElementRenderer
