--[[
    Nexus-Lua GUI System | Phase 2: The Window Manager
    Purpose: Creates and manages the main visual containers of the GUI.
    Handles dragging, minimizing, and the core layout.
]]

local WindowManager = {}

-- Roblox Services
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

-- Configuration
local ZINDEX_BASE = 500
local WINDOW_DEFAULT_SIZE = Vector2.new(550, 400)
local HEADER_HEIGHT = 35
local SIDEBAR_WIDTH = 130

-- Module State
local Engine -- This will be set by the main script
local gui -- The main ScreenGui
local window -- The main window frame
local header, sidebar, contentArea, orb
local isDragging = false
local dragStart, originalPosition

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

-- //////////////////////////////////////////////////////////////////////////////////
-- // 2. ANIMATION AND THEME
-- //////////////////////////////////////////////////////////////////////////////////

local function tween(instance, goal, duration)
    duration = duration or 0.25
    local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
    local t = TweenService:Create(instance, tweenInfo, goal)
    t:Play()
    return t
end

function WindowManager.ApplyTheme(theme)
    if not window then return end
    
    tween(window, { BackgroundColor3 = theme.Background })
    tween(header, { BackgroundColor3 = theme.Header })
    tween(sidebar, { BackgroundColor3 = theme.Sidebar })
    
    -- You can add more theme applications here for text colors, etc.
end

-- //////////////////////////////////////////////////////////////////////////////////
-- // 3. WINDOW BEHAVIORS (DRAG, MINIMIZE)
-- //////////////////////////////////////////////////////////////////////////////////

local function onDragBegan(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        isDragging = true
        dragStart = input.Position
        originalPosition = window.Position
        window.ZIndex = ZINDEX_BASE + 10 -- Bring to front when interacting
    end
end

local function onInputChanged(input)
    if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        window.Position = UDim2.fromOffset(originalPosition.X.Offset + delta.X, originalPosition.Y.Offset + delta.Y)
    end
end

local function onInputEnded(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        if isDragging then
            isDragging = false
            window.ZIndex = ZINDEX_BASE
        end
    end
end

function WindowManager.Minimize()
    local lastPosition = window.AbsolutePosition
    orb.Position = UDim2.fromOffset(lastPosition.X, lastPosition.Y)
    
    tween(window, { Size = UDim2.fromOffset(0, 0), Position = UDim2.fromOffset(lastPosition.X, lastPosition.Y), BackgroundTransparency = 1 }, 0.25)
    
    for _, child in ipairs(window:GetChildren()) do
        tween(child, {Transparency = 1}, 0.1)
    end

    orb.Visible = true
    tween(orb, { ImageTransparency = 0, BackgroundTransparency = 0.5 }, 0.2)
    orb.Draggable = true
end

function WindowManager.Restore()
    local orbPosition = orb.AbsolutePosition
    local windowSize = window.Size.X.Offset > 50 and window.Size or UDim2.fromOffset(WINDOW_DEFAULT_SIZE.X, WINDOW_DEFAULT_SIZE.Y)
    
    tween(window, { Size = windowSize, Position = UDim2.fromOffset(orbPosition.X, orbPosition.Y), BackgroundTransparency = 0.1 }, 0.25)
    
    for _, child in ipairs(window:GetChildren()) do
        tween(child, {Transparency = 0}, 0.4)
    end

    tween(orb, { ImageTransparency = 1, BackgroundTransparency = 1 }, 0.2)
    task.wait(0.2)
    orb.Visible = false
    orb.Draggable = false
end

function WindowManager.Destroy()
    if gui then
        gui:Destroy()
        gui = nil
    end
end

-- //////////////////////////////////////////////////////////////////////////////////
-- // 4. COMPONENT CREATION
-- //////////////////////////////////////////////////////////////////////////////////

local function createHeader(parent)
    header = create("Frame", {
        Name = "Header",
        Parent = parent,
        BackgroundColor3 = Color3.fromRGB(35, 35, 35),
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, HEADER_HEIGHT),
        ZIndex = ZINDEX_BASE + 2,
    })
    header.InputBegan:Connect(onDragBegan)
    
    local title = create("TextLabel", {
        Name = "Title",
        Parent = header,
        Size = UDim2.new(0, 200, 1, 0),
        Position = UDim2.new(0, 10, 0, 0),
        Text = "GUI System",
        TextColor3 = Color3.fromRGB(240, 240, 240),
        Font = Enum.Font.SourceSansSemibold,
        TextSize = 18,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = ZINDEX_BASE + 3,
    })

    local iconTray = create("Frame", {
        Name = "IconTray",
        Parent = header,
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 100, 1, 0),
        Position = UDim2.new(1, -105, 0, 0),
        ZIndex = ZINDEX_BASE + 3,
    })
    create("UIListLayout", {
        Parent = iconTray,
        FillDirection = Enum.FillDirection.Horizontal,
        SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        Padding = UDim.new(0, 5)
    })
    
    local settingsBtn = create("TextButton", { Name = "SettingsButton", Text = "S", LayoutOrder = 1, Size = UDim2.fromOffset(28, 28) })
    local minimizeBtn = create("TextButton", { Name = "MinimizeButton", Text = "_", LayoutOrder = 2, Size = UDim2.fromOffset(28, 28) })
    local exitBtn = create("TextButton", { Name = "ExitButton", Text = "X", LayoutOrder = 3, Size = UDim2.fromOffset(28, 28) })
    
    for _, btn in ipairs({settingsBtn, minimizeBtn, exitBtn}) do
        btn.Parent = iconTray
        btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        btn.TextColor3 = Color3.fromRGB(220, 220, 220)
        btn.TextSize = 20
        btn.Font = Enum.Font.SourceSansBold
        create("UICorner", { CornerRadius = UDim.new(0, 4), Parent = btn })
    end
    
    return { settingsBtn = settingsBtn, minimizeBtn = minimizeBtn, exitBtn = exitBtn }
end

local function createSidebar(parent)
    sidebar = create("ScrollingFrame", {
        Name = "Sidebar",
        Parent = parent,
        BackgroundColor3 = Color3.fromRGB(45, 45, 45),
        BorderSizePixel = 0,
        Size = UDim2.new(0, SIDEBAR_WIDTH, 1, -HEADER_HEIGHT),
        Position = UDim2.new(0, 0, 0, HEADER_HEIGHT),
        ClipsDescendants = true,
        ZIndex = ZINDEX_BASE + 1,
        CanvasSize = UDim2.new(),
        ScrollBarImageColor3 = Color3.fromRGB(150, 150, 150),
        ScrollBarThickness = 5,
    })
    
    create("UIListLayout", {
        Name = "TabListLayout",
        Parent = sidebar,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 5),
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
    })
    create("UIPadding", {
        Parent = sidebar,
        PaddingTop = UDim.new(0, 5)
    })

    return sidebar
end

local function createContentArea(parent)
    contentArea = create("Frame", {
        Name = "ContentArea",
        Parent = parent,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.new(1, -SIDEBAR_WIDTH, 1, -HEADER_HEIGHT),
        Position = UDim2.new(0, SIDEBAR_WIDTH, 0, HEADER_HEIGHT),
        ClipsDescendants = true,
        ZIndex = ZINDEX_BASE + 1,
    })
    
    -- This frame will hold all the pages for user-created elements.
    local contentPagesContainer = create("Frame", {
        Name = "ContentPagesContainer",
        Parent = contentArea,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
    })

    -- This frame will hold the settings UI.
    local settingsPanelContainer = create("ScrollingFrame", {
        Name = "SettingsPanelContainer",
        Parent = contentArea,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        Visible = false, -- Initially hidden
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarImageColor3 = Color3.fromRGB(150, 150, 150),
        ScrollBarThickness = 5,
    })
    create("UIPadding", {
        Parent = settingsPanelContainer,
        PaddingLeft = UDim.new(0,15),
        PaddingRight = UDim.new(0,15),
        PaddingTop = UDim.new(0,10),
    })

    return { pages = contentPagesContainer, settings = settingsPanelContainer }
end

local function createOrb(parent)
    orb = create("ImageButton", {
        Name = "Orb",
        Parent = parent,
        Image = "rbxassetid://6034842194", -- A simple orb/circle icon
        ImageColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundColor3 = Color3.fromRGB(50,50,50),
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(50, 50),
        ZIndex = ZINDEX_BASE + 11,
        ImageTransparency = 1,
        Visible = false,
        Draggable = false
    })
    create("UICorner", {CornerRadius = UDim.new(1,0), Parent = orb})

    orb.MouseButton1Click:Connect(WindowManager.Restore)
    -- Manual drag for the orb
    orb.InputBegan:Connect(function(input)
        if orb.Draggable and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
            local startPos = input.Position
            local startOrbPos = orb.Position
            local conn
            conn = UserInputService.InputChanged:Connect(function(inp)
                if inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch then
                    local delta = inp.Position - startPos
                    orb.Position = UDim2.fromOffset(startOrbPos.X.Offset + delta.X, startOrbPos.Y.Offset + delta.Y)
                elseif inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
                    if inp.UserInputState == Enum.UserInputState.End then
                        conn:Disconnect()
                    end
                end
            end)
        end
    end)

    return orb
end

-- //////////////////////////////////////////////////////////////////////////////////
-- // 5. PUBLIC API
-- //////////////////////////////////////////////////////////////////////////////////

function WindowManager.Init(engineRef)
    Engine = engineRef
    
    gui = create("ScreenGui", {
        Name = "NexusLuaGUISystem",
        Parent = gethui and gethui() or game:GetService("CoreGui"),
        ZIndexBehavior = Enum.ZIndexBehavior.Global,
        ResetOnSpawn = false,
    })
    
    window = create("Frame", {
        Name = "Window",
        Parent = gui,
        BackgroundColor3 = Color3.fromRGB(55, 55, 55),
        BackgroundTransparency = 0.1,
        BorderSizePixel = 0,
        Active = true,
        Draggable = false,
        Size = UDim2.fromOffset(WINDOW_DEFAULT_SIZE.X, WINDOW_DEFAULT_SIZE.Y),
        Position = UDim2.new(0.5, -WINDOW_DEFAULT_SIZE.X / 2, 0.5, -WINDOW_DEFAULT_SIZE.Y / 2),
        ClipsDescendants = true,
        ZIndex = ZINDEX_BASE,
    })
    create("UICorner", { CornerRadius = UDim.new(0, 6), Parent = window })
    
    -- Create components
    local headerControls = createHeader(window)
    local sidebarContainer = createSidebar(window)
    local contentContainers = createContentArea(window)
    local orbControl = createOrb(gui)
    
    -- Connect input events for dragging
    UserInputService.InputChanged:Connect(onInputChanged)
    UserInputService.InputEnded:Connect(onInputEnded)
    
    -- Return containers for other modules to use
    return {
        sidebarContainer = sidebarContainer,
        contentPagesContainer = contentContainers.pages,
        settingsPanelContainer = contentContainers.settings,
        
        settingsButton = headerControls.settingsBtn,
        minimizeButton = headerControls.minimizeBtn,
        exitButton = headerControls.exitBtn,
        
        themeApplicator = WindowManager.ApplyTheme
    }
end

return WindowManager
