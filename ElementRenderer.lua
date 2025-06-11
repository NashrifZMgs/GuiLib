--[[
    Phase 3: The Element Renderer
    This module is responsible for creating the visual representation of elements.
    - It listens for signals from the Engine (ElementAdded, ElementRemoved, etc.).
    - It contains functions to render each type of element (Button, Toggle, Slider, Dropdown).
    - It connects UI events (e.g., a button click) back to the Engine to execute code.
    - It updates the visual state of elements when their values change programmatically.
]]

local ElementRenderer = {}

-- Roblox Services
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

-- Module State
local Engine
local contentContainer -- The parent frame for all content pages, provided by WindowManager
local renderedElements = {} -- Stores the actual GUI objects, indexed by elementID

-- Configuration
local ELEMENT_HEIGHT = 40
local ELEMENT_PADDING = 10

-- //////////////////////////////////////////////////////////////////////////////////
-- // 1. INSTANCE CREATION UTILITIES
-- //////////////////////////////////////////////////////////////////////////////////

local function create(instanceType, properties)
    local inst = Instance.new(instanceType)
    for prop, value in pairs(properties or {}) do
        inst[prop] = value
    end
    return inst
end

local function createBaseElementFrame(elementData)
    local frame = create("Frame", {
        Name = elementData.uniqueID,
        BackgroundColor3 = Color3.fromRGB(60, 60, 60),
        BorderSizePixel = 0,
        Size = UDim2.new(1, -ELEMENT_PADDING * 2, 0, ELEMENT_HEIGHT),
        LayoutOrder = os.time(), -- Simple way to order by creation
    })
    create("UICorner", { CornerRadius = UDim.new(0, 4), Parent = frame })
    
    create("TextLabel", {
        Name = "Label",
        Parent = frame,
        Size = UDim2.new(0.4, 0, 1, 0),
        Position = UDim2.new(0, ELEMENT_PADDING, 0, 0),
        Text = elementData.label,
        TextColor3 = Color3.fromRGB(240, 240, 240),
        Font = Enum.Font.SourceSans,
        TextSize = 16,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    
    return frame
end

-- //////////////////////////////////////////////////////////////////////////////////
-- // 2. RENDERER FUNCTIONS FOR EACH ELEMENT TYPE
-- //////////////////////////////////////////////////////////////////////////////////

local function renderButton(elementData)
    local frame = createBaseElementFrame(elementData)
    
    local button = create("TextButton", {
        Name = "ButtonControl",
        Parent = frame,
        Size = UDim2.new(0.5, -ELEMENT_PADDING, 1, -10),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = Color3.fromRGB(80, 80, 80),
        Text = elementData.label,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        Font = Enum.Font.SourceSansSemibold,
        TextSize = 16,
    })
    create("UICorner", { CornerRadius = UDim.new(0, 4), Parent = button })
    
    -- Hide the base label as the button has its own
    frame.Label.Visible = false
    
    button.MouseButton1Click:Connect(function()
        Engine.ExecuteCode(elementData.uniqueID)
    end)
    
    return frame
end

local function renderToggle(elementData)
    local frame = createBaseElementFrame(elementData)
    
    local switch = create("TextButton", {
        Name = "ToggleControl",
        Parent = frame,
        Size = UDim2.new(0, 60, 0, ELEMENT_HEIGHT - 16),
        Position = UDim2.new(1, -ELEMENT_PADDING - 60, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = Color3.fromRGB(40, 40, 40),
        Text = "",
    })
    create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = switch })
    
    local knob = create("Frame", {
        Name = "Knob",
        Parent = switch,
        Size = UDim2.new(0, 24, 0, 24),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, 15, 0.5, 0),
        BackgroundColor3 = Color3.fromRGB(200, 200, 200),
        BorderSizePixel = 0,
    })
    create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = knob })

    local function updateVisuals(value, withAnimation)
        local goalPosition = value and UDim2.new(0, 45, 0.5, 0) or UDim2.new(0, 15, 0.5, 0)
        local goalColor = value and Color3.fromRGB(70, 180, 90) or Color3.fromRGB(150, 150, 150)
        
        if withAnimation then
            local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
            TweenService:Create(knob, tweenInfo, { Position = goalPosition }):Play()
            TweenService:Create(knob, tweenInfo, { BackgroundColor3 = goalColor }):Play()
        else
            knob.Position = goalPosition
            knob.BackgroundColor3 = goalColor
        end
    end
    
    switch.MouseButton1Click:Connect(function()
        local element = Engine.GetElement(elementData.uniqueID)
        element.value = not element.value
        updateVisuals(element.value, true)
        Engine.ExecuteCode(elementData.uniqueID)
    end)
    
    updateVisuals(elementData.value, false)
    
    renderedElements[elementData.uniqueID] = {
        instance = frame,
        updateFunc = updateVisuals,
    }
    return frame
end

local function renderSlider(elementData)
    local frame = createBaseElementFrame(elementData)
    local props = elementData.properties
    
    local valueLabel = create("TextLabel", {
        Name = "ValueLabel",
        Parent = frame,
        Size = UDim2.new(0, 50, 1, 0),
        Position = UDim2.new(1, -ELEMENT_PADDING - 50, 0, 0),
        BackgroundTransparency = 1,
        Font = Enum.Font.SourceSans,
        TextSize = 15,
        TextColor3 = Color3.fromRGB(200, 200, 200),
        Text = tostring(elementData.value) .. (props.suffix or ""),
    })
    
    local track = create("Frame", {
        Name = "Track",
        Parent = frame,
        Size = UDim2.new(0.5, -ELEMENT_PADDING - 50, 0, 8),
        Position = UDim2.new(0.5, -25, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = Color3.fromRGB(40, 40, 40),
        BorderSizePixel = 0,
    })
    create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = track })
    
    local progress = create("Frame", {
        Name = "Progress",
        Parent = track,
        Size = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = Color3.fromRGB(70, 120, 220),
        BorderSizePixel = 0,
    })
    create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = progress })
    
    local isDragging = false
    
    local function updateVisuals(value)
        local percentage = (value - props.minValue) / (props.maxValue - props.minValue)
        progress.Size = UDim2.new(percentage, 0, 1, 0)
        valueLabel.Text = tostring(math.floor(value / props.increment + 0.5) * props.increment) .. (props.suffix or "")
    end
    
    local function onInput(input)
        local percentage = (input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X
        percentage = math.clamp(percentage, 0, 1)
        
        local rawValue = props.minValue + (props.maxValue - props.minValue) * percentage
        local steppedValue = math.clamp(math.floor(rawValue / props.increment + 0.5) * props.increment, props.minValue, props.maxValue)

        if Engine.GetElement(elementData.uniqueID).value ~= steppedValue then
            Engine.GetElement(elementData.uniqueID).value = steppedValue
            updateVisuals(steppedValue)
            Engine.ExecuteCode(elementData.uniqueID)
        end
    end
    
    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isDragging = true
            onInput(input)
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            onInput(input)
        end
    end)
    
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isDragging = false
        end
    end)

    updateVisuals(elementData.value)

    renderedElements[elementData.uniqueID] = {
        instance = frame,
        updateFunc = updateVisuals,
    }
    return frame
end

-- //////////////////////////////////////////////////////////////////////////////////
-- // 3. CORE LOGIC
-- //////////////////////////////////////////////////////////////////////////////////

local renderDispatch = {
    Button = renderButton,
    Toggle = renderToggle,
    Slider = renderSlider,
    -- Dropdown can be added here in the same pattern
}

local function onElementAdded(elementData)
    local tabID = elementData.targetTabID
    local contentPage = contentContainer:FindFirstChild(tabID)
    if not contentPage then
        warn("[Renderer] Could not find content page for tab ID:", tabID)
        return
    end

    local renderFunc = renderDispatch[elementData.type]
    if renderFunc then
        local elementInstance = renderFunc(elementData)
        elementInstance.Parent = contentPage:FindFirstChild("LayoutFrame")
        
        -- Store a reference to the top-level frame instance.
        if not renderedElements[elementData.uniqueID] then
             renderedElements[elementData.uniqueID] = { instance = elementInstance }
        end
    else
        warn("[Renderer] No render function found for element type:", elementData.type)
    end
end

local function onElementRemoved(elementID)
    if renderedElements[elementID] then
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

function ElementRenderer.Init(engineRef, containers)
    Engine = engineRef
    contentContainer = containers.contentContainer
    
    -- Create content pages for any pre-existing tabs
    for _, tabData in ipairs(Engine.Registry.Tabs) do
        ElementRenderer.CreateContentPage(tabData)
    end
    
    -- Connect to Engine signals
    Engine.Signals.ElementAdded:Connect(onElementAdded)
    Engine.Signals.ElementRemoved:Connect(onElementRemoved)
    Engine.Signals.ElementValueChanged:Connect(onElementValueChanged)
end

-- This function will be called by the main script when a tab is created.
function ElementRenderer.CreateContentPage(tabData)
    local existing = contentContainer:FindFirstChild(tabData.uniqueID)
    if existing then return existing end

    local page = create("Frame", {
        Name = tabData.uniqueID,
        Parent = contentContainer,
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Visible = false, -- Will be made visible by tab selection logic
    })

    local scrollingFrame = create("ScrollingFrame", {
        Name = "LayoutFrame",
        Parent = page,
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        CanvasSize = UDim2.new(0, 0, 0, 0), -- Let UIListLayout manage this
        BorderSizePixel = 0,
        ScrollBarImageColor3 = Color3.fromRGB(150, 150, 150),
        ScrollBarThickness = 6,
    })

    create("UIListLayout", {
        Parent = scrollingFrame,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, ELEMENT_PADDING),
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
    })
    
    return page
end

function ElementRenderer.DestroyContentPage(tabID)
    local page = contentContainer:FindFirstChild(tabID)
    if page then
        page:Destroy()
    end
end

return ElementRenderer
