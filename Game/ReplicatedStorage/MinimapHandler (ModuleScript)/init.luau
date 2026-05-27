-- ============================================================
--  Ce script gère un système de minimap dynamique à l'aide de ViewportFrames.
--  Il permet le traitement optimisé de la géométrie, le tracking de caméra/joueur,
--  et l'affichage en temps réel d'indicateurs visuels et de points de repère.
-- ============================================================

local CS = game:GetService("CollectionService")
local RS = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AntiTimeoutKey = "LoadMap"
local AntiTimeout = require(script.AntiTimeout); AntiTimeout.Register(AntiTimeoutKey, 4)
local WaypointTemplate = script.WaypointFrame

local AutoColorCorrect = false
local ObstructedIgnore = "MinimapIgnore"
local HideFromMinimap = "MinimapHide"
local TrackBind = "MinimapTrackCam"
local WaypointBind = "MinimapWaypointMove"
local IndicatorBind = "MinimapIndicatorMove"
local CreationTag = "_MinimapModule:Module:"..tick()

local FastClassCheck = {
Model = true, Folder = true, Configuration = true,
FileMesh = true, SpecialMesh = true, BevelMesh = true,
BlockMesh = true, CylinderMesh = true, CharacterMesh = true,
Decal = false, Texture = true
}

local function Lerp(x:number, y:number, delta:number):number
return x + (y - x) * delta
end

local Operations = {
{1, 1, 1}, {-1, 1, -1}, {1, 1, 1, true}, {-1, 1, -1, true},
{0.5, 0.5, 0.5}, {-0.5, 0.5, -0.5}, {0.5, 0.5, 0.5, true}, {-0.5, 0.5, -0.5, true},
{0.25, 0.25, 0.25}, {-0.25, 0.25, -0.25}, {0.25, 0.25, 0.25, true}, {-0.25, 0.25, -0.25, true},
}
local BasicOp = {
{1, 1, 1}, {-1, 1, -1}, {1, 1, 1, true}, {-1, 1, -1, true},
}

-- Algorithme de calcul des sommets tridimensionnels de la pièce pour le raycasting
local function GetCorners(inst:BasePart, Basic:boolean?)
local CurrentTab = Basic and BasicOp or Operations
local FoundCorners = {}
local cFrame = inst.CFrame
local size = inst.Size

for _, Operation in CurrentTab do
	local X,Y,Z,Flip = Operation[1], Operation[2], Operation[3], (Operation[4] or false)
	local X2,Y2,Z2

	if Flip then
		cFrame *= CFrame.Angles(0, math.rad(90), 0)
		X2,Y2,Z2 = size.Z, size.Y, size.X
	else
		X2,Y2,Z2 = size.X, size.Y, size.Z
	end

	local CornerCFrame = cFrame * CFrame.new(X2/2 * X, Y2/2 * Y, Z2/2 * Z)
	table.insert(FoundCorners, CornerCFrame.Position)
end

return FoundCorners
end

local function ValidClass(inst:Instance):boolean
if inst:IsA("BasePart") and not inst:IsA("Terrain") then
return true
end
return FastClassCheck[inst.ClassName] == true
end

local function GetMainAncestors(tab:{Instance}, MainParent:Instance):{Instance}
local FinalTab = {}
for _, inst in ipairs(tab) do
local FoundParent = nil
local CurrentInst = inst
repeat
local CurrentParent = CurrentInst.Parent
if CurrentParent ~= MainParent then
FoundParent = CurrentParent
CurrentInst = CurrentParent
else
break
end
until not CurrentParent

	FoundParent = FoundParent or inst
	if not table.find(FinalTab, FoundParent) then
		table.insert(FinalTab, FoundParent)
	end
end
return FinalTab
end

-- Processus d'exclusion des parties cachées via détection de boîtes d'occlusion et de tracés de rayons (Raycasting)
local function GetValidParts(WorldModel:WorldModel, MapToScan:Instance, tab:{Instance}, CamPosition:Vector3, HideObstructed:boolean?, DebugEnabled:boolean?, PrintWarnings:boolean?):{Instance}
local ValidParts = {}
local StartTime = tick()

if PrintWarnings then
	local Warned = false
	if #tab >= 45000 and HideObstructed then
		Warned = true
		warn("Minimap: The selected map has a very high part count ("..#tab.."), the loading process may cause temporary lag.")
	elseif #tab >= 20000 and not HideObstructed then
		Warned = true
		warn("Minimap: The selected map has a very high part count ("..#tab.."), performance may suffer.")
	end
	if Warned then
		warn("Minimap: To disable warnings like this, see Minimap.ExtraWarnings")
	end
end

if DebugEnabled then
	print("(Loading) Map part count: "..#tab)
end

local RayParams = RaycastParams.new()
RayParams.IgnoreWater = true
RayParams.RespectCanCollide = false

local BoundParams = OverlapParams.new()
BoundParams.RespectCanCollide = false

for i, inst in ipairs(tab) do
	if i % 1000 == 0 then task.wait() end 
	AntiTimeout.Checkup(AntiTimeoutKey)

	if inst:IsA("BasePart") then
		if inst.Transparency >= 0.25 or CS:HasTag(inst, HideFromMinimap) or CS:HasTag(inst, ObstructedIgnore) then
			continue
		end

		local Visible = false

		if HideObstructed then
			local RayPoints = GetCorners(inst)
			table.insert(RayPoints, 1, inst.Position)
			local IsUnion = inst:IsA("UnionOperation") or inst:IsA("MeshPart")

			if IsUnion then 
				Visible = true
				local SizeY = 300 
				local PosOffsetY = 2
				local PosOffset = Vector3.new(0, SizeY/2 + PosOffsetY, 0)
				local SearchSize = Vector3.new(0, SizeY - PosOffsetY, 0)
				local Overlaps = 0
				local OverlapLimit = #RayPoints - 2

				for _, Pos in ipairs(RayPoints) do
					local SearchPos = Pos + PosOffset
					local SearchCFrame = CFrame.new(SearchPos)
					local Overlapping = Workspace:GetPartBoundsInBox(SearchCFrame, SearchSize, BoundParams)

					if #Overlapping >= 2 then
						Overlaps += 1
						if Overlaps >= OverlapLimit then
							Visible = false
							break
						end
					end
				end
			else 
				Visible = false
				local RayPosition = Vector3.new(inst.Position.X, CamPosition.Y, inst.Position.Z)

				for _, Pos in ipairs(RayPoints) do
					local PosDistance = (RayPosition - Pos).Magnitude
					local NewRot = CFrame.lookAt(RayPosition, Pos).LookVector * (PosDistance + 0.1)
					local ray = Workspace:Raycast(RayPosition, NewRot, RayParams)

					if ray and ray.Instance == inst then
						Visible = true
						break
					end
				end
			end
		else
			Visible = true
		end

		if Visible then
			table.insert(ValidParts, inst)
		end
	end
end

if DebugEnabled then
	print("(Loading) Tock "..(tick() - StartTime))
	print("(Loading) Final visible part count: "..#ValidParts)
end

return ValidParts
end

local function ClearViewport(MapFolder:Instance)
for _, inst in MapFolder:GetChildren() do
inst:Destroy()
end
end

local function FindUICorner(Frame:Instance):UICorner?
return Frame:FindFirstChildWhichIsA("UICorner")
end

local function GetCornerMagnitude(Frame:Frame|ViewportFrame, UICorner:UICorner):number
local Absolute = Frame.AbsoluteSize
local Corner = UICorner.CornerRadius
local AxisMin = math.min(Absolute.X, Absolute.Y)

local ScaleMax = 0.5 
local OffsetMax = AxisMin/2
local ScaleMag = math.clamp(Corner.Scale, 0, ScaleMax)
local OffsetMag = math.clamp(Corner.Offset, 0, OffsetMax)

return (ScaleMag * AxisMin) + OffsetMag
end

-- Ajustement des coordonnées de l'interface graphique pour épouser les bordures arrondies de l'interface parente
local function FitToCorner(Frame:Frame|ViewportFrame, Position:Vector2):Vector2
local UICorner = FindUICorner(Frame)

if UICorner and UICorner.CornerRadius ~= UDim.new(0,0) then
	local Absolute = Frame.AbsoluteSize
	local MainMagnitude = GetCornerMagnitude(Frame, UICorner)

	local XResult = Absolute.X - MainMagnitude
	local YResult = Absolute.Y - MainMagnitude
	local Corner1 = Vector2.new(MainMagnitude,MainMagnitude)
	local Corner2 = Vector2.new(MainMagnitude,YResult)
	local Corner3 = Vector2.new(XResult, MainMagnitude)
	local Corner4 = Vector2.new(XResult, YResult)

	local OnLeft, OnCorner

	if Position.X < Corner1.X and Position.Y < Corner1.Y then
		OnLeft = true; OnCorner = Corner1
	elseif Position.X < Corner2.X  and Position.Y > Corner2.Y then
		OnLeft = true; OnCorner = Corner2
	elseif Position.X > Corner3.X and Position.Y < Corner3.Y then
		OnLeft = false; OnCorner = Corner3
	elseif Position.X > Corner4.X and Position.Y > Corner4.Y then
		OnLeft = false; OnCorner = Corner4
	else
		OnCorner = Position
	end

	local CenterMagnitude = (Position - OnCorner).Magnitude

	if CenterMagnitude > MainMagnitude then
		local Change = Vector2.new(math.abs(Position.X - OnCorner.X), math.abs(Position.Y - OnCorner.Y))
		local Acos = math.acos(Change.Y/CenterMagnitude)
		local XVector = MainMagnitude * math.sin(Acos)
		local YVector = MainMagnitude * math.cos(Acos)

		if OnLeft then
			return OnCorner - Vector2.new(XVector, YVector)
		else
			return OnCorner + Vector2.new(XVector, YVector)
		end
	end
end
return Position
end

local function NextFrame(LastTick:number, FrameLimit:number):boolean
return (tick() - LastTick) >= 1/FrameLimit
end

local function ClearInstances(tab:{})
local ToRemove = {}
local TaggedRemove = {"MapHolder", "TrackerCamera", "TrackerPart"}

for i, v in tab do
	if table.find(ToRemove, i) then
		v:Destroy()
	elseif table.find(TaggedRemove, i) then
		if CS:HasTag(v, "_ModuleCreated") then
			v:Destroy()
		end
	end
end
end

-- Génération asynchrone des modèles au sein du ViewportFrame avec option d'aplatissement (2D Flattening)
local function LoadInto(Self, MapHolder:Instance, FinalHolder:Instance, ClearMap:boolean?):{}
local CameraPosition = Self.CameraPosition
local HideObstructed = Self.HideObstructed
local Flatten = Self.Flatten
local DebugEnabled = Self.DebugEnabled
local PrintWarnings = Self.ExtraWarnings

local Descendants = MapHolder:GetDescendants()
local ValidParts = GetValidParts(Workspace, MapHolder, Descendants, CameraPosition, HideObstructed, DebugEnabled, PrintWarnings)
local AddedInstances = {}

if ClearMap then
	ClearViewport(FinalHolder)
end

for i, inst in ipairs(ValidParts) do
	if i % 500 == 0 then task.wait() end 
	AntiTimeout.Checkup(AntiTimeoutKey)

	local InstClone = inst:Clone()
	if InstClone:IsA("BasePart") then
		InstClone.CastShadow = false
	end

	for _, child in ipairs(InstClone:GetDescendants()) do
		if not ValidClass(child) then
			child:Destroy()
		elseif child:IsA("BasePart") then
			child.Anchored = true
			child.Material = Enum.Material.SmoothPlastic
			child.CastShadow = false
		end
	end

	InstClone.Anchored = true
	
	CS:AddTag(InstClone, CreationTag)
	CS:AddTag(InstClone, Self._Hidden._TrackingString)
	InstClone.Parent = FinalHolder

	table.insert(AddedInstances, InstClone)
end

if Flatten then
	table.sort(AddedInstances, function(a,b)
		return a.Position.Y < b.Position.Y
	end)

	local AddSize = 0.004
	local HighestPart = AddedInstances[#AddedInstances]
	if HighestPart then
		local LowestPart = AddedInstances[1]
		local LastYPos = LowestPart.Position.Y - AddSize

		for _, inst in ipairs(AddedInstances) do
			AntiTimeout.Checkup(AntiTimeoutKey)
			if inst:IsA("BasePart") then
				LastYPos += AddSize
				local Pos = inst.Position
				local Rot = inst.Rotation
				local Size = inst.Size

				inst.Rotation = Vector3.new(0, Rot.Y, 0)
				inst.Size = Vector3.new(Size.X, AddSize, Size.Z)
				inst.Position = Vector3.new(Pos.X, LastYPos, Pos.Z)
			end
		end
	end
end

return AddedInstances
end

local MainHandler = {}
MainHandler.__index = MainHandler

-- Constructeur principal initialisant les Viewports de rendu, les structures de données cachées et les boucles RenderStep
function MainHandler.new(Viewport:ViewportFrame, CameraPosition:Vector3, MapHolder:Instance?)
if Viewport and CameraPosition then
if AutoColorCorrect then
Viewport.Ambient = Color3.fromRGB(320,330,345)
Viewport.LightColor = Color3.fromRGB(0,0,0)
Viewport.ImageColor3 = Color3.fromRGB(240, 250, 255)
Viewport.LightDirection = Vector3.new(0, -1, 0)
end

	local TrackerViewport = Instance.new("ViewportFrame", Viewport)
	TrackerViewport.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
	TrackerViewport.BackgroundTransparency = 1
	TrackerViewport.Size = UDim2.new(1,0,1,0)
	TrackerViewport.Name = "_Indicator:AlwaysOnTop"
	TrackerViewport.CurrentCamera = Instance.new("Camera", TrackerViewport)

	local TrackViewCorner = Instance.new("UICorner", TrackerViewport)
	TrackViewCorner.CornerRadius = UDim.new(0,0)

	local TrackerModel = Instance.new("WorldModel", Viewport)
	TrackerModel.Name = "_IndicatorModel"

	local enumTable = {Fixed = 0, Rotate = 1, Position = 2, FullTrack = 3}
	local self = setmetatable({TrackModes = enumTable}, MainHandler)

	self.MapHolder = MapHolder or Instance.new("Folder")
	self.CameraPosition = CameraPosition
	self.CameraRotation = CFrame.new()
	self.TrackerCamera = Instance.new("Camera")
	self.TrackerPart = Instance.new("Part")
	self.TrackerMaxAngle = -90
	self.TrackerMinAngle = -90
	self.HideObstructed = false
	self.WaypointAutoSize = true
	self.WaypointEdges = false
	self.Flatten = false
	self.Rotation2D = 0
	self.FPSCap = 75
	self.DebugEnabled = false
	self.ExtraWarnings = true

	local HiddenSettings = {}

	HiddenSettings._Viewport = Viewport
	HiddenSettings._LastMapHolder = nil
	HiddenSettings._CachedHolders = {}
	HiddenSettings._MapFolder = Instance.new("Folder", Viewport)
	HiddenSettings._TrackerViewport = TrackerViewport
	HiddenSettings._TrackerModel = TrackerModel
	HiddenSettings._Tracking = false
	HiddenSettings._TrackingString = tostring(tick())
	HiddenSettings._ActiveIndicators = {}
	HiddenSettings._ActiveWaypoints = {}
	HiddenSettings._IndicatorSettings = {}
	HiddenSettings._IndicatorCurrentLayer = -100000
	HiddenSettings._TrackLastTick = tick()
	HiddenSettings._IndicatorLastTick = tick()

	HiddenSettings._MapFolder.Name = "_MapContents"

	self._Hidden = setmetatable(HiddenSettings, self)

	if not Viewport.CurrentCamera then
		Viewport.CurrentCamera = Instance.new("Camera", Viewport)
	end

	CS:AddTag(self.TrackerCamera, "_ModuleCreated")
	CS:AddTag(self.TrackerPart, "_ModuleCreated")

	if not MapHolder then
		CS:AddTag(self.MapHolder, "_ModuleCreated")
	end

	RS:BindToRenderStep(WaypointBind..HiddenSettings._TrackingString, 2001, function()
		local AutoSize = self.WaypointAutoSize
		local ShowEdge = self.WaypointEdges
		local _Hidden = self._Hidden
		local Viewport = _Hidden._Viewport
		local TableName = "_ActiveWaypoints"

		if Viewport then
			local Camera = Viewport.CurrentCamera

			if Camera then
				for Name, tab in _Hidden[TableName] do
					local OrigCFrame = Camera.CFrame

					local Waypoint:Frame = tab.Waypoint
					local Position:Vector3 = tab.Position
					local Vector:Vector3 = Camera:WorldToViewportPoint(Position)

					if Vector.Z <= 0 then
						Camera.CFrame *= CFrame.Angles(0, math.rad(180), 0)
						local NewVector = Camera:WorldToViewportPoint(Position)
						Vector = Vector3.new(-NewVector.X, NewVector.Y, -NewVector.Z)
						Camera.CFrame = OrigCFrame
					end

					local ScreenPos = Vector2.new(Vector.X, Vector.Y) * Viewport.AbsoluteSize
					local OrigPos = ScreenPos

					local SizeAttribute = "WaypointOriginalSize"
					local OriginalSize:UDim2 = Waypoint:GetAttribute(SizeAttribute)
					local Divisor = 1.4
					local SizeLerp = 0.2

					if not OriginalSize then
						Waypoint:SetAttribute(SizeAttribute, Waypoint.Size)
						OriginalSize = Waypoint.Size
					end

					if ShowEdge then
						local Inset = 0
						local CorneredPos = FitToCorner(Viewport, ScreenPos)
						local X = math.clamp(CorneredPos.X, Inset, Viewport.AbsoluteSize.X - Inset)
						local Y = math.clamp(CorneredPos.Y, Inset, Viewport.AbsoluteSize.Y - Inset)
						ScreenPos = Vector2.new(X,Y)
					end

					local Visible = (ScreenPos == OrigPos)

					if AutoSize then
						if Visible or not ShowEdge then
							Waypoint.Size = Waypoint.Size:Lerp(OriginalSize, SizeLerp)
						elseif ShowEdge then
							local DivSize = UDim2.new(OriginalSize.X.Scale/Divisor, 0, OriginalSize.Y.Scale/Divisor, 0)
							Waypoint.Size = Waypoint.Size:Lerp(DivSize, SizeLerp)
						end
					end

					Waypoint.Position = UDim2.new(0, ScreenPos.X, 0, ScreenPos.Y)
					Waypoint.Parent = Viewport
					Waypoint.ZIndex = Viewport.ZIndex + 1
				end
			end
		end
	end)


	RS:BindToRenderStep(IndicatorBind..HiddenSettings._TrackingString, Enum.RenderPriority.Camera.Value - 2, function()
		local _Hidden = self._Hidden
		local Viewport = _Hidden._Viewport
		local TableName = "_ActiveIndicators"

		if NextFrame(_Hidden._IndicatorLastTick, self.FPSCap) then
			_Hidden._IndicatorLastTick = tick()
			if Viewport then
				local Camera = Viewport.CurrentCamera

				if Camera then
					TrackerViewport.CurrentCamera = Camera
					local TrackViewCam = TrackerViewport.CurrentCamera

					TrackerViewport.ZIndex = Viewport.ZIndex + 1
					TrackerViewport.Ambient = Viewport.Ambient
					TrackerViewport.LightColor = Viewport.LightColor
					TrackerViewport.LightDirection = Viewport.LightDirection
					TrackerViewport.ImageColor3 = Viewport.ImageColor3
					TrackerViewport.ImageTransparency = Viewport.ImageTransparency
					TrackViewCam.FieldOfView = Camera.FieldOfView
					TrackViewCam.FieldOfViewMode = Camera.FieldOfViewMode

					local ViewportCorner = Viewport:FindFirstChildWhichIsA("UICorner")

					if ViewportCorner then
						TrackViewCorner.CornerRadius = ViewportCorner.CornerRadius
					else
						TrackViewCorner.CornerRadius = UDim.new(0,0)
					end

					local Table = _Hidden[TableName]

					for Name, tab in Table do
						local Indicator = tab.Indicator
						local TrackPart = tab.Part
						local RotOffset = tab.RotOffset
						local TrackCamera = tab.Camera
						local Visible = tab.Visible
						local OnTop = tab.AlwaysOnTop
						local YOffset = tab._YOffset

						local ToRemove = false

						if TrackPart then
							if TrackPart:FindFirstAncestorWhichIsA("DataModel") then
								if Visible then
									local TrackerPos
									local TrackerRot

									if TrackPart:IsA("Model") then
										local Pivot = TrackPart:GetPivot()
										TrackerPos = Pivot.Position
										TrackerRot = Pivot.Rotation
									else
										local Pivot = TrackPart.CFrame
										TrackerPos = TrackPart.Position
										TrackerRot = Pivot.Rotation
									end

									if not CS:HasTag(TrackCamera, "_ModuleCreated") then
										TrackerRot = TrackCamera.CFrame.Rotation
									end

									local IndicatorPos = Vector3.new(TrackerPos.X, math.min(Camera.CFrame.Position.Y - 30, (TrackerPos.Y + YOffset)), TrackerPos.Z)
									local RX,RY,RZ = TrackerRot:ToOrientation()
									local IndicatorRot = CFrame.fromOrientation(0,RY,0)
									local OffsetAngles = CFrame.Angles(math.rad(RotOffset.X), math.rad(RotOffset.Y), math.rad(RotOffset.Z))
									local IndicateCFrame = CFrame.new(IndicatorPos) * IndicatorRot * OffsetAngles

									if Indicator:IsA("Model") then
										Indicator:PivotTo(IndicateCFrame)
									elseif Indicator:IsA("BasePart") then
										Indicator.CFrame = IndicateCFrame
									else
										ToRemove = true
										warn("Indicator is not a valid class! (BasePart or Model)")
									end

									if not OnTop then
										Indicator.Parent = TrackerModel
									else
										Indicator.Parent = TrackerViewport
									end
								else
									Indicator.Parent = nil
								end
							else
								ToRemove = true
							end
						else
							ToRemove = true
						end

						if ToRemove then
							Indicator:Destroy()
							Table[Name] = nil
						end
					end
				end
			end
		end
	end)

	self._Connections = {}
	return self
else
	error("Missing required argument(s)!")
end
end

function MainHandler:Destroy()
local _Hidden = self._Hidden
_Hidden._TrackerViewport:Destroy()
_Hidden._TrackerModel:Destroy()
_Hidden._MapFolder:Destroy()

for _, tab in _Hidden._CachedHolders do
	local Holder = tab.MapHolder
	local Contents = tab.Contents
	Contents:Destroy()
end

for _, Connection in self._Connections do
	Connection:Disconnect()
end

RS:UnbindFromRenderStep(TrackBind.._Hidden._TrackingString)
RS:UnbindFromRenderStep(WaypointBind.._Hidden._TrackingString)
RS:UnbindFromRenderStep(IndicatorBind.._Hidden._TrackingString)

ClearInstances(self)

setmetatable(self._Hidden, nil)
setmetatable(self, nil)
table.clear(self)
end

function MainHandler:AddIndicator(Name:string, Template:Model|BasePart, Part:BasePart)
local _Hidden = self._Hidden
local Viewport = _Hidden._Viewport

if Viewport and typeof(Name) == "string" and typeof(Template) == "Instance" and typeof(Part) == "Instance" then
	local TableName = "_ActiveIndicators"
	local MainTab = _Hidden[TableName]
	local ExistingFound = MainTab[Name]

	if ExistingFound then
		ExistingFound.Indicator:Destroy()
		MainTab[Name] = nil
	end

	local Indicator = Template:Clone()
	local LayerName = "_IndicatorCurrentLayer"

	local Settings = setmetatable({}, _Hidden._IndicatorSettings)
	Settings.Indicator = Indicator
	Settings.Part = Part
	Settings.RotOffset = Vector3.zero
	Settings.Camera = Instance.new("Camera")
	Settings.Visible = true
	Settings.AlwaysOnTop = false

	_Hidden[LayerName] += 1
	if _Hidden[LayerName] > 100000 then
		_Hidden[LayerName] = -100000
	end

	Settings._YOffset  = _Hidden[LayerName]/1000000 

	CS:AddTag(Settings.Camera, "_ModuleCreated")

	MainTab[Name] = Settings
	return Settings
elseif Viewport then
	error("Invalid argument(s)!")
else
	error("No viewport selected for creating indicators!")
end
end

function MainHandler:RemoveIndicator(Name:string)
local _Hidden = self._Hidden

if typeof(Name) == "string" then
	local TableName = "_ActiveIndicators"
	local MatchingTab = _Hidden[TableName]

	MatchingTab[Name].Indicator:Destroy()
	MatchingTab[Name] = nil
else
	error("Invalid argument!")
end
end

function MainHandler:ClearIndicators()
local _Hidden = self._Hidden
local TableName = "_ActiveIndicators"
local MatchingTab = _Hidden[TableName]

for Name, tab in MatchingTab do
	tab.Indicator:Destroy()
	MatchingTab[Name] = nil
end
end

function MainHandler:AddWaypoint(Name:string, Position:Vector3, ImageOrText:string?, BackgroundColor:Color3?)
local _Hidden = self._Hidden
local Viewport = _Hidden._Viewport

if Viewport and typeof(Name) == "string" and typeof(Position) == "Vector3" then
	local TableName = "_ActiveWaypoints"
	local MainTab = _Hidden[TableName]
	local ExistingFound = MainTab[Name]

	if ExistingFound then
		ExistingFound.Waypoint:Destroy()
		MainTab[Name] = nil
	end

	local WaypointClone = WaypointTemplate:Clone()
	local IsImage = false
	local NewColor = BackgroundColor or Color3.new(1, 1, 1)

	if ImageOrText then
		if string.find(ImageOrText, "rbxassetid://") then
			IsImage = true
		else
			IsImage = false
		end

		local ImageLabel = WaypointClone.WaypointImage
		local TextLabel = WaypointClone.WaypointText

		if IsImage then
			ImageLabel.Image = ImageOrText
		else
			TextLabel.Text = ImageOrText
		end
	end

	_Hidden[TableName][Name] = {Waypoint = WaypointClone, Position = Position}
	return WaypointClone
elseif Viewport then
	error("Invalid argument(s)!")
else
	error("No viewport selected for setting waypoints!")
end
end

function MainHandler:RemoveWaypoint(Name:string)
local _Hidden = self._Hidden

if typeof(Name) == "string" then
	local TableName = "_ActiveWaypoints"
	local MatchingTab = _Hidden[TableName]
	if MatchingTab then
		MatchingTab[Name].Waypoint:Destroy()
		MatchingTab[Name] = nil
	end
else
	error("Invalid argument!")
end
end

function MainHandler:ClearWaypoints()
local _Hidden = self._Hidden
local TableName = "_ActiveWaypoints"
local MatchingTab = _Hidden[TableName]

for Name, tab in MatchingTab do
	tab.Waypoint:Destroy()
	MatchingTab[Name] = nil
end
end

function MainHandler:Refresh(IgnoreMap:boolean?):{Instance?}
local MapHolder = self.MapHolder
local CameraPosition = self.CameraPosition
local Rotation2D = self.Rotation2D
local _Hidden = self._Hidden
local Viewport = _Hidden._Viewport
local MapFolder = _Hidden._MapFolder

if typeof(MapHolder) == "Instance" then
	local AddedInstances = {}

	if IgnoreMap ~= true then
		AddedInstances = LoadInto(self, MapHolder, MapFolder, true)
	end

	local CurrentCam = Viewport.CurrentCamera or Instance.new("Camera", Viewport)
	local NewRotation = CFrame.Angles(math.rad(-90),  0, math.rad(Rotation2D))

	if not _Hidden._Tracking then
		self.CameraRotation = NewRotation
		CurrentCam.CFrame = CFrame.new(CameraPosition)
		CurrentCam.CFrame *= NewRotation
	end

	Viewport.CurrentCamera = CurrentCam
	_Hidden._LastMapHolder = MapHolder

	return AddedInstances
else
	error("MapHolder is not an instance!")
end
end

function MainHandler:Cache()
local PrintWarnings = self.ExtraWarnings
local DebugEnabled = self.DebugEnabled
local _Hidden = self._Hidden
local MapFolder = _Hidden._MapFolder
local LastMapHolder = _Hidden._LastMapHolder

if LastMapHolder then
	local FoundIndex = nil

	for i, tab in _Hidden._CachedHolders do
		if tab.MapHolder == LastMapHolder then
			table.remove(_Hidden._CachedHolders, i)
			break
		end
	end

	table.insert(_Hidden._CachedHolders, {MapHolder = LastMapHolder, Contents = MapFolder:Clone()})
else
	warn("No map has been loaded yet, nothing has been cached.")
end
end

function MainHandler:LoadIntoCache(MapHolder:Instance)
if typeof(MapHolder) == "Instance" then
local _Hidden = self._Hidden
local Folder = Instance.new("Folder")
local AddedInstances = LoadInto(self, MapHolder, Folder)

	table.insert(_Hidden._CachedHolders, {MapHolder = MapHolder, Contents = Folder})
else
	error("MapHolder argument missing or nil!")
end
end

function MainHandler:LoadFromCache(MapHolder:Instance)
local DebugEnabled = self.DebugEnabled
local _Hidden = self._Hidden
local MapFolder = _Hidden._MapFolder

if typeof(MapHolder) == "Instance" then
	local FoundIndex = nil
	local FoundContents = nil

	for i, tab in _Hidden._CachedHolders do
		if tab.MapHolder == MapHolder then
			FoundIndex = i
			FoundContents = tab.Contents
			break
		end
	end

	if FoundIndex and FoundContents then
		self:Refresh(true)

		local ContentClone = FoundContents:Clone()
		ContentClone.Name = "LoadedCache"

		ClearViewport(MapFolder)

		task.spawn(function()
			ContentClone.Parent = MapFolder
		end)

		self.MapHolder = MapHolder
		_Hidden._LastMapHolder = MapHolder

		if DebugEnabled then
			print("(Cache) Loaded instance count: "..#ContentClone:GetDescendants())
		end
	else
		warn("No cache of this MapHolder has been saved, nothing has been loaded.")
	end
else
	error("MapHolder argument missing or nil!")
end
end

function MainHandler:RemoveFromCache(MapHolder:Instance)
local _Hidden = self._Hidden
local MapFolder = _Hidden._MapFolder
local FoundIndex = nil

if typeof(MapHolder) == "Instance" then
	for i, tab in _Hidden._CachedHolders do
		local Holder = tab.MapHolder
		local Contents = tab.Contents

		if Holder == MapHolder then
			Contents:Destroy()
			FoundIndex = i
			break
		end
	end

	if FoundIndex then
		table.remove(_Hidden._CachedHolders, FoundIndex)
	end
else
	error("MapHolder argument missing or nil!")
end
end

function MainHandler:ClearCache()
local _Hidden = self._Hidden
local MapFolder = _Hidden._MapFolder

for _, tab in _Hidden._CachedHolders do
	local Holder = tab.MapHolder
	local Contents = tab.Contents
	Contents:Destroy()
end

table.clear(_Hidden._CachedHolders)
end

function MainHandler:_GetCache():{{}}
local _Hidden = self._Hidden
local MapCache = _Hidden._CachedHolders
return MapCache
end

function MainHandler:Clear()
local _Hidden = self._Hidden
local MapFolder = _Hidden._MapFolder
local Viewport = _Hidden._Viewport

if MapFolder then
	ClearViewport(MapFolder)
else
	error("No viewport set!")
end
end

-- Gestionnaire principal d'asservissement et d'orientation de la caméra du Viewport en fonction d'un élément cible
function MainHandler:Track(TrackMode:number, Smooth:boolean?, XEffectiveness:number?)
local _Hidden = self._Hidden
local Viewport = _Hidden._Viewport

if typeof(TrackMode) == "number" then
	if typeof(self.TrackerCamera) == "Instance" then
		if typeof(self.TrackerPart) == "Instance" then
			if Viewport.CurrentCamera then
				local BindString = TrackBind.._Hidden._TrackingString

				RS:UnbindFromRenderStep(BindString)

				RS:BindToRenderStep(BindString, Enum.RenderPriority.Camera.Value - 5, function(delta)
					local PrintWarnings = self.ExtraWarnings
					if NextFrame(_Hidden._TrackLastTick, self.FPSCap) then
						_Hidden._TrackLastTick = tick()
						_Hidden._Tracking = true

						local OrigRotation = self.CameraRotation
						local CurrentCam = Viewport.CurrentCamera
						local TrackerCam = self.TrackerCamera
						local TrackerPart = self.TrackerPart
						local PartTags = CS:GetTags(TrackerPart)
						local MaxAngle = self.TrackerMaxAngle
						local MinAngle = self.TrackerMinAngle
						local Effect = XEffectiveness or 1

						MaxAngle = math.min(0, MaxAngle)
						MinAngle = math.max(-90, MinAngle)

						if CurrentCam then
							local CameraCFrame = CurrentCam.CFrame
							local CameraPos = CameraCFrame.Position
							local TrackerCFrame = TrackerCam.CFrame
							local TrackerPos = TrackerCFrame.Position
							local TrackerRot

							local UsingPart = false

							if not table.find(PartTags, "_ModuleCreated") then
								UsingPart = true
								TrackerPos = TrackerPart.Position
							end

							TrackerRot = TrackerCFrame.Rotation
							local X = math.deg(TrackerRot:ToOrientation())
							local X2 = math.deg(OrigRotation:ToOrientation())
							local LerpX = Lerp(X2, X, Effect)

							if LerpX > MaxAngle then
								TrackerRot *= CFrame.Angles(math.rad(MaxAngle - X), 0, 0)
							elseif LerpX < MinAngle then
								TrackerRot *= CFrame.Angles(math.rad(MinAngle - X), 0, 0)
							else
								TrackerRot *= CFrame.Angles(math.rad(LerpX - X), 0, 0)
							end

							if TrackMode == 2 or TrackMode == 3 then
								CameraPos = Vector3.new(TrackerPos.X, CameraPos.Y, TrackerPos.Z)
							end

							local NewRotation
							if TrackMode == 1 or TrackMode == 3 then
								NewRotation = TrackerRot
							else
								NewRotation = OrigRotation
							end

							local NewCFrame = CFrame.new(CameraPos) * NewRotation

							if Smooth then
								NewCFrame = CameraCFrame:Lerp(NewCFrame, 0.25)
							end

							CurrentCam.CFrame = NewCFrame
						else
							if PrintWarnings then
								warn("The camera being tracked no longer exists! Tracking has been halted.")
							end

							RS:UnbindFromRenderStep(BindString)
							_Hidden._Tracking = false
						end
					end
				end)
			else
				error("No viewport CurrentCamera is set!")
			end
		else
			error("No tracker part is set!")
		end
	else
		error("No tracker camera is set!")
	end
else
	error("No camera mode was chosen!")
end
end

function MainHandler:StopTracking()
local _Hidden = self._Hidden
local BindString = TrackBind.._Hidden._TrackingString

RS:UnbindFromRenderStep(BindString)
_Hidden._Tracking = false
end

return MainHandler