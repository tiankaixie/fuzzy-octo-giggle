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
const PostProcessClass := preload("res://scripts/post_process.gd")
const CITY_BG_PATH := "res://assets/backgrounds/city.png"
const CITY_DAY_PATH := "res://assets/backgrounds/city_day.png"
const WC_SKYLINE := "res://assets/warped_city/bg/skyline-b.png"
const WC_BUILDINGS := "res://assets/warped_city/bg/buildings-bg.png"
const WC_NEAR := "res://assets/warped_city/bg/near-buildings-bg.png"

var city_texture: Texture2D
var city_day_texture: Texture2D
var wc_skyline: Texture2D
var wc_buildings: Texture2D
var wc_near: Texture2D
var wc_props := {}
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
	if ResourceLoader.exists(WC_SKYLINE):
		wc_skyline = load(WC_SKYLINE)
	if ResourceLoader.exists(WC_BUILDINGS):
		wc_buildings = load(WC_BUILDINGS)
	if ResourceLoader.exists(WC_NEAR):
		wc_near = load(WC_NEAR)
	for prop_name in ["hotel-sign", "banner-big", "banner-neon", "banner-open", "banner-sushi", "banners", "control-box-1", "control-box-2", "antenna", "monitor-face"]:
		var pp: String = "res://assets/warped_city/props/" + str(prop_name) + ".png"
		if ResourceLoader.exists(pp):
			wc_props[prop_name] = load(pp)
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
	var post := PostProcessClass.new()
	add_child(post)
	post.configure(_post_preset())

	var cinematic := CinematicOverlayClass.new()
	add_child(cinematic)
	cinematic.configure(_cinematic_preset())

	battle_hud = BattleHUDClass.new()
	add_child(battle_hud)
	battle_hud.configure(stage_id, _room_count())
	_spawn_room_wave()


func _post_preset() -> Dictionary:
	# Lighter touch so the detailed skyline art reads clearly.
	match stage_id:
		"transit":
			return {"bloom_intensity": 0.85, "bloom_threshold": 0.56, "ca_amount": 0.0012, "contrast": 1.05, "saturation": 1.08, "grain": 0.022}
		"foundry":
			return {"bloom_intensity": 1.0, "bloom_threshold": 0.54, "ca_amount": 0.0013, "contrast": 1.06, "saturation": 1.1, "grain": 0.024}
		_:
			return {"bloom_intensity": 0.95, "bloom_threshold": 0.55, "ca_amount": 0.0013, "contrast": 1.05, "saturation": 1.12, "grain": 0.022}


func _cinematic_preset() -> Dictionary:
	match stage_id:
		"transit":
			return {"grade": Color(0.22, 0.42, 0.66, 0.06), "fog": Color(0.09, 0.16, 0.25), "fog_strength": 0.1, "particles": "rain", "count": 64, "vignette": 0.6}
		"foundry":
			return {"grade": Color(1.0, 0.42, 0.18, 0.07), "fog": Color(0.23, 0.11, 0.08), "fog_strength": 0.1, "particles": "embers", "count": 48, "vignette": 0.6}
		_:
			return {"grade": Color(0.88, 0.28, 0.6, 0.06), "fog": Color(0.2, 0.13, 0.26), "fog_strength": 0.08, "particles": "snow", "count": 44, "vignette": 0.6}


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
	_draw_city_props()
	match stage_id:
		"arcade": _draw_arcade()
		"transit": _draw_transit()
		"foundry": _draw_foundry()
		_: _draw_arcade()
	_draw_god_rays()
	_draw_room_variant()
	_draw_playfield()
	_draw_floor_reflection()
	_draw_room_navigation()
	_draw_atmosphere()


func _draw_city_props() -> void:
	# Lit neon signage hung in the mid-distance; bloom makes it glow. Builds the
	# layered "signs everywhere" depth of the reference street scenes.
	if wc_props.is_empty():
		return
	if stage_id == "arcade":
		var signs := [
			["banner-big", Vector2(112, 32)],
			["hotel-sign", Vector2(296, 40)],
			["banner-open", Vector2(86, 58)],
			["banner-neon", Vector2(250, 50)],
			["banners", Vector2(424, 38)],
			["banner-sushi", Vector2(350, 84)],
		]
		for s in signs:
			var tex = wc_props.get(s[0])
			if tex:
				draw_texture(tex, s[1], Color(1, 1, 1))
	# Wall tech on the side pillars for every stage.
	if wc_props.has("control-box-1"):
		draw_texture(wc_props["control-box-1"], Vector2(20, 96), Color(0.72, 0.74, 0.82))
	if wc_props.has("monitor-face"):
		draw_texture(wc_props["monitor-face"], Vector2(444, 104), Color(0.85, 0.85, 0.96))


func _stage_light() -> Color:
	match stage_id:
		"transit": return Color(0.4, 0.7, 0.95)
		"foundry": return Color(1.0, 0.55, 0.25)
		_: return Color(0.95, 0.4, 0.7)


func _draw_god_rays() -> void:
	# Volumetric light shafts slanting down from off-screen sources.
	var tint := _stage_light()
	for i in range(5):
		var x := 40.0 + i * 104.0 + sin(ambience_time * 0.3 + i) * 5.0
		var sway := sin(ambience_time * 0.5 + i * 1.3) * 0.06
		var a := 0.02 + 0.012 * sin(ambience_time * 0.8 + i * 2.0)
		draw_colored_polygon(PackedVector2Array([
			Vector2(x, 18), Vector2(x + 26, 18),
			Vector2(x - 36 + sway * 60.0, 168), Vector2(x - 70 + sway * 60.0, 168),
		]), Color(tint, maxf(0.0, a)))


func _draw_floor_reflection() -> void:
	# Wet-floor sheen + mirrored neon smear on the walkable plane.
	var tint := _stage_light()
	draw_rect(Rect2(0, 164, 480, 24), Color(tint, 0.04))
	for i in range(9):
		var x := 24.0 + i * 52.0 + sin(ambience_time * 0.6 + i) * 3.0
		var h := 22.0 + (i % 3) * 8.0
		draw_rect(Rect2(x, 168, 2, h), Color(tint, 0.05))
		draw_rect(Rect2(x, 168, 1, h * 0.6), Color(tint, 0.05))


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
	# High-fidelity cyberpunk skyline (ansimuz "Warped City", CC0) as a layered
	# parallax backdrop, tinted per stage mood.
	if wc_skyline:
		_draw_warped_skyline(day)
	elif city_texture:
		var tint := Color(0.54, 0.47, 0.64, 0.95)
		draw_texture_rect(city_texture, Rect2(0, 18, 480, 152), false, tint)
	# Smog band over the skyline for depth.
	draw_rect(Rect2(0, 120, 480, 50), Color(0.13, 0.08, 0.22, 0.14))


func _draw_warped_skyline(day: float) -> void:
	var base := Color(0.64, 0.62, 0.74)
	match stage_id:
		"transit": base = Color(0.44, 0.54, 0.66)
		"foundry": base = Color(0.64, 0.47, 0.42)
	var b := 0.72 + 0.34 * day
	var far := Color(base.r * b * 0.78, base.g * b * 0.78, base.b * b * 0.84)
	var mid := Color(base.r * b * 0.9, base.g * b * 0.9, base.b * b * 0.94)
	var near := Color(base.r * b, base.g * b, base.b * b)
	var floor_y := 172.0
	if wc_skyline:
		var sw := wc_skyline.get_width()
		for tx in range(0, 5):
			draw_texture(wc_skyline, Vector2(tx * sw, floor_y - wc_skyline.get_height()), far)
	if wc_buildings:
		var bw := wc_buildings.get_width()
		for tx in range(0, 5):
			draw_texture(wc_buildings, Vector2(tx * bw, floor_y - wc_buildings.get_height()), mid)
	if stage_id == "arcade" and wc_near:
		draw_texture(wc_near, Vector2(0, floor_y - wc_near.get_height()), near)


func _draw_playfield() -> void:
	# Wet cyberpunk street: dark asphalt that catches a neon sheen toward the
	# front, a shallow DNF-style depth lane, and ground decals in perspective.
	var tint := _stage_light()
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, 164), Vector2(480, 164), Vector2(480, 270), Vector2(0, 270)
	]), Color("0b1020"))
	for i in range(9):
		var t := float(i) / 8.0
		var y := 164.0 + t * 106.0
		draw_rect(Rect2(0, y, 480, 14), Color(tint.r, tint.g, tint.b, 0.012 + 0.04 * t))
	for y in [180, 200, 224, 250]:
		draw_line(Vector2(0, y), Vector2(480, y), Color(0.15, 0.18, 0.29, 0.4), 1)
	for x in range(-20, 520, 56):
		draw_line(Vector2(240 + (x - 240) * 0.45, 164), Vector2(x, 270), Color(0.12, 0.15, 0.26, 0.35), 1)
	draw_line(Vector2(0, 173), Vector2(480, 173), Color(0.25, 0.24, 0.37, 0.5), 2)
	draw_line(Vector2(0, 235), Vector2(480, 235), Color("080b17"), 3)
	_draw_ground_decals(tint)


func _draw_ground_decals(tint: Color) -> void:
	# Manhole covers (dark, ribbed) and neon-catching puddles set into the street.
	for mh in [Vector2(150, 250), Vector2(372, 242)]:
		draw_ellipse(mh, 15, 5.5, Color(0.2, 0.22, 0.3))
		draw_ellipse(mh, 13, 4.5, Color("0a0e1a"))
		for gx in range(-9, 10, 4):
			draw_line(mh + Vector2(gx, -3), mh + Vector2(gx, 3), Color(0.16, 0.18, 0.26, 0.7), 1)
	for pd in [Vector2(92, 256), Vector2(252, 261), Vector2(420, 251)]:
		draw_ellipse(pd, 24, 5, Color(tint.r, tint.g, tint.b, 0.06))
		draw_ellipse(pd, 15, 3, Color(tint.r, tint.g, tint.b, 0.1))
		draw_ellipse(pd, 7, 1.4, Color(1, 1, 1, 0.06))
	# Faded hazard paint and a couple of cracks for wear.
	for i in range(5):
		var hx := 404.0 + i * 11.0
		if i % 2 == 0:
			draw_colored_polygon(PackedVector2Array([
				Vector2(hx, 230), Vector2(hx + 7, 230), Vector2(hx + 1, 241), Vector2(hx - 6, 241)
			]), Color(0.85, 0.62, 0.22, 0.16))
	for c in [Vector2(205, 243), Vector2(312, 257)]:
		draw_line(c, c + Vector2(15, 4), Color(0, 0, 0, 0.32), 1)
		draw_line(c + Vector2(6, 2), c + Vector2(11, -3), Color(0, 0, 0, 0.26), 1)


func _draw_arcade() -> void:
	# The lit city buildings/signs now come from the Warped City backdrop; only
	# the street-level foreground props and navigation are drawn here.
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
	# Near-black foreground silhouettes at the edges frame the shot for depth.
	var silhouette := Color(0.04, 0.05, 0.09)
	if wc_props.has("antenna"):
		foreground.draw_texture(wc_props["antenna"], Vector2(0, 170), silhouette)
	if wc_props.has("control-box-1"):
		foreground.draw_texture(wc_props["control-box-1"], Vector2(452, 226), silhouette)


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
