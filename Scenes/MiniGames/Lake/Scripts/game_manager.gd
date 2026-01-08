extends Node
signal all_corrupters_defused
signal game_won

var total_corrupters: int = 0
var defused_corrupters: int = 0
var fish_killed: int = 0
var game_start_time: float = 0.0
var game_end_time: float = 0.0
var game_duration: float = 0.0

var portal_blocker: StaticBody2D = null
var blocked_label: Label = null

func _ready() -> void:
	add_to_group("game_manager")
	game_start_time = Time.get_ticks_msec() / 1000.0
	
	# Wait for scene to load, then setup
	await get_tree().process_frame
	_count_corrupters()
	_block_portal()

func register_fish_kill() -> void:
	fish_killed += 1
	print("Fish killed: ", fish_killed)

func _count_corrupters() -> void:
	var corrupters = get_tree().get_nodes_in_group("corrupter")
	total_corrupters = corrupters.size()
	print("Total corrupters found: ", total_corrupters)
	
	# Connect to each corrupter's defused signal
	for corrupter in corrupters:
		if corrupter.has_signal("corrupter_defused"):
			corrupter.corrupter_defused.connect(_on_corrupter_defused)
			print("Connected to corrupter: ", corrupter.name)

func _block_portal() -> void:
	var portal = get_tree().get_first_node_in_group("portal")
	if not portal:
		push_warning("Portal not found!")
		return
	
	# Create a physical blocker (StaticBody2D with collision)
	portal_blocker = StaticBody2D.new()
	portal_blocker.name = "PortalBlocker"
	portal_blocker.collision_layer = 1  # World layer
	portal_blocker.collision_mask = 2   # Player layer
	
	# Add collision shape
	var collision_shape = CollisionShape2D.new()
	var rect_shape = RectangleShape2D.new()
	rect_shape.size = Vector2(80, 80)  # Adjust size as needed
	collision_shape.shape = rect_shape
	portal_blocker.add_child(collision_shape)
	
	# Add blocker to portal
	portal.add_child(portal_blocker)
	
	# Create blocked label
	blocked_label = Label.new()
	blocked_label.name = "BlockedLabel"
	blocked_label.text = "Portal Blocked!\nDestroy all corrupters first"
	blocked_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	blocked_label.position = Vector2(-100, -60)
	blocked_label.size = Vector2(200, 60)
	blocked_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	# Styling
	blocked_label.add_theme_font_size_override("font_size", 16)
	blocked_label.add_theme_color_override("font_color", Color.RED)
	blocked_label.add_theme_color_override("font_outline_color", Color.BLACK)
	blocked_label.add_theme_constant_override("outline_size", 3)
	
	portal.add_child(blocked_label)
	print("Portal blocked - physical collision enabled")

func _unblock_portal() -> void:
	# Remove the physical blocker
	if portal_blocker:
		portal_blocker.queue_free()
		portal_blocker = null
	
	# Remove blocked label
	if blocked_label:
		blocked_label.queue_free()
		blocked_label = null
	
	print("Portal unblocked - physical collision removed!")

func _on_corrupter_defused() -> void:
	defused_corrupters += 1
	print("Corrupters defused: ", defused_corrupters, "/", total_corrupters)
	
	# Check if all are defused
	if defused_corrupters >= total_corrupters and total_corrupters > 0:
		_all_corrupters_defused()

func _all_corrupters_defused() -> void:
	game_end_time = Time.get_ticks_msec() / 1000.0
	game_duration = game_end_time - game_start_time
	
	print("All corrupters defused! Unblocking portal...")
	all_corrupters_defused.emit()
	
	# Unblock the portal
	_unblock_portal()
	
	# Kill all fish
	_kill_all_fish()
	
	# Wait for fish to float away, then show win screen
	await get_tree().create_timer(2.5).timeout
	_show_win_screen()

func _kill_all_fish() -> void:
	var fish = get_tree().get_nodes_in_group("enemy")
	for f in fish:
		if f.has_method("die_and_float"):
			f.die_and_float()

func _show_win_screen() -> void:
	game_won.emit()
	
	var win_screen = get_tree().get_first_node_in_group("win_screen")
	if win_screen:
		win_screen.show_win_screen()
