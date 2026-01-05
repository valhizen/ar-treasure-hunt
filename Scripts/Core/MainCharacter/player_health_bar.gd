extends CanvasLayer
class_name PlayerHealthBar

## Simple Player Health Bar - Shows at bottom of screen during boss fights

@export_category("Player Reference")
@export var player_node_path: NodePath

@export_category("Colors")
@export var health_color: Color = Color(0.2, 0.85, 0.3, 1.0)
@export var damage_color: Color = Color(0.9, 0.15, 0.15, 0.8)
@export var bg_color: Color = Color(0.1, 0.1, 0.15, 0.95)
@export var frame_color: Color = Color(0.5, 0.55, 0.6, 1.0)

@export_category("Size")
@export var bar_width: float = 280.0
@export var bar_height: float = 22.0
@export var margin_bottom: float = 40.0

# Nodes
var container: Control
var bg: ColorRect
var damage_bar: ColorRect
var health_bar: ColorRect
var label: Label
var health_label: Label

# State
var player: Node = null
var max_health: float = 100.0
var current_health: float = 100.0
var display_health: float = 100.0
var damage_display: float = 100.0
var is_active: bool = false


func _ready() -> void:
	layer = 100
	_build_ui()
	
	# Start hidden
	visible = false
	
	# Try to auto-connect if path is set
	if player_node_path:
		call_deferred("_try_connect")


func _try_connect() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var node = get_node_or_null(player_node_path)
	if node:
		setup_player(node)
		show_bar()


func _process(delta: float) -> void:
	if not is_active:
		return
	
	# Smooth health animation
	display_health = lerpf(display_health, current_health, 8.0 * delta)
	damage_display = lerpf(damage_display, current_health, 2.0 * delta)
	
	_update_bars()


func _build_ui() -> void:
	# Main container
	container = Control.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	
	# Position at bottom center
	var vp_size = Vector2(1920, 1080)  # Default, will update
	if get_viewport():
		vp_size = get_viewport().get_visible_rect().size
	
	var bar_x = (vp_size.x - bar_width - 20) / 2
	var bar_y = vp_size.y - bar_height - margin_bottom - 30
	
	# Frame/border
	var frame = ColorRect.new()
	frame.position = Vector2(bar_x - 4, bar_y - 4)
	frame.size = Vector2(bar_width + 28, bar_height + 28)
	frame.color = frame_color
	container.add_child(frame)
	
	# Background
	bg = ColorRect.new()
	bg.position = Vector2(bar_x, bar_y)
	bg.size = Vector2(bar_width + 20, bar_height + 20)
	bg.color = bg_color
	container.add_child(bg)
	
	# Damage bar (red, shows delayed)
	damage_bar = ColorRect.new()
	damage_bar.position = Vector2(bar_x + 5, bar_y + 5)
	damage_bar.size = Vector2(bar_width + 10, bar_height + 10)
	damage_bar.color = damage_color
	container.add_child(damage_bar)
	
	# Health bar (green)
	health_bar = ColorRect.new()
	health_bar.position = Vector2(bar_x + 5, bar_y + 5)
	health_bar.size = Vector2(bar_width + 10, bar_height + 10)
	health_bar.color = health_color
	container.add_child(health_bar)
	
	# "PLAYER" label
	label = Label.new()
	label.text = "PLAYER"
	label.position = Vector2(bar_x, bar_y - 22)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color.WHITE)
	container.add_child(label)
	
	# Health numbers
	health_label = Label.new()
	health_label.text = "100 / 100"
	health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	health_label.position = Vector2(bar_x, bar_y - 22)
	health_label.size = Vector2(bar_width + 20, 20)
	health_label.add_theme_font_size_override("font_size", 14)
	health_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	container.add_child(health_label)


func _update_bars() -> void:
	var hp_pct = clampf(display_health / max_health, 0, 1)
	var dmg_pct = clampf(damage_display / max_health, 0, 1)
	
	health_bar.size.x = (bar_width + 10) * hp_pct
	damage_bar.size.x = (bar_width + 10) * dmg_pct
	
	# Update color based on health
	if hp_pct > 0.5:
		health_bar.color = health_color
	elif hp_pct > 0.25:
		health_bar.color = Color(0.95, 0.75, 0.1)  # Yellow
	else:
		health_bar.color = Color(0.95, 0.2, 0.2)  # Red
	
	health_label.text = "%d / %d" % [ceili(display_health), int(max_health)]


# === PUBLIC API ===

func setup_player(player_node: Node) -> void:
	player = player_node
	print("[PlayerHealthBar] Setting up for player: ", player.name)
	
	if "max_health" in player:
		max_health = player.max_health
	if "current_health" in player:
		current_health = player.current_health
	else:
		current_health = max_health
	
	display_health = current_health
	damage_display = current_health
	
	# Connect signals
	if player.has_signal("health_changed"):
		if not player.health_changed.is_connected(_on_health_changed):
			player.health_changed.connect(_on_health_changed)
			print("[PlayerHealthBar] Connected to health_changed signal")
	
	if player.has_signal("player_died"):
		if not player.player_died.is_connected(_on_player_died):
			player.player_died.connect(_on_player_died)


func show_bar() -> void:
	print("[PlayerHealthBar] Showing bar!")
	visible = true
	is_active = true
	
	# Reposition based on current viewport
	var vp_size = get_viewport().get_visible_rect().size
	var bar_x = (vp_size.x - bar_width - 20) / 2
	var bar_y = vp_size.y - bar_height - margin_bottom - 30
	
	# Update positions
	if bg:
		bg.position = Vector2(bar_x, bar_y)
	if damage_bar:
		damage_bar.position = Vector2(bar_x + 5, bar_y + 5)
	if health_bar:
		health_bar.position = Vector2(bar_x + 5, bar_y + 5)
	if label:
		label.position = Vector2(bar_x, bar_y - 22)
	if health_label:
		health_label.position = Vector2(bar_x, bar_y - 22)
	
	_update_bars()


func hide_bar() -> void:
	visible = false
	is_active = false


func _on_health_changed(new_hp: float, new_max: float) -> void:
	print("[PlayerHealthBar] Health changed: ", new_hp, "/", new_max)
	max_health = new_max
	current_health = new_hp


func _on_player_died() -> void:
	await get_tree().create_timer(2.0).timeout
	hide_bar()
