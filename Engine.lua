--[[
    Phase 1: The Core Engine
    This module is the non-visual brain of the entire GUI system.
    - It manages the state and definitions of all tabs and elements.
    - It provides the API for user-written Lua snippets.
    - It executes user code in a controlled (sandboxed) environment.
    - It uses signals to communicate with other modules (like the renderer and window manager).
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
    local connection = {
        _func = func,
        _signal = self,
        Connected = true,
    }

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
            task.spawn(connection._func, ...)
        end
    end
end

-- //////////////////////////////////////////////////////////////////////////////////
-- // 2. ENGINE STATE AND REGISTRY
-- // This is the single source of truth for the GUI's structure and data.
-- //////////////////////////////////////////////////////////////////////////////////

Engine.Registry = {
    -- Stores definitions for tabs. e.g., { uniqueID = "main", label = "Main" }
    Tabs = {},
    -- Stores complete definitions for elements, indexed by their uniqueID.
    Elements = {},
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

    -- Fired by API.Notify to request the WindowManager show a notification.
    -- Passes title, content.
    NotificationRequested = Signal.new(),
    
    -- Stubs for the main script to connect to.
    SaveRequested = Signal.new(),
    LoadRequested = Signal.new(),
}

-- //////////////////////////////////////////////////////////////////////////////////
-- // 3. API FOR USER-WRITTEN LUA
-- // This table is injected into the environment of the user's code snippets.
-- //////////////////////////////////////////////////////////////////////////////////

local API = {}

--- Returns the current value of another element.
-- @param elementUniqueID (string) The ID of the element to get the value from.
-- @return The element's value (boolean for toggle, number for slider, string/table for dropdown).
function API.GetValue(elementUniqueID)
    local element = Engine.Registry.Elements[elementUniqueID]
    if not element then
        warn("[GUI Engine API] GetValue failed: No element found with ID: " .. tostring(elementUniqueID))
        return nil
    end
    -- The 'value' property will be managed by the ElementRenderer in a later phase.
    return element.value
end

--- Programmatically sets the value of another element.
-- @param elementUniqueID (string) The ID of the element to change.
-- @param newValue (any) The new value to set.
function API.SetValue(elementUniqueID, newValue)
    local element = Engine.Registry.Elements[elementUniqueID]
    if not element then
        warn("[GUI Engine API] SetValue failed: No element found with ID: " .. tostring(elementUniqueID))
        return
    end
    
    -- Set the new value in the registry
    element.value = newValue
    
    -- Fire a signal so the renderer can update the visual part of the element.
    Engine.Signals.ElementValueChanged:Fire(elementUniqueID, newValue)
    
    -- Also, trigger the target element's own code to create action chains.
    Engine.ExecuteCode(elementUniqueID)
end

--- Simulates a primary action on another element (e.g., a button click).
-- @param elementUniqueID (string) The ID of the element to trigger.
function API.Trigger(elementUniqueID)
    local element = Engine.Registry.Elements[elementUniqueID]
    if not element then
        warn("[GUI Engine API] Trigger failed: No element found with ID: " .. tostring(elementUniqueID))
        return
    end
    Engine.ExecuteCode(elementUniqueID)
end

--- Shows an on-screen notification.
-- @param title (string) The title of the notification.
-- @param content (string) The main text of the notification.
function API.Notify(title, content)
    Engine.Signals.NotificationRequested:Fire(tostring(title), tostring(content))
end

--- Gets the configuration properties of an element (e.g., min/max range of a slider).
-- @param elementUniqueID (string) The ID of the element to inspect.
-- @return A table of the element's properties.
function API.GetProperties(elementUniqueID)
    local element = Engine.Registry.Elements[elementUniqueID]
    if not element then
        warn("[GUI Engine API] GetProperties failed: No element found with ID: " .. tostring(elementUniqueID))
        return nil
    end
    -- Return a deep copy to prevent user code from modifying the original properties table.
    return table.clone(element.properties)
end


-- //////////////////////////////////////////////////////////////////////////////////
-- // 4. REGISTRY MANAGEMENT
-- // Functions to safely add, remove, and update tabs and elements.
-- //////////////////////////////////////////////////////////////////////////////////

function Engine.GetElement(elementID)
    return Engine.Registry.Elements[elementID]
end

function Engine.AddElement(elementData)
    local id = elementData.uniqueID
    if Engine.Registry.Elements[id] then
        warn("[GUI Engine] AddElement failed: An element with ID '" .. id .. "' already exists.")
        return
    end
    
    -- Initialize the element's current value with its default if it exists
    elementData.value = elementData.properties.defaultValue

    Engine.Registry.Elements[id] = elementData
    Engine.Signals.ElementAdded:Fire(elementData)
end

function Engine.RemoveElement(elementID)
    if not Engine.Registry.Elements[elementID] then return end
    
    Engine.Registry.Elements[elementID] = nil
    Engine.Signals.ElementRemoved:Fire(elementID)
end

function Engine.UpdateElement(elementID, newElementData)
    if not Engine.Registry.Elements[elementID] then
        warn("[GUI Engine] UpdateElement failed: No element found with ID: " .. elementID)
        return
    end
    
    Engine.Registry.Elements[elementID] = newElementData
    Engine.Signals.ElementUpdated:Fire(elementID, newElementData)
end

function Engine.AddTab(tabData)
    table.insert(Engine.Registry.Tabs, tabData)
    Engine.Signals.TabAdded:Fire(tabData)
end

function Engine.RemoveTab(tabID)
    for i, tab in ipairs(Engine.Registry.Tabs) do
        if tab.uniqueID == tabID then
            table.remove(Engine.Registry.Tabs, i)
            Engine.Signals.TabRemoved:Fire(tabID)
            
            -- Also remove all elements associated with that tab
            for elementID, elementData in pairs(Engine.Registry.Elements) do
                if elementData.targetTabID == tabID then
                    Engine.RemoveElement(elementID)
                end
            end
            
            return
        end
    end
end

-- //////////////////////////////////////////////////////////////////////////////////
-- // 5. SANDBOXED CODE EXECUTION
-- //////////////////////////////////////////////////////////////////////////////////

--- Executes the Lua code associated with a specific element.
-- @param elementID (string) The ID of the element whose code should be run.
function Engine.ExecuteCode(elementID)
    local element = Engine.Registry.Elements[elementID]
    if not element or not element.luaCode or element.luaCode:match("^%s*$") then
        return -- Do nothing if element doesn't exist or has no code.
    end

    -- Create the sandboxed environment
    local env = {
        -- The API for linking elements
        API = API,
        -- 'self' provides easy access to the element's own value
        self = {
            Value = element.value,
            Properties = table.clone(element.properties) -- Read-only access to properties
        },
        -- Standard safe libraries
        print = print,
        warn = warn,
        task = task,
        game = game, -- Pass the game object for game interactions
        -- Add other safe globals as needed
    }
    
    -- Load the user's code string within the sandboxed environment
    local func, err = loadstring(element.luaCode)
    if not func then
        API.Notify("Lua Error in '"..element.label.."'", "Syntax Error: " .. tostring(err))
        warn("[GUI Engine] Syntax error in element '" .. element.label .. "': " .. tostring(err))
        return
    end
    
    setfenv(func, env)
    
    -- Execute the function
    local success, execErr = pcall(func)
    if not success then
        API.Notify("Lua Error in '"..element.label.."'", "Runtime Error: " .. tostring(execErr))
        warn("[GUI Engine] Runtime error in element '" .. element.label .. "': " .. tostring(execErr))
    end
end

-- //////////////////////////////////////////////////////////////////////////////////
-- // 6. CONFIGURATION STUBS
-- // These will fire signals that the top-level Main.lua script will handle.
-- //////////////////////////////////////////////////////////////////////////////////

function Engine.SaveConfiguration()
    Engine.Signals.SaveRequested:Fire()
end

function Engine.LoadConfiguration()
    Engine.Signals.LoadRequested:Fire()
end


return Engine
