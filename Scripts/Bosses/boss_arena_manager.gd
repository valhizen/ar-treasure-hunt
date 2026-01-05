extends Node2D
class_name BossArenaManager

## Manages boss fight flow, UI, and transitions

@export_category("Arena Setup")
@export var boss_node: BossBase
@export var player_node: MainCharacter
@export var boss_health_bar: BossHealthBar
@export var player_health_bar: PlayerHealthBar
@export var arena_camera: ShakeableCamera

@export_category("Boss Info")
@export var boss_display_name: String = "BOSS"
@export var boss_subtitle: String = "Guardian of the Arena"

@export_category("Arena Bounds")
@export var use_arena_bounds: bool = true
@export var arena_left_bound: float = -500.0
@export var arena_right_bound: float = 500.0

@export_category("Fight Settings")
@export var start_fight_on_ready: bool = false
@export var show_intro_animation: bool = true
@export var intro_delay: float = 1.5

# Internal state
var fight_started: bool = false
var fight_ended: bool = false
var player_won: bool = false

# Signals
signal fight_started_signal
signal fight_ended_signal(player_won: bool)
signal boss_phase_changed(phase: int)


func _ready() -> void:
	_setup_references()
	
	if start_fight_on_ready:
		call_deferred("start_boss_fight")


func _setup_references() -> void:
	# Auto-find nodes if not assigned
	if not boss_node:
		var bosses = get_tree().get_nodes_in_group("boss")
		if bosses.size() > 0:
			boss_node = bosses[0]
	
	if not player_node:
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player_node = players[0]
	
	if not arena_camera:
		var cams = get_tree().get_nodes_in_group("camera")
		for cam in cams:
			if cam is ShakeableCamera:
				arena_camera = cam
				break
	
	# Connect signals
	if boss_node:
		if boss_node.has_signal("boss_defeated"):
			boss_node.boss_defeated.connect(_on_boss_defeated)
		if boss_node.has_signal("health_changed"):
			boss_node.health_changed.connect(_on_boss_health_changed)
	
	if player_node:
		if player_node.has_signal("player_died"):
			player_node.player_died.connect(_on_player_died)


func _physics_process(_delta: float) -> void:
	if not fight_started or fight_ended:
		return
	
	# Enforce arena bounds
	if use_arena_bounds and player_node:
		player_node.global_position.x = clampf(
			player_node.global_position.x,
			arena_left_bound,
			arena_right_bound
		)
	
	if use_arena_bounds and boss_node:
		boss_node.global_position.x = clampf(
			boss_node.global_position.x,
			arena_left_bound,
			arena_right_bound
		)


# === PUBLIC API ===

func start_boss_fight() -> void:
	if fight_started:
		return
	
	print("[BossArena] Starting boss fight!")
	
	if show_intro_animation:
		await _play_intro()
	
	fight_started = true
	fight_started_signal.emit()
	
	# Setup and show health bars
	_setup_health_bars()
	
	# Activate boss AI
	if boss_node:
		boss_node.set_aggro(player_node)


func _play_intro() -> void:
	# Disable player input during intro
	if player_node:
		player_node.set_physics_process(false)
	
	# Camera focus on boss
	if arena_camera and boss_node:
		var original_pos = arena_camera.global_position
		
		# Pan to boss
		var tween = create_tween()
		tween.tween_property(arena_camera, "global_position", boss_node.global_position + Vector2(0, -50), 0.8)
		await tween.finished
		
		await get_tree().create_timer(intro_delay).timeout
		
		# Pan back to player
		if player_node:
			tween = create_tween()
			tween.tween_property(arena_camera, "global_position", player_node.global_position, 0.6)
			await tween.finished
	else:
		await get_tree().create_timer(intro_delay).timeout
	
	# Re-enable player
	if player_node:
		player_node.set_physics_process(true)


func _setup_health_bars() -> void:
	# Boss health bar
	if boss_health_bar and boss_node:
		boss_health_bar.boss_name = boss_display_name
		boss_health_bar.boss_subtitle = boss_subtitle
		boss_health_bar.setup_boss(boss_node)
		boss_health_bar.show_bar()
	
	# Player health bar
	if player_health_bar and player_node:
		player_health_bar.setup_player(player_node)
		player_health_bar.show_bar()


func end_boss_fight(did_player_win: bool) -> void:
	if fight_ended:
		return
	
	fight_ended = true
	player_won = did_player_win
	
	print("[BossArena] Fight ended! Player won: ", did_player_win)
	
	# Hide player health bar
	if player_health_bar:
		await get_tree().create_timer(1.0).timeout
		player_health_bar.hide_bar()
	
	fight_ended_signal.emit(did_player_win)


# === EVENT HANDLERS ===

func _on_boss_defeated() -> void:
	print("[BossArena] Boss defeated!")
	
	# Camera shake for dramatic effect
	if arena_camera:
		arena_camera.boss_death_shake()
	
	end_boss_fight(true)


func _on_player_died() -> void:
	print("[BossArena] Player died!")
	end_boss_fight(false)


func _on_boss_health_changed(current: float, maximum: float) -> void:
	# Check for phase transitions based on health thresholds
	var health_percent = current / maximum
	
	if health_percent <= 0.25:
		boss_phase_changed.emit(3)  # Phase 3: Desperate
	elif health_percent <= 0.5:
		boss_phase_changed.emit(2)  # Phase 2: Enraged
	elif health_percent <= 0.75:
		boss_phase_changed.emit(1)  # Phase 1: Normal


# === UTILITY ===

func reset_arena() -> void:
	fight_started = false
	fight_ended = false
	player_won = false
	
	if boss_health_bar:
		boss_health_bar.hide_bar()
	if player_health_bar:
		player_health_bar.hide_bar()


func spawn_boss(boss_scene: PackedScene, spawn_position: Vector2) -> BossBase:
	var new_boss = boss_scene.instantiate()
	new_boss.global_position = spawn_position
	add_child(new_boss)
	boss_node = new_boss
	
	# Reconnect signals
	if boss_node.has_signal("boss_defeated"):
		boss_node.boss_defeated.connect(_on_boss_defeated)
	if boss_node.has_signal("health_changed"):
		boss_node.health_changed.connect(_on_boss_health_changed)
	
	return new_boss
