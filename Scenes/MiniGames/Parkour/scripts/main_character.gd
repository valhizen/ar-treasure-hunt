extends CharacterBody2D

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var actionable_finder: Area2D = $Direction/ActionableFinder
@onready var main_character: CharacterBody2D = $"."
@onready var enemies: Node2D = $"../Enemies"
@onready var checkpoint: Area2D = $"../Checkpoint"
@onready var coins: Label = $Coins
@onready var message: Label = $"../message"
@onready var message_2: Label = $"../message2"
@onready var respawn_label: Label = $Respawn
@onready var death: AudioStreamPlayer = $"../Music/death"
@onready var coin: AudioStreamPlayer = $"../Music/coin"

# Player controls
@export var player_land_speed: float = 150
var player_speed = player_land_speed

@export var just_entered_wall: bool = false
@export var just_exited_wall: bool = false
@export var in_wall: bool = false

# Platformer Movement Controls
@export var max_velocity_air: float = 300
@export var land_gravity: float = 600
@export var airtime_rate: float = 10
@export var airtime_threshold: float = 0.5
@export var player_land_jump: float = 300

var airtime: float = 0
var gravity: float = land_gravity
var max_velocity: float = max_velocity_air
var jump_force: float = player_land_jump
var hitbox: Area2D = null
var checkpoint_position: Vector2
var is_jumping: bool = false

# ═══════════════════════════════════════════════════════════════
# SCORE SYSTEM
# ═══════════════════════════════════════════════════════════════
var coins_collected: int = 0
var death_count: int = 0
var time_elapsed: float = 0.0
var level_started: bool = false
var level_completed: bool = false

@export_group("Score Settings")
@export var level_id: String = "platformer_level_1"
@export var coin_score_value: int = 100
@export var death_penalty: int = 50
@export var time_bonus_max: float = 120.0
@export var time_bonus_points: int = 1000


func _ready() -> void:
	add_to_group("player")
	
	animated_sprite.play("idle_down")
	checkpoint_position = main_character.global_position
	
	# Start level timer
	level_started = true
	time_elapsed = 0.0
	death_count = 0
	coins_collected = 0
	_update_coins_display()
	
	# Connect to portal
	call_deferred("_connect_to_portal")


func _connect_to_portal() -> void:
	"""Find and connect to exit portal"""
	await get_tree().process_frame
	
	# Find portal - check Area2D nodes
	var portal: Area2D = null
	
	# Method 1: Check group
	var portals = get_tree().get_nodes_in_group("exit_portal")
	if portals.size() > 0:
		portal = portals[0]
	
	# Method 2: Find by name pattern
	if portal == null:
		portal = _find_portal_in_tree(get_tree().current_scene)
	
	if portal:
		print("[Player] ✓ Found portal: %s" % portal.get_path())
		
		# Connect to body_entered signal directly (most reliable)
		if not portal.body_entered.is_connected(_on_portal_body_entered):
			portal.body_entered.connect(_on_portal_body_entered)
			print("[Player] ✓ Connected to portal.body_entered")
		
		# Also connect to custom signals if they exist
		if portal.has_signal("player_entered_portal"):
			if not portal.player_entered_portal.is_connected(_on_entered_portal):
				portal.player_entered_portal.connect(_on_entered_portal)
	else:
		push_warning("[Player] ✗ No portal found in scene!")


func _find_portal_in_tree(node: Node) -> Area2D:
	"""Recursively find portal Area2D"""
	if node == null:
		return null
	
	# Check if this is a portal Area2D
	if node is Area2D:
		if "portal" in node.name.to_lower() or "exit" in node.name.to_lower():
			return node
		if node.get_script() and "MinigameExitPortal" in str(node.get_script()):
			return node
	
	# Check children
	for child in node.get_children():
		var found = _find_portal_in_tree(child)
		if found:
			return found
	
	return null


func _on_portal_body_entered(body: Node2D) -> void:
	"""Called when ANY body enters portal - check if it's us"""
	if body == self:
		print("[Player] Portal body_entered triggered!")
		_submit_score()


func _on_entered_portal() -> void:
	"""Called from MinigameExitPortal signal"""
	print("[Player] player_entered_portal signal received!")
	_submit_score()


func _process(delta: float) -> void:
	if level_started and not level_completed:
		time_elapsed += delta


func _physics_process(delta: float) -> void:
	_update_animation()
	_platformer_physics(delta)


func _update_animation():
	if is_on_wall() and not is_on_floor():
		if animated_sprite.animation != "hanging":
			animated_sprite.play("hanging")
		return

	if velocity.x != 0:
		if velocity.x < 0:
			if animated_sprite.animation != "run_left":
				animated_sprite.play("run_left")
		else:
			if animated_sprite.animation != "run_right":
				animated_sprite.play("run_right")
		return

	if animated_sprite.animation != "idle_down":
		animated_sprite.play("idle_down")


func _platformer_physics(delta: float) -> void:
	if just_entered_wall:
		in_wall = true
		just_entered_wall = false

	if just_exited_wall:
		in_wall = false
		just_exited_wall = false

	_player_switch_settings()

	if not is_on_floor():
		if in_wall:
			if is_on_wall():
				velocity.y = gravity * delta * 0.5
				if Input.is_action_pressed("Left"):
					if Input.is_action_just_pressed("Jump"):
						velocity.x = -player_speed
						velocity.y = -300
				elif Input.is_action_pressed("Right"):
					if Input.is_action_just_pressed("Jump"):
						velocity.x = player_speed
						velocity.y = -300
		velocity.y += gravity * delta
		if absf(velocity.y) >= max_velocity:
			velocity.y = max_velocity
		airtime += airtime_rate * delta
	else:
		airtime = 0
	
	if not is_on_wall():
		if Input.is_action_pressed("Left"):
			animated_sprite.play("run_left")
			velocity.x = -player_speed
		elif Input.is_action_pressed("Right"):
			animated_sprite.play("run_right")
			velocity.x = player_speed
		else:
			velocity.x = 0
	
	if Input.is_action_just_pressed("Jump"):
		if airtime < airtime_threshold:
			velocity.y = -jump_force
	
	move_and_slide()


func _player_switch_settings():
	gravity = land_gravity
	max_velocity = max_velocity_air
	player_speed = player_land_speed
	jump_force = player_land_jump


func wait_seconds(seconds: float) -> void:
	var timer := get_tree().create_timer(seconds, true)
	await timer.timeout


func respawn_countdown() -> void:
	respawn_label.visible = true
	for i in range(4, 0, -1):
		if i == 4:
			respawn_label.text = "You Died!"
			blink(20, 0.12) 
			await wait_seconds(1.0)
		else:
			respawn_label.text = "Respawning in .." + str(i)
			await wait_seconds(1.0)
	
	respawn_label.visible = false


func striked():
	await die()
	main_character.global_position = checkpoint_position
	
	message.text = "You're back \n There's nothing hehe"
	message_2.text = "Sorry, Not Sorry"

	enemies.queue_free()


func save_checkpoint(position: Vector2):
	checkpoint_position = position


func add_coin():
	coin.play()
	coins_collected += 1
	_update_coins_display()


func _update_coins_display():
	coins.text = "Coins: " + str(coins_collected)


func blink(times, interval) -> void:
	animated_sprite.process_mode = Node.PROCESS_MODE_ALWAYS
	animated_sprite.play("idle_down")
	for i in times:
		animated_sprite.visible = false
		await get_tree().create_timer(interval, true).timeout
		animated_sprite.visible = true
		await get_tree().create_timer(interval, true).timeout

	animated_sprite.process_mode = Node.PROCESS_MODE_INHERIT


func die():
	death_count += 1
	print("Deaths: ", death_count)
	
	get_tree().paused = true
	death.play()
	await respawn_countdown()
	await wait_seconds(0.0)
	main_character.global_position = checkpoint_position
	get_tree().paused = false


# ═══════════════════════════════════════════════════════════════
# SCORE SUBMISSION
# ═══════════════════════════════════════════════════════════════

func _submit_score() -> void:
	"""Submit score to ScoreManager"""
	if level_completed:
		print("[Player] Score already submitted, skipping...")
		return
	
	level_completed = true
	var final_score = _calculate_score()
	
	print("═══════════════════════════════════════")
	print("[Platformer] SUBMITTING SCORE...")
	print("  Level: %s" % level_id)
	print("  Coins: %d" % coins_collected)
	print("  Deaths: %d" % death_count)
	print("  Time: %.1fs" % time_elapsed)
	print("  Final Score: %d" % final_score)
	print("═══════════════════════════════════════")
	
	# Submit to ScoreManager (like TempleStack does via MinigameBase)
	var result = await ScoreManager.submit_score(level_id, final_score, {
		"coins_collected": coins_collected,
		"death_count": death_count,
		"time_taken": time_elapsed,
		"success": true
	})
	
	if result.success:
		print("[Platformer] ✓ Score submitted successfully!")
	else:
		print("[Platformer] ✗ Score submission failed: %s" % result.get("error", "Unknown"))


func _calculate_score() -> int:
	# Coin points
	var coin_score = coins_collected * coin_score_value
	
	# Time bonus (faster = more points)
	var time_bonus = 0
	if time_elapsed < time_bonus_max:
		var time_ratio = 1.0 - (time_elapsed / time_bonus_max)
		time_bonus = int(time_ratio * time_bonus_points)
	
	# Death penalty
	var penalty = death_count * death_penalty
	
	return max(0, coin_score + time_bonus - penalty)


# ═══════════════════════════════════════════════════════════════
# PUBLIC METHODS
# ═══════════════════════════════════════════════════════════════

func get_current_score() -> int:
	return _calculate_score()

func get_time_elapsed() -> float:
	return time_elapsed

func get_death_count() -> int:
	return death_count

func get_coins() -> int:
	return coins_collected
