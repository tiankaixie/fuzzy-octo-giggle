extends Node

const BUNKER_SCENE := preload("res://scenes/bunker.tscn")
const EXPEDITION_MAP_SCENE := preload("res://scenes/expedition_map.tscn")
const DUNGEON_SCENE := preload("res://scenes/dungeon.tscn")

var current_world: Node
var transition_layer: CanvasLayer
var transition_rect: ColorRect
var transition_caption: Label
var transitioning := false
var selected_stage_id := "arcade"
var salvage := 160
var last_loot := 0
# Persistent time-of-day clock shared across worlds, so deploying from the
# bunker at night drops you into a night-time stage.
var world_time := 0.0
# Combat loadout from the bunker's rooms, captured on deploy and applied in the dungeon.
var loadout := {}


func _process(delta: float) -> void:
	world_time += delta
	if is_instance_valid(current_world) and "world_time" in current_world:
		current_world.world_time = world_time


func _ready() -> void:
	_register_inputs()
	_build_transition_layer()
	_show_world("bunker")
	transition_rect.color.a = 1.0
	var intro := create_tween().set_parallel(true)
	intro.tween_property(transition_rect, "color:a", 0.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	intro.tween_property(transition_caption, "modulate:a", 0.0, 0.35).set_delay(0.25)


func _register_inputs() -> void:
	_add_action("move_left", [KEY_A, KEY_LEFT])
	_add_action("move_right", [KEY_D, KEY_RIGHT])
	_add_action("move_up", [KEY_W, KEY_UP])
	_add_action("move_down", [KEY_S, KEY_DOWN])


func _add_action(action: StringName, keys: Array[int]) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for keycode in keys:
		var event := InputEventKey.new()
		event.physical_keycode = keycode
		InputMap.action_add_event(action, event)


func _build_transition_layer() -> void:
	transition_layer = CanvasLayer.new()
	transition_layer.layer = 100
	add_child(transition_layer)

	transition_rect = ColorRect.new()
	transition_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	transition_rect.color = Color("060611")
	transition_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition_layer.add_child(transition_rect)

	transition_caption = Label.new()
	transition_caption.text = "DESCENDING // HOME"
	transition_caption.position = Vector2(165, 132)
	transition_caption.add_theme_font_size_override("font_size", 8)
	transition_caption.add_theme_color_override("font_color", Color("f7a55f"))
	transition_caption.add_theme_color_override("font_shadow_color", Color("5b203c"))
	transition_caption.add_theme_constant_override("shadow_offset_x", 1)
	transition_caption.add_theme_constant_override("shadow_offset_y", 1)
	transition_layer.add_child(transition_caption)


func _show_world(target: String) -> void:
	if is_instance_valid(current_world):
		if current_world.has_method("compute_loadout"):
			loadout = current_world.compute_loadout()
		current_world.queue_free()
	match target:
		"bunker":
			current_world = BUNKER_SCENE.instantiate()
			current_world.salvage = salvage
			current_world.last_loot = last_loot
		"map": current_world = EXPEDITION_MAP_SCENE.instantiate()
		_:
			current_world = DUNGEON_SCENE.instantiate()
			current_world.stage_id = selected_stage_id
	if "world_time" in current_world:
		current_world.world_time = world_time
	if "loadout" in current_world:
		current_world.loadout = loadout
	add_child(current_world)
	move_child(current_world, 0)
	current_world.transition_requested.connect(_on_transition_requested)
	if current_world.has_signal("stage_selected"):
		current_world.stage_selected.connect(_on_stage_selected)
	if current_world.has_signal("stage_completed"):
		current_world.stage_completed.connect(_on_stage_completed)
	if current_world.has_signal("salvage_changed"):
		current_world.salvage_changed.connect(_on_salvage_changed)
	if target == "bunker":
		last_loot = 0


func _on_stage_selected(stage_id: String) -> void:
	selected_stage_id = stage_id
	_on_transition_requested("dungeon")


func _on_stage_completed(completed_stage_id: String, loot: int) -> void:
	selected_stage_id = completed_stage_id
	last_loot = loot
	salvage += loot
	_on_transition_requested("bunker")


func _on_salvage_changed(value: int) -> void:
	salvage = value


func _on_transition_requested(target: String) -> void:
	if transitioning:
		return
	Engine.time_scale = 1.0
	transitioning = true
	current_world.set_process(false)
	current_world.set_physics_process(false)
	match target:
		"map": transition_caption.text = "UPLINK // CHOOSE A ROUTE"
		"dungeon": transition_caption.text = "DEPLOYING // " + selected_stage_id.to_upper()
		_: transition_caption.text = "DESCENDING // HOME"
	transition_caption.modulate.a = 0.0

	var fade_out := create_tween().set_parallel(true)
	fade_out.tween_property(transition_rect, "color:a", 1.0, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fade_out.tween_property(transition_caption, "modulate:a", 1.0, 0.2).set_delay(0.12)
	await fade_out.finished
	await get_tree().create_timer(0.28).timeout

	_show_world(target)
	var fade_in := create_tween().set_parallel(true)
	fade_in.tween_property(transition_rect, "color:a", 0.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	fade_in.tween_property(transition_caption, "modulate:a", 0.0, 0.28).set_delay(0.15)
	await fade_in.finished
	transitioning = false
