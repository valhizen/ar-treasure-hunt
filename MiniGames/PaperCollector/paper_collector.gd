extends Node2D

@export var paper_scene: PackedScene
@export var initial_spawn_interval := 2.0
@export_range(0.0, 1.0, 0.01) var spawn_time_decline_factor := 0.85
@export var total_papers := 30

enum GameState { PLAYING, COMPLETED }
var game_state := GameState.PLAYING

@onready var player = $Player
@onready var score_label: Label = $UI/ScoreLabel
@onready var completed_stats: Label = $UI/CompletedStats

var score := 0
var spawn_timer := 0.0
var spawn_interval := initial_spawn_interval

var dropped_papers := 0
var collected_papers := 0
var active_papers := 0

var _screen_width := 0.0

func _ready():
	_screen_width = get_viewport().get_visible_rect().size.x
	score_label.text = "Papers: 0 / " + str(total_papers)
	completed_stats.visible = false

func _process(delta):
	if game_state != GameState.PLAYING:
		return

	spawn_timer += delta

	if spawn_timer >= spawn_interval and dropped_papers < total_papers:
		spawn_timer = 0.0
		dropped_papers += 1
		spawn_paper()

func spawn_paper():
	var paper = paper_scene.instantiate()
	var spawn_x = randf_range(50, _screen_width - 50)
	paper.position = Vector2(spawn_x, -50)

	active_papers += 1

	paper.collected.connect(_on_paper_collected)
	paper.tree_exited.connect(_on_paper_removed)

	add_child(paper)

func _on_paper_collected():
	collected_papers += 1
	spawn_interval *= spawn_time_decline_factor
	score_label.text = "Papers: %d / %d" % [collected_papers, total_papers]

func _on_paper_removed():
	active_papers -= 1

	# Finish ONLY when everything is done
	if dropped_papers >= total_papers and active_papers == 0:
		complete_game()

func complete_game():
	game_state = GameState.COMPLETED
	player.visible = false
	score_label.visible = false
	update_ui()

func update_ui():
	completed_stats.visible = true
	completed_stats.text = "Well done!\nCollected %d / %d papers." % [
		collected_papers,
		total_papers
	]
