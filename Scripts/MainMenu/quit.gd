extends Button

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var audio_stream_player: AudioStreamPlayer = $AudioStreamPlayer

func _on_focus_entered() -> void:
	animation_player.play("hover")

func _on_focus_exited() -> void:
	animation_player.play("normal")
	
func _on_mouse_entered() -> void:
	if not has_focus():
		animation_player.play("hover")

func _on_mouse_exited() -> void:
	# Don't change if button has focus (keyboard)
	if not has_focus():
		animation_player.play("normal")


func _on_pressed() -> void:
	animation_player.play("click")
	await animation_player.animation_finished
	audio_stream_player.play()
	get_tree().quit() 
