--[[
    Nexus-Lua GUI System | Phase 4: The Settings Panel
    Purpose: Builds the UI for creating, editing, and managing tabs and elements.
    This is the command center for the user to build their own GUI.
]]

local SettingsPanel = {}

-- Module State
local Engine
local settingsContainer -- The parent frame provided by WindowManager
local activeEditElementID = nil
local elementTypes = {"Button", "Toggle", "Slider", "Dropdown"}

-- Configuration
local SECTION_PADDING = 15
local INPUT_HEIGHT = 30
local THEME_DEFAULTS = {
    Text = Color3.fromRGB(240, 240, 240),
    Subtle = Color3.fromRGB(40, 40, 40),
    Accent = Color3.fromRGB(85, 125, 255),
    Destructive = Color3.fromRGB(180, 70, 70),
}

-- //////////////////////////////////////////////////////////////////////////////////
-- // 1. UTILITIES
-- //////////////////////////////////////////////////////////////////////////////////

local function create(instanceType, properties)
    local inst = Instance.new(instanceType)
    for prop, value in pairs(properties or {}) do
        inst[prop] = value
    end
    return inst
end

local function createSection(name, parent)
    local frame = create("Frame", {
        Name = name .. "Section",
        Parent = parent,
        BackgroundTransparency = 1,
        AutomaticSize = Enum.AutomaticSize.Y,
        Size = UDim2.new(1, 0, 0, 0), -- Placeholder size
    })
    
    local listLayout = create("UIListLayout", {
        Parent = frame,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 8),
    })
    
    create("TextLabel", {
        Name = "Header",
        Parent = frame,
        Size = UDim2.new(1, 0, 0, 25),
        Text = name,
        Font = Enum.Font.SourceSansBold,
        TextSize = 20,
        TextColor3 = THEME_DEFAULTS.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    
    create("Frame", { Name="Divider", Parent=frame, Size=UDim2.new(1,0,0,1), BackgroundColor3=THEME_DEFAULTS.Subtle, BorderSizePixel=0 })

    return frame, listLayout
end

local function createTextButton(text, parent)
     local btn = create("TextButton", {
        Name = text, Parent = parent, Size = UDim2.new(0, 150, 0, 35), BackgroundColor3 = THEME_DEFAULTS.Accent,
        Text = text, TextColor3 = Color3.fromRGB(255, 255, 255), Font = Enum.Font.SourceSansSemibold, TextSize = 16,
    })
    create("UICorner", { CornerRadius = UDim.new(0, 4), Parent = btn })
    return btn
end

local function createTextInput(placeholder, parent)
    local frame = create("Frame", {
        Name = placeholder .. "InputFrame", Parent = parent, Size = UDim2.new(1, 0, 0, INPUT_HEIGHT),
        BackgroundColor3 = THEME_DEFAULTS.Subtle, BorderSizePixel = 0,
    })
    create("UICorner", { CornerRadius = UDim.new(0, 4), Parent = frame })

    local textBox = create("TextBox", {
        Name = "Input", Parent = frame, Size = UDim2.new(1, -20, 1, 0), Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, PlaceholderText = placeholder,
        PlaceholderColor3 = Color3.fromRGB(150, 150, 150), Text = "", TextColor3 = Color3.fromRGB(220, 220, 220),
        Font = Enum.Font.SourceSans, TextSize = 14, ClearTextOnFocus = false,
    })
    return frame, textBox
end


-- //////////////////////////////////////////////////////////////////////////////////
-- // 2. TAB MANAGER
-- //////////////////////////////////////////////////////////////////////////////////

local function buildTabManager(parent)
    local section, layout = createSection("Tab Manager", parent)
    
    local _, tabNameInput = createTextInput("New Tab Name", section)
    local addTabBtn = createTextButton("Add Tab", section)

    addTabBtn.MouseButton1Click:Connect(function()
        local name = tabNameInput.Text
        if name and name:match("%S") then
            Engine.AddTab({
                uniqueID = name:lower():gsub("%s+", "_"),
                label = name,
            })
            tabNameInput.Text = ""
        end
    end)
    
    -- Dynamically add/remove tab management rows
    local function addTabRow(tabData)
        local row = create("Frame", {Name=tabData.uniqueID, Parent=section, Size=UDim2.new(1,0,0,30), BackgroundTransparency=1})
        create("TextLabel", {Parent=row, Size=UDim2.new(0.7,0,1,0), Text=tabData.label, TextColor3=THEME_DEFAULTS.Text, TextXAlignment=Enum.TextXAlignment.Left})
        local removeBtn = createTextButton("Remove", row)
        removeBtn.Size, removeBtn.Position, removeBtn.AnchorPoint = UDim2.new(0.2,0,1,0), UDim2.new(1,0,0.5,0), Vector2.new(1,0.5)
        removeBtn.BackgroundColor3 = THEME_DEFAULTS.Destructive
        removeBtn.MouseButton1Click:Connect(function() Engine.RemoveTab(tabData.uniqueID) end)
    end
    
    Engine.Signals.TabAdded:Connect(addTabRow)
    Engine.Signals.TabRemoved:Connect(function(tabID) if section:FindFirstChild(tabID) then section[tabID]:Destroy() end end)
    
    for _, tabData in ipairs(Engine.Registry.Tabs) do addTabRow(tabData) end
end

-- //////////////////////////////////////////////////////////////////////////////////
-- // 3. ELEMENT MANAGER
-- //////////////////////////////////////////////////////////////////////////////////

local editPanel, editPanelLayout
local elementListLayout -- Layout for the master list of elements

local function clearEditPanel()
    for _, child in ipairs(editPanel:GetChildren()) do
        if child.Name ~= "Header" and child.Name ~= "Divider" then child:Destroy() end
    end
    editPanel.Visible = false
    activeEditElementID = nil
end

local function populateEditPanel(elementData)
    clearEditPanel()

    elementData = elementData or {}
    local props = elementData.properties or {}

    -- Step 1: Identity
    local _, nameInput = createTextInput("Display Name", editPanel)
    nameInput.Text = elementData.label or ""

    local _, idInput = createTextInput("Unique ID (no spaces)", editPanel)
    idInput.Text = elementData.uniqueID or ""
    
    -- Element Type Dropdown
    local typeDropdown = create("DropDown", {
        Name = "TypeDropdown", Parent = editPanel, List = elementTypes,
        Size=UDim2.new(1,0,0,INPUT_HEIGHT), BackgroundColor3=THEME_DEFAULTS.Subtle,
        Value = table.find(elementTypes, elementData.type or "Button")
    })
    
    -- Target Tab Dropdown
    local tabIDs = {}
    for _,t in ipairs(Engine.Registry.Tabs) do table.insert(tabIDs, t.uniqueID) end
    local tabDropdown = create("DropDown", {
        Name = "TabDropdown", Parent = editPanel, List = tabIDs,
        Size=UDim2.new(1,0,0,INPUT_HEIGHT), BackgroundColor3=THEME_DEFAULTS.Subtle,
        Value = table.find(tabIDs, elementData.targetTabID or (tabIDs[1] or ""))
    })

    -- Step 2: Dynamic Properties Panel
    local propsPanel = create("Frame", {Name="PropsPanel", Parent=editPanel, BackgroundTransparency=1, AutomaticSize=Enum.AutomaticSize.Y, Size=UDim2.new(1,0,0,0)})
    create("UIListLayout", {Parent=propsPanel, Padding=UDim.new(0,5)})
    
    local dynamicInputs = {}
    local function buildDynamicProps(elementType)
        for _,child in ipairs(propsPanel:GetChildren()) do if child:IsA("Frame") then child:Destroy() end end
        dynamicInputs = {}
        
        if elementType == "Slider" then
            local _, minIn = createTextInput("Min Value", propsPanel); dynamicInputs.minValue = minIn
            local _, maxIn = createTextInput("Max Value", propsPanel); dynamicInputs.maxValue = maxIn
            local _, incIn = createTextInput("Increment", propsPanel); dynamicInputs.increment = incIn
            local _, defIn = createTextInput("Default Value", propsPanel); dynamicInputs.defaultValue = defIn
            local _, sufIn = createTextInput("Suffix", propsPanel); dynamicInputs.suffix = sufIn
        elseif elementType == "Dropdown" then
            local f, i = createTextInput("Options (one per line)", propsPanel)
            i.TextWrapped, i.MultiLine = true, true; f.Size=UDim2.new(1,0,0,80)
            dynamicInputs.options = i
        end

        -- Populate with existing data if editing
        for key, input in pairs(dynamicInputs) do
            if props[key] then 
                input.Text = type(props[key]) == "table" and table.concat(props[key], "\n") or tostring(props[key])
            end
        end
    end
    
    typeDropdown.Changed:Connect(function(val) buildDynamicProps(elementTypes[val]) end)
    buildDynamicProps(typeDropdown.Text)
    
    -- Step 3: Lua Code Editor
    local f, luaInput = createTextInput("Lua Code (paste here)", editPanel)
    f.Size = UDim2.new(1,0,0,120); luaInput.MultiLine, luaInput.TextXAlignment = true, Enum.TextXAlignment.Left
    luaInput.Text = elementData.luaCode or ""
    
    -- Controls
    local saveBtn = createTextButton("Save Element", editPanel)
    local cancelBtn = createTextButton("Cancel", editPanel)
    cancelBtn.BackgroundColor3 = THEME_DEFAULTS.Destructive

    cancelBtn.MouseButton1Click:Connect(clearEditPanel)
    saveBtn.MouseButton1Click:Connect(function()
        local data = {
            label = nameInput.Text,
            uniqueID = idInput.Text:gsub("%s+", "_"),
            targetTabID = tabDropdown.Text,
            type = typeDropdown.Text,
            luaCode = luaInput.Text,
            properties = {},
        }
        
        for key, input in pairs(dynamicInputs) do
            local val = input.Text
            if key == "options" then
                data.properties[key] = val:split("\n")
            else
                data.properties[key] = tonumber(val) or val -- Attempt to convert to number
            end
        end

        if data.type == "Toggle" then data.properties.defaultValue = false end
        
        if activeEditElementID then Engine.UpdateElement(activeEditElementID, data) else Engine.AddElement(data) end
        clearEditPanel()
    end)
    
    editPanel.Visible = true
end

local function addElementToList(elementData)
    local id = elementData.uniqueID
    if elementListLayout.Parent:FindFirstChild(id) then elementListLayout.Parent[id]:Destroy() end

    local row = create("Frame", {Name=id, Parent=elementListLayout.Parent, Size=UDim2.new(1,0,0,30), BackgroundColor3=Color3.fromRGB(55,55,55)})
    create("UICorner", {Parent=row})
    local label = create("TextLabel", {Parent=row, Size=UDim2.new(1,-80,1,0), Position=UDim2.new(0,10,0,0), Text = elementData.label .. " (" .. elementData.uniqueID .. ")", TextColor3=THEME_DEFAULTS.Text, TextXAlignment=Enum.TextXAlignment.Left})
    
    local editBtn = createTextButton("Edit", row); editBtn.Size, editBtn.Position, editBtn.AnchorPoint = UDim2.new(0,35,0.8,0), UDim2.new(1,-45,0.5,0), Vector2.new(1,0.5)
    local removeBtn = createTextButton("X", row); removeBtn.Size, removeBtn.Position, removeBtn.AnchorPoint, removeBtn.BackgroundColor3 = UDim2.new(0,35,0.8,0), UDim2.new(1,-5,0.5,0), Vector2.new(1,0.5), THEME_DEFAULTS.Destructive

    removeBtn.MouseButton1Click:Connect(function() Engine.RemoveElement(id) end)
    editBtn.MouseButton1Click:Connect(function() activeEditElementID = id; populateEditPanel(Engine.GetElement(id)) end)
end

local function buildElementManager(parent)
    local section, _ = createSection("Element Manager", parent)
    
    local listFrame = create("ScrollingFrame", {
        Name = "ElementListScroll", Parent = section, Size = UDim2.new(1, 0, 0, 200),
        BackgroundColor3 = THEME_DEFAULTS.Subtle, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
    })
    elementListLayout = create("UIListLayout", { Parent = listFrame, Padding = UDim.new(0,5) })
    create("UIPadding", {Parent=listFrame, PaddingLeft=UDim.new(0,5), PaddingRight=UDim.new(0,5)})

    local createBtn = createTextButton("Create New Element", section)
    createBtn.MouseButton1Click:Connect(function() activeEditElementID = nil; populateEditPanel() end)
    
    editPanel, editPanelLayout = createSection("Create/Edit Element", parent)
    editPanel.Visible = false
    
    -- Connect signals
    Engine.Signals.ElementAdded:Connect(addElementToList)
    Engine.Signals.ElementUpdated:Connect(addElementToList) -- Re-adds to update label
    Engine.Signals.ElementRemoved:Connect(function(id) if listFrame:FindFirstChild(id) then listFrame[id]:Destroy() end end)
    
    for _, elData in pairs(Engine.Registry.Elements) do addElementToList(elData) end
end

-- //////////////////////////////////////////////////////////////////////////////////
-- // 4. CONFIGURATION MANAGER
-- //////////////////////////////////////////////////////////////////////////////////

local function buildConfigManager(parent)
    local section, _ = createSection("Configuration", parent)

    local exportBtn = createTextButton("Export Config to Clipboard", section)
    exportBtn.MouseButton1Click:Connect(Engine.RequestSave)

    local _, importInput = createTextInput("Paste Config Here", section)
    local importBtn = createTextButton("Import from Text", section)
    importBtn.MouseButton1Click:Connect(function()
        if importInput.Text and importInput.Text ~= "" then
            Engine.RequestLoad(importInput.Text)
        end
    end)
end

-- //////////////////////////////////////////////////////////////////////////////////
-- // 5. INITIALIZATION
-- //////////////////////////////////////////////////////////////////////////////////

function SettingsPanel.Init(engineRef, containers)
    Engine = engineRef
    settingsContainer = containers.settingsPanelContainer
    
    create("UIListLayout", { Parent = settingsContainer, Padding = UDim.new(0, SECTION_PADDING) })
    
    buildTabManager(settingsContainer)
    buildConfigManager(settingsContainer)
    buildElementManager(settingsContainer)
end

return SettingsPanel
