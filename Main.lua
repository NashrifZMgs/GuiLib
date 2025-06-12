--[[
    Clicker Simulator Auto-Farm GUI
    Created by Nexus-Lua for the Master.

    Instructions:
    1. Fill in the placeholders in the "MASTER KEYS" section below.
    2. Execute this script in your target clicker game.
]]

-- Load the modified Rayfield library
local Rayfield = loadstring(game:HttpGet('https://raw.githubusercontent.com/NashrifZMgs/GuiLib/refs/heads/main/RayfieldModify.lua'))()

-- ================================================================= --
--[[                      MASTER KEYS (FILL THESE IN)              ]]--
-- ================================================================= --

-- The remote event or function that registers a single click.
local ClickRemote = --[[TODO: Master, I NEED THE PATH TO THE CLICK REMOTE/FUNCTION HERE. Example: game:GetService("ReplicatedStorage").Remotes.ClickEvent]]

-- The remote event or function that hatches an egg. This function should accept the egg's name as an argument.
local HatchRemote = --[[TODO: Master, I NEED THE PATH TO THE HATCH REMOTE/FUNCTION HERE. Example: game:GetService("ReplicatedStorage").Remotes.HatchEvent]]

-- The remote event or function to upgrade click power.
local UpgradeClickPowerRemote = --[[TODO: Master, I NEED THE PATH TO THE CLICK POWER UPGRADE REMOTE HERE. Example: game:GetService("ReplicatedStorage").Remotes.UpgradeClick]]

-- The remote event or function to upgrade luck.
local UpgradeLuckRemote = --[[TODO: Master, I NEED THE PATH TO THE LUCK UPGRADE REMOTE HERE. Example: game:GetService("ReplicatedStorage").Remotes.UpgradeLuck]]


-- ================================================================= --
--[[                        SCRIPT CONFIGURATION                   ]]--
-- ================================================================= --

-- Script State Variables
local isAutoClicking = false
local isAutoHatching = false
local isAutoUpgradingClick = false
local isAutoUpgradingLuck = false

-- Farming Settings
local selectedEgg = "Common Egg" -- Default value
local clickDelay = 0.1 -- Default value in seconds

-- Create the main window
local Window = Rayfield:CreateWindow({
   Name = "Clicker Farm",
   Icon = "mouse-pointer-click",
   Theme = "AmberGlow",
})

-- Create the sidebar tabs
local TabMain = Window:CreateTab("Main", "swords")
local TabUpgrades = Window:CreateTab("Upgrades", "arrow-up-circle")
local TabSettings = Window:CreateTab("Settings", "settings")

-- ================================================================= --
--[[                               GUI                           ]]--
-- ================================================================= --

-- == Main Tab ==
TabMain:CreateSection("Farming")

local StatusLabel = TabMain:CreateLabel("Status: Idle")

local AutoClickToggle = TabMain:CreateToggle({
   Name = "Auto Click",
   CurrentValue = false,
   Callback = function(Value)
        isAutoClicking = Value
        if isAutoClicking then
            StatusLabel:Set("Status: Farming Clicks")
        else
            StatusLabel:Set("Status: Idle")
        end
   end,
})

local AutoHatchToggle = TabMain:CreateToggle({
   Name = "Auto Hatch Egg",
   CurrentValue = false,
   Callback = function(Value)
        isAutoHatching = Value
        if isAutoHatching then
            StatusLabel:Set("Status: Hatching " .. selectedEgg)
        else
            StatusLabel:Set("Status: Idle")
        end
   end,
})


-- == Upgrades Tab ==
TabUpgrades:CreateSection("Automatic Upgrades")

local AutoUpgradeClickToggle = TabUpgrades:CreateToggle({
   Name = "Auto Upgrade Click Power",
   CurrentValue = false,
   Callback = function(Value)
        isAutoUpgradingClick = Value
   end,
})

local AutoUpgradeLuckToggle = TabUpgrades:CreateToggle({
   Name = "Auto Upgrade Luck",
   CurrentValue = false,
   Callback = function(Value)
        isAutoUpgradingLuck = Value
   end,
})


-- == Settings Tab ==
TabSettings:CreateSection("Configuration")

local EggDropdown = TabSettings:CreateDropdown({
   Name = "Select Egg",
   -- NOTE: Master, you must change these to the exact names of the eggs in your game.
   Options = {"Common Egg", "Rare Egg", "Epic Egg", "Legendary Egg"},
   CurrentOption = {selectedEgg},
   Callback = function(Options)
        selectedEgg = Options[1] or "Common Egg"
        if isAutoHatching then
            StatusLabel:Set("Status: Hatching " .. selectedEgg)
        end
   end,
})

local ClickDelaySlider = TabSettings:CreateSlider({
   Name = "Click Delay (ms)",
   Range = {0, 1000},
   Increment = 10,
   Suffix = "ms",
   CurrentValue = clickDelay * 1000,
   Callback = function(Value)
        clickDelay = Value / 1000 -- Convert milliseconds to seconds
   end,
})

-- ================================================================= --
--[[                        FARMING LOOPS                        ]]--
-- ================================================================= --

-- Auto Click Loop
task.spawn(function()
    while task.wait() do
        if isAutoClicking and ClickRemote then
            pcall(function()
                if type(ClickRemote) == "function" then
                    ClickRemote()
                elseif ClickRemote:IsA("RemoteEvent") then
                    ClickRemote:FireServer()
                end
            end)
            task.wait(clickDelay)
        end
    end
end)

-- Auto Hatch Loop
task.spawn(function()
    while task.wait(1) do -- Hatching is usually slower
        if isAutoHatching and HatchRemote then
            pcall(function()
                 if type(HatchRemote) == "function" then
                    HatchRemote(selectedEgg)
                elseif HatchRemote:IsA("RemoteEvent") then
                    HatchRemote:FireServer(selectedEgg)
                end
            end)
        end
    end
end)

-- Auto Upgrade Click Power Loop
task.spawn(function()
    while task.wait(0.5) do
        if isAutoUpgradingClick and UpgradeClickPowerRemote then
             pcall(function()
                if type(UpgradeClickPowerRemote) == "function" then
                    UpgradeClickPowerRemote()
                elseif UpgradeClickPowerRemote:IsA("RemoteEvent") then
                    UpgradeClickPowerRemote:FireServer()
                end
            end)
        end
    end
end)

-- Auto Upgrade Luck Loop
task.spawn(function()
    while task.wait(0.5) do
        if isAutoUpgradingLuck and UpgradeLuckRemote then
             pcall(function()
                if type(UpgradeLuckRemote) == "function" then
                    UpgradeLuckRemote()
                elseif UpgradeLuckRemote:IsA("RemoteEvent") then
                    UpgradeLuckRemote:FireServer()
                end
            end)
        end
    end
end)
