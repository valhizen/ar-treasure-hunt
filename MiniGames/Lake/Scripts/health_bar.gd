extends CanvasLayer

@export var player_path: NodePath
@export var margin := Vector2(20, 20)
@export var health_bar_width := 200.0
@export var health_bar_height := 20.0

var player: Node
var game_manager: Node

var container: PanelContainer
var health_bar: ProgressBar
var health_label: Label
var timer_label: Label
var kill_label: Label

func _ready() -> void:
	# ─── Find Player ───
	if player_path:
		player = get_node(player_path)
	else:
		player = get_tree().get_first_node_in_group("player")

	if not player:
		push_error("HUD: Player not found")
		return

	# ─── Find GameManager ───
	game_manager = get_tree().get_first_node_in_group("game_manager")
	if not game_manager:
		push_error("HUD: GameManager not found")
		return

	# ─── UI Container ───
	container = PanelContainer.new()
	add_child(container)
	container.position = margin

	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0, 0, 0, 0.7)
	panel.set_corner_radius_all(8)
	panel.content_margin_left = 14
	panel.content_margin_right = 14
	panel.content_margin_top = 10
	panel.content_margin_bottom = 10
	container.add_theme_stylebox_override("panel", panel)

	var vbox := VBoxContainer.new()
	container.add_child(vbox)
	vbox.add_theme_constant_override("separation", 6)

	# ─── Timer ───
	timer_label = Label.new()
	timer_label.text = "Time: 00:00"
	vbox.add_child(timer_label)

	# ─── Kills ───
	kill_label = Label.new()
	kill_label.text = "Kills: 0"
	vbox.add_child(kill_label)

	# ─── Health ───
	health_label = Label.new()
	vbox.add_child(health_label)

	health_bar = ProgressBar.new()
	health_bar.custom_minimum_size = Vector2(health_bar_width, health_bar_height)
	health_bar.show_percentage = false
	vbox.add_child(health_bar)

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.2, 0.2, 0.2)
	bg.set_corner_radius_all(4)
	health_bar.add_theme_stylebox_override("background", bg)

	var fill := StyleBoxFlat.new()
	fill.bg_color = Color.GREEN
	fill.set_corner_radius_all(4)
	health_bar.add_theme_stylebox_override("fill", fill)

	health_bar.max_value = player.max_health

func _process(_delta: float) -> void:
	_update_health()
	_update_kills()
	_update_timer()

# ─────────────────────────────
func _update_health() -> void:
	var hp: float = player.player_health
	health_bar.value = hp
	health_label.text = "Health: %d / %d" % [hp, health_bar.max_value]

	var percent: float = hp / health_bar.max_value
	var fill := health_bar.get_theme_stylebox("fill") as StyleBoxFlat

	if percent > 0.5:
		fill.bg_color = Color.GREEN
	elif percent > 0.25:
		fill.bg_color = Color.YELLOW
	else:
		fill.bg_color = Color.RED

# ─────────────────────────────
func _update_kills() -> void:
	kill_label.text = "Kills: %d" % game_manager.fish_killed

# ─────────────────────────────
func _update_timer() -> void:
	var elapsed: float

	if game_manager.game_end_time > 0:
		elapsed = game_manager.game_duration
	else:
		elapsed = Time.get_ticks_msec() / 1000.0 - game_manager.game_start_time

	var m := int(elapsed) / 60
	var s := int(elapsed) % 60
	timer_label.text = "Time: %02d:%02d" % [m, s]
