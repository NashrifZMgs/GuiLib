--[[
    Nexus-Lua Script: Rayfield Sidebar Modification
    Description: This script modifies the Rayfield UI to use a collapsible sidebar for tab navigation,
    optimizing it for mobile and touchscreen devices.
]]

-- Load the Rayfield library
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- Create the main window. You can customize these settings as you wish.
local Window = Rayfield:CreateWindow({
    Name = "Mobile-Optimized UI",
    LoadingTitle = "Nexus-Lua Scripts",
    LoadingSubtitle = "by your Master",
    Theme = "Default",
    ConfigurationSaving = {
        Enabled = false -- Keep false unless you plan to add savable elements
    }
})

-- SECTION 1: UI MODIFICATION
-- We wait for a brief moment to ensure all Rayfield objects are loaded before we modify them.
task.wait(0.1)

local TweenService = game:GetService("TweenService")
local MainFrame = Rayfield.Main
local Topbar = MainFrame.Topbar
local ElementsContainer = MainFrame.Elements

-- Hide the default horizontal tab list
MainFrame.TabList.Visible = false

-- Create the sidebar frame
local SidebarFrame = Instance.new("Frame")
SidebarFrame.Name = "CustomSidebar"
SidebarFrame.Size = UDim2.new(0, 150, 1, -45) -- Full height minus topbar
SidebarFrame.Position = UDim2.new(0, -150, 0, 45) -- Start off-screen
SidebarFrame.BackgroundColor3 = MainFrame.BackgroundColor3
SidebarFrame.BorderSizePixel = 0
SidebarFrame.ZIndex = 99
SidebarFrame.Parent = MainFrame

-- Add a list layout to the sidebar for the buttons
local SidebarLayout = Instance.new("UIListLayout")
SidebarLayout.Padding = Pading.new(0, 5)
SidebarLayout.SortOrder = Enum.SortOrder.LayoutOrder
SidebarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
SidebarLayout.Parent = SidebarFrame

-- Create the hamburger menu button
local HamburgerButton = Instance.new("ImageButton")
HamburgerButton.Name = "HamburgerButton"
HamburgerButton.Size = UDim2.new(0, 30, 0, 30)
HamburgerButton.Position = UDim2.new(0, 10, 0.5, 0)
HamburgerButton.AnchorPoint = Vector2.new(0, 0.5)
HamburgerButton.Image = "http://www.roblox.com/asset/?id=5917039534" -- A generic, free-to-use hamburger icon
HamburgerButton.ImageColor3 = Topbar.Title.TextColor3
HamburgerButton.BackgroundTransparency = 1
HamburgerButton.ZIndex = 101
HamburgerButton.Parent = Topbar

-- Make the main title shift to the right to make space for the hamburger icon
Topbar.Title.Position = UDim2.new(0, 50, 0.5, 0)
if Topbar:FindFirstChild("Icon") then
    Topbar.Icon.Position = UDim2.new(0, 50, 0.5, 0)
    Topbar.Title.Position = UDim2.new(0, 90, 0.5, 0)
end


-- SECTION 2: FUNCTIONALITY

local isSidebarVisible = false

-- Function to animate the sidebar in and out
local function ToggleSidebar(newState)
    isSidebarVisible = (newState == nil) and not isSidebarVisible or newState
    
    local goalPosition
    if isSidebarVisible then
        goalPosition = UDim2.new(0, 0, 0, 45) -- On-screen
    else
        goalPosition = UDim2.new(0, -150, 0, 45) -- Off-screen
    end
    
    local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
    local tween = TweenService:Create(SidebarFrame, tweenInfo, { Position = goalPosition })
    tween:Play()
end

-- Connect the hamburger button to the toggle function
HamburgerButton.MouseButton1Click:Connect(function()
    ToggleSidebar()
end)

-- This new function will create a Rayfield tab AND a corresponding button in our new sidebar
function Window:CreateSidebarTab(tabName, icon)
    -- This first part creates the actual tab page where elements will go.
    -- We are "wrapping" the original function.
    local Tab = Window:CreateTab(tabName, icon)

    -- This second part creates our custom button for the sidebar.
    local TabButton = Instance.new("TextButton")
    TabButton.Name = tabName .. "Button"
    TabButton.Text = " " .. tabName
    TabButton.Size = UDim2.new(0.9, 0, 0, 35)
    TabButton.BackgroundColor3 = MainFrame.BackgroundColor3
    TabButton.TextColor3 = Topbar.Title.TextColor3
    TabButton.TextXAlignment = Enum.TextXAlignment.Left
    TabButton.Font = Enum.Font.GothamSemibold
    TabButton.TextSize = 16
    TabButton.Parent = SidebarFrame

    local Stroke = Instance.new("UIStroke")
    Stroke.Color = Color3.fromRGB(60, 60, 60)
    Stroke.Thickness = 1
    Stroke.Parent = TabButton
    
    -- Interaction animations for the button
    TabButton.MouseEnter:Connect(function()
        TweenService:Create(TabButton, TweenInfo.new(0.2), { BackgroundColor3 = Color3.fromRGB(60, 60, 60) }):Play()
    end)
    TabButton.MouseLeave:Connect(function()
        TweenService:Create(TabButton, TweenInfo.new(0.2), { BackgroundColor3 = MainFrame.BackgroundColor3 }):Play()
    end)
    
    -- Main logic: When a sidebar button is clicked...
    TabButton.MouseButton1Click:Connect(function()
        -- Find the correct content page inside Rayfield's structure
        local pageToJumpTo = ElementsContainer:FindFirstChild(tabName)
        if pageToJumpTo then
            -- Tell Rayfield to switch to that page
            ElementsContainer.UIPageLayout:JumpTo(pageToJumpTo)
            
            -- Automatically hide the sidebar for a smooth experience
            ToggleSidebar(false)
        end
    end)

    -- Return the Tab object so you can still add elements to it like normal
    return Tab
end

-- Function to keep the custom UI elements matching the theme if it changes
local function SyncTheme()
    local theme = Rayfield.Theme[Window.Theme] or Rayfield.Theme.Default
    SidebarFrame.BackgroundColor3 = theme.Background
    HamburgerButton.ImageColor3 = theme.TextColor
    for _, button in pairs(SidebarFrame:GetChildren()) do
        if button:IsA("TextButton") then
            button.BackgroundColor3 = theme.Background
            button.TextColor3 = theme.TextColor
            button.UIStroke.Color = theme.ElementStroke
        end
    end
end

-- We will override the ModifyTheme function to also update our custom elements
local oldModifyTheme = Window.ModifyTheme
function Window.ModifyTheme(newTheme)
    oldModifyTheme(newTheme)
    Window.Theme = type(newTheme) == "string" and newTheme or "Custom"
    task.wait(0.1)
    SyncTheme()
end

-- Call it once to set the initial colors
SyncTheme()


-- SECTION 3: YOUR SCRIPT CONTENT
-- Now, instead of Window:CreateTab, you use Window:CreateSidebarTab

-- Example Tab 1: Main
local MainTab = Window:CreateSidebarTab("Main", "home")

MainTab:CreateLabel("Welcome, Master.")
MainTab:CreateParagraph({Title = "Sidebar UI", Content = "This is a mobile-friendly sidebar layout. Click the hamburger icon to open and close it."})

local Button = MainTab:CreateButton({
    Name = "Notify Me",
    Callback = function()
        Rayfield:Notify({
            Title = "Master's Command",
            Content = "The button was pressed successfully.",
            Duration = 5,
            Image = "check-circle"
        })
    end,
})

-- Example Tab 2: Settings
local SettingsTab = Window:CreateSidebarTab("Settings", "settings")
SettingsTab:CreateSection("Theme Settings")

local themeOptions = {}
for themeName, _ in pairs(Rayfield.Theme) do
    table.insert(themeOptions, themeName)
end

local Dropdown = SettingsTab:CreateDropdown({
    Name = "Change Theme",
    Options = themeOptions,
    CurrentOption = {"Default"},
    MultipleOptions = false,
    Callback = function(options)
        Window:ModifyTheme(options[1])
    end,
})

-- Example Tab 3: Credits
local CreditsTab = Window:CreateSidebarTab("Credits", "users")
CreditsTab:CreateLabel("Script by Nexus-Lua")
CreditsTab:CreateLabel("UI by Rayfield")
