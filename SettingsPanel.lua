--[[
    Phase 4: The Settings Panel
    This module builds the entire user interface for the "Settings" view.
    - It creates the Tab Manager for adding/removing content tabs.
    - It creates the Element Manager for creating, editing, and removing elements.
    - It constructs the dynamic form for defining element properties and their Lua code.
]]

local SettingsPanel = {}

-- Module State
local Engine
local settingsContainer -- The parent frame provided by WindowManager
local activeEditElementID = nil

-- Configuration
local SECTION_PADDING = 15
local INPUT_HEIGHT = 30

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

local function createSection(name, layoutOrder, parent)
    local frame = create("Frame", {
        Name = name .. "Section",
        Parent = parent,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -20, 0, 150), -- Placeholder size, layout will manage
        LayoutOrder = layoutOrder,
    })
    
    local listLayout = create("UIListLayout", {
        Parent = frame,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 5),
    })
    
    create("TextLabel", {
        Name = "Header",
        Parent = frame,
        LayoutOrder = 1,
        Size = UDim2.new(1, 0, 0, 25),
        Text = name,
        Font = Enum.Font.SourceSansBold,
        TextSize = 20,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    return frame, listLayout
end

local function createTextButton(text, parent, layoutOrder)
     local btn = create("TextButton", {
        Name = text,
        Parent = parent,
        LayoutOrder = layoutOrder,
        Size = UDim2.new(1, 0, 0, 35),
        BackgroundColor3 = Color3.fromRGB(80, 80, 80),
        Text = text,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        Font = Enum.Font.SourceSansSemibold,
        TextSize = 16,
    })
    create("UICorner", { CornerRadius = UDim.new(0, 4), Parent = btn })
    return btn
end

local function createTextInput(placeholder, parent, layoutOrder)
    local frame = create("Frame", {
        Name = placeholder .. "InputFrame",
        Parent = parent,
        LayoutOrder = layoutOrder,
        Size = UDim2.new(1, 0, 0, INPUT_HEIGHT),
        BackgroundColor3 = Color3.fromRGB(40, 40, 40),
        BorderSizePixel = 0,
    })
    create("UICorner", { CornerRadius = UDim.new(0, 4), Parent = frame })

    local textBox = create("TextBox", {
        Name = "Input",
        Parent = frame,
        Size = UDim2.new(1, -10, 1, 0),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        PlaceholderText = placeholder,
        PlaceholderColor3 = Color3.fromRGB(150, 150, 150),
        Text = "",
        TextColor3 = Color3.fromRGB(220, 220, 220),
        Font = Enum.Font.SourceSans,
        TextSize = 14,
        ClearTextOnFocus = false,
    })
    return frame, textBox
end

-- //////////////////////////////////////////////////////////////////////////////////
-- // 2. TAB MANAGER
-- //////////////////////////////////////////////////////////////////////////////////

local function buildTabManager(parent)
    local section, _ = createSection("Tabs", 1, parent)
    
    local tabNameInputFrame, tabNameInput = createTextInput("New Tab Name", section, 2)
    local addTabBtn = createTextButton("Add New Tab", section, 3)

    addTabBtn.MouseButton1Click:Connect(function()
        local name = tabNameInput.Text
        if name and name:match("%S") then -- Check if not empty or just whitespace
            Engine.AddTab({
                uniqueID = name:lower():gsub("%s+", "_"), -- e.g., "My Tab" -> "my_tab"
                label = name,
            })
            tabNameInput.Text = ""
        end
    end)
end

-- //////////////////////////////////////////////////////////////////////////////////
-- // 3. ELEMENT MANAGER
-- //////////////////////////////////////////////////////////////////////////////////

local editPanel -- Frame that holds the creation/editing form
local elementListLayout -- Layout for the master list of elements

local function clearEditPanel()
    for _, child in ipairs(editPanel:GetChildren()) do
        if child.Name ~= "Header" then
            child:Destroy()
        end
    end
    editPanel.Visible = false
    activeEditElementID = nil
end

local function populateEditPanel(elementData)
    clearEditPanel()

    elementData = elementData or {}
    local props = elementData.properties or {}
    
    -- Inputs for common properties
    local _, nameInput = createTextInput("Display Name", editPanel, 2)
    nameInput.Text = elementData.label or ""

    local _, idInput = createTextInput("Unique ID (no spaces)", editPanel, 3)
    idInput.Text = elementData.uniqueID or ""
    
    -- Dropdown for Target Tab
    -- Note: A proper dropdown element would be better, but a simple text box suffices for this example.
    local _, tabInput = createTextInput("Target Tab ID", editPanel, 4)
    tabInput.Text = elementData.targetTabID or ""
    
    -- Inputs for type-specific properties (a simplified example)
    -- A real implementation would have more robust type-checking and dynamic inputs
    local _, typeInput = createTextInput("Type (Button, Toggle, Slider)", editPanel, 5)
    typeInput.Text = elementData.type or ""
    
    -- LUA CODE EDITOR
    local luaInputFrame, luaInput = createTextInput("Lua Code (paste here)", editPanel, 6)
    luaInputFrame.Size = UDim2.new(1, 0, 0, 100) -- Make it taller
    luaInput.TextXAlignment = Enum.TextXAlignment.Left
    luaInput.TextYAlignment = Enum.TextYAlignment.Top
    luaInput.MultiLine = true
    luaInput.Text = elementData.luaCode or ""

    local saveBtn = createTextButton("Save Element", editPanel, 7)
    local cancelBtn = createTextButton("Cancel", editPanel, 8)
    cancelBtn.BackgroundColor3 = Color3.fromRGB(120, 60, 60)
    
    cancelBtn.MouseButton1Click:Connect(clearEditPanel)
    
    saveBtn.MouseButton1Click:Connect(function()
        local data = {
            label = nameInput.Text,
            uniqueID = idInput.Text,
            targetTabID = tabInput.Text,
            type = typeInput.Text,
            luaCode = luaInput.Text,
            -- This is a simplified property setup. A full version would read from dynamic inputs.
            properties = {
                defaultValue = (typeInput.Text == "Toggle" and false) or (typeInput.Text == "Slider" and 50) or nil,
                minValue = 0,
                maxValue = 100,
                increment = 1,
                suffix = "",
            },
        }

        if activeEditElementID then
            Engine.UpdateElement(activeEditElementID, data)
        else
            Engine.AddElement(data)
        end
        clearEditPanel()
    end)
    
    editPanel.Visible = true
end

local function addElementToList(elementData)
    local elementID = elementData.uniqueID
    local frame = create("Frame", {
        Name = elementID,
        Parent = elementListLayout.Parent, -- Parent to the scrolling frame
        LayoutOrder = 3,
        Size = UDim2.new(1, 0, 0, INPUT_HEIGHT),
        BackgroundColor3 = Color3.fromRGB(50, 50, 50),
    })
    
    create("TextLabel", {
        Parent = frame,
        Size = UDim2.new(1, -70, 1, 0),
        BackgroundTransparency = 1,
        Text = "  " .. elementData.label .. " (" .. elementData.type .. ")",
        Font = Enum.Font.SourceSans,
        TextSize = 14,
        TextColor3 = Color3.fromRGB(220, 220, 220),
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    
    local editBtn = createTextButton("Edit", frame, 1)
    editBtn.Size = UDim2.new(0, 30, 0.8, 0)
    editBtn.AnchorPoint = Vector2.new(1, 0.5)
    editBtn.Position = UDim2.new(1, -40, 0.5, 0)
    editBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 150)

    local removeBtn = createTextButton("X", frame, 2)
    removeBtn.Size = UDim2.new(0, 30, 0.8, 0)
    removeBtn.AnchorPoint = Vector2.new(1, 0.5)
    removeBtn.Position = UDim2.new(1, -5, 0.5, 0)
    removeBtn.BackgroundColor3 = Color3.fromRGB(150, 70, 70)

    removeBtn.MouseButton1Click:Connect(function()
        Engine.RemoveElement(elementID)
    end)
    
    editBtn.MouseButton1Click:Connect(function()
        activeEditElementID = elementID
        populateEditPanel(Engine.GetElement(elementID))
    end)
end

local function onElementRemovedFromList(elementID)
    local listItem = elementListLayout.Parent:FindFirstChild(elementID)
    if listItem then
        listItem:Destroy()
    end
end

local function buildElementManager(parent)
    local section, _ = createSection("Elements", 2, parent)
    section.Size = UDim2.new(1, -20, 0, 300) -- Give it more space

    -- Master List (Scrollable)
    local listFrame = create("ScrollingFrame", {
        Name = "ElementListScroll",
        Parent = section,
        LayoutOrder = 2,
        Size = UDim2.new(1, 0, 0, 150),
        BackgroundColor3 = Color3.fromRGB(40, 40, 40),
        CanvasSize = UDim2.new(0,0,0,0), -- Use AutomaticCanvasSize
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
    })
    elementListLayout = create("UIListLayout", { Parent = listFrame, SortOrder = Enum.SortOrder.LayoutOrder })

    local createBtn = createTextButton("Create New Element", section, 3)
    createBtn.MouseButton1Click:Connect(function()
        activeEditElementID = nil -- Ensure we are in "create" mode
        populateEditPanel()
    end)
    
    -- Edit Panel (initially hidden)
    editPanel, _ = createSection("Create/Edit Element", 4, parent)
    editPanel.Visible = false
    
    -- Populate list with any pre-existing elements
    for _, elementData in pairs(Engine.Registry.Elements) do
        addElementToList(elementData)
    end
    
    -- Connect signals to update the list
    Engine.Signals.ElementAdded:Connect(addElementToList)
    Engine.Signals.ElementRemoved:Connect(onElementRemovedFromList)
end

-- //////////////////////////////////////////////////////////////////////////////////
-- // 4. PUBLIC API
-- //////////////////////////////////////////////////////////////////////////////////

function SettingsPanel.Init(engineRef, containers)
    Engine = engineRef
    settingsContainer = containers.settingsContainer
    
    -- Main layout for the settings view
    local mainLayout = create("UIListLayout", {
        Parent = settingsContainer,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, SECTION_PADDING),
    })
    
    -- Build the UI components
    buildTabManager(settingsContainer)
    buildElementManager(settingsContainer)
    
    -- A spacer at the bottom
    create("Frame", { Name = "Spacer", Parent = settingsContainer, BackgroundTransparency = 1, LayoutOrder = 100, Size = UDim2.new(1,0,0,20) })
end

return SettingsPanel
