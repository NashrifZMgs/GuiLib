--[[
    Nexus-Lua Script: Example for Native Sidebar Rayfield
    Description: This script loads and uses the Rayfield library with the built-in sidebar
    to demonstrate its functionality.
]]

-- Load your custom, pre-modified Rayfield library from the provided URL
local Rayfield = loadstring(game:HttpGet('https://raw.githubusercontent.com/NashrifZMgs/GuiLib/refs/heads/main/RayfieldModify.lua'))()

-- Create the main window. All the sidebar logic is now handled internally by the library.
local Window = Rayfield:CreateWindow({
    Name = "Master's UI",
    LoadingTitle = "Loading Script...",
    LoadingSubtitle = "Please Wait",
    Theme = "DarkBlue" -- You can set any theme here: Default, Amethyst, Ocean, etc.
})

-- Since the sidebar is now built-in, we just use Window:CreateTab as normal.
-- The library will automatically handle creating the sidebar buttons.

-- Tab 1: Main Features
local MainTab = Window:CreateTab("Main", "home")

MainTab:CreateSection("Core Functions")

MainTab:CreateLabel("This UI now has a native sidebar.")

MainTab:CreateButton({
    Name = "Example Notification",
    Callback = function()
        Rayfield:Notify({
            Title = "Success",
            Content = "The button was pressed as commanded.",
            Duration = 5,
            Image = "check-circle"
        })
    end,
})

MainTab:CreateToggle({
    Name = "Example Toggle",
    CurrentValue = false,
    Flag = "MainToggle", -- Flags are for configuration saving if you enable it
    Callback = function(Value)
        print("Toggle is now:", Value)
    end,
})


-- Tab 2: Settings
local SettingsTab = Window:CreateTab("Settings", "settings")

SettingsTab:CreateSection("UI Customization")

-- Create a list of all available themes to put in the dropdown
local themeOptions = {}
for themeName, _ in pairs(Rayfield.Theme) do
    table.insert(themeOptions, themeName)
end

SettingsTab:CreateDropdown({
    Name = "Change Theme",
    Options = themeOptions,
    CurrentOption = {"DarkBlue"}, -- Match the initial theme
    Callback = function(options)
        -- The Window:ModifyTheme function is part of the library and will update everything
        Window:ModifyTheme(options[1])
    end,
})

SettingsTab:CreateSlider({
    Name = "Example Slider",
    Range = {0, 100},
    Increment = 10,
    Suffix = "%",
    CurrentValue = 50,
    Flag = "MainSlider",
    Callback = function(Value)
        print("Slider is now at:", Value)
    end,
})


-- Tab 3: Credits
local CreditsTab = Window:CreateTab("Credits", "users")

CreditsTab:CreateSection("Acknowledgements")
CreditsTab:CreateLabel("Script created for the Master.")
CreditsTab:CreateParagraph({
    Title = "UI Library",
    Content = "This UI was built using a version of the Rayfield Interface Suite, modified to perfection by Nexus-Lua under the Master's command."
})
