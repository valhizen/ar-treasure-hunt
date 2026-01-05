extends Control

@export var bg_image: Texture2D
@export var background_image: Texture2D
@export var grid_size: int = 3
@export var tile_gap: int = 2
@export var render_scale: float = 1.0 / 3.0


@export var board_bg_color: Color = Color(1,1,1,0.6) 
@export var border_color: Color = Color.BLACK
@export var border_thickness: float = 6.0

# Scoring system
@export var base_points: int = 500
@export var time_penalty_per_second: int = 2

@onready var win_label: RichTextLabel = $WinLabel
@onready var background: TextureRect = $Background

var tiles = []
var empty_index: int = 0
var tile_size: Vector2
var is_animating: bool = false
var board_offset: Vector2
var board_size: Vector2

var game_start_time: float = 0.0
var elapsed_time: float = 0.0
var is_game_active: bool = false
var move_count: int = 0
var final_score: int = 0

const TILE_SCENE = preload("uid://ccjewxgukji3a")

func _ready():
	
	win_label.visible = false
	var zoom_level = Vector2(render_scale, render_scale)
	get_viewport().canvas_transform = Transform2D.IDENTITY.scaled(zoom_level)

	# Setup background first
	if background_image and background:
		setup_background()

	# Then start the game with puzzle image
	if bg_image:
		start_game()

func _process(delta):
	if is_game_active:
		elapsed_time = Time.get_ticks_msec() / 1000.0 - game_start_time

func setup_background():
	background.texture = background_image
	
	# Make background cover the entire screen
	var screen_size = get_viewport_rect().size / render_scale
	background.size = screen_size
	background.position = Vector2.ZERO
	background.z_index = -1  # Behind everything
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED

func start_game():
	var img_width = bg_image.get_width()
	var img_height = bg_image.get_height()
	tile_size = Vector2(floor(img_width / grid_size), floor(img_height / grid_size))

	board_size = Vector2(
		grid_size * tile_size.x + (grid_size - 1) * tile_gap,
		grid_size * tile_size.y + (grid_size - 1) * tile_gap
	)

	var screen_size = get_viewport_rect().size / render_scale
	board_offset = (screen_size - board_size) / 2

	tiles.clear()
	for child in get_children():
		if child != win_label and child != background:
			child.queue_free()

	generate_tiles()
	shuffle_board()
	
	# Reset game stats
	move_count = 0
	elapsed_time = 0.0
	game_start_time = Time.get_ticks_msec() / 1000.0
	is_game_active = true
	
	queue_redraw()

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

func get_grid_position(x: int, y: int) -> Vector2:
	return board_offset + Vector2(x * (tile_size.x + tile_gap), y * (tile_size.y + tile_gap))

func _on_tile_pressed(tile_node):
	if is_animating or not is_game_active:
		return
	if is_adjacent(tile_node.current_index, empty_index):
		swap_tiles(tile_node.current_index, empty_index)
		move_count += 1
		check_win()

func is_adjacent(idx1: int, idx2: int) -> bool:
	var x1 = idx1 % grid_size
	var y1 = int(float(idx1) / grid_size)
	var x2 = idx2 % grid_size
	var y2 = int(float(idx2) / grid_size)
	
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
		if tiles[i] != null and tiles[i].correct_index != tiles[i].current_index:
			return
	on_puzzle_completed()

func calculate_score() -> int:
	var time_used = int(elapsed_time)
	var time_penalty = time_used * time_penalty_per_second
	var score = max(0, base_points - time_penalty)
	return score

func on_puzzle_completed():
	is_game_active = false
	is_animating = true
	
	final_score = calculate_score()
	var minutes = int(elapsed_time) / 60
	var seconds = int(elapsed_time) % 60
	
	win_label.text = "[center][color=green] PUZZLE COMPLETE! [/color]
[color=green]Time: %d:%02d
Moves: %d
Score: %d points[/color][/center]" % [minutes, seconds, move_count, final_score]
	
	win_label.visible = true
	await get_tree().create_timer(3.0).timeout

func _draw():
	if board_size == Vector2.ZERO:
		return

	draw_rect(Rect2(board_offset, board_size), board_bg_color, true)

	var half = border_thickness / 2.0
	var rect = Rect2(
		board_offset - Vector2(half, half),
		board_size + Vector2(border_thickness, border_thickness)
	)
	draw_rect(rect, border_color, false, border_thickness)
