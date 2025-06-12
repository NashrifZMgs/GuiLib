--[[
    Demonstration Script for the Modified Rayfield Library
    Created by Nexus-Lua for the Master.
    
    This script showcases the new sidebar layout, the hamburger menu,
    and confirms that all original elements are functional.
]]

-- Step 1: Load your modified Rayfield library from the specified URL
local Rayfield = loadstring(game:HttpGet('https://raw.githubusercontent.com/NashrifZMgs/GuiLib/refs/heads/main/RayfieldModify.lua'))()

-- Step 2: Create the Main Window
-- I have enabled ConfigurationSaving to test its functionality with the new layout.
local Window = Rayfield:CreateWindow({
   Name = "Sidebar UI Demo",
   Icon = "layout-dashboard",
   LoadingTitle = "Rayfield Sidebar Demo",
   LoadingSubtitle = "Nexus-Lua Edition",
   Theme = "DarkBlue",
   ConfigurationSaving = {
      Enabled = true,
      FolderName = "NexusLuaDemos",
      FileName = "SidebarDemoConfig"
   }
})

-- Step 3: Create Vertical Tabs
-- These will now appear in the new sidebar on the left.
local TabHome = Window:CreateTab("Home", "home")
local TabElements = Window:CreateTab("Elements", "toy-brick")
local TabMisc = Window:CreateTab("Misc", "list")

-- Step 4: Populate the Tabs with Elements

-- == Home Tab: Information and Instructions ==
TabHome:CreateSection("Welcome, Master")

TabHome:CreateParagraph({
    Title = "New Sidebar Interface",
    Content = "This is a demonstration of the modified Rayfield UI.\n\nUse the hamburger menu icon (☰) in the top-left corner to hide or show the sidebar navigation panel. All tabs will now appear here."
})

TabHome:CreateParagraph({
    Title = "How to Destroy the GUI",
    Content = "The 'Destroy GUI' button is now located within the settings panel.\n\nClick the gear icon (⚙️) on the top bar, and you will find the button under the 'Actions' section."
})

-- == Elements Tab: Testing Core Interactive Elements ==
TabElements:CreateSection("Standard Elements")

TabElements:CreateButton({
   Name = "Send Notification",
   Callback = function()
        Rayfield:Notify({
           Title = "Notification Test",
           Content = "All elements are working correctly.",
           Duration = 5,
           Image = "check-circle",
        })
   end,
})

TabElements:CreateToggle({
   Name = "Example Toggle",
   CurrentValue = false,
   Flag = "DemoToggle", -- Flag for configuration saving
   Callback = function(Value)
        print("Toggle State:", Value)
   end,
})

TabElements:CreateSlider({
   Name = "Example Slider",
   Range = {0, 100},
   Increment = 10,
   Suffix = "%",
   CurrentValue = 50,
   Flag = "DemoSlider", -- Flag for configuration saving
   Callback = function(Value)
        print("Slider Value:", Value)
   end,
})

TabElements:CreateColorPicker({
    Name = "Example Color Picker",
    Color = Color3.fromRGB(0, 150, 255),
    Flag = "DemoColor", -- Flag for configuration saving
    Callback = function(Value)
        print("Color3 Picked:", Value)
    end
})

-- == Misc Tab: Testing Other Elements ==
TabMisc:CreateSection("Miscellaneous Elements")

TabMisc:CreateInput({
   Name = "Example Input",
   PlaceholderText = "Type something here...",
   Flag = "DemoInput", -- Flag for configuration saving
   Callback = function(Text)
        print("Input Changed:", Text)
   end,
})

-- Dynamically create a list of themes for the dropdown
local availableThemes = {}
for themeName, _ in pairs(Rayfield.Theme) do
    table.insert(availableThemes, themeName)
end

TabMisc:CreateDropdown({
   Name = "UI Theme Selector",
   Options = availableThemes,
   CurrentOption = {"DarkBlue"},
   Flag = "DemoThemeDropdown", -- Flag for configuration saving
   Callback = function(Options)
        -- The callback returns a table, we only need the first value
        local selectedTheme = Options[1]
        if selectedTheme then
            Window.ModifyTheme(selectedTheme)
            print("Theme changed to:", selectedTheme)
        end
   end,
})

TabMisc:CreateKeybind({
   Name = "Example Keybind",
   CurrentKeybind = "F",
   Flag = "DemoKeybind", -- Flag for configuration saving
   Callback = function()
        Rayfield:Notify({Title = "Keybind Pressed!", Content = "The keybind 'F' was pressed.", Image = "keyboard"})
   end,
})

-- Step 5: Finalize and Load Configuration
-- This must be at the end of the script to load saved values for all created elements.
Rayfield:LoadConfiguration()
