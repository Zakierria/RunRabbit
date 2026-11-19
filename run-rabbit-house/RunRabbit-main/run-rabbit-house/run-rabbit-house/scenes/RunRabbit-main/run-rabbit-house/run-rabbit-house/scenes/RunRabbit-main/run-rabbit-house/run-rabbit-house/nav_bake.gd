extends NavigationRegion3D
## Builds the walkable area (navigation mesh) for the old man from the house's walls and floors
## when the game starts. Point "Source Root" at the house. The old man uses this to find his way around.

@export var source_root: NodePath = ^"../TrenchbroomPrototype"  ## The house to build from
@export var agent_radius: float = 0.2      ## How far he keeps from walls. Small enough to fit through narrow spots.
@export var agent_height: float = 1.8      ## How tall he is (avoids low ceilings)
@export var agent_max_climb: float = 0.4   ## Biggest step he can walk up (stairs)
@export var cell_size: float = 0.1         ## Detail of the walkable map (small = narrow passages stay connected)
@export var bake_bounds: AABB = AABB(Vector3(1.7, 0.5, -7.9), Vector3(11.1, 9.0, 30.2))  ## Only this box counts as walkable (the inside of the house)


func _ready() -> void:
	# The navigation map has to use the same detail level as the walkable area.
	var map := get_world_3d().navigation_map
	NavigationServer3D.map_set_cell_size(map, cell_size)
	NavigationServer3D.map_set_cell_height(map, cell_size)
	_bake.call_deferred()


# Build in the background so the game doesn't freeze while it works.
func _bake() -> void:
	var root := get_node_or_null(source_root)
	if root == null:
		push_warning("Navigation: can't find Source Root.")
		return
	var nav_mesh := NavigationMesh.new()
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_mesh.geometry_collision_mask = 1  # ignore doors (layer 2), so doorways count as walkable
	nav_mesh.cell_size = cell_size
	nav_mesh.cell_height = cell_size
	nav_mesh.agent_radius = agent_radius
	nav_mesh.agent_height = agent_height
	nav_mesh.agent_max_climb = agent_max_climb
	nav_mesh.agent_max_slope = 50.0  # stairs are 45 degrees
	nav_mesh.filter_baking_aabb = bake_bounds  # keeps him inside the house
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nav_mesh, source, root)
	NavigationServer3D.bake_from_source_geometry_data_async(nav_mesh, source, func(): _finish_bake.call_deferred(nav_mesh))


func _finish_bake(nav_mesh: NavigationMesh) -> void:
	navigation_mesh = nav_mesh
