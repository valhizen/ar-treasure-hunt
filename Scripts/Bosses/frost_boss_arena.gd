extends Node2D
class_name FrostBossArena

## Simple arena manager for Frost Boss fight

@export_category("References")
@export var boss_path: NodePath
@export var player_path: NodePath
@export var boss_health_bar_path: NodePath
@export var player_health_bar_path: NodePath

var boss: Node = null
var player: Node = null
var boss_health_bar: Node = null
var player_health_bar: Node = null

var fight_started: bool = false


func _ready() -> void:
	# Wait for everything to be ready
	await get_tree().process_frame
	await get_tree().process_frame
	
	_setup_references()
	_start_fight()


func _setup_references() -> void:
	# Get boss
	if boss_path:
		boss = get_node_or_null(boss_path)
	if not boss:
		var bosses = get_tree().get_nodes_in_group("boss")
		if bosses.size() > 0:
			boss = bosses[0]
	
	# Get player
	if player_path:
		player = get_node_or_null(player_path)
	if not player:
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player = players[0]
	
	# Get boss health bar
	if boss_health_bar_path:
		boss_health_bar = get_node_or_null(boss_health_bar_path)
	if not boss_health_bar:
		for child in get_children():
			if child.get_class() == "CanvasLayer" and child.has_method("setup_boss"):
				boss_health_bar = child
				break
	
	# Get player health bar
	if player_health_bar_path:
		player_health_bar = get_node_or_null(player_health_bar_path)
	if not player_health_bar:
		for child in get_children():
			if child is CanvasLayer and child.has_method("setup_player"):
				if child != boss_health_bar:
					player_health_bar = child
					break
	
	print("[Arena] Boss: ", boss)
	print("[Arena] Player: ", player)
	print("[Arena] BossHealthBar: ", boss_health_bar)
	print("[Arena] PlayerHealthBar: ", player_health_bar)


func _start_fight() -> void:
	if fight_started:
		return
	
	fight_started = true
	print("[Arena] Starting boss fight!")
	
	# Setup boss health bar
	if boss_health_bar and boss:
		if boss_health_bar.has_method("setup_boss"):
			boss_health_bar.setup_boss(boss)
		if boss_health_bar.has_method("show_bar"):
			boss_health_bar.show_bar()
	
	# Setup player health bar
	if player_health_bar and player:
		if player_health_bar.has_method("setup_player"):
			player_health_bar.setup_player(player)
		if player_health_bar.has_method("show_bar"):
			player_health_bar.show_bar()
	
	# Connect boss defeated signal
	if boss and boss.has_signal("boss_defeated"):
		boss.boss_defeated.connect(_on_boss_defeated)
	
	# Connect player died signal
	if player and player.has_signal("player_died"):
		player.player_died.connect(_on_player_died)


func _on_boss_defeated() -> void:
	print("[Arena] Boss defeated!")
	
	await get_tree().create_timer(2.0).timeout
	
	if player_health_bar and player_health_bar.has_method("hide_bar"):
		player_health_bar.hide_bar()


func _on_player_died() -> void:
	print("[Arena] Player died!")
	
	# You can add game over logic here
