extends CanvasLayer

# Minimap (always visible, follows player)
@onready var minimap_container: SubViewportContainer = $MinimapContainer
@onready var minimap_viewport: SubViewport = $MinimapContainer/SubViewport
@onready var minimap_camera: Camera2D = $MinimapContainer/SubViewport/Camera2D

# Big map container
@onready var bigmap_container: Control = $BigMapContainer
@onready var bigmap_texture: TextureRect = $BigMapContainer/TextureRect

@onready var player = get_tree().get_first_node_in_group("player")

# Dictionary to store all your big maps
var big_maps: Dictionary = {
	"bhaktapur": preload("res://path/to/bhaktapur_map.png"),
	"kathmandu": preload("res://path/to/kathmandu_map.png"),
	"patan": preload("res://path/to/patan_map.png"),
	# Add more maps here
}

var current_area: String = "bhaktapur"
var is_bigmap_open: bool = false

func _ready() -> void:
	# Setup minimap
	minimap_viewport.world_2d = get_tree().root.world_2d
	minimap_container.anchor_right = 0.0
	minimap_container.anchor_bottom = 0.0
	minimap_container.offset_left = 10
	minimap_container.offset_top = 10
	minimap_container.offset_right = 210
	minimap_container.offset_bottom = 210
	minimap_camera.zoom = Vector2(0.3, 0.3)
	
	# Setup big map container (fullscreen, hidden by default)
	bigmap_container.anchor_right = 1.0
	bigmap_container.anchor_bottom = 1.0
	bigmap_container.visible = false
	
	# Setup the texture rect to show the map image
	bigmap_texture.anchor_right = 1.0
	bigmap_texture.anchor_bottom = 1.0
	bigmap_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bigmap_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

func _physics_process(delta: float) -> void:
	# Minimap always follows player
	if player:
		minimap_camera.position = player.position

func _input(event: InputEvent) -> void:
	# Toggle big map with M key
	if event.is_action_pressed("ui_map_toggle"):
		toggle_bigmap()
	
	# Close big map with ESC
	if event.is_action_pressed("ui_cancel") and is_bigmap_open:
		close_bigmap()

func toggle_bigmap() -> void:
	if is_bigmap_open:
		close_bigmap()
	else:
		open_bigmap()

func open_bigmap() -> void:
	is_bigmap_open = true
	bigmap_container.visible = true
	
	# Load the appropriate map for current area
	if big_maps.has(current_area):
		bigmap_texture.texture = big_maps[current_area]
	
	# Optional: pause game when map is open
	get_tree().paused = true

func close_bigmap() -> void:
	is_bigmap_open = false
	bigmap_container.visible = false
	get_tree().paused = false

# Call this function when player enters a new area
func set_current_area(area_name: String) -> void:
	if big_maps.has(area_name):
		current_area = area_name

# Example: You can also open a specific map directly
func open_specific_map(map_name: String) -> void:
	if big_maps.has(map_name):
		current_area = map_name
		open_bigmap()
