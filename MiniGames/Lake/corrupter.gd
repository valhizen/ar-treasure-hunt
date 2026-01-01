extends Node2D

@export var defuse_time: float = 3.0
@export var interaction_range: float = 80.0
@export var corrupted_color: Color = Color(0.8, 0.1, 0.1, 1)  # Red
@export var defused_color: Color = Color(0.1, 0.8, 0.1, 1)  # Green

var defuse_progress: float = 0.0
var is_defused: bool = false
var player_in_range: bool = false
var player: Node2D = null

@onready var colored_rect: ColorRect = $ColorRect
@onready var progress_bar: ProgressBar = $ProgressBar
@onready var interaction_label: Label = $InteractionLabel
@onready var detection_area: Area2D = $DetectionArea

func _ready() -> void:
	# Setup colored rect
	if not has_node("ColorRect"):
		colored_rect = ColorRect.new()
		add_child(colored_rect)
		colored_rect.size = Vector2(64, 64)
		colored_rect.position = Vector2(-32, -32)
	
	colored_rect.color = corrupted_color
	
	# Setup progress bar
	if not has_node("ProgressBar"):
		progress_bar = ProgressBar.new()
		add_child(progress_bar)
		progress_bar.position = Vector2(-40, -50)
		progress_bar.size = Vector2(80, 10)
	
	progress_bar.max_value = defuse_time
	progress_bar.value = 0
	progress_bar.show_percentage = false
	progress_bar.visible = false
	
	# Style progress bar
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.2, 0.2, 0.2, 0.8)
	progress_bar.add_theme_stylebox_override("background", bg_style)
	
	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = Color(0.2, 0.6, 1, 1)  # Blue
	progress_bar.add_theme_stylebox_override("fill", fill_style)
	
	# Setup interaction label
	if not has_node("InteractionLabel"):
		interaction_label = Label.new()
		add_child(interaction_label)
		interaction_label.position = Vector2(-30, 40)
	
	interaction_label.text = "[E] Defuse"
	interaction_label.visible = false
	
	# Setup detection area
	if not has_node("DetectionArea"):
		detection_area = Area2D.new()
		add_child(detection_area)
		
		var collision_shape = CollisionShape2D.new()
		var circle = CircleShape2D.new()
		circle.radius = interaction_range
		collision_shape.shape = circle
		detection_area.add_child(collision_shape)
	
	detection_area.body_entered.connect(_on_detection_area_entered)
	detection_area.body_exited.connect(_on_detection_area_exited)
	
	# Find player
	player = get_tree().get_first_node_in_group("player")

func _process(delta: float) -> void:
	if is_defused:
		return
	
	# Check if player is in range
	if player:
		var distance = global_position.distance_to(player.global_position)
		player_in_range = distance <= interaction_range
	
	# Show/hide interaction prompt
	interaction_label.visible = player_in_range and not is_defused
	
	# Handle defusing
	if player_in_range and Input.is_action_pressed("interact"):
		_defuse(delta)
	else:
		# Hide progress bar when not defusing
		if defuse_progress > 0 and not Input.is_action_pressed("interact"):
			progress_bar.visible = false

func _defuse(delta: float) -> void:
	# Increase defuse progress
	defuse_progress += delta
	
	# Update progress bar
	progress_bar.value = defuse_progress
	progress_bar.visible = true
	
	# Check if defusing is complete
	if defuse_progress >= defuse_time:
		_complete_defuse()

func _complete_defuse() -> void:
	is_defused = true
	colored_rect.color = defused_color
	progress_bar.visible = false
	interaction_label.visible = false
	
	# Optional: emit signal or call function
	print("Corrupter defused!")

func _on_detection_area_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = true

func _on_detection_area_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		progress_bar.visible = false
