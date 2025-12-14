extends Resource
class_name GameSaveData

@export var save_version: int = 1
@export var save_timestamp: String
@export var current_map: String = ""
@export var play_time_seconds: float = 0.0

@export var kathmandu_data: MapData
@export var patan_data: MapData
@export var bhaktapur_data: MapData

@export var minigame_data: Dictionary = {}
