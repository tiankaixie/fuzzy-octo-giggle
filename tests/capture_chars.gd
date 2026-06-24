extends SceneTree

# Standalone character art preview: renders the player and every enemy archetype
# large on a neutral backdrop so sprite detail can be inspected and iterated
# without hunting for them inside a full scene.

const PlayerClass := preload("res://scripts/combat/combat_player.gd")
const EnemyClass := preload("res://scripts/combat/combat_enemy.gd")
const ContentRegistryClass := preload("res://scripts/data/content_registry.gd")

const SCALE := 5.0
const FEET_Y := 244.0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	RenderingServer.set_default_clear_color(Color("141826"))
	var root_node := Node2D.new()
	root.add_child(root_node)

	# Checker backdrop so transparent pixels and silhouette edges read clearly.
	var bg := Node2D.new()
	bg.draw.connect(_draw_backdrop.bind(bg))
	root_node.add_child(bg)

	var player: CombatPlayer = PlayerClass.new()
	player.setup(CyberPlayer.ViewMode.BEAT_EM_UP)
	player.scale = Vector2(SCALE, SCALE)
	player.position = Vector2(70, FEET_Y)
	player.set_physics_process(false)
	player.set_process(false)
	root_node.add_child(player)

	var ids := ["melee", "ranged", "elite"]
	for i in range(ids.size()):
		var enemy: CombatEnemy = EnemyClass.new()
		enemy.setup(ContentRegistryClass.enemy(ids[i]), player, Vector2.ZERO)
		enemy.scale = Vector2(SCALE, SCALE)
		enemy.position = Vector2(190.0 + i * 100.0, FEET_Y)
		enemy.facing = -1.0
		root_node.add_child(enemy)
		enemy.set_physics_process(false)

	await process_frame
	await process_frame
	for child in root_node.get_children():
		if child.has_method("queue_redraw"):
			child.queue_redraw()
	await process_frame
	await create_timer(0.1).timeout

	var image := root.get_texture().get_image()
	var error := image.save_png("/tmp/cyber_chars.png")
	print("CAPTURED chars: ", error == OK)
	quit(0)


func _draw_backdrop(node: Node2D) -> void:
	for ty in range(0, 270, 16):
		for tx in range(0, 480, 16):
			var shade := 0.10 if (tx / 16 + ty / 16) % 2 == 0 else 0.14
			node.draw_rect(Rect2(tx, ty, 16, 16), Color(shade, shade + 0.02, shade + 0.05))
	node.draw_line(Vector2(0, FEET_Y), Vector2(480, FEET_Y), Color(1, 1, 1, 0.12), 1)
