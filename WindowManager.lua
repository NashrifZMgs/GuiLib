--[[
    Phase 2: The Window & Layout Manager
    This module creates and manages all the primary visual containers of the GUI.
    - It builds the main window, header, sidebar, and content area.
    - It handles dragging, resizing, and minimizing/restoring the window.
    - It implements the slide-in/out animation for the sidebar.
    - It listens for notification requests from the Engine.
]]

local WindowManager = {}

-- Roblox Services
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")

-- Configuration
local ZINDEX_BASE = 500
local WINDOW_MIN_SIZE = Vector2.new(450, 300)
local SIDEBAR_WIDTH = 150
local HEADER_HEIGHT = 40

-- Module State
local Engine -- This will be set by the main script
local gui -- The main ScreenGui
local window -- The main window frame
local header, sidebar, contentArea, orb, resizeHandle
local isSidebarVisible = true
local isDragging = false
local isResizing = false
local dragStart, originalPosition
local resizeStart, originalSize

-- //////////////////////////////////////////////////////////////////////////////////
-- // 1. INSTANCE CREATION UTILITIES
-- // Helper functions to keep the main code cleaner.
-- //////////////////////////////////////////////////////////////////////////////////

local function create(instanceType, properties)
    local inst = Instance.new(instanceType)
    for prop, value in pairs(properties or {}) do
        inst[prop] = value
    end
    return inst
end

-- //////////////////////////////////////////////////////////////////////////////////
-- // 2. ANIMATION AND TWEENING
-- //////////////////////////////////////////////////////////////////////////////////

local function tween(instance, goal, duration)
    duration = duration or 0.3
    local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
    local t = TweenService:Create(instance, tweenInfo, goal)
    t:Play()
    return t
end

-- //////////////////////////////////////////////////////////////////////////////////
-- // 3. WINDOW BEHAVIORS (DRAG, RESIZE, MINIMIZE)
-- //////////////////////////////////////////////////////////////////////////////////

local function onDragBegan(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        isDragging = true
        dragStart = input.Position
        originalPosition = window.Position
        window.ZIndex = ZINDEX_BASE + 10 -- Bring to front when interacting
    end
end

local function onResizeBegan(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        isResizing = true
        resizeStart = input.Position
        originalSize = window.AbsoluteSize
        window.ZIndex = ZINDEX_BASE + 10
    end
end

local function onInputChanged(input)
    if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        window.Position = UDim2.fromOffset(originalPosition.X.Offset + delta.X, originalPosition.Y.Offset + delta.Y)
    elseif isResizing and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - resizeStart
        local newSize = originalSize + delta
        window.Size = UDim2.fromOffset(
            math.max(WINDOW_MIN_SIZE.X, newSize.X),
            math.max(WINDOW_MIN_SIZE.Y, newSize.Y)
        )
    end
end

local function onInputEnded(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        isDragging = false
        isResizing = false
        window.ZIndex = ZINDEX_BASE
    end
end

local function minimizeWindow()
    local lastPosition = orb.AbsolutePosition
    tween(window, { Size = UDim2.fromOffset(0, 0), Position = UDim2.fromOffset(lastPosition.X, lastPosition.Y), BackgroundTransparency = 1 }, 0.25)
    tween(orb, { ImageTransparency = 0, BackgroundTransparency = 0.5 }, 0.2)
    orb.Draggable = true
end

local function restoreWindow()
    local orbPosition = orb.AbsolutePosition
    local windowSize = window.Size.X.Offset > 0 and window.Size or UDim2.fromOffset(WINDOW_MIN_SIZE.X, WINDOW_MIN_SIZE.Y)
    
    tween(window, { Size = windowSize, Position = UDim2.fromOffset(orbPosition.X, orbPosition.Y), BackgroundTransparency = 0.1 }, 0.25)
    tween(orb, { ImageTransparency = 1, BackgroundTransparency = 1 }, 0.2)
    orb.Draggable = false
end

-- //////////////////////////////////////////////////////////////////////////////////
-- // 4. COMPONENT CREATION
-- //////////////////////////////////////////////////////////////////////////////////

local function createHeader()
    header = create("Frame", {
        Name = "Header",
        Parent = window,
        BackgroundColor3 = Color3.fromRGB(35, 35, 35),
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, HEADER_HEIGHT),
        ZIndex = ZINDEX_BASE + 2,
    })
    header.InputBegan:Connect(onDragBegan)
    
    local hamburgerBtn = create("TextButton", {
        Name = "HamburgerButton",
        Parent = header,
        Size = UDim2.new(0, HEADER_HEIGHT, 0, HEADER_HEIGHT),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = Color3.fromRGB(35, 35, 35),
        Text = "≡",
        TextColor3 = Color3.fromRGB(220, 220, 220),
        TextSize = 30,
        Font = Enum.Font.SourceSansBold,
        ZIndex = ZINDEX_BASE + 3,
    })
    hamburgerBtn.MouseButton1Click:Connect(function()
        WindowManager.ToggleSidebar()
    end)
    
    create("TextLabel", {
        Name = "Title",
        Parent = header,
        Size = UDim2.new(1, - (HEADER_HEIGHT * 4), 0, HEADER_HEIGHT),
        Position = UDim2.new(0, HEADER_HEIGHT, 0, 0),
        Text = "GUI System",
        TextColor3 = Color3.fromRGB(255, 255, 255),
        Font = Enum.Font.SourceSansSemibold,
        TextSize = 18,
        ZIndex = ZINDEX_BASE + 3,
    })

    local iconTray = create("Frame", {
        Name = "IconTray",
        Parent = header,
        BackgroundTransparency = 1,
        Size = UDim2.new(0, HEADER_HEIGHT * 3, 0, HEADER_HEIGHT),
        Position = UDim2.new(1, - (HEADER_HEIGHT * 3), 0, 0),
        ZIndex = ZINDEX_BASE + 3,
    })
    create("UIListLayout", {
        Parent = iconTray,
        FillDirection = Enum.FillDirection.Horizontal,
        SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, 5)
    })
    
    local settingsBtn = create("TextButton", { Name = "SettingsButton", Parent = iconTray, LayoutOrder = 1, Size = UDim2.new(0, 30, 0, 30), BackgroundColor3 = Color3.fromRGB(35, 35, 35), Text = "S", TextColor3 = Color3.fromRGB(220, 220, 220), TextSize = 20, Font = Enum.Font.SourceSansBold })
    local minimizeBtn = create("TextButton", { Name = "MinimizeButton", Parent = iconTray, LayoutOrder = 2, Size = UDim2.new(0, 30, 0, 30), BackgroundColor3 = Color3.fromRGB(35, 35, 35), Text = "M", TextColor3 = Color3.fromRGB(220, 220, 220), TextSize = 20, Font = Enum.Font.SourceSansBold })
    local exitBtn = create("TextButton", { Name = "ExitButton", Parent = iconTray, LayoutOrder = 3, Size = UDim2.new(0, 30, 0, 30), BackgroundColor3 = Color3.fromRGB(35, 35, 35), Text = "X", TextColor3 = Color3.fromRGB(220, 220, 220), TextSize = 20, Font = Enum.Font.SourceSansBold })
    
    minimizeBtn.MouseButton1Click:Connect(minimizeWindow)
    exitBtn.MouseButton1Click:Connect(function()
        WindowManager.Destroy()
    end)
    
    return { settingsBtn = settingsBtn }
end

local function createSidebar()
    sidebar = create("Frame", {
        Name = "Sidebar",
        Parent = window,
        BackgroundColor3 = Color3.fromRGB(45, 45, 45),
        BorderSizePixel = 0,
        Size = UDim2.new(0, SIDEBAR_WIDTH, 1, -HEADER_HEIGHT),
        Position = UDim2.new(0, 0, 0, HEADER_HEIGHT),
        ClipsDescendants = true,
        ZIndex = ZINDEX_BASE + 1,
    })
    
    local scrollingFrame = create("ScrollingFrame", {
        Name = "SidebarScroll",
        Parent = sidebar,
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarImageColor3 = Color3.fromRGB(150, 150, 150),
        ScrollBarThickness = 6,
    })
    
    create("UIListLayout", {
        Name = "TabListLayout",
        Parent = scrollingFrame,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 5),
    })

    return scrollingFrame
end

local function createContentArea()
    contentArea = create("Frame", {
        Name = "ContentArea",
        Parent = window,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.new(1, -SIDEBAR_WIDTH, 1, -HEADER_HEIGHT),
        Position = UDim2.new(0, SIDEBAR_WIDTH, 0, HEADER_HEIGHT),
        ClipsDescendants = true,
        ZIndex = ZINDEX_BASE + 1,
    })
    
    local contentFrame = create("Frame", {
        Name = "ContentFrame",
        Parent = contentArea,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
    })

    local settingsFrame = create("Frame", {
        Name = "SettingsFrame",
        Parent = contentArea,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        Visible = false
    })

    return { content = contentFrame, settings = settingsFrame }
end

local function createOrb()
    orb = create("ImageButton", {
        Name = "Orb",
        Parent = gui,
        Image = "rbxassetid://2635952492", -- A simple circle/orb icon
        ImageColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(50, 50),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        ZIndex = ZINDEX_BASE + 11,
        ImageTransparency = 1,
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = Rect.new(100, 100, 100, 100),
    })
    orb.MouseButton1Click:Connect(restoreWindow)
end

-- //////////////////////////////////////////////////////////////////////////////////
-- // 5. PUBLIC API
-- //////////////////////////////////////////////////////////////////////////////////

function WindowManager.ToggleSidebar()
    isSidebarVisible = not isSidebarVisible
    if isSidebarVisible then
        tween(sidebar, { Position = UDim2.new(0, 0, 0, HEADER_HEIGHT) })
        tween(contentArea, { Size = UDim2.new(1, -SIDEBAR_WIDTH, 1, -HEADER_HEIGHT), Position = UDim2.new(0, SIDEBAR_WIDTH, 0, HEADER_HEIGHT) })
    else
        tween(sidebar, { Position = UDim2.new(0, -SIDEBAR_WIDTH, 0, HEADER_HEIGHT) })
        tween(contentArea, { Size = UDim2.new(1, 0, 1, -HEADER_HEIGHT), Position = UDim2.new(0, 0, 0, HEADER_HEIGHT) })
    end
end

function WindowManager.Destroy()
    if gui then
        gui:Destroy()
        gui = nil
    end
end

function WindowManager.Init(engineRef)
    Engine = engineRef
    
    -- Main ScreenGui
    gui = create("ScreenGui", {
        Name = "MyGUISystem",
        Parent = game:GetService("CoreGui"),
        ZIndexBehavior = Enum.ZIndexBehavior.Global,
        ResetOnSpawn = false,
    })
    
    -- Main Window
    window = create("Frame", {
        Name = "Window",
        Parent = gui,
        BackgroundColor3 = Color3.fromRGB(55, 55, 55),
        BackgroundTransparency = 0.1,
        BorderSizePixel = 1,
        BorderColor3 = Color3.fromRGB(20, 20, 20),
        Active = true,
        Draggable = false, -- We handle dragging manually
        Size = UDim2.fromOffset(600, 400),
        Position = UDim2.new(0.5, -300, 0.5, -200),
        ClipsDescendants = true,
        ZIndex = ZINDEX_BASE,
    })
    create("UICorner", { CornerRadius = UDim.new(0, 6), Parent = window })
    
    -- Create components
    local headerControls = createHeader()
    local sidebarContainer = createSidebar()
    local contentContainers = createContentArea()
    createOrb()
    
    resizeHandle = create("Frame", {
        Name = "ResizeHandle",
        Parent = window,
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(20, 20),
        Position = UDim2.new(1, -20, 1, -20),
        ZIndex = ZINDEX_BASE + 3,
    })
    resizeHandle.InputBegan:Connect(onResizeBegan)
    
    -- Connect input events
    UserInputService.InputChanged:Connect(onInputChanged)
    UserInputService.InputEnded:Connect(onInputEnded)
    
    -- Return containers for other modules to use
    return {
        tabContainer = sidebarContainer,
        contentContainer = contentContainers.content,
        settingsContainer = contentContainers.settings,
        settingsButton = headerControls.settingsBtn,
    }
end

return WindowManager
