# pikpik.gd
# PikPik character - triggers dialogue and notifies intro system

extends Node2D

@export var dialogue_resource: DialogueResource
@export var dialogue_start: String = "start"


func action() -> void:
	# Notify the intro system that PikPik was found
	var intro = get_parent().get_node_or_null("PrologueIntro")
	if intro and intro.has_method("on_pikpik_found"):
		intro.on_pikpik_found()
	
	# Start the dialogue
	DialogueManager.show_dialogue_balloon(dialogue_resource, dialogue_start)
