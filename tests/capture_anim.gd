extends SceneTree

# Captures a live dungeon-combat sequence so sprite-sheet animations (run, attack,
# hurt, death) can be verified actually playing in-engine.

const FRAMES := 28


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed: PackedScene = load("res://scenes/game.tscn")
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.selected_stage_id = "transit"
	game._show_world("dungeon")
	game.transition_rect.color.a = 0.0
	await process_frame
	await create_timer(0.4).timeout

	var world = game.current_world
	world.player.position = Vector2(150, 205)
	world.player.facing = 1.0

	for i in range(FRAMES):
		if i % 6 == 2:
			world.player.basic_attack()
		await physics_frame
		await process_frame
		Engine.time_scale = 1.0
		_grab("/tmp/anim_seq_%02d.png" % i)

	print("ANIM DONE")
	quit(0)


func _grab(path: String) -> void:
	var image := root.get_texture().get_image()
	image.save_png(path)
