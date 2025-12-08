extends Node2D


@export var map_id : String

func _ready():
	# Find all TileMapLayers
	var min_pos = Vector2(INF, INF)
	var max_pos = Vector2(-INF, -INF)
	
	var tilemaps = get_tree().get_nodes_in_group("level_map")
	if tilemaps.size() == 0:
		# Search for all TileMapLayer nodes
		tilemaps = find_all_tilemaps(self)
	
	print("=== FINDING MAP BOUNDS ===")
	for tilemap in tilemaps:
		if tilemap is TileMapLayer:
			var cells = tilemap.get_used_cells()
			print("Tilemap ", tilemap.name, " has ", cells.size(), " cells")
			
			for cell in cells:
				var world_pos = tilemap.map_to_local(cell)
				min_pos.x = min(min_pos.x, world_pos.x)
				min_pos.y = min(min_pos.y, world_pos.y)
				max_pos.x = max(max_pos.x, world_pos.x)
				max_pos.y = max(max_pos.y, world_pos.y)
	
	# Add padding
	min_pos -= Vector2(100, 100)
	max_pos += Vector2(100, 100)
	
	print("=== RESULT ===")
	print("Set World Min to: ", min_pos)
	print("Set World Max to: ", max_pos)
	print("==================")

func find_all_tilemaps(node):
	var result = []
	for child in node.get_children():
		if child is TileMapLayer:
			result.append(child)
		result.append_array(find_all_tilemaps(child))
	return result
