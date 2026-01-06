extends Control

@export var bg_image: Texture2D
@export var grid_size: int = 3
@export var tile_gap: int = 2
@export var render_scale: float = 1.0 / 3.0

@export_group("Hint Settings")
@export var moves_before_hint_available: int = 10
@export var hint_score_penalty: int = 50
@export var auto_solve_score_penalty: int = 500
@export var auto_solve_move_delay: float = 0.3

var tiles = []
var empty_index: int = 0
var tile_size: Vector2
var is_animating: bool = false
var board_offset: Vector2

# Score tracking
var move_count: int = 0
var time_elapsed: float = 0.0
var game_started: bool = false
var game_won: bool = false

# Hint system
var hints_used: int = 0
var auto_solve_used: bool = false
var solution_path: Array = []  # Stores the optimal moves
var is_auto_solving: bool = false

# UI
var hint_button: Button
var solve_button: Button
var status_label: Label

const TILE_SCENE = preload("uid://ccjewxgukji3a")

func _ready():
	var zoom_level = Vector2(render_scale, render_scale)
	get_viewport().canvas_transform = Transform2D.IDENTITY.scaled(zoom_level)
	
	_create_ui()
	
	if bg_image:
		start_game()

func _process(delta):
	if game_started and not game_won and not is_auto_solving:
		time_elapsed += delta

func _create_ui():
	# Hint Button
	hint_button = Button.new()
	hint_button.text = "Hint"
	hint_button.visible = false
	hint_button.pressed.connect(_on_hint_pressed)
	hint_button.anchor_left = 1.0
	hint_button.anchor_right = 1.0
	hint_button.offset_left = -240
	hint_button.offset_right = -130
	hint_button.offset_top = 20
	hint_button.offset_bottom = 60
	hint_button.add_theme_font_size_override("font_size", 16)
	_style_button(hint_button, Color(0.2, 0.6, 0.3))
	add_child(hint_button)
	
	# Auto-Solve Button
	solve_button = Button.new()
	solve_button.text = "Auto-Solve"
	solve_button.visible = false
	solve_button.pressed.connect(_on_auto_solve_pressed)
	solve_button.anchor_left = 1.0
	solve_button.anchor_right = 1.0
	solve_button.offset_left = -120
	solve_button.offset_right = -10
	solve_button.offset_top = 20
	solve_button.offset_bottom = 60
	solve_button.add_theme_font_size_override("font_size", 16)
	_style_button(solve_button, Color(0.6, 0.3, 0.2))
	add_child(solve_button)
	
	# Status Label
	status_label = Label.new()
	status_label.text = ""
	status_label.anchor_left = 0.5
	status_label.anchor_right = 0.5
	status_label.offset_left = -200
	status_label.offset_right = 200
	status_label.offset_top = 10
	status_label.offset_bottom = 40
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 18)
	status_label.add_theme_color_override("font_color", Color.WHITE)
	status_label.add_theme_constant_override("outline_size", 3)
	status_label.add_theme_color_override("font_outline_color", Color.BLACK)
	add_child(status_label)

func _style_button(button: Button, color: Color):
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	button.add_theme_stylebox_override("normal", style)
	
	var hover = style.duplicate()
	hover.bg_color = color.lightened(0.2)
	button.add_theme_stylebox_override("hover", hover)

func start_game():
	var img_width = bg_image.get_width()
	var img_height = bg_image.get_height()
	tile_size = Vector2(floor(float(img_width) / grid_size), floor(float(img_height) / grid_size))
	
	var total_width = img_width + (grid_size - 1) * tile_gap
	var total_height = img_height + (grid_size - 1) * tile_gap
	
	var screen_size = get_viewport_rect().size / render_scale
	board_offset = (screen_size - Vector2(total_width, total_height)) / 2
	
	# Reset tracking
	move_count = 0
	time_elapsed = 0.0
	game_won = false
	hints_used = 0
	auto_solve_used = false
	solution_path.clear()
	is_auto_solving = false
	
	hint_button.visible = false
	solve_button.visible = false
	status_label.text = ""
	
	generate_tiles()
	shuffle_board()
	
	game_started = true

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
	if is_animating or game_won or is_auto_solving:
		return
	
	_clear_all_highlights()
	
	if is_adjacent(tile_node.current_index, empty_index):
		move_count += 1
		solution_path.clear()  # Invalidate cached solution
		swap_tiles(tile_node.current_index, empty_index)
		_update_ui()
		check_win()

func _update_ui():
	if move_count >= moves_before_hint_available and not game_won:
		hint_button.visible = true
		hint_button.text = "Hint (-%d)" % hint_score_penalty
		solve_button.visible = true
		solve_button.text = "Solve (-%d)" % auto_solve_score_penalty

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
	var ty = int(float(to_index) / grid_size)
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
		var neighbors = _get_neighbor_indices(empty_index)
		var random_neighbor = neighbors.pick_random()
		
		if random_neighbor != previous_empty:
			swap_tiles(random_neighbor, empty_index, false)
			previous_empty = empty_index
			moves += 1
	
	is_animating = false

func _get_neighbor_indices(idx: int) -> Array:
	var neighbors = []
	var x = idx % grid_size
	var y = int(float(idx) / grid_size)
	
	if x > 0:
		neighbors.append(idx - 1)
	if x < grid_size - 1:
		neighbors.append(idx + 1)
	if y > 0:
		neighbors.append(idx - grid_size)
	if y < grid_size - 1:
		neighbors.append(idx + grid_size)
	
	return neighbors

# ═══════════════════════════════════════════════════════════════════════════════
# A* SOLVER
# ═══════════════════════════════════════════════════════════════════════════════

func _get_current_state() -> Array:
	"""Convert current board to state array"""
	var state = []
	for i in range(tiles.size()):
		if tiles[i] == null:
			state.append(-1)  # Empty
		else:
			state.append(tiles[i].correct_index)
	return state

func _get_goal_state() -> Array:
	"""Get the solved state"""
	var goal = []
	for i in range(grid_size * grid_size - 1):
		goal.append(i)
	goal.append(-1)  # Empty at end
	return goal

func _manhattan_distance(state: Array) -> int:
	"""Calculate total Manhattan distance heuristic"""
	var distance = 0
	for i in range(state.size()):
		var val = state[i]
		if val != -1:
			var current_x = i % grid_size
			var current_y = int(float(i) / grid_size)
			var goal_x = val % grid_size
			var goal_y = int(float(val) / grid_size)
			distance += abs(current_x - goal_x) + abs(current_y - goal_y)
	return distance

func _state_to_string(state: Array) -> String:
	"""Convert state to string for dictionary key"""
	var s = ""
	for v in state:
		s += str(v) + ","
	return s

func _find_empty_in_state(state: Array) -> int:
	"""Find empty position in state"""
	for i in range(state.size()):
		if state[i] == -1:
			return i
	return -1

func _get_state_neighbors(state: Array) -> Array:
	"""Get all possible next states"""
	var empty_idx = _find_empty_in_state(state)
	var neighbors = []
	var adjacent = _get_neighbor_indices(empty_idx)
	
	for adj in adjacent:
		var new_state = state.duplicate()
		new_state[empty_idx] = new_state[adj]
		new_state[adj] = -1
		neighbors.append({"state": new_state, "moved_from": adj})
	
	return neighbors

func solve_puzzle() -> Array:
	"""A* solver - returns array of tile indices to move"""
	var start_state = _get_current_state()
	var goal_state = _get_goal_state()
	
	if start_state == goal_state:
		return []
	
	# Priority queue: [f_score, g_score, state, path]
	var open_set = []
	var h = _manhattan_distance(start_state)
	open_set.append([h, 0, start_state, []])
	
	var closed_set = {}
	var iterations = 0
	var max_iterations = 500000  # Safety limit
	
	while open_set.size() > 0 and iterations < max_iterations:
		iterations += 1
		
		# Find lowest f_score
		var lowest_idx = 0
		for i in range(1, open_set.size()):
			if open_set[i][0] < open_set[lowest_idx][0]:
				lowest_idx = i
		
		var current = open_set[lowest_idx]
		open_set.remove_at(lowest_idx)
		
		var current_state = current[2]
		var current_g = current[1]
		var current_path = current[3]
		
		# Goal check
		if current_state == goal_state:
			print("[Solver] Found solution in %d moves, %d iterations" % [current_path.size(), iterations])
			return current_path
		
		var state_key = _state_to_string(current_state)
		if closed_set.has(state_key):
			continue
		closed_set[state_key] = true
		
		# Expand neighbors
		for neighbor_data in _get_state_neighbors(current_state):
			var neighbor_state = neighbor_data["state"]
			var neighbor_key = _state_to_string(neighbor_state)
			
			if closed_set.has(neighbor_key):
				continue
			
			var new_g = current_g + 1
			var new_h = _manhattan_distance(neighbor_state)
			var new_f = new_g + new_h
			var new_path = current_path.duplicate()
			new_path.append(neighbor_data["moved_from"])
			
			open_set.append([new_f, new_g, neighbor_state, new_path])
	
	print("[Solver] No solution found in %d iterations" % iterations)
	return []

# ═══════════════════════════════════════════════════════════════════════════════
# HINT SYSTEM
# ═══════════════════════════════════════════════════════════════════════════════

func _on_hint_pressed():
	if game_won or is_auto_solving:
		return
	
	_clear_all_highlights()
	
	# Calculate solution if not cached
	if solution_path.is_empty():
		status_label.text = "Calculating..."
		await get_tree().process_frame
		solution_path = solve_puzzle()
		status_label.text = ""
	
	if solution_path.is_empty():
		status_label.text = "Already solved!"
		return
	
	# Highlight the next tile to move
	var next_move_idx = solution_path[0]
	var tile_to_move = tiles[next_move_idx]
	
	if tile_to_move:
		hints_used += 1
		_highlight_tile(tile_to_move)
		status_label.text = "Move this tile! (%d moves left)" % solution_path.size()

func _highlight_tile(tile: Node):
	"""Highlight a tile with green glow"""
	if tile.has_method("set_highlight"):
		tile.set_highlight(Color(0, 1, 0, 0.6))
	else:
		# Create highlight overlay
		var highlight = ColorRect.new()
		highlight.name = "Highlight"
		highlight.color = Color(0, 1, 0, 0.4)
		highlight.size = tile_size
		highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(highlight)
		
		# Pulse animation
		var tween = create_tween().set_loops()
		tween.tween_property(highlight, "color:a", 0.2, 0.5)
		tween.tween_property(highlight, "color:a", 0.5, 0.5)

func _clear_all_highlights():
	"""Remove all highlight effects"""
	for tile in tiles:
		if tile != null:
			if tile.has_method("clear_highlight"):
				tile.clear_highlight()
			else:
				var highlight = tile.get_node_or_null("Highlight")
				if highlight:
					highlight.queue_free()
	status_label.text = ""

# ═══════════════════════════════════════════════════════════════════════════════
# AUTO-SOLVE
# ═══════════════════════════════════════════════════════════════════════════════

func _on_auto_solve_pressed():
	if game_won or is_auto_solving:
		return
	
	_clear_all_highlights()
	
	# Calculate solution if not cached
	if solution_path.is_empty():
		status_label.text = "Calculating solution..."
		await get_tree().process_frame
		solution_path = solve_puzzle()
	
	if solution_path.is_empty():
		status_label.text = "Already solved!"
		return
	
	auto_solve_used = true
	is_auto_solving = true
	hint_button.visible = false
	solve_button.visible = false
	
	status_label.text = "Auto-solving... (%d moves)" % solution_path.size()
	
	# Execute each move with animation
	for i in range(solution_path.size()):
		var tile_idx = solution_path[i]
		
		# Wait for any animation
		while is_animating:
			await get_tree().process_frame
		
		# Highlight briefly
		if tiles[tile_idx]:
			_highlight_tile(tiles[tile_idx])
		
		await get_tree().create_timer(auto_solve_move_delay * 0.3).timeout
		
		# Make the move
		_clear_all_highlights()
		move_count += 1
		swap_tiles(tile_idx, empty_index)
		
		status_label.text = "Auto-solving... (%d moves left)" % (solution_path.size() - i - 1)
		
		await get_tree().create_timer(auto_solve_move_delay * 0.7).timeout
	
	solution_path.clear()
	is_auto_solving = false
	check_win()

# ═══════════════════════════════════════════════════════════════════════════════
# WIN & SCORE
# ═══════════════════════════════════════════════════════════════════════════════

func check_win():
	for i in range(tiles.size()):
		if tiles[i] != null:
			if tiles[i].correct_index != tiles[i].current_index:
				return
	
	game_won = true
	_clear_all_highlights()
	hint_button.visible = false
	solve_button.visible = false
	status_label.text = "PUZZLE COMPLETE!"
	
	print("YOU WON!")
	
	var final_score = _calculate_score()
	ScoreManager.submit_score("sliding_puzzle", final_score, {
		"time_taken": time_elapsed,
		"move_count": move_count,
		"grid_size": grid_size,
		"hints_used": hints_used,
		"auto_solve_used": auto_solve_used,
		"success": true
	})
	print("[SlidingPuzzle] Score: %d (moves: %d, time: %.1fs, hints: %d, auto: %s)" % [
		final_score, move_count, time_elapsed, hints_used, str(auto_solve_used)
	])

func _calculate_score() -> int:
	var base_score = 1000
	
	# Move bonus
	var optimal_moves = grid_size * grid_size * grid_size
	var move_bonus = max(0, (optimal_moves * 2 - move_count) * 5)
	
	# Time bonus
	var time_bonus = int(max(0.0, 3000.0 - time_elapsed * 50.0))
	
	# Penalties
	var hint_penalty = hints_used * hint_score_penalty
	var auto_penalty = auto_solve_score_penalty if auto_solve_used else 0
	
	return max(100, base_score + move_bonus + time_bonus - hint_penalty - auto_penalty)
