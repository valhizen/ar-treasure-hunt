extends Node
## AudioManager - Audio Management
## AutoLoad Singleton: Handles music, sound effects, and volume control

#region Signals
signal music_changed(track_name: String)
signal volume_changed(bus_name: String, volume: float)
#endregion

#region Audio Bus Names
const BUS_MASTER: String = "Master"
const BUS_MUSIC: String = "Music"
const BUS_SFX: String = "SFX"
const BUS_AMBIENT: String = "Ambient"
const BUS_UI: String = "UI"
#endregion

#region Audio Players
var music_player: AudioStreamPlayer
var ambient_player: AudioStreamPlayer
var ui_player: AudioStreamPlayer

# Pool of SFX players for overlapping sounds
var sfx_players: Array[AudioStreamPlayer] = []
const SFX_POOL_SIZE: int = 8
#endregion

#region State
var current_music_track: String = ""
var is_music_playing: bool = false
var music_fade_tween: Tween = null
#endregion

#region Lifecycle
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_audio_buses()
	_create_audio_players()
	_load_volume_settings()
	print("[AudioManager] Initialized")


func _setup_audio_buses() -> void:
	"""Ensure required audio buses exist"""
	# Note: You should set up buses in Project Settings > Audio > Buses
	# This just checks they exist
	var buses = [BUS_MUSIC, BUS_SFX, BUS_AMBIENT, BUS_UI]
	for bus_name in buses:
		var idx = AudioServer.get_bus_index(bus_name)
		if idx == -1:
			push_warning("[AudioManager] Audio bus '%s' not found. Create it in Project Settings." % bus_name)


func _create_audio_players() -> void:
	"""Create audio player nodes"""
	# Music player
	music_player = AudioStreamPlayer.new()
	music_player.bus = BUS_MUSIC
	music_player.name = "MusicPlayer"
	add_child(music_player)
	
	# Ambient player
	ambient_player = AudioStreamPlayer.new()
	ambient_player.bus = BUS_AMBIENT
	ambient_player.name = "AmbientPlayer"
	add_child(ambient_player)
	
	# UI player
	ui_player = AudioStreamPlayer.new()
	ui_player.bus = BUS_UI
	ui_player.name = "UIPlayer"
	add_child(ui_player)
	
	# SFX pool
	for i in range(SFX_POOL_SIZE):
		var player = AudioStreamPlayer.new()
		player.bus = BUS_SFX
		player.name = "SFXPlayer_%d" % i
		add_child(player)
		sfx_players.append(player)
#endregion

#region Music Control
func play_music(stream: AudioStream, fade_in: float = 0.5) -> void:
	"""Play a music track with optional fade in"""
	if music_player.stream == stream and is_music_playing:
		return  # Already playing this track
	
	current_music_track = stream.resource_path if stream else ""
	
	if music_fade_tween:
		music_fade_tween.kill()
	
	if fade_in > 0 and is_music_playing:
		# Crossfade
		music_fade_tween = create_tween()
		music_fade_tween.tween_property(music_player, "volume_db", -40.0, fade_in * 0.5)
		music_fade_tween.tween_callback(func():
			music_player.stream = stream
			music_player.play()
		)
		music_fade_tween.tween_property(music_player, "volume_db", 0.0, fade_in * 0.5)
	else:
		music_player.stream = stream
		if fade_in > 0:
			music_player.volume_db = -40.0
			music_player.play()
			music_fade_tween = create_tween()
			music_fade_tween.tween_property(music_player, "volume_db", 0.0, fade_in)
		else:
			music_player.volume_db = 0.0
			music_player.play()
	
	is_music_playing = true
	music_changed.emit(current_music_track)


func play_music_from_path(path: String, fade_in: float = 0.5) -> void:
	"""Load and play music from file path"""
	var stream = load(path) as AudioStream
	if stream:
		play_music(stream, fade_in)
	else:
		push_error("[AudioManager] Could not load music: %s" % path)


func stop_music(fade_out: float = 0.5) -> void:
	"""Stop current music with optional fade out"""
	if not is_music_playing:
		return
	
	if music_fade_tween:
		music_fade_tween.kill()
	
	if fade_out > 0:
		music_fade_tween = create_tween()
		music_fade_tween.tween_property(music_player, "volume_db", -40.0, fade_out)
		music_fade_tween.tween_callback(music_player.stop)
	else:
		music_player.stop()
	
	is_music_playing = false
	current_music_track = ""


func pause_music() -> void:
	"""Pause music"""
	music_player.stream_paused = true


func resume_music() -> void:
	"""Resume music"""
	music_player.stream_paused = false


func is_music_paused() -> bool:
	return music_player.stream_paused
#endregion

#region Sound Effects
func play_sfx(stream: AudioStream, volume_db: float = 0.0, pitch: float = 1.0) -> AudioStreamPlayer:
	"""Play a sound effect"""
	var player = _get_available_sfx_player()
	if player:
		player.stream = stream
		player.volume_db = volume_db
		player.pitch_scale = pitch
		player.play()
		return player
	else:
		push_warning("[AudioManager] No available SFX players")
		return null


func play_sfx_from_path(path: String, volume_db: float = 0.0, pitch: float = 1.0) -> AudioStreamPlayer:
	"""Load and play SFX from file path"""
	var stream = load(path) as AudioStream
	if stream:
		return play_sfx(stream, volume_db, pitch)
	else:
		push_error("[AudioManager] Could not load SFX: %s" % path)
		return null


func play_sfx_random_pitch(stream: AudioStream, volume_db: float = 0.0, pitch_range: Vector2 = Vector2(0.9, 1.1)) -> AudioStreamPlayer:
	"""Play SFX with randomized pitch"""
	var pitch = randf_range(pitch_range.x, pitch_range.y)
	return play_sfx(stream, volume_db, pitch)


func _get_available_sfx_player() -> AudioStreamPlayer:
	"""Get an available SFX player from the pool"""
	for player in sfx_players:
		if not player.playing:
			return player
	# All busy, return the first one (will interrupt oldest sound)
	return sfx_players[0]
#endregion

#region UI Sounds
func play_ui_sound(stream: AudioStream) -> void:
	"""Play a UI sound (button clicks, etc.)"""
	ui_player.stream = stream
	ui_player.play()


func play_ui_click() -> void:
	"""Play default click sound (you need to set this up)"""
	# Load your click sound here
	# play_ui_sound(preload("res://Audio/UI/click.wav"))
	pass


func play_ui_hover() -> void:
	"""Play default hover sound"""
	# play_ui_sound(preload("res://Audio/UI/hover.wav"))
	pass
#endregion

#region Ambient Sounds
func play_ambient(stream: AudioStream, fade_in: float = 1.0) -> void:
	"""Play ambient/background sound"""
	ambient_player.stream = stream
	if fade_in > 0:
		ambient_player.volume_db = -40.0
		ambient_player.play()
		var tween = create_tween()
		tween.tween_property(ambient_player, "volume_db", 0.0, fade_in)
	else:
		ambient_player.volume_db = 0.0
		ambient_player.play()


func stop_ambient(fade_out: float = 1.0) -> void:
	"""Stop ambient sound"""
	if fade_out > 0:
		var tween = create_tween()
		tween.tween_property(ambient_player, "volume_db", -40.0, fade_out)
		tween.tween_callback(ambient_player.stop)
	else:
		ambient_player.stop()
#endregion

#region Volume Control
func set_bus_volume(bus_name: String, volume_linear: float) -> void:
	"""Set volume for a bus (0.0 to 1.0)"""
	var bus_idx = AudioServer.get_bus_index(bus_name)
	if bus_idx == -1:
		push_error("[AudioManager] Bus not found: %s" % bus_name)
		return
	
	volume_linear = clampf(volume_linear, 0.0, 1.0)
	var volume_db = linear_to_db(volume_linear)
	AudioServer.set_bus_volume_db(bus_idx, volume_db)
	
	volume_changed.emit(bus_name, volume_linear)


func get_bus_volume(bus_name: String) -> float:
	"""Get volume for a bus (0.0 to 1.0)"""
	var bus_idx = AudioServer.get_bus_index(bus_name)
	if bus_idx == -1:
		return 0.0
	
	return db_to_linear(AudioServer.get_bus_volume_db(bus_idx))


func set_master_volume(volume: float) -> void:
	set_bus_volume(BUS_MASTER, volume)


func set_music_volume(volume: float) -> void:
	set_bus_volume(BUS_MUSIC, volume)


func set_sfx_volume(volume: float) -> void:
	set_bus_volume(BUS_SFX, volume)


func get_master_volume() -> float:
	return get_bus_volume(BUS_MASTER)


func get_music_volume() -> float:
	return get_bus_volume(BUS_MUSIC)


func get_sfx_volume() -> float:
	return get_bus_volume(BUS_SFX)


func mute_bus(bus_name: String, muted: bool) -> void:
	"""Mute/unmute a bus"""
	var bus_idx = AudioServer.get_bus_index(bus_name)
	if bus_idx != -1:
		AudioServer.set_bus_mute(bus_idx, muted)


func is_bus_muted(bus_name: String) -> bool:
	var bus_idx = AudioServer.get_bus_index(bus_name)
	if bus_idx == -1:
		return false
	return AudioServer.is_bus_mute(bus_idx)
#endregion

#region Settings Persistence
func _load_volume_settings() -> void:
	"""Load volume settings from SaveManager"""
	var settings = SaveManager.load_settings()
	
	set_master_volume(settings.get("master_volume", 1.0))
	set_music_volume(settings.get("music_volume", 0.8))
	set_sfx_volume(settings.get("sfx_volume", 1.0))


func save_volume_settings() -> void:
	"""Save current volume settings"""
	var settings = SaveManager.load_settings()
	settings["master_volume"] = get_master_volume()
	settings["music_volume"] = get_music_volume()
	settings["sfx_volume"] = get_sfx_volume()
	SaveManager.save_settings(settings)
#endregion

#region Utility
func stop_all() -> void:
	"""Stop all audio"""
	music_player.stop()
	ambient_player.stop()
	ui_player.stop()
	for player in sfx_players:
		player.stop()
	is_music_playing = false
	current_music_track = ""
#endregion
