extends CanvasLayer
class_name BossHealthBar

## Premium Boss Health Bar with layered effects, animations, and full customization
## Just drag the .tscn into your scene and set the boss_node_path!

# === BOSS CONFIGURATION ===
@export_category("Boss Info")
@export var boss_name: String = "FROST TITAN"
@export var boss_subtitle: String = "Guardian of the Frozen Depths"
@export var boss_node_path: NodePath

@export_category("Health Bar Colors")
@export var health_color_full: Color = Color(0.0, 0.92, 1.0, 1.0)
@export var health_color_mid: Color = Color(1.0, 0.6, 0.0, 1.0)
@export var health_color_low: Color = Color(1.0, 0.15, 0.25, 1.0)
@export var frame_color: Color = Color(0.35, 0.42, 0.52, 1.0)
@export var frame_highlight: Color = Color(0.6, 0.7, 0.8, 1.0)
@export var bg_color: Color = Color(0.05, 0.06, 0.1, 0.97)

@export_category("Animation")
@export var health_lerp_speed: float = 4.5
@export var damage_delay_speed: float = 1.2
@export var shake_intensity: float = 8.0
@export var low_health_pulse: bool = true
@export var low_health_threshold: float = 0.25

@export_category("Dimensions")
@export var bar_width: float = 580.0
@export var bar_height: float = 32.0
@export var bar_margin_top: float = 45.0
@export var frame_thickness: float = 4.0

@export_category("Visual Options")
@export var show_health_text: bool = true
@export var show_damage_numbers: bool = true
@export var show_boss_icon: bool = true
@export var animated_background: bool = true
@export var segment_count: int = 10

# Node references
var root: Control
var bar_anchor: Control
var frame_outer: Control
var frame_inner: Control
var bg_panel: Panel
var damage_bar: Panel
var health_bar: Panel
var health_gradient: Panel
var shine_top: Panel
var shine_bottom: Panel
var glow_layer: Control
var inner_glow: Control
var particles_container: Control
var name_container: Control
var name_label: Label
var subtitle_label: Label
var health_text: Label
var left_wing: Control
var right_wing: Control
var center_diamond: Control
var corner_tl: Control
var corner_tr: Control
var corner_bl: Control
var corner_br: Control
var boss_icon_frame: Control
var pulse_overlay: Panel
var energy_lines: Control

# State
var boss: Node = null
var max_health: float = 100.0
var current_health: float = 100.0
var display_health: float = 100.0
var damage_display: float = 100.0
var is_active: bool = false
var shake_time: float = 0.0
var base_position: Vector2
var pulse_tween: Tween
var energy_particles: Array[Dictionary] = []

signal health_depleted

func _ready() -> void:
	layer = 100
	_build_ui()
	visible = false
	
	if boss_node_path:
		call_deferred("_try_auto_connect")

func _try_auto_connect() -> void:
	await get_tree().process_frame
	var node = get_node_or_null(boss_node_path)
	if node:
		setup_boss(node)

func _process(delta: float) -> void:
	if not is_active:
		return
	
	# Smooth health animation
	display_health = lerpf(display_health, current_health, health_lerp_speed * delta)
	damage_display = lerpf(damage_display, current_health, damage_delay_speed * delta)
	
	if absf(display_health - current_health) < 0.3:
		display_health = current_health
	if absf(damage_display - current_health) < 0.3:
		damage_display = current_health
	
	_update_visuals()
	_update_shake(delta)
	
	if animated_background:
		_update_energy_particles(delta)

func _update_shake(delta: float) -> void:
	if shake_time > 0:
		shake_time -= delta
		bar_anchor.position = base_position + Vector2(
			randf_range(-shake_intensity, shake_intensity),
			randf_range(-shake_intensity * 0.5, shake_intensity * 0.5)
		)
	else:
		bar_anchor.position = base_position

# =============================================
#               BUILD UI
# =============================================

func _build_ui() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	
	bar_anchor = Control.new()
	bar_anchor.custom_minimum_size = Vector2(bar_width + 160, 140)
	bar_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bar_anchor)
	
	_center_anchor()
	base_position = bar_anchor.position
	
	_build_glow_layers()
	_build_decorative_frame()
	_build_health_bar_layers()
	_build_overlay_effects()
	_build_text_elements()
	if show_boss_icon:
		_build_boss_icon()

func _center_anchor() -> void:
	var vp = get_viewport().get_visible_rect().size
	bar_anchor.position = Vector2(
		(vp.x - bar_width - 160) / 2,
		bar_margin_top
	)

# =============================================
#            GLOW & ATMOSPHERE
# =============================================

func _build_glow_layers() -> void:
	# Outer atmospheric glow
	glow_layer = Control.new()
	glow_layer.position = Vector2(80, 55)
	glow_layer.custom_minimum_size = Vector2(bar_width, bar_height)
	bar_anchor.add_child(glow_layer)
	
	var outer_glow = Panel.new()
	outer_glow.position = Vector2(-20, -20)
	outer_glow.size = Vector2(bar_width + 40, bar_height + 40)
	var og_style = StyleBoxFlat.new()
	og_style.bg_color = Color(0, 0, 0, 0)
	og_style.shadow_color = health_color_full * Color(1, 1, 1, 0.4)
	og_style.shadow_size = 25
	og_style.set_corner_radius_all(12)
	outer_glow.add_theme_stylebox_override("panel", og_style)
	glow_layer.add_child(outer_glow)
	
	# Inner concentrated glow
	inner_glow = Control.new()
	inner_glow.position = Vector2(80, 55)
	bar_anchor.add_child(inner_glow)
	
	var ig = Panel.new()
	ig.position = Vector2(-8, -8)
	ig.size = Vector2(bar_width + 16, bar_height + 16)
	var ig_style = StyleBoxFlat.new()
	ig_style.bg_color = Color(0, 0, 0, 0)
	ig_style.shadow_color = health_color_full * Color(1, 1, 1, 0.6)
	ig_style.shadow_size = 12
	ig_style.set_corner_radius_all(8)
	ig.add_theme_stylebox_override("panel", ig_style)
	inner_glow.add_child(ig)

# =============================================
#            DECORATIVE FRAME
# =============================================

func _build_decorative_frame() -> void:
	var frame_x = 80.0
	var frame_y = 55.0
	
	# Main frame background
	frame_outer = Control.new()
	frame_outer.position = Vector2(frame_x - frame_thickness, frame_y - frame_thickness)
	frame_outer.custom_minimum_size = Vector2(bar_width + frame_thickness * 2, bar_height + frame_thickness * 2)
	bar_anchor.add_child(frame_outer)
	
	var outer_panel = Panel.new()
	outer_panel.size = Vector2(bar_width + frame_thickness * 2, bar_height + frame_thickness * 2)
	var outer_style = StyleBoxFlat.new()
	outer_style.bg_color = frame_color
	outer_style.set_corner_radius_all(6)
	outer_panel.add_theme_stylebox_override("panel", outer_style)
	frame_outer.add_child(outer_panel)
	
	# Highlight edge (top)
	var highlight = Panel.new()
	highlight.position = Vector2(0, 0)
	highlight.size = Vector2(bar_width + frame_thickness * 2, 2)
	var hl_style = StyleBoxFlat.new()
	hl_style.bg_color = frame_highlight
	hl_style.set_corner_radius_all(1)
	highlight.add_theme_stylebox_override("panel", hl_style)
	frame_outer.add_child(highlight)
	
	# Shadow edge (bottom)
	var shadow = Panel.new()
	shadow.position = Vector2(0, bar_height + frame_thickness * 2 - 2)
	shadow.size = Vector2(bar_width + frame_thickness * 2, 2)
	var sh_style = StyleBoxFlat.new()
	sh_style.bg_color = frame_color * Color(0.5, 0.5, 0.5, 1)
	sh_style.set_corner_radius_all(1)
	shadow.add_theme_stylebox_override("panel", sh_style)
	frame_outer.add_child(shadow)
	
	# Corner accents
	_build_corner_accents(frame_x, frame_y)
	
	# Wing decorations
	_build_wing_decorations(frame_x, frame_y)
	
	# Center diamond emblem
	_build_center_emblem()

func _build_corner_accents(fx: float, fy: float) -> void:
	var corner_size = 14.0
	var positions = [
		Vector2(fx - frame_thickness - 2, fy - frame_thickness - 2),  # TL
		Vector2(fx + bar_width + frame_thickness - corner_size + 2, fy - frame_thickness - 2),  # TR
		Vector2(fx - frame_thickness - 2, fy + bar_height + frame_thickness - corner_size + 2),  # BL
		Vector2(fx + bar_width + frame_thickness - corner_size + 2, fy + bar_height + frame_thickness - corner_size + 2),  # BR
	]
	var rotations = [0, 90, -90, 180]
	
	for i in range(4):
		var corner = Control.new()
		corner.position = positions[i]
		corner.custom_minimum_size = Vector2(corner_size, corner_size)
		bar_anchor.add_child(corner)
		
		var draw = Control.new()
		draw.custom_minimum_size = Vector2(corner_size, corner_size)
		var rot = rotations[i]
		var _frame_hl = frame_highlight
		var _health_col = health_color_full
		
		draw.draw.connect(func():
			var pts: PackedVector2Array
			match rot:
				0: pts = PackedVector2Array([Vector2(0,0), Vector2(corner_size,0), Vector2(0,corner_size)])
				90: pts = PackedVector2Array([Vector2(corner_size,0), Vector2(corner_size,corner_size), Vector2(0,0)])
				-90: pts = PackedVector2Array([Vector2(0,0), Vector2(corner_size,corner_size), Vector2(0,corner_size)])
				180: pts = PackedVector2Array([Vector2(corner_size,corner_size), Vector2(0,corner_size), Vector2(corner_size,0)])
			draw.draw_colored_polygon(pts, _frame_hl * Color(1,1,1,0.9))
			# Inner accent
			var inner_pts: PackedVector2Array
			var offset = 4.0
			match rot:
				0: inner_pts = PackedVector2Array([Vector2(offset,offset), Vector2(corner_size-2,offset), Vector2(offset,corner_size-2)])
				90: inner_pts = PackedVector2Array([Vector2(corner_size-offset,offset), Vector2(corner_size-offset,corner_size-2), Vector2(2,offset)])
				-90: inner_pts = PackedVector2Array([Vector2(offset,2), Vector2(corner_size-2,corner_size-offset), Vector2(offset,corner_size-offset)])
				180: inner_pts = PackedVector2Array([Vector2(corner_size-offset,corner_size-offset), Vector2(2,corner_size-offset), Vector2(corner_size-offset,2)])
			var accent_col = _health_col
			accent_col.a = 0.7
			draw.draw_colored_polygon(inner_pts, accent_col)
		)
		corner.add_child(draw)

func _build_wing_decorations(fx: float, fy: float) -> void:
	# Left wing
	left_wing = Control.new()
	left_wing.position = Vector2(fx - frame_thickness - 45, fy + bar_height / 2 - 20)
	left_wing.custom_minimum_size = Vector2(50, 40)
	bar_anchor.add_child(left_wing)
	
	var left_draw = Control.new()
	left_draw.custom_minimum_size = Vector2(50, 40)
	var _frame_col = frame_color
	var _frame_hl = frame_highlight
	var _health_col = health_color_full
	
	left_draw.draw.connect(func():
		# Wing shape
		var wing = PackedVector2Array([
			Vector2(50, 8), Vector2(50, 32),
			Vector2(30, 28), Vector2(15, 30), Vector2(5, 25),
			Vector2(0, 20), Vector2(5, 15), Vector2(15, 10), Vector2(30, 12)
		])
		left_draw.draw_colored_polygon(wing, _frame_col)
		# Highlight
		left_draw.draw_polyline(wing, _frame_hl * Color(1,1,1,0.7), 1.5, true)
		# Inner line accent
		var inner = PackedVector2Array([Vector2(45, 15), Vector2(25, 17), Vector2(12, 20), Vector2(25, 23), Vector2(45, 25)])
		var accent = _health_col
		accent.a = 0.6
		left_draw.draw_polyline(inner, accent, 2.0, true)
	)
	left_wing.add_child(left_draw)
	
	# Right wing (mirrored)
	right_wing = Control.new()
	right_wing.position = Vector2(fx + bar_width + frame_thickness - 5, fy + bar_height / 2 - 20)
	right_wing.custom_minimum_size = Vector2(50, 40)
	bar_anchor.add_child(right_wing)
	
	var right_draw = Control.new()
	right_draw.custom_minimum_size = Vector2(50, 40)
	
	right_draw.draw.connect(func():
		var wing = PackedVector2Array([
			Vector2(0, 8), Vector2(0, 32),
			Vector2(20, 28), Vector2(35, 30), Vector2(45, 25),
			Vector2(50, 20), Vector2(45, 15), Vector2(35, 10), Vector2(20, 12)
		])
		right_draw.draw_colored_polygon(wing, _frame_col)
		right_draw.draw_polyline(wing, _frame_hl * Color(1,1,1,0.7), 1.5, true)
		var inner = PackedVector2Array([Vector2(5, 15), Vector2(25, 17), Vector2(38, 20), Vector2(25, 23), Vector2(5, 25)])
		var accent = _health_col
		accent.a = 0.6
		right_draw.draw_polyline(inner, accent, 2.0, true)
	)
	right_wing.add_child(right_draw)

func _build_center_emblem() -> void:
	var cx = 80 + bar_width / 2 - 24
	var cy = -5.0
	
	center_diamond = Control.new()
	center_diamond.position = Vector2(cx, cy)
	center_diamond.custom_minimum_size = Vector2(48, 48)
	bar_anchor.add_child(center_diamond)
	
	var diamond_draw = Control.new()
	diamond_draw.name = "DiamondDraw"
	diamond_draw.custom_minimum_size = Vector2(48, 48)
	diamond_draw.draw.connect(_draw_center_diamond.bind(diamond_draw))
	center_diamond.add_child(diamond_draw)

func _draw_center_diamond(node: Control) -> void:
	var c = Vector2(24, 24)
	var outer = PackedVector2Array([
		c + Vector2(0, -24), c + Vector2(24, 0), c + Vector2(0, 24), c + Vector2(-24, 0)
	])
	
	# Outer frame
	node.draw_colored_polygon(outer, frame_color)
	
	# Highlight edges
	node.draw_line(outer[3], outer[0], frame_highlight, 2.0, true)
	node.draw_line(outer[0], outer[1], frame_highlight * Color(1,1,1,0.7), 1.5, true)
	
	# Shadow edges  
	node.draw_line(outer[1], outer[2], frame_color * Color(0.5,0.5,0.5,1), 2.0, true)
	node.draw_line(outer[2], outer[3], frame_color * Color(0.6,0.6,0.6,1), 1.5, true)
	
	# Inner diamond
	var inner = PackedVector2Array([
		c + Vector2(0, -16), c + Vector2(16, 0), c + Vector2(0, 16), c + Vector2(-16, 0)
	])
	node.draw_colored_polygon(inner, bg_color)
	
	# Health-colored core
	var core = PackedVector2Array([
		c + Vector2(0, -10), c + Vector2(10, 0), c + Vector2(0, 10), c + Vector2(-10, 0)
	])
	var col = _get_health_color()
	col.a = 0.9
	node.draw_colored_polygon(core, col)
	
	# Core glow lines
	var glow_col = col
	glow_col.a = 0.5
	for i in range(4):
		node.draw_line(core[i], core[(i+1)%4], glow_col, 2.0, true)
	
	# Center dot
	node.draw_circle(c, 3, Color.WHITE * Color(1,1,1,0.9))

# =============================================
#            HEALTH BAR LAYERS
# =============================================

func _build_health_bar_layers() -> void:
	var bx = 80.0
	var by = 55.0
	
	# Dark background
	bg_panel = Panel.new()
	bg_panel.position = Vector2(bx, by)
	bg_panel.size = Vector2(bar_width, bar_height)
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = bg_color
	bg_style.set_corner_radius_all(4)
	bg_panel.add_theme_stylebox_override("panel", bg_style)
	bar_anchor.add_child(bg_panel)
	
	# Animated energy background
	if animated_background:
		_build_energy_background(bx, by)
	
	# Damage indicator (red delayed bar)
	damage_bar = Panel.new()
	damage_bar.position = Vector2(bx + 3, by + 3)
	damage_bar.size = Vector2(bar_width - 6, bar_height - 6)
	var dmg_style = StyleBoxFlat.new()
	dmg_style.bg_color = Color(0.9, 0.1, 0.1, 0.85)
	dmg_style.set_corner_radius_all(3)
	damage_bar.add_theme_stylebox_override("panel", dmg_style)
	bar_anchor.add_child(damage_bar)
	
	# Main health fill
	health_bar = Panel.new()
	health_bar.position = Vector2(bx + 3, by + 3)
	health_bar.size = Vector2(bar_width - 6, bar_height - 6)
	health_bar.clip_contents = true
	var hp_style = StyleBoxFlat.new()
	hp_style.bg_color = health_color_full
	hp_style.set_corner_radius_all(3)
	health_bar.add_theme_stylebox_override("panel", hp_style)
	bar_anchor.add_child(health_bar)
	
	# Gradient overlay on health (lighter at top)
	health_gradient = Panel.new()
	health_gradient.position = Vector2(0, 0)
	health_gradient.size = Vector2(bar_width - 6, (bar_height - 6) / 2)
	var grad_style = StyleBoxFlat.new()
	grad_style.bg_color = Color(1, 1, 1, 0.2)
	grad_style.set_corner_radius_all(3)
	health_gradient.add_theme_stylebox_override("panel", grad_style)
	health_bar.add_child(health_gradient)
	
	# Top shine line
	shine_top = Panel.new()
	shine_top.position = Vector2(bx + 3, by + 3)
	shine_top.size = Vector2(bar_width - 6, 4)
	var st_style = StyleBoxFlat.new()
	st_style.bg_color = Color(1, 1, 1, 0.25)
	st_style.set_corner_radius_all(2)
	shine_top.add_theme_stylebox_override("panel", st_style)
	bar_anchor.add_child(shine_top)
	
	# Bottom shadow line
	shine_bottom = Panel.new()
	shine_bottom.position = Vector2(bx + 3, by + bar_height - 7)
	shine_bottom.size = Vector2(bar_width - 6, 4)
	var sb_style = StyleBoxFlat.new()
	sb_style.bg_color = Color(0, 0, 0, 0.3)
	sb_style.set_corner_radius_all(2)
	shine_bottom.add_theme_stylebox_override("panel", sb_style)
	bar_anchor.add_child(shine_bottom)
	
	# Segment dividers
	if segment_count > 0:
		_build_segments(bx, by)
	
	# Moving shine streak
	_build_shine_streak(bx, by)

func _build_energy_background(bx: float, by: float) -> void:
	particles_container = Control.new()
	particles_container.position = Vector2(bx + 3, by + 3)
	particles_container.custom_minimum_size = Vector2(bar_width - 6, bar_height - 6)
	particles_container.clip_contents = true
	bar_anchor.add_child(particles_container)
	
	energy_lines = Control.new()
	energy_lines.custom_minimum_size = Vector2(bar_width - 6, bar_height - 6)
	energy_lines.draw.connect(_draw_energy_particles)
	particles_container.add_child(energy_lines)
	
	# Initialize particles
	for i in range(12):
		energy_particles.append({
			"x": randf() * (bar_width - 6),
			"y": randf() * (bar_height - 6),
			"speed": randf_range(15, 40),
			"size": randf_range(1.5, 3.5),
			"alpha": randf_range(0.2, 0.5)
		})

func _draw_energy_particles() -> void:
	var col = _get_health_color()
	for p in energy_particles:
		var c = col
		c.a = p.alpha
		energy_lines.draw_circle(Vector2(p.x, p.y), p.size, c)

func _update_energy_particles(delta: float) -> void:
	var w = bar_width - 6
	for p in energy_particles:
		p.x += p.speed * delta
		if p.x > w:
			p.x = -5
			p.y = randf() * (bar_height - 6)
	if energy_lines:
		energy_lines.queue_redraw()

func _build_segments(bx: float, by: float) -> void:
	var segs = Control.new()
	segs.position = Vector2(bx + 3, by + 3)
	segs.custom_minimum_size = Vector2(bar_width - 6, bar_height - 6)
	
	var _w = bar_width - 6
	var _h = bar_height - 6
	var _count = segment_count
	
	segs.draw.connect(func():
		for i in range(1, _count):
			var x = (_w / _count) * i
			# Dark line
			segs.draw_line(Vector2(x, 0), Vector2(x, _h), Color(0, 0, 0, 0.4), 2.0)
			# Highlight
			segs.draw_line(Vector2(x + 1, 0), Vector2(x + 1, _h), Color(1, 1, 1, 0.1), 1.0)
	)
	bar_anchor.add_child(segs)

func _build_shine_streak(bx: float, by: float) -> void:
	var clip = Control.new()
	clip.position = Vector2(bx + 3, by + 3)
	clip.size = Vector2(bar_width - 6, bar_height - 6)
	clip.clip_contents = true
	bar_anchor.add_child(clip)
	
	var streak = Panel.new()
	streak.name = "ShineStreak"
	streak.size = Vector2(80, bar_height - 6)
	streak.position = Vector2(-100, 0)
	
	# Create angled shine effect
	var streak_style = StyleBoxFlat.new()
	streak_style.bg_color = Color(1, 1, 1, 0.08)
	streak_style.skew = Vector2(0.3, 0)
	streak.add_theme_stylebox_override("panel", streak_style)
	clip.add_child(streak)
	
	# Animate
	var tw = create_tween()
	tw.set_loops()
	tw.tween_property(streak, "position:x", bar_width + 50, 3.0).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(streak, "position:x", -100.0, 0.0)
	tw.tween_interval(1.5)

# =============================================
#            OVERLAY EFFECTS
# =============================================

func _build_overlay_effects() -> void:
	# Pulse overlay for low health
	pulse_overlay = Panel.new()
	pulse_overlay.position = Vector2(80, 55)
	pulse_overlay.size = Vector2(bar_width, bar_height)
	pulse_overlay.modulate.a = 0
	var pulse_style = StyleBoxFlat.new()
	pulse_style.bg_color = health_color_low
	pulse_style.set_corner_radius_all(4)
	pulse_overlay.add_theme_stylebox_override("panel", pulse_style)
	bar_anchor.add_child(pulse_overlay)

# =============================================
#            TEXT ELEMENTS
# =============================================

func _build_text_elements() -> void:
	name_container = Control.new()
	name_container.position = Vector2(80, 8)
	bar_anchor.add_child(name_container)
	
	# Boss name shadow
	var shadow = Label.new()
	shadow.text = boss_name
	shadow.position = Vector2(2, 2)
	shadow.add_theme_font_size_override("font_size", 28)
	shadow.add_theme_color_override("font_color", Color(0, 0, 0, 0.7))
	name_container.add_child(shadow)
	
	# Boss name main
	name_label = Label.new()
	name_label.text = boss_name
	name_label.add_theme_font_size_override("font_size", 28)
	name_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	name_container.add_child(name_label)
	
	# Subtitle
	subtitle_label = Label.new()
	subtitle_label.text = boss_subtitle
	subtitle_label.position = Vector2(80, 35)
	subtitle_label.add_theme_font_size_override("font_size", 12)
	subtitle_label.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75, 0.85))
	bar_anchor.add_child(subtitle_label)
	
	# Health numbers
	if show_health_text:
		health_text = Label.new()
		health_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		health_text.position = Vector2(80, 92)
		health_text.size = Vector2(bar_width, 20)
		health_text.add_theme_font_size_override("font_size", 14)
		health_text.add_theme_color_override("font_color", Color(0.75, 0.8, 0.88, 0.95))
		bar_anchor.add_child(health_text)

# =============================================
#              BOSS ICON
# =============================================

func _build_boss_icon() -> void:
	boss_icon_frame = Control.new()
	boss_icon_frame.position = Vector2(10, 40)
	boss_icon_frame.custom_minimum_size = Vector2(60, 60)
	bar_anchor.add_child(boss_icon_frame)
	
	var icon_draw = Control.new()
	icon_draw.custom_minimum_size = Vector2(60, 60)
	var _frame_col = frame_color
	var _frame_hl = frame_highlight
	var _bg = bg_color
	var _health = health_color_full
	
	icon_draw.draw.connect(func():
		# Outer octagon frame
		var outer = _make_octagon(Vector2(30, 30), 30)
		icon_draw.draw_colored_polygon(outer, _frame_col)
		
		# Highlight
		for i in range(4):
			icon_draw.draw_line(outer[i], outer[(i+1)%8], _frame_hl * Color(1,1,1,0.8), 2.0, true)
		
		# Inner octagon
		var inner = _make_octagon(Vector2(30, 30), 24)
		icon_draw.draw_colored_polygon(inner, _bg)
		
		# Placeholder icon (skull silhouette)
		var skull_col = _health
		skull_col.a = 0.6
		icon_draw.draw_circle(Vector2(30, 26), 10, skull_col)
		icon_draw.draw_circle(Vector2(30, 35), 6, skull_col)
		icon_draw.draw_circle(Vector2(24, 24), 3, _bg)
		icon_draw.draw_circle(Vector2(36, 24), 3, _bg)
	)
	boss_icon_frame.add_child(icon_draw)

func _make_octagon(center: Vector2, radius: float) -> PackedVector2Array:
	var pts: PackedVector2Array = []
	for i in range(8):
		var angle = (i * PI / 4) - PI / 8
		pts.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return pts

# =============================================
#             UPDATE VISUALS
# =============================================

func _update_visuals() -> void:
	var hp_pct = clampf(display_health / max_health, 0, 1)
	var dmg_pct = clampf(damage_display / max_health, 0, 1)
	
	var fill_w = (bar_width - 6) * hp_pct
	var dmg_w = (bar_width - 6) * dmg_pct
	
	health_bar.size.x = maxf(0, fill_w)
	damage_bar.size.x = maxf(0, dmg_w)
	shine_top.size.x = maxf(0, fill_w)
	shine_bottom.size.x = maxf(0, fill_w)
	
	var col = _get_health_color()
	
	# Update health bar color
	var hp_style = health_bar.get_theme_stylebox("panel") as StyleBoxFlat
	if hp_style:
		hp_style.bg_color = col
	
	# Update glows
	_update_glow_colors(col)
	
	# Update text
	if health_text:
		health_text.text = "%d / %d" % [ceili(display_health), int(max_health)]
	
	# Redraw emblem
	var dd = center_diamond.get_node_or_null("DiamondDraw")
	if dd:
		dd.queue_redraw()
	
	# Low health pulse
	if low_health_pulse and hp_pct <= low_health_threshold and hp_pct > 0:
		_start_pulse()
	else:
		_stop_pulse()

func _get_health_color() -> Color:
	var pct = display_health / max_health
	if pct > 0.55:
		return health_color_full
	elif pct > 0.28:
		var t = (pct - 0.28) / 0.27
		return health_color_mid.lerp(health_color_full, t)
	else:
		var t = pct / 0.28
		return health_color_low.lerp(health_color_mid, t)

func _update_glow_colors(col: Color) -> void:
	if glow_layer and glow_layer.get_child_count() > 0:
		var p = glow_layer.get_child(0) as Panel
		if p:
			var s = p.get_theme_stylebox("panel") as StyleBoxFlat
			if s:
				s.shadow_color = col * Color(1,1,1,0.4)
	
	if inner_glow and inner_glow.get_child_count() > 0:
		var p = inner_glow.get_child(0) as Panel
		if p:
			var s = p.get_theme_stylebox("panel") as StyleBoxFlat
			if s:
				s.shadow_color = col * Color(1,1,1,0.6)

func _start_pulse() -> void:
	if pulse_tween and pulse_tween.is_running():
		return
	pulse_tween = create_tween()
	pulse_tween.set_loops()
	pulse_tween.tween_property(pulse_overlay, "modulate:a", 0.3, 0.4)
	pulse_tween.tween_property(pulse_overlay, "modulate:a", 0.0, 0.4)

func _stop_pulse() -> void:
	if pulse_tween:
		pulse_tween.kill()
		pulse_tween = null
	pulse_overlay.modulate.a = 0

# =============================================
#              PUBLIC API
# =============================================

func setup_boss(boss_node: Node, custom_name: String = "", custom_subtitle: String = "") -> void:
	boss = boss_node
	
	if custom_name != "":
		boss_name = custom_name
	if custom_subtitle != "":
		boss_subtitle = custom_subtitle
	
	_update_labels()
	
	if "max_health" in boss:
		max_health = boss.max_health
	if "current_health" in boss:
		current_health = boss.current_health
	else:
		current_health = max_health
	
	display_health = current_health
	damage_display = current_health
	
	if boss.has_signal("health_changed"):
		if not boss.health_changed.is_connected(_on_health_changed):
			boss.health_changed.connect(_on_health_changed)
	
	if boss.has_signal("boss_defeated"):
		if not boss.boss_defeated.is_connected(_on_boss_defeated):
			boss.boss_defeated.connect(_on_boss_defeated)
	
	show_bar()

func _update_labels() -> void:
	if name_label:
		name_label.text = boss_name
		var shadow = name_container.get_child(0) as Label
		if shadow:
			shadow.text = boss_name
	if subtitle_label:
		subtitle_label.text = boss_subtitle

func show_bar() -> void:
	visible = true
	is_active = true
	_center_anchor()
	base_position = bar_anchor.position
	
	bar_anchor.modulate.a = 0
	bar_anchor.position.y = base_position.y - 30
	
	var tw = create_tween()
	tw.set_ease(Tween.EASE_OUT)
	tw.set_trans(Tween.TRANS_BACK)
	tw.tween_property(bar_anchor, "modulate:a", 1.0, 0.5)
	tw.parallel().tween_property(bar_anchor, "position:y", base_position.y, 0.8)

func hide_bar() -> void:
	var tw = create_tween()
	tw.tween_property(bar_anchor, "modulate:a", 0.0, 0.4)
	tw.parallel().tween_property(bar_anchor, "position:y", base_position.y - 25, 0.4)
	await tw.finished
	visible = false
	is_active = false

func set_health(val: float) -> void:
	var old = current_health
	current_health = clampf(val, 0, max_health)
	if current_health < old:
		_on_damage(old - current_health)

func deal_damage(amount: float) -> void:
	set_health(current_health - amount)

# =============================================
#             EVENT HANDLERS
# =============================================

func _on_health_changed(new_hp: float, new_max: float) -> void:
	var old = current_health
	max_health = new_max
	current_health = new_hp
	if new_hp < old:
		_on_damage(old - new_hp)

func _on_damage(amount: float) -> void:
	# Flash
	health_bar.modulate = Color(3, 3, 3, 1)
	var tw = create_tween()
	tw.tween_property(health_bar, "modulate", Color(1,1,1,1), 0.1)
	
	# Shake
	shake_time = 0.25
	
	# Damage number
	if show_damage_numbers:
		_spawn_damage_num(amount)

func _spawn_damage_num(amt: float) -> void:
	var lbl = Label.new()
	lbl.text = "-%d" % ceili(amt)
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.add_theme_color_override("font_color", Color(1, 0.2, 0.2, 1))
	lbl.add_theme_color_override("font_outline_color", Color(0,0,0,0.9))
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.position = Vector2(80 + randf_range(50, bar_width - 50), 40)
	bar_anchor.add_child(lbl)
	
	var tw = create_tween()
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "position:y", lbl.position.y - 40, 0.6)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.6).set_delay(0.15)
	await tw.finished
	lbl.queue_free()

func _on_boss_defeated() -> void:
	_stop_pulse()
	shake_intensity = 15.0
	shake_time = 1.5
	
	bar_anchor.modulate = Color(2.5, 0.4, 0.4, 1)
	var tw = create_tween()
	tw.tween_property(bar_anchor, "modulate", Color(1,1,1,1), 0.3)
	
	await get_tree().create_timer(1.5).timeout
	shake_intensity = 8.0
	health_depleted.emit()
	await hide_bar()
