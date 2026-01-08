extends Control
## LoginScreen - Team Code and Team Name Login
## UPDATED VERSION - Team-based authentication

#region Scene References
@export_file("*.tscn") var main_menu_path: String = "res://Scenes/Core/MainMenu/main_menu.tscn"
#endregion

#region Node References
# Panels
@onready var login_panel: Control = $LoginPanel

# Login fields
@onready var team_name: LineEdit = $LoginPanel/Container/TeamName
@onready var team_code: LineEdit = $LoginPanel/Container/TeamCode
@onready var login_button: Button = $LoginPanel/Container/HBoxContainer/LoginButton
@onready var guest_button: Button = $LoginPanel/Container/HBoxContainer/GuestButton

# Status
@onready var status_label: Label = $StatusLabel
@onready var loading_spinner: Control = $LoadingSpinner
#endregion

#region State
var is_loading: bool = false
var is_guest_mode: bool = false
#endregion

func _ready() -> void:
	print("[LoginScreen] ═══════════════════════════════════════")
	print("[LoginScreen] Initializing Team Login...")
	_debug_check_nodes()
	_connect_signals()
	_check_existing_session()
	_fix_mouse_filters()
	print("[LoginScreen] Ready!")
	print("[LoginScreen] ═══════════════════════════════════════")


func _fix_mouse_filters() -> void:
	$LoginPanel.mouse_filter = Control.MOUSE_FILTER_PASS
	$LoginPanel/Container.mouse_filter = Control.MOUSE_FILTER_PASS
	$LoginPanel/Container/HBoxContainer.mouse_filter = Control.MOUSE_FILTER_PASS
	$LoadingSpinner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	print("[LoginScreen] Mouse filters fixed!")


func _debug_check_nodes() -> void:
	print("[LoginScreen] Checking nodes...")
	print("  LoginPanel: %s" % ("✓" if login_panel else "✗ MISSING"))
	print("  team_name: %s" % ("✓" if team_name else "✗ MISSING"))
	print("  team_code: %s" % ("✓" if team_code else "✗ MISSING"))
	print("  login_button: %s" % ("✓" if login_button else "✗ MISSING"))
	print("  guest_button: %s" % ("✓" if guest_button else "✗ MISSING"))


func _connect_signals() -> void:
	print("[LoginScreen] Connecting signals...")
	
	# Login button
	if login_button:
		login_button.pressed.connect(_on_login_pressed)
		print("  ✓ LoginButton connected")
	else:
		print("  ✗ LoginButton not found!")
	
	
	# Guest button
	if guest_button:
		guest_button.pressed.connect(_on_guest_pressed)
		print("  ✓ GuestButton connected")
	else:
		print("  ✗ GuestButton not found!")
	
	# AuthManager signals - Only if AuthManager exists
	if AuthManager:
		AuthManager.login_completed.connect(_on_auth_success)
		AuthManager.login_failed.connect(_on_auth_failed)
		AuthManager.session_restored.connect(_on_session_restored)
		AuthManager.session_invalid.connect(_on_session_invalid)
		print("  ✓ AuthManager signals connected")
	else:
		print("  ⚠ AuthManager not found - running in offline mode")

	print("[LoginScreen] Login button pressed")
	
	# DEBUG: Print what we actually have
	print("DEBUG: login_panel exists? ", login_panel != null)
	if login_panel:
		print("DEBUG: login_panel children: ", login_panel.get_children())
		for child in login_panel.get_children():
			print("  - ", child.name, " (", child.get_class(), ")")
			if child.has_node("TeamName"):
				print("    FOUND TeamName at: $LoginPanel/", child.name, "/TeamName")
			if child.has_node("TeamCode"):
				print("    FOUND TeamCode at: $LoginPanel/", child.name, "/TeamCode")
func _check_existing_session() -> void:
	"""Check if user has valid saved session"""
	if not AuthManager:
		print("[LoginScreen] No AuthManager, running in offline mode")
		return
	
	# If already logged in (session was restored before we connected signals)
	if AuthManager.is_logged_in:
		_show_status("Welcome back, %s!" % AuthManager.get_display_name())
		await get_tree().create_timer(1.0).timeout
		_proceed_to_game()


#region Login
func _on_login_pressed() -> void:
	print("[LoginScreen] Login button pressed")
	
	if not AuthManager:
		_show_error("Login requires backend connection. Please use Guest mode.")
		return
	
	# Get nodes directly instead of using @onready variables (web build fix)
	var team_name_field = $LoginPanel/Container/TeamName
	var team_code_field = $LoginPanel/Container/TeamCode
	
	if not team_name_field or not team_code_field:
		_show_error("UI Error: Fields not found")
		print("[LoginScreen] ERROR: Could not find input fields!")
		return
	
	var input_team_name = team_name_field.text.strip_edges()
	var input_team_code = team_code_field.text.strip_edges()
	
	print("[LoginScreen] Team Name: '%s', Team Code: '%s'" % [input_team_name, input_team_code])
	
	if input_team_name.is_empty() or input_team_code.is_empty():
		_show_error("Please enter both team name and team code")
		return
	
	_set_loading(true)
	_show_status("Verifying team credentials...")
	
	# Call new team login method
	await AuthManager.login_with_team(input_team_name, input_team_code)
	_set_loading(false)
	
func _on_guest_pressed() -> void:
	print("[LoginScreen] Guest button pressed - starting offline guest mode")
	
	_set_loading(true)
	_show_status("Starting as guest...")
	
	# Set guest mode flag
	is_guest_mode = true
	
	# Initialize guest session locally (no backend needed)
	_setup_guest_session()
	
	await get_tree().create_timer(0.5).timeout
	_set_loading(false)
	
	_show_success("Playing as Guest")
	await get_tree().create_timer(1.0).timeout
	
	# Go directly to game for guests
	_proceed_to_game()


func _setup_guest_session() -> void:
	"""Setup a local guest session without backend"""
	print("[LoginScreen] Setting up offline guest session")
	
	# If AuthManager exists, use it for guest mode
	if AuthManager and AuthManager.has_method("set_guest_mode"):
		AuthManager.set_guest_mode()
	
	# If ScoreManager exists, enable offline mode
	if ScoreManager and ScoreManager.has_method("set_offline_mode"):
		ScoreManager.set_offline_mode(true)
	
	print("[LoginScreen] Guest session ready (offline mode)")
#endregion


#region Auth Callbacks
func _on_auth_success(user_data: Dictionary) -> void:
	print("[LoginScreen] Auth success! Team: %s" % user_data.get("team_name", "Unknown"))
	_show_success("Welcome, %s!" % user_data.get("team_name", "Team"))
	await get_tree().create_timer(1.0).timeout
	_proceed_to_game()


func _on_auth_failed(error: String) -> void:
	print("[LoginScreen] Auth failed: %s" % error)
	_show_error(error)


func _on_session_restored(user_data: Dictionary) -> void:
	print("[LoginScreen] Session restored for: %s" % user_data.get("team_name", "Unknown"))
	_show_status("Welcome back, %s!" % user_data.get("team_name", "Team"))
	await get_tree().create_timer(1.0).timeout
	_proceed_to_game()


func _on_session_invalid() -> void:
	print("[LoginScreen] Session invalid, staying on login screen")
	_clear_status()
#endregion


#region Navigation
func _proceed_to_game() -> void:
	print("[LoginScreen] Proceeding to main menu: %s" % main_menu_path)
	
	# Only sync if logged in (not guest) and backend is available
	if not is_guest_mode and AuthManager and AuthManager.is_logged_in and ScoreManager:
		if ScoreManager.has_method("sync_progress"):
			await ScoreManager.sync_progress()
	
	if not ResourceLoader.exists(main_menu_path):
		_show_error("Main menu scene not found: %s" % main_menu_path)
		print("[LoginScreen] ERROR: Scene not found: %s" % main_menu_path)
		return
	
	get_tree().change_scene_to_file(main_menu_path)
#endregion


#region UI Helpers
func _show_error(message: String) -> void:
	_show_toast(message, Color(1.0, 0.3, 0.3), Color(0.2, 0.05, 0.05, 0.95))
	print("[LoginScreen] ERROR: %s" % message)


func _show_status(message: String) -> void:
	_show_toast(message, Color(0.9, 0.9, 0.9), Color(0.15, 0.15, 0.15, 0.95))
	print("[LoginScreen] Status: %s" % message)


func _show_success(message: String) -> void:
	_show_toast(message, Color(0.3, 1.0, 0.4), Color(0.05, 0.2, 0.05, 0.95))
	print("[LoginScreen] Success: %s" % message)


var _toast_bg: PanelContainer = null

func _show_toast(message: String, text_color: Color, bg_color: Color, duration: float = 4.0) -> void:
	if not status_label:
		return
	
	if not _toast_bg:
		_toast_bg = _create_toast_background()
	
	status_label.text = message
	status_label.add_theme_color_override("font_color", text_color)
	
	var style = _toast_bg.get_theme_stylebox("panel").duplicate()
	style.bg_color = bg_color
	_toast_bg.add_theme_stylebox_override("panel", style)
	
	_toast_bg.visible = true
	_toast_bg.modulate.a = 0.0
	
	var tween = create_tween()
	tween.tween_property(_toast_bg, "modulate:a", 1.0, 0.2)
	
	if text_color.r > 0.7 and text_color.g < 0.5:
		_shake_toast()
	
	if duration > 0 and not message.ends_with("..."):
		await get_tree().create_timer(duration).timeout
		if status_label.text == message:
			_fade_out_toast()


func _create_toast_background() -> PanelContainer:
	var center = CenterContainer.new()
	center.name = "ToastCenter"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.anchor_top = 0.85
	
	var bg = PanelContainer.new()
	bg.name = "ToastBG"
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.15, 0.95)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.3, 0.3, 0.3, 0.5)
	
	bg.add_theme_stylebox_override("panel", style)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var parent = status_label.get_parent()
	parent.remove_child(status_label)
	bg.add_child(status_label)
	
	center.add_child(bg)
	add_child(center)
	
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.position = Vector2.ZERO
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	_toast_bg = bg
	return bg


func _shake_toast() -> void:
	if not _toast_bg:
		return
	
	var tween = create_tween()
	var base_x = _toast_bg.position.x
	
	tween.tween_property(_toast_bg, "position:x", base_x + 12, 0.04)
	tween.tween_property(_toast_bg, "position:x", base_x - 12, 0.04)
	tween.tween_property(_toast_bg, "position:x", base_x + 8, 0.04)
	tween.tween_property(_toast_bg, "position:x", base_x - 8, 0.04)
	tween.tween_property(_toast_bg, "position:x", base_x + 4, 0.04)
	tween.tween_property(_toast_bg, "position:x", base_x, 0.04)


func _fade_out_toast() -> void:
	if _toast_bg and _toast_bg.visible:
		var tween = create_tween()
		tween.tween_property(_toast_bg, "modulate:a", 0.0, 0.3)
		await tween.finished
		_toast_bg.visible = false


func _clear_status() -> void:
	_fade_out_toast()


func _set_loading(loading: bool) -> void:
	is_loading = loading
	
	if loading_spinner:
		loading_spinner.visible = loading
	
	if login_button:
		login_button.disabled = loading
	if guest_button:
		guest_button.disabled = loading
#endregion


#region Input
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_on_login_pressed()
#endregion
