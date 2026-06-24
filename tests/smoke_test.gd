extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed: PackedScene = load("res://scenes/game.tscn")
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	_assert(game.current_world.name == "Bunker", "Game starts in the bunker")
	_assert(game.current_world.player.view_mode == CyberPlayer.ViewMode.SIDE, "Bunker uses side-view movement")
	_assert(game.current_world.layout.size() == 18, "Bunker exposes an expandable 6x3 room grid")
	_assert(game.current_world._cell_at(Vector2(354, 187)) == Vector2i(4, 2), "Mouse coordinates map to build cells")
	_assert(game.current_world._palette_index_at(Vector2(300, 250)) == 3, "Room palette is clickable")
	_assert(game.current_world.place_room(Vector2i(3, 2), "grow", false), "Player can place a room")
	_assert(game.current_world.place_room(Vector2i(4, 2), "grow", false), "Player can expand a room horizontally")
	_assert(game.current_world.rooms_are_merged(Vector2i(3, 2), Vector2i(4, 2)), "Adjacent matching rooms merge")
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
	_assert(game.current_world.STAGES.size() == 3, "Expedition map offers three selectable stages")
	_assert(game.current_world._stage_at(Vector2(245, 104)) == 1, "Map nodes support mouse selection")
	_assert(game.current_world.select_stage("transit"), "A stage can be selected by id")
	game.current_world.launch_selected()
	await create_timer(1.4).timeout
	_assert(game.current_world.name == "Dungeon", "Selected map stage deploys into combat")
	_assert(game.current_world.stage_id == "transit", "Dungeon receives the selected stage theme")
	_assert(game.current_world.player.view_mode == CyberPlayer.ViewMode.BEAT_EM_UP, "Dungeon uses belt-scroller movement")
	_assert(game.current_world.battle_hud.stage_id == "transit", "Combat HUD receives stage context")
	_assert(game.current_world.battle_hud.room_count == 3, "Combat HUD shows the dungeon room route")
	var skill_event := InputEventKey.new()
	skill_event.keycode = KEY_J
	skill_event.pressed = true
	var energy_before: float = game.current_world.battle_hud.energy
	game.current_world.battle_hud._input(skill_event)
	_assert(game.current_world.battle_hud.skill_flash[0] > 0.0, "Combat hotkeys activate HUD skill feedback")
	_assert(game.current_world.battle_hud.energy < energy_before, "Skill feedback consumes displayed energy")
	var surface_start: Vector2 = game.current_world.player.position
	Input.action_press("move_right")
	Input.action_press("move_up")
	await create_timer(0.18).timeout
	Input.action_release("move_right")
	Input.action_release("move_up")
	_assert(game.current_world.player.position.x > surface_start.x, "Dungeon player moves horizontally")
	_assert(game.current_world.player.position.y < surface_start.y, "Dungeon player moves through the depth lane")

	game.current_world.player.position.x = 470.0
	await create_timer(0.65).timeout
	_assert(game.current_world.room_index == 1, "Right gate advances to the next dungeon room")
	_assert(game.current_world.battle_hud.room_index == 1, "Combat minimap follows room progression")
	game.current_world.player.position.x = 9.0
	await create_timer(0.65).timeout
	_assert(game.current_world.room_index == 0, "Left gate returns to the previous dungeon room")
	game.current_world.player.position.x = 9.0
	await process_frame
	await create_timer(1.4).timeout
	_assert(game.current_world.name == "ExpeditionMap", "First dungeon room returns to stage selection")
	game.current_world.return_home()
	await create_timer(1.4).timeout
	_assert(game.current_world.name == "Bunker", "Expedition map can return home")
	print("SMOKE TEST PASSED: bunker → stage map → selected dungeon → map loop is operational")
	quit(0)


func _assert(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	push_error("FAIL: " + message)
	quit(1)
