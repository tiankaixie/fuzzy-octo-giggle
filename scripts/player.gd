class_name CyberPlayer
extends CharacterBody2D

enum ViewMode { SIDE, TOP_DOWN, BEAT_EM_UP }

var view_mode := ViewMode.SIDE
var speed := 66.0
var motion_time := 0.0
var facing := 1.0
var movement_enabled := true


func setup(mode: ViewMode) -> void:
	view_mode = mode
	if mode == ViewMode.SIDE:
		speed = 66.0
	elif mode == ViewMode.BEAT_EM_UP:
		speed = 74.0
	else:
		speed = 82.0
	queue_redraw()


func _ready() -> void:
	z_index = 20
	var shape := CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	if view_mode == ViewMode.SIDE or view_mode == ViewMode.BEAT_EM_UP:
		capsule.radius = 4.0
		capsule.height = 16.0
		shape.position = Vector2(0, -8)
	else:
		capsule.radius = 5.0
		capsule.height = 12.0
	shape.shape = capsule
	add_child(shape)


func _physics_process(delta: float) -> void:
	if not movement_enabled:
		velocity = Vector2.ZERO
		return

	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if view_mode == ViewMode.SIDE:
		input.y = 0.0
	if input.length_squared() > 0.0:
		input = input.normalized()
		velocity = input * speed
		motion_time += delta * 11.0
		if absf(input.x) > 0.05:
			facing = signf(input.x)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, speed * delta * 8.0)
		motion_time += delta * 2.0
	move_and_slide()
	queue_redraw()


func _draw() -> void:
	if view_mode == ViewMode.SIDE or view_mode == ViewMode.BEAT_EM_UP:
		_draw_side()
	else:
		_draw_top_down()


func _draw_side() -> void:
	var walking := velocity.length() > 4.0
	var bob := roundi(sin(motion_time) * 1.0) if walking else 0
	var step := roundi(sin(motion_time) * 2.0) if walking else 0

	# Soft, chunky pixel shadow.
	draw_rect(Rect2(-7, -1, 14, 3), Color(0.02, 0.02, 0.05, 0.55))
	# Legs and boots.
	draw_rect(Rect2(-5, -8 + bob, 4, 8 + step), Color("25314d"))
	draw_rect(Rect2(1, -8 + bob, 4, 8 - step), Color("36486a"))
	draw_rect(Rect2(-6, -2 + step, 5, 3), Color("0c1123"))
	draw_rect(Rect2(1, -2 - step, 6, 3), Color("0c1123"))
	# Coat and backpack silhouette.
	draw_rect(Rect2(-7, -20 + bob, 13, 13), Color("17233d"))
	draw_rect(Rect2(-9 if facing < 0 else 5, -19 + bob, 4, 10), Color("34264c"))
	draw_rect(Rect2(-6, -18 + bob, 12, 3), Color("41597b"))
	# Head, hood, and cyan optical implant.
	draw_rect(Rect2(-5, -28 + bob, 10, 9), Color("111a30"))
	draw_rect(Rect2(-4, -27 + bob, 8, 7), Color("ad6f68"))
	draw_rect(Rect2(-5, -28 + bob, 9, 3), Color("263756"))
	var eye_x := 2.0 if facing > 0 else -4.0
	draw_rect(Rect2(eye_x, -24 + bob, 3, 2), Color("50f6e3"))
	draw_rect(Rect2(eye_x + facing, -24 + bob, 2, 2), Color(0.31, 0.96, 0.88, 0.28))
	# Orange cybernetic forearm.
	var arm_x := 6.0 if facing > 0 else -9.0
	draw_rect(Rect2(arm_x, -17 + bob, 3, 8), Color("f08a5d"))
	draw_rect(Rect2(arm_x, -11 + bob, 4, 2), Color("ffd166"))


func _draw_top_down() -> void:
	var walking := velocity.length() > 5.0
	var bob := roundi(sin(motion_time) * 1.0) if walking else 0
	var step := roundi(sin(motion_time) * 2.0) if walking else 0
	_draw_oval(Vector2(0, 5), Vector2(9, 5), Color(0.01, 0.02, 0.06, 0.55))
	# Feet visible below the coat.
	draw_rect(Rect2(-6 - step, 2, 5, 5), Color("0a1020"))
	draw_rect(Rect2(1 + step, 2, 5, 5), Color("0a1020"))
	# Backpack and shoulders.
	draw_rect(Rect2(-8, -8 + bob, 16, 12), Color("16223c"))
	draw_rect(Rect2(-6, -10 + bob, 12, 5), Color("364b6d"))
	draw_rect(Rect2(-10, -5 + bob, 4, 7), Color("39294f"))
	draw_rect(Rect2(6, -5 + bob, 4, 7), Color("f08a5d"))
	# Head from above with bright implant direction cue.
	draw_rect(Rect2(-5, -14 + bob, 10, 8), Color("233454"))
	draw_rect(Rect2(-3, -13 + bob, 7, 5), Color("9d6665"))
	var eye_x := 2.0 if facing > 0 else -4.0
	draw_rect(Rect2(eye_x, -10 + bob, 3, 2), Color("51f4e1"))


func _draw_oval(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(16):
		var angle := TAU * float(i) / 16.0
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	draw_colored_polygon(points, color)
