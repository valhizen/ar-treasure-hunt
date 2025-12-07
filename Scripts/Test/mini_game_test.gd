extends Node2D

@export var building_id : String = "building_temple"
@export_file("*.tscn") var minigame_scene_path: String = "res://scenes/minigames/repair_minigame.tscn"
var is_rebuilt : bool = false

@onready var rebuild_sprite: Sprite2D = $YSortEnabled/rebuildSprite
@onready var broken_sprite: Sprite2D = $InteractionArea/brokenSprite
@onready var interaction_area: Area2D = $InteractionArea

func _ready() -> void:
	set_rebuilt_status()
	

func set_broken_status():
	broken_sprite.visible = true
	rebuild_sprite.visible = false
	is_rebuilt = false;
	print("The Building is Broken")
	
	
func set_rebuilt_status():
	broken_sprite.visible = false
	rebuild_sprite.visible = true
	is_rebuilt = true
	print("The Building is Rebuild")
	
	
