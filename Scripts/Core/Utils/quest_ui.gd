extends CanvasLayer
class_name QuestUI
## QuestUI - Nepali-inspired dystopian quest tracker
## Dark, weathered, elegant aesthetic
## Add as AutoLoad named "QuestUI"

#region Configuration
@export_category("Position")
@export var margin_right: float = 28.0
@export var margin_top: float = 90.0
@export var panel_width: float = 280.0

@export_category("Colors - Dystopian Nepali")
## Deep crimson, worn
@export var accent_color: Color = Color(0.72, 0.16, 0.14, 1.0)
## Antique brass/gold
@export var gold_color: Color = Color(0.78, 0.62, 0.35, 0.95)
## Bright gold for highlights
@export var gold_bright: Color = Color(0.9, 0.75, 0.45, 1.0)
## Warm parchment text
@export var text_color: Color = Color(0.88, 0.84, 0.76, 1.0)
## Muted objective text
@export var dim_text_color: Color = Color(0.62, 0.58, 0.52, 0.95)
## Completed - sage green
@export var complete_color: Color = Color(0.5, 0.68, 0.45, 0.9)
## Deep worn background
@export var bg_color: Color = Color(0.065, 0.05, 0.045, 0.94)
## Secondary background
@export var bg_secondary: Color = Color(0.1, 0.08, 0.07, 0.6)
## Border - dried blood
@export var border_color: Color = Color(0.4, 0.14, 0.12, 0.85)
## Shadow color
@export var shadow_color: Color = Color(0.0, 0.0, 0.0, 0.4)
#endregion

# UI Elements
var panel: Control
var header_label: Label
var quest_container: VBoxContainer
var empty_label: Label
var scroll_container: ScrollContainer

# Quest data
var quests: Dictionary = {}

# Animation
var _header_glow_tween: Tween


func _ready() -> void:
	layer = 50
	_build_ui()
	_connect_quest_manager()
	_start_ambient_animation()
	print("[QuestUI] Initialized")


func _connect_quest_manager() -> void:
	var qm = get_node_or_null("/root/QuestManager")
	if not qm:
		return
	
	if qm.has_signal("quest_activated"):
		qm.quest_activated.connect(func(quest):
			var objs: Array[String] = []
			if quest.objectives:
				objs.assign(quest.objectives)
			add_quest(quest.id, quest.title, objs)
		)
	
	if qm.has_signal("quest_completed"):
		qm.quest_completed.connect(func(quest):
			complete_quest(quest.id)
		)
	
	if qm.has_signal("objective_completed"):
		qm.objective_completed.connect(func(quest, idx):
			complete_objective(quest.id, idx)
		)
	
	print("[QuestUI] Connected to QuestManager")


func _build_ui() -> void:
	# Root anchor
	var root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	
	# Main panel
	panel = Control.new()
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -(panel_width + margin_right)
	panel.offset_right = -margin_right
	panel.offset_top = margin_top
	panel.offset_bottom = margin_top + 420
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)
	
	# Drop shadow
	var shadow = _create_shadow()
	panel.add_child(shadow)
	
	# Background with ornate frame
	var bg = _create_background()
	panel.add_child(bg)
	
	# Content container
	var content = MarginContainer.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.add_theme_constant_override("margin_left", 18)
	content.add_theme_constant_override("margin_right", 18)
	content.add_theme_constant_override("margin_top", 12)
	content.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(content)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	content.add_child(vbox)
	
	# Header
	var header_container = _create_header()
	vbox.add_child(header_container)
	
	# Scrollable quest area
	scroll_container = ScrollContainer.new()
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_container.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	vbox.add_child(scroll_container)
	
	# Quest list
	quest_container = VBoxContainer.new()
	quest_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quest_container.add_theme_constant_override("separation", 16)
	scroll_container.add_child(quest_container)
	
	# Empty state
	empty_label = Label.new()
	empty_label.text = "No active quests"
	empty_label.add_theme_color_override("font_color", Color(dim_text_color, 0.4))
	empty_label.add_theme_font_size_override("font_size", 12)
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quest_container.add_child(empty_label)


func _create_shadow() -> Control:
	var shadow = ColorRect.new()
	shadow.set_anchors_preset(Control.PRESET_FULL_RECT)
	shadow.offset_left = 4
	shadow.offset_top = 4
	shadow.offset_right = 4
	shadow.offset_bottom = 4
	shadow.color = shadow_color
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return shadow


func _create_background() -> Control:
	var bg_container = Control.new()
	bg_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Main dark background
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = bg_color
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_container.add_child(bg)
	
	# Inner gradient overlay (darker at edges)
	var inner_shadow = ColorRect.new()
	inner_shadow.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner_shadow.offset_left = 3
	inner_shadow.offset_top = 3
	inner_shadow.offset_right = -3
	inner_shadow.offset_bottom = -3
	inner_shadow.color = bg_secondary
	inner_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_container.add_child(inner_shadow)
	
	# === FRAME BORDERS ===
	
	# Left border - thick ornate
	var left_border = ColorRect.new()
	left_border.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	left_border.offset_right = 4
	left_border.color = border_color
	left_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_container.add_child(left_border)
	
	# Left gold inlay
	var left_gold = ColorRect.new()
	left_gold.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	left_gold.offset_left = 4
	left_gold.offset_right = 6
	left_gold.offset_top = 20
	left_gold.offset_bottom = -20
	left_gold.color = Color(gold_color, 0.3)
	left_gold.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_container.add_child(left_gold)
	
	# Right border
	var right_border = ColorRect.new()
	right_border.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	right_border.offset_left = -2
	right_border.color = Color(border_color, 0.6)
	right_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_container.add_child(right_border)
	
	# Top border
	var top_border = ColorRect.new()
	top_border.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_border.offset_bottom = 3
	top_border.color = border_color
	top_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_container.add_child(top_border)
	
	# Top gold accent
	var top_gold = ColorRect.new()
	top_gold.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_gold.offset_top = 3
	top_gold.offset_bottom = 5
	top_gold.offset_left = 20
	top_gold.offset_right = -20
	top_gold.color = Color(gold_color, 0.5)
	top_gold.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_container.add_child(top_gold)
	
	# Bottom border
	var bottom_border = ColorRect.new()
	bottom_border.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_border.offset_top = -3
	bottom_border.color = Color(border_color, 0.7)
	bottom_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_container.add_child(bottom_border)
	
	# === CORNER ORNAMENTS ===
	
	# Top-left corner (large)
	var corner_tl = _create_corner_ornament(true, true)
	bg_container.add_child(corner_tl)
	
	# Top-right corner
	var corner_tr = _create_corner_ornament(false, true)
	bg_container.add_child(corner_tr)
	
	# Bottom-left corner
	var corner_bl = _create_corner_ornament(true, false)
	bg_container.add_child(corner_bl)
	
	# Bottom-right corner
	var corner_br = _create_corner_ornament(false, false)
	bg_container.add_child(corner_br)
	
	return bg_container


func _create_corner_ornament(is_left: bool, is_top: bool) -> Control:
	var container = Control.new()
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var x_offset = 0 if is_left else panel_width - 14
	var y_offset = 0 if is_top else -14
	
	# Outer square
	var outer = ColorRect.new()
	outer.offset_left = x_offset
	outer.offset_top = y_offset if is_top else 0
	outer.offset_right = x_offset + 14
	outer.offset_bottom = 14 if is_top else 0
	if not is_top:
		outer.set_anchors_preset(Control.PRESET_BOTTOM_LEFT if is_left else Control.PRESET_BOTTOM_RIGHT)
		outer.offset_top = -14
		outer.offset_bottom = 0
		outer.offset_left = 0 if is_left else -14
		outer.offset_right = 14 if is_left else 0
	outer.color = accent_color
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(outer)
	
	# Inner gold square
	var inner = ColorRect.new()
	if is_top:
		inner.offset_left = x_offset + 3
		inner.offset_top = y_offset + 3 if is_top else 3
		inner.offset_right = x_offset + 11
		inner.offset_bottom = 11
	else:
		inner.set_anchors_preset(Control.PRESET_BOTTOM_LEFT if is_left else Control.PRESET_BOTTOM_RIGHT)
		inner.offset_left = 3 if is_left else -11
		inner.offset_top = -11
		inner.offset_right = 11 if is_left else -3
		inner.offset_bottom = -3
	inner.color = gold_color
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(inner)
	
	return container


func _create_header() -> Control:
	var header_box = VBoxContainer.new()
	header_box.add_theme_constant_override("separation", 8)
	
	# Decorative top element
	var top_deco = HBoxContainer.new()
	top_deco.alignment = BoxContainer.ALIGNMENT_CENTER
	top_deco.add_theme_constant_override("separation", 0)
	
	var deco_label = Label.new()
	deco_label.text = "◆  ◆  ◆"
	deco_label.add_theme_color_override("font_color", Color(gold_color, 0.4))
	deco_label.add_theme_font_size_override("font_size", 8)
	deco_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_deco.add_child(deco_label)
	header_box.add_child(top_deco)
	
	# Main title row
	var title_row = HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 12)
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	
	# Left ornament
	var left_orn = Label.new()
	left_orn.text = "═══"
	left_orn.add_theme_color_override("font_color", Color(gold_color, 0.6))
	left_orn.add_theme_font_size_override("font_size", 11)
	title_row.add_child(left_orn)
	
	# Title with icon
	var title_container = HBoxContainer.new()
	title_container.add_theme_constant_override("separation", 8)
	
	# Quest icon (scroll/book symbol)
	var icon_label = Label.new()
	icon_label.text = "📜"
	icon_label.add_theme_font_size_override("font_size", 14)
	title_container.add_child(icon_label)
	
	# Main title
	header_label = Label.new()
	header_label.name = "HeaderLabel"
	header_label.text = "QUESTS"
	header_label.add_theme_color_override("font_color", gold_bright)
	header_label.add_theme_font_size_override("font_size", 16)
	header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_container.add_child(header_label)
	
	title_row.add_child(title_container)
	
	# Right ornament
	var right_orn = Label.new()
	right_orn.text = "═══"
	right_orn.add_theme_color_override("font_color", Color(gold_color, 0.6))
	right_orn.add_theme_font_size_override("font_size", 11)
	title_row.add_child(right_orn)
	
	header_box.add_child(title_row)
	
	# Nepali subtitle
	var subtitle = Label.new()
	subtitle.text = "कार्यहरू"  # "Tasks" in Nepali
	subtitle.add_theme_color_override("font_color", Color(accent_color, 0.7))
	subtitle.add_theme_font_size_override("font_size", 10)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_box.add_child(subtitle)
	
	# Separator with ornament
	var sep_container = HBoxContainer.new()
	sep_container.alignment = BoxContainer.ALIGNMENT_CENTER
	sep_container.add_theme_constant_override("separation", 0)
	
	var sep_left = ColorRect.new()
	sep_left.custom_minimum_size = Vector2(60, 1)
	sep_left.color = Color(gold_color, 0.35)
	sep_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sep_container.add_child(sep_left)
	
	var sep_center = Label.new()
	sep_center.text = " ◈ "
	sep_center.add_theme_color_override("font_color", Color(accent_color, 0.8))
	sep_center.add_theme_font_size_override("font_size", 10)
	sep_container.add_child(sep_center)
	
	var sep_right = ColorRect.new()
	sep_right.custom_minimum_size = Vector2(60, 1)
	sep_right.color = Color(gold_color, 0.35)
	sep_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sep_container.add_child(sep_right)
	
	header_box.add_child(sep_container)
	
	return header_box


func _start_ambient_animation() -> void:
	# Subtle glow pulse on header
	_pulse_header()


func _pulse_header() -> void:
	if not is_instance_valid(header_label):
		return
	
	_header_glow_tween = create_tween()
	_header_glow_tween.set_loops()
	_header_glow_tween.tween_property(header_label, "modulate", Color(1.15, 1.1, 1.0, 1.0), 2.0)
	_header_glow_tween.tween_property(header_label, "modulate", Color(1.0, 1.0, 1.0, 1.0), 2.0)


#region Public API

## Add a quest with optional priority indicator
func add_quest(id: String, title: String, objectives: Array[String] = [], is_main: bool = false) -> void:
	if id in quests:
		return
	
	empty_label.hide()
	
	var quest_node = _create_quest_node(id, title, objectives, is_main)
	quest_container.add_child(quest_node)
	
	quests[id] = {
		"node": quest_node,
		"title": title,
		"completed": [],
		"is_main": is_main
	}
	
	for i in range(objectives.size()):
		quests[id].completed.append(false)
	
	# Animated entry
	quest_node.modulate.a = 0
	quest_node.position.x = 20
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(quest_node, "modulate:a", 1.0, 0.5).set_ease(Tween.EASE_OUT)
	tween.tween_property(quest_node, "position:x", 0, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	
	print("[QuestUI] Quest added: %s" % title)


## Complete an objective
func complete_objective(id: String, index: int) -> void:
	if id not in quests:
		return
	
	var data = quests[id]
	if index >= data.completed.size() or data.completed[index]:
		return
	
	data.completed[index] = true
	
	# Update visual
	var obj_container = data.node.get_node_or_null("Objectives")
	if obj_container and index < obj_container.get_child_count():
		_mark_objective_done(obj_container.get_child(index))
	
	# Check all done
	var all_done = true
	for c in data.completed:
		if not c:
			all_done = false
			break
	
	if all_done and data.completed.size() > 0:
		await get_tree().create_timer(0.8).timeout
		complete_quest(id)


## Complete entire quest
func complete_quest(id: String) -> void:
	if id not in quests:
		return
	
	var node = quests[id].node
	var title = quests[id].title
	
	# Celebration flash then fade
	var tween = create_tween()
	tween.tween_property(node, "modulate", Color(1.3, 1.4, 1.2, 1.0), 0.15)
	tween.tween_property(node, "modulate", Color(0.7, 0.65, 0.5, 0.9), 0.3)
	tween.tween_property(node, "modulate:a", 0.0, 0.4)
	tween.parallel().tween_property(node, "position:x", -30, 0.4)
	
	await tween.finished
	node.queue_free()
	quests.erase(id)
	
	_check_empty()
	print("[QuestUI] Quest completed: %s" % title)


## Remove quest without completion animation
func remove_quest(id: String) -> void:
	if id not in quests:
		return
	
	var node = quests[id].node
	var tween = create_tween()
	tween.tween_property(node, "modulate:a", 0.0, 0.3)
	await tween.finished
	
	node.queue_free()
	quests.erase(id)
	_check_empty()


## Clear all quests
func clear_all() -> void:
	for id in quests.keys():
		quests[id].node.queue_free()
	quests.clear()
	_check_empty()


## Update quest title
func set_quest_title(id: String, new_title: String) -> void:
	if id in quests:
		var title_label = quests[id].node.get_node_or_null("TitleLabel")
		if title_label:
			title_label.text = new_title
			quests[id].title = new_title




## Check if quest exists
func has_quest(id: String) -> bool:
	return id in quests


## Get active quest count
func get_quest_count() -> int:
	return quests.size()

#endregion


#region Internal

func _create_quest_node(id: String, title: String, objectives: Array[String], is_main: bool = false) -> Control:
	var quest_box = VBoxContainer.new()
	quest_box.name = "Quest_" + id
	quest_box.add_theme_constant_override("separation", 6)
	
	# Quest header row
	var header_row = HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 8)
	
	# Quest type indicator
	var indicator = Label.new()
	indicator.name = "Indicator"
	if is_main:
		indicator.text = "◆"
		indicator.add_theme_color_override("font_color", gold_bright)
	else:
		indicator.text = "◇"
		indicator.add_theme_color_override("font_color", Color(gold_color, 0.7))
	indicator.add_theme_font_size_override("font_size", 12)
	indicator.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header_row.add_child(indicator)
	
	# Quest title
	var title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.text = title
	title_label.add_theme_color_override("font_color", text_color if not is_main else gold_bright)
	title_label.add_theme_font_size_override("font_size", 14)
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(title_label)
	
	quest_box.add_child(header_row)
	
	# Thin separator under title
	var title_sep = ColorRect.new()
	title_sep.custom_minimum_size.y = 1
	title_sep.color = Color(accent_color, 0.3)
	title_sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	quest_box.add_child(title_sep)
	
	# Objectives
	if objectives.size() > 0:
		var obj_box = VBoxContainer.new()
		obj_box.name = "Objectives"
		obj_box.add_theme_constant_override("separation", 4)
		
		for i in range(objectives.size()):
			var obj = _create_objective_node(objectives[i], i)
			obj_box.add_child(obj)
		
		quest_box.add_child(obj_box)
	
	return quest_box


func _create_objective_node(text: String, index: int) -> Control:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.set_meta("done", false)
	row.set_meta("index", index)
	
	# Indent spacer
	var spacer = Control.new()
	spacer.custom_minimum_size.x = 12
	row.add_child(spacer)
	
	# Checkbox-style marker
	var marker_container = Control.new()
	marker_container.custom_minimum_size = Vector2(14, 14)
	
	var marker_bg = ColorRect.new()
	marker_bg.name = "MarkerBG"
	marker_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	marker_bg.color = Color(accent_color, 0.25)
	marker_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker_container.add_child(marker_bg)
	
	var marker_border = ColorRect.new()
	marker_border.name = "MarkerBorder"
	marker_border.set_anchors_preset(Control.PRESET_FULL_RECT)
	marker_border.offset_left = 1
	marker_border.offset_top = 1
	marker_border.offset_right = -1
	marker_border.offset_bottom = -1
	marker_border.color = Color(bg_color, 0.9)
	marker_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker_container.add_child(marker_border)
	
	var marker_check = Label.new()
	marker_check.name = "MarkerCheck"
	marker_check.text = ""
	marker_check.set_anchors_preset(Control.PRESET_CENTER)
	marker_check.add_theme_color_override("font_color", complete_color)
	marker_check.add_theme_font_size_override("font_size", 10)
	marker_check.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	marker_check.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	marker_container.add_child(marker_check)
	
	row.add_child(marker_container)
	
	# Objective text
	var label = Label.new()
	label.name = "Text"
	label.text = text
	label.add_theme_color_override("font_color", dim_text_color)
	label.add_theme_font_size_override("font_size", 12)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	
	return row


func _mark_objective_done(obj: Control) -> void:
	if obj.get_meta("done", false):
		return
	
	obj.set_meta("done", true)
	
	var marker_container = obj.get_child(1)  # After spacer
	var marker_bg = marker_container.get_node_or_null("MarkerBG")
	var marker_check = marker_container.get_node_or_null("MarkerCheck")
	var label = obj.get_node_or_null("Text")
	
	# Animate checkmark appearing
	if marker_bg:
		marker_bg.color = Color(complete_color, 0.4)
	
	if marker_check:
		marker_check.text = "✓"
		marker_check.modulate.a = 0
		var check_tween = create_tween()
		check_tween.tween_property(marker_check, "modulate:a", 1.0, 0.2)
	
	if label:
		label.add_theme_color_override("font_color", Color(complete_color, 0.75))
	
	# Satisfying completion flash
	var tween = create_tween()
	tween.tween_property(obj, "modulate", Color(1.3, 1.4, 1.2, 1.0), 0.12)
	tween.tween_property(obj, "modulate", Color.WHITE, 0.25)


func _check_empty() -> void:
	empty_label.visible = quests.is_empty()

#endregion
