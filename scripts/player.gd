class_name CyberPlayer
extends CharacterBody2D

const CharacterFramesClass := preload("res://scripts/art/character_frames.gd")

enum ViewMode { SIDE, TOP_DOWN, BEAT_EM_UP }

# Licensed CraftPix cyberpunk sprite (OGA-BY 3.0, see assets/.../CREDITS.md).
const CHARACTER_ID := "biker"
const SPRITE_OFFSET := Vector2(0, -20)

var view_mode := ViewMode.SIDE
var speed := 66.0
var motion_time := 0.0
var facing := 1.0
var movement_enabled := true
var sprite: AnimatedSprite2D
var current_anim := ""


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

	if view_mode != ViewMode.TOP_DOWN:
		sprite = AnimatedSprite2D.new()
		sprite.sprite_frames = CharacterFramesClass.get_frames(CHARACTER_ID)
		sprite.centered = true
		sprite.offset = SPRITE_OFFSET
		add_child(sprite)
		current_anim = "idle"
		sprite.play("idle")


func _process(_delta: float) -> void:
	_update_anim()


# Desired animation for the current state; combat subclass adds attack/hurt poses.
func _desired_anim() -> String:
	if velocity.length() > 4.0:
		return "run"
	return "idle"


func _update_anim() -> void:
	if sprite == null:
		return
	sprite.flip_h = facing < 0
	var want := _desired_anim()
	if want != current_anim:
		current_anim = want
		sprite.play(want)


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
	# Body is an AnimatedSprite2D child now; only the contact shadow is drawn here.
	_draw_oval(Vector2(0, 3), Vector2(9, 3.2), Color(0.01, 0.02, 0.05, 0.55))
	_draw_oval(Vector2(0, 3), Vector2(6, 2.2), Color(0.0, 0.01, 0.03, 0.4))


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
