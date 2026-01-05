@tool
extends Resource
class_name Quest
## Quest - Data container for a single quest

## Unique identifier for this quest
@export var id: String = ""

## Display name shown in UI
@export var title: String = "New Quest"

## Optional description (for quest log, not shown in HUD)
@export_multiline var description: String = ""

## Which scene/map this quest belongs to (empty = global)
@export var scene_id: String = ""

## Quest objectives - sub-tasks within this quest
@export var objectives: Array[String] = []

## Is this quest currently active?
@export var is_active: bool = false

## Is this quest completed?
@export var is_completed: bool = false

## Track which objectives are done (by index)
var completed_objectives: Array[bool] = []

## Icon to show (optional)
@export var icon: Texture2D = null

## Priority for sorting (higher = shown first)
@export var priority: int = 0


func _init(p_id: String = "", p_title: String = "", p_scene: String = "") -> void:
	id = p_id
	title = p_title
	scene_id = p_scene
	_init_objectives()


func _init_objectives() -> void:
	completed_objectives.clear()
	for i in range(objectives.size()):
		completed_objectives.append(false)


## Activate this quest
func activate() -> void:
	is_active = true
	is_completed = false
	_init_objectives()


## Complete a specific objective by index
func complete_objective(index: int) -> bool:
	if index < 0 or index >= objectives.size():
		return false
	
	completed_objectives[index] = true
	
	# Check if all objectives are done
	var all_done = true
	for done in completed_objectives:
		if not done:
			all_done = false
			break
	
	if all_done:
		complete()
	
	return all_done


## Complete the entire quest
func complete() -> void:
	is_completed = true
	is_active = false


## Reset quest to initial state
func reset() -> void:
	is_active = false
	is_completed = false
	_init_objectives()


## Get progress as percentage (0.0 to 1.0)
func get_progress() -> float:
	if objectives.is_empty():
		return 1.0 if is_completed else 0.0
	
	var done_count = 0
	for done in completed_objectives:
		if done:
			done_count += 1
	
	return float(done_count) / float(objectives.size())


## Serialize for saving
func to_dict() -> Dictionary:
	return {
		"id": id,
		"is_active": is_active,
		"is_completed": is_completed,
		"completed_objectives": completed_objectives
	}


## Load from save data
func from_dict(data: Dictionary) -> void:
	is_active = data.get("is_active", false)
	is_completed = data.get("is_completed", false)
	var saved_objectives = data.get("completed_objectives", [])
	for i in range(mini(saved_objectives.size(), completed_objectives.size())):
		completed_objectives[i] = saved_objectives[i]
