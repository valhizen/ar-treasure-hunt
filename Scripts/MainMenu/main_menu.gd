extends Control

@onready var continue_button: Button = $Container/Continue

func _ready() -> void:
	continue_button.grab_focus()
