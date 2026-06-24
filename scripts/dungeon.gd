extends Node2D

signal transition_requested(target: String)

const PlayerClass := preload("res://scripts/player.gd")
const BattleHUDClass := preload("res://scripts/battle_hud.gd")
const STAGE_DATA := {
	"arcade": {
		"name": "NEON MARKET",
		"rooms": ["MARKET GATE", "GAME HALL", "NEON CORE"],
		"codes": ["12-A1", "12-A2", "12-A3"],
	},
	"transit": {
		"name": "FLOODED LINE",
		"rooms": ["TICKET HALL", "FLOODED PLATFORM", "TRAIN WRECK"],
		"codes": ["12-B1", "12-B2", "12-B3"],
	},
	"foundry": {
		"name": "SIGNAL FOUNDRY",
		"rooms": ["LOADING BAY", "SIGNAL CORE", "ROOT CHAMBER"],
		"codes": ["12-C1", "12-C2", "12-C3"],
	},
}

var player: CyberPlayer
var foreground: Node2D
var transition_layer: CanvasLayer
var room_wipe: ColorRect
var battle_hud: BattleHUD
var stage_id := "arcade"
var room_index := 0
var ambience_time := 0.0
var room_transitioning := false
var transition_sent := false


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("050819"))
	player = PlayerClass.new()
	player.setup(CyberPlayer.ViewMode.BEAT_EM_UP)
	player.position = Vector2(78, 211)
	add_child(player)

	foreground = Node2D.new()
	foreground.z_index = 250
	foreground.draw.connect(_draw_foreground)
	add_child(foreground)
	_build_room_wipe()
	battle_hud = BattleHUDClass.new()
	add_child(battle_hud)
	battle_hud.configure(stage_id, _room_count())


func _process(delta: float) -> void:
	ambience_time += delta
	player.position.y = clampf(player.position.y, 174.0, 222.0)
	player.position.x = clampf(player.position.x, 8.0, 472.0)
	player.z_index = 20 + int(player.position.y)

	if not room_transitioning and not transition_sent:
		if player.position.x >= 468.0:
			if room_index < _room_count() - 1:
				_change_room(1)
			else:
				player.position.x = 462.0
		elif player.position.x <= 12.0:
			if room_index > 0:
				_change_room(-1)
			else:
				transition_sent = true
				player.movement_enabled = false
				transition_requested.emit("map")

	queue_redraw()
	foreground.queue_redraw()


func _build_room_wipe() -> void:
	transition_layer = CanvasLayer.new()
	transition_layer.layer = 80
	add_child(transition_layer)
	room_wipe = ColorRect.new()
	room_wipe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	room_wipe.color = Color(0.02, 0.03, 0.08, 0.0)
	room_wipe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition_layer.add_child(room_wipe)


func _room_count() -> int:
	var data: Dictionary = STAGE_DATA.get(stage_id, STAGE_DATA.arcade)
	return data.rooms.size()


func _change_room(direction: int) -> void:
	room_transitioning = true
	player.movement_enabled = false
	var fade_out := create_tween()
	fade_out.tween_property(room_wipe, "color:a", 0.93, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await fade_out.finished
	room_index += direction
	battle_hud.set_room(room_index)
	player.position = Vector2(25 if direction > 0 else 455, 211)
	queue_redraw()
	foreground.queue_redraw()
	var fade_in := create_tween()
	fade_in.tween_property(room_wipe, "color:a", 0.0, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await fade_in.finished
	player.movement_enabled = true
	room_transitioning = false


func _draw() -> void:
	_draw_sky_and_depth()
	match stage_id:
		"arcade": _draw_arcade()
		"transit": _draw_transit()
		"foundry": _draw_foundry()
		_: _draw_arcade()
	_draw_room_variant()
	_draw_playfield()
	_draw_room_navigation()
	_draw_atmosphere()


func _draw_room_variant() -> void:
	# Each selected dungeon contains a short room chain, with denser signal activity deeper in.
	if room_index == 1:
		for x in [172, 306]:
			draw_rect(Rect2(x, 72, 34, 11), Color("151b30"))
			draw_rect(Rect2(x + 4, 76, 20, 2), Color(0.45, 0.82, 0.78, 0.5))
	elif room_index == 2:
		var warning := Color("e86d70")
		for x in range(162, 322, 20):
			draw_colored_polygon(PackedVector2Array([
				Vector2(x, 158), Vector2(x + 9, 158), Vector2(x + 17, 166), Vector2(x + 8, 166)
			]), Color(warning, 0.38))
		var pulse := 0.55 + sin(ambience_time * 4.0) * 0.25
		_label("CORE SIGNAL DETECTED", Vector2(184, 158), Color(1.0, 0.48, 0.5, pulse), 6)


func _draw_sky_and_depth() -> void:
	draw_rect(Rect2(0, 0, 480, 270), Color("050819"))
	# Distant city silhouettes establish a side-on horizon.
	draw_rect(Rect2(0, 27, 480, 142), Color("081126"))
	for i in range(18):
		var width := 18 + (i * 11) % 24
		var height := 28 + (i * 19) % 68
		var x := i * 31 - 18
		draw_rect(Rect2(x, 169 - height, width, height), Color("0d1530"))
		if i % 3 != 0:
			draw_rect(Rect2(x + 5, 177 - height, 2, 3), Color(0.22, 0.53, 0.65, 0.23))
	# Smog bands and a broken magenta skyline glow.
	draw_rect(Rect2(0, 115, 480, 54), Color(0.13, 0.08, 0.22, 0.18))
	draw_line(Vector2(0, 168), Vector2(480, 168), Color("3d254c"), 2)


func _draw_playfield() -> void:
	# DNF-like perspective floor: movement is horizontal plus a shallow depth lane.
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, 164), Vector2(480, 164), Vector2(480, 270), Vector2(0, 270)
	]), Color("11172a"))
	for y in [178, 198, 221, 247]:
		draw_line(Vector2(0, y), Vector2(480, y), Color(0.14, 0.17, 0.28, 0.55), 1)
	for x in range(-20, 520, 48):
		draw_line(Vector2(240 + (x - 240) * 0.45, 164), Vector2(x, 270), Color(0.12, 0.15, 0.25, 0.5), 1)
	# Walkable depth band edges are indicated through wear rather than UI rails.
	draw_line(Vector2(0, 173), Vector2(480, 173), Color(0.25, 0.24, 0.37, 0.55), 2)
	draw_line(Vector2(0, 235), Vector2(480, 235), Color("080b17"), 3)


func _draw_arcade() -> void:
	# Abandoned shops and an inviting but optional route away from home.
	draw_rect(Rect2(29, 72, 127, 97), Color("18162c"))
	draw_rect(Rect2(36, 85, 113, 84), Color("241d38"))
	draw_rect(Rect2(45, 115, 42, 54), Color("0a1020"))
	draw_rect(Rect2(98, 104, 42, 65), Color("0a1020"))
	_neon_sign(Rect2(43, 91, 100, 17), "NOODLE//24", Color("e6549c"), 0.8)
	# Arcade cabinets emit small pools of cyan and violet.
	for x in [180, 211, 242]:
		draw_rect(Rect2(x, 126, 24, 43), Color("25263f"))
		draw_rect(Rect2(x + 4, 131, 16, 12), Color("0b1725"))
		draw_rect(Rect2(x + 6, 133, 12, 2), Color("4ecfc8") if x % 2 == 0 else Color("9c65dd"))
		draw_rect(Rect2(x + 8, 151, 8, 3), Color("c45d91"))
	# Surface hatch back to the bunker, visibly safe and always available.
	draw_rect(Rect2(0, 112, 25, 58), Color("122536"))
	draw_rect(Rect2(4, 119, 19, 50), Color("284252"))
	for y in range(123, 166, 9):
		draw_rect(Rect2(7, y, 13, 2), Color("55717c"))
	draw_rect(Rect2(19, 132, 4, 4), Color("55ddcd"))
	_label("MAP", Vector2(4, 106), Color("62d8d0"), 6)
	# Exit gate to the next dungeon room.
	_draw_side_gate(449, Color("d75a9f"), true)


func _draw_transit() -> void:
	# Massive tunnel arch and flooded platform.
	for i in range(7):
		var inset := i * 7
		draw_arc(Vector2(240, 172), 204 - inset, PI, TAU, 32, Color(0.16, 0.2, 0.31, 0.6 - i * 0.06), 3)
	draw_rect(Rect2(0, 133, 480, 37), Color("10192b"))
	for x in range(0, 480, 54):
		draw_rect(Rect2(x, 136, 38, 5), Color("2f3447"))
	# Dead train rests behind the movement lane.
	draw_rect(Rect2(91, 84, 294, 80), Color("17273a"))
	draw_rect(Rect2(98, 92, 280, 68), Color("26384b"))
	for x in range(110, 356, 48):
		draw_rect(Rect2(x, 101, 34, 28), Color("091629"))
		draw_rect(Rect2(x + 3, 104, 28, 3), Color(0.23, 0.65, 0.69, 0.35))
	draw_rect(Rect2(101, 145, 273, 5), Color("704454"))
	# Water along the rear lane, with reflections.
	draw_colored_polygon(PackedVector2Array([Vector2(36, 157), Vector2(443, 157), Vector2(472, 190), Vector2(10, 190)]), Color("0b2635"))
	for i in range(9):
		var px := 24 + i * 51 + sin(ambience_time + i) * 4.0
		draw_line(Vector2(px, 170 + i % 3 * 5), Vector2(px + 22, 170 + i % 3 * 5), Color(0.28, 0.75, 0.72, 0.28), 1)
	# Warning beacons.
	for x in [43, 431]:
		var on := fmod(ambience_time + x, 1.2) < 0.65
		_glow_circle(Vector2(x, 125), Color("f06d62"), 19)
		draw_rect(Rect2(x - 3, 121, 6, 7), Color("f06d62") if on else Color("5a333d"))
	_draw_side_gate(5, Color("8a65d0"), false)
	_draw_side_gate(449, Color("55d1c5"), true)
	_neon_sign(Rect2(184, 54, 112, 17), "PLATFORM NULL", Color("55d1c5"), 0.5)


func _draw_foundry() -> void:
	# Industrial final room built around a dormant signal core.
	for x in [38, 132, 332, 426]:
		draw_rect(Rect2(x, 43, 13, 126), Color("252a3d"))
		draw_rect(Rect2(x + 3, 47, 4, 116), Color("3b4052"))
	draw_rect(Rect2(0, 55, 480, 10), Color("24293d"))
	for x in range(12, 470, 37):
		draw_line(Vector2(x, 55), Vector2(x + 19, 65), Color("555265"), 2)
	# Central signal core.
	_glow_circle(Vector2(240, 124), Color("61e0ce"), 54)
	draw_circle(Vector2(240, 124), 31, Color("102a38"))
	draw_circle(Vector2(240, 124), 22, Color("1c4651"))
	draw_circle(Vector2(240, 124), 10 + sin(ambience_time * 2.0) * 2.0, Color(0.35, 0.91, 0.8, 0.36))
	draw_circle(Vector2(240, 124), 4, Color("8ffff0"))
	for angle in [0.0, PI * 0.5, PI, PI * 1.5]:
		var inner := Vector2(240, 124) + Vector2(cos(angle), sin(angle)) * 34.0
		var outer := Vector2(240, 124) + Vector2(cos(angle), sin(angle)) * 58.0
		draw_line(inner, outer, Color("4d596b"), 5)
	# Hoist crane and signal consoles.
	draw_rect(Rect2(84, 76, 7, 93), Color("4d4658"))
	draw_rect(Rect2(84, 76, 84, 6), Color("574c5d"))
	draw_line(Vector2(157, 82), Vector2(157, 125), Color("776270"), 2)
	draw_rect(Rect2(150, 124, 14, 7), Color("3a3447"))
	for x in [313, 349]:
		draw_rect(Rect2(x, 133, 29, 36), Color("263448"))
		draw_rect(Rect2(x + 5, 139, 19, 9), Color("0b1726"))
		draw_rect(Rect2(x + 7, 141, 15, 2), Color("e66d7b"))
	_draw_side_gate(5, Color("55d1c5"), false)
	if room_index < _room_count() - 1:
		_draw_side_gate(449, Color("ee7868"), true)
	else:
		# The next sector is visibly sealed; the player can return to the map.
		draw_rect(Rect2(451, 88, 29, 82), Color("1e2738"))
		for y in range(96, 164, 12):
			draw_rect(Rect2(456, y, 24, 4), Color("4d495a"))
		_label("SEALED", Vector2(442, 81), Color("e16b70"), 6)
	_neon_sign(Rect2(185, 30, 111, 17), "SIGNAL ROOT", Color("68dfce"), 0.7)


func _draw_side_gate(x: float, color: Color, points_right: bool) -> void:
	draw_rect(Rect2(x, 94, 26, 76), Color("111b2c"))
	draw_rect(Rect2(x + 4, 101, 18, 69), Color("263447"))
	for y in range(107, 166, 10):
		draw_rect(Rect2(x + 6, y, 14, 2), Color("536071"))
	draw_rect(Rect2(x + (3 if points_right else 19), 126, 4, 5), color)


func _draw_room_navigation() -> void:
	# Arrows are painted into the world, not HUD objectives.
	var pulse := 0.55 + sin(ambience_time * 4.0) * 0.24
	if room_index > 0:
		_label("‹", Vector2(13, 194), Color(0.45, 0.88, 0.84, pulse), 15)
	else:
		_label("‹ MAP", Vector2(8, 194), Color(0.45, 0.88, 0.84, pulse), 7)
	if room_index < _room_count() - 1:
		_label("›", Vector2(459, 194), Color(0.88, 0.45, 0.66, pulse), 15)
	# Small diegetic sector plate.
	draw_rect(Rect2(12, 13, 137, 18), Color(0.03, 0.05, 0.12, 0.82))
	draw_rect(Rect2(12, 30, 137, 2), Color("4c3c66"))
	var data: Dictionary = STAGE_DATA[stage_id]
	_label(str(data.codes[room_index]) + " // " + str(data.rooms[room_index]), Vector2(18, 25), Color("a7a3b8"), 7)


func _draw_atmosphere() -> void:
	for i in range(17):
		var x := fmod(float(i * 61) + ambience_time * (5.0 + i % 4), 500.0) - 10.0
		var y := 42.0 + float((i * 37) % 188)
		draw_line(Vector2(x, y), Vector2(x + 5, y - 1), Color(0.35, 0.39, 0.58, 0.17), 1)


func _draw_foreground() -> void:
	# Objects at the bottom edge occlude the player and reinforce belt-scroller depth.
	foreground.draw_rect(Rect2(0, 252, 480, 18), Color("070a15"))
	for x in range(0, 480, 34):
		foreground.draw_rect(Rect2(x, 253 + (x % 3), 22, 4), Color("26283b"))
	match stage_id:
		"arcade":
			_draw_barrel(Vector2(319, 239), Color("7a3e62"))
			_draw_barrel(Vector2(345, 246), Color("35676c"))
			foreground.draw_rect(Rect2(390, 232, 52, 8), Color("27283c"))
		"transit":
			foreground.draw_rect(Rect2(42, 238, 84, 9), Color("222b3c"))
			foreground.draw_line(Vector2(52, 238), Vector2(91, 222), Color("495266"), 4)
			foreground.draw_line(Vector2(91, 222), Vector2(119, 238), Color("495266"), 4)
		"foundry":
			_draw_barrel(Vector2(49, 242), Color("765d43"))
			_draw_barrel(Vector2(72, 247), Color("765d43"))
			foreground.draw_rect(Rect2(375, 235, 57, 10), Color("2d2d41"))


func _draw_barrel(pos: Vector2, color: Color) -> void:
	foreground.draw_rect(Rect2(pos - Vector2(8, 15), Vector2(16, 15)), color)
	foreground.draw_rect(Rect2(pos - Vector2(9, 13), Vector2(18, 3)), color.lightened(0.15))
	foreground.draw_rect(Rect2(pos - Vector2(9, 4), Vector2(18, 3)), color.darkened(0.2))


func _neon_sign(rect: Rect2, text: String, color: Color, flicker_offset: float) -> void:
	var alpha := 0.09 + sin(ambience_time * 2.5 + flicker_offset) * 0.025
	draw_rect(rect.grow(6), Color(color, alpha))
	draw_rect(rect, Color("101326"))
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 2)), color)
	_label(text, rect.position + Vector2(6, 12), color, 7)


func _glow_circle(center: Vector2, color: Color, radius: float) -> void:
	for i in range(5, 0, -1):
		var glow := color
		glow.a = 0.012 + float(5 - i) * 0.013
		draw_circle(center, radius * float(i) / 5.0, glow)


func _label(text: String, pos: Vector2, color: Color, size := 8) -> void:
	draw_string(ThemeDB.fallback_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
