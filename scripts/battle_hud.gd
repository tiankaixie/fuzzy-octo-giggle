class_name BattleHUD
extends CanvasLayer

const HOTKEYS := ["J", "K", "L"]
const KEYCODES := [KEY_J, KEY_K, KEY_L]
const SKILL_NAMES := ["FIRE", "SPREAD", "DODGE"]
const ContentRegistryClass := preload("res://scripts/data/content_registry.gd")

var canvas: Node2D
var stage_id := "arcade"
var stage_definition: StageDefinition
var room_index := 0
var room_count := 3
var hp := 100.0
var energy := 76.0
var combo_count := 0
var targets := 0
var salvage := 0
var skill_flash := [0.0, 0.0, 0.0]
var hud_time := 0.0
var banner_text := ""
var banner_time := 0.0
var result_visible := false
var result_title := ""
var result_loot := 0


func _ready() -> void:
	layer = 60
	canvas = Node2D.new()
	canvas.draw.connect(_draw_hud)
	add_child(canvas)


func configure(id: String, rooms: int) -> void:
	stage_id = id
	stage_definition = ContentRegistryClass.stage(id)
	room_count = rooms
	if is_instance_valid(canvas):
		canvas.queue_redraw()


func set_room(index: int) -> void:
	room_index = index
	if is_instance_valid(canvas):
		canvas.queue_redraw()


func set_stats(health: float, current_energy: float, combo: int, target_count := 0, loot := 0) -> void:
	hp = health
	energy = current_energy
	combo_count = combo
	targets = target_count
	salvage = loot


func show_banner(text: String, duration := 1.2) -> void:
	banner_text = text
	banner_time = duration


func show_results(title: String, loot: int) -> void:
	result_visible = true
	result_title = title
	result_loot = loot


func show_defeat() -> void:
	result_visible = true
	result_title = "EXPEDITION FAILED"
	result_loot = 0


func _process(delta: float) -> void:
	hud_time += delta
	banner_time = maxf(0.0, banner_time - delta)
	for i in range(skill_flash.size()):
		skill_flash[i] = maxf(0.0, skill_flash[i] - delta * 3.4)
	canvas.queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var slot := KEYCODES.find(event.keycode)
		if slot >= 0:
			skill_flash[slot] = 1.0


func _draw_hud() -> void:
	var accent: Color = stage_definition.accent_color if stage_definition else Color("58d6cc")
	_draw_minimap(accent)
	_draw_bottom_frame(accent)
	if combo_count > 1:
		_draw_combo(accent)
	if banner_time > 0.0:
		_draw_banner(accent)
	if result_visible:
		_draw_results(accent)


func _draw_combo(accent: Color) -> void:
	var pulse := 1.0 + sin(hud_time * 12.0) * 0.04
	canvas.draw_set_transform(Vector2(335, 205), 0.0, Vector2(pulse, pulse))
	_label(str(combo_count) + " HIT", Vector2.ZERO, accent.lightened(0.25), 14)
	_label("CHAIN", Vector2(2, 10), Color("d4ced9"), 6)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_banner(accent: Color) -> void:
	var alpha := minf(1.0, banner_time * 2.0)
	canvas.draw_rect(Rect2(152, 83, 176, 28), Color(0.02, 0.025, 0.065, 0.82 * alpha))
	canvas.draw_rect(Rect2(152, 83, 176, 28), Color(accent, alpha), false, 1)
	_label(banner_text, Vector2(187, 101), Color(accent, alpha), 10)


func _draw_results(accent: Color) -> void:
	canvas.draw_rect(Rect2(0, 0, 480, 226), Color(0.015, 0.02, 0.055, 0.72))
	canvas.draw_rect(Rect2(91, 53, 298, 121), Color("0c1022"))
	canvas.draw_rect(Rect2(91, 53, 298, 121), accent, false, 2)
	canvas.draw_rect(Rect2(91, 53, 298, 5), accent)
	_label(result_title, Vector2(139, 79), accent.lightened(0.2), 14)
	if result_loot > 0:
		_label("RECOVERED SALVAGE", Vector2(177, 103), Color("a7a5b2"), 7)
		canvas.draw_rect(Rect2(191, 112, 19, 19), Color(accent, 0.18))
		canvas.draw_rect(Rect2(195, 116, 11, 11), accent)
		_label("+" + str(result_loot), Vector2(218, 127), Color("f1c36f"), 16)
		_label("PRESS ENTER // RETURN TO BUNKER", Vector2(145, 153), Color("8bded7"), 7)
	else:
		_label("PRESS ENTER // RETURN TO MAP", Vector2(154, 137), Color("d67b83"), 7)


func _draw_minimap(accent: Color) -> void:
	# DFO-style compact room route in the upper-right.
	canvas.draw_rect(Rect2(382, 8, 88, 45), Color(0.025, 0.035, 0.075, 0.88))
	canvas.draw_rect(Rect2(382, 8, 88, 45), Color("455067"), false, 1)
	_label("MAP // " + str(room_index + 1) + "/" + str(room_count), Vector2(388, 19), Color("a7a9b5"), 6)
	var start_x := 394.0
	for i in range(room_count):
		var pos := Vector2(start_x + i * 25.0, 35)
		if i < room_count - 1:
			canvas.draw_line(pos + Vector2(6, 0), pos + Vector2(19, 0), Color("4c5367"), 2)
		var current := i == room_index
		canvas.draw_rect(Rect2(pos - Vector2(5, 5), Vector2(11, 11)), Color(accent, 0.35 if current else 0.08))
		canvas.draw_rect(Rect2(pos - Vector2(5, 5), Vector2(11, 11)), accent if current else Color("586071"), false, 1)
		if current:
			canvas.draw_rect(Rect2(pos - Vector2(2, 2), Vector2(5, 5)), accent)


func _draw_bottom_frame(accent: Color) -> void:
	# Layered chrome panel with accent hairlines, corner notches and dividers.
	canvas.draw_rect(Rect2(0, 224, 480, 46), Color(0.012, 0.016, 0.04, 0.97))
	canvas.draw_rect(Rect2(0, 224, 480, 3), Color(0.05, 0.06, 0.1))
	canvas.draw_rect(Rect2(0, 224, 480, 1), Color(accent, 0.72))
	canvas.draw_rect(Rect2(0, 267, 480, 3), Color(0.0, 0.0, 0.0, 0.45))
	for nx in [3, 471]:
		canvas.draw_rect(Rect2(nx, 228, 6, 1), Color(accent, 0.55))
		canvas.draw_rect(Rect2(nx if nx < 100 else nx + 5, 228, 1, 6), Color(accent, 0.55))
	for dx in [132, 296, 391]:
		canvas.draw_line(Vector2(dx, 230), Vector2(dx, 265), Color("343a4d"), 1)
	_draw_portrait(accent)
	_draw_status_bars(accent)
	_draw_skill_slots(accent)
	_draw_center_readout(accent)
	_draw_item_slots(accent)


func _draw_portrait(accent: Color) -> void:
	canvas.draw_rect(Rect2(5, 231, 30, 33), Color("0e1322"))
	canvas.draw_rect(Rect2(5, 231, 30, 3), Color(accent, 0.45))
	canvas.draw_rect(Rect2(5, 231, 30, 33), accent.darkened(0.2), false, 1)
	# Pixel portrait echoes the Warped City gunner (purple hair, yellow jacket).
	canvas.draw_rect(Rect2(12, 243, 15, 13), Color("e7b23b"))
	canvas.draw_rect(Rect2(11, 245, 3, 11), Color("c8902c"))
	canvas.draw_rect(Rect2(14, 239, 11, 8), Color("c5896a"))
	canvas.draw_rect(Rect2(12, 236, 14, 5), Color("7a3d9e"))
	canvas.draw_rect(Rect2(13, 236, 6, 3), Color("9a5cc0"))
	canvas.draw_rect(Rect2(20, 243, 4, 2), Color("2b2b3c"))
	canvas.draw_rect(Rect2(7, 256, 26, 7), Color("121a2c"))
	_label("07", Vector2(17, 262), Color("d4b477"), 6)


func _draw_status_bars(accent: Color) -> void:
	canvas.draw_rect(Rect2(40, 230, 33, 9), Color(accent, 0.16))
	canvas.draw_rect(Rect2(40, 230, 33, 9), Color(accent, 0.55), false, 1)
	_label("LV.07", Vector2(43, 237), accent.lightened(0.3), 6)
	_label("OPERATIVE", Vector2(78, 237), Color("8b8a98"), 6)
	_heart(Vector2(42, 244), Color("e6485f"))
	_bar(Rect2(50, 242, 74, 7), hp / 100.0, Color("e6485f"), str(roundi(hp)))
	_bolt(Vector2(43, 254), Color("4fc7d1"))
	_bar(Rect2(50, 253, 74, 7), energy / 100.0, Color("4fc7d1"), str(roundi(energy)))


func _heart(c: Vector2, col: Color) -> void:
	canvas.draw_rect(Rect2(c.x, c.y, 2, 2), col)
	canvas.draw_rect(Rect2(c.x + 3, c.y, 2, 2), col)
	canvas.draw_rect(Rect2(c.x, c.y + 1, 5, 2), col)
	canvas.draw_rect(Rect2(c.x + 1, c.y + 3, 3, 1), col)


func _bolt(c: Vector2, col: Color) -> void:
	canvas.draw_rect(Rect2(c.x + 2, c.y, 2, 3), col)
	canvas.draw_rect(Rect2(c.x, c.y + 2, 3, 2), col)
	canvas.draw_rect(Rect2(c.x + 1, c.y + 3, 2, 2), col)


func _draw_center_readout(accent: Color) -> void:
	_label("TARGETS", Vector2(302, 237), Color("8b8a98"), 6)
	if targets <= 0:
		_label("CLEAR", Vector2(348, 237), accent.lightened(0.3), 6)
	else:
		for i in range(mini(targets, 6)):
			var px := 348.0 + i * 7.0
			canvas.draw_rect(Rect2(px, 231, 5, 6), Color("e6485f"))
			canvas.draw_rect(Rect2(px, 231, 5, 6), Color("ff97a3"), false, 1)
	_label("SALVAGE", Vector2(302, 252), Color("8b8a98"), 6)
	canvas.draw_rect(Rect2(346, 247, 7, 7), Color("c79a3a"))
	canvas.draw_rect(Rect2(347, 248, 5, 5), Color("f1c36f"))
	_label(str(salvage), Vector2(357, 253), Color("f6dd8a"), 7)


func _bar(rect: Rect2, amount: float, color: Color, text: String) -> void:
	canvas.draw_rect(rect, Color("141828"))
	canvas.draw_rect(rect, Color("2a3047"), false, 1)
	var w := (rect.size.x - 2) * clampf(amount, 0.0, 1.0)
	canvas.draw_rect(Rect2(rect.position + Vector2(1, 1), Vector2(w, rect.size.y - 2)), color)
	canvas.draw_rect(Rect2(rect.position + Vector2(1, 1), Vector2(w, 1)), color.lightened(0.45))
	var tx := rect.position.x + 12.0
	while tx < rect.position.x + rect.size.x - 2.0:
		canvas.draw_rect(Rect2(tx, rect.position.y + 1, 1, rect.size.y - 2), Color(0, 0, 0, 0.32))
		tx += 12.0
	_label(text, rect.position + Vector2(rect.size.x - 15.0, 6), Color("f2edf0"), 5)


func _draw_skill_slots(accent: Color) -> void:
	for i in range(HOTKEYS.size()):
		var pos := Vector2(150 + i * 44, 233)
		var flash: float = skill_flash[i]
		canvas.draw_rect(Rect2(pos, Vector2(40, 30)), Color(accent, 0.1 + flash * 0.3))
		canvas.draw_rect(Rect2(pos, Vector2(40, 30)), accent.lightened(0.1 + flash * 0.4), false, 1)
		_draw_skill_icon(i, pos + Vector2(20, 12), accent, flash)
		canvas.draw_rect(Rect2(pos + Vector2(1, 1), Vector2(10, 9)), Color(0.02, 0.025, 0.06, 0.85))
		_label(HOTKEYS[i], pos + Vector2(3, 8), Color("d9d4dd"), 6)
		canvas.draw_rect(Rect2(pos + Vector2(0, 21), Vector2(40, 9)), Color(0.02, 0.025, 0.06, 0.82))
		_label(SKILL_NAMES[i], pos + Vector2(4, 28), accent.lightened(0.22), 5)


func _draw_skill_icon(index: int, center: Vector2, color: Color, flash: float) -> void:
	var bright := color.lightened(0.3 + flash * 0.35)
	match index:
		0:  # FIRE — bullet leaving the barrel
			canvas.draw_line(center + Vector2(-8, 0), center + Vector2(3, 0), bright, 2)
			canvas.draw_circle(center + Vector2(6, 0), 2.0, bright)
		1:  # SPREAD — three diverging shots
			for a in [-0.45, 0.0, 0.45]:
				canvas.draw_line(center + Vector2(-6, 0), center + Vector2(8, 0).rotated(a), bright, 1)
		2:  # DODGE — dash chevrons
			for dx in [-3.0, 2.0]:
				canvas.draw_line(center + Vector2(dx - 2, -4), center + Vector2(dx + 3, 0), bright, 2)
				canvas.draw_line(center + Vector2(dx + 3, 0), center + Vector2(dx - 2, 4), bright, 2)


func _draw_item_slots(accent: Color) -> void:
	for i in range(2):
		var pos := Vector2(399 + i * 34, 234)
		canvas.draw_rect(Rect2(pos, Vector2(29, 29)), Color(accent, 0.07))
		canvas.draw_rect(Rect2(pos, Vector2(29, 29)), Color("4a5164"), false, 1)
		if i == 0:
			canvas.draw_rect(Rect2(pos + Vector2(11, 6), Vector2(7, 14)), Color("9f3f58"))
			canvas.draw_rect(Rect2(pos + Vector2(12, 4), Vector2(5, 4)), Color("d8b16d"))
		else:
			canvas.draw_circle(pos + Vector2(14, 13), 6, Color("487f82"))
			canvas.draw_rect(Rect2(pos + Vector2(12, 4), Vector2(4, 5)), Color("b4b0a0"))
		_label("Q" if i == 0 else "E", pos + Vector2(3, 27), Color("d5d1d8"), 6)


func _label(text: String, pos: Vector2, color: Color, size := 8) -> void:
	canvas.draw_string(ThemeDB.fallback_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
