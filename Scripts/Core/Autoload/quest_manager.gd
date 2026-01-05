extends Node
## QuestManager - Global quest tracking system
## AutoLoad Singleton: Manages all quests, tracks progress, emits signals

#region Signals
signal quest_added(quest: Quest)
signal quest_activated(quest: Quest)
signal quest_completed(quest: Quest)
signal quest_failed(quest: Quest)
signal objective_completed(quest: Quest, objective_index: int)
signal quests_updated
#endregion

## All registered quests (id -> Quest)
var quests: Dictionary = {}

## Currently active quests
var active_quests: Array[Quest] = []

## Current scene ID for filtering
var current_scene: String = ""


func _ready() -> void:
	print("[QuestManager] Initialized")


#region Quest Registration
## Register a quest (from resource or create new)
func register_quest(quest: Quest) -> void:
	if quest.id.is_empty():
		push_error("[QuestManager] Quest has no ID!")
		return
	
	quests[quest.id] = quest
	print("[QuestManager] Registered quest: %s" % quest.id)
	quest_added.emit(quest)


## Create and register a simple quest
func create_quest(id: String, title: String, scene: String = "") -> Quest:
	var quest = Quest.new(id, title, scene)
	register_quest(quest)
	return quest


## Create quest with objectives
func create_quest_with_objectives(id: String, title: String, objectives: Array[String], scene: String = "") -> Quest:
	var quest = Quest.new(id, title, scene)
	quest.objectives = objectives
	quest._init_objectives()
	register_quest(quest)
	return quest
#endregion


#region Quest Activation
## Activate a quest by ID
func activate_quest(quest_id: String) -> bool:
	var quest = quests.get(quest_id)
	if not quest:
		push_warning("[QuestManager] Quest not found: %s" % quest_id)
		return false
	
	if quest.is_active:
		return true  # Already active
	
	quest.activate()
	
	if quest not in active_quests:
		active_quests.append(quest)
		_sort_active_quests()
	
	print("[QuestManager] Activated quest: %s" % quest_id)
	quest_activated.emit(quest)
	quests_updated.emit()
	return true


## Deactivate a quest (without completing)
func deactivate_quest(quest_id: String) -> void:
	var quest = quests.get(quest_id)
	if quest:
		quest.is_active = false
		active_quests.erase(quest)
		quests_updated.emit()
#endregion


#region Quest Completion
## Complete a quest by ID
func complete_quest(quest_id: String) -> bool:
	var quest = quests.get(quest_id)
	if not quest:
		push_warning("[QuestManager] Quest not found: %s" % quest_id)
		return false
	
	quest.complete()
	
	print("[QuestManager] Completed quest: %s" % quest_id)
	quest_completed.emit(quest)
	
	# Remove from active after short delay (for animation)
	_delayed_remove_from_active(quest)
	
	return true


## Complete a specific objective
func complete_objective(quest_id: String, objective_index: int) -> bool:
	var quest = quests.get(quest_id)
	if not quest:
		return false
	
	var all_done = quest.complete_objective(objective_index)
	
	print("[QuestManager] Completed objective %d in quest: %s" % [objective_index, quest_id])
	objective_completed.emit(quest, objective_index)
	quests_updated.emit()
	
	if all_done:
		quest_completed.emit(quest)
		_delayed_remove_from_active(quest)
	
	return all_done


## Helper: Remove quest from active list after delay
func _delayed_remove_from_active(quest: Quest) -> void:
	await get_tree().create_timer(1.5).timeout  # Wait for completion animation
	active_quests.erase(quest)
	quests_updated.emit()
#endregion


#region Scene Management
## Set current scene and filter quests
func set_current_scene(scene_id: String) -> void:
	current_scene = scene_id
	print("[QuestManager] Scene set to: %s" % scene_id)
	quests_updated.emit()


## Get quests for current scene (active only)
func get_scene_quests() -> Array[Quest]:
	var result: Array[Quest] = []
	
	for quest in active_quests:
		# Include if: quest is for this scene OR quest is global (no scene specified)
		if quest.scene_id.is_empty() or quest.scene_id == current_scene:
			result.append(quest)
	
	return result


## Get all active quests
func get_active_quests() -> Array[Quest]:
	return active_quests.duplicate()
#endregion


#region Query Functions
## Check if a quest is active
func is_quest_active(quest_id: String) -> bool:
	var quest = quests.get(quest_id)
	return quest != null and quest.is_active


## Check if a quest is completed
func is_quest_completed(quest_id: String) -> bool:
	var quest = quests.get(quest_id)
	return quest != null and quest.is_completed


## Get a quest by ID
func get_quest(quest_id: String) -> Quest:
	return quests.get(quest_id)
#endregion


#region Sorting
func _sort_active_quests() -> void:
	active_quests.sort_custom(func(a, b): return a.priority > b.priority)
#endregion


#region Save/Load
func get_save_data() -> Dictionary:
	var data = {}
	for quest_id in quests:
		data[quest_id] = quests[quest_id].to_dict()
	return data


func load_save_data(data: Dictionary) -> void:
	for quest_id in data:
		if quests.has(quest_id):
			quests[quest_id].from_dict(data[quest_id])
			if quests[quest_id].is_active:
				if quests[quest_id] not in active_quests:
					active_quests.append(quests[quest_id])
	
	_sort_active_quests()
	quests_updated.emit()


## Reset all quests
func reset_all() -> void:
	for quest_id in quests:
		quests[quest_id].reset()
	active_quests.clear()
	quests_updated.emit()
#endregion
