extends Node2D

@export_group("Wood Settings")
@export var wood_size := Vector2(600, 800)
@export var wood_texture_path := "res://wood_texture.jpg"  # Add your wood texture here
@export var use_procedural_wood := true  # Fallback if no texture

@export_group("Carving Settings")
@export var carve_radius := 15.0
@export var min_radius := 5.0
@export var max_radius := 40.0
@export var radius_step := 2.0
@export var tool_color := Color(1.0, 0.5, 0, 0.5)

@export_group("Target Silhouette")
@export var target_images: Array[Texture2D] = []

enum GameState{MENU, PLAYING, COMPLETED}

# Game state
var wood_texture: Image
var target_silhouette: Image
var chosen_target: Texture2D
var carved_mask: Image
var game_state := GameState.MENU

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

# Node references
@onready var wood_sprite: Sprite2D = $Wood
@onready var target_sprite: Sprite2D = $TargetSprite
@onready var carving_tool: Node2D = $CarvingTool
@onready var tool_circle: Sprite2D = $CarvingTool/ToolCircle

# UI Elements
@onready var menu_panel: Panel = $UI/MenuPanel
@onready var start_button: Button = $UI/MenuPanel/VBox/StartButton
@onready var quit_button: Button = $UI/MenuPanel/VBox/QuitButton
@onready var menu_title: Label = $UI/MenuPanel/VBox/TitleLabel

@onready var game_panel: Panel = $UI/GamePanel
@onready var stats_label: Label = $UI/GamePanel/StatsVBox/StatsLabel
@onready var tool_size_label: Label = $UI/GamePanel/ToolControls/SizeLabel
@onready var decrease_tool_button: Button = $UI/GamePanel/ToolControls/DecreaseButton
@onready var increase_tool_button: Button = $UI/GamePanel/ToolControls/IncreaseButton
@onready var reset_button: Button = $UI/GamePanel/ButtonsHBox/ResetButton
@onready var done_button: Button = $UI/GamePanel/ButtonsHBox/DoneButton
@onready var show_target_button: CheckButton = $UI/GamePanel/ButtonsHBox/ShowTargetButton

@onready var completed_panel: Panel = $UI/CompletedPanel
@onready var completed_stats: Label = $UI/CompletedPanel/VBox/StatsLabel
@onready var play_again_button: Button = $UI/CompletedPanel/VBox/PlayAgainButton
@onready var menu_button: Button = $UI/CompletedPanel/VBox/MenuButton

var is_carving := false
var last_carve_pos := Vector2.ZERO
var current_stroke := []

var needs_wood_update := false
var update_timer := 0.0
const UPDATE_INTERVAL := 0.05

var circle_pattern = []

func _ready():
	setup_scene()
	setup_ui_connections()
	precompute_circle_pattern()
	calculate_size_multiplier()
	create_tool_texture()
	load_target_silhouette()
	show_menu()

func setup_scene():
	"""Position main elements"""
	var viewport_size = get_viewport_rect().size
	wood_sprite.position = viewport_size / 2
	target_sprite.position = wood_sprite.position
	target_sprite.modulate = Color(0, 1, 0, 0.3)  # Green tint with transparency
	carving_tool.visible = false

func setup_ui_connections():
	"""Connect all UI button signals"""
	# Menu buttons
	if start_button:
		start_button.pressed.connect(start_game)
	if quit_button:
		quit_button.pressed.connect(quit_game)
	
	# Game buttons
	if done_button:
		done_button.pressed.connect(complete_game)
	if reset_button:
		reset_button.pressed.connect(reset_and_start)
	if show_target_button:
		show_target_button.toggled.connect(_on_show_target_toggled)
	if increase_tool_button:
		increase_tool_button.pressed.connect(func(): change_tool_size(radius_step))
	if decrease_tool_button:
		decrease_tool_button.pressed.connect(func(): change_tool_size(-radius_step))
	
	# Completion buttons
	if play_again_button:
		play_again_button.pressed.connect(start_game)
	if menu_button:
		menu_button.pressed.connect(show_menu)

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
	size_multiplier = 1.5 - normalized_size

func change_tool_size(delta: float):
	"""Change tool size and update everything needed"""
	carve_radius = clamp(carve_radius + delta, min_radius, max_radius)
	precompute_circle_pattern()
	calculate_size_multiplier()
	create_tool_texture()
	update_tool_size_label()

func update_tool_size_label():
	if tool_size_label:
		tool_size_label.text = "Tool: %.0f px (%.1fx)" % [carve_radius, size_multiplier]

func create_tool_texture():
	"""Create visual representation of carving tool"""
	var size = int(carve_radius * 2) + 4
	var tool_image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	tool_image.fill(Color.TRANSPARENT)
	
	@warning_ignore("integer_division")
	var center = Vector2(size/2, size/2)
	draw_circle_on_image(tool_image, center, carve_radius + 1, Color.WHITE)
	draw_circle_on_image(tool_image, center, carve_radius, tool_color)
	
	tool_circle.texture = ImageTexture.create_from_image(tool_image)
	tool_circle.centered = true

func load_wood_texture():
	"""Load wood texture from file or generate procedural texture"""
	wood_texture = Image.create(int(wood_size.x), int(wood_size.y), false, Image.FORMAT_RGBA8)
	
	if not use_procedural_wood and FileAccess.file_exists(wood_texture_path):
		# Try to load texture from file
		var loaded_texture = load(wood_texture_path)
		if loaded_texture and loaded_texture is Texture2D:
			wood_texture = loaded_texture.get_image()
			wood_texture.resize(int(wood_size.x), int(wood_size.y))
			wood_texture.convert(Image.FORMAT_RGBA8)
			return
	
	# Fallback: Generate procedural wood texture
	generate_procedural_wood()

func generate_procedural_wood():
	"""Generate a more realistic wood grain texture"""
	var data = wood_texture.get_data()
	var width = int(wood_size.x)
	var height = int(wood_size.y)
	
	# Wood grain parameters
	var grain_frequency = 0.02
	var grain_strength = 0.15
	
	for y in range(height):
		for x in range(width):
			var idx = (y * width + x) * 4
			
			# Create wood grain effect using sine waves
			var grain = sin(x * grain_frequency + sin(y * 0.05) * 3.0) * grain_strength
			var noise = randf_range(-0.05, 0.05)
			
			# Base wood color with variations
			var base_r = 0.55 + grain + noise
			var base_g = 0.35 + grain * 0.8 + noise
			var base_b = 0.20 + grain * 0.5 + noise
			
			data[idx] = int(clamp(base_r, 0, 1) * 255)
			data[idx + 1] = int(clamp(base_g, 0, 1) * 255)
			data[idx + 2] = int(clamp(base_b, 0, 1) * 255)
			data[idx + 3] = 255
	
	wood_texture = Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, data)

func load_target_silhouette():
	"""Load and prepare the target shape"""
	if target_images.size() > 0:
		chosen_target = target_images.pick_random()
		target_silhouette = chosen_target.get_image()
		target_silhouette.resize(int(wood_size.x), int(wood_size.y))
		target_silhouette.convert(Image.FORMAT_RGBA8)
	else:
		# Fallback: Create a simple heart shape
		target_silhouette = Image.create(int(wood_size.x), int(wood_size.y), false, Image.FORMAT_RGBA8)
		target_silhouette.fill(Color.TRANSPARENT)
		create_default_heart_shape()

func create_default_heart_shape():
	"""Create a default heart shape as target"""
	var center = wood_size / 2
	var size = min(wood_size.x, wood_size.y) * 0.3
	
	# Draw two circles for top of heart
	draw_circle_on_image(target_silhouette, center + Vector2(-size * 0.3, -size * 0.2), size * 0.4, Color.BLACK)
	draw_circle_on_image(target_silhouette, center + Vector2(size * 0.3, -size * 0.2), size * 0.4, Color.BLACK)
	
	# Draw triangle for bottom of heart
	for y in range(int(center.y - size * 0.2), int(center.y + size * 0.6)):
		var width_at_y = (center.y + size * 0.6 - y) / (size * 0.8) * size
		for x in range(int(center.x - width_at_y), int(center.x + width_at_y)):
			if x >= 0 and x < wood_size.x and y >= 0 and y < wood_size.y:
				target_silhouette.set_pixel(x, y, Color.BLACK)

func show_menu():
	"""Display main menu"""
	game_state = GameState.MENU
	
	if menu_panel:
		menu_panel.visible = true
	if game_panel:
		game_panel.visible = false
	if completed_panel:
		completed_panel.visible = false
	
	wood_sprite.visible = false
	target_sprite.visible = false
	carving_tool.visible = false

func start_game():
	"""Start a new game"""
	reset_game()
	game_state = GameState.PLAYING
	
	if menu_panel:
		menu_panel.visible = false
	if game_panel:
		game_panel.visible = true
	if completed_panel:
		completed_panel.visible = false
	
	wood_sprite.visible = true
	target_sprite.visible = true
	
	if show_target_button:
		show_target_button.button_pressed = true

func reset_and_start():
	"""Reset and restart current game"""
	start_game()

func reset_game():
	"""Reset all game variables"""
	time_elapsed = 0.0
	cuts_made = 0
	perfect_cuts = 0
	mistakes = 0
	accuracy = 0.0
	score = 0
	
	load_target_silhouette()
	load_wood_texture()
	
	carved_mask = Image.create(int(wood_size.x), int(wood_size.y), false, Image.FORMAT_RGBA8)
	carved_mask.fill(Color.WHITE)
	
	update_wood_sprite()
	update_target_sprite()
	update_ui()

func update_wood_sprite():
	"""Update the wood sprite with carved areas"""
	var display = wood_texture.duplicate()
	var wood_data = display.get_data()
	var mask_data = carved_mask.get_data()
	
	var pixel_count = int(wood_size.x * wood_size.y)
	for i in range(pixel_count):
		var mask_idx = i * 4
		if mask_data[mask_idx] < 128:
			wood_data[mask_idx + 3] = 0
	
	display = Image.create_from_data(int(wood_size.x), int(wood_size.y), false, Image.FORMAT_RGBA8, wood_data)
	wood_sprite.texture = ImageTexture.create_from_image(display)
	needs_wood_update = false

func update_target_sprite():
	"""Update target sprite display"""
	if target_silhouette:
		target_sprite.texture = ImageTexture.create_from_image(target_silhouette)

func update_ui():
	"""Update game UI elements"""
	if game_state == GameState.PLAYING and stats_label:
		stats_label.text = "Time: %.1fs | Score: %d\nAccuracy: %.1f%% | Cuts: %d\nPerfect: %d | Mistakes: %d" % [
			time_elapsed, score, accuracy, cuts_made, perfect_cuts, mistakes
		]
	update_tool_size_label()

func _input(event):
	"""Handle input events"""
	# Keep spacebar shortcut for quick restart
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		if game_state != GameState.PLAYING:
			start_game()
	
	# Mouse wheel still works for tool size
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			change_tool_size(radius_step)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			change_tool_size(-radius_step)
	
	if game_state == GameState.PLAYING:
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
	"""Begin carving operation"""
	is_carving = true
	carving_tool.visible = true
	current_stroke = []
	last_carve_pos = carving_tool.position

func stop_carving():
	"""End carving operation"""
	is_carving = false
	if current_stroke.size() > 0:
		evaluate_stroke()
	current_stroke.clear()
	calculate_accuracy()

func carve_at_position(pos: Vector2):
	"""Carve at the given position"""
	var local_pos = pos - wood_sprite.position + wood_size / 2
	if local_pos.x < 0 or local_pos.x >= wood_size.x or local_pos.y < 0 or local_pos.y >= wood_size.y:
		return
	
	var distance = last_carve_pos.distance_to(pos)
	var steps = max(1, int(distance / carve_radius * 0.5))
	
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
	"""Fast circle carving using precomputed pattern"""
	var mask_data = carved_mask.get_data()
	var width = int(wood_size.x)
	var height = int(wood_size.y)
	
	for offset in circle_pattern:
		var px = int(center.x) + offset.x
		var py = int(center.y) + offset.y
		
		if px >= 0 and px < width and py >= 0 and py < height:
			var idx = (py * width + px) * 4
			mask_data[idx] = 0
			mask_data[idx + 1] = 0
			mask_data[idx + 2] = 0
	
	carved_mask = Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, mask_data)

func evaluate_stroke():
	"""Evaluate the quality of the current stroke"""
	@warning_ignore("integer_division")
	var sample_rate = max(1, current_stroke.size() / 20)
	
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
	
	var stroke_score = (stroke_perfect * base_score_per_cut - stroke_mistakes * base_score_per_cut * 0.5) * size_multiplier
	score += int(stroke_score)

func calculate_accuracy():
	"""Calculate overall carving accuracy"""
	var width = int(wood_size.x)
	var height = int(wood_size.y)
	var total_pixels = width * height
	
	var sample_step = 1
	if total_pixels > 100000:
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
	"""Main game loop"""
	if game_state == GameState.PLAYING:
		time_elapsed += delta
		update_timer += delta
		
		if needs_wood_update and update_timer >= UPDATE_INTERVAL:
			update_wood_sprite()
			update_timer = 0.0
		
		update_ui()
		
		# Update tool visibility
		var mouse_pos = get_viewport().get_mouse_position()
		var in_bounds = Rect2(wood_sprite.position - wood_size/2, wood_size).has_point(mouse_pos)
		carving_tool.visible = in_bounds

func complete_game():
	"""Finish the game and show results"""
	game_state = GameState.COMPLETED
	calculate_accuracy()
	
	# Calculate bonuses
	var time_bonus = max(0, int((60.0 - time_elapsed) * 5))
	var accuracy_bonus = int(accuracy * 2)
	var efficiency_bonus = 0
	if cuts_made > 0:
		efficiency_bonus = int((float(perfect_cuts) / float(cuts_made)) * 100)
	
	var final_score = score + time_bonus + accuracy_bonus + efficiency_bonus
	
	# Update UI
	if menu_panel:
		menu_panel.visible = false
	if game_panel:
		game_panel.visible = false
	if completed_panel:
		completed_panel.visible = true
	
	wood_sprite.visible = false
	target_sprite.visible = false
	carving_tool.visible = false
	
	# Show results
	if completed_stats:
		completed_stats.text = """CARVING COMPLETED!

FINAL SCORE: %d points

Base Score:          %d pts
Time Bonus:          +%d pts
Accuracy Bonus:      +%d pts
Efficiency Bonus:    +%d pts

STATS:
Time Taken:          %.1f seconds
Accuracy:            %.1f%%
Perfect Cuts:        %d
Mistakes:            %d
Total Cuts:          %d
Avg Tool Size:       %.1f px""" % [
			final_score, score, time_bonus, accuracy_bonus, efficiency_bonus,
			time_elapsed, accuracy, perfect_cuts, mistakes, cuts_made, carve_radius
		]

func _on_show_target_toggled(button_pressed: bool):
	"""Toggle target visibility"""
	if target_sprite:
		target_sprite.visible = button_pressed

func quit_game():
	"""Quit the application"""
	get_tree().quit()

func draw_circle_on_image(img: Image, center: Vector2, radius: float, color: Color):
	"""Draw a filled circle on an image"""
	var radius_sq = radius * radius
	for y in range(max(0, int(center.y - radius)), min(img.get_height(), int(center.y + radius + 1))):
		for x in range(max(0, int(center.x - radius)), min(img.get_width(), int(center.x + radius + 1))):
			var dx = x - center.x
			var dy = y - center.y
			if dx * dx + dy * dy <= radius_sq:
				img.set_pixel(x, y, color)
