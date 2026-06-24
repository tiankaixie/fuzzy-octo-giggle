extends Node2D

signal stage_selected(stage_id: String)
signal transition_requested(target: String)

const ContentRegistryClass := preload("res://scripts/data/content_registry.gd")
const CinematicOverlayClass := preload("res://scripts/cinematic_overlay.gd")

var stages: Array = []
var selected_index := 0
var hover_index := -1
var ambience_time := 0.0
var launching := false


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("050818"))
	stages = ContentRegistryClass.stages()
	var cinematic := CinematicOverlayClass.new()
	add_child(cinematic)
	cinematic.configure({"grade": Color(0.78, 0.36, 0.46, 0.06), "fog": Color(0.16, 0.16, 0.26), "fog_strength": 0.1, "particles": "snow", "count": 30, "vignette": 0.7, "letterbox": 12.0})


func _process(delta: float) -> void:
	ambience_time += delta
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if launching:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_LEFT, KEY_A, KEY_UP, KEY_W:
				select_index(selected_index - 1)
			KEY_RIGHT, KEY_D, KEY_DOWN, KEY_S:
				select_index(selected_index + 1)
			KEY_ENTER, KEY_SPACE:
				launch_selected()
			KEY_ESCAPE, KEY_BACKSPACE:
				return_home()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		hover_index = _stage_at(event.position)
		if hover_index >= 0:
			selected_index = hover_index
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var hit := _stage_at(event.position)
		if hit >= 0:
			selected_index = hit
			launch_selected()
		elif Rect2(372, 231, 94, 26).has_point(event.position):
			launch_selected()
		elif Rect2(14, 231, 78, 26).has_point(event.position):
			return_home()
		get_viewport().set_input_as_handled()


func select_index(index: int) -> void:
	selected_index = wrapi(index, 0, stages.size())


func select_stage(id: String) -> bool:
	for i in range(stages.size()):
		if stages[i].id == id:
			selected_index = i
			return true
	return false


func launch_selected() -> void:
	if launching:
		return
	launching = true
	stage_selected.emit(stages[selected_index].id)


func return_home() -> void:
	if launching:
		return
	launching = true
	transition_requested.emit("bunker")


func _stage_at(point: Vector2) -> int:
	for i in range(stages.size()):
		if point.distance_to(stages[i].map_position) < 28.0:
			return i
	return -1


func _draw() -> void:
	_draw_city_map()
	_draw_routes()
	_draw_stage_nodes()
	_draw_selection_panel()


func _draw_city_map() -> void:
	draw_rect(Rect2(0, 0, 480, 270), Color("050818"))
	# Satellite-like sector map with blocky terrain and scan lines.
	draw_rect(Rect2(0, 31, 480, 172), Color("081229"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, 72), Vector2(105, 44), Vector2(191, 59), Vector2(244, 39),
		Vector2(339, 60), Vector2(480, 42), Vector2(480, 203), Vector2(0, 203)
	]), Color("0b1730"))
	for x in range(8, 480, 29):
		for y in range(42, 198, 23):
			if (x + y) % 4 != 0:
				var shade := Color(0.08, 0.13, 0.24, 0.58)
				draw_rect(Rect2(x, y, 17 + (x % 3) * 4, 11 + (y % 2) * 4), shade)
	# Acid canal splits the old district.
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, 176), Vector2(86, 158), Vector2(163, 173), Vector2(237, 149),
		Vector2(327, 174), Vector2(401, 155), Vector2(480, 169), Vector2(480, 195),
		Vector2(398, 183), Vector2(326, 198), Vector2(238, 176), Vector2(160, 197),
		Vector2(83, 181), Vector2(0, 201)
	]), Color("092433"))
	for i in range(13):
		var x := i * 41 + sin(ambience_time + i) * 4.0
		draw_line(Vector2(x, 181 + i % 2 * 5), Vector2(x + 19, 181 + i % 2 * 5), Color(0.2, 0.69, 0.66, 0.2), 1)
	# Map scan sweep.
	var scan_y := 36.0 + fmod(ambience_time * 17.0, 162.0)
	draw_rect(Rect2(0, scan_y, 480, 2), Color(0.28, 0.74, 0.76, 0.035))
	draw_rect(Rect2(0, 0, 480, 32), Color("080b19"))
	_label("OUTER DISTRICT // EXPEDITION ROUTER", Vector2(15, 21), Color("a9a4b7"), 8)
	_label("CHOOSE A DUNGEON", Vector2(370, 21), Color("58c9c8"), 7)


func _draw_routes() -> void:
	# Routes are verified signal corridors rather than a linear obligation.
	var home := Vector2(28, 188)
	draw_polyline(PackedVector2Array([home, Vector2(70, 170), stages[0].map_position, Vector2(180, 129), stages[1].map_position, Vector2(310, 122), stages[2].map_position]), Color("34455f"), 3)
	draw_polyline(PackedVector2Array([home, Vector2(70, 170), stages[0].map_position, Vector2(180, 129), stages[1].map_position, Vector2(310, 122), stages[2].map_position]), Color(0.33, 0.83, 0.8, 0.18), 1)
	for p in [Vector2(70, 170), Vector2(180, 129), Vector2(310, 122)]:
		draw_circle(p, 3, Color("476178"))
	# Home marker.
	draw_circle(home, 11, Color("112d3b"))
	draw_rect(Rect2(home - Vector2(5, 5), Vector2(10, 10)), Color("55d4c9"))
	draw_rect(Rect2(home - Vector2(2, 8), Vector2(4, 16)), Color("081421"))
	_label("B-07", Vector2(12, 213), Color("5accc4"), 6)


func _draw_stage_nodes() -> void:
	for i in range(stages.size()):
		var stage: StageDefinition = stages[i]
		var pos: Vector2 = stage.map_position
		var color: Color = stage.accent_color
		var selected := i == selected_index
		var pulse := 0.55 + sin(ambience_time * 4.0 + i) * 0.2
		if selected:
			for radius in [28.0, 22.0, 17.0]:
				draw_circle(pos, radius, Color(color, 0.025 + (28.0 - radius) * 0.004))
			draw_arc(pos, 25, -PI * 0.5 + ambience_time, PI * 1.1 + ambience_time, 18, Color(color, pulse), 2)
		# Each node is a tiny landmark silhouette.
		draw_circle(pos, 14, Color("0a1020"))
		draw_circle(pos, 12, Color(color, 0.2 if selected else 0.1))
		match stage.id:
			"arcade":
				draw_rect(Rect2(pos - Vector2(8, 5), Vector2(16, 12)), Color("34223e"))
				draw_rect(Rect2(pos - Vector2(6, 3), Vector2(12, 3)), color)
			"transit":
				draw_rect(Rect2(pos - Vector2(9, 4), Vector2(18, 9)), Color("213647"))
				for wx in [-6, 0, 6]:
					draw_rect(Rect2(pos + Vector2(wx - 2, -2), Vector2(4, 3)), color)
			"foundry":
				draw_circle(pos, 8, Color("243745"))
				draw_circle(pos, 4, color)
				draw_line(pos + Vector2(0, -12), pos + Vector2(0, -7), color, 2)
		_label(stage.sector, pos + Vector2(-23, 25), color if selected else Color("697184"), 6)


func _draw_selection_panel() -> void:
	var stage: StageDefinition = stages[selected_index]
	var color: Color = stage.accent_color
	draw_rect(Rect2(0, 203, 480, 67), Color("080b17"))
	draw_rect(Rect2(0, 203, 480, 2), Color(color, 0.7))
	draw_rect(Rect2(103, 214, 252, 44), Color("101426"))
	draw_rect(Rect2(103, 214, 3, 44), color)
	_label(stage.display_name, Vector2(115, 230), color, 9)
	_label(stage.description, Vector2(115, 243), Color("8f91a3"), 6)
	_label("RISK " + stage.risk + "  //  " + stage.recommended_level, Vector2(115, 254), Color("c7a374"), 6)
	# Home and deploy buttons.
	_button(Rect2(14, 231, 78, 26), "‹ HOME", Color("58c9c8"), false)
	_button(Rect2(372, 231, 94, 26), "DEPLOY ›", color, true)
	_label("A/D SELECT   ENTER DEPLOY", Vector2(176, 267), Color("545a6c"), 6)


func _button(rect: Rect2, text: String, color: Color, active: bool) -> void:
	draw_rect(rect, Color(color, 0.16 if active else 0.07))
	draw_rect(rect, color if active else Color("405465"), false, 1)
	_label(text, rect.position + Vector2(12, 17), color, 7)


func _label(text: String, pos: Vector2, color: Color, size := 8) -> void:
	draw_string(ThemeDB.fallback_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
