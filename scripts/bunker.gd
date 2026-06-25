extends Node2D

signal transition_requested(target: String)
signal salvage_changed(value: int)
signal siege_resolved(won: bool)

const PlayerClass := preload("res://scripts/player.gd")
const RoomClass := preload("res://scripts/bunker_room.gd")
const ContentRegistryClass := preload("res://scripts/data/content_registry.gd")
const CinematicOverlayClass := preload("res://scripts/cinematic_overlay.gd")
const PostProcessClass := preload("res://scripts/post_process.gd")
const CombatPlayerClass := preload("res://scripts/combat/combat_player.gd")
const CombatEnemyClass := preload("res://scripts/combat/combat_enemy.gd")
const CombatProjectileClass := preload("res://scripts/combat/combat_projectile.gd")
const CombatFXClass := preload("res://scripts/combat/combat_fx.gd")

const COLS := 6
const ROWS := 3
const CELL_SIZE := Vector2(68, 58)
const GRID_ORIGIN := Vector2(48, 42)
const SAVE_PATH := "user://bunker_layout.json"
# The top floor sits above ground; everything below GROUND_Y is buried. Row 0
# cells become windows onto the city skyline (licensed CraftPix bg, OGA-BY 3.0).
const GROUND_Y := 100.0
const WC_NEAR := "res://assets/warped_city/bg/near-buildings-bg.png"
const WC_SKYLINE := "res://assets/warped_city/bg/skyline-b.png"
# User-authored cutaway art (own asset): the surface fortress + skyline band.
const SURFACE_BG := "res://assets/bunker/scene/surface.png"
const CUTAWAY_BG := "res://assets/bunker/scene/cutaway_full.png"

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
var city_texture: Texture2D
var wc_skyline: Texture2D
var surface_bg: Texture2D
var cutaway_bg: Texture2D
var world_time := 0.0
var loadout := {}

# --- Siege (tower-defense) state ---
var start_in_siege := false
var siege_active := false
var siege_ended := false
var siege_tier := 1
var siege_fx: Node2D
var siege_wave := 0
var siege_total_waves := 3
var siege_to_spawn := 0
var siege_alive := 0
var siege_spawn_timer := 0.0
var siege_lull := 0.0
var siege_prep := false
var siege_prep_time := 0.0
var turret_cooldowns := {}


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("070812"))
	if ResourceLoader.exists(WC_NEAR):
		city_texture = load(WC_NEAR)
	if ResourceLoader.exists(WC_SKYLINE):
		wc_skyline = load(WC_SKYLINE)
	if ResourceLoader.exists(SURFACE_BG):
		surface_bg = load(SURFACE_BG)
	if ResourceLoader.exists(CUTAWAY_BG):
		cutaway_bg = load(CUTAWAY_BG)
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

	var post := PostProcessClass.new()
	add_child(post)
	post.configure({"bloom_intensity": 0.7, "bloom_threshold": 0.56, "ca_amount": 0.0012, "contrast": 1.06, "saturation": 1.08, "grain": 0.04})

	var cinematic := CinematicOverlayClass.new()
	add_child(cinematic)
	cinematic.configure({"grade": Color(0.92, 0.56, 0.3, 0.05), "fog": Color(0.16, 0.13, 0.2), "fog_strength": 0.09, "particles": "dust", "count": 36, "vignette": 0.8, "letterbox": 12.0})

	if last_loot > 0:
		_show_status("EXPEDITION SALVAGE // +" + str(last_loot))

	if start_in_siege:
		call_deferred("start_siege", siege_tier)


func _process(delta: float) -> void:
	ambience_time += delta
	for room in room_nodes:
		if is_instance_valid(room) and room.above_ground:
			room.world_time = world_time
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

	if siege_active:
		if siege_prep:
			siege_prep_time -= delta
			if siege_prep_time <= 0.0:
				_begin_live_siege()
		else:
			_siege_process(delta)
			_update_turrets(delta)
	elif current_floor == 0 and player.position.x > 459.0 and not transition_sent:
		transition_sent = true
		player.movement_enabled = false
		transition_requested.emit("map")

	queue_redraw()
	if is_instance_valid(overlay):
		overlay.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if siege_active and not siege_prep:
		return  # No build/blueprint input during a live siege.
	if siege_prep and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ENTER:
		siege_prep_time = 0.0  # Skip the rest of the fortify window and attack now.
		get_viewport().set_input_as_handled()
		return
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


# Combat loadout derived from the built rooms (summed per cell, scaled by level),
# so building and upgrading the base directly powers up the next expedition.
func compute_loadout() -> Dictionary:
	var lo := {"bonus_hp": 0.0, "bonus_energy": 0.0, "energy_regen": 0.0, "hp_regen": 0.0, "damage_mult": 1.0, "loot_mult": 1.0}
	for row in range(ROWS):
		for col in range(COLS):
			var cell := Vector2i(col, row)
			var type := get_room(cell)
			if type == "" or type == "airlock":
				continue
			var lvl := float(get_room_level(cell))
			match type:
				"rest": lo.bonus_hp += 16.0 * lvl
				"power":
					lo.bonus_energy += 12.0 * lvl
					lo.energy_regen += 1.1 * lvl
				"grow": lo.hp_regen += 1.4 * lvl
				"workshop": lo.damage_mult += 0.12 * lvl
				"commons": lo.loot_mult += 0.12 * lvl
	return lo


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
			room.city_texture = city_texture
			room.above_ground = row == 0 and type != "airlock"
			room.window_col = col
			room.setup(type, left_join, right_join, get_room_level(cell))
			room.z_index = 2
			room.visible = cutaway_bg == null  # cutaway art supplies the room interiors
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


# ----------------------------------------------------------------------------
# Siege mode (tower defense): zombies breach the surface entrance and grind down
# the shaft toward the reactor core. The built rooms arm the gunner via the
# loadout; lose the core or the gunner and the run is wiped (permadeath).
# ----------------------------------------------------------------------------
func start_siege(tier := 1) -> void:
	if siege_active:
		return
	siege_active = true
	siege_ended = false
	siege_prep = true
	siege_prep_time = 18.0
	siege_tier = maxi(1, tier)
	transition_sent = true  # block the airlock exit for the duration
	turret_cooldowns = {}
	siege_fx = CombatFXClass.new()
	add_child(siege_fx)
	siege_wave = 0
	siege_total_waves = 3
	siege_alive = 0
	siege_to_spawn = 0
	siege_lull = 0.8
	_show_status("SIEGE IMMINENT // FORTIFY  [ENTER] BEGIN")


# After the fortify window, swap in the gunner and let the waves loose.
func _begin_live_siege() -> void:
	siege_prep = false
	build_mode = false
	current_floor = 0
	if is_instance_valid(player):
		player.queue_free()
	var cp: CombatPlayer = CombatPlayerClass.new()
	cp.setup(CyberPlayer.ViewMode.SIDE)
	cp.position = Vector2(240, _floor_y(0))
	add_child(cp)
	cp.apply_loadout(compute_loadout())
	cp.shoot_requested.connect(_on_siege_player_shot)
	cp.died.connect(_on_siege_player_died)
	player = cp
	_show_status("SIEGE // DEFEND THE REACTOR")


func _begin_next_wave() -> void:
	siege_wave += 1
	if siege_wave > siege_total_waves:
		_win_siege()
		return
	siege_to_spawn = 2 + siege_wave + siege_tier
	siege_spawn_timer = 0.0
	_show_status("WAVE %d / %d" % [siege_wave, siege_total_waves])


func _siege_process(delta: float) -> void:
	if siege_ended:
		return
	if siege_to_spawn > 0:
		siege_spawn_timer -= delta
		if siege_spawn_timer <= 0.0:
			_spawn_siege_zombie()
			siege_to_spawn -= 1
			siege_spawn_timer = 0.9
	elif siege_alive <= 0:
		siege_lull -= delta
		if siege_lull <= 0.0:
			siege_lull = 1.6
			_begin_next_wave()


func _spawn_siege_zombie() -> void:
	var ids := ["melee"]
	if siege_wave >= 2:
		ids.append("ranged")
	if siege_wave >= 3:
		ids.append("elite")
	var id: String = ids[siege_alive % ids.size()]
	var base: EnemyDefinition = ContentRegistryClass.enemy(id)
	if base == null:
		return
	# Reskin the licensed enemy art to a sickly-green zombie tint (no new assets).
	var def: EnemyDefinition = base.duplicate()
	def.body_color = Color(0.42, 0.72, 0.38)
	def.glow_color = Color(0.55, 0.95, 0.45)
	var z: CombatEnemy = CombatEnemyClass.new()
	z.setup(def, player, Vector2(456, _floor_y(0)))
	z.siege = true
	z.siege_player = player
	z.siege_floor_ys = [_floor_y(0), _floor_y(1), _floor_y(2)]
	z.siege_shaft_x = 30.0
	z.defeated.connect(_on_siege_zombie_defeated)
	z.projectile_requested.connect(_on_siege_enemy_projectile)
	add_child(z)
	siege_alive += 1


func _on_siege_player_shot(origin: Vector2, direction: Vector2, damage: float, knockback: float) -> void:
	var shot: CombatProjectile = CombatProjectileClass.new()
	shot.setup(origin, direction, null, damage, knockback, Color(1.0, 0.86, 0.5), true)
	shot.struck.connect(_on_siege_shot_hit)
	add_child(shot)


func _on_siege_shot_hit(pos: Vector2, amount: int, _tint: Color) -> void:
	if is_instance_valid(siege_fx):
		siege_fx.hit(pos, amount, Color(1.0, 0.95, 0.6))


func _on_siege_enemy_projectile(origin: Vector2, direction: Vector2, damage: float, knockback: float, color: Color) -> void:
	var p: CombatProjectile = CombatProjectileClass.new()
	p.setup(origin, direction, player, damage, knockback, color)
	add_child(p)


# Built rooms double as automated defenses during a siege: the habitat you build
# IS the fortress's firepower. WORKSHOP auto-fires, POWER arcs, GROW repairs.
func _update_turrets(delta: float) -> void:
	for row in range(ROWS):
		for col in range(COLS):
			var type := get_room(Vector2i(col, row))
			if type != "workshop" and type != "power" and type != "grow":
				continue
			var key := row * COLS + col
			var cd := float(turret_cooldowns.get(key, 0.0)) - delta
			if cd > 0.0:
				turret_cooldowns[key] = cd
				continue
			var lvl := float(get_room_level(Vector2i(col, row)))
			var center := GRID_ORIGIN + Vector2(col, row) * CELL_SIZE + Vector2(CELL_SIZE.x * 0.5, 0.0)
			var fy := _floor_y(row)
			match type:
				"workshop":
					var tgt = _nearest_zombie_on_floor(fy, center.x)
					if tgt != null:
						var muzzle := Vector2(center.x, fy - 12.0)
						var dir: Vector2 = (tgt.position + Vector2(0, -12) - muzzle).normalized()
						_spawn_turret_shot(muzzle, dir, 9.0 + 3.0 * lvl, 18.0)
						turret_cooldowns[key] = 1.2 / (1.0 + 0.18 * lvl)
					else:
						turret_cooldowns[key] = 0.3
				"power":
					var tgt2 = _nearest_zombie_on_floor(fy, center.x)
					if tgt2 != null and absf(tgt2.position.x - center.x) < 78.0:
						var hit_pos: Vector2 = tgt2.position + Vector2(0, -12)
						if tgt2.take_damage(10.0 + 4.0 * lvl, center, 10.0) and is_instance_valid(siege_fx):
							siege_fx.hit(hit_pos, int(10.0 + 4.0 * lvl), Color(0.5, 0.85, 1.0))
						turret_cooldowns[key] = 1.7 / (1.0 + 0.12 * lvl)
					else:
						turret_cooldowns[key] = 0.35
				"grow":
					if is_instance_valid(player) and "health" in player and player.health > 0.0:
						player.health = minf(player.max_health, player.health + (3.0 + 2.0 * lvl))
						player.health_changed.emit(player.health, player.max_health)
					turret_cooldowns[key] = 1.0


func _nearest_zombie_on_floor(floor_y: float, from_x: float):
	var best = null
	var best_d := 9999.0
	for z in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(z) or z.dead:
			continue
		if absf(z.position.y - floor_y) > 32.0:
			continue
		var d := absf(z.position.x - from_x)
		if d < best_d:
			best_d = d
			best = z
	return best


func _spawn_turret_shot(origin: Vector2, direction: Vector2, damage: float, knockback: float) -> void:
	var shot: CombatProjectile = CombatProjectileClass.new()
	shot.setup(origin, direction, null, damage, knockback, Color(0.55, 0.95, 0.55), true)
	shot.struck.connect(_on_siege_shot_hit)
	add_child(shot)


func _on_siege_zombie_defeated(enemy, _loot: int) -> void:
	siege_alive = maxi(0, siege_alive - 1)
	if is_instance_valid(siege_fx) and is_instance_valid(enemy) and enemy.definition:
		siege_fx.burst(enemy.position + Vector2(0, -16), enemy.definition.glow_color)


func _on_siege_player_died() -> void:
	_lose_siege()


func _win_siege() -> void:
	if siege_ended:
		return
	siege_ended = true
	siege_active = false
	var reward := 35 + 25 * siege_tier
	salvage += reward
	salvage_changed.emit(salvage)
	_end_siege_cleanup()
	siege_resolved.emit(true)
	_show_status("BUNKER HELD // +%d SALVAGE" % reward)


func _lose_siege() -> void:
	if siege_ended:
		return
	siege_ended = true
	siege_active = false
	_show_status("BUNKER OVERRUN")
	transition_requested.emit("overrun")


func _end_siege_cleanup() -> void:
	for z in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(z):
			z.queue_free()
	for child in get_children():
		if child is CombatProjectile:
			child.queue_free()
	if is_instance_valid(siege_fx):
		siege_fx.queue_free()
	siege_fx = null
	if is_instance_valid(player):
		player.queue_free()
	var np: CyberPlayer = PlayerClass.new()
	np.setup(CyberPlayer.ViewMode.SIDE)
	np.position = Vector2(74, _floor_y(current_floor))
	add_child(np)
	player = np
	transition_sent = false
	start_in_siege = false
	siege_prep = false


func _draw_siege_hud() -> void:
	# Vertical focus: dim floors with no active threat that aren't the player's.
	for f in range(ROWS):
		var has_zombie := false
		for z in get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(z) and absf(z.position.y - _floor_y(f)) < 30.0:
				has_zombie = true
				break
		if not has_zombie and f != current_floor:
			overlay.draw_rect(Rect2(0, _floor_y(f) - 46, 480, 60), Color(0.02, 0.02, 0.06, 0.4))
	# Top siege banner.
	var pulse := 0.6 + sin(ambience_time * 6.0) * 0.4
	overlay.draw_rect(Rect2(150, 6, 184, 16), Color(0.08, 0.02, 0.04, 0.72))
	overlay.draw_rect(Rect2(150, 6, 3, 16), Color(1.0, 0.3, 0.3, pulse))
	_label_on(overlay, "SIEGE  //  WAVE %d / %d  —  SURVIVE" % [siege_wave, siege_total_waves], Vector2(160, 18), Color("ff8a7a"), 8)
	# Player vitals (bottom-left) and threat counter.
	var hp := 1.0
	var hpmax := 1.0
	var en := 0.0
	var enmax := 1.0
	if is_instance_valid(player) and "health" in player:
		hp = player.health
		hpmax = maxf(1.0, player.max_health)
		en = player.energy
		enmax = maxf(1.0, player.max_energy)
	_siege_bar(Rect2(14, 246, 92, 6), hp / hpmax, Color("e6485f"), "HP")
	_siege_bar(Rect2(14, 255, 92, 6), en / enmax, Color("4fc7d1"), "EN")
	_label_on(overlay, "THREAT " + str(siege_alive + siege_to_spawn), Vector2(360, 254), Color("9bd66a"), 7)
	if ambience_time < status_until:
		_label_on(overlay, status_text, Vector2(150, 254), Color("ff9a6a"), 7)


func _siege_bar(rect: Rect2, ratio: float, color: Color, tag: String) -> void:
	overlay.draw_rect(rect, Color("0a0d16"))
	overlay.draw_rect(Rect2(rect.position, Vector2(rect.size.x * clampf(ratio, 0.0, 1.0), rect.size.y)), color)
	overlay.draw_rect(rect, Color("39435f"), false, 1)
	_label_on(overlay, tag, rect.position + Vector2(-12, 6), color, 5)


func _draw() -> void:
	# --- Full cutaway backdrop: user-authored cross-section art ---
	var day := _day_factor()
	if cutaway_bg:
		var tint := 0.86 + 0.2 * day
		draw_texture_rect(cutaway_bg, Rect2(0, 0, 480, 270), false, Color(tint, tint, tint))
	else:
		draw_rect(Rect2(0, 0, 480, 270), Color("0b0f22"))

	# Subtle current-floor indicator on the left rail.
	for row in range(ROWS):
		var fy := GRID_ORIGIN.y + float(row) * CELL_SIZE.y
		if row == current_floor:
			draw_rect(Rect2(5, fy + 48, 5, 12), Color(0.94, 0.63, 0.34, 0.9))

	# Bunker identity, on small plates so it reads over the sky.
	_draw_plate_label(Vector2(74, 15), "BUNKER 07 // HABITAT GRID", Color("9aa6c0"))
	_draw_plate_label(Vector2(393, 15), "SALVAGE " + str(salvage), Color("e3b669"))
	_draw_loadout_readout()
	var lift_hint := "W/S  CHANGE FLOOR" if player and player.position.x < 64.0 and not build_mode else ""
	if lift_hint != "":
		_label(lift_hint, Vector2(50, 235), Color("e6a466"), 7)


func _day_factor() -> float:
	# Slow day/night cycle (~110s period) on the shared world clock; 0=night, 1=day.
	return 0.5 + 0.5 * sin(world_time * 0.057)


func _draw_surface_entrance() -> void:
	# The single fortified ingress on the surface: a hardened bunker cap over the
	# lift with a heavy blast door — narratively the only way the dead get in.
	var ex := 10.0
	# Concrete apron the cap sits on.
	draw_rect(Rect2(ex - 4, 31, 64, 5), Color("221f2d"))
	draw_rect(Rect2(ex - 4, 31, 64, 1), Color("3a3550"))
	# Hardened cap shell.
	draw_rect(Rect2(ex - 2, 9, 58, 25), Color("1c1f30"))
	draw_rect(Rect2(ex - 2, 9, 58, 3), Color("3b4059"))
	draw_rect(Rect2(ex - 2, 9, 2, 25), Color("2c3146"))
	draw_rect(Rect2(ex + 54, 9, 2, 25), Color("2c3146"))
	# Bulkhead lintel with hazard chevrons.
	for i in range(7):
		draw_rect(Rect2(ex + i * 8, 11, 5, 3), Color("e0a24a") if i % 2 == 0 else Color("16161f"))
	# Recessed twin blast door with bolts and a glowing vision slit.
	draw_rect(Rect2(ex + 13, 16, 24, 18), Color("0c1018"))
	draw_rect(Rect2(ex + 13, 16, 24, 18), Color("394157"), false, 1)
	draw_rect(Rect2(ex + 24, 16, 2, 18), Color("232a3c"))
	for bx in [ex + 15, ex + 33]:
		for by in [18, 31]:
			draw_rect(Rect2(bx, by, 2, 2), Color("4a5168"))
	draw_rect(Rect2(ex + 17, 21, 16, 2), Color("55ddcd"))
	# Mast + alarm beacon — red and fast while a siege is imminent or live.
	var alarm := siege_active or start_in_siege
	draw_line(Vector2(ex + 48, 9), Vector2(ex + 48, 2), Color("4a5060"), 1)
	var period := 0.5 if alarm else 1.4
	var on := fmod(ambience_time, period) < period * 0.5
	var beacon := Color("ff3030") if alarm else Color("ff5a52")
	if on:
		_glow_at(Vector2(ex + 48, 2), beacon, 5.0)
	draw_circle(Vector2(ex + 48, 2), 2.0, beacon if on else Color("4a2526"))
	_label("ENTRY", Vector2(ex + 2, 8), Color("8fb0bf"), 5)


func _draw_rooftop_props() -> void:
	# Hardware sitting on the roof slab (y~34), silhouetted against the skyline.
	# Satellite dish.
	draw_rect(Rect2(168, 30, 4, 5), Color("33384e"))
	draw_circle(Vector2(170, 26), 6.0, Color("2a2f44"))
	draw_circle(Vector2(170, 26), 5.0, Color("3c4259"))
	draw_line(Vector2(170, 26), Vector2(174, 21), Color("596184"), 1)
	draw_circle(Vector2(174, 21), 1.0, Color("8fb0bf"))
	# Vent / AC box.
	draw_rect(Rect2(246, 24, 22, 11), Color("262a3c"))
	draw_rect(Rect2(246, 24, 22, 2), Color("3a3f57"))
	for vx in range(249, 266, 4):
		draw_rect(Rect2(vx, 28, 2, 5), Color("12151f"))
	# Antenna mast cluster with a blinking tip.
	draw_rect(Rect2(330, 18, 2, 17), Color("4a5066"))
	draw_line(Vector2(331, 22), Vector2(324, 18), Color("3c4156"), 1)
	draw_line(Vector2(331, 22), Vector2(338, 18), Color("3c4156"), 1)
	var blink := fmod(ambience_time, 1.6) < 0.8
	draw_circle(Vector2(331, 17), 1.5, Color("6ad6ff") if blink else Color("294452"))
	# Comms pylon on the far right.
	draw_rect(Rect2(430, 22, 2, 13), Color("434860"))
	draw_rect(Rect2(426, 22, 10, 2), Color("363b51"))


func _draw_window_cell(cell_pos: Vector2) -> void:
	# A reinforced window onto the skyline (the city is already drawn behind).
	var ox := cell_pos.x + 2.0
	var oy := cell_pos.y + 3.0
	draw_rect(Rect2(ox, oy, 64, 52), Color(0.42, 0.6, 0.82, 0.05))
	draw_line(Vector2(ox + 6, oy + 4), Vector2(ox + 22, oy + 34), Color(0.65, 0.78, 0.92, 0.05), 2)
	draw_rect(Rect2(ox + 31, oy, 2, 52), Color("23263a"))
	draw_rect(Rect2(ox, oy + 25, 64, 2), Color("23263a"))
	draw_rect(Rect2(ox, oy, 64, 52), Color("2a2d40"), false, 2)
	draw_rect(Rect2(ox - 1, oy + 50, 66, 4), Color("3a3d54"))
	draw_rect(Rect2(ox - 1, oy + 50, 66, 1), Color("525873"))


func _glow_at(center: Vector2, color: Color, radius: float) -> void:
	for i in range(3, 0, -1):
		draw_circle(center, radius * float(i) / 3.0, Color(color, 0.05 * (4 - i)))


# Reads the bunker as two distinct zones: an exposed surface and a buried
# fortress that hardens (darker, thicker walls) the deeper it goes.
func _draw_depth_structure() -> void:
	var day := _day_factor()
	# Ground seam: a heavy hazard bulkhead clamping the surface onto the fortress.
	draw_rect(Rect2(8, GROUND_Y - 4, 464, 11), Color("241f2e"))
	draw_rect(Rect2(8, GROUND_Y - 4, 464, 2), Color("6b5a6f").lerp(Color("8a7f95"), day))
	for cx in range(10, 470, 14):
		var amber := ((cx / 14) % 2) == 0
		draw_rect(Rect2(cx, GROUND_Y - 1, 12, 5), Color("c8902f") if amber else Color("16151f"))
	draw_rect(Rect2(8, GROUND_Y + 6, 464, 1), Color(0, 0, 0, 0.5))

	# Left armored spine + right rib, thickening on each deeper sublevel.
	for row in range(1, ROWS):
		var fy := GRID_ORIGIN.y + float(row) * CELL_SIZE.y
		var w := 6.0 + float(row) * 2.0
		draw_rect(Rect2(0, fy, w, CELL_SIZE.y), Color("13111d"))
		draw_rect(Rect2(w - 1.0, fy, 1, CELL_SIZE.y), Color("2c2740"))
		for ry in range(int(fy) + 6, int(fy + CELL_SIZE.y), 12):
			draw_rect(Rect2(2, ry, 2, 2), Color("3a3550"))
		var w2 := 4.0 + float(row) * 2.0
		draw_rect(Rect2(480.0 - w2, fy, w2, CELL_SIZE.y), Color("13111d"))
		draw_rect(Rect2(480.0 - w2, fy, 1, CELL_SIZE.y), Color("2c2740"))

	# Depth darkening: deeper sublevels read more enclosed.
	for row in range(1, ROWS):
		var fy3 := GRID_ORIGIN.y + float(row) * CELL_SIZE.y
		var d := float(row) / float(ROWS - 1)
		draw_rect(Rect2(8, fy3, 464, CELL_SIZE.y), Color(0.0, 0.0, 0.02, 0.08 + 0.10 * d))

	# Depth tags running up the spine.
	_draw_vlabel("SURFACE", Vector2(3, 96), Color(0.58, 0.72, 0.8, 0.6), 6)
	_draw_vlabel("SUBLEVEL 1", Vector2(3, 154), Color(0.5, 0.62, 0.72, 0.55), 6)
	_draw_vlabel("SUBLEVEL 2", Vector2(3, 212), Color(0.5, 0.62, 0.72, 0.55), 6)


func _draw_vlabel(text: String, pos: Vector2, color: Color, size := 6) -> void:
	draw_set_transform(pos, -PI / 2.0, Vector2.ONE)
	draw_string(ThemeDB.fallback_font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_loadout_readout() -> void:
	# Compact summary of the combat bonuses the built rooms grant the next run.
	var lo := compute_loadout()
	var parts: Array[String] = []
	if lo.bonus_hp > 0.0:
		parts.append("HP+" + str(int(lo.bonus_hp)))
	if lo.damage_mult > 1.0:
		parts.append("DMG+" + str(int(round((lo.damage_mult - 1.0) * 100.0))) + "%")
	if lo.bonus_energy > 0.0:
		parts.append("EN+" + str(int(lo.bonus_energy)))
	if lo.hp_regen > 0.0:
		parts.append("REGEN " + str(snappedf(lo.hp_regen, 0.1)))
	if lo.loot_mult > 1.0:
		parts.append("LOOT+" + str(int(round((lo.loot_mult - 1.0) * 100.0))) + "%")
	if parts.is_empty():
		return
	var text := "LOADOUT  " + "   ".join(parts)
	var width := float(text.length()) * 4.3 + 10.0
	var x := 472.0 - width
	draw_rect(Rect2(x, 31, width, 12), Color(0.03, 0.05, 0.11, 0.72))
	draw_rect(Rect2(x, 31, 2, 12), Color("66d6cc"))
	_label(text, Vector2(x + 5, 40), Color("9fe0d8"), 6)


func _draw_prep_banner() -> void:
	# Fortify countdown shown over the normal build overlay during pre-siege.
	var secs := int(ceil(maxf(0.0, siege_prep_time)))
	var pulse := 0.55 + sin(ambience_time * 6.0) * 0.45
	overlay.draw_rect(Rect2(96, 4, 300, 18), Color(0.1, 0.02, 0.03, 0.8))
	overlay.draw_rect(Rect2(96, 4, 300, 2), Color(1.0, 0.35, 0.3, pulse))
	overlay.draw_rect(Rect2(96, 20, 300, 2), Color(1.0, 0.35, 0.3, pulse * 0.7))
	_label_on(overlay, "SIEGE IMMINENT // FORTIFY %ds   [TAB] BUILD   [ENTER] BEGIN" % secs, Vector2(104, 17), Color("ff9a6a"), 7)


func _draw_plate_label(pos: Vector2, text: String, color: Color) -> void:
	var width := float(text.length()) * 4.2 + 8.0
	draw_rect(Rect2(pos.x, pos.y, width, 13), Color(0.03, 0.05, 0.11, 0.72))
	draw_rect(Rect2(pos.x, pos.y + 13, width, 1), Color(color, 0.5))
	_label(text, pos + Vector2(4, 10), color, 7)


func _draw_overlay() -> void:
	if siege_active and not siege_prep:
		_draw_siege_hud()
		return
	if siege_active and siege_prep:
		_draw_prep_banner()  # countdown over the normal build overlay
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
