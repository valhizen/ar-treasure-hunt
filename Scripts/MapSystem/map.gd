extends CanvasLayer

@onready var bigmap_container: Control = $BigMapContainer
@onready var bigmap_texture: TextureRect = $BigMapContainer/TextureRect

var is_bigmap_open: bool = false

func _ready() -> void:
	# IMPORTANT: Allow this node to process even when paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Setup big map container (fullscreen, hidden by default)
	bigmap_container.anchor_right = 1.0
	bigmap_container.anchor_bottom = 1.0
	bigmap_container.offset_left = 0
	bigmap_container.offset_top = 0
	bigmap_container.offset_right = 0
	bigmap_container.offset_bottom = 0
	bigmap_container.visible = false
	
	# Setup the texture to show the map image (centered)
	bigmap_texture.anchor_left = 0.5
	bigmap_texture.anchor_top = 0.5
	bigmap_texture.anchor_right = 0.5
	bigmap_texture.anchor_bottom = 0.5
	bigmap_texture.offset_left = -400  # Half of your desired width
	bigmap_texture.offset_top = -300   # Half of your desired height
	bigmap_texture.offset_right = 400  # Half of your desired width
	bigmap_texture.offset_bottom = 300 # Half of your desired height
	bigmap_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bigmap_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bigmap_texture.texture = preload("res://Map/bhaktapur_map.jpg")

func _input(event: InputEvent) -> void:
	# Same key toggles on and off
	if event.is_action_pressed("toggle_map"):
		toggle_bigmap()

func toggle_bigmap() -> void:
	if is_bigmap_open:
		close_bigmap()
	else:
		open_bigmap()

func open_bigmap() -> void:
	is_bigmap_open = true
	bigmap_container.visible = true
	get_tree().paused = true

func close_bigmap() -> void:
	is_bigmap_open = false
	bigmap_container.visible = false
	get_tree().paused = false
