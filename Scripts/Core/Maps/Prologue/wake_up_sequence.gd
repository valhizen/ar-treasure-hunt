# WakeUpSequence.gd
extends CanvasLayer

signal sequence_finished

# Node references
var black_overlay: ColorRect
var blur_overlay: ColorRect
var text_label: Label
var loud_noise: AudioStreamPlayer2D

# Settings
@export var skip_enabled: bool = false

func _ready():
	layer = 100  # Above everything
	_create_overlays()
	_disable_player()
	start_wake_up_sequence()

func _create_overlays():
	# === BLACK OVERLAY ===
	black_overlay = ColorRect.new()
	black_overlay.name = "BlackOverlay"
	black_overlay.color = Color.BLACK
	black_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	black_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(black_overlay)
	
	# === BLUR OVERLAY ===
	blur_overlay = ColorRect.new()
	blur_overlay.name = "BlurOverlay"
	blur_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	blur_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Create blur shader through code
	var shader_material = ShaderMaterial.new()
	var shader = Shader.new()
	shader.code = """
shader_type canvas_item;

uniform float blur_amount : hint_range(0.0, 5.0) = 3.0;
uniform vec4 tint_color : source_color = vec4(0.8, 0.85, 1.0, 0.3);

void fragment() {
	vec2 pixel_size = SCREEN_PIXEL_SIZE * blur_amount * 2.0;
	vec4 color = vec4(0.0);
	
	// Sample surrounding pixels for blur
	float total = 0.0;
	for(float x = -3.0; x <= 3.0; x += 1.0) {
		for(float y = -3.0; y <= 3.0; y += 1.0) {
			float weight = 1.0 - length(vec2(x, y)) / 5.0;
			weight = max(weight, 0.0);
			color += texture(SCREEN_TEXTURE, SCREEN_UV + vec2(x, y) * pixel_size) * weight;
			total += weight;
		}
	}
	color /= total;
	
	// Add slight color tint for "waking up" feel
	color.rgb = mix(color.rgb, tint_color.rgb, tint_color.a * (blur_amount / 3.0));
	
	COLOR = color;
}
"""
	shader_material.shader = shader
	shader_material.set_shader_parameter("blur_amount", 3.0)
	shader_material.set_shader_parameter("tint_color", Color(0.7, 0.75, 1.0, 0.4))
	
	blur_overlay.material = shader_material
	add_child(blur_overlay)
	blur_overlay.visible = false  # Hidden until black fades
	
	# === TEXT LABEL ===
	text_label = Label.new()
	text_label.name = "ThoughtText"
	text_label.set_anchors_preset(Control.PRESET_CENTER)
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text_label.add_theme_font_size_override("font_size", 32)
	text_label.add_theme_color_override("font_color", Color.WHITE)
	text_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	text_label.add_theme_constant_override("shadow_offset_x", 2)
	text_label.add_theme_constant_override("shadow_offset_y", 2)
	text_label.modulate.a = 0.0
	text_label.text = ""
	
	# Center the label properly
	text_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	text_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	text_label.position = Vector2(-200, -50)
	text_label.size = Vector2(400, 100)
	
	add_child(text_label)
	
	# === AUDIO (if you have a child AudioStreamPlayer2D) ===
	loud_noise = get_node_or_null("AudioStreamPlayer2D")

func _disable_player():
	get_tree().call_group("player", "set_can_move", false)

func _enable_player():
	get_tree().call_group("player", "set_can_move", true)

func start_wake_up_sequence():
	# ===== PHASE 1: DARKNESS + LOUD NOISE =====
	black_overlay.modulate.a = 1.0
	
	# Play the loud noise that wakes the character
	if loud_noise:
		loud_noise.play()
	
	await get_tree().create_timer(0.5).timeout
	
	# ===== PHASE 2: FIRST TEXT IN DARKNESS =====
	await show_text("...", 1.5)
	await get_tree().create_timer(0.3).timeout
	
	await show_text("What... what was that?", 2.0)
	await get_tree().create_timer(0.5).timeout
	
	# ===== PHASE 3: EYES OPENING (BLACK FADES, BLUR APPEARS) =====
	blur_overlay.visible = true
	set_blur(3.0)
	
	var fade_tween = create_tween()
	fade_tween.tween_property(black_overlay, "modulate:a", 0.0, 2.0)
	await fade_tween.finished
	
	# ===== PHASE 4: BLURRY VISION + THOUGHTS =====
	await show_text("My head... everything is blurry...", 2.5)
	await get_tree().create_timer(0.3).timeout
	
	# Vision starts clearing
	var blur_tween = create_tween()
	blur_tween.tween_method(set_blur, 3.0, 1.5, 2.0)
	await blur_tween.finished
	
	await show_text("The house looks fine... but that sound...", 2.5)
	await get_tree().create_timer(0.3).timeout
	
	# ===== PHASE 5: VISION CLEARS FULLY =====
	var clear_tween = create_tween()
	clear_tween.tween_method(set_blur, 1.5, 0.0, 1.5)
	await clear_tween.finished
	
	blur_overlay.visible = false
	
	await show_text("I need to check outside!", 2.0)
	await get_tree().create_timer(0.5).timeout
	
	# ===== PHASE 6: SEQUENCE COMPLETE =====
	_enable_player()
	sequence_finished.emit()
	queue_free()

func show_text(message: String, duration: float) -> void:
	text_label.text = message
	
	# Fade in
	var fade_in = create_tween()
	fade_in.tween_property(text_label, "modulate:a", 1.0, 0.4)
	await fade_in.finished
	
	# Wait
	await get_tree().create_timer(duration).timeout
	
	# Fade out
	var fade_out = create_tween()
	fade_out.tween_property(text_label, "modulate:a", 0.0, 0.4)
	await fade_out.finished

func set_blur(value: float):
	if blur_overlay and blur_overlay.material:
		blur_overlay.material.set_shader_parameter("blur_amount", value)

# Optional: Allow skipping with input
func _input(event):
	if skip_enabled and event.is_action_pressed("ui_accept"):
		# Skip to end
		_enable_player()
		sequence_finished.emit()
		queue_free()
