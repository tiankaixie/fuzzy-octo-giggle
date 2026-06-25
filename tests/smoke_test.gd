extends SceneTree

const ContentRegistryClass := preload("res://scripts/data/content_registry.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	# Resource-backed content is the source of truth.
	_assert(ContentRegistryClass.rooms().size() == 6, "Room definitions load from Godot Resources")
	_assert(ContentRegistryClass.enemies().size() == 3, "Three enemy archetypes load from Godot Resources")
	_assert(ContentRegistryClass.stages().size() == 3, "Stage definitions load from Godot Resources")
	_assert(ContentRegistryClass.enemy("melee").archetype == EnemyDefinition.Archetype.MELEE, "Melee enemy resource is configured")
	_assert(ContentRegistryClass.enemy("ranged").archetype == EnemyDefinition.Archetype.RANGED, "Ranged enemy resource is configured")
	_assert(ContentRegistryClass.enemy("elite").archetype == EnemyDefinition.Archetype.ELITE, "Elite enemy resource is configured")

	var packed: PackedScene = load("res://scenes/game.tscn")
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	_assert(game.current_world.name == "Bunker", "Game starts in the bunker")
	_assert(game.current_world.player.view_mode == CyberPlayer.ViewMode.SIDE, "Bunker uses side-view movement")
	_assert(game.current_world.layout.size() == 18, "Bunker exposes an expandable 6x3 room grid")
	_assert(game.current_world.room_levels.size() == 18, "Bunker persists a level for every room cell")
	_assert(game.current_world._cell_at(Vector2(354, 187)) == Vector2i(4, 2), "Mouse coordinates map to build cells")
	_assert(game.current_world._palette_index_at(Vector2(300, 250)) == 3, "Resource-backed room palette is clickable")
	_assert(game.current_world.place_room(Vector2i(3, 2), "grow", false), "Player can place a room")
	_assert(game.current_world.place_room(Vector2i(4, 2), "grow", false), "Player can expand a room horizontally")
	_assert(game.current_world.rooms_are_merged(Vector2i(3, 2), Vector2i(4, 2)), "Adjacent matching rooms merge")
	_assert(game.current_world.compute_loadout().hp_regen > 0.0, "Built rooms produce a combat loadout")
	_assert(game.current_world.remove_room(Vector2i(4, 2), false), "Player can salvage a room")
	_assert(not game.current_world.remove_room(Vector2i(5, 0), false), "Structural airlock cannot be removed")
	game.current_world.remove_room(Vector2i(3, 2), false)

	var bunker_start: Vector2 = game.current_world.player.position
	Input.action_press("move_right")
	await create_timer(0.18).timeout
	Input.action_release("move_right")
	_assert(game.current_world.player.position.x > bunker_start.x, "Bunker player moves horizontally")
	_assert(is_equal_approx(game.current_world.player.position.y, bunker_start.y), "Bunker movement remains side-on")
	game.current_world.player.position.x = 30.0
	Input.action_press("move_up")
	await create_timer(0.1).timeout
	Input.action_release("move_up")
	await create_timer(0.35).timeout
	_assert(game.current_world.current_floor == 0, "Lift connects expandable bunker floors")

	game.current_world.player.position = Vector2(461, game.current_world._floor_y(0))
	await process_frame
	await create_timer(1.4).timeout
	_assert(game.current_world.name == "ExpeditionMap", "Airlock opens the expedition map")
	_assert(game.current_world.stages.size() == 3, "Expedition map offers three resource-backed stages")
	_assert(game.current_world._stage_at(Vector2(245, 104)) == 1, "Map nodes support mouse selection")
	_assert(game.current_world.select_stage("transit"), "A stage can be selected by id")
	game.current_world.launch_selected()
	await create_timer(1.4).timeout
	_assert(game.current_world.name == "Dungeon", "Selected map stage deploys into combat")
	_assert(game.current_world.stage_id == "transit", "Dungeon receives the selected stage resource")
	_assert(game.current_world.player is CombatPlayer, "Dungeon uses the combat player controller")
	_assert(game.current_world.player.view_mode == CyberPlayer.ViewMode.BEAT_EM_UP, "Combat remains a belt-scroller")
	_assert(game.current_world.remaining_enemies == 2, "First room spawns its configured enemy wave")
	_assert(game.current_world.combat_audio.streams.size() == 7, "Procedural combat sound set is generated")
	_assert(game.current_world.battle_hud.room_count == 3, "Combat HUD shows the dungeon room route")

	# Basic attack, hit reaction, knockback, hit-stop, shake and combo feedback.
	var enemies := get_nodes_in_group("enemies")
	var target: CombatEnemy = enemies[0]
	game.current_world.player.position = Vector2(235, 205)
	target.position = Vector2(250, 205)
	var health_before_melee: float = game.current_world.player.health
	target._perform_attack()
	_assert(game.current_world.player.health < health_before_melee, "Melee enemy connects a close-range attack")
	var ranged_enemy: CombatEnemy = enemies[1]
	ranged_enemy.position = Vector2(350, 205)
	ranged_enemy._perform_attack()
	await process_frame
	var projectile_found := false
	for child in game.current_world.get_children():
		if child is CombatProjectile:
			projectile_found = true
			child.queue_free()
	_assert(projectile_found, "Ranged enemy launches a combat projectile")
	await create_timer(0.3, true, false, true).timeout
	for enemy in enemies:
		enemy.attack_cooldown = 99.0
		enemy.windup = 0.0
		enemy.hitstun = 2.0
	game.current_world.player.hitstun = 0.0
	game.current_world.player.velocity = Vector2.ZERO
	game.current_world.player.facing = 1.0
	game.current_world.player.position = Vector2(235, 205)
	target.position = Vector2(257, 205)
	var enemy_health_before: float = target.health
	_assert(game.current_world.player.basic_attack(), "Basic attack starts")
	await create_timer(0.16, true, false, true).timeout
	_assert(target.health < enemy_health_before, "Basic attack damages a target")
	_assert(absf(target.velocity.x) > 0.0, "Hit applies knockback")
	_assert(game.current_world.hitstop_generation > 0, "Connected shot requests hit-stop")
	_assert(game.current_world.shake_strength > 0.0, "Connected shot requests camera shake")
	await create_timer(0.24, true, false, true).timeout
	var health_after_first: float = target.health
	target.hitstun = 2.0
	target.position = Vector2(257, 205)
	game.current_world.player.position = Vector2(235, 205)
	game.current_world.player.facing = 1.0
	_assert(game.current_world.player.basic_attack(), "Player can fire again")
	await create_timer(0.26, true, false, true).timeout
	_assert(target.health < health_after_first, "Repeated ranged shots keep dealing damage")
	await create_timer(0.2, true, false, true).timeout
	var energy_before: float = game.current_world.player.energy
	_assert(game.current_world.player.use_skill(), "Energy skill activates")
	_assert(game.current_world.player.energy < energy_before, "Skill consumes player energy")
	await create_timer(0.48, true, false, true).timeout
	_assert(game.current_world.player.dodge(), "Dodge activates")
	_assert(not game.current_world.player.take_damage(10.0, Vector2.ZERO, 20.0), "Dodge invulnerability rejects damage")
	await create_timer(0.3, true, false, true).timeout
	var player_health_before: float = game.current_world.player.health
	_assert(game.current_world.player.take_damage(10.0, Vector2.ZERO, 20.0), "Player can receive damage after dodge")
	_assert(game.current_world.player.health < player_health_before, "Received damage updates player health")

	# Room locking, three enemy archetypes, loot accumulation and stage settlement.
	game.current_world.debug_clear_room()
	await create_timer(0.25, true, false, true).timeout
	_assert(game.current_world.cleared_rooms.get(0, false), "Defeating a wave clears and unlocks the room")
	_assert(game.current_world.total_loot > 0, "Defeated enemies award salvage")
	game.current_world.player.position.x = 470.0
	await create_timer(0.7, true, false, true).timeout
	_assert(game.current_world.room_index == 1, "Unlocked right gate advances to the next room")
	_assert(game.current_world.battle_hud.room_index == 1, "Combat minimap follows room progression")
	game.current_world.debug_clear_room()
	await create_timer(0.25, true, false, true).timeout
	game.current_world.player.position.x = 470.0
	await create_timer(0.7, true, false, true).timeout
	_assert(game.current_world.room_index == 2, "Second cleared wave advances to the final room")
	var has_elite := false
	for enemy in get_nodes_in_group("enemies"):
		if enemy.definition.archetype == EnemyDefinition.Archetype.ELITE:
			has_elite = true
	_assert(has_elite, "Final wave contains the configured elite enemy")
	game.current_world.debug_clear_room()
	await create_timer(0.25, true, false, true).timeout
	game.current_world.player.position.x = 470.0
	await create_timer(0.2, true, false, true).timeout
	_assert(game.current_world.result_state == "clear", "Final room opens stage-clear settlement")
	_assert(game.current_world.battle_hud.result_visible, "Settlement displays recovered loot")
	var expected_reward: int = game.current_world.total_loot + game.current_world.stage_definition.clear_bonus
	var salvage_before_reward: int = game.salvage
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	game.current_world._unhandled_input(enter)
	await create_timer(1.5).timeout
	_assert(game.current_world.name == "Bunker", "Stage settlement returns directly to the bunker")
	_assert(game.salvage == salvage_before_reward + expected_reward, "Recovered loot enters bunker salvage storage")
	_assert(game.current_world.salvage == game.salvage, "Bunker receives the persistent salvage balance")

	# Expedition loot can immediately build and upgrade a room.
	var build_cell := Vector2i(4, 2)
	game.current_world.remove_room(build_cell, false)
	var grow_definition: RoomDefinition = ContentRegistryClass.room("grow")
	var balance_before_build: int = game.salvage
	_assert(game.current_world.place_room(build_cell, "grow", true), "Loot can build a resource-defined room")
	_assert(game.salvage == balance_before_build - grow_definition.build_cost, "Building consumes configured salvage cost")
	var balance_before_upgrade: int = game.salvage
	_assert(game.current_world.place_room(build_cell, "grow", true), "Selecting an existing room upgrades it")
	_assert(game.current_world.get_room_level(build_cell) == 2, "Room upgrade increases its persistent level")
	_assert(game.salvage == balance_before_upgrade - grow_definition.upgrade_cost, "Upgrade consumes configured salvage cost")
	game.current_world._reset_layout()

	Engine.time_scale = 1.0
	print("SMOKE TEST PASSED: combat → loot → bunker build/upgrade loop is operational")
	quit(0)


func _assert(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	push_error("FAIL: " + message)
	Engine.time_scale = 1.0
	quit(1)
