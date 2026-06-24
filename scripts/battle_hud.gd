class_name BattleHUD
extends CanvasLayer

const HOTKEYS := ["J", "K", "L", "U", "I", "O", "P", ";"]
const KEYCODES := [KEY_J, KEY_K, KEY_L, KEY_U, KEY_I, KEY_O, KEY_P, KEY_SEMICOLON]
const STAGE_NAMES := {
	"arcade": "NEON MARKET",
	"transit": "FLOODED LINE",
	"foundry": "SIGNAL FOUNDRY",
}
const STAGE_COLORS := {
	"arcade": Color("eb5aa2"),
	"transit": Color("58d6cc"),
	"foundry": Color("ee7868"),
}

var canvas: Node2D
var stage_id := "arcade"
var room_index := 0
var room_count := 3
var hp := 100.0
var energy := 76.0
var skill_flash := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var hud_time := 0.0


func _ready() -> void:
	layer = 60
	canvas = Node2D.new()
	canvas.draw.connect(_draw_hud)
	add_child(canvas)


func configure(id: String, rooms: int) -> void:
	stage_id = id
	room_count = rooms
	if is_instance_valid(canvas):
		canvas.queue_redraw()


func set_room(index: int) -> void:
	room_index = index
	if is_instance_valid(canvas):
		canvas.queue_redraw()


func _process(delta: float) -> void:
	hud_time += delta
	for i in range(skill_flash.size()):
		skill_flash[i] = maxf(0.0, skill_flash[i] - delta * 3.4)
	canvas.queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var slot := KEYCODES.find(event.keycode)
		if slot >= 0:
			skill_flash[slot] = 1.0
			energy = maxf(0.0, energy - (2.0 + slot * 0.7))


func _draw_hud() -> void:
	var accent: Color = STAGE_COLORS.get(stage_id, Color("58d6cc"))
	_draw_minimap(accent)
	_draw_bottom_frame(accent)


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
	# Black chrome frame and segmented lower action bar.
	canvas.draw_rect(Rect2(0, 226, 480, 44), Color(0.018, 0.022, 0.052, 0.96))
	canvas.draw_rect(Rect2(0, 226, 480, 2), Color(accent, 0.62))
	canvas.draw_line(Vector2(132, 231), Vector2(132, 268), Color("3a4053"), 1)
	canvas.draw_line(Vector2(391, 231), Vector2(391, 268), Color("3a4053"), 1)
	_draw_portrait(accent)
	_draw_status_bars(accent)
	_draw_skill_slots(accent)
	_draw_item_slots(accent)


func _draw_portrait(accent: Color) -> void:
	canvas.draw_rect(Rect2(5, 232, 29, 31), Color("151a2c"))
	canvas.draw_rect(Rect2(5, 232, 29, 31), accent.darkened(0.25), false, 1)
	# Pixel portrait echoes the playable character.
	canvas.draw_rect(Rect2(12, 240, 15, 16), Color("24344f"))
	canvas.draw_rect(Rect2(14, 238, 11, 9), Color("9d6766"))
	canvas.draw_rect(Rect2(13, 237, 12, 3), Color("354764"))
	canvas.draw_rect(Rect2(21, 242, 5, 2), Color("59e7d7"))
	canvas.draw_rect(Rect2(9, 254, 21, 7), Color("18243b"))
	_label("07", Vector2(19, 261), Color("d4b477"), 6)


func _draw_status_bars(accent: Color) -> void:
	_label("OPERATIVE // LV.07", Vector2(40, 237), Color("a9a7b3"), 6)
	_bar(Rect2(40, 241, 84, 7), hp / 100.0, Color("e45768"), "HP " + str(roundi(hp)))
	_bar(Rect2(40, 252, 84, 7), energy / 100.0, Color("4fc7d1"), "EN " + str(roundi(energy)))
	canvas.draw_rect(Rect2(40, 262, 84, 2), Color(accent, 0.22))
	canvas.draw_rect(Rect2(40, 262, 47, 2), accent)


func _bar(rect: Rect2, amount: float, color: Color, text: String) -> void:
	canvas.draw_rect(rect, Color("181c2d"))
	canvas.draw_rect(Rect2(rect.position + Vector2(1, 1), Vector2((rect.size.x - 2) * clampf(amount, 0.0, 1.0), rect.size.y - 2)), color)
	_label(text, rect.position + Vector2(3, 6), Color("f2edf0"), 5)


func _draw_skill_slots(accent: Color) -> void:
	for i in range(HOTKEYS.size()):
		var pos := Vector2(138 + i * 31, 233)
		var flash: float = skill_flash[i]
		var slot_color := accent if i < 4 else Color("8c68d2")
		canvas.draw_rect(Rect2(pos, Vector2(27, 30)), Color(slot_color, 0.11 + flash * 0.3))
		canvas.draw_rect(Rect2(pos, Vector2(27, 30)), slot_color.lightened(flash * 0.35), false, 1)
		_draw_skill_icon(i, pos + Vector2(13, 12), slot_color, flash)
		canvas.draw_rect(Rect2(pos + Vector2(1, 21), Vector2(25, 8)), Color(0.02, 0.025, 0.06, 0.82))
		_label(HOTKEYS[i], pos + Vector2(3, 28), Color("d9d4dd"), 6)
		if i in [2, 5, 7]:
			_label(str(i + 1), pos + Vector2(20, 28), Color("696e80"), 5)


func _draw_skill_icon(index: int, center: Vector2, color: Color, flash: float) -> void:
	var bright := color.lightened(0.28 + flash * 0.35)
	match index:
		0:
			canvas.draw_line(center - Vector2(7, 4), center + Vector2(7, 4), bright, 3)
			canvas.draw_line(center + Vector2(2, -6), center + Vector2(7, 4), bright, 2)
		1:
			canvas.draw_circle(center, 7, Color(color, 0.18))
			canvas.draw_arc(center, 6, -1.2, 2.1, 10, bright, 2)
		2:
			canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(-6, 6), center + Vector2(0, -7), center + Vector2(6, 6)]), Color(color, 0.55))
		3:
			canvas.draw_line(center + Vector2(-6, 0), center + Vector2(6, 0), bright, 3)
			canvas.draw_line(center + Vector2(0, -6), center + Vector2(0, 6), bright, 3)
		4:
			canvas.draw_circle(center, 6, Color(color, 0.35))
			canvas.draw_circle(center, 2, bright)
		5:
			for angle in [0.0, 2.1, 4.2]:
				canvas.draw_line(center, center + Vector2(cos(angle), sin(angle)) * 7.0, bright, 2)
		6:
			canvas.draw_rect(Rect2(center - Vector2(5, 6), Vector2(10, 12)), Color(color, 0.45))
			canvas.draw_rect(Rect2(center - Vector2(2, 3), Vector2(4, 6)), bright)
		7:
			canvas.draw_arc(center, 7, 0, TAU, 12, bright, 2)
			canvas.draw_line(center, center + Vector2(5, -5), bright, 2)


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
