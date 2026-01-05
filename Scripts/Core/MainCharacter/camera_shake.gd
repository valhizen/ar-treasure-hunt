extends Camera2D
class_name ShakeableCamera

## Simple camera shake - won't mess with camera position

@export var decay_rate: float = 5.0
@export var max_shake: Vector2 = Vector2(10, 8)

var trauma: float = 0.0
var noise: FastNoiseLite
var noise_y: int = 0


func _ready() -> void:
	add_to_group("camera")
	
	noise = FastNoiseLite.new()
	noise.seed = randi()
	noise.frequency = 2.0


func _process(delta: float) -> void:
	if trauma > 0:
		trauma = maxf(trauma - decay_rate * delta, 0)
		_apply_shake()
	else:
		# Reset offset when not shaking
		offset = Vector2.ZERO


func _apply_shake() -> void:
	var shake_amount = trauma * trauma
	noise_y += 1
	
	offset.x = max_shake.x * shake_amount * noise.get_noise_2d(noise.seed, noise_y)
	offset.y = max_shake.y * shake_amount * noise.get_noise_2d(noise.seed * 2, noise_y)


## Add trauma (0.0 to 1.0)
func add_trauma(amount: float) -> void:
	trauma = minf(trauma + amount, 1.0)


## Quick shake
func shake(intensity: float = 0.3) -> void:
	add_trauma(intensity)


## Light shake for hits
func hit_shake() -> void:
	add_trauma(0.2)


## Medium shake for damage
func damage_shake() -> void:
	add_trauma(0.4)


## Heavy shake for boss death
func boss_death_shake() -> void:
	add_trauma(0.8)
