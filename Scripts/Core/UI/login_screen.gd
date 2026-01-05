extends Control
## LoginScreen - Login, Registration, and Event Code Entry
## FIXED VERSION - Matches your exact scene structure

#region Scene References
@export_file("*.tscn") var main_menu_path: String = "res://Scenes/Core/MainMenu/main_menu.tscn"
#endregion

#region Node References
# Panels - These are the three main panels
@onready var login_panel: Control = $LoginPanel
@onready var register_panel: Control = $RegisterPanel
@onready var event_code_panel: Control = $EventCodePanel

# Login fields (under LoginPanel/Container/)
@onready var login_email: LineEdit = $LoginPanel/Container/Email
@onready var login_password: LineEdit = $LoginPanel/Container/Password
@onready var login_button: Button = $LoginPanel/Container/HBoxContainer/LoginButton
@onready var register_link: Button = $LoginPanel/Container/HBoxContainer/RegisterLink
@onready var guest_button: Button = $LoginPanel/Container/HBoxContainer/GuestButton

# Register fields (under RegisterPanel/Container/)
@onready var register_email: LineEdit = $RegisterPanel/Container/Email
@onready var register_password: LineEdit = $RegisterPanel/Container/Password
@onready var register_confirm: LineEdit = $RegisterPanel/Container/ConfirmPassword
@onready var register_name: LineEdit = $RegisterPanel/Container/DisplayName
@onready var register_button: Button = $RegisterPanel/Container/RegisterButton
@onready var login_link: Button = $RegisterPanel/Container/LoginLink

# Event code fields (under EventCodePanel/Container/)
@onready var event_code_input: LineEdit = $EventCodePanel/Container/CodeInput
@onready var verify_button: Button = $EventCodePanel/Container/VerifyButton
@onready var skip_button: Button = $EventCodePanel/Container/SkipButton

# Status (direct children of LoginScreen)
@onready var status_label: Label = $StatusLabel
@onready var loading_spinner: Control = $LoadingSpinner
#endregion

#region State
enum Screen { LOGIN, REGISTER, EVENT_CODE }
var current_screen: Screen = Screen.LOGIN
var is_loading: bool = false
#endregion

func _ready() -> void:
	print("[LoginScreen] ═══════════════════════════════════════")
	print("[LoginScreen] Initializing...")
	_debug_mouse_filters()
	
	# Debug: Check if nodes exist
	_debug_check_nodes()
	
	# Connect signals
	_connect_signals()
	
	# Show login panel first, hide others
	_show_screen(Screen.LOGIN)
	
	# Check for existing session (if already logged in)
	_check_existing_session()
	_fix_mouse_filters()
	_fix_all_mouse_filters(self)
	print("[LoginScreen] Ready!")
	print("[LoginScreen] ═══════════════════════════════════════")
	
func _fix_all_mouse_filters(node: Node) -> void:
	if node is Control:
		var ctrl = node as Control
		# Only buttons and line edits should stop
		if ctrl is Button or ctrl is LineEdit:
			ctrl.mouse_filter = Control.MOUSE_FILTER_STOP
		else:
			ctrl.mouse_filter = Control.MOUSE_FILTER_PASS
		
		print("Set %s to %s" % [node.name, ctrl.mouse_filter])
	
	for child in node.get_children():
		_fix_all_mouse_filters(child)
func _fix_mouse_filters() -> void:
	# Panels should let clicks through to their children
	$LoginPanel.mouse_filter = Control.MOUSE_FILTER_PASS
	$RegisterPanel.mouse_filter = Control.MOUSE_FILTER_PASS
	$EventCodePanel.mouse_filter = Control.MOUSE_FILTER_PASS
	
	# Containers inside panels should also pass clicks
	$LoginPanel/Container.mouse_filter = Control.MOUSE_FILTER_PASS
	$LoginPanel/Container/HBoxContainer.mouse_filter = Control.MOUSE_FILTER_PASS
	
	$RegisterPanel/Container.mouse_filter = Control.MOUSE_FILTER_PASS
	
	$EventCodePanel/Container.mouse_filter = Control.MOUSE_FILTER_PASS
	
	# Non-interactive elements should ignore mouse entirely
	$LoadingSpinner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$VBoxContainer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	print("[LoginScreen] Mouse filters fixed!")
func _debug_mouse_filters() -> void:
	print("[LoginScreen] ═══ MOUSE FILTER DEBUG ═══")
	for child in get_children():
		if child is Control:
			var filter_name = ""
			match child.mouse_filter:
				Control.MOUSE_FILTER_STOP:
					filter_name = "STOP ← BLOCKING!"
				Control.MOUSE_FILTER_PASS:
					filter_name = "PASS"
				Control.MOUSE_FILTER_IGNORE:
					filter_name = "IGNORE ✓"
			print("  %s: %s (size: %s, pos: %s)" % [child.name, filter_name, child.size, child.position])
	print("[LoginScreen] ═══════════════════════════")
func _debug_check_nodes() -> void:
	"""Debug function to check if all nodes exist"""
	print("[LoginScreen] Checking nodes...")
	
	# Panels
	print("  LoginPanel: %s" % ("✓" if login_panel else "✗ MISSING"))
	print("  RegisterPanel: %s" % ("✓" if register_panel else "✗ MISSING"))
	print("  EventCodePanel: %s" % ("✓" if event_code_panel else "✗ MISSING"))
	
	# Login panel children
	print("  login_email: %s" % ("✓" if login_email else "✗ MISSING"))
	print("  login_password: %s" % ("✓" if login_password else "✗ MISSING"))
	print("  login_button: %s" % ("✓" if login_button else "✗ MISSING"))
	print("  register_link: %s" % ("✓" if register_link else "✗ MISSING"))
	print("  guest_button: %s" % ("✓" if guest_button else "✗ MISSING"))
	
	# Register panel children
	print("  register_email: %s" % ("✓" if register_email else "✗ MISSING"))
	print("  register_name: %s" % ("✓" if register_name else "✗ MISSING"))
	print("  register_button: %s" % ("✓" if register_button else "✗ MISSING"))
	print("  login_link: %s" % ("✓" if login_link else "✗ MISSING"))


func _connect_signals() -> void:
	print("[LoginScreen] Connecting signals...")
	
	# ═══════════════════════════════════════════════════════════════════
	# LOGIN PANEL BUTTONS
	# ═══════════════════════════════════════════════════════════════════
	
	# Login button - attempts login
	if login_button:
		login_button.pressed.connect(_on_login_pressed)
		print("  ✓ LoginButton connected")
	else:
		print("  ✗ LoginButton not found!")
	
	# Register link - switches to register screen
	if register_link:
		register_link.pressed.connect(_on_register_link_pressed)
		print("  ✓ RegisterLink connected")
	else:
		print("  ✗ RegisterLink not found!")
	
	# Guest button - plays as guest
	if guest_button:
		guest_button.pressed.connect(_on_guest_pressed)
		print("  ✓ GuestButton connected")
	else:
		print("  ✗ GuestButton not found!")
	
	# ═══════════════════════════════════════════════════════════════════
	# REGISTER PANEL BUTTONS
	# ═══════════════════════════════════════════════════════════════════
	
	# Register button - creates account
	if register_button:
		register_button.pressed.connect(_on_register_pressed)
		print("  ✓ RegisterButton connected")
	else:
		print("  ✗ RegisterButton not found!")
	
	# Login link (Back to login) - switches back to login screen
	if login_link:
		login_link.pressed.connect(_on_login_link_pressed)
		print("  ✓ LoginLink (Back to login) connected")
	else:
		print("  ✗ LoginLink not found!")
	
	# ═══════════════════════════════════════════════════════════════════
	# EVENT CODE PANEL BUTTONS
	# ═══════════════════════════════════════════════════════════════════
	
	if verify_button:
		verify_button.pressed.connect(_on_verify_code_pressed)
		print("  ✓ VerifyButton connected")
	
	if skip_button:
		skip_button.pressed.connect(_on_skip_pressed)
		print("  ✓ SkipButton connected")
	
	# ═══════════════════════════════════════════════════════════════════
	# AUTH MANAGER SIGNALS (for responses from server)
	# ═══════════════════════════════════════════════════════════════════
	
	if AuthManager:
		AuthManager.login_success.connect(_on_auth_success)
		AuthManager.login_failed.connect(_on_auth_failed)
		AuthManager.registration_success.connect(_on_auth_success)
		AuthManager.registration_failed.connect(_on_auth_failed)
		AuthManager.event_code_valid.connect(_on_event_code_valid)
		AuthManager.event_code_invalid.connect(_on_event_code_invalid)
		print("  ✓ AuthManager signals connected")
	else:
		print("  ✗ AuthManager not found! Is it in AutoLoad?")


func _check_existing_session() -> void:
	"""Check if user has valid saved session"""
	if not AuthManager:
		print("[LoginScreen] No AuthManager, skipping session check")
		return
	
	_set_loading(true)
	_show_status("Checking session...")
	
	var result = await AuthManager.check_session()
	
	_set_loading(false)
	
	if result.success:
		_show_status("Welcome back, %s!" % AuthManager.get_display_name())
		await get_tree().create_timer(1.0).timeout
		_show_screen(Screen.EVENT_CODE)
	else:
		_clear_status()


#region Screen Management
func _show_screen(screen: Screen) -> void:
	"""Show the specified screen and hide others"""
	current_screen = screen
	
	print("[LoginScreen] Switching to screen: %s" % Screen.keys()[screen])
	
	# Hide all panels first
	if login_panel:
		login_panel.visible = false
	if register_panel:
		register_panel.visible = false
	if event_code_panel:
		event_code_panel.visible = false
	
	# Show the selected panel
	match screen:
		Screen.LOGIN:
			if login_panel:
				login_panel.visible = true
				print("[LoginScreen] LOGIN panel now visible")
		Screen.REGISTER:
			if register_panel:
				register_panel.visible = true
				print("[LoginScreen] REGISTER panel now visible")
		Screen.EVENT_CODE:
			if event_code_panel:
				event_code_panel.visible = true
				print("[LoginScreen] EVENT_CODE panel now visible")
	
	_clear_status()
#endregion

#region Button Handlers
func _on_register_link_pressed() -> void:
	"""Called when 'Register' button on login screen is pressed"""
	print("[LoginScreen] Register link clicked - switching to REGISTER screen")
	_show_screen(Screen.REGISTER)


func _on_login_link_pressed() -> void:
	"""Called when 'Back to login' button on register screen is pressed"""
	print("[LoginScreen] Login link clicked - switching to LOGIN screen")
	_show_screen(Screen.LOGIN)
#endregion

#region Login
func _on_login_pressed() -> void:
	print("[LoginScreen] Login button pressed")
	
	if not login_email or not login_password:
		_show_error("UI Error: Fields not found")
		return
	
	var email = login_email.text.strip_edges()
	var password = login_password.text
	
	# Validate
	if email.is_empty() or password.is_empty():
		_show_error("Please enter email and password")
		return
	
	if not _is_valid_email(email):
		_show_error("Please enter a valid email")
		return
	
	if not AuthManager:
		_show_error("AuthManager not available")
		return
	
	_set_loading(true)
	_show_status("Logging in...")
	
	var result = await AuthManager.login(email, password)
	
	_set_loading(false)
	
	# Result is handled by _on_auth_success or _on_auth_failed


func _on_guest_pressed() -> void:
	"""Login as guest (limited features)"""
	print("[LoginScreen] Guest button pressed")
	
	if not AuthManager:
		_show_error("AuthManager not available")
		return
	
	_set_loading(true)
	_show_status("Starting as guest...")
	
	var result = await AuthManager.login_as_guest()
	
	_set_loading(false)
	
	if result.success:
		_proceed_to_game()
	else:
		_show_error(result.get("error", "Guest login failed"))
#endregion

#region Registration
func _on_register_pressed() -> void:
	print("[LoginScreen] Register button pressed")
	
	if not register_email or not register_password or not register_confirm or not register_name:
		_show_error("UI Error: Fields not found")
		return
	
	var email = register_email.text.strip_edges()
	var password = register_password.text
	var confirm = register_confirm.text
	var display_name = register_name.text.strip_edges()
	
	# Validate
	if email.is_empty() or password.is_empty() or display_name.is_empty():
		_show_error("Please fill all fields")
		return
	
	if not _is_valid_email(email):
		_show_error("Please enter a valid email")
		return
	
	if password.length() < 4:
		_show_error("Password must be at least 4 characters")
		return
	
	if password != confirm:
		_show_error("Passwords do not match")
		return
	
	if display_name.length() < 2:
		_show_error("Display name must be at least 2 characters")
		return
	
	if not AuthManager:
		_show_error("AuthManager not available")
		return
	
	_set_loading(true)
	_show_status("Creating account...")
	
	var result = await AuthManager.register(email, password, display_name)
	
	_set_loading(false)
	
	# Result is handled by _on_auth_success or _on_auth_failed


func _on_auth_success(_user_data: Dictionary) -> void:
	print("[LoginScreen] Auth success!")
	_show_status("Success!")
	await get_tree().create_timer(0.5).timeout
	_show_screen(Screen.EVENT_CODE)


func _on_auth_failed(error: String) -> void:
	print("[LoginScreen] Auth failed: %s" % error)
	_show_error(error)
#endregion

#region Event Code
func _on_verify_code_pressed() -> void:
	print("[LoginScreen] Verify code pressed")
	
	if not event_code_input:
		_show_error("UI Error: Code input not found")
		return
	
	var code = event_code_input.text.strip_edges().to_upper()
	
	if code.is_empty():
		_show_error("Please enter an event code")
		return
	
	if not AuthManager:
		_show_error("AuthManager not available")
		return
	
	_set_loading(true)
	_show_status("Verifying code...")
	
	var result = await AuthManager.verify_event_code(code)
	
	_set_loading(false)


func _on_event_code_valid(_event_data: Dictionary) -> void:
	_show_status("Code verified! Starting game...")
	await get_tree().create_timer(1.0).timeout
	_proceed_to_game()


func _on_event_code_invalid(error: String) -> void:
	_show_error(error)


func _on_skip_pressed() -> void:
	"""Skip event code (play without event)"""
	print("[LoginScreen] Skip pressed - proceeding without event code")
	_show_status("Starting game...")
	await get_tree().create_timer(0.5).timeout
	_proceed_to_game()
#endregion

#region Navigation
func _proceed_to_game() -> void:
	"""Go to main menu"""
	print("[LoginScreen] Proceeding to main menu: %s" % main_menu_path)
	
	# Sync any existing progress
	if AuthManager and AuthManager.is_logged_in and ScoreManager:
		await ScoreManager.sync_progress()
	
	# Check if the main menu path exists
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
	
	# Create background if needed
	if not _toast_bg:
		_toast_bg = _create_toast_background()
	
	# Update text and colors
	status_label.text = message
	status_label.add_theme_color_override("font_color", text_color)
	
	# Update background
	var style = _toast_bg.get_theme_stylebox("panel").duplicate()
	style.bg_color = bg_color
	_toast_bg.add_theme_stylebox_override("panel", style)
	
	# Show with fade in
	_toast_bg.visible = true
	_toast_bg.modulate.a = 0.0
	
	var tween = create_tween()
	tween.tween_property(_toast_bg, "modulate:a", 1.0, 0.2)
	
	# Shake for errors
	if text_color.r > 0.7 and text_color.g < 0.5:
		_shake_toast()
	
	# Auto-hide (skip for loading messages with "...")
	if duration > 0 and not message.ends_with("..."):
		await get_tree().create_timer(duration).timeout
		if status_label.text == message:  # Only fade if message hasn't changed
			_fade_out_toast()


func _create_toast_background() -> PanelContainer:
	# Create a full-screen container to center the toast
	var center = CenterContainer.new()
	center.name = "ToastCenter"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Offset to bottom
	center.anchor_top = 0.85  # Push to bottom 15% of screen
	
	var bg = PanelContainer.new()
	bg.name = "ToastBG"
	
	# Rounded style
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
	
	# Move label into background
	var parent = status_label.get_parent()
	parent.remove_child(status_label)
	bg.add_child(status_label)
	
	# Build hierarchy: center -> bg -> label
	center.add_child(bg)
	add_child(center)
	
	# Center text
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.position = Vector2.ZERO
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Store reference to the actual panel for animations
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
	if register_button:
		register_button.disabled = loading
	if verify_button:
		verify_button.disabled = loading
	if guest_button:
		guest_button.disabled = loading


func _is_valid_email(email: String) -> bool:
	return email.contains("@") and email.contains(".")

#endregion

#region Input
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		match current_screen:
			Screen.LOGIN:
				_on_login_pressed()
			Screen.REGISTER:
				_on_register_pressed()
			Screen.EVENT_CODE:
				_on_verify_code_pressed()
#endregion
