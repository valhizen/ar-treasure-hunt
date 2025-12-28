extends Area2D

func _ready() -> void:
	connect("body_entered", Callable(self, "_on_body_entered"))
	connect("body_exited", Callable(self, "_on_body_exited"))

func _on_body_entered(body):
	if body.name == "MainCharacter":
		body.just_entered_wall = true

func _on_body_exited(body):
	if body.name == "MainCharacter":
		body.just_exited_wall = true
