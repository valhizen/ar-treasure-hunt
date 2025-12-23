extends Control
## LoginScreen - Login, Registration, and Event Code Entry
## FIXED VERSION - Matches your exact scene structure

#region Scene References
@export_file("*.tscn") var main_menu_path: String = "res://Sceans/Core/MainMenu/main_menu.tscn"
#endregion

#region Node References
# Panels - These are the three main panels
@onready var login_panel: Control = $LoginPanel
@onready var register_panel: Control = $RegisterPanel
@onready var event_code_panel: Control = $EventCodePanel

# Login fields (under LoginPanel/Container/)
@onready var login_email: LineEdit = $LoginPanel/Container/Email
@onready var login_password: LineEdit = $LoginPanel/Container/Password
@onready var login_button: Button = $LoginPanel/Container/LoginButton
@onready var register_link: Button = $LoginPanel/Container/RegisterLink
@onready var guest_button: Button = $LoginPanel/Container/GuestButton

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
	
	# Debug: Check if nodes exist
	_debug_check_nodes()
	
	# Connect signals
	_connect_signals()
	
	# Show login panel first, hide others
	_show_screen(Screen.LOGIN)
	
	# Check for existing session (if already logged in)
	_check_existing_session()
	
	print("[LoginScreen] Ready!")
	print("[LoginScreen] ═══════════════════════════════════════")


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
func _show_status(message: String) -> void:
	if status_label:
		status_label.text = message
		status_label.add_theme_color_override("font_color", Color.WHITE)
	print("[LoginScreen] Status: %s" % message)


func _show_error(message: String) -> void:
	if status_label:
		status_label.text = message
		status_label.add_theme_color_override("font_color", Color.RED)
	print("[LoginScreen] ERROR: %s" % message)


func _clear_status() -> void:
	if status_label:
		status_label.text = ""


func _set_loading(loading: bool) -> void:
	is_loading = loading
	
	if loading_spinner:
		loading_spinner.visible = loading
	
	# Disable buttons while loading
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
