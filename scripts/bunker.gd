extends Node2D

signal transition_requested(target: String)

const PlayerClass := preload("res://scripts/player.gd")
const RoomClass := preload("res://scripts/bunker_room.gd")

const COLS := 6
const ROWS := 3
const CELL_SIZE := Vector2(68, 58)
const GRID_ORIGIN := Vector2(48, 42)
const SAVE_PATH := "user://bunker_layout.json"
const BUILDABLE_TYPES := ["rest", "commons", "grow", "workshop", "power"]
const TYPE_LABELS := ["REST", "COMMON", "GROW", "RIG", "POWER"]
const TYPE_COLORS := [Color("e9a15f"), Color("f06f62"), Color("d75cb2"), Color("8062d1"), Color("55c9b8")]

var player: CyberPlayer
var layout: Array = []
var room_nodes: Array[Node] = []
var overlay: Node2D
var ambience_time := 0.0
var transition_sent := false
var build_mode := false
var selected_room := "rest"
var hover_cell := Vector2i(-1, -1)
var current_floor := 1
var floor_switching := false
var floor_input_latched := false
var status_text := ""
var status_until := 0.0


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("070812"))
	_load_layout()
	_rebuild_rooms()

	player = PlayerClass.new()
	player.setup(CyberPlayer.ViewMode.SIDE)
	player.position = Vector2(74, _floor_y(current_floor))
	add_child(player)

	overlay = Node2D.new()
	overlay.z_index = 100
	overlay.draw.connect(_draw_overlay)
	add_child(overlay)


func _process(delta: float) -> void:
	ambience_time += delta
	if not floor_switching:
		player.position.y = _floor_y(current_floor)
	player.position.x = clampf(player.position.x, 15.0, 466.0)
	player.z_index = 20

	var floor_input := Input.get_axis("move_up", "move_down")
	if absf(floor_input) < 0.1:
		floor_input_latched = false
	elif not build_mode and not floor_switching and not floor_input_latched and player.position.x < 50.0:
		floor_input_latched = true
		_switch_floor(signi(roundi(floor_input)))

	if current_floor == 0 and player.position.x > 459.0 and not transition_sent:
		transition_sent = true
		player.movement_enabled = false
		transition_requested.emit("map")

	queue_redraw()
	if is_instance_valid(overlay):
		overlay.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB:
			_set_build_mode(not build_mode)
			get_viewport().set_input_as_handled()
			return
		if build_mode:
			if event.keycode >= KEY_1 and event.keycode <= KEY_5:
				selected_room = BUILDABLE_TYPES[event.keycode - KEY_1]
				_show_status("BLUEPRINT // " + selected_room.to_upper())
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_R:
				_reset_layout()
				get_viewport().set_input_as_handled()

	if event is InputEventMouseMotion:
		hover_cell = _cell_at(event.position)
		if build_mode:
			get_viewport().set_input_as_handled()

	if event is InputEventMouseButton and event.pressed and build_mode:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var palette_index := _palette_index_at(event.position)
			if palette_index >= 0:
				selected_room = BUILDABLE_TYPES[palette_index]
				_show_status("BLUEPRINT // " + selected_room.to_upper())
			elif _valid_cell(hover_cell):
				place_room(hover_cell, selected_room)
		elif event.button_index == MOUSE_BUTTON_RIGHT and _valid_cell(hover_cell):
			remove_room(hover_cell)
		get_viewport().set_input_as_handled()


func place_room(cell: Vector2i, type: String, persist := true) -> bool:
	if not _valid_cell(cell) or type not in BUILDABLE_TYPES:
		return false
	if get_room(cell) == "airlock":
		_show_status("AIRLOCK IS STRUCTURAL")
		return false
	_set_room(cell, type)
	_rebuild_rooms()
	if persist:
		_save_layout()
	_show_status("BUILT // " + type.to_upper())
	return true


func remove_room(cell: Vector2i, persist := true) -> bool:
	if not _valid_cell(cell) or get_room(cell) == "" or get_room(cell) == "airlock":
		_show_status("NOTHING TO SALVAGE")
		return false
	_set_room(cell, "")
	_rebuild_rooms()
	if persist:
		_save_layout()
	_show_status("ROOM SALVAGED")
	return true


func get_room(cell: Vector2i) -> String:
	if not _valid_cell(cell):
		return ""
	return str(layout[cell.y * COLS + cell.x])


func rooms_are_merged(left_cell: Vector2i, right_cell: Vector2i) -> bool:
	return right_cell == left_cell + Vector2i.RIGHT and get_room(left_cell) != "" and get_room(left_cell) == get_room(right_cell)


func _set_room(cell: Vector2i, type: String) -> void:
	layout[cell.y * COLS + cell.x] = type


func _rebuild_rooms() -> void:
	for node in room_nodes:
		if is_instance_valid(node):
			remove_child(node)
			node.queue_free()
	room_nodes.clear()

	for row in range(ROWS):
		for col in range(COLS):
			var cell := Vector2i(col, row)
			var type := get_room(cell)
			if type == "":
				continue
			var room: BunkerRoom = RoomClass.new()
			var left_join := col > 0 and get_room(Vector2i(col - 1, row)) == type and type != "airlock"
			var right_join := col < COLS - 1 and get_room(Vector2i(col + 1, row)) == type and type != "airlock"
			room.position = GRID_ORIGIN + Vector2(col, row) * CELL_SIZE
			room.setup(type, left_join, right_join)
			room.z_index = 2
			add_child(room)
			room_nodes.append(room)


func _set_build_mode(enabled: bool) -> void:
	build_mode = enabled
	player.movement_enabled = not enabled
	_show_status("BUILD MODE // SELECT A ROOM" if enabled else "LAYOUT SAVED")


func _switch_floor(direction: int) -> void:
	var next_floor := clampi(current_floor + direction, 0, ROWS - 1)
	if next_floor == current_floor:
		return
	floor_switching = true
	player.movement_enabled = false
	current_floor = next_floor
	var tween := create_tween()
	tween.tween_property(player, "position:y", _floor_y(current_floor), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	floor_switching = false
	player.movement_enabled = true


func _floor_y(row: int) -> float:
	return GRID_ORIGIN.y + float(row) * CELL_SIZE.y + 54.0


func _cell_at(point: Vector2) -> Vector2i:
	var local := point - GRID_ORIGIN
	if local.x < 0.0 or local.y < 0.0:
		return Vector2i(-1, -1)
	var cell := Vector2i(floori(local.x / CELL_SIZE.x), floori(local.y / CELL_SIZE.y))
	return cell if _valid_cell(cell) else Vector2i(-1, -1)


func _valid_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < COLS and cell.y < ROWS


func _palette_index_at(point: Vector2) -> int:
	if point.y < 240.0 or point.y > 266.0 or point.x < 53.0:
		return -1
	var index := floori((point.x - 53.0) / 78.0)
	return index if index >= 0 and index < BUILDABLE_TYPES.size() else -1


func _default_layout() -> Array:
	return [
		"", "", "", "", "", "airlock",
		"commons", "rest", "rest", "grow", "", "",
		"power", "power", "workshop", "", "", "",
	]


func _load_layout() -> void:
	layout = _default_layout()
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Array and parsed.size() == COLS * ROWS:
		layout = parsed
		# The surface connection is fixed so a custom layout can never strand the player.
		layout[COLS - 1] = "airlock"


func _save_layout() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(layout))


func _reset_layout() -> void:
	layout = _default_layout()
	_rebuild_rooms()
	_save_layout()
	_show_status("DEFAULT LAYOUT RESTORED")


func _show_status(text: String) -> void:
	status_text = text
	status_until = ambience_time + 1.6


func _draw() -> void:
	draw_rect(Rect2(0, 0, 480, 270), Color("070812"))
	# Excavated earth and the concrete bunker shell.
	draw_rect(Rect2(0, 17, 480, 211), Color("121426"))
	for x in range(0, 480, 19):
		var y := 20 + ((x * 7) % 11)
		draw_rect(Rect2(x, y, 13, 3), Color("242039"))
	for y in range(38, 225, 19):
		draw_rect(Rect2(4, y, 16, 4), Color("201b32"))
		draw_rect(Rect2(458, y + 7, 19, 4), Color("201b32"))
	draw_rect(Rect2(8, 34, 464, 194), Color("292b3e"))
	draw_rect(Rect2(12, 38, 456, 186), Color("0b0e1b"))

	# Permanent lift shaft lets the player reach every expandable floor.
	draw_rect(Rect2(15, 42, 29, 174), Color("111827"))
	draw_rect(Rect2(19, 45, 21, 168), Color("263344"))
	draw_rect(Rect2(22, 48, 3, 162), Color("60707b"))
	draw_rect(Rect2(34, 48, 3, 162), Color("60707b"))
	for y in range(51, 209, 10):
		draw_rect(Rect2(23, y, 13, 2), Color("52626f"))
	for row in range(ROWS):
		var fy := GRID_ORIGIN.y + row * CELL_SIZE.y
		draw_rect(Rect2(12, fy + 54, 456, 4), Color("555269"))
		draw_rect(Rect2(17, fy + 55, 24, 2), Color("f0a158") if row == current_floor else Color("5c5366"))

	# Empty rock cells remain legible as buildable excavation sites.
	for row in range(ROWS):
		for col in range(COLS):
			if get_room(Vector2i(col, row)) != "":
				continue
			var cell_pos := GRID_ORIGIN + Vector2(col, row) * CELL_SIZE
			draw_rect(Rect2(cell_pos + Vector2(2, 3), CELL_SIZE - Vector2(4, 6)), Color("151527"))
			for n in range(4):
				var px := cell_pos.x + 8 + ((col * 17 + row * 23 + n * 13) % 49)
				var py := cell_pos.y + 11 + ((col * 7 + row * 11 + n * 9) % 36)
				draw_rect(Rect2(px, py, 7, 2), Color("26223a"))

	# Bunker identity is diegetic; only build mode adds an editing overlay.
	_label("BUNKER 07 // HABITAT GRID", Vector2(15, 31), Color("7a7187"), 7)
	var lift_hint := "W/S  CHANGE FLOOR" if player and player.position.x < 64.0 and not build_mode else ""
	if lift_hint != "":
		_label(lift_hint, Vector2(15, 235), Color("e6a466"), 7)


func _draw_overlay() -> void:
	if not build_mode:
		var pulse := 0.55 + sin(ambience_time * 2.2) * 0.18
		_label_on(overlay, "[TAB] DESIGN BUNKER", Vector2(345, 235), Color(0.48, 0.72, 0.76, pulse), 7)
		if ambience_time < status_until:
			_label_on(overlay, status_text, Vector2(15, 254), Color("e6a466"), 7)
		return

	# Blueprint tint, grid guides, hover preview and the compact room palette.
	overlay.draw_rect(Rect2(0, 0, 480, 270), Color(0.04, 0.1, 0.16, 0.14))
	for row in range(ROWS):
		for col in range(COLS):
			var pos := GRID_ORIGIN + Vector2(col, row) * CELL_SIZE
			overlay.draw_rect(Rect2(pos + Vector2(1, 2), CELL_SIZE - Vector2(2, 4)), Color(0.3, 0.75, 0.78, 0.18), false, 1)
	if _valid_cell(hover_cell):
		var hover_pos := GRID_ORIGIN + Vector2(hover_cell) * CELL_SIZE
		var selected_color: Color = TYPE_COLORS[BUILDABLE_TYPES.find(selected_room)]
		overlay.draw_rect(Rect2(hover_pos + Vector2(2, 3), CELL_SIZE - Vector2(4, 6)), Color(selected_color, 0.2))
		overlay.draw_rect(Rect2(hover_pos + Vector2(1, 2), CELL_SIZE - Vector2(2, 4)), selected_color, false, 2)

	overlay.draw_rect(Rect2(0, 232, 480, 38), Color("080b18"))
	overlay.draw_rect(Rect2(0, 232, 480, 2), Color("3c8390"))
	for i in range(BUILDABLE_TYPES.size()):
		var rect := Rect2(53 + i * 78, 240, 73, 22)
		var active: bool = BUILDABLE_TYPES[i] == selected_room
		overlay.draw_rect(rect, Color(TYPE_COLORS[i], 0.22 if active else 0.06))
		overlay.draw_rect(rect, TYPE_COLORS[i] if active else Color("3b4355"), false, 1)
		_label_on(overlay, str(i + 1) + " " + TYPE_LABELS[i], rect.position + Vector2(6, 14), TYPE_COLORS[i] if active else Color("7f8190"), 6)
	_label_on(overlay, "BUILD", Vector2(10, 253), Color("64d4d1"), 7)
	if ambience_time < status_until:
		_label_on(overlay, status_text, Vector2(317, 237), Color("eab06c"), 6)


func _label(text: String, pos: Vector2, color: Color, size := 8) -> void:
	draw_string(ThemeDB.fallback_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _label_on(canvas: CanvasItem, text: String, pos: Vector2, color: Color, size := 8) -> void:
	canvas.draw_string(ThemeDB.fallback_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
