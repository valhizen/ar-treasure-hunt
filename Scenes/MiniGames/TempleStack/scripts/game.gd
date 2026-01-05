extends MinigameBase
## TempleStack - Temple block stacking minigame
## Stack blocks with precision for points

#region Custom Configuration
@export_group("Block Settings")
@export var blocks: Array[PackedScene]

@export_group("Scoring")
@export var center_x := 254.0
@export var max_distance := 200.0
@export var perfect_threshold := 10.0
@export var perfect_bonus := 50
#endregion

#region Signals
signal drop
#endregion

#region Game State
var block_index := 0
var current_top_y := -94.0
var blocks_placed := 0
var perfect_placements := 0
var spawn_positions := [Vector2(500, -94), Vector2(23, -94), Vector2(500, -130), Vector2(23, -130)]

const BLOCK_HEIGHT := 100.0
#endregion


#region MinigameBase Overrides
func _setup_game() -> void:
	"""Initialize temple stacking"""
	print("[TempleStack] Setting up...")
	
	block_index = 0
	current_top_y = -94.0
	blocks_placed = 0
	perfect_placements = 0
	current_score = 0
	
	# Reset spawn positions
	spawn_positions = [Vector2(500, -94), Vector2(23, -94), Vector2(500, -130), Vector2(23, -130)]
	
	# Clear any existing blocks
	for child in get_children():
		if child.is_in_group("block"):
			child.queue_free()


func _start_game() -> void:
	"""Start the game - spawn first block"""
	print("[TempleStack] Game started!")
	spawn_block()


func _update_game(_delta: float) -> void:
	"""Check for drop input"""
	if Input.is_action_just_pressed("Jump") or Input.is_action_just_pressed("interact"):
		drop.emit()


func _on_time_up() -> void:
	"""Time ran out"""
	complete_game()


func _cleanup_game() -> void:
	"""Remove all blocks"""
	for child in get_children():
		if child.is_in_group("block"):
			child.queue_free()


func _calculate_final_score() -> int:
	"""Calculate final score with bonuses"""
	var base = current_score
	var perfect_total = perfect_placements * perfect_bonus
	var completion_bonus = 200 if block_index >= blocks.size() else 0
	var height_bonus = blocks_placed * 25
	
	game_data["blocks_placed"] = blocks_placed
	game_data["perfect_placements"] = perfect_placements
	game_data["tower_height"] = abs(current_top_y)
	game_data["completion_bonus"] = completion_bonus
	
	return base + perfect_total + completion_bonus + height_bonus


func _calculate_rewards(score: int, stars: int) -> Dictionary:
	var rewards = {
		"currency": 10 + (stars * 15) + (perfect_placements * 5),
		"items": []
	}
	
	if block_index >= blocks.size() and stars >= 2:
		rewards["items"].append({
			"id": "temple_master_badge",
			"amount": 1,
			"special": true
		})
	
	return rewards
#endregion


#region Block Management
func spawn_block() -> void:
	"""Spawn the next block"""
	if not is_playing():
		return
	
	if block_index >= blocks.size():
		print("[TempleStack] All blocks placed!")
		complete_game()
		return
	
	var block_scene: PackedScene = blocks[block_index]
	block_index += 1
	
	var new_block = block_scene.instantiate()
	new_block.position = spawn_positions.pick_random()
	new_block.add_to_group("block")
	add_child(new_block)
	
	# Connect signals
	drop.connect(new_block._on_game_drop)
	new_block.landed.connect(_on_block_landed)
	new_block.spawn.connect(_on_block_spawn)


func _on_block_spawn() -> void:
	"""Called when block signals to spawn next"""
	spawn_block()


func _on_block_landed(final_position: Vector2) -> void:
	"""Calculate score when block lands"""
	if not is_playing():
		return
	
	blocks_placed += 1
	
	# Calculate alignment score
	var dx: float = abs(final_position.x - center_x)
	var ratio: float = clamp(1.0 - (dx / max_distance), 0.0, 1.0)
	var align_score: int = int(round(ratio * 100.0))
	
	# Perfect placement bonus
	if dx <= perfect_threshold:
		perfect_placements += 1
		align_score += perfect_bonus
		print("[TempleStack] PERFECT!")
	
	add_score(align_score)
	
	# Update spawn positions
	current_top_y = min(current_top_y, final_position.y)
	var next_y := current_top_y - BLOCK_HEIGHT
	
	spawn_positions.clear()
	spawn_positions.append(Vector2(500, next_y))
	spawn_positions.append(Vector2(23, next_y))
	
	print("[TempleStack] +%d pts (Total: %d)" % [align_score, current_score])
#endregion
