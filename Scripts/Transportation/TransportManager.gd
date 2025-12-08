# transport_manager.gd
# This should be set as an Autoload in Project Settings
extends Node

var spawn_position: Vector2 = Vector2.ZERO
var should_spawn_at_position: bool = false

func set_spawn_position(pos: Vector2):
	spawn_position = pos
	should_spawn_at_position = true

func get_spawn_position() -> Vector2:
	return spawn_position

func has_spawn_position() -> bool:
	return should_spawn_at_position

func clear_spawn_position():
	should_spawn_at_position = false
	spawn_position = Vector2.ZERO
