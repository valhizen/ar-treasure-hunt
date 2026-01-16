extends Node
# Add this as Autoload: Project Settings > Autoload > Add "ProgressTracker"

signal minigame_completed(minigame_name: String)
signal portal_unlocked(map_name: String)

var completed_minigames: Dictionary = {}  # { "patan": ["carving", "lake", "parkour"] }

func complete_minigame(minigame_name: String, map_name: String) -> void:
	if not completed_minigames.has(map_name):
		completed_minigames[map_name] = []
	
	if minigame_name not in completed_minigames[map_name]:
		completed_minigames[map_name].append(minigame_name)
		print("[ProgressTracker] ✅ Completed: %s on %s" % [minigame_name, map_name])
		print("[ProgressTracker] Total on %s: %d" % [map_name, completed_minigames[map_name].size()])
		minigame_completed.emit(minigame_name)


func get_count(map_name: String) -> int:
	if completed_minigames.has(map_name):
		return completed_minigames[map_name].size()
	return 0


func is_completed(minigame_name: String, map_name: String) -> bool:
	if completed_minigames.has(map_name):
		return minigame_name in completed_minigames[map_name]
	return false
