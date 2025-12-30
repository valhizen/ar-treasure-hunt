extends CanvasLayer

@export var player_path: NodePath
@export var health_bar_width: float = 200.0
@export var health_bar_height: float = 20.0
@export var margin: Vector2 = Vector2(20, 20)

var player: Node = null
var health_bar: ProgressBar = null
var health_label: Label = null
var container: PanelContainer = null

func _ready() -> void:
	# Find player
	if player_path:
		player = get_node(player_path)
	else:
		player = get_tree().get_first_node_in_group("player")
	
	if not player:
		push_error("Player not found! Make sure player is in 'player' group or set player_path.")
		return
	
	# Create UI container
	container = PanelContainer.new()
	add_child(container)
	container.position = margin
	
	# Style the panel
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0, 0, 0, 0.7)
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.content_margin_left = 15
	panel_style.content_margin_right = 15
	panel_style.content_margin_top = 10
	panel_style.content_margin_bottom = 10
	container.add_theme_stylebox_override("panel", panel_style)
	
	# Create VBox for vertical layout
	var vbox = VBoxContainer.new()
	container.add_child(vbox)
	vbox.add_theme_constant_override("separation", 5)
	
	# Create health label
	health_label = Label.new()
	vbox.add_child(health_label)
	health_label.text = "Health"
	health_label.add_theme_font_size_override("font_size", 14)
	
	# Create health bar
	health_bar = ProgressBar.new()
	vbox.add_child(health_bar)
	health_bar.custom_minimum_size = Vector2(health_bar_width, health_bar_height)
	health_bar.show_percentage = false
	
	# Style health bar
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.2, 0.2, 0.2, 1)
	bg_style.corner_radius_top_left = 4
	bg_style.corner_radius_top_right = 4
	bg_style.corner_radius_bottom_left = 4
	bg_style.corner_radius_bottom_right = 4
	health_bar.add_theme_stylebox_override("background", bg_style)
	
	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = Color(0.8, 0.2, 0.2, 1)  # Red
	fill_style.corner_radius_top_left = 4
	fill_style.corner_radius_top_right = 4
	fill_style.corner_radius_bottom_left = 4
	fill_style.corner_radius_bottom_right = 4
	health_bar.add_theme_stylebox_override("fill", fill_style)
	
	# Initialize health bar values
	if "max_health" in player:
		health_bar.max_value = player.max_health
	else:
		health_bar.max_value = 100
	
	_update_health()

func _process(_delta: float) -> void:
	if player:
		_update_health()

func _update_health() -> void:
	if not player or not health_bar:
		return
	
	var current_health = 100.0
	if "player_health" in player:
		current_health = player.player_health
	elif "health" in player:
		current_health = player.health
	
	health_bar.value = current_health
	
	# Update label with numeric value
	health_label.text = "Health: %d / %d" % [current_health, health_bar.max_value]
	
	# Change color based on health percentage
	var health_percent = current_health / health_bar.max_value
	var fill_style = health_bar.get_theme_stylebox("fill")
	
	if fill_style is StyleBoxFlat:
		if health_percent > 0.5:
			fill_style.bg_color = Color(0.2, 0.8, 0.2, 1)  # Green
		elif health_percent > 0.25:
			fill_style.bg_color = Color(0.9, 0.7, 0.1, 1)  # Yellow
		else:
			fill_style.bg_color = Color(0.8, 0.2, 0.2, 1)  # Red
