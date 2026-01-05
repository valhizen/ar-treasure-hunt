# destruction_atmosphere_enhanced.gd
# ENHANCED VERSION - Heavy destruction atmosphere
# Attach this to your scene root node

extends Node

## === SETTINGS ===
@export_category("Atmosphere")
@export var enabled: bool = true
## How destroyed the scene looks (0.0 = slight, 1.0 = heavy destruction)
@export_range(0.0, 1.0) var destruction_level: float = 0.8
@onready var quest_ui: QuestUI = $QuestUI

@export_category("Color Grading")
## Main tint color - cold and abandoned
@export var atmosphere_color: Color = Color(0.55, 0.58, 0.7)
## Secondary darker color for contrast
@export var shadow_tint: Color = Color(0.4, 0.42, 0.55)

@export_category("Vignette")
@export var enable_vignette: bool = true
@export_range(0.0, 1.0) var vignette_intensity: float = 0.7
@export_range(0.0, 1.0) var vignette_size: float = 0.3

@export_category("Dust Particles")
@export var enable_dust: bool = true
@export var dust_amount: int = 120
@export var dust_color: Color = Color(0.9, 0.85, 0.75, 0.4)

@export_category("Floating Debris")
@export var enable_debris: bool = true
@export var debris_amount: int = 30

@export_category("Fog/Haze")
@export var enable_fog: bool = true
@export_range(0.0, 0.5) var fog_intensity: float = 0.15

@export_category("Screen Effects")
@export var enable_noise: bool = true
@export var enable_subtle_shake: bool = false
@export_range(0.0, 2.0) var shake_intensity: float = 0.5

# Internal nodes
var canvas_modulate: CanvasModulate
var effects_layer: CanvasLayer
var vignette_rect: ColorRect
var fog_rect: ColorRect
var noise_rect: ColorRect
var dust_particles: GPUParticles2D
var debris_particles: GPUParticles2D
var camera: Camera2D

var shake_timer: float = 0.0


func _ready() -> void:
	if enabled:
		call_deferred("_setup_atmosphere")
	var objectives: Array[String] = ["Find the exit"]
	quest_ui.add_quest("escape", "Get Out", objectives)



func _process(delta: float) -> void:
	if enable_subtle_shake and camera:
		_apply_subtle_shake(delta)


func _setup_atmosphere() -> void:
	# Find camera for shake effect
	camera = _find_camera()
	
	# 1. Dark color tint
	_create_canvas_modulate()
	
	# 2. Effects layer (vignette, fog, noise)
	_create_effects_layer()
	
	# 3. Dust particles
	if enable_dust:
		_create_dust_particles()
	
	# 4. Debris particles
	if enable_debris:
		_create_debris_particles()


func _find_camera() -> Camera2D:
	# Try to find camera in scene
	var cameras = get_tree().get_nodes_in_group("camera")
	if cameras.size() > 0:
		return cameras[0]
	
	# Search for any Camera2D
	return _find_node_by_class(get_tree().root, "Camera2D")


func _find_node_by_class(node: Node, class_name_str: String) -> Camera2D:
	if node is Camera2D:
		return node
	for child in node.get_children():
		var result = _find_node_by_class(child, class_name_str)
		if result:
			return result
	return null


func _create_canvas_modulate() -> void:
	canvas_modulate = CanvasModulate.new()
	canvas_modulate.name = "DestructionTint"
	# Lerp between normal and destroyed based on level
	var tint = atmosphere_color.lerp(shadow_tint, destruction_level * 0.5)
	canvas_modulate.color = tint
	add_child(canvas_modulate)


func _create_effects_layer() -> void:
	effects_layer = CanvasLayer.new()
	effects_layer.name = "DestructionEffectsLayer"
	effects_layer.layer = 100
	add_child(effects_layer)
	
	# Fog/Haze layer (rendered first, behind vignette)
	if enable_fog:
		_create_fog()
	
	# Film grain/noise
	if enable_noise:
		_create_noise()
	
	# Vignette (rendered last, on top)
	if enable_vignette:
		_create_vignette()


func _create_vignette() -> void:
	vignette_rect = ColorRect.new()
	vignette_rect.name = "Vignette"
	vignette_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var shader_material = ShaderMaterial.new()
	var shader = Shader.new()
	shader.code = """
shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 0.7;
uniform float size : hint_range(0.0, 1.0) = 0.3;
uniform vec4 vignette_color : source_color = vec4(0.0, 0.0, 0.02, 1.0);

void fragment() {
	vec2 center = UV - vec2(0.5);
	float dist = length(center) * 1.8;
	float vignette = smoothstep(size, size + 0.6, dist);
	// Add slight color to vignette (dark blue-ish)
	vec3 color = mix(vec3(0.0), vignette_color.rgb, 0.3);
	COLOR = vec4(color, vignette * intensity);
}
"""
	shader_material.shader = shader
	shader_material.set_shader_parameter("intensity", vignette_intensity * destruction_level)
	shader_material.set_shader_parameter("size", vignette_size)
	shader_material.set_shader_parameter("vignette_color", Color(0.0, 0.0, 0.05, 1.0))
	
	vignette_rect.material = shader_material
	effects_layer.add_child(vignette_rect)


func _create_fog() -> void:
	fog_rect = ColorRect.new()
	fog_rect.name = "Fog"
	fog_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fog_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var shader_material = ShaderMaterial.new()
	var shader = Shader.new()
	shader.code = """
shader_type canvas_item;

uniform float intensity : hint_range(0.0, 0.5) = 0.15;
uniform vec4 fog_color : source_color = vec4(0.4, 0.38, 0.35, 1.0);
uniform float speed : hint_range(0.0, 1.0) = 0.3;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 4; i++) {
		value += amplitude * noise(p);
		p *= 2.0;
		amplitude *= 0.5;
	}
	return value;
}

void fragment() {
	vec2 uv = UV * 3.0;
	float n = fbm(uv + TIME * speed * 0.1);
	n += fbm(uv * 2.0 - TIME * speed * 0.05) * 0.5;
	n = n / 1.5;
	
	// Vary fog density across screen
	float density = n * intensity;
	
	COLOR = vec4(fog_color.rgb, density);
}
"""
	shader_material.shader = shader
	shader_material.set_shader_parameter("intensity", fog_intensity * destruction_level)
	shader_material.set_shader_parameter("fog_color", Color(0.45, 0.42, 0.38, 1.0))
	shader_material.set_shader_parameter("speed", 0.3)
	
	fog_rect.material = shader_material
	effects_layer.add_child(fog_rect)


func _create_noise() -> void:
	noise_rect = ColorRect.new()
	noise_rect.name = "FilmGrain"
	noise_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	noise_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var shader_material = ShaderMaterial.new()
	var shader = Shader.new()
	shader.code = """
shader_type canvas_item;

uniform float intensity : hint_range(0.0, 0.2) = 0.06;

float random(vec2 co, float seed) {
	return fract(sin(dot(co.xy, vec2(12.9898, 78.233)) + seed) * 43758.5453);
}

void fragment() {
	float noise = random(UV * 800.0, TIME * 10.0);
	float grain = (noise - 0.5) * intensity;
	COLOR = vec4(vec3(grain + 0.5), abs(grain) * 2.0);
}
"""
	shader_material.shader = shader
	shader_material.set_shader_parameter("intensity", 0.04 + destruction_level * 0.04)
	
	noise_rect.material = shader_material
	effects_layer.add_child(noise_rect)


func _create_dust_particles() -> void:
	dust_particles = GPUParticles2D.new()
	dust_particles.name = "DustParticles"
	dust_particles.amount = int(dust_amount * destruction_level)
	dust_particles.lifetime = 10.0
	dust_particles.randomness = 1.0
	dust_particles.z_index = 500
	
	var mat = ParticleProcessMaterial.new()
	mat.direction = Vector3(0.2, 0.3, 0)
	mat.spread = 180.0
	mat.gravity = Vector3(0, 8, 0)
	mat.initial_velocity_min = 3.0
	mat.initial_velocity_max = 12.0
	mat.angular_velocity_min = -30.0
	mat.angular_velocity_max = 30.0
	mat.orbit_velocity_min = 0.1
	mat.orbit_velocity_max = 0.3
	mat.scale_min = 1.0
	mat.scale_max = 4.0
	mat.color = dust_color
	
	# Fade in and out
	var gradient = Gradient.new()
	gradient.set_offset(0, 0.0)
	gradient.set_color(0, Color(dust_color.r, dust_color.g, dust_color.b, 0.0))
	gradient.add_point(0.2, dust_color)
	gradient.add_point(0.8, dust_color)
	gradient.set_offset(gradient.get_point_count() - 1, 1.0)
	gradient.set_color(gradient.get_point_count() - 1, Color(dust_color.r, dust_color.g, dust_color.b, 0.0))
	
	var gradient_tex = GradientTexture1D.new()
	gradient_tex.gradient = gradient
	mat.color_ramp = gradient_tex
	
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(700, 500, 0)
	
	dust_particles.process_material = mat
	dust_particles.emitting = true
	
	# Create simple circle texture for particles
	var img = Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	for x in range(8):
		for y in range(8):
			var dist = Vector2(x - 3.5, y - 3.5).length()
			if dist < 3.5:
				var alpha = 1.0 - (dist / 3.5)
				img.set_pixel(x, y, Color(1, 1, 1, alpha * 0.8))
	
	var tex = ImageTexture.create_from_image(img)
	dust_particles.texture = tex
	
	# Position based on viewport
	var viewport_size = get_viewport().get_visible_rect().size
	dust_particles.position = viewport_size / 2
	
	add_child(dust_particles)


func _create_debris_particles() -> void:
	debris_particles = GPUParticles2D.new()
	debris_particles.name = "DebrisParticles"
	debris_particles.amount = int(debris_amount * destruction_level)
	debris_particles.lifetime = 15.0
	debris_particles.randomness = 1.0
	debris_particles.z_index = 400
	
	var mat = ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 180.0
	mat.gravity = Vector3(0, 15, 0)
	mat.initial_velocity_min = 5.0
	mat.initial_velocity_max = 20.0
	mat.angular_velocity_min = -60.0
	mat.angular_velocity_max = 60.0
	mat.scale_min = 2.0
	mat.scale_max = 6.0
	mat.color = Color(0.35, 0.32, 0.28, 0.5)
	
	# Fade out
	var gradient = Gradient.new()
	gradient.set_offset(0, 0.0)
	gradient.set_color(0, Color(0.35, 0.32, 0.28, 0.0))
	gradient.add_point(0.1, Color(0.35, 0.32, 0.28, 0.5))
	gradient.add_point(0.7, Color(0.35, 0.32, 0.28, 0.5))
	gradient.set_offset(gradient.get_point_count() - 1, 1.0)
	gradient.set_color(gradient.get_point_count() - 1, Color(0.35, 0.32, 0.28, 0.0))
	
	var gradient_tex = GradientTexture1D.new()
	gradient_tex.gradient = gradient
	mat.color_ramp = gradient_tex
	
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(700, 100, 0)
	
	debris_particles.process_material = mat
	debris_particles.emitting = true
	
	# Create square debris texture
	var img = Image.create(6, 6, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0.9))
	
	var tex = ImageTexture.create_from_image(img)
	debris_particles.texture = tex
	
	var viewport_size = get_viewport().get_visible_rect().size
	debris_particles.position = Vector2(viewport_size.x / 2, 0)
	
	add_child(debris_particles)


func _apply_subtle_shake(delta: float) -> void:
	if not camera:
		return
	
	shake_timer += delta
	var shake_amount = sin(shake_timer * 2.0) * shake_intensity * destruction_level
	camera.offset = Vector2(
		sin(shake_timer * 3.7) * shake_amount,
		cos(shake_timer * 2.3) * shake_amount * 0.5
	)


## === PUBLIC API ===

## Set destruction level dynamically
func set_destruction_level(level: float) -> void:
	destruction_level = clamp(level, 0.0, 1.0)
	
	# Update tint
	if canvas_modulate:
		var tint = atmosphere_color.lerp(shadow_tint, destruction_level * 0.5)
		canvas_modulate.color = tint
	
	# Update vignette
	if vignette_rect and vignette_rect.material:
		vignette_rect.material.set_shader_parameter("intensity", vignette_intensity * destruction_level)
	
	# Update fog
	if fog_rect and fog_rect.material:
		fog_rect.material.set_shader_parameter("intensity", fog_intensity * destruction_level)
	
	# Update particles
	if dust_particles:
		dust_particles.amount = int(dust_amount * destruction_level)
	if debris_particles:
		debris_particles.amount = int(debris_amount * destruction_level)


## Gradually restore to normal
func restore(duration: float = 3.0) -> void:
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Restore color
	if canvas_modulate:
		tween.tween_property(canvas_modulate, "color", Color.WHITE, duration)
	
	# Fade vignette
	if vignette_rect and vignette_rect.material:
		tween.tween_method(
			func(v): vignette_rect.material.set_shader_parameter("intensity", v),
			vignette_intensity * destruction_level, 0.0, duration
		)
	
	# Fade fog
	if fog_rect and fog_rect.material:
		tween.tween_method(
			func(v): fog_rect.material.set_shader_parameter("intensity", v),
			fog_intensity * destruction_level, 0.0, duration
		)
	
	# Fade particles
	if dust_particles:
		tween.tween_property(dust_particles, "modulate:a", 0.0, duration)
	if debris_particles:
		tween.tween_property(debris_particles, "modulate:a", 0.0, duration)
	
	# Fade noise
	if noise_rect:
		tween.tween_property(noise_rect, "modulate:a", 0.0, duration)


## Toggle all effects
func toggle(on: bool) -> void:
	if canvas_modulate:
		canvas_modulate.visible = on
	if effects_layer:
		effects_layer.visible = on
	if dust_particles:
		dust_particles.visible = on
	if debris_particles:
		debris_particles.visible = on


## Trigger a big shake (for events)
func trigger_shake(duration: float = 0.5, intensity: float = 5.0) -> void:
	if not camera:
		camera = _find_camera()
	if not camera:
		return
	
	var original_offset = camera.offset
	var elapsed = 0.0
	
	while elapsed < duration:
		var shake_power = intensity * (1.0 - elapsed / duration)
		camera.offset = original_offset + Vector2(
			randf_range(-shake_power, shake_power),
			randf_range(-shake_power, shake_power)
		)
		elapsed += get_process_delta_time()
		await get_tree().process_frame
	
	camera.offset = original_offset
