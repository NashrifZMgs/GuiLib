--[[
    Nexus-Lua GUI System | Phase 5: Main Orchestrator
    Purpose: Initializes and connects all modules, manages high-level UI logic,
    and handles the save/load functionality.
]]

-- Roblox Services
local HttpService = game:GetService("HttpService")

-- Wait for the game to be ready to avoid issues.
if not game:IsLoaded() then
    game.Loaded:Wait()
end

-- //////////////////////////////////////////////////////////////////////////////////
-- // 1. REQUIRE ALL MODULES
-- // In the final loader, these will be pre-loaded, but for modularity, we use require.
-- //////////////////////////////////////////////////////////////////////////////////

local Engine = require(script.Engine)
local WindowManager = require(script.WindowManager)
local ElementRenderer = require(script.ElementRenderer)
local SettingsPanel = require(script.SettingsPanel)

-- //////////////////////////////////////////////////////////////////////////////////
-- // 2. INITIALIZE MODULES IN CORRECT ORDER
-- //////////////////////////////////////////////////////////////////////////////////

-- WindowManager returns a table of container frames for other modules to use.
local containers = WindowManager.Init(Engine)

-- ElementRenderer and SettingsPanel need the Engine and the containers from the WindowManager.
ElementRenderer.Init(Engine, containers)
SettingsPanel.Init(Engine, containers)

-- //////////////////////////////////////////////////////////////////////////////////
-- // 3. HIGH-LEVEL UI LOGIC AND CONNECTIONS
-- //////////////////////////////////////////////////////////////////////////////////

local isSettingsVisible = false
local currentTheme

-- Function to toggle the visibility of the settings panel
local function setSettingsVisible(visible)
    isSettingsVisible = visible
    containers.settingsPanelContainer.Visible = isSettingsVisible
    containers.contentPagesContainer.Visible = not isSettingsVisible
end

-- Connect the header buttons from the WindowManager
containers.settingsButton.MouseButton1Click:Connect(function()
    setSettingsVisible(not isSettingsVisible)
end)

containers.minimizeButton.MouseButton1Click:Connect(WindowManager.Minimize)
containers.exitButton.MouseButton1Click:Connect(WindowManager.Destroy)

-- Tab Management Logic
local activeTabButton = nil

local function selectTab(tabButton, page)
    -- Deselect the previously active tab
    if activeTabButton and activeTabButton.Parent then
        activeTabButton.BackgroundColor3 = currentTheme.Sidebar or Color3.fromRGB(65, 65, 65)
    end
    
    -- Select the new tab
    activeTabButton = tabButton
    activeTabButton.BackgroundColor3 = currentTheme.Accent or Color3.fromRGB(85, 125, 255)
    
    -- Hide all other pages
    for _, child in ipairs(containers.contentPagesContainer:GetChildren()) do
        if child:IsA("Frame") then
            child.Visible = false
        end
    end
    
    -- Show the correct page
    if page then
        page.Visible = true
    end

    -- Always hide settings when switching to a content tab
    setSettingsVisible(false)
end

-- Connect tab creation/destruction signals
Engine.Signals.TabAdded:Connect(function(tabData)
    local page = ElementRenderer.CreateContentPage(tabData)
    local sidebar = containers.sidebarContainer
    
    local tabButton = Instance.new("TextButton")
    tabButton.Name = tabData.uniqueID
    tabButton.Parent = sidebar
    tabButton.Size = UDim2.new(1, -10, 0, 35)
    tabButton.BackgroundColor3 = currentTheme and currentTheme.Sidebar or Color3.fromRGB(65, 65, 65)
    tabButton.Text = tabData.label
    tabButton.TextColor3 = Color3.fromRGB(230, 230, 230)
    tabButton.Font = Enum.Font.SourceSansSemibold
    tabButton.TextSize = 16
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = tabButton

    tabButton.MouseButton1Click:Connect(function()
        selectTab(tabButton, page)
    end)
    
    -- Automatically select the first tab added
    if not activeTabButton then
        selectTab(tabButton, page)
    end
end)

Engine.Signals.TabRemoved:Connect(function(tabID)
    ElementRenderer.DestroyContentPage(tabID)
    local sidebar = containers.sidebarContainer
    local button = sidebar:FindFirstChild(tabID)
    if button then
        if activeTabButton == button then activeTabButton = nil end
        button:Destroy()
    end
end)

-- Theme Management Logic
Engine.Signals.ThemeChanged:Connect(function(theme)
    currentTheme = theme
    containers.themeApplicator(theme)
end)

-- Notification Logic
Engine.Signals.NotificationRequested:Connect(function(title, content)
    -- This is a placeholder for a proper notification system.
    -- For now, we will use a simple print. A full implementation
    -- would create a notification frame in the WindowManager.
    print(string.format("[GUI NOTIFICATION | %s]: %s", title, content))
end)

-- //////////////////////////////////////////////////////////////////////////////////
-- // 4. SAVE AND LOAD FUNCTIONALITY (CLIPBOARD METHOD)
-- //////////////////////////////////////////////////////////////////////////////////

local function saveConfiguration()
    if not setclipboard then
        Engine.Signals.NotificationRequested:Fire("Error", "Clipboard function not available in this executor.")
        return
    end

    local dataToSave = {
        Registry = Engine.Registry
    }
    
    local success, encodedData = pcall(function()
        return HttpService:JSONEncode(dataToSave)
    end)
    
    if success then
        setclipboard(encodedData)
        Engine.Signals.NotificationRequested:Fire("System", "Configuration copied to clipboard!")
    else
        Engine.Signals.NotificationRequested:Fire("Error", "Failed to encode configuration.")
    end
end

local function loadConfiguration(encodedData)
    local success, decodedData = pcall(function()
        return HttpService:JSONDecode(encodedData)
    end)
    
    if success and decodedData and decodedData.Registry then
        -- Clear existing setup before loading
        while #Engine.Registry.Tabs > 0 do
            Engine.RemoveTab(Engine.Registry.Tabs[1].uniqueID)
        end
        
        -- Load new data
        Engine.UpdateTheme(decodedData.Registry.Theme or {})
        for _, tabData in ipairs(decodedData.Registry.Tabs) do
            Engine.AddTab(tabData)
        end
        for _, elementData in pairs(decodedData.Registry.Elements) do
            Engine.AddElement(elementData)
        end
        
        Engine.Signals.NotificationRequested:Fire("System", "Configuration Loaded Successfully!")
    else
        Engine.Signals.NotificationRequested:Fire("Error", "Failed to load config. Data may be corrupt.")
    end
end

-- Connect the signals from the Engine to our functions
Engine.Signals.SaveRequested:Connect(saveConfiguration)
Engine.Signals.LoadRequested:Connect(loadConfiguration)

-- //////////////////////////////////////////////////////////////////////////////////
-- // 5. DEFAULT SETUP ON FIRST LAUNCH
-- //////////////////////////////////////////////////////////////////////////////////

-- Set a default theme
local defaultTheme = {
    Background = Color3.fromRGB(55, 55, 55),
    Header = Color3.fromRGB(35, 35, 35),
    Sidebar = Color3.fromRGB(45, 45, 45),
    Accent = Color3.fromRGB(85, 125, 255),
}
Engine.UpdateTheme(defaultTheme)

-- Create a default tab if none exist
if #Engine.Registry.Tabs == 0 then
    Engine.AddTab({ uniqueID = "main", label = "Main" })
end

print("Nexus-Lua GUI: System is ready.")
