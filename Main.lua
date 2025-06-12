--[[
    Nexus-Lua Script: Rayfield Sidebar Modification (v5 - UI/UX Refinement)
    Description: Overhauled the UI for a professional look and feel. The sidebar now pushes
    content instead of overlapping it, the hamburger icon is custom-built, and tabs have a "selected" state.
]]

-- Load the Rayfield library
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- Create the main window.
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

local function FindRayfieldParent()
    if gethui and type(gethui) == "function" then
        return gethui()
    else
        return game:GetService("CoreGui")
    end
end

local CorrectParent = FindRayfieldParent()
local RayfieldGui = CorrectParent:WaitForChild("Rayfield", 15)

if not RayfieldGui then
    warn("Nexus-Lua: Could not find the Rayfield GUI after waiting. The script cannot continue.")
    return
end

local MainFrame = RayfieldGui:WaitForChild("Main")
local Topbar = MainFrame:WaitForChild("Topbar")
local ElementsContainer = MainFrame:WaitForChild("Elements")

-- Hide the default horizontal tab list
MainFrame.TabList.Visible = false
local sidebarWidth = 150

-- Create the sidebar frame
local SidebarFrame = Instance.new("Frame")
SidebarFrame.Name = "CustomSidebar"
SidebarFrame.Size = UDim2.new(0, sidebarWidth, 1, -45)
SidebarFrame.Position = UDim2.new(0, -sidebarWidth, 0, 45)
SidebarFrame.BackgroundColor3 = MainFrame.BackgroundColor3 -- Match main background
SidebarFrame.BorderSizePixel = 0
SidebarFrame.ZIndex = 99
SidebarFrame.Parent = MainFrame

local SidebarLayout = Instance.new("UIListLayout")
SidebarLayout.Padding = UDim.new(0, 5)
SidebarLayout.SortOrder = Enum.SortOrder.LayoutOrder
SidebarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
SidebarLayout.Parent = SidebarFrame

-- Add a stroke to the right side for separation
local SidebarStroke = Instance.new("Frame")
SidebarStroke.Name = "SidebarStroke"
SidebarStroke.Size = UDim2.new(0, 1, 1, 0)
SidebarStroke.Position = UDim2.new(1, 0, 0, 0)
SidebarStroke.BackgroundColor3 = Color3.fromRGB(0, 0, 0) -- Will be themed later
SidebarStroke.BorderSizePixel = 0
SidebarStroke.Parent = SidebarFrame

-- Create a custom, clean hamburger menu button
local HamburgerButton = Instance.new("TextButton")
HamburgerButton.Name = "HamburgerButton"
HamburgerButton.Size = UDim2.new(0, 32, 0, 32)
HamburgerButton.Position = UDim2.new(0, 10, 0.5, 0)
HamburgerButton.AnchorPoint = Vector2.new(0, 0.5)
HamburgerButton.Text = ""
HamburgerButton.BackgroundTransparency = 1
HamburgerButton.ZIndex = 101
HamburgerButton.Parent = Topbar

local function createHamburgerLine()
    local line = Instance.new("Frame")
    line.Size = UDim2.new(0.6, 0, 0, 3)
    line.AnchorPoint = Vector2.new(0.5, 0.5)
    line.BackgroundColor3 = Topbar.Title.TextColor3
    line.BorderSizePixel = 0
    line.Parent = HamburgerButton
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = line
    return line
end

local line1 = createHamburgerLine()
line1.Position = UDim2.new(0.5, 0, 0.5, -6)
local line2 = createHamburgerLine()
line2.Position = UDim2.new(0.5, 0, 0.5, 0)
local line3 = createHamburgerLine()
line3.Position = UDim2.new(0.5, 0, 0.5, 6)

-- Make the main title shift to the right
Topbar.Title.Position = UDim2.new(0, 50, 0.5, 0)
if Topbar:FindFirstChild("Icon") and Topbar.Icon.Visible then
    Topbar.Icon.Position = UDim2.new(0, 50, 0.5, 0)
    Topbar.Title.Position = UDim2.new(0, 90, 0.5, 0)
end


-- SECTION 2: FUNCTIONALITY

local isSidebarVisible = false
local activeTabButton = nil

-- This function now pushes the content container instead of overlapping it
local function ToggleSidebar(newState)
    isSidebarVisible = (newState == nil) and not isSidebarVisible or newState
    
    local sidebarGoal, contentGoal
    if isSidebarVisible then
        sidebarGoal = { Position = UDim2.new(0, 0, 0, 45) }
        contentGoal = { Position = UDim2.new(0, sidebarWidth, 0, 0) }
    else
        sidebarGoal = { Position = UDim2.new(0, -sidebarWidth, 0, 45) }
        contentGoal = { Position = UDim2.new(0, 0, 0, 0) }
    end
    
    local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
    TweenService:Create(SidebarFrame, tweenInfo, sidebarGoal):Play()
    TweenService:Create(ElementsContainer, tweenInfo, contentGoal):Play()
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
    TabButton.TextXAlignment = Enum.TextXAlignment.Left
    TabButton.Font = Enum.Font.GothamSemibold
    TabButton.TextSize = 16
    TabButton.Parent = SidebarFrame
    Instance.new("UICorner", TabButton)
    
    TabButton.MouseButton1Click:Connect(function()
        local pageToJumpTo = ElementsContainer:FindFirstChild(tabName)
        if pageToJumpTo then
            ElementsContainer.UIPageLayout:JumpTo(pageToJumpTo)
            
            -- Set new active button style
            if activeTabButton then
                activeTabButton.BackgroundColor3 = SidebarFrame.BackgroundColor3
            end
            activeTabButton = TabButton
            local theme = Rayfield.Theme[Window.Theme or "Default"] or Rayfield.Theme.Default
            activeTabButton.BackgroundColor3 = theme.ElementBackgroundHover

            ToggleSidebar(false)
        end
    end)
    
    -- Set the first tab created as the active one by default
    if not activeTabButton then
       activeTabButton = TabButton
       task.wait(0.2) -- wait for theme to load
       local theme = Rayfield.Theme[Window.Theme or "Default"] or Rayfield.Theme.Default
       activeTabButton.BackgroundColor3 = theme.ElementBackgroundHover
    end

    return Tab
end

local function SyncTheme()
    task.wait(0.1) 
    local currentThemeName = Window.Theme or "Default"
    local theme = Rayfield.Theme[currentThemeName] or Rayfield.Theme.Default

    SidebarFrame.BackgroundColor3 = theme.Background
    SidebarStroke.BackgroundColor3 = theme.ElementStroke
    
    -- Update hamburger icon lines
    for _, child in ipairs(HamburgerButton:GetChildren()) do
        if child:IsA("Frame") then child.BackgroundColor3 = theme.TextColor end
    end
    
    -- Update buttons, including the active one
    for _, child in pairs(SidebarFrame:GetChildren()) do
        if child:IsA("TextButton") then
            child.TextColor3 = theme.TextColor
            if child == activeTabButton then
                child.BackgroundColor3 = theme.ElementBackgroundHover
            else
                child.BackgroundColor3 = theme.Background
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
MainTab:CreateParagraph({Title = "UI Refined", Content = "The sidebar now pushes content, the hamburger icon is clean, and the active tab is highlighted."})
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
