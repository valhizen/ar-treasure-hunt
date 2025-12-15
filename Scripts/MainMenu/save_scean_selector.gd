# SaveSlotSelector.gd
extends Control

signal slot_selected(slot: int)
signal cancelled

@onready var slot_container = $MarginContainer/HBoxContainer/VBoxContainer
@onready var back_button = $BackButton  # Fixed this line
@onready var title_label = $MarginContainer/TitleLabel  # Adjust path if needed

var slot_button_scene = preload("res://Sceans/MainMenu/save_slot_button.tscn")
var mode: String = "load"  # "load", "save", or "new_game"

func _ready():
	back_button.pressed.connect(_on_back_pressed)
	_populate_slots()

func setup(mode_type: String, title: String = ""):
	mode = mode_type
	if title != "":
		title_label.text = title

func _populate_slots():
	# Clear existing buttons
	for child in slot_container.get_children():
		child.queue_free()
	
	var saves = SaveManager.get_all_saves()
	
	for save_info in saves:
		var slot_button = slot_button_scene.instantiate()
		slot_container.add_child(slot_button)
		slot_button.setup(save_info, mode)
		slot_button.slot_pressed.connect(_on_slot_pressed)
		slot_button.slot_deleted.connect(_on_slot_deleted)

func _on_slot_pressed(slot: int):
	emit_signal("slot_selected", slot)

func _on_slot_deleted(slot: int):
	SaveManager.delete_save(slot)
	_populate_slots()  # Refresh the list

func _on_back_pressed():
	emit_signal("cancelled")
	queue_free()
