extends Control

@export var bg_image: Texture2D
@export var grid_size: int = 3
@export var tile_gap: int = 2
@export var render_scale: float = 1.0 / 3.0

var tiles = []
var empty_index: int = 0
var tile_size: Vector2
var is_animating: bool = false
var board_offset: Vector2

const TILE_SCENE = preload("res://Sceans/MiniGames/MuseumPuzzle/scenes/tile.tscn")

func _ready():
	var zoom_level = Vector2(render_scale, render_scale)
	get_viewport().canvas_transform = Transform2D.IDENTITY.scaled(zoom_level)
	
	if bg_image:
		start_game()

func start_game():
	var img_width = bg_image.get_width()
	var img_height = bg_image.get_height()
	tile_size = Vector2(img_width / grid_size, img_height / grid_size)
	
	var total_width = img_width + (grid_size - 1) * tile_gap
	var total_height = img_height + (grid_size - 1) * tile_gap
	
	var screen_size = get_viewport_rect().size / render_scale
	board_offset = (screen_size - Vector2(total_width, total_height)) / 2
	
	generate_tiles()
	shuffle_board()

func generate_tiles():
	tiles.resize(grid_size * grid_size)
	
	for y in range(grid_size):
		for x in range(grid_size):
			var index = y * grid_size + x
			
			if index == (grid_size * grid_size) - 1:
				empty_index = index
				tiles[index] = null
				continue
			
			var tile = TILE_SCENE.instantiate()
			add_child(tile)
			
			var atlas = AtlasTexture.new()
			atlas.atlas = bg_image
			atlas.region = Rect2(x * tile_size.x, y * tile_size.y, tile_size.x, tile_size.y)
			
			tile.texture = atlas
			tile.size = tile_size
			tile.correct_index = index
			tile.current_index = index
			
			var pos = get_grid_position(x, y)
			tile.update_visual_position(pos, false)
			
			tile.tile_pressed.connect(_on_tile_pressed)
			tiles[index] = tile

func _on_tile_pressed(tile_node):
	if is_animating: return
	
	if is_adjacent(tile_node.current_index, empty_index):
		swap_tiles(tile_node.current_index, empty_index)
		check_win()

func is_adjacent(idx1: int, idx2: int) -> bool:
	var x1 = idx1 % grid_size
	var y1 = idx1 / grid_size
	var x2 = idx2 % grid_size
	var y2 = idx2 / grid_size
	
	return abs(x1 - x2) + abs(y1 - y2) == 1

func swap_tiles(from_index: int, to_index: int, animate: bool = true):
	var tile = tiles[from_index]
	
	tiles[to_index] = tile
	tiles[from_index] = null
	
	tile.current_index = to_index
	empty_index = from_index
	
	var tx = to_index % grid_size
	var ty = to_index / grid_size
	var target_pos = get_grid_position(tx, ty)
	
	tile.update_visual_position(target_pos, animate)

func get_grid_position(x: int, y: int) -> Vector2:
	return board_offset + Vector2(x * (tile_size.x + tile_gap), y * (tile_size.y + tile_gap))

func shuffle_board():
	is_animating = true
	var moves = 0
	var max_moves = 100
	var previous_empty = -1
	
	while moves < max_moves:
		var neighbors = []
		var x = empty_index % grid_size
		var y = empty_index / grid_size
		
		if x > 0: neighbors.append(empty_index - 1)
		if x < grid_size - 1: neighbors.append(empty_index + 1)
		if y > 0: neighbors.append(empty_index - grid_size)
		if y < grid_size - 1: neighbors.append(empty_index + grid_size)
		
		var random_neighbor = neighbors.pick_random()
		
		if random_neighbor != previous_empty:
			swap_tiles(random_neighbor, empty_index, false)
			previous_empty = empty_index
			moves += 1
	
	is_animating = false

func check_win():
	for i in range(tiles.size()):
		if tiles[i] != null:
			if tiles[i].correct_index != tiles[i].current_index:
				return
	
	print("YOU WON!")
