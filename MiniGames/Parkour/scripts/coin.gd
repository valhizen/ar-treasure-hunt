extends Area2D

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
		body.add_coin()
		queue_free()
