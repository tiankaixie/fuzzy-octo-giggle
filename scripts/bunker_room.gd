class_name BunkerRoom
extends Node2D

const SIZE := Vector2(68, 58)
const ContentRegistryClass := preload("res://scripts/data/content_registry.gd")

var room_type := "rest"
var definition: RoomDefinition
var level := 1
var connected_left := false
var connected_right := false
var room_time := 0.0

func setup(type: String, joins_left: bool, joins_right: bool, room_level := 1) -> void:
	room_type = type
	definition = ContentRegistryClass.room(type)
	level = room_level
	connected_left = joins_left
	connected_right = joins_right
	queue_redraw()


func _process(delta: float) -> void:
	room_time += delta
	queue_redraw()


func _draw() -> void:
	var accent: Color = definition.accent_color if definition else Color.WHITE
	_draw_shell(accent)
	match room_type:
		"rest": _draw_rest(accent)
		"commons": _draw_commons(accent)
		"grow": _draw_grow(accent)
		"workshop": _draw_workshop(accent)
		"power": _draw_power(accent)
		"airlock": _draw_airlock(accent)


func _draw_shell(accent: Color) -> void:
	var glow := accent
	glow.a = 0.07
	draw_rect(Rect2(-2 if connected_left else 1, 1, 72 if connected_left and connected_right else 69 if connected_left or connected_right else 66, 55), glow)
	# Back wall base with a soft top-down ambient gradient for interior depth.
	draw_rect(Rect2(2, 3, 64, 52), Color("0e1326"))
	draw_rect(Rect2(3, 4, 62, 50), Color("151b32"))
	for i in range(7):
		draw_rect(Rect2(3, 4 + i * 2, 62, 2), Color(0.0, 0.0, 0.0, 0.17 - i * 0.024))
	draw_rect(Rect2(3, 4, 62, 50), Color(accent, 0.05))
	# Riveted wall panels read as a built structure rather than a flat box.
	for seam_y in [18, 31]:
		draw_rect(Rect2(4, seam_y, 60, 1), Color(0.0, 0.0, 0.0, 0.22))
		draw_rect(Rect2(4, seam_y + 1, 60, 1), Color(1.0, 1.0, 1.0, 0.03))
	for seam_x in [23, 45]:
		draw_rect(Rect2(seam_x, 5, 1, 39), Color(0.0, 0.0, 0.0, 0.12))
	for rx in [7, 28, 49, 61]:
		draw_rect(Rect2(rx, 14, 1, 1), Color(accent, 0.35))
		draw_rect(Rect2(rx, 27, 1, 1), Color(accent, 0.28))
	# Light pool spilling from the ceiling strip.
	draw_colored_polygon(PackedVector2Array([Vector2(7, 10), Vector2(29, 10), Vector2(36, 44), Vector2(0, 44)]), Color(accent, 0.045))
	# Recessed floor plate with lit leading edge and worn scuffs.
	draw_rect(Rect2(3, 45, 62, 9), Color("0b0f1f"))
	draw_rect(Rect2(3, 44, 62, 1), Color(accent, 0.22))
	draw_rect(Rect2(3, 45, 62, 1), Color(1.0, 1.0, 1.0, 0.045))
	for fx in range(8, 62, 13):
		draw_rect(Rect2(fx, 49, 7, 1), Color(1.0, 1.0, 1.0, 0.022))
	# Corner ambient occlusion deepens the recess.
	for corner in [Vector2(3, 4), Vector2(57, 4), Vector2(3, 47), Vector2(57, 47)]:
		for s in range(3):
			var ax: float = corner.x if corner.x < 30 else corner.x + (5 - s)
			var ay: float = corner.y if corner.y < 30 else corner.y + (5 - s)
			draw_rect(Rect2(ax, ay, 5 - s, 5 - s), Color(0.0, 0.0, 0.0, 0.10))
	draw_rect(Rect2(2, 3, 64, 3), Color(accent, 0.38))
	draw_rect(Rect2(2, 52, 64, 3), Color("3c3b51"))
	if connected_left:
		draw_rect(Rect2(-2, 6, 7, 46), Color("0e1326"))
		draw_rect(Rect2(-2, 6, 7, 2), Color(accent, 0.3))
	else:
		draw_rect(Rect2(1, 3, 3, 52), Color("4b485d"))
		draw_rect(Rect2(4, 4, 1, 50), Color(0.0, 0.0, 0.0, 0.22))
	if connected_right:
		draw_rect(Rect2(63, 6, 7, 46), Color("0e1326"))
		draw_rect(Rect2(63, 6, 7, 2), Color(accent, 0.3))
	else:
		draw_rect(Rect2(64, 3, 3, 52), Color("4b485d"))
		draw_rect(Rect2(63, 4, 1, 50), Color(0.0, 0.0, 0.0, 0.22))
	# Ceiling strip light with a brighter hot core; neighbors read as one room.
	draw_rect(Rect2(8, 8, 20, 2), Color(accent, 0.88))
	draw_rect(Rect2(10, 8, 14, 1), Color(1.0, 1.0, 1.0, 0.5))
	if connected_right:
		draw_rect(Rect2(31, 8, 35, 2), Color(accent, 0.5))
	if room_type != "airlock":
		for i in range(level):
			draw_rect(Rect2(59 - i * 5, 11, 3, 2), accent)


func _draw_rest(accent: Color) -> void:
	# Compact bunk, lamp, shelf and old-world photo.
	draw_rect(Rect2(8, 38, 45, 7), Color("743e59"))
	draw_rect(Rect2(10, 35, 41, 5), Color("b75b65"))
	draw_rect(Rect2(11, 35, 13, 4), Color("e8bc78"))
	draw_rect(Rect2(9, 45, 3, 7), Color("5b4350"))
	draw_rect(Rect2(49, 45, 3, 7), Color("5b4350"))
	draw_rect(Rect2(56, 29, 2, 17), Color("674750"))
	draw_colored_polygon(PackedVector2Array([Vector2(51, 30), Vector2(63, 30), Vector2(60, 24), Vector2(54, 24)]), accent)
	_glow(Vector2(57, 30), accent, 12)
	draw_rect(Rect2(12, 15, 11, 13), Color("3a2a42"))
	draw_rect(Rect2(14, 17, 7, 8), Color("9d6963"))
	_label("REST", Vector2(31, 21), accent, 6)


func _draw_commons(accent: Color) -> void:
	# Communal table, radio and hanging warm light.
	draw_rect(Rect2(20, 9, 2, 17), Color("634852"))
	draw_colored_polygon(PackedVector2Array([Vector2(14, 25), Vector2(29, 25), Vector2(26, 20), Vector2(17, 20)]), accent)
	_glow(Vector2(21, 25), accent, 13)
	draw_rect(Rect2(12, 39, 46, 4), Color("754951"))
	draw_rect(Rect2(16, 43, 3, 9), Color("4f3844"))
	draw_rect(Rect2(51, 43, 3, 9), Color("4f3844"))
	draw_rect(Rect2(41, 29, 17, 10), Color("30374b"))
	draw_rect(Rect2(43, 31, 9, 3), Color("11182a"))
	draw_rect(Rect2(44, 32, 5 + int(sin(room_time * 2.0) * 2.0), 1), accent)
	draw_circle(Vector2(55, 35), 2, Color("d39264"))
	_label("COMMON", Vector2(6, 17), accent, 6)


func _draw_grow(accent: Color) -> void:
	# Hydroponic trays visually repeat when rooms are expanded.
	for lx in [10, 36]:
		draw_rect(Rect2(lx, 13, 21, 2), Color("ff9de0"))
		var bloom := accent
		bloom.a = 0.09
		draw_rect(Rect2(lx - 2, 10, 25, 8), bloom)
	for bx in [8, 31]:
		draw_rect(Rect2(bx, 42, 21, 7), Color("41455b"))
		draw_rect(Rect2(bx + 2, 40, 17, 3), Color("734f76"))
		for px in [bx + 5, bx + 11, bx + 17]:
			draw_rect(Rect2(px, 29, 2, 12), Color("45926e"))
			draw_rect(Rect2(px - 3, 31, 4, 3), Color("68b973"))
			draw_rect(Rect2(px + 1, 27, 4, 3), Color("82c77a"))
	draw_rect(Rect2(57, 23, 6, 24), Color("286a71"))
	draw_rect(Rect2(59, 26, 2, 2), Color("75e3cd"))
	_label("GROW", Vector2(6, 23), accent, 6)


func _draw_workshop(accent: Color) -> void:
	# Pegboard, tools, bench and a cybernetic arm.
	draw_rect(Rect2(7, 14, 54, 21), Color("25223a"))
	for y in range(18, 33, 6):
		for x in range(11, 59, 7):
			draw_rect(Rect2(x, y, 1, 1), Color("615270"))
	draw_rect(Rect2(16, 19, 2, 13), Color("c47a6d"))
	draw_rect(Rect2(14, 19, 6, 3), Color("764b5c"))
	draw_rect(Rect2(32, 18, 2, 14), Color("66a5a0"))
	draw_circle(Vector2(33, 18), 3, Color("46586c"))
	draw_rect(Rect2(7, 41, 54, 5), Color("65404e"))
	draw_rect(Rect2(10, 46, 3, 6), Color("48343f"))
	draw_rect(Rect2(56, 46, 3, 6), Color("48343f"))
	draw_rect(Rect2(29, 37, 19, 3), Color("a9a7ab"))
	draw_rect(Rect2(46, 35, 8, 5), Color("e78762"))
	draw_rect(Rect2(31, 36, 2, 2), Color("59e7d7"))
	_label("RIG", Vector2(45, 12), accent, 6)


func _draw_power(accent: Color) -> void:
	# Quiet self-sufficient micro-reactor, not a survival countdown.
	draw_rect(Rect2(9, 16, 50, 34), Color("1c3040"))
	draw_rect(Rect2(14, 20, 20, 25), Color("284959"))
	for i in range(4):
		var y := 24 + i * 5
		draw_rect(Rect2(17, y, 14, 2), Color(accent, 0.45 + i * 0.08))
	draw_circle(Vector2(46, 32), 10, Color("152937"))
	draw_circle(Vector2(46, 32), 6, Color(accent, 0.18))
	draw_circle(Vector2(46, 32), 3, accent)
	var meter := 5 + int((sin(room_time * 1.4) + 1.0) * 3.0)
	draw_rect(Rect2(42, 47, meter, 2), accent)
	_label("POWER", Vector2(7, 13), accent, 6)


func _draw_airlock(accent: Color) -> void:
	draw_rect(Rect2(9, 13, 50, 39), Color("182637"))
	draw_rect(Rect2(16, 17, 36, 35), Color("26394a"))
	for y in range(21, 49, 8):
		draw_rect(Rect2(19, y, 30, 2), Color("405568"))
	for x in range(12, 58, 9):
		draw_colored_polygon(PackedVector2Array([Vector2(x, 48), Vector2(x + 4, 48), Vector2(x, 53), Vector2(x - 4, 53)]), Color("e99a57"))
	draw_rect(Rect2(55, 29, 5, 11), Color("283848"))
	draw_rect(Rect2(57, 31, 2, 2), accent)
	_label("SURFACE", Vector2(12, 11), accent, 6)


func _glow(center: Vector2, color: Color, radius: float) -> void:
	for i in range(3, 0, -1):
		var glow := color
		glow.a = 0.018 + float(3 - i) * 0.018
		draw_circle(center, radius * float(i) / 3.0, glow)


func _label(text: String, pos: Vector2, color: Color, size := 7) -> void:
	draw_string(ThemeDB.fallback_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
