extends Node2D

@export var blocks: Array[PackedScene]
signal drop
@onready var score_label: Label = $ScoreLabel

var score: int = 0
const CENTER_X := 256.0
const MAX_DISTANCE := 200.0 
var array = [Vector2(500, -94), Vector2(23, -94), Vector2(500, -130), Vector2(23, -130) ]
var block_index = 0
var current_top_y := -94.0
const BLOCK_HEIGHT := 100.0 

func _ready() -> void:
	spawn_block()


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("Jump"):
		drop.emit()  
	
func _on_block_spawn():
	spawn_block()

func spawn_block() -> void:
	if block_index >= blocks.size():
		print('gameover')
	else:
		var block: PackedScene = blocks[block_index]
		block_index = (block_index + 1)
		var new_instance = block.instantiate()
		new_instance.position = array.pick_random() 
		add_child(new_instance)
		
		
		drop.connect(new_instance._on_game_drop)

		new_instance.landed.connect(_on_block_landed)
		new_instance.spawn.connect(_on_block_spawn)


func _on_block_landed(final_position: Vector2) -> void:
		var dx: float = abs(((final_position.x) * 1.1)- CENTER_X)

		var ratio: float = clamp(1.0-(dx / MAX_DISTANCE), 0.0, 1.0)
		var align_score: int = int(round(ratio * 100.0))
		

		score += align_score

		current_top_y = min(current_top_y, final_position.y)
		var next_y := current_top_y - BLOCK_HEIGHT
		
		array.clear()
		array.append(Vector2(500, next_y))
		array.append(Vector2(23, next_y))
		print("Block landed at x=", final_position.x, " → +", align_score, " points. Total score: ", score)
		score_label.text = "Score: %d" % score
  
