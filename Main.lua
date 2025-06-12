--[[
    Nexus-Lua Script: Rayfield Sidebar Modification (v3 - Executor Aware)
    Description: This script reliably finds the Rayfield UI by checking the same locations
    the library does, preventing "Infinite Yield" errors on mobile executors.
]]

-- Load the Rayfield library
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- Create the main window. You can customize these settings as you wish.
local Window = Rayfield:CreateWindow({
    Name = "Mobile-Optimized UI",
    LoadingTitle = "Nexus-Lua Scripts",
    LoadingSubtitle = "by your Master",
    Theme = "DarkBlue",
    ConfigurationSaving = {
        Enabled = false
    }
})

-- SECTION 1: RELIABLE UI FINDING & MODIFICATION

local TweenService = game:GetService("TweenService")

-- This function finds the correct parent for the Rayfield GUI, just like the library does.
local function FindRayfieldParent()
    if gethui and type(gethui) == "function" then
        return gethui() -- Use the special UI parent on mobile executors
    else
        return game:GetService("CoreGui") -- Fallback for other executors
    end
end

local CorrectParent = FindRayfieldParent()

-- We now wait for the Rayfield GUI to appear in the CORRECT parent location.
local RayfieldGui = CorrectParent:WaitForChild("Rayfield", 15) -- Wait up to 15 seconds

-- If the GUI is still not found after waiting, we stop the script to prevent further errors.
if not RayfieldGui then
    warn("Nexus-Lua: Could not find the Rayfield GUI after waiting. The script cannot continue.")
    return
end

-- Now that we have the GUI, we can safely get the other parts.
local MainFrame = RayfieldGui:WaitForChild("Main")
local Topbar = MainFrame:WaitForChild("Topbar")
local ElementsContainer = MainFrame:WaitForChild("Elements")

-- Hide the default horizontal tab list
MainFrame.TabList.Visible = false

-- Create the sidebar frame
local SidebarFrame = Instance.new("Frame")
SidebarFrame.Name = "CustomSidebar"
SidebarFrame.Size = UDim2.new(0, 150, 1, -45) -- Full height minus topbar
SidebarFrame.Position = UDim2.new(0, -150, 0, 45) -- Start off-screen
SidebarFrame.BackgroundColor3 = Topbar.BackgroundColor3
SidebarFrame.BorderSizePixel = 0
SidebarFrame.ZIndex = 99
SidebarFrame.Parent = MainFrame

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
HamburgerButton.Image = "http://www.roblox.com/asset/?id=5917039534"
HamburgerButton.ImageColor3 = Topbar.Title.TextColor3
HamburgerButton.BackgroundTransparency = 1
HamburgerButton.ZIndex = 101
HamburgerButton.Parent = Topbar

-- Make the main title shift to the right
Topbar.Title.Position = UDim2.new(0, 50, 0.5, 0)
if Topbar:FindFirstChild("Icon") and Topbar.Icon.Visible then
    Topbar.Icon.Position = UDim2.new(0, 50, 0.5, 0)
    Topbar.Title.Position = UDim2.new(0, 90, 0.5, 0)
end


-- SECTION 2: FUNCTIONALITY

local isSidebarVisible = false

local function ToggleSidebar(newState)
    isSidebarVisible = (newState == nil) and not isSidebarVisible or newState
    local goalPosition = isSidebarVisible and UDim2.new(0, 0, 0, 45) or UDim2.new(0, -150, 0, 45)
    local tween = TweenService:Create(SidebarFrame, TweenInfo.new(0.3, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), { Position = goalPosition })
    tween:Play()
end

HamburgerButton.MouseButton1Click:Connect(function()
    ToggleSidebar()
end)

function Window:CreateSidebarTab(tabName, icon)
    local Tab = Window:CreateTab(tabName, icon)
    local TabButton = Instance.new("TextButton")
    TabButton.Name = tabName .. "Button"
    TabButton.Text = " " .. tabName
    TabButton.Size = UDim2.new(0.9, 0, 0, 35)
    TabButton.BackgroundColor3 = SidebarFrame.BackgroundColor3
    TabButton.TextColor3 = Topbar.Title.TextColor3
    TabButton.TextXAlignment = Enum.TextXAlignment.Left
    TabButton.Font = Enum.Font.GothamSemibold
    TabButton.TextSize = 16
    TabButton.Parent = SidebarFrame

    local Stroke = Instance.new("UIStroke")
    Stroke.Color = Color3.fromRGB(60, 60, 60)
    Stroke.Thickness = 1
    Stroke.Parent = TabButton
    
    TabButton.MouseEnter:Connect(function()
        TweenService:Create(TabButton, TweenInfo.new(0.2), { BackgroundColor3 = Color3.fromRGB(80, 80, 80) }):Play()
    end)
    TabButton.MouseLeave:Connect(function()
        TweenService:Create(TabButton, TweenInfo.new(0.2), { BackgroundColor3 = SidebarFrame.BackgroundColor3 }):Play()
    end)
    
    TabButton.MouseButton1Click:Connect(function()
        local pageToJumpTo = ElementsContainer:FindFirstChild(tabName)
        if pageToJumpTo then
            ElementsContainer.UIPageLayout:JumpTo(pageToJumpTo)
            ToggleSidebar(false)
        end
    end)

    return Tab
end

local function SyncTheme()
    task.wait(0.1) -- Delay to ensure Window.Theme has updated
    local currentThemeName = Window.Theme or "Default"
    local theme = Rayfield.Theme[currentThemeName] or Rayfield.Theme.Default

    SidebarFrame.BackgroundColor3 = theme.Topbar
    HamburgerButton.ImageColor3 = theme.TextColor
    for _, child in pairs(SidebarFrame:GetChildren()) do
        if child:IsA("TextButton") then
            child.BackgroundColor3 = theme.Topbar
            child.TextColor3 = theme.TextColor
            if child:FindFirstChildOfClass("UIStroke") then
                child.UIStroke.Color = theme.ElementStroke
            end
        end
    end
end

local oldModifyTheme = Window.ModifyTheme
function Window.ModifyTheme(newTheme)
    oldModifyTheme(newTheme)
    Window.Theme = type(newTheme) == "string" and newTheme or "Custom"
    SyncTheme()
end

SyncTheme()


-- SECTION 3: YOUR SCRIPT CONTENT

local MainTab = Window:CreateSidebarTab("Main", "home")
MainTab:CreateLabel("Welcome, Master.")
MainTab:CreateParagraph({Title = "Sidebar UI", Content = "This script is now fully functional on your executor."})
MainTab:CreateButton({
    Name = "Notify Me",
    Callback = function()
        Rayfield:Notify({Title = "Success", Content = "The button was pressed.", Duration = 5, Image = "check-circle"})
    end,
})

local SettingsTab = Window:CreateSidebarTab("Settings", "settings")
local themeOptions = {}
for themeName, _ in pairs(Rayfield.Theme) do table.insert(themeOptions, themeName) end
SettingsTab:CreateDropdown({
    Name = "Change Theme",
    Options = themeOptions,
    CurrentOption = {"DarkBlue"},
    Callback = function(options) Window:ModifyTheme(options[1]) end,
})
