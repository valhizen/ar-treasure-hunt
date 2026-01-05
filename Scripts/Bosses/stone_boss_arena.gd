extends Node2D

## Simple Arena Manager with Restart Button

@export var boss_path: NodePath
@export var player_path: NodePath

var boss: Node2D
var player: Node2D
var restart_ui: CanvasLayer
var is_fight_over: bool = false


func _ready() -> void:
	# Get references
	if boss_path:
		boss = get_node_or_null(boss_path)
	else:
		var bosses = get_tree().get_nodes_in_group("boss")
		if bosses.size() > 0:
			boss = bosses[0]
	
	if player_path:
		player = get_node_or_null(player_path)
	else:
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player = players[0]
	
	# Connect signals
	if boss and boss.has_signal("boss_defeated"):
		boss.boss_defeated.connect(_on_boss_defeated)
	
	if player and player.has_signal("player_died"):
		player.player_died.connect(_on_player_died)
	
	# Create restart UI (hidden)
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
	var label = Label.new()
	label.name = "StatusLabel"
	label.text = "YOU DIED"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 48)
	label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	vbox.add_child(label)
	
	# Restart button
	var btn = Button.new()
	btn.text = "RESTART"
	btn.custom_minimum_size = Vector2(200, 50)
	btn.add_theme_font_size_override("font_size", 24)
	btn.pressed.connect(_restart)
	vbox.add_child(btn)


func _on_player_died() -> void:
	if is_fight_over:
		return
	is_fight_over = true
	
	await get_tree().create_timer(1.5).timeout
	
	var label = restart_ui.get_node_or_null("ColorRect/CenterContainer/VBoxContainer/StatusLabel")
	if label:
		label.text = "YOU DIED"
		label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	
	restart_ui.visible = true


func _on_boss_defeated() -> void:
	if is_fight_over:
		return
	is_fight_over = true
	
	await get_tree().create_timer(2.0).timeout
	
	var label = restart_ui.get_node_or_null("ColorRect/CenterContainer/VBoxContainer/StatusLabel")
	if label:
		label.text = "VICTORY!"
		label.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
	
	restart_ui.visible = true


func _restart() -> void:
	get_tree().reload_current_scene()


func _input(event: InputEvent) -> void:
	if is_fight_over:
		if event.is_action_pressed("ui_accept") or (event is InputEventKey and event.keycode == KEY_R and event.pressed):
			_restart()
