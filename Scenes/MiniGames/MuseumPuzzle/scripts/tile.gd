extends TextureRect

signal tile_pressed(tile_node)

var correct_index: int = 0
var current_index: int = 0

# CHANGE 1: Use the built-in virtual function name (_gui_input instead of _on_gui_input)
# This ensures it runs automatically without needing to connect signals in the editor.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event() # Good practice to consume the event
		tile_pressed.emit(self)

func update_visual_position(target_pos: Vector2, animate: bool = true):
	if animate:
		var tween = create_tween()
		tween.tween_property(self, "position", target_pos, 0.2).set_trans(Tween.TRANS_SINE)
	else:
		position = target_pos
