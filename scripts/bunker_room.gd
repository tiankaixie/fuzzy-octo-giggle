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
var above_ground := false
var window_col := 0
var city_texture: Texture2D
var world_time := 0.0

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
	if above_ground and city_texture:
		_draw_city_window()
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
	# Bunk with a shaded blanket and pillow, a warm reading lamp and a framed photo.
	draw_rect(Rect2(8, 39, 45, 8), Color("351f2c"))
	draw_rect(Rect2(8, 38, 45, 7), Color("6e3a52"))
	draw_rect(Rect2(10, 34, 41, 6), Color("a8505f"))
	draw_rect(Rect2(10, 34, 41, 2), Color("c66b77"))
	draw_rect(Rect2(10, 39, 41, 1), Color("3a1f2a"))
	draw_rect(Rect2(11, 34, 14, 5), Color("e8c79a"))
	draw_rect(Rect2(11, 34, 14, 1), Color("f7e1c1"))
	draw_rect(Rect2(9, 45, 3, 7), Color("44313c"))
	draw_rect(Rect2(49, 45, 3, 7), Color("44313c"))
	draw_rect(Rect2(56, 29, 2, 17), Color("5a3d46"))
	draw_colored_polygon(PackedVector2Array([Vector2(51, 30), Vector2(63, 30), Vector2(60, 23), Vector2(54, 23)]), Color("d9b06a"))
	draw_rect(Rect2(54, 29, 6, 1), Color("ffd98a"))
	_glow(Vector2(57, 31), Color("ffcf7a"), 13)
	draw_rect(Rect2(12, 14, 12, 14), Color("281d31"))
	draw_rect(Rect2(13, 15, 10, 12), Color("46353e"))
	draw_rect(Rect2(14, 17, 8, 8), Color("9d6963"))
	draw_rect(Rect2(14, 17, 8, 2), Color(accent, 0.4))
	_label("REST", Vector2(31, 21), accent, 6)


func _draw_commons(accent: Color) -> void:
	# Communal table with a hanging warm lamp, a radio and a mug.
	draw_rect(Rect2(20, 9, 2, 16), Color("4a363f"))
	draw_colored_polygon(PackedVector2Array([Vector2(14, 25), Vector2(29, 25), Vector2(26, 19), Vector2(17, 19)]), Color("d9b06a"))
	draw_rect(Rect2(16, 24, 11, 1), Color("ffd98a"))
	_glow(Vector2(21, 26), Color("ffcf7a"), 14)
	draw_rect(Rect2(12, 38, 46, 2), Color("8a5860"))
	draw_rect(Rect2(12, 40, 46, 4), Color("5e3a44"))
	draw_rect(Rect2(16, 44, 3, 8), Color("3c2832"))
	draw_rect(Rect2(51, 44, 3, 8), Color("3c2832"))
	draw_rect(Rect2(24, 35, 4, 4), Color("9a8f86"))
	draw_rect(Rect2(28, 36, 1, 2), Color("9a8f86"))
	draw_rect(Rect2(41, 28, 17, 11), Color("2a3145"))
	draw_rect(Rect2(41, 28, 17, 1), Color("3e465e"))
	draw_rect(Rect2(43, 30, 9, 4), Color("0c1426"))
	draw_rect(Rect2(44, 31, 5 + int(sin(room_time * 2.0) * 2.0), 2), Color(accent, 0.9))
	draw_circle(Vector2(55, 35), 2, Color("d39264"))
	draw_circle(Vector2(55, 35), 1, Color("f0c79a"))
	_label("COMMON", Vector2(6, 17), accent, 6)


func _draw_grow(accent: Color) -> void:
	# Hydroponic trays under glowing grow lights, with a water glint.
	for lx in [10, 36]:
		var bloom := Color("ff9de0")
		bloom.a = 0.12
		draw_rect(Rect2(lx - 2, 9, 25, 9), bloom)
		draw_rect(Rect2(lx, 13, 21, 2), Color("ff9de0"))
		draw_rect(Rect2(lx, 13, 21, 1), Color("ffd0f0"))
	for bx in [8, 31]:
		draw_rect(Rect2(bx, 42, 21, 7), Color("363a4e"))
		draw_rect(Rect2(bx, 42, 21, 1), Color("4a4f66"))
		draw_rect(Rect2(bx + 2, 40, 17, 3), Color("5f4368"))
		draw_rect(Rect2(bx + 2, 40, 17, 1), Color("8a6a9a"))
		for px in [bx + 5, bx + 11, bx + 17]:
			draw_rect(Rect2(px, 29, 2, 12), Color("3c8a64"))
			draw_rect(Rect2(px - 3, 31, 4, 3), Color("68b973"))
			draw_rect(Rect2(px + 1, 27, 4, 3), Color("82c77a"))
			draw_rect(Rect2(px, 27, 1, 2), Color("a8e28e"))
	draw_rect(Rect2(57, 23, 6, 24), Color("286a71"))
	draw_rect(Rect2(57, 23, 6, 1), Color("3f8a90"))
	draw_rect(Rect2(59, 26, 2, 2), Color("75e3cd"))
	_label("GROW", Vector2(6, 23), accent, 6)


func _draw_workshop(accent: Color) -> void:
	# Pegboard with tools, a diagnostic screen, a workbench and a cyber arm.
	draw_rect(Rect2(7, 14, 54, 21), Color("221f34"))
	draw_rect(Rect2(7, 14, 54, 1), Color("332e48"))
	for y in range(18, 33, 6):
		for x in range(11, 42, 7):
			draw_rect(Rect2(x, y, 1, 1), Color("564a66"))
	draw_rect(Rect2(16, 19, 2, 13), Color("c47a6d"))
	draw_rect(Rect2(14, 19, 6, 3), Color("8a5867"))
	draw_rect(Rect2(32, 18, 2, 14), Color("66a5a0"))
	draw_circle(Vector2(33, 18), 3, Color("46586c"))
	draw_circle(Vector2(33, 18), 1.5, Color("0c1426"))
	draw_rect(Rect2(44, 17, 13, 11), Color("12202e"))
	draw_rect(Rect2(45, 18, 11, 9), Color("173b3a"))
	draw_rect(Rect2(46, 20, 9, 1), Color("59e7d7"))
	draw_rect(Rect2(46, 23, 6, 1), Color("3fae9e"))
	draw_rect(Rect2(7, 40, 54, 2), Color("8a5560"))
	draw_rect(Rect2(7, 42, 54, 5), Color("5e3a44"))
	draw_rect(Rect2(10, 47, 3, 5), Color("3c2832"))
	draw_rect(Rect2(56, 47, 3, 5), Color("3c2832"))
	draw_rect(Rect2(29, 37, 19, 3), Color("a9a7ab"))
	draw_rect(Rect2(29, 37, 19, 1), Color("d2d0d4"))
	draw_rect(Rect2(46, 35, 8, 5), Color("e78762"))
	draw_rect(Rect2(31, 36, 2, 2), Color("59e7d7"))
	_label("RIG", Vector2(45, 12), accent, 6)


func _draw_power(accent: Color) -> void:
	# Self-sufficient micro-reactor with a pulsing core and conduit panel.
	draw_rect(Rect2(9, 16, 50, 34), Color("16293a"))
	draw_rect(Rect2(9, 16, 50, 1), Color("23425a"))
	draw_rect(Rect2(14, 20, 20, 25), Color("21404f"))
	draw_rect(Rect2(14, 20, 20, 1), Color("335a6e"))
	for i in range(4):
		var y := 24 + i * 5
		draw_rect(Rect2(17, y, 14, 2), Color(accent, 0.45 + i * 0.08))
		draw_rect(Rect2(17, y, 14, 1), Color(accent, 0.85))
	var pulse := 0.5 + sin(room_time * 2.2) * 0.5
	for r in range(4, 0, -1):
		draw_circle(Vector2(46, 32), 8.0 + r * 2.0, Color(accent, 0.05 * pulse))
	draw_circle(Vector2(46, 32), 10, Color("12222e"))
	draw_circle(Vector2(46, 32), 6, Color(accent, 0.25))
	draw_circle(Vector2(46, 32), 3.0 + pulse * 1.5, accent)
	draw_circle(Vector2(46, 32), 1.5, Color("ffffff"))
	var meter := 5 + int((sin(room_time * 1.4) + 1.0) * 3.0)
	draw_rect(Rect2(42, 47, 12, 2), Color("0c1622"))
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


func _draw_city_window() -> void:
	# Above-ground rooms look out onto the skyline; the slice is offset per column
	# so the view reads as one continuous city across the top floor.
	var wx := 7.0
	var wy := 12.0
	var ww := 54.0
	var wh := 21.0
	var tw := float(city_texture.get_width())
	var th := float(city_texture.get_height())
	var src_x := clampf(20.0 + float(window_col) * 70.0, 0.0, tw - 150.0)
	var src := Rect2(src_x, th - 150.0, 150.0, 96.0)
	var dest := Rect2(wx, wy, ww, wh)
	var day := 0.5 + 0.5 * sin(world_time * 0.057)
	var b := 0.6 + 0.45 * day
	draw_texture_rect_region(city_texture, dest, src, Color(b * 0.95, b * 0.95, b))
	draw_rect(Rect2(wx, wy, ww, wh), Color(0.42, 0.6, 0.82, 0.05))
	draw_line(Vector2(wx + 4, wy + 3), Vector2(wx + 17, wy + wh - 2), Color(0.7, 0.8, 0.95, 0.06), 2)
	draw_rect(Rect2(wx + ww / 2.0 - 1.0, wy, 2, wh), Color("23263a"))
	draw_rect(Rect2(wx, wy + wh / 2.0 - 1.0, ww, 2), Color("23263a"))
	draw_rect(Rect2(wx, wy, ww, wh), Color("262a3e"), false, 2)
	draw_rect(Rect2(wx - 1, wy + wh, ww + 2, 3), Color("3a3d54"))
	draw_rect(Rect2(wx - 1, wy + wh, ww + 2, 1), Color("525873"))


func _glow(center: Vector2, color: Color, radius: float) -> void:
	for i in range(3, 0, -1):
		var glow := color
		glow.a = 0.018 + float(3 - i) * 0.018
		draw_circle(center, radius * float(i) / 3.0, glow)


func _label(text: String, pos: Vector2, color: Color, size := 7) -> void:
	draw_string(ThemeDB.fallback_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
