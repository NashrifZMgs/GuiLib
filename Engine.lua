--[[
    Nexus-Lua GUI System | Phase 1: The Engine
    Purpose: The non-visual core that manages all data, logic, and state.
    This is the central nervous system of the GUI.
]]

local Engine = {}

-- //////////////////////////////////////////////////////////////////////////////////
-- // 1. INTERNAL SIGNAL SYSTEM
-- // A simple event class to allow modules to communicate without being tightly coupled.
-- //////////////////////////////////////////////////////////////////////////////////
local Signal = {}
Signal.__index = Signal

function Signal.new()
    local self = setmetatable({}, Signal)
    self._connections = {}
    return self
end

function Signal:Connect(func)
    assert(typeof(func) == "function", "Signal:Connect requires a function.")
    local connection = { _func = func, _signal = self, Connected = true }
    table.insert(self._connections, connection)

    function connection:Disconnect()
        if not self.Connected then return end
        for i, conn in ipairs(self._signal._connections) do
            if conn == self then
                table.remove(self._signal._connections, i)
                self.Connected = false
                break
            end
        end
    end
    return connection
end

function Signal:Fire(...)
    for _, connection in ipairs(self._connections) do
        if connection.Connected then
            -- Using task.spawn ensures that one misbehaving listener doesn't stop others.
            task.spawn(connection._func, ...)
        end
    end
end

-- //////////////////////////////////////////////////////////////////////////////////
-- // 2. ENGINE STATE AND REGISTRY
-- // This is the single source of truth for the GUI's structure and data.
-- //////////////////////////////////////////////////////////////////////////////////

Engine.Registry = {
    -- Stores definitions for tabs. e.g., { uniqueID = "main", label = "Main", icon = "home" }
    Tabs = {},
    -- Stores complete definitions for elements, indexed by their uniqueID.
    Elements = {},
    -- Stores the current theme settings.
    Theme = {},
}

Engine.Signals = {
    -- Fired when a new tab is created. Passes tabData.
    TabAdded = Signal.new(),
    -- Fired when a tab is removed. Passes tabID.
    TabRemoved = Signal.new(),

    -- Fired when a new element is created. Passes elementData.
    ElementAdded = Signal.new(),
    -- Fired when an element's definition changes. Passes elementID, newElementData.
    ElementUpdated = Signal.new(),
    -- Fired when an element is removed. Passes elementID.
    ElementRemoved = Signal.new(),

    -- Fired by API.SetValue to notify the renderer to update an element's visual state.
    -- Passes elementID, newValue.
    ElementValueChanged = Signal.new(),
    
    -- Fired when the GUI's theme is changed. Passes the new theme table.
    ThemeChanged = Signal.new(),

    -- Fired by API.Notify to request the WindowManager show a notification.
    -- Passes title, content.
    NotificationRequested = Signal.new(),
    
    -- Fired to request the main script handle saving/loading.
    SaveRequested = Signal.new(),
    LoadRequested = Signal.new(),
}

-- //////////////////////////////////////////////////////////////////////////////////
-- // 3. HELPER UTILITIES
-- //////////////////////////////////////////////////////////////////////////////////

local function deepClone(original)
    local copy = {}
    for k, v in pairs(original) do
        if type(v) == "table" then
            v = deepClone(v)
        end
        copy[k] = v
    end
    return copy
end


-- //////////////////////////////////////////////////////////////////////////////////
-- // 4. API FOR USER-WRITTEN LUA
-- // This table is injected into the environment of the user's code snippets.
-- //////////////////////////////////////////////////////////////////////////////////

local API = {}

--- Returns the current value of another element.
function API.GetValue(elementUniqueID)
    local element = Engine.Registry.Elements[elementUniqueID]
    if not element then
        warn("[GUI Engine API] GetValue failed: No element found with ID: " .. tostring(elementUniqueID))
        return nil
    end
    return element.value
end

--- Programmatically sets the value of another element. This will trigger that element's own Lua code.
function API.SetValue(elementUniqueID, newValue)
    local element = Engine.Registry.Elements[elementUniqueID]
    if not element then
        warn("[GUI Engine API] SetValue failed: No element found with ID: " .. tostring(elementUniqueID))
        return
    end
    
    element.value = newValue
    Engine.Signals.ElementValueChanged:Fire(elementUniqueID, newValue)
    Engine.ExecuteCode(elementUniqueID) -- Trigger action chains
end

--- Simulates a primary action on another element (e.g., a button click).
function API.Trigger(elementUniqueID)
    local element = Engine.Registry.Elements[elementUniqueID]
    if not element then
        warn("[GUI Engine API] Trigger failed: No element found with ID: " .. tostring(elementUniqueID))
        return
    end
    Engine.ExecuteCode(elementUniqueID)
end

--- Shows an on-screen notification.
function API.Notify(title, content)
    Engine.Signals.NotificationRequested:Fire(tostring(title), tostring(content))
end

--- Gets the configuration properties of an element (e.g., min/max range of a slider).
function API.GetProperties(elementUniqueID)
    local element = Engine.Registry.Elements[elementUniqueID]
    if not element then
        warn("[GUI Engine API] GetProperties failed: No element found with ID: " .. tostring(elementUniqueID))
        return nil
    end
    -- Return a deep copy to prevent user code from accidentally modifying the registry.
    return deepClone(element.properties)
end

--- Changes the configuration properties of an element.
function API.SetProperties(elementUniqueID, newProperties)
    local element = Engine.Registry.Elements[elementUniqueID]
    if not element then
        warn("[GUI Engine API] SetProperties failed: No element found with ID: " .. tostring(elementUniqueID))
        return
    end
    
    for key, value in pairs(newProperties) do
        element.properties[key] = value
    end

    -- Fire the generic ElementUpdated signal so renderers can rebuild if needed (e.g., change dropdown options).
    Engine.Signals.ElementUpdated:Fire(elementUniqueID, deepClone(element))
end


-- //////////////////////////////////////////////////////////////////////////////////
-- // 5. REGISTRY MANAGEMENT
-- // Functions for other modules to safely add, remove, and update data.
-- //////////////////////////////////////////////////////////////////////////////////

function Engine.GetElement(elementID)
    return Engine.Registry.Elements[elementID]
end

function Engine.AddElement(elementData)
    local id = elementData.uniqueID
    if not id or Engine.Registry.Elements[id] then
        warn("[GUI Engine] AddElement failed: Invalid or duplicate element ID: '" .. tostring(id) .. "'.")
        return
    end
    
    -- Initialize the element's current value with its default if it exists.
    elementData.value = elementData.properties.defaultValue

    Engine.Registry.Elements[id] = elementData
    Engine.Signals.ElementAdded:Fire(deepClone(elementData))
end

function Engine.RemoveElement(elementID)
    if not Engine.Registry.Elements[elementID] then return end
    
    Engine.Registry.Elements[elementID] = nil
    Engine.Signals.ElementRemoved:Fire(elementID)
end

function Engine.UpdateElement(elementID, newElementData)
    if not Engine.Registry.Elements[elementID] then
        warn("[GUI Engine] UpdateElement failed: No element found with ID: " .. tostring(elementID))
        return
    end
    
    -- Preserve the current value if it's not being changed in the update
    newElementData.value = newElementData.value or Engine.Registry.Elements[elementID].value
    
    Engine.Registry.Elements[elementID] = newElementData
    Engine.Signals.ElementUpdated:Fire(elementID, deepClone(newElementData))
end

function Engine.AddTab(tabData)
    local id = tabData.uniqueID
    for _, tab in ipairs(Engine.Registry.Tabs) do
        if tab.uniqueID == id then
             warn("[GUI Engine] AddTab failed: A tab with ID '" .. tostring(id) .. "' already exists.")
             return
        end
    end

    table.insert(Engine.Registry.Tabs, tabData)
    Engine.Signals.TabAdded:Fire(deepClone(tabData))
end

function Engine.RemoveTab(tabID)
    for i, tab in ipairs(Engine.Registry.Tabs) do
        if tab.uniqueID == tabID then
            table.remove(Engine.Registry.Tabs, i)
            Engine.Signals.TabRemoved:Fire(tabID)
            
            -- Also remove all elements associated with that tab.
            local elementsToRemove = {}
            for elementID, elementData in pairs(Engine.Registry.Elements) do
                if elementData.targetTabID == tabID then
                    table.insert(elementsToRemove, elementID)
                end
            end
            for _, id in ipairs(elementsToRemove) do
                Engine.RemoveElement(id)
            end
            return
        end
    end
end

function Engine.UpdateTheme(themeTable)
    Engine.Registry.Theme = themeTable
    Engine.Signals.ThemeChanged:Fire(deepClone(themeTable))
end

-- //////////////////////////////////////////////////////////////////////////////////
-- // 6. SANDBOXED CODE EXECUTION
-- //////////////////////////////////////////////////////////////////////////////////

--- Executes the Lua code associated with a specific element.
function Engine.ExecuteCode(elementID)
    local element = Engine.Registry.Elements[elementID]
    -- Do nothing if element doesn't exist or has no code.
    if not element or not element.luaCode or element.luaCode:match("^%s*$") then
        return
    end

    -- Create the sandboxed environment
    local env = {
        -- The API for linking elements
        API = API,
        -- 'self' provides easy access to the element's own data
        self = {
            Value = element.value,
            Properties = deepClone(element.properties) -- Read-only access to properties
        },
        -- Standard safe libraries
        print = print,
        warn = warn,
        task = task,
        game = game, -- Pass the game object for game interactions
        -- Add other safe globals as needed
        Color3 = Color3,
        Vector3 = Vector3,
        CFrame = CFrame,
        Enum = Enum,
        pairs = pairs,
        ipairs = ipairs,
        tostring = tostring,
    }
    
    local func, err = loadstring(element.luaCode)
    if not func then
        API.Notify("Lua Error in '"..element.label.."'", "Syntax Error: " .. tostring(err))
        return
    end
    
    -- Set the environment for the function.
    setfenv(func, env)
    
    -- Execute the function safely using a protected call.
    local success, execErr = pcall(func)
    if not success then
        API.Notify("Lua Error in '"..element.label.."'", "Runtime Error: " .. tostring(execErr))
    end
end

-- //////////////////////////////////////////////////////////////////////////////////
-- // 7. CONFIGURATION REQUESTS
-- // These fire signals that the top-level Main.lua script will handle.
-- //////////////////////////////////////////////////////////////////////////////////

function Engine.RequestSave()
    Engine.Signals.SaveRequested:Fire()
end

function Engine.RequestLoad()
    Engine.Signals.LoadRequested:Fire()
end

return Engine
