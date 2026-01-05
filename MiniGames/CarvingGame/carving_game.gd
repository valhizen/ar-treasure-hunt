extends Node2D

@export_group("Wood Settings")
@export var wood_size := Vector2(600, 800)
@export var wood_texture_resource: Texture2D 

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

# Optimization: Persistent texture references and Shader
var mask_texture: ImageTexture
var wood_shader_material: ShaderMaterial

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
@onready var ghost_overlay: Sprite2D = $GhostOverlay
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

@onready var completed_panel: Panel = $UI/CompletedPanel
@onready var completed_stats: Label = $UI/CompletedPanel/VBox/StatsLabel
@onready var play_again_button: Button = $UI/CompletedPanel/VBox/PlayAgainButton
@onready var menu_button: Button = $UI/CompletedPanel/VBox/MenuButton

@onready var carve_sfx: AudioStreamPlayer2D = $CarveSFXPlayer
@onready var bgm_player: AudioStreamPlayer2D = $BGMPlayer


var is_carving := false
var last_carve_pos := Vector2.ZERO
var current_stroke := []

var needs_wood_update := false
var update_timer := 0.0
const UPDATE_INTERVAL := 0.05

var circle_pattern = []

# Shader code to handle masking on GPU instead of CPU
const SHADER_CODE = """
shader_type canvas_item;
uniform sampler2D mask_tex;

void fragment() {
	vec4 color = texture(TEXTURE, UV);
	vec4 mask = texture(mask_tex, UV);
	// If mask is black (carved), make pixel transparent
	if (mask.r < 0.5) {
		color.a = 0.0;
	}
	COLOR = color;
}
"""

func _ready():
	setup_scene()
	setup_shader() # Initialize shader optimization
	setup_ui_connections()
	precompute_circle_pattern()
	calculate_size_multiplier()
	create_tool_texture()
	load_target_silhouette()
	show_menu()

func setup_shader():
	"""Create and assign the shader material for GPU masking"""
	wood_shader_material = ShaderMaterial.new()
	var shader = Shader.new()
	shader.code = SHADER_CODE
	wood_shader_material.shader = shader
	wood_sprite.material = wood_shader_material

func setup_scene():
	"""Position main elements"""
	var viewport_size = get_viewport_rect().size
	wood_sprite.position = viewport_size / 2
	target_sprite.position = wood_sprite.position
	ghost_overlay.position = wood_sprite.position
	carving_tool.visible = false

func setup_ui_connections():
	"""Connect all UI button signals"""
	if start_button: start_button.pressed.connect(start_game)
	if quit_button: quit_button.pressed.connect(quit_game)
	if done_button: done_button.pressed.connect(complete_game)
	if reset_button: reset_button.pressed.connect(reset_and_start)
	if increase_tool_button: increase_tool_button.pressed.connect(func(): change_tool_size(radius_step))
	if decrease_tool_button: decrease_tool_button.pressed.connect(func(): change_tool_size(-radius_step))
	if play_again_button: play_again_button.pressed.connect(start_game)
	if menu_button: menu_button.pressed.connect(show_menu)

func precompute_circle_pattern():
	"""Precompute relative positions for circle carving"""
	circle_pattern.clear()
	var radius_sq = carve_radius * carve_radius
	for y in range(-int(carve_radius), int(carve_radius) + 1):
		for x in range(-int(carve_radius), int(carve_radius) + 1):
			if x * x + y * y <= radius_sq:
				circle_pattern.append(Vector2i(x, y))

func calculate_size_multiplier():
	var normalized_size = (carve_radius - min_radius) / (max_radius - min_radius)
	size_multiplier = 1.5 - normalized_size

func change_tool_size(delta: float):
	carve_radius = clamp(carve_radius + delta, min_radius, max_radius)
	precompute_circle_pattern()
	calculate_size_multiplier()
	create_tool_texture()
	update_tool_size_label()

func update_tool_size_label():
	if tool_size_label:
		tool_size_label.text = "Tool: %.0f px (%.1fx)" % [carve_radius, size_multiplier]

func create_tool_texture():
	var size = int(carve_radius * 2) + 4
	var tool_image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	tool_image.fill(Color.TRANSPARENT)
	
	@warning_ignore("integer_division")
	var center = Vector2(size/2, size/2)
	draw_circle_on_image(tool_image, center, carve_radius + 1, Color.WHITE)
	draw_circle_on_image(tool_image, center, carve_radius, tool_color)
	
	tool_circle.texture = ImageTexture.create_from_image(tool_image)
	tool_circle.centered = true

func load_wood():
	"""Load wood texture"""
	if wood_texture_resource:
		wood_texture = wood_texture_resource.get_image().duplicate()
		wood_texture.resize(int(wood_size.x), int(wood_size.y))
		wood_texture.convert(Image.FORMAT_RGBA8)
	else:
		push_warning("No wood texture resource assigned! Using fallback brown texture.")
		wood_texture = Image.create(int(wood_size.x), int(wood_size.y), false, Image.FORMAT_RGBA8)
		var wood_color = Color(0.6, 0.4, 0.2)
		wood_texture.fill(wood_color)
		
		# Optimization: Direct access for noise generation
		var data = wood_texture.get_data()
		var pixel_count = int(wood_size.x * wood_size.y)
		for i in range(pixel_count):
			var noise = randf_range(-0.05, 0.05)
			var idx = i * 4
			data[idx] = int((wood_color.r + noise) * 255)
			data[idx + 1] = int((wood_color.g + noise) * 255)
			data[idx + 2] = int((wood_color.b + noise) * 255)
			data[idx + 3] = 255
		wood_texture.set_data(int(wood_size.x), int(wood_size.y), false, Image.FORMAT_RGBA8, data)
	
	# Set the base texture once
	wood_sprite.texture = ImageTexture.create_from_image(wood_texture)

func load_target_silhouette():
	if target_images.size() > 0:
		chosen_target = target_images.pick_random()
		target_silhouette = chosen_target.get_image().duplicate()
		target_silhouette.resize(int(wood_size.x), int(wood_size.y))
		target_silhouette.convert(Image.FORMAT_RGBA8)
	else:
		target_silhouette = Image.create(int(wood_size.x), int(wood_size.y), false, Image.FORMAT_RGBA8)
		target_silhouette.fill(Color.TRANSPARENT)
		draw_circle_on_image(target_silhouette, wood_size / 2, 100, Color.WHITE)

func show_menu():
	if bgm_player:
		bgm_player.stop()

	game_state = GameState.MENU
	if menu_panel: menu_panel.visible = true
	if game_panel: game_panel.visible = false
	if completed_panel: completed_panel.visible = false
	wood_sprite.visible = false
	target_sprite.visible = false
	ghost_overlay.visible = false
	carving_tool.visible = false

func start_game():
	reset_game()
	if bgm_player and not bgm_player.playing:
		bgm_player.play()
		
	game_state = GameState.PLAYING
	if menu_panel: menu_panel.visible = false
	if game_panel: game_panel.visible = true
	if completed_panel: completed_panel.visible = false
	wood_sprite.visible = true
	target_sprite.visible = true
	ghost_overlay.visible = true

func reset_and_start():
	start_game()

func reset_game():
	time_elapsed = 0.0
	cuts_made = 0
	perfect_cuts = 0
	mistakes = 0
	accuracy = 0.0
	score = 0
	
	load_target_silhouette()
	create_ghost_overlay()
	load_wood()
	
	# Initialize mask
	carved_mask = Image.create(int(wood_size.x), int(wood_size.y), false, Image.FORMAT_RGBA8)
	carved_mask.fill(Color.WHITE)
	
	# Initialize GPU texture for mask
	mask_texture = ImageTexture.create_from_image(carved_mask)
	wood_shader_material.set_shader_parameter("mask_tex", mask_texture)
	
	update_target_sprite()
	update_ui()

func update_wood_sprite():
	"""Optimized: Update the GPU texture only"""
	if mask_texture:
		# ImageTexture.update (or set_image depending on Godot version) is efficient
		mask_texture.update(carved_mask)
	needs_wood_update = false

func update_target_sprite():
	if target_silhouette:
		target_sprite.texture = ImageTexture.create_from_image(target_silhouette)

func update_ui():
	if game_state == GameState.PLAYING and stats_label:
		stats_label.text = "Time: %.1fs | Score: %d\nAccuracy: %.1f%% | Cuts: %d\nPerfect: %d | Mistakes: %d" % [
			time_elapsed, score, accuracy, cuts_made, perfect_cuts, mistakes
		]
	update_tool_size_label()

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		if game_state != GameState.PLAYING:
			start_game()
	
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
	is_carving = true
	carving_tool.visible = true
	current_stroke = []
	last_carve_pos = carving_tool.position
	
	if carve_sfx and not carve_sfx.playing:
		carve_sfx.play()

func stop_carving():
	is_carving = false
	if carve_sfx and carve_sfx.playing:
		carve_sfx.stop()
	if current_stroke.size() > 0:
		evaluate_stroke()
	current_stroke.clear()
	calculate_accuracy()

func carve_at_position(pos: Vector2):
	"""Optimized carving logic"""
	var local_pos = pos - wood_sprite.position + wood_size / 2
	if local_pos.x < 0 or local_pos.x >= wood_size.x or local_pos.y < 0 or local_pos.y >= wood_size.y:
		return
	
	var distance = last_carve_pos.distance_to(pos)
	var steps = max(1, int(distance / carve_radius * 0.5))
	
	# OPTIMIZATION: Get data once, modify, set data once
	var mask_data = carved_mask.get_data()
	var width = int(wood_size.x)
	var height = int(wood_size.y)
	
	for i in range(steps):
		var t = float(i) / float(steps)
		var interp_pos = last_carve_pos.lerp(pos, t)
		var interp_local = interp_pos - wood_sprite.position + wood_size / 2
		# Pass data array directly
		carve_circle_fast_optimized(interp_local, mask_data, width, height)
	
	# Commit changes back to image once
	carved_mask.set_data(width, height, false, Image.FORMAT_RGBA8, mask_data)
	
	last_carve_pos = pos
	current_stroke.append(local_pos)
	cuts_made += 1
	needs_wood_update = true

func carve_circle_fast_optimized(center: Vector2, data: PackedByteArray, width: int, height: int):
	"""Optimized: Modifies byte array directly"""
	var cx = int(center.x)
	var cy = int(center.y)
	
	for offset in circle_pattern:
		var px = cx + offset.x
		var py = cy + offset.y
		
		if px >= 0 and px < width and py >= 0 and py < height:
			var idx = (py * width + px) * 4
			data[idx] = 0     # R
			data[idx + 1] = 0 # G
			data[idx + 2] = 0 # B
			# Alpha remains 255 in mask, shader reads Red channel
	
func evaluate_stroke():
	@warning_ignore("integer_division")
	var sample_rate = max(1, current_stroke.size() / 20)
	
	var stroke_perfect = 0
	var stroke_mistakes = 0
	
	# Optimization: Local access
	var wood_w = wood_size.x
	var wood_h = wood_size.y
	
	for i in range(0, current_stroke.size(), sample_rate):
		var pos = current_stroke[i]
		if pos.x >= 0 and pos.x < wood_w and pos.y >= 0 and pos.y < wood_h:
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
	var width = int(wood_size.x)
	var height = int(wood_size.y)
	
	# Adaptive sampling for performance
	var sample_step = 8
	
	var carved_data = carved_mask.get_data()
	var target_data = target_silhouette.get_data()
	
	var correct = 0
	var total = 0
	
	# Optimized loop
	for y in range(0, height, sample_step):
		var y_offset = y * width
		for x in range(0, width, sample_step):
			var idx = (y_offset + x) * 4
			
			# Check logic: Carved (black, <128) vs Target (visible, >128)
			var carved = carved_data[idx] < 128
			var target = target_data[idx + 3] > 128
			
			total += 1
			if carved == target:
				correct += 1
	
	accuracy = (float(correct) / float(total)) * 100.0

func _process(delta):
	if game_state == GameState.PLAYING:
		time_elapsed += delta
		update_timer += delta
		
		if needs_wood_update and update_timer >= UPDATE_INTERVAL:
			update_wood_sprite()
			update_timer = 0.0
		
		update_ui()
		
		var mouse_pos = get_viewport().get_mouse_position()
		# Simple bounds check
		var half_size = wood_size / 2
		var in_bounds = (mouse_pos.x > wood_sprite.position.x - half_size.x and 
						 mouse_pos.x < wood_sprite.position.x + half_size.x and 
						 mouse_pos.y > wood_sprite.position.y - half_size.y and 
						 mouse_pos.y < wood_sprite.position.y + half_size.y)
		carving_tool.visible = in_bounds

func complete_game():
	game_state = GameState.COMPLETED
	calculate_accuracy() # Final full calculation could go here if needed, but keeping simple
	
	var time_bonus = max(0, int((60.0 - time_elapsed) * 5))
	var accuracy_bonus = int(accuracy * 2)
	var efficiency_bonus = 0
	if cuts_made > 0:
		efficiency_bonus = int((float(perfect_cuts) / float(cuts_made)) * 100)
	
	var final_score = score + time_bonus + accuracy_bonus + efficiency_bonus
	
	if menu_panel: menu_panel.visible = false
	if game_panel: game_panel.visible = false
	if completed_panel: completed_panel.visible = true
	
	wood_sprite.visible = false
	target_sprite.visible = false
	ghost_overlay.visible= false
	carving_tool.visible = false
	
	if bgm_player:
		bgm_player.stop()
	
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

func quit_game():
	get_tree().quit()

func draw_circle_on_image(img: Image, center: Vector2, radius: float, color: Color):
	var radius_sq = radius * radius
	var w = img.get_width()
	var h = img.get_height()
	
	var min_y = max(0, int(center.y - radius))
	var max_y = min(h, int(center.y + radius + 1))
	var min_x = max(0, int(center.x - radius))
	var max_x = min(w, int(center.x + radius + 1))
	
	for y in range(min_y, max_y):
		for x in range(min_x, max_x):
			var dx = x - center.x
			var dy = y - center.y
			if dx * dx + dy * dy <= radius_sq:
				img.set_pixel(x, y, color)

func create_ghost_overlay():
	"""Optimized ghost overlay generation"""
	if not target_silhouette: return

	var width := int(wood_size.x)
	var height := int(wood_size.y)
	var dot_size := 4
	var dot_spacing := 14
	var padding := 3
	var dot_sq = dot_size * dot_size

	var ghost_image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	ghost_image.fill(Color.TRANSPARENT)

	var target_data := target_silhouette.get_data()
	var ghost_data := ghost_image.get_data()

	# Optimization: Flatten loops or just optimize checks
	# Since this runs only once on start, we don't need to go crazy, 
	# but we can skip iterations faster.
	
	for y in range(1, height - 1):
		# Skip rows that don't align with spacing logic to save edge checks
		# Logic in original: if (x + y) % dot_spacing != 0: continue
		# We can't skip rows entirely because x changes the sum, but we can't optimize easily without changing visuals.
		# Keeping original loop logic but cleaner variable access.
		
		var y_idx = y * width
		for x in range(1, width - 1):
			if (x + y) % dot_spacing != 0: continue

			var idx :int = (y_idx + x) * 4
			if target_data[idx + 3] <= 128: continue # Not part of silhouette

			# Check edge (inline optimization)
			var is_edge := false
			
			# Check cardinal neighbors only first for speed (approximate)
			# Or keep full check for exact visual match
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					if dx == 0 and dy == 0: continue
					var nidx :int= ((y + dy) * width + (x + dx)) * 4
					if target_data[nidx + 3] <= 128:
						is_edge = true
						break
				if is_edge: break

			if not is_edge: continue

			# Draw dot
			for py in range(-dot_size, dot_size + 1):
				for px in range(-dot_size, dot_size + 1):
					if px * px + py * py > dot_sq: continue

					var ox := x + px + padding
					var oy := y + py + padding

					if ox < 0 or ox >= width or oy < 0 or oy >= height: continue

					var oidx := (oy * width + ox) * 4
					ghost_data[oidx] = 255
					ghost_data[oidx + 1] = 255
					ghost_data[oidx + 2] = 255
					ghost_data[oidx + 3] = 255

	ghost_image.set_data(width, height, false, Image.FORMAT_RGBA8, ghost_data)
	ghost_overlay.texture = ImageTexture.create_from_image(ghost_image)
