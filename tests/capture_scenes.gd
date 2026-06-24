extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed: PackedScene = load("res://scenes/game.tscn")
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	await create_timer(0.9).timeout
	_capture("/tmp/cyber_bunker.png")
	game.current_world._set_build_mode(true)
	game.current_world.hover_cell = Vector2i(4, 2)
	await process_frame
	await process_frame
	await create_timer(0.08).timeout
	_capture("/tmp/cyber_bunker_build.png")

	game._show_world("map")
	game.transition_rect.color.a = 0.0
	await process_frame
	await process_frame
	await create_timer(0.15).timeout
	_capture("/tmp/cyber_expedition_map.png")

	game.selected_stage_id = "transit"
	game._show_world("dungeon")
	await process_frame
	await process_frame
	await create_timer(0.35).timeout
	game.current_world.player.position = Vector2(228, 207)
	var combat_enemies := get_nodes_in_group("enemies")
	for i in range(combat_enemies.size()):
		combat_enemies[i].position = Vector2(300 + i * 54, 201 - i * 13)
	await process_frame
	_capture("/tmp/cyber_dungeon.png")
	game.current_world.room_index = 1
	game.current_world.battle_hud.set_room(1)
	game.current_world._spawn_room_wave()
	await process_frame
	await process_frame
	await create_timer(0.2).timeout
	_capture("/tmp/cyber_dungeon_transit.png")
	game.current_world.debug_clear_room()
	await create_timer(0.3, true, false, true).timeout
	game.current_world.battle_hud.show_results("STAGE CLEAR", 144)
	await process_frame
	await process_frame
	await create_timer(0.08).timeout
	_capture("/tmp/cyber_stage_clear.png")

	Engine.time_scale = 1.0
	game.selected_stage_id = "foundry"
	game._show_world("dungeon")
	await process_frame
	await process_frame
	await create_timer(0.12).timeout
	game.current_world.room_index = 2
	game.current_world.battle_hud.set_room(2)
	game.current_world._spawn_room_wave()
	await process_frame
	await process_frame
	await create_timer(0.16).timeout
	_capture("/tmp/cyber_dungeon_foundry.png")
	quit(0)


func _capture(path: String) -> void:
	var image := root.get_texture().get_image()
	var error := image.save_png(path)
	if error != OK:
		push_error("Could not save capture: " + path)
	else:
		print("CAPTURED: ", path)
