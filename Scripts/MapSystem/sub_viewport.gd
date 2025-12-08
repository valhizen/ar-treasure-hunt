extends SubViewport

@onready var camera_2d: Camera2D = $Camera2D
@onready var player = get_tree().get_first_node_in_group("player")

func _ready() -> void:
	world_2d = get_tree().root.world_2d
	
	size = Vector2i(128, 128)
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR
	camera_2d.zoom = Vector2(0.5, 0.5)

	var bright_layer = CanvasLayer.new()
	bright_layer.layer = 100  # High layer to render on top
	add_child(bright_layer)
	
	var bright_modulate = CanvasModulate.new()
	bright_modulate.color = Color(1.0, 1.0, 1.0)  # Full brightness (white)
	bright_layer.add_child(bright_modulate)

func _physics_process(delta: float) -> void:
	if player:
		camera_2d.global_position = player.global_position
