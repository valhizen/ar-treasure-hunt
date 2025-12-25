extends Node2D

@export_group("Wood Settings")
@export var wood_size := Vector2(600, 800)
@export var wood_color := Color(0.6, 0.4, 0.2)

@export_group("Carving Settings")
@export var carve_radius := 15.0
@export var min_radius := 5.0
@export var max_radius := 40.0
@export var radius_step := 2.0
@export var tool_color := Color(1.0, 0.5, 0, 0.5)

@export_group("Target Silhouette")
@export var target_images: Array[Texture2D] = []

enum GameState{menu,playing,completed}

# Game state
var wood_texture: Image
var target_silhouette: Image
var chosen_target: Texture2D
var carved_mask: Image
var game_state := GameState.menu  

# Scoring
var accuracy := 0.0
var cuts_made := 0
var time_elapsed := 0.0
var perfect_cuts := 0
var mistakes := 0
var score := 0

# Tool size scoring
var base_score_per_cut := 10
var size_multiplier := 1.0

@onready var wood_sprite: Sprite2D = $Wood
@onready var target_sprite: Sprite2D = $TargetSprite
@onready var carving_tool: Node2D = $CarvingTool
@onready var tool_circle: Sprite2D = $CarvingTool/ToolCircle

@onready var stats_label: Label = $UI/StatsLabel
@onready var done_button: Button = $UI/DoneButton
@onready var completed_stats: Label = $UI/CompletedStats


var is_carving := false
var last_carve_pos := Vector2.ZERO
var current_stroke := []

var needs_wood_update := false
var update_timer := 0.0
const UPDATE_INTERVAL := 0.1  # Update every 100ms for performance

var circle_pattern = [] 

func _ready():
	wood_sprite.position = get_viewport_rect().size / 2
	target_sprite.position = wood_sprite.position
	
	# Precompute circle pattern
	precompute_circle_pattern()
	calculate_size_multiplier()
	
	# Setup tool
	create_tool_texture()
	carving_tool.visible = false
	
	# Setup UI
	if done_button:
		done_button.pressed.connect(_on_done_button_pressed)
		done_button.visible = false
	
	if completed_stats:
		completed_stats.visible = false
	
	load_target_silhouette()
	reset_game()

func precompute_circle_pattern():
	"""Precompute relative positions for circle carving"""
	circle_pattern.clear()
	var radius_sq = carve_radius * carve_radius
	for y in range(-int(carve_radius), int(carve_radius) + 1):
		for x in range(-int(carve_radius), int(carve_radius) + 1):
			if x * x + y * y <= radius_sq:
				circle_pattern.append(Vector2i(x, y))

func calculate_size_multiplier():
	"""Calculate score multiplier based on tool size - smaller tools = higher reward"""
	var normalized_size = (carve_radius - min_radius) / (max_radius - min_radius)
	# Inverse relationship: smaller tool = higher multiplier (1.5x to 0.5x)
	size_multiplier = 1.5 - normalized_size

func change_tool_size(delta: float):
	"""Change tool size and update everything needed"""
	carve_radius = clamp(carve_radius + delta, min_radius, max_radius)
	
	# Recalculate everything that depends on radius
	precompute_circle_pattern()
	calculate_size_multiplier()
	create_tool_texture()
	
	# Visual feedback
	update_ui()

func create_tool_texture():
	var size = int(carve_radius * 2) + 4
	var tool_image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	tool_image.fill(Color.TRANSPARENT)
	
	# Draw outer circle (border)
	@warning_ignore("integer_division")
	draw_circle_on_image(tool_image, Vector2(size/2, size/2), carve_radius + 1, Color.WHITE)
	# Draw inner circle (semi-transparent)
	@warning_ignore("integer_division")
	draw_circle_on_image(tool_image, Vector2(size/2, size/2), carve_radius, tool_color)
	
	tool_circle.texture = ImageTexture.create_from_image(tool_image)
	tool_circle.centered = true

func load_target_silhouette():
	if target_images.size() > 0:
		chosen_target = target_images.pick_random()
		target_silhouette = chosen_target.get_image()
		target_silhouette.resize(int(wood_size.x), int(wood_size.y))
		target_silhouette.convert(Image.FORMAT_RGBA8)
	else:
		# Fallback default shape
		target_silhouette = Image.create(int(wood_size.x), int(wood_size.y), false, Image.FORMAT_RGBA8)
		target_silhouette.fill(Color.TRANSPARENT)
		draw_circle_on_image(target_silhouette, wood_size / 2, 100, Color.BLACK)

func reset_game():
	game_state = GameState.menu
	time_elapsed = 0.0
	cuts_made = 0
	perfect_cuts = 0
	mistakes = 0
	accuracy = 0.0
	score = 0
	
	load_target_silhouette()
	
	# Fresh wood - optimized with PackedByteArray
	wood_texture = Image.create(int(wood_size.x), int(wood_size.y), false, Image.FORMAT_RGBA8)
	var data = wood_texture.get_data()
	var pixel_count = int(wood_size.x * wood_size.y)
	
	for i in range(pixel_count):
		var noise = randf_range(-0.05, 0.05)
		var idx = i * 4
		data[idx] = int((wood_color.r + noise) * 255)
		data[idx + 1] = int((wood_color.g + noise) * 255)
		data[idx + 2] = int((wood_color.b + noise) * 255)
		data[idx + 3] = 255
	
	wood_texture = Image.create_from_data(int(wood_size.x), int(wood_size.y), false, Image.FORMAT_RGBA8, data)
	
	# Carved mask - simple fill is fine
	carved_mask = Image.create(int(wood_size.x), int(wood_size.y), false, Image.FORMAT_RGBA8)
	carved_mask.fill(Color.WHITE)
	
	update_wood_sprite()
	update_target_sprite()
	update_ui()

func start_game():
	reset_game()
	game_state = GameState.playing
	if done_button:
		done_button.visible = true
	if completed_stats:
		completed_stats.visible = false
	target_sprite.visible = true

func update_wood_sprite():
	"""Use blit operations and direct data manipulation"""
	var display = wood_texture.duplicate()
	var wood_data = display.get_data()
	var mask_data = carved_mask.get_data()
	
	var pixel_count = int(wood_size.x * wood_size.y)
	for i in range(pixel_count):
		var mask_idx = i * 4
		if mask_data[mask_idx] < 128:  # Check if carved (black in mask)
			# Set to transparent
			wood_data[mask_idx + 3] = 0
	
	display = Image.create_from_data(int(wood_size.x), int(wood_size.y), false, Image.FORMAT_RGBA8, wood_data)
	wood_sprite.texture = ImageTexture.create_from_image(display)
	needs_wood_update = false

func update_target_sprite():
	if target_silhouette:
		target_sprite.texture = ImageTexture.create_from_image(target_silhouette)

func update_ui():
	if game_state == GameState.playing and stats_label:
		stats_label.visible = true
		stats_label.text = "SPACE: Reset | SCROLL: Tool Size | DONE: Submit Work\n\nTime: %.1fs | Score: %d | Cuts: %d\nAccuracy: %.1f%%\nPerfect: %d | Mistakes: %d\nTool Size: %.1f (%.1fx multiplier)" % [time_elapsed, score, cuts_made, accuracy, perfect_cuts, mistakes, carve_radius, size_multiplier]
	elif game_state == GameState.menu and stats_label:
		stats_label.visible = true
		stats_label.text = "WOOD CARVING GAME\n\nPress SPACE to start\n\nCarve the target shape shown in green\nScroll to change tool size\nSmaller tools = higher score multiplier!"
	elif game_state == GameState.completed:
		if stats_label:
			stats_label.visible = false

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE:
			if game_state != GameState.playing:
				start_game()
			else:
				reset_game()
				start_game()
		elif event.keycode == KEY_ENTER:
			print("Time: %.1fs | Score: %d | Cuts: %d | Accuracy: %.1f%% | Perfect: %d | Mistakes: %d | Tool Size: %.1f" % 
				[time_elapsed, score, cuts_made, accuracy, perfect_cuts, mistakes, carve_radius])
	
	# Mouse wheel to change tool size
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			change_tool_size(radius_step)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			change_tool_size(-radius_step)
	
	if game_state == GameState.playing:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				start_carving()
			else:
				stop_carving()
		if event is InputEventMouseMotion:
			carving_tool.position = event.position
			if is_carving:
				carve_at_position(event.position)

func start_carving():
	is_carving = true
	carving_tool.visible = true
	current_stroke = []
	last_carve_pos = carving_tool.position

func stop_carving():
	is_carving = false
	if current_stroke.size() > 0:
		evaluate_stroke()
	current_stroke.clear()
	calculate_accuracy()

func carve_at_position(pos: Vector2):
	var local_pos = pos - wood_sprite.position + wood_size / 2
	if local_pos.x < 0 or local_pos.x >= wood_size.x or local_pos.y < 0 or local_pos.y >= wood_size.y:
		return
	
	# Optimized: Reduce interpolation steps
	var distance = last_carve_pos.distance_to(pos)
	var steps = max(1, int(distance / carve_radius * 0.5))  # Fewer steps
	
	for i in range(steps):
		var t = float(i) / float(steps)
		var interp_pos = last_carve_pos.lerp(pos, t)
		var interp_local = interp_pos - wood_sprite.position + wood_size / 2
		carve_circle_fast(interp_local)
	
	last_carve_pos = pos
	current_stroke.append(local_pos)
	cuts_made += 1
	needs_wood_update = true

func carve_circle_fast(center: Vector2):
	"""Use precomputed pattern and direct data access"""
	var mask_data = carved_mask.get_data()
	var width = int(wood_size.x)
	var height = int(wood_size.y)
	
	for offset in circle_pattern:
		var px = int(center.x) + offset.x
		var py = int(center.y) + offset.y
		
		if px >= 0 and px < width and py >= 0 and py < height:
			var idx = (py * width + px) * 4
			mask_data[idx] = 0      # R
			mask_data[idx + 1] = 0  # G
			mask_data[idx + 2] = 0  # B
			# Alpha stays the same
	
	carved_mask = Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, mask_data)

func evaluate_stroke():
	"""Sample stroke instead of checking every pixel"""
	@warning_ignore("integer_division")
	var sample_rate = max(1, current_stroke.size() / 20)  # Sample ~20 points
	
	var stroke_perfect = 0
	var stroke_mistakes = 0
	
	for i in range(0, current_stroke.size(), sample_rate):
		var pos = current_stroke[i]
		if pos.x >= 0 and pos.x < wood_size.x and pos.y >= 0 and pos.y < wood_size.y:
			var target_pixel = target_silhouette.get_pixel(int(pos.x), int(pos.y))
			if target_pixel.a > 0.5:
				stroke_perfect += 1
			else:
				stroke_mistakes += 1
	
	perfect_cuts += stroke_perfect
	mistakes += stroke_mistakes
	
	# Calculate score based on performance and tool size
	# Perfect cuts give positive points, mistakes subtract points
	var stroke_score = (stroke_perfect * base_score_per_cut - stroke_mistakes * base_score_per_cut * 0.5) * size_multiplier
	score += int(stroke_score)

func calculate_accuracy():
	"""Use direct data access and sampling for large images"""
	var width = int(wood_size.x)
	var height = int(wood_size.y)
	var total_pixels = width * height
	
	# For large images, sample pixels instead of checking all
	var sample_step = 1
	if total_pixels > 100000:  # If image is large, sample
		sample_step = 8
	
	var carved_data = carved_mask.get_data()
	var target_data = target_silhouette.get_data()
	
	var correct = 0
	var total = 0
	
	for y in range(0, height, sample_step):
		for x in range(0, width, sample_step):
			var idx = (y * width + x) * 4
			var carved = carved_data[idx] < 128
			var target = target_data[idx + 3] > 128
			
			total += 1
			if carved == target:
				correct += 1
	
	accuracy = (float(correct) / float(total)) * 100.0

func _process(delta):
	if game_state == GameState.playing:
		time_elapsed += delta
		update_timer += delta
		
		# Throttled updates during carving
		if needs_wood_update and update_timer >= UPDATE_INTERVAL:
			update_wood_sprite()
			update_timer = 0.0
		update_ui()
		carving_tool.visible = true
	else:
		carving_tool.visible = false

func _on_done_button_pressed():
	if game_state == GameState.playing:
		complete_game()

func complete_game():
	"""Finish the game and show results"""
	game_state = GameState.completed
	calculate_accuracy()
	
	# Calculate final score with bonuses
	var time_bonus = max(0, int((60.0 - time_elapsed) * 5))  # Bonus for speed (under 60s)
	var accuracy_bonus = int(accuracy * 2)  # Accuracy bonus
	var efficiency_bonus = 0
	if cuts_made > 0:
		efficiency_bonus = int((float(perfect_cuts) / float(cuts_made)) * 100)  # Efficiency bonus
	
	var final_score = score + time_bonus + accuracy_bonus + efficiency_bonus
	
	# Hide game elements
	wood_sprite.visible = false
	target_sprite.visible = false
	carving_tool.visible = false
	done_button.visible = false
	
	# Show completion screen
	if completed_stats:
		completed_stats.visible = true
		completed_stats.text = """
		CARVING COMPLETED!          
		PERFORMANCE BREAKDOWN:
		  Base Score:        %d pts
		  Time Bonus:        +%d pts
		  Accuracy Bonus:    +%d pts  
		  Efficiency Bonus:  +%d pts
		  FINAL SCORE:       %d pts
		DETAILED STATS:
		  Time Taken:        %.1f seconds
		  Accuracy:          %.1f%%
		  Perfect Cuts:      %d
		  Mistakes:          %d
		  Total Cuts:        %d
		  Avg Tool Size:     %.1f
		Press SPACE to try again!
		""" % [ score, time_bonus, accuracy_bonus, efficiency_bonus, 
			   final_score, time_elapsed, accuracy, perfect_cuts, mistakes, 
			   cuts_made, carve_radius]
	
	update_ui()

func draw_circle_on_image(img: Image, center: Vector2, radius: float, color: Color):
	var radius_sq = radius * radius
	for y in range(max(0, int(center.y - radius)), min(img.get_height(), int(center.y + radius + 1))):
		for x in range(max(0, int(center.x - radius)), min(img.get_width(), int(center.x + radius + 1))):
			var dx = x - center.x
			var dy = y - center.y
			if dx * dx + dy * dy <= radius_sq:
				img.set_pixel(x, y, color)
