-- ============================================================
--  Ce script regroupe les définitions de types stricts (Luau)
--  pour le système de projection d'interface 2D en espace 3D.
--  Il formalise les structures de données (screen3D, component3D)
--  et les signatures de fonctions de leurs constructeurs respectifs.
-- ============================================================

export type screen3D = typeof(
	setmetatable(
		{} :: {
			partIndex: { [GuiObject]: component3D },
			rootGui: ScreenGui,
			displayDistance: number,
			rootOffset: CFrame,
			cameraReference: Camera
		},
		{} :: screenGen
	)
)

export type component3D = typeof(
	setmetatable(
		{} :: {
			enabled: boolean,
			_compatibility: boolean,
			component2D: GuiObject?,
			surfaceGui: SurfaceGui?,
			parent2D: GuiObject?,
			screen3D: screen3D,
			parent3D: component3D?,
			compatibilityParent3D: component3D?,
			compatibilityParent2D: GuiObject?,
			offset: CFrame,
			viewportSize: Vector2,
			conn: RBXScriptConnection?
		},
		{} :: componentGen
	)
)

export type screenGen = {
	__index: screenGen,
	new: (screenGui: ScreenGui, displayDistance: number) -> screen3D,
	SetCameraReference: (screen3D, camera: Camera) -> (),
	GetComponent3D: (screen3D, Component2D: GuiObject) -> component3D?,
	GetRealCanvasSize: (screen3D) -> Vector2,
	GetInsetCanvasSize: (screen3D) -> Vector2,
	GetIntendedCanvasSize: (screen3D) -> Vector2,
	GetInset: (screen3D) -> Vector2
}  

export type componentGen = {
	__index: componentGen,
	new: (Component2D: GuiObject, Screen3D: screen3D) -> component3D,
	Enable: (component3D) -> (component3D),
	EnableCompatibility: (component3D) -> (component3D),
	Disable: (component3D) -> (component3D),
	RecomputeParent: (component3D) -> (),
	GetStudsScreenSize: (component3D, viewportSize: Vector2) -> Vector3,
	ReadWorldCFrame: (component3D) -> (CFrame),
	UDim2ToCFrame: (component3D, position2D: UDim2) -> CFrame,
	GetCompatibilityPosition: (component3D) -> UDim2,
	GetViewportSize: (component3D) -> Vector2
}  

return nil