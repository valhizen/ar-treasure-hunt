extends TextureRect

@export 
var wait_time_normal: float = 1.5     # How long to stay Normal
@export 
var wait_time_destroyed: float = 1.0  # How long to stay Destroyed

var progress: float = 0.0
var direction: int = 1
var speed: float = 0.5
var pause_timer: float = 0.0
var paused: bool = false
var shader_material: ShaderMaterial

func _ready():
	shader_material = material as ShaderMaterial
	shader_material.set_shader_parameter("progress", 0.0)
	
	paused = true
	pause_timer = wait_time_normal

func _process(delta):
	if paused:
		pause_timer -= delta
		if pause_timer <= 0.0:
			paused = false
			if progress >= 1.0:
				direction = -1
			else:
				direction = 1
		return

	progress += delta * speed * direction

	if progress >= 1.0:
		progress = 1.0
		paused = true
		pause_timer = wait_time_destroyed
	elif progress <= 0.0:
		progress = 0.0
		paused = true
		pause_timer = wait_time_normal

	shader_material.set_shader_parameter("progress", progress)
