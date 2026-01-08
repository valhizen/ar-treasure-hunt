extends Node2D
## Simple Arena Manager
## Handles Death Screen only (No Victory Screen)

@export var boss_path: NodePath
@export var player_path: NodePath

var boss: Node2D
var player: Node2D

# UI References
var restart_ui: CanvasLayer
var status_label: Label
var action_button: Button

# State Flags
var victory_triggered: bool = false
var game_over_triggered: bool = false

func _ready() -> void:
	# 1. Find Boss
	if boss_path:
		boss = get_node_or_null(boss_path)
	else:
		var bosses = get_tree().get_nodes_in_group("boss")
		if bosses.size() > 0:
			boss = bosses[0]
	
	# 2. Find Player
	if player_path:
		player = get_node_or_null(player_path)
	else:
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player = players[0]
	
	# 3. Connect Signals
	if boss and boss.has_signal("boss_defeated"):
		boss.boss_defeated.connect(_on_boss_defeated)
	
	if player and player.has_signal("player_died"):
		player.player_died.connect(_on_player_died)
	
	# 4. Build UI (Hidden by default)
	_create_restart_ui()

func _create_restart_ui() -> void:
	restart_ui = CanvasLayer.new()
	restart_ui.layer = 100
	restart_ui.visible = false
	add_child(restart_ui)
	
	# Dark background
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.7)
	restart_ui.add_child(bg)
	
	# Center container
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.add_child(center)
	
	# VBox
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	center.add_child(vbox)
	
	# Label
	status_label = Label.new()
	status_label.text = "YOU DIED"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 48)
	status_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	vbox.add_child(status_label)
	
	# Button
	action_button = Button.new()
	action_button.text = "RESTART"
	action_button.custom_minimum_size = Vector2(200, 50)
	action_button.add_theme_font_size_override("font_size", 24)
	action_button.pressed.connect(_restart)
	vbox.add_child(action_button)

func _on_player_died() -> void:
	# If we already won, do NOT show the death screen
	if victory_triggered:
		return
		
	# Check if boss is essentially dead (Simultaneous death check)
	if boss and "current_health" in boss and boss.current_health <= 0:
		return
	
	game_over_triggered = true
	
	# Wait a moment for death animation
	await get_tree().create_timer(1.5).timeout
	
	# Check victory again just in case boss died during the timer
	if victory_triggered:
		return
	
	# Show "YOU DIED" UI
	restart_ui.visible = true

func _on_boss_defeated() -> void:
	# 1. Mark victory so Player Death logic knows to stop
	victory_triggered = true
	
	# 2. Cleanup dangerous projectiles
	_cleanup_boss_attacks()
	
	# 3. DO NOTHING ELSE.
	# We do not make restart_ui visible. 
	# The player stays in the scene with the dead boss.

func _cleanup_boss_attacks() -> void:
	var projectiles = get_tree().get_nodes_in_group("boss_projectile")
	for proj in projectiles:
		if is_instance_valid(proj):
			proj.queue_free()
	
	if get_tree().current_scene:
		for child in get_tree().current_scene.get_children():
			if child.name.begins_with("StoneProjectile"):
				child.queue_free()

func _restart() -> void:
	get_tree().reload_current_scene()

func _input(event: InputEvent) -> void:
	# Only allow restart shortcut if the UI is actually visible (Player Died)
	if restart_ui.visible:
		if event.is_action_pressed("ui_accept") or (event is InputEventKey and event.keycode == KEY_R and event.pressed):
			_restart()
