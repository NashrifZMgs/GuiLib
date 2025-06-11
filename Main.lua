--[[
    Phase 5: The Main Script
    This is the top-level script that initializes and connects all modules.
    - It requires all the other Lua modules (Engine, WindowManager, etc.).
    - It calls the Init() function for each module in the correct order.
    - It connects the various parts together (e.g., settings button toggles settings panel).
    - It implements the final save/load functionality.
]]

-- Roblox Services
local HttpService = game:GetService("HttpService")

-- Configuration
local CONFIG_FOLDER_NAME = "MyGUISystem"
local CONFIG_FILE_NAME = "gui_config.json"

-- Wait for the game to be ready
if not game:IsLoaded() then
    game.Loaded:Wait()
end

-- //////////////////////////////////////////////////////////////////////////////////
-- // 1. REQUIRE ALL MODULES
-- // Assuming all modules are located in the same place as this script.
-- //////////////////////////////////////////////////////////////////////////////////

local Engine = require(script.Engine)
local WindowManager = require(script.WindowManager)
local ElementRenderer = require(script.ElementRenderer)
local SettingsPanel = require(script.SettingsPanel)

print("GUI System: All modules loaded.")

-- //////////////////////////////////////////////////////////////////////////////////
-- // 2. INITIALIZE MODULES IN CORRECT ORDER
-- // The order is critical: Engine -> WindowManager -> Renderer -> SettingsPanel
-- //////////////////////////////////////////////////////////////////////////////////

-- WindowManager.Init() returns a table of container frames for other modules to use.
local containers = WindowManager.Init(Engine)

-- ElementRenderer needs the Engine for signals and the content container from the WindowManager.
ElementRenderer.Init(Engine, containers)

-- SettingsPanel needs the Engine and the settings container from the WindowManager.
SettingsPanel.Init(Engine, containers)

print("GUI System: All modules initialized.")

-- //////////////////////////////////////////////////////////////////////////////////
-- // 3. CONNECT THE SYSTEM TOGETHER
-- // This is where we make the UI interactive at a high level.
-- //////////////////////////////////////////////////////////////////////////////////

local isSettingsVisible = false

-- Function to toggle the visibility of the settings panel
local function toggleSettingsView()
    isSettingsVisible = not isSettingsVisible
    containers.settingsContainer.Visible = isSettingsVisible
    containers.contentContainer.Visible = not isSettingsVisible
end

-- Connect the settings button from the WindowManager to our toggle function.
containers.settingsButton.MouseButton1Click:Connect(toggleSettingsView)

-- Connect tab creation/destruction signals to the ElementRenderer
Engine.Signals.TabAdded:Connect(function(tabData)
    -- This function creates the content page for the new tab.
    local page = ElementRenderer.CreateContentPage(tabData)
    
    -- We also need to add a button to the sidebar for this tab.
    local sidebar = containers.tabContainer
    local tabButton = Instance.new("TextButton")
    tabButton.Name = tabData.uniqueID
    tabButton.Parent = sidebar
    tabButton.LayoutOrder = #sidebar:GetChildren() -- Explicitly set layout order
    tabButton.Size = UDim2.new(1, -10, 0, 35) -- Add padding
    tabButton.Position = UDim2.new(0.5, 0, 0, 0)
    tabButton.AnchorPoint = Vector2.new(0.5, 0)
    tabButton.BackgroundColor3 = Color3.fromRGB(65, 65, 65) -- Slightly lighter for better contrast
    tabButton.Text = tabData.label
    tabButton.TextColor3 = Color3.fromRGB(230, 230, 230)
    tabButton.Font = Enum.Font.SourceSansSemibold
    tabButton.TextSize = 16
    tabButton.TextXAlignment = Enum.TextXAlignment.Center -- Center text
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = tabButton

    tabButton.MouseButton1Click:Connect(function()
        -- Hide all other pages
        for _, child in ipairs(containers.contentContainer:GetChildren()) do
            child.Visible = false
        end
        -- Show the correct page
        page.Visible = true
        
        -- Also hide the settings view if it's open
        if isSettingsVisible then
            toggleSettingsView()
        end
        
        -- Visual feedback for selection
        for _, btn in ipairs(sidebar:GetChildren()) do
            if btn:IsA("TextButton") then
                btn.BackgroundColor3 = Color3.fromRGB(65, 65, 65)
            end
        end
        tabButton.BackgroundColor3 = Color3.fromRGB(85, 125, 255) -- Highlight selected tab
    end)
end)

Engine.Signals.TabRemoved:Connect(function(tabID)
    -- Remove the content page
    ElementRenderer.DestroyContentPage(tabID)
    
    -- Remove the tab button from the sidebar
    local sidebar = containers.tabContainer
    local button = sidebar:FindFirstChild(tabID)
    if button then
        button:Destroy()
    end
end)

print("GUI System: Inter-module connections established.")

-- //////////////////////////////////////////////////////////////////////////////////
-- // 4. IMPLEMENT SAVE AND LOAD FUNCTIONALITY
-- //////////////////////////////////////////////////////////////////////////////////

-- Ensure the configuration folder exists
if not isfolder(CONFIG_FOLDER_NAME) then
    makefolder(CONFIG_FOLDER_NAME)
end
local configFilePath = CONFIG_FOLDER_NAME .. "/" .. CONFIG_FILE_NAME

local function saveConfiguration()
    local dataToSave = {
        Registry = Engine.Registry
        -- In the future, you could add ThemeSettings here too.
    }
    
    local success, encodedData = pcall(function()
        return HttpService:JSONEncode(dataToSave)
    end)
    
    if success then
        writefile(configFilePath, encodedData)
        Engine.API.Notify("System", "Configuration Saved!")
        print("GUI System: Configuration saved successfully.")
    else
        Engine.API.Notify("Error", "Failed to save configuration.")
        warn("GUI System: Failed to encode configuration:", encodedData)
    end
end

local function loadConfiguration()
    if not isfile(configFilePath) then
        print("GUI System: No configuration file found to load.")
        return
    end
    
    local fileContent = readfile(configFilePath)
    local success, decodedData = pcall(function()
        return HttpService:JSONDecode(fileContent)
    end)
    
    if success and decodedData and decodedData.Registry then
        -- Clear existing elements and tabs before loading
        -- Note: A more robust system might merge configs, but clearing is simpler.
        for _, tab in ipairs(Engine.Registry.Tabs) do
            Engine.Signals.TabRemoved:Fire(tab.uniqueID)
        end
        Engine.Registry.Tabs = {}
        Engine.Registry.Elements = {}
        
        -- Load new data
        for _, tabData in ipairs(decodedData.Registry.Tabs) do
            Engine.AddTab(tabData)
        end
        for _, elementData in pairs(decodedData.Registry.Elements) do
            Engine.AddElement(elementData)
        end
        Engine.API.Notify("System", "Configuration Loaded!")
        print("GUI System: Configuration loaded successfully.")
    else
        Engine.API.Notify("Error", "Failed to load configuration file. It may be corrupt.")
        warn("GUI System: Failed to decode configuration file:", decodedData)
    end
end

-- Connect the signals from the Engine to our functions
Engine.Signals.SaveRequested:Connect(saveConfiguration)
Engine.Signals.LoadRequested:Connect(loadConfiguration)

-- Automatically load configuration on startup
loadConfiguration()

print("GUI System: Ready.")

-- //////////////////////////////////////////////////////////////////////////////////
-- // 5. EXAMPLE / DEFAULT SETUP (Optional)
-- // You can remove this section if you want the GUI to start empty.
-- //////////////////////////////////////////////////////////////////////////////////

-- Check if the GUI is completely empty after loading
if #Engine.Registry.Tabs == 0 then
    print("GUI System: No config found. Creating a default setup.")
    
    -- Create a default tab
    local defaultTabData = { uniqueID = "main", label = "Main" }
    Engine.AddTab(defaultTabData)
    
    -- Create a button to save the configuration
    Engine.AddElement({
        uniqueID = "save_button",
        label = "Save Config",
        type = "Button",
        targetTabID = "main",
        properties = {},
        luaCode = [[
            API.Notify("System", "Saving configuration...")
            -- We can't call Engine.Save directly, so we use the signal.
            -- This is a placeholder as the Main script handles the actual saving.
            -- For a real use case, you might need a dedicated API call.
            -- For now, let's just make it a placeholder button.
            print("Save button pressed by user.")
        ]]
    })
    
    -- Make the first tab visible by default
    local mainContentPage = containers.contentContainer:FindFirstChild("main")
    if mainContentPage then
        mainContentPage.Visible = true
    end
end
