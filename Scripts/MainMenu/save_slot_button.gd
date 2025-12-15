# SaveSlotButton.gd
extends PanelContainer

signal slot_pressed(slot: int)
signal slot_deleted(slot: int)

@onready var slot_label = $MarginContainer/HBoxContainer/VBoxContainer/SlotLabel
@onready var timestamp_label = $MarginContainer/HBoxContainer/VBoxContainer/TimestampLabel
@onready var info_label = $MarginContainer/HBoxContainer/VBoxContainer/InfoLabel
@onready var load_button = $MarginContainer/HBoxContainer/HBoxContainer/LoadButton
@onready var delete_button = $MarginContainer/HBoxContainer/HBoxContainer/DeleteButton

var slot_number: int = 1
var save_exists: bool = false

func _ready():
	load_button.pressed.connect(_on_load_pressed)
	delete_button.pressed.connect(_on_delete_pressed)

func setup(save_info: Dictionary, mode: String):
	slot_number = save_info["slot"]
	save_exists = save_info["exists"]
	
	if save_exists:
		slot_label.text = "Save Slot %d" % slot_number
		timestamp_label.text = save_info["timestamp"]
		info_label.text = "%s | Play Time: %s | Completion: %.1f%%" % [
			save_info["current_map"].capitalize(),
			save_info["play_time"],
			save_info["completion"]
		]
		load_button.text = "Load" if mode == "load" else "Select"
		delete_button.visible = true
		delete_button.disabled = false
	else:
		slot_label.text = "Save Slot %d - Empty" % slot_number
		timestamp_label.text = "No save data"
		info_label.text = "Click to create new save"
		load_button.text = "New Game"
		delete_button.visible = false
	
	# Adjust button behavior based on mode
	if mode == "new_game" and save_exists:
		load_button.text = "Overwrite"

func _on_load_pressed():
	emit_signal("slot_pressed", slot_number)

func _on_delete_pressed():
	# Show confirmation dialog
	var dialog = ConfirmationDialog.new()
	dialog.dialog_text = "Delete save slot %d?" % slot_number
	dialog.confirmed.connect(func(): emit_signal("slot_deleted", slot_number))
	add_child(dialog)
	dialog.popup_centered()
