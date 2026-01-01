extends CanvasLayer

var death_panel: PanelContainer = null
var death_label: Label = null
var restart_label: Label = null
var is_showing: bool = false

func _ready() -> void:
	# Set this layer to always process (ignore pause)
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Create dark overlay
	death_panel = PanelContainer.new()
	add_child(death_panel)
	
	# Make it cover the entire screen
	death_panel.anchor_left = 0
	death_panel.anchor_top = 0
	death_panel.anchor_right = 1
	death_panel.anchor_bottom = 1
	death_panel.offset_left = 0
	death_panel.offset_top = 0
	death_panel.offset_right = 0
	death_panel.offset_bottom = 0
	
	# Style the overlay
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0, 0, 0, 0.85)
	death_panel.add_theme_stylebox_override("panel", panel_style)
	
	# Create VBox for centering content
	var vbox = VBoxContainer.new()
	death_panel.add_child(vbox)
	vbox.anchor_left = 0.5
	vbox.anchor_top = 0.5
	vbox.anchor_right = 0.5
	vbox.anchor_bottom = 0.5
	vbox.offset_left = -200
	vbox.offset_top = -100
	vbox.offset_right = 200
	vbox.offset_bottom = 100
	vbox.add_theme_constant_override("separation", 20)
	
	# "You Died" label
	death_label = Label.new()
	vbox.add_child(death_label)
	death_label.text = "YOU DIED"
	death_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_label.add_theme_font_size_override("font_size", 64)
	death_label.add_theme_color_override("font_color", Color(0.9, 0.1, 0.1, 1))
	
	# "Press Space to Restart" label
	restart_label = Label.new()
	vbox.add_child(restart_label)
	restart_label.text = "Press SPACE to Restart"
	restart_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	restart_label.add_theme_font_size_override("font_size", 24)
	restart_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1))
	
	# Hide by default
	hide_death_screen()

func _process(_delta: float) -> void:
	if is_showing:
		# Check for space key
		if Input.is_key_pressed(KEY_SPACE):
			restart_game()
		
		# Make restart text blink
		restart_label.modulate.a = 0.5 + (sin(Time.get_ticks_msec() / 300.0) * 0.5)

func show_death_screen() -> void:
	is_showing = true
	death_panel.visible = true
	# Pause the game but allow UI input
	get_tree().paused = true

func hide_death_screen() -> void:
	is_showing = false
	death_panel.visible = false
	get_tree().paused = false

func restart_game() -> void:
	print("Restarting game...")
	get_tree().paused = false
	get_tree().reload_current_scene()
