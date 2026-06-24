extends Node2D

signal transition_requested(target: String)
signal stage_completed(stage_id: String, loot: int)

const PlayerClass := preload("res://scripts/combat/combat_player.gd")
const EnemyClass := preload("res://scripts/combat/combat_enemy.gd")
const ProjectileClass := preload("res://scripts/combat/combat_projectile.gd")
const CombatAudioClass := preload("res://scripts/combat/combat_audio.gd")
const BattleHUDClass := preload("res://scripts/battle_hud.gd")
const ContentRegistryClass := preload("res://scripts/data/content_registry.gd")
const CinematicOverlayClass := preload("res://scripts/cinematic_overlay.gd")
const CITY_BG_PATH := "res://assets/backgrounds/city.png"
const CITY_DAY_PATH := "res://assets/backgrounds/city_day.png"

var city_texture: Texture2D
var city_day_texture: Texture2D
var world_time := 0.0
var player: CombatPlayer
var foreground: Node2D
var transition_layer: CanvasLayer
var room_wipe: ColorRect
var battle_hud: BattleHUD
var stage_id := "arcade"
var stage_definition: StageDefinition
var combat_audio: CombatAudio
var combat_camera: Camera2D
var room_index := 0
var ambience_time := 0.0
var room_transitioning := false
var transition_sent := false
var cleared_rooms: Dictionary = {}
var remaining_enemies := 0
var total_loot := 0
var shake_strength := 0.0
var hitstop_generation := 0
var result_state := ""


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("050819"))
	if ResourceLoader.exists(CITY_BG_PATH):
		city_texture = load(CITY_BG_PATH)
	if ResourceLoader.exists(CITY_DAY_PATH):
		city_day_texture = load(CITY_DAY_PATH)
	stage_definition = ContentRegistryClass.stage(stage_id)
	player = PlayerClass.new()
	player.setup(CyberPlayer.ViewMode.BEAT_EM_UP)
	player.position = Vector2(78, 211)
	add_child(player)
	player.sfx_requested.connect(_play_sfx)
	player.impact_requested.connect(_on_impact)
	player.died.connect(_on_player_died)

	combat_audio = CombatAudioClass.new()
	add_child(combat_audio)
	combat_camera = Camera2D.new()
	combat_camera.position = Vector2(240, 135)
	combat_camera.enabled = true
	add_child(combat_camera)

	foreground = Node2D.new()
	foreground.z_index = 250
	foreground.draw.connect(_draw_foreground)
	add_child(foreground)
	_build_room_wipe()
	var cinematic := CinematicOverlayClass.new()
	add_child(cinematic)
	cinematic.configure(_cinematic_preset())

	battle_hud = BattleHUDClass.new()
	add_child(battle_hud)
	battle_hud.configure(stage_id, _room_count())
	_spawn_room_wave()


func _cinematic_preset() -> Dictionary:
	match stage_id:
		"transit":
			return {"grade": Color(0.22, 0.42, 0.66, 0.10), "fog": Color(0.09, 0.16, 0.25), "fog_strength": 0.16, "particles": "rain", "count": 70}
		"foundry":
			return {"grade": Color(1.0, 0.42, 0.18, 0.10), "fog": Color(0.23, 0.11, 0.08), "fog_strength": 0.15, "particles": "embers", "count": 52}
		_:
			return {"grade": Color(0.88, 0.28, 0.6, 0.1), "fog": Color(0.23, 0.14, 0.28), "fog_strength": 0.13, "particles": "snow", "count": 48}


func _process(delta: float) -> void:
	ambience_time += delta
	shake_strength = maxf(0.0, shake_strength - delta * 25.0)
	combat_camera.offset = Vector2(randf_range(-shake_strength, shake_strength), randf_range(-shake_strength * 0.55, shake_strength * 0.55)) if shake_strength > 0.1 else Vector2.ZERO
	player.position.y = clampf(player.position.y, 174.0, 222.0)
	player.position.x = clampf(player.position.x, 8.0, 472.0)
	player.z_index = 20 + int(player.position.y)

	battle_hud.set_stats(player.health, player.energy, player.combo_hits)
	if not room_transitioning and not transition_sent and result_state == "":
		if player.position.x >= 468.0:
			if not cleared_rooms.get(room_index, false):
				player.position.x = 462.0
			elif room_index < _room_count() - 1:
				_change_room(1)
			else:
				_complete_stage()
		elif player.position.x <= 12.0:
			if room_index > 0:
				_change_room(-1)
			else:
				transition_sent = true
				player.movement_enabled = false
				transition_requested.emit("map")

	queue_redraw()
	foreground.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ENTER:
		if result_state == "clear":
			stage_completed.emit(stage_id, total_loot + stage_definition.clear_bonus)
		elif result_state == "defeat":
			transition_requested.emit("map")


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
	return stage_definition.room_names.size()


func _change_room(direction: int) -> void:
	room_transitioning = true
	player.movement_enabled = false
	var fade_out := create_tween()
	fade_out.tween_property(room_wipe, "color:a", 0.93, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await fade_out.finished
	room_index += direction
	battle_hud.set_room(room_index)
	player.position = Vector2(25 if direction > 0 else 455, 211)
	_spawn_room_wave()
	queue_redraw()
	foreground.queue_redraw()
	var fade_in := create_tween()
	fade_in.tween_property(room_wipe, "color:a", 0.0, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await fade_in.finished
	player.movement_enabled = true
	room_transitioning = false


func _spawn_room_wave() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy):
			enemy.queue_free()
	remaining_enemies = 0
	if cleared_rooms.get(room_index, false):
		return
	var ids := stage_definition.room_waves[room_index].split(",", false)
	var positions := [Vector2(327, 205), Vector2(389, 184), Vector2(280, 218), Vector2(421, 214)]
	for i in range(ids.size()):
		var definition := ContentRegistryClass.enemy(ids[i].strip_edges())
		if definition == null:
			continue
		var enemy: CombatEnemy = EnemyClass.new()
		enemy.setup(definition, player, positions[i % positions.size()])
		enemy.defeated.connect(_on_enemy_defeated)
		enemy.projectile_requested.connect(_spawn_projectile)
		enemy.attack_connected.connect(_on_impact)
		enemy.sfx_requested.connect(_play_sfx)
		add_child(enemy)
		remaining_enemies += 1
	battle_hud.show_banner("HOSTILES // " + str(remaining_enemies), 0.9)


func _spawn_projectile(origin: Vector2, direction: Vector2, damage: float, knockback: float, color: Color) -> void:
	var projectile: CombatProjectile = ProjectileClass.new()
	projectile.setup(origin, direction, player, damage, knockback, color)
	add_child(projectile)


func _on_enemy_defeated(_enemy: CombatEnemy, loot: int) -> void:
	total_loot += loot
	remaining_enemies = maxi(0, remaining_enemies - 1)
	shake_strength = maxf(shake_strength, 7.0)
	if remaining_enemies == 0:
		cleared_rooms[room_index] = true
		battle_hud.show_banner("ROOM CLEAR", 1.5)
		_play_sfx("clear")
		_on_impact(8.0, 0.07)


func _complete_stage() -> void:
	if result_state != "":
		return
	result_state = "clear"
	player.movement_enabled = false
	player.velocity = Vector2.ZERO
	_play_sfx("clear")
	battle_hud.show_results("STAGE CLEAR", total_loot + stage_definition.clear_bonus)


func _on_player_died() -> void:
	result_state = "defeat"
	battle_hud.show_defeat()


func _play_sfx(id: String) -> void:
	combat_audio.play_sfx(id)


func _on_impact(strength: float, duration: float) -> void:
	shake_strength = maxf(shake_strength, strength)
	hitstop_generation += 1
	var generation := hitstop_generation
	Engine.time_scale = 0.08
	await get_tree().create_timer(duration, true, false, true).timeout
	if generation == hitstop_generation:
		Engine.time_scale = 1.0


func debug_clear_room() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy):
			enemy.take_damage(9999.0, player.position, 0.0)


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
	# Shared day/night clock so a stage matches the time you deployed at.
	var day := 0.5 + 0.5 * sin(world_time * 0.057)
	draw_rect(Rect2(0, 0, 480, 270), Color("050819").lerp(Color("2b3650"), day * 0.8))
	draw_rect(Rect2(0, 27, 480, 142), Color("081126").lerp(Color("303c58"), day * 0.7))
	# Distant city skyline (licensed CraftPix bg) tinted per stage mood, with the
	# night and day variants crossfading behind the stage's midground structures.
	if city_texture:
		var tint := Color(0.5, 0.45, 0.6, 0.85)
		match stage_id:
			"arcade": tint = Color(0.54, 0.47, 0.64, 0.95)
			"transit": tint = Color(0.34, 0.43, 0.5, 0.68)
			"foundry": tint = Color(0.52, 0.39, 0.4, 0.66)
		var dest := Rect2(0, 18, 480, 152)
		draw_texture_rect(city_texture, dest, false, tint)
		if city_day_texture and day > 0.01:
			draw_texture_rect(city_day_texture, dest, false, Color(0.95, 0.92, 0.88, tint.a * day))
	else:
		for i in range(18):
			var width := 18 + (i * 11) % 24
			var height := 28 + (i * 19) % 68
			var x := i * 31 - 18
			draw_rect(Rect2(x, 169 - height, width, height), Color("0d1530"))
	# Smog bands and a horizon line layered over the skyline for depth.
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
	elif cleared_rooms.get(room_index, false):
		_draw_side_gate(449, Color("68dfce"), true)
		_label("EXTRACT", Vector2(437, 81), Color("68dfce"), 6)
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
		if cleared_rooms.get(room_index, false):
			_label("›", Vector2(459, 194), Color(0.88, 0.45, 0.66, pulse), 15)
		else:
			draw_rect(Rect2(458, 171, 4, 53), Color(0.94, 0.33, 0.45, 0.42))
			_label("LOCK " + str(remaining_enemies), Vector2(431, 194), Color("ef6678"), 6)
	elif cleared_rooms.get(room_index, false):
		_label("EXTRACT ›", Vector2(425, 194), Color(0.45, 0.9, 0.82, pulse), 7)
	# Small diegetic sector plate.
	draw_rect(Rect2(12, 13, 137, 18), Color(0.03, 0.05, 0.12, 0.82))
	draw_rect(Rect2(12, 30, 137, 2), Color("4c3c66"))
	_label(stage_definition.room_codes[room_index] + " // " + stage_definition.room_names[room_index], Vector2(18, 25), Color("a7a3b8"), 7)


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
