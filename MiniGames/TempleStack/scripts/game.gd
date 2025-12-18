extends Node2D

@export var block: PackedScene
signal drop

var score: int = 0
const CENTER_X := 254.0      # ideal center x (same as spawn x)
const MAX_DISTANCE := 200.0  # how far away before score goes to 0
var array = [Vector2(500, -94), Vector2(23, -94), Vector2(500, -130), Vector2(23, -130) ]

func _ready() -> void:
	spawn_block()


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("Jump"):
		# tell current block to fall
		drop.emit()  
	
func _on_block_spawn():
	spawn_block()

func spawn_block() -> void:
	var new_instance = block.instantiate()
	new_instance.position = array.pick_random() 
	add_child(new_instance)

	# connect global drop signal to this block's drop handler
	drop.connect(new_instance._on_game_drop)

	# connect this block's landed signal to our scoring function
	new_instance.landed.connect(_on_block_landed)
	new_instance.spawn.connect(_on_block_spawn)


func _on_block_landed(final_position: Vector2) -> void:
	# How far horizontally from the ideal temple center?
	if final_position.y > -92:
		var dx: float = abs(final_position.x - CENTER_X)

	# Alignment score: 100 if perfectly centered, 0 if far away
		var ratio: float = clamp(1.0 - (dx / MAX_DISTANCE), 0.0, 1.0)
		var align_score: int = int(round(ratio * 100.0))

		score += align_score

		print("Block landed at x=", final_position.x, " → +", align_score, " points. Total score: ", score)
	else:
		print('gameover')
		get_tree().reload_current_scene()                 
	# If you have a label in the scene (e.g. $ScoreLabel), you can also do:
	# $ScoreLabel.text = "Score: %d" % score
  
