extends Node2D

signal transition_requested(target: String)
signal salvage_changed(value: int)

const PlayerClass := preload("res://scripts/player.gd")
const RoomClass := preload("res://scripts/bunker_room.gd")
const ContentRegistryClass := preload("res://scripts/data/content_registry.gd")

const COLS := 6
const ROWS := 3
const CELL_SIZE := Vector2(68, 58)
const GRID_ORIGIN := Vector2(48, 42)
const SAVE_PATH := "user://bunker_layout.json"

var player: CyberPlayer
var layout: Array = []
var room_levels: Array = []
var room_definitions: Array = []
var buildable_types: Array[String] = []
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
var salvage := 160
var last_loot := 0


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("070812"))
	room_definitions = ContentRegistryClass.buildable_rooms()
	for definition: RoomDefinition in room_definitions:
		buildable_types.append(definition.id)
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
	if last_loot > 0:
		_show_status("EXPEDITION SALVAGE // +" + str(last_loot))


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
				selected_room = buildable_types[event.keycode - KEY_1]
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
				selected_room = buildable_types[palette_index]
				_show_status("BLUEPRINT // " + selected_room.to_upper())
			elif _valid_cell(hover_cell):
				place_room(hover_cell, selected_room)
		elif event.button_index == MOUSE_BUTTON_RIGHT and _valid_cell(hover_cell):
			remove_room(hover_cell)
		get_viewport().set_input_as_handled()


func place_room(cell: Vector2i, type: String, persist := true) -> bool:
	if not _valid_cell(cell) or type not in buildable_types:
		return false
	if get_room(cell) == "airlock":
		_show_status("AIRLOCK IS STRUCTURAL")
		return false
	if get_room(cell) == type:
		return upgrade_room(cell, persist)
	var definition := ContentRegistryClass.room(type)
	if persist and not _spend_salvage(definition.build_cost):
		_show_status("NEED " + str(definition.build_cost) + " SALVAGE")
		return false
	_set_room(cell, type)
	_set_room_level(cell, 1)
	_rebuild_rooms()
	if persist:
		_save_layout()
	_show_status("BUILT // " + definition.display_name.to_upper())
	return true


func upgrade_room(cell: Vector2i, persist := true) -> bool:
	var type := get_room(cell)
	var definition := ContentRegistryClass.room(type)
	if definition == null or type == "airlock":
		return false
	var level := get_room_level(cell)
	if level >= definition.max_level:
		_show_status("MAX LEVEL // " + definition.short_name)
		return false
	var cost := definition.upgrade_cost * level
	if persist and not _spend_salvage(cost):
		_show_status("UPGRADE NEEDS " + str(cost) + " SALVAGE")
		return false
	_set_room_level(cell, level + 1)
	_rebuild_rooms()
	if persist:
		_save_layout()
	_show_status("UPGRADED // " + definition.short_name + " LV." + str(level + 1))
	return true


func remove_room(cell: Vector2i, persist := true) -> bool:
	if not _valid_cell(cell) or get_room(cell) == "" or get_room(cell) == "airlock":
		_show_status("NOTHING TO SALVAGE")
		return false
	_set_room(cell, "")
	_set_room_level(cell, 0)
	_rebuild_rooms()
	if persist:
		_save_layout()
	_show_status("ROOM SALVAGED")
	return true


func get_room(cell: Vector2i) -> String:
	if not _valid_cell(cell):
		return ""
	return str(layout[cell.y * COLS + cell.x])


func get_room_level(cell: Vector2i) -> int:
	if not _valid_cell(cell):
		return 0
	return int(room_levels[cell.y * COLS + cell.x])


func rooms_are_merged(left_cell: Vector2i, right_cell: Vector2i) -> bool:
	return right_cell == left_cell + Vector2i.RIGHT and get_room(left_cell) != "" and get_room(left_cell) == get_room(right_cell)


func _set_room(cell: Vector2i, type: String) -> void:
	layout[cell.y * COLS + cell.x] = type


func _set_room_level(cell: Vector2i, level: int) -> void:
	room_levels[cell.y * COLS + cell.x] = level


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
			room.setup(type, left_join, right_join, get_room_level(cell))
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
	return index if index >= 0 and index < buildable_types.size() else -1


func _default_layout() -> Array:
	return [
		"", "", "", "", "", "airlock",
		"commons", "rest", "rest", "grow", "", "",
		"power", "power", "workshop", "", "", "",
	]


func _default_levels() -> Array:
	var levels: Array = []
	for type in _default_layout():
		levels.append(1 if type != "" else 0)
	return levels


func _load_layout() -> void:
	layout = _default_layout()
	room_levels = _default_levels()
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary and parsed.has("layout") and parsed.layout is Array and parsed.layout.size() == COLS * ROWS:
		layout = parsed.layout
		if parsed.has("levels") and parsed.levels is Array and parsed.levels.size() == COLS * ROWS:
			room_levels = parsed.levels
	elif parsed is Array and parsed.size() == COLS * ROWS:
		layout = parsed
	# The surface connection is fixed so a custom layout can never strand the player.
	layout[COLS - 1] = "airlock"
	room_levels[COLS - 1] = 1


func _save_layout() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"layout": layout, "levels": room_levels}))


func _reset_layout() -> void:
	layout = _default_layout()
	room_levels = _default_levels()
	_rebuild_rooms()
	_save_layout()
	_show_status("DEFAULT LAYOUT RESTORED")


func _spend_salvage(amount: int) -> bool:
	if salvage < amount:
		return false
	salvage -= amount
	salvage_changed.emit(salvage)
	return true


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

	# Empty cells read as raw excavated structure waiting to be built out:
	# recessed rock with exposed girders, conduit and rubble rather than a flat box.
	for row in range(ROWS):
		for col in range(COLS):
			if get_room(Vector2i(col, row)) != "":
				continue
			_draw_empty_cell(GRID_ORIGIN + Vector2(col, row) * CELL_SIZE, col, row)

	# Bunker identity is diegetic; only build mode adds an editing overlay.
	_label("BUNKER 07 // HABITAT GRID", Vector2(15, 31), Color("7a7187"), 7)
	_label("SALVAGE " + str(salvage), Vector2(393, 31), Color("e3b669"), 7)
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
		var selected_definition := ContentRegistryClass.room(selected_room)
		var selected_color: Color = selected_definition.accent_color
		overlay.draw_rect(Rect2(hover_pos + Vector2(2, 3), CELL_SIZE - Vector2(4, 6)), Color(selected_color, 0.2))
		overlay.draw_rect(Rect2(hover_pos + Vector2(1, 2), CELL_SIZE - Vector2(2, 4)), selected_color, false, 2)
		var current_type := get_room(hover_cell)
		if current_type != "" and current_type != "airlock":
			var current_definition := ContentRegistryClass.room(current_type)
			var current_level := get_room_level(hover_cell)
			var hint := "MAX" if current_level >= current_definition.max_level else "UP " + str(current_definition.upgrade_cost * current_level)
			_label_on(overlay, "LV." + str(current_level) + " // " + hint, hover_pos + Vector2(7, 49), current_definition.accent_color, 6)

	overlay.draw_rect(Rect2(0, 232, 480, 38), Color("080b18"))
	overlay.draw_rect(Rect2(0, 232, 480, 2), Color("3c8390"))
	for i in range(buildable_types.size()):
		var rect := Rect2(53 + i * 78, 240, 73, 22)
		var definition: RoomDefinition = room_definitions[i]
		var active: bool = definition.id == selected_room
		overlay.draw_rect(rect, Color(definition.accent_color, 0.22 if active else 0.06))
		overlay.draw_rect(rect, definition.accent_color if active else Color("3b4355"), false, 1)
		_label_on(overlay, str(i + 1) + " " + definition.short_name + " " + str(definition.build_cost), rect.position + Vector2(4, 14), definition.accent_color if active else Color("7f8190"), 5)
	_label_on(overlay, "BUILD", Vector2(10, 253), Color("64d4d1"), 7)
	_label_on(overlay, "¤ " + str(salvage), Vector2(427, 253), Color("e3b669"), 7)
	if ambience_time < status_until:
		_label_on(overlay, status_text, Vector2(317, 237), Color("eab06c"), 6)


func _draw_empty_cell(cell_pos: Vector2, col: int, row: int) -> void:
	var ox := cell_pos.x + 2.0
	var oy := cell_pos.y + 3.0
	# Recessed rock face with a soft top-down ambient gradient.
	draw_rect(Rect2(ox, oy, 64, 52), Color("0c1020"))
	draw_rect(Rect2(ox + 1, oy + 1, 62, 50), Color("12152a"))
	for i in range(7):
		draw_rect(Rect2(ox + 1, oy + 1 + i * 2, 62, 2), Color(0.0, 0.0, 0.0, 0.16 - i * 0.022))
	# Deterministic excavation speckle so the rock reads as textured, not flat.
	var seed := col * 31 + row * 17
	for n in range(11):
		var px := ox + 6.0 + float((seed + n * 23) % 50)
		var py := oy + 6.0 + float((seed * 3 + n * 13) % 40)
		var dark := (n % 3) == 0
		draw_rect(Rect2(px, py, 2, 2), Color("090b16") if dark else Color("1b1d34"))
	# Exposed structural girders and a conduit run across the bare site.
	draw_rect(Rect2(ox + 17, oy + 1, 3, 50), Color("1f2138"))
	draw_rect(Rect2(ox + 17, oy + 1, 1, 50), Color("2c2f4c"))
	draw_rect(Rect2(ox + 45, oy + 1, 3, 50), Color("1b1d31"))
	draw_rect(Rect2(ox + 4, oy + 12, 56, 2), Color("2a2c44"))
	draw_rect(Rect2(ox + 4, oy + 12, 56, 1), Color(0.5, 0.55, 0.7, 0.12))
	for bx in [12, 30, 50]:
		draw_rect(Rect2(ox + bx, oy + 11, 2, 4), Color("3a3d56"))
	# Loose rubble and a deeper shadow pooled on the floor.
	draw_rect(Rect2(ox, oy + 45, 64, 7), Color("080a14"))
	draw_rect(Rect2(ox, oy + 45, 64, 1), Color(1.0, 1.0, 1.0, 0.03))
	for rb in range(3):
		var rx := ox + 9.0 + float((seed + rb * 19) % 46)
		draw_rect(Rect2(rx, oy + 48, 4, 2), Color("141631"))
	# Corner ambient occlusion sinks the recess back.
	for corner in [Vector2(ox, oy), Vector2(ox + 60, oy), Vector2(ox, oy + 48), Vector2(ox + 60, oy + 48)]:
		for s in range(3):
			var cx: float = corner.x if corner.x < ox + 30 else corner.x + (4 - s)
			var cy: float = corner.y if corner.y < oy + 26 else corner.y + (4 - s)
			draw_rect(Rect2(cx, cy, 4 - s, 4 - s), Color(0.0, 0.0, 0.0, 0.12))


func _label(text: String, pos: Vector2, color: Color, size := 8) -> void:
	draw_string(ThemeDB.fallback_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _label_on(canvas: CanvasItem, text: String, pos: Vector2, color: Color, size := 8) -> void:
	canvas.draw_string(ThemeDB.fallback_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
