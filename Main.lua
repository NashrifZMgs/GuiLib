--[[
    Nexus-Lua: Unified GUI System v2.0
    Re-architected by Nexus-Lua, inspired by the robust library pattern of Rayfield.
    
    Version 2.0 Changes:
    - Entire script is encapsulated into a library object ('Nexus') to be returned, preventing initialization race conditions.
    - Default tab and element creation is now delayed until after the main window is fully initialized.
    - This resolves the "attempt to call a nil value" error by ensuring UI components are ready before being manipulated.
    - All modules are defined as internal components of the main library function.
]]

local function CreateNexusGUILibrary()
    -- Roblox Services & Global Utilities
    local HttpService = game:GetService("HttpService")
    local TweenService = game:GetService("TweenService")
    local UserInputService = game:GetService("UserInputService")
    local RunService = game:GetService("RunService")
    local CoreGui = game:GetService("CoreGui")

    -- Helper function to create instances, used by multiple modules
    local function create(instanceType, properties)
        local inst = Instance.new(instanceType)
        for prop, value in pairs(properties or {}) do
            inst[prop] = value
        end
        return inst
    end

    ----------------------------------------------------------------------------------
    -- INTERNAL MODULE DEFINITIONS START
    -- All modules are now local and encapsulated within the library.
    ----------------------------------------------------------------------------------

    -- ////////////////////////////////////////////////////////////////////////////////
    -- // Phase 1: The Core Engine
    -- ////////////////////////////////////////////////////////////////////////////////
    local Engine = {}
    do
        local Signal = {}
        Signal.__index = Signal
        function Signal.new() return setmetatable({ _connections = {} }, Signal) end
        function Signal:Connect(func)
            local connection = { _func = func, _signal = self, Connected = true }
            table.insert(self._connections, connection)
            function connection:Disconnect()
                if not self.Connected then return end
                for i, conn in ipairs(self._signal._connections) do
                    if conn == self then table.remove(self._signal._connections, i) self.Connected = false; break end
                end
            end
            return connection
        end
        function Signal:Fire(...) for _, c in ipairs(self._connections) do if c.Connected then task.spawn(c._func, ...) end end end
        Engine.Registry = { Tabs = {}, Elements = {} }
        Engine.Signals = { TabAdded=Signal.new(), TabRemoved=Signal.new(), ElementAdded=Signal.new(), ElementUpdated=Signal.new(), ElementRemoved=Signal.new(), ElementValueChanged=Signal.new(), NotificationRequested=Signal.new(), SaveToClipboard=Signal.new() }
        local API = {}
        function API.GetValue(id) local el = Engine.Registry.Elements[id]; return el and el.value or nil end
        function API.SetValue(id, val) local el = Engine.Registry.Elements[id]; if not el then return end; el.value = val; Engine.Signals.ElementValueChanged:Fire(id, val); Engine.ExecuteCode(id) end
        function API.Trigger(id) if not Engine.Registry.Elements[id] then return end; Engine.ExecuteCode(id) end
        function API.Notify(title, content) Engine.Signals.NotificationRequested:Fire(tostring(title), tostring(content)) end
        function API.GetProperties(id) local el=Engine.Registry.Elements[id]; return el and table.clone(el.properties) or nil end
        function Engine.GetElement(id) return Engine.Registry.Elements[id] end
        function Engine.AddElement(data) if Engine.Registry.Elements[data.uniqueID] then return end; data.value = data.properties.defaultValue; Engine.Registry.Elements[data.uniqueID] = data; Engine.Signals.ElementAdded:Fire(data) end
        function Engine.RemoveElement(id) if not Engine.Registry.Elements[id] then return end; Engine.Registry.Elements[id] = nil; Engine.Signals.ElementRemoved:Fire(id) end
        function Engine.UpdateElement(id, newData) if not Engine.Registry.Elements[id] then return end; Engine.Registry.Elements[id] = newData; Engine.Signals.ElementUpdated:Fire(id, newData) end
        function Engine.AddTab(data) table.insert(Engine.Registry.Tabs, data); Engine.Signals.TabAdded:Fire(data) end
        function Engine.RemoveTab(id) for i,tab in ipairs(Engine.Registry.Tabs) do if tab.uniqueID == id then table.remove(Engine.Registry.Tabs, i); Engine.Signals.TabRemoved:Fire(id); for elID, elData in pairs(Engine.Registry.Elements) do if elData.targetTabID == id then Engine.RemoveElement(elID) end end; return end end end
        function Engine.ExecuteCode(id) local el = Engine.Registry.Elements[id]; if not (el and el.luaCode and el.luaCode:match("%S")) then return end; local env = { API=API, self={Value=el.value, Properties=table.clone(el.properties)}, print=print, warn=warn, task=task, game=game }; local f, err = loadstring(el.luaCode); if not f then API.Notify("Lua Error: "..el.label, "Syntax: "..tostring(err)); return end; setfenv(f, env); local s, execErr = pcall(f); if not s then API.Notify("Lua Error: "..el.label, "Runtime: "..tostring(execErr)) end end
        function Engine.LoadConfigurationFromString(json) local s, d = pcall(function() return HttpService:JSONDecode(json) end); if s and d and d.Registry then local c = table.clone(Engine.Registry.Tabs); for _, t in ipairs(c) do Engine.RemoveTab(t.uniqueID) end; for _, t in ipairs(d.Registry.Tabs) do Engine.AddTab(t) end; for _, e in pairs(d.Registry.Elements) do Engine.AddElement(e) end; API.Notify("System", "Config Imported!") else API.Notify("Error", "Import Failed.") end end
    end

    -- ////////////////////////////////////////////////////////////////////////////////
    -- // Phase 2: The Window & Layout Manager
    -- ////////////////////////////////////////////////////////////////////////////////
    local WindowManager = {}
    do
        local Z, MIN_SIZE, SIDEBAR_W, HEADER_H = 500, Vector2.new(520, 350), 150, 40
        local gui, win, head, side, cont, resize; local sideVisible=true; local isDrag,isResize=false,false; local dStart,oPos,rStart,oSize
        local function tween(i, g, d) local t=TweenService:Create(i, TweenInfo.new(d or 0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), g); t:Play(); return t end
        local function onInputBegan(o, i) if i.UserInputType~=Enum.UserInputType.MouseButton1 and i.UserInputType~=Enum.UserInputType.Touch then return end; if o==head then isDrag,dStart,oPos=true,i.Position,win.Position elseif o==resize then isResize,rStart,oSize=true,i.Position,win.AbsoluteSize end; win.ZIndex = Z+10 end
        local function onInputChanged(i) if i.UserInputType~=Enum.UserInputType.MouseMovement and i.UserInputType~=Enum.UserInputType.Touch then return end; if isDrag then local d=i.Position-dStart; win.Position=UDim2.fromOffset(oPos.X.Offset+d.X, oPos.Y.Offset+d.Y) elseif isResize then local d=i.Position-rStart; local n=oSize+d; win.Size=UDim2.fromOffset(math.max(MIN_SIZE.X, n.X), math.max(MIN_SIZE.Y, n.Y)) end end
        local function onInputEnded(i) if i.UserInputType~=Enum.UserInputType.MouseButton1 and i.UserInputType~=Enum.UserInputType.Touch then return end; isDrag,isResize,win.ZIndex=false,false,Z end
        function WindowManager.ToggleSidebar() sideVisible=not sideVisible; local sPos=sideVisible and UDim2.new(0,0,0,HEADER_H) or UDim2.new(0,-SIDEBAR_W,0,HEADER_H); local cPos=sideVisible and UDim2.new(0,SIDEBAR_W,0,HEADER_H) or UDim2.new(0,0,0,HEADER_H); local cSize=sideVisible and UDim2.new(1,-SIDEBAR_W,1,-HEADER_H) or UDim2.new(1,0,1,-HEADER_H); tween(side,{Position=sPos}); tween(cont,{Position=cPos, Size=cSize}) end
        function WindowManager.Destroy() if gui then gui:Destroy() gui=nil end end
        function WindowManager.ShowNotification(title, content) local n=create("Frame",{Name="N", Parent=gui, Size=UDim2.new(0,250,0,60), Position=UDim2.new(1,-270,1,0), BackgroundColor3=Color3.fromRGB(30,30,30), BackgroundTransparency=0.2, BorderSizePixel=0, ZIndex=Z+100}); create("UICorner",{Parent=n,CornerRadius=UDim.new(0,5)}); create("UIPadding",{Parent=n,PaddingLeft=UDim.new(0,10),PaddingRight=UDim.new(0,10),PaddingTop=UDim.new(0,5),PaddingBottom=UDim.new(0,5)}); create("TextLabel",{Name="T",Parent=n,Size=UDim2.new(1,0,0,20),Text=title,Font=Enum.Font.SourceSansBold,TextColor3=Color3.fromRGB(255,255,255),TextSize=16,TextXAlignment=Enum.TextXAlignment.Left,BackgroundTransparency=1}); create("TextLabel",{Name="C",Parent=n,Size=UDim2.new(1,0,1,-25),Position=UDim2.new(0,0,0,25),Text=content,Font=Enum.Font.SourceSans,TextColor3=Color3.fromRGB(220,220,220),TextSize=14,TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true,BackgroundTransparency=1}); tween(n,{Position=UDim2.new(1,-270,1,-80)},0.3); task.delay(4,function() if n and n.Parent then tween(n,{Position=UDim2.new(1,-270,1,0)},0.3); task.wait(0.3); n:Destroy() end end) end
        function WindowManager.Init() Engine.Signals.NotificationRequested:Connect(WindowManager.ShowNotification); gui=create("ScreenGui",{Name="NexusGUISystem",Parent=CoreGui,ZIndexBehavior=Enum.ZIndexBehavior.Global,ResetOnSpawn=false}); win=create("Frame",{Name="Window",Parent=gui,BackgroundColor3=Color3.fromRGB(45,45,45),BorderSizePixel=0,Active=true,Size=UDim2.fromOffset(600,400),Position=UDim2.new(0.5,-300,0.5,-200),ClipsDescendants=true,ZIndex=Z}); create("UICorner",{Parent=win,CornerRadius=UDim.new(0,6)}); head=create("Frame",{Name="Header",Parent=win,BackgroundColor3=Color3.fromRGB(35,35,35),BorderSizePixel=0,Size=UDim2.new(1,0,0,HEADER_H),ZIndex=Z+2}); head.InputBegan:Connect(function(i) onInputBegan(head,i) end); create("TextButton",{Name="SidebarToggle",Parent=head,Size=UDim2.fromOffset(40,40),Text="≡",TextColor3=Color3.fromRGB(220,220,220),TextSize=30,BackgroundTransparency=1,ZIndex=Z+3}).MouseButton1Click:Connect(WindowManager.ToggleSidebar); create("TextLabel",{Name="Title",Parent=head,Size=UDim2.new(1,-120,1,0),Position=UDim2.new(0,40,0,0),Text="Nexus-Lua GUI",TextColor3=Color3.fromRGB(255,255,255),Font=Enum.Font.SourceSansSemibold,TextSize=18,TextXAlignment=Enum.TextXAlignment.Left,BackgroundTransparency=1,ZIndex=Z+3}); local eB=create("TextButton",{Name="Exit",Parent=head,Size=UDim2.fromOffset(40,40),Position=UDim2.new(1,-40,0,0),Text="X",TextColor3=Color3.fromRGB(220,220,220),TextSize=20,BackgroundTransparency=1,ZIndex=Z+3}); local sB=create("TextButton",{Name="Settings",Parent=head,Size=UDim2.fromOffset(40,40),Position=UDim2.new(1,-80,0,0),Text="⚙",TextColor3=Color3.fromRGB(220,220,220),TextSize=24,BackgroundTransparency=1,ZIndex=Z+3}); eB.MouseButton1Click:Connect(WindowManager.Destroy); side=create("ScrollingFrame",{Name="Sidebar",Parent=win,BackgroundColor3=Color3.fromRGB(55,55,55),BorderSizePixel=0,Size=UDim2.new(0,SIDEBAR_W,1,-HEADER_H),Position=UDim2.new(0,0,0,HEADER_H),AutomaticCanvasSize=Enum.AutomaticSize.Y,ZIndex=Z+1,ScrollBarImageColor3=Color3.fromRGB(120,120,120),ScrollBarThickness=4}); create("UIListLayout",{Parent=side,SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,5),HorizontalAlignment=Enum.HorizontalAlignment.Center}); create("UIPadding",{Parent=side,PaddingTop=UDim.new(0,5)}); cont=create("Frame",{Name="ContentArea",Parent=win,BackgroundColor3=Color3.fromRGB(40,40,40),BorderSizePixel=0,Size=UDim2.new(1,-SIDEBAR_W,1,-HEADER_H),Position=UDim2.new(0,SIDEBAR_W,0,HEADER_H),ClipsDescendants=true,ZIndex=Z+1}); local cF=create("Frame",{Name="ContentFrame",Parent=cont,BackgroundTransparency=1,Size=UDim2.new(1,0,1,0)}); local sF=create("Frame",{Name="SettingsFrame",Parent=cont,BackgroundTransparency=1,Size=UDim2.new(1,0,1,0),Visible=false}); resize=create("Frame",{Name="ResizeHandle",Parent=win,BackgroundTransparency=1,Size=UDim2.fromOffset(20,20),Position=UDim2.new(1,-20,1,-20),ZIndex=Z+3}); resize.InputBegan:Connect(function(i) onInputBegan(resize,i) end); UserInputService.InputChanged:Connect(onInputChanged); UserInputService.InputEnded:Connect(onInputEnded); return{tabContainer=side,contentContainer=cF,settingsContainer=sF,settingsButton=sB} end
    end

    -- ////////////////////////////////////////////////////////////////////////////////
    -- // Phase 3: The Element Renderer
    -- ////////////////////////////////////////////////////////////////////////////////
    local ElementRenderer = {}
    do
        local H, P, cont, rendered = 40, 10, nil, {}
        local function createBase(d) local f=create("Frame",{Name=d.uniqueID,BackgroundColor3=Color3.fromRGB(60,60,60),BorderSizePixel=0,Size=UDim2.new(1,0,0,H)}); create("UICorner",{Parent=f,CornerRadius=UDim.new(0,4)}); create("TextLabel",{Name="L",Parent=f,Size=UDim2.new(0.4,0,1,0),Position=UDim2.new(0,P,0,0),Text=d.label,TextColor3=Color3.fromRGB(240,240,240),Font=Enum.Font.SourceSans,TextSize=16,TextXAlignment=Enum.TextXAlignment.Left,BackgroundTransparency=1}); return f end
        local function rButton(d) local f=createBase(d); local b=create("TextButton",{Name="BC",Parent=f,Size=UDim2.new(0.5,-P,1,-10),Position=UDim2.new(0.5,0,0.5,0),AnchorPoint=Vector2.new(0,0.5),BackgroundColor3=Color3.fromRGB(80,80,80),Text=d.label,TextColor3=Color3.fromRGB(255,255,255),Font=Enum.Font.SourceSansSemibold,TextSize=16}); create("UICorner",{Parent=b,CornerRadius=UDim.new(0,4)}); f.L.Visible=false; b.MouseButton1Click:Connect(function() Engine.ExecuteCode(d.uniqueID) end); return f end
        local function rToggle(d) local f=createBase(d); local s=create("TextButton",{Name="TC",Parent=f,Size=UDim2.new(0,60,0,H-16),Position=UDim2.new(1,-P,0.5,0),AnchorPoint=Vector2.new(1,0.5),BackgroundColor3=Color3.fromRGB(40,40,40),Text=""}); create("UICorner",{Parent=s,CornerRadius=UDim.new(1,0)}); local k=create("Frame",{Name="K",Parent=s,Size=UDim2.new(0,24,0,24),AnchorPoint=Vector2.new(0.5,0.5),BackgroundColor3=Color3.fromRGB(200,200,200),BorderSizePixel=0}); create("UICorner",{Parent=k,CornerRadius=UDim.new(1,0)}); local function uV(v,a) local p=v and UDim2.new(1,-15,0.5,0) or UDim2.new(0,15,0.5,0); local c=v and Color3.fromRGB(70,180,90) or Color3.fromRGB(150,150,150); if a then local t=TweenService:Create(k,TweenInfo.new(0.2),{Position=p,BackgroundColor3=c}); t:Play() else k.Position,k.BackgroundColor3=p,c end end; s.MouseButton1Click:Connect(function() local el=Engine.GetElement(d.uniqueID); el.value=not el.value; uV(el.value,true); Engine.ExecuteCode(d.uniqueID) end); uV(d.value,false); rendered[d.uniqueID]={instance=f,updateFunc=uV}; return f end
        local function rSlider(d) local f=createBase(d); local pr=d.properties; local vL=create("TextLabel",{Name="VL",Parent=f,Size=UDim2.new(0,60,1,0),Position=UDim2.new(1,-P-60,0,0),BackgroundTransparency=1,Font=Enum.Font.SourceSans,TextSize=15,TextColor3=Color3.fromRGB(200,200,200)}); local t=create("Frame",{Name="T",Parent=f,Size=UDim2.new(0.6,-P-60,0,8),Position=UDim2.new(0.4,0,0.5,0),AnchorPoint=Vector2.new(0,0.5),BackgroundColor3=Color3.fromRGB(40,40,40)}); create("UICorner",{Parent=t,CornerRadius=UDim.new(1,0)}); local p=create("Frame",{Name="P",Parent=t,BackgroundColor3=Color3.fromRGB(85,125,255)}); create("UICorner",{Parent=p,CornerRadius=UDim.new(1,0)}); local isD=false; local function uV(v) local per=(v-pr.minValue)/(pr.maxValue-pr.minValue); p.Size=UDim2.new(per,0,1,0); local rV=math.floor((v/pr.increment)+0.5)*pr.increment; vL.Text=tostring(rV)..(pr.suffix or"") end; local function onI(i) local per=math.clamp((i.Position.X-t.AbsolutePosition.X)/t.AbsoluteSize.X,0,1); local raw=pr.minValue+(pr.maxValue-pr.minValue)*per; local st=math.clamp(math.floor(raw/pr.increment+0.5)*pr.increment,pr.minValue,pr.maxValue); if Engine.GetElement(d.uniqueID).value~=st then Engine.GetElement(d.uniqueID).value=st; uV(st); Engine.ExecuteCode(d.uniqueID) end end; t.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then isD=true onI(i) end end); UserInputService.InputChanged:Connect(function(i) if isD and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then onI(i) end end); UserInputService.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then isD=false end end); uV(d.value); rendered[d.uniqueID]={instance=f,updateFunc=uV}; return f end
        local dispatch={Button=rButton,Toggle=rToggle,Slider=rSlider}
        function ElementRenderer.CreateContentPage(d) if cont:FindFirstChild(d.uniqueID) then return end; local p=create("Frame",{Name=d.uniqueID,Parent=cont,Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Visible=false}); local s=create("ScrollingFrame",{Name="LF",Parent=p,Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,AutomaticCanvasSize=Enum.AutomaticSize.Y,BorderSizePixel=0,ScrollBarImageColor3=Color3.fromRGB(150,150,150),ScrollBarThickness=6}); create("UIListLayout",{Parent=s,SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,P),HorizontalAlignment=Enum.HorizontalAlignment.Center}); create("UIPadding",{Parent=s,PaddingLeft=UDim.new(0,10),PaddingRight=UDim.new(0,10),PaddingTop=UDim.new(0,10)}); return p end
        function ElementRenderer.DestroyContentPage(id) local p=cont and cont:FindFirstChild(id); if p then p:Destroy() end end
        local function onAdd(d) local p=cont:FindFirstChild(d.targetTabID); if not p then return end; local rF=dispatch[d.type]; if rF then local i=rF(d); i.Parent=p.LF; if not rendered[d.uniqueID] then rendered[d.uniqueID]={instance=i} end end end
        local function onRem(id) if rendered[id] then rendered[id].instance:Destroy() rendered[id]=nil end end
        local function onVal(id,v) local r=rendered[id]; if r and r.updateFunc then r.updateFunc(v,true) end end
        function ElementRenderer.Init(e, c) Engine,cont=e,c.contentContainer; for _,t in ipairs(Engine.Registry.Tabs) do ElementRenderer.CreateContentPage(t) end; Engine.Signals.ElementAdded:Connect(onAdd); Engine.Signals.ElementRemoved:Connect(onRem); Engine.Signals.ElementValueChanged:Connect(onVal) end
    end

    -- ////////////////////////////////////////////////////////////////////////////////
    -- // Phase 4: The Settings Panel
    -- ////////////////////////////////////////////////////////////////////////////////
    local SettingsPanel = {}
    do
        local cont, activeID, editPanel
        local function createSec(n, o, p) local f=create("Frame",{Name=n.."S",Parent=p,BackgroundTransparency=1,Size=UDim2.new(1,-20,0,0),AutomaticSize=Enum.AutomaticSize.Y,LayoutOrder=o}); local l=create("UIListLayout",{Parent=f,SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,5)}); create("TextLabel",{Name="H",Parent=f,LayoutOrder=1,Size=UDim2.new(1,0,0,25),Text=n,Font=Enum.Font.SourceSansBold,TextSize=20,TextColor3=Color3.fromRGB(255,255,255),TextXAlignment=Enum.TextXAlignment.Left,BackgroundTransparency=1}); return f,l end
        local function createBtn(t, p, o) local b=create("TextButton",{Name=t,Parent=p,LayoutOrder=o,Size=UDim2.new(1,0,0,35),BackgroundColor3=Color3.fromRGB(80,80,80),Text=t,TextColor3=Color3.fromRGB(255,255,255),Font=Enum.Font.SourceSansSemibold,TextSize=16}); create("UICorner",{Parent=b,CornerRadius=UDim.new(0,4)}); return b end
        local function createInput(ph, p, o, h) local f=create("Frame",{Name=ph.."IF",Parent=p,LayoutOrder=o,Size=UDim2.new(1,0,0,h or 30),BackgroundColor3=Color3.fromRGB(30,30,30)}); create("UICorner",{Parent=f,CornerRadius=UDim.new(0,4)}); local tB=create("TextBox",{Name="I",Parent=f,Size=UDim2.new(1,-10,1,-10),Position=UDim2.new(0.5,0,0.5,0),AnchorPoint=Vector2.new(0.5,0.5),BackgroundTransparency=1,PlaceholderText=ph,PlaceholderColor3=Color3.fromRGB(150,150,150),Text="",TextColor3=Color3.fromRGB(220,220,220),Font=Enum.Font.SourceSans,TextSize=14,ClearTextOnFocus=false}); return f,tB end
        local function clearEdit() for i,c in ipairs(editPanel:GetChildren()) do if i>1 then c:Destroy() end end; editPanel.Visible=false; activeID=nil end
        local function populateEdit(d) clearEdit(); d=d or {}; local _,nI=createInput("Display Name",editPanel,2); local _,idI=createInput("Unique ID",editPanel,3); local _,tI=createInput("Target Tab ID",editPanel,4); local _,tyI=createInput("Type (Button,Toggle,Slider)",editPanel,5); local _,lI=createInput("Lua Code",editPanel,6,120); lI.MultiLine,lI.TextXAlignment,lI.TextYAlignment=true,Enum.TextXAlignment.Left,Enum.TextYAlignment.Top; nI.Text,idI.Text,tI.Text,tyI.Text,lI.Text=d.label or"",d.uniqueID or"",d.targetTabID or"",d.type or"",d.luaCode or""; local sB=createBtn("Save",editPanel,7); local cB=createBtn("Cancel",editPanel,8); cB.BackgroundColor3=Color3.fromRGB(120,60,60); cB.MouseButton1Click:Connect(clearEdit); sB.MouseButton1Click:Connect(function() local nD={label=nI.Text,uniqueID=idI.Text,targetTabID=tI.Text,type=tyI.Text,luaCode=lI.Text,properties={defaultValue=(tyI.Text=="Toggle" and false) or(tyI.Text=="Slider" and 50) or nil,minValue=0,maxValue=100,increment=1,suffix=""}}; if activeID then Engine.UpdateElement(activeID,nD) else Engine.AddElement(nD) end; clearEdit() end); editPanel.Visible=true end
        function SettingsPanel.Init(e, c) Engine,cont=e,c.settingsContainer; create("UIListLayout",{Parent=cont,Padding=UDim.new(0,15),HorizontalAlignment=Enum.HorizontalAlignment.Center}); create("UIPadding",{Parent=cont,PaddingLeft=UDim.new(0,10),PaddingRight=UDim.new(0,10),PaddingTop=UDim.new(0,10)}); local cS,_=createSec("Config",1,cont); local _,iB=createInput("Paste config or use button...",cS,2,80); iB.MultiLine,iB.TextXAlignment,iB.TextYAlignment=true,Enum.TextXAlignment.Left,Enum.TextYAlignment.Top; local iBtn=createBtn("Import From Clipboard",cS,3); local eBtn=createBtn("Export To Clipboard",cS,4); iBtn.MouseButton1Click:Connect(function() if getclipboard and #iB.Text==0 then iB.Text=getclipboard() or "" end; if iB.Text and #iB.Text>0 then Engine.LoadConfigurationFromString(iB.Text) end end); eBtn.MouseButton1Click:Connect(function() Engine.Signals.SaveToClipboard:Fire() end); local tS,_=createSec("Tabs",2,cont); local _,tN=createInput("New Tab Name",tS,2); createBtn("Add Tab",tS,3).MouseButton1Click:Connect(function() if tN.Text:match("%S") then Engine.AddTab({uniqueID=tN.Text:lower():gsub("%s+","_"),label=tN.Text}); tN.Text="" end end); local eS,_=createSec("Elements",3,cont); editPanel,_=createSec("Create/Edit",4,cont); editPanel.Visible=false; createBtn("Create Element",eS,3).MouseButton1Click:Connect(function() activeID=nil; populateEdit() end) end
    end

    ----------------------------------------------------------------------------------
    -- FINAL LIBRARY OBJECT AND INITIALIZER
    ----------------------------------------------------------------------------------
    local Nexus = {}

    function Nexus:CreateWindow(settings)
        print("Nexus-Lua: Initializing Unified GUI System v2.0...")

        if not game:IsLoaded() then game.Loaded:Wait() end

        local containers = WindowManager.Init()
        ElementRenderer.Init(Engine, containers)
        SettingsPanel.Init(Engine, containers)

        local isSettingsVisible = false
        local function toggleSettingsView() isSettingsVisible=not isSettingsVisible; containers.settingsContainer.Visible=isSettingsVisible; containers.contentContainer.Visible=not isSettingsVisible end
        containers.settingsButton.MouseButton1Click:Connect(toggleSettingsView)

        local activeTabButton = nil
        local function selectTab(tabButton, page)
            for _, child in ipairs(containers.contentContainer:GetChildren()) do child.Visible = false end
            page.Visible = true
            if isSettingsVisible then toggleSettingsView() end
            if activeTabButton then activeTabButton.BackgroundColor3 = Color3.fromRGB(65, 65, 65) end
            tabButton.BackgroundColor3 = Color3.fromRGB(85, 125, 255)
            activeTabButton = tabButton
        end

        Engine.Signals.TabAdded:Connect(function(tabData)
            local page = ElementRenderer.CreateContentPage(tabData)
            local sidebar = containers.tabContainer
            local tabButton = create("TextButton", { Name = tabData.uniqueID, Parent = sidebar, Size = UDim2.new(1, -10, 0, 35), BackgroundColor3 = Color3.fromRGB(65, 65, 65), Text = tabData.label, TextColor3 = Color3.fromRGB(230, 230, 230), Font = Enum.Font.SourceSansSemibold, TextSize = 16 })
            create("UICorner", { Parent = tabButton, CornerRadius = UDim.new(0, 4) })
            tabButton.MouseButton1Click:Connect(function() selectTab(tabButton, page) end)
            if not activeTabButton then task.wait(); selectTab(tabButton, page) end
        end)
        
        Engine.Signals.TabRemoved:Connect(function(tabID)
            ElementRenderer.DestroyContentPage(tabID)
            local button = containers.tabContainer:FindFirstChild(tabID)
            if button then local selectNew=#containers.tabContainer:GetChildren()>1 and activeTabButton==button; activeTabButton=(activeTabButton==button) and nil or activeTabButton; button:Destroy(); if selectNew then local nextBtn=containers.tabContainer:GetChildren()[1]; if nextBtn then selectTab(nextBtn, containers.contentContainer:FindFirstChild(nextBtn.Name)) end end end
        end)

        Engine.Signals.SaveToClipboard:Connect(function()
            local dataToSave = { Registry = Engine.Registry }
            local s, encoded = pcall(function() return HttpService:JSONEncode(dataToSave) end)
            if s and setclipboard then setclipboard(encoded); Engine.API.Notify("System", "Config copied!") else Engine.API.Notify("Error", "Export failed.") end
        end)
        
        print("GUI System: Connections established.")

        task.delay(0.5, function()
            if #Engine.Registry.Tabs == 0 then
                print("GUI System: No config. Creating default setup.")
                Engine.AddTab({ uniqueID = "main", label = "Main" })
                Engine.AddElement({ uniqueID = "welcome", label = "Welcome!", type = "Button", targetTabID = "main", properties = {}, luaCode = [[ API.Notify("Welcome", "This is the Nexus-Lua GUI system.") ]] })
            end
        end)
        
        print("Nexus-Lua: GUI System launch complete.")
        return Nexus 
    end

    function Nexus:Destroy()
        WindowManager.Destroy()
    end
    
    return Nexus
end

-- The final line returns the library, ready to be used.
return CreateNexusGUILibrary()
