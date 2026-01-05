extends Node
## SettingsManager - Applies settings on game startup
## Add to Project Settings → Autoload

var settings: Dictionary = {}

func _ready() -> void:
	load_and_apply_settings()


func load_and_apply_settings() -> void:
	"""Load settings and apply them"""
	if SaveManager:
		settings = SaveManager.load_settings()
	else:
		settings = get_defaults()
	
	apply_all_settings()


func get_defaults() -> Dictionary:
	return {
		"master_volume": 1.0,
		"music_volume": 0.8,
		"sfx_volume": 1.0,
		"fullscreen": false,
		"vsync": true
	}


func apply_all_settings() -> void:
	"""Apply all settings"""
	apply_fullscreen(settings.get("fullscreen", false))
	apply_vsync(settings.get("vsync", true))
	apply_volume("Master", settings.get("master_volume", 1.0))
	apply_volume("Music", settings.get("music_volume", 0.8))
	apply_volume("SFX", settings.get("sfx_volume", 1.0))
	print("[SettingsManager] Settings applied")


func apply_fullscreen(enabled: bool) -> void:
	"""Apply fullscreen setting"""
	if enabled:
		# Use EXCLUSIVE for true fullscreen, FULLSCREEN for borderless
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	print("[SettingsManager] Fullscreen: %s" % enabled)


func apply_vsync(enabled: bool) -> void:
	"""Apply VSync setting"""
	if enabled:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	print("[SettingsManager] VSync: %s" % enabled)


func apply_volume(bus_name: String, volume: float) -> void:
	"""Apply volume to audio bus"""
	var idx = AudioServer.get_bus_index(bus_name)
	if idx != -1:
		AudioServer.set_bus_volume_db(idx, linear_to_db(volume))


func set_fullscreen(enabled: bool) -> void:
	settings["fullscreen"] = enabled
	apply_fullscreen(enabled)
	_save()


func set_vsync(enabled: bool) -> void:
	settings["vsync"] = enabled
	apply_vsync(enabled)
	_save()


func set_volume(bus_name: String, volume: float) -> void:
	var key = bus_name.to_lower() + "_volume"
	settings[key] = volume
	apply_volume(bus_name, volume)
	_save()


func _save() -> void:
	if SaveManager:
		SaveManager.save_settings(settings)
