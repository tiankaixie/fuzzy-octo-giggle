class_name CombatProjectile
extends Node2D

var direction := Vector2.LEFT
var speed := 128.0
var damage := 8.0
var knockback := 22.0
var target: Node2D
var lifetime := 2.2
var color := Color("5be4d2")
var phase := 0.0
var trail: Array[Vector2] = []


func setup(origin: Vector2, aim_direction: Vector2, victim: Node2D, amount: float, force: float, tint: Color) -> void:
	position = origin
	direction = aim_direction.normalized()
	target = victim
	damage = amount
	knockback = force
	color = tint


func _ready() -> void:
	z_index = 230


func _physics_process(delta: float) -> void:
	phase += delta
	trail.push_front(position)
	if trail.size() > 7:
		trail.pop_back()
	position += direction * speed * delta
	lifetime -= delta
	if is_instance_valid(target) and position.distance_to(target.position) < 11.0:
		if target.take_damage(damage, position - direction * 8.0, knockback):
			queue_free()
			return
	if lifetime <= 0.0 or position.x < -20.0 or position.x > 500.0:
		queue_free()
	queue_redraw()


func _draw() -> void:
	# Tapered motion trail from recorded positions (converted to local space).
	for i in range(trail.size()):
		var local: Vector2 = trail[i] - position
		var t := 1.0 - float(i) / float(trail.size())
		draw_circle(local, 1.0 + t * 2.2, Color(color, 0.06 + t * 0.16))
	# Soft outer bloom.
	for i in range(4, 0, -1):
		draw_circle(Vector2.ZERO, float(i) * 2.4, Color(color, 0.03 * i))
	# Elongated arc bolt with a hot white core and leading spark.
	var perp := Vector2(-direction.y, direction.x)
	var glow := color.lightened(0.25)
	draw_colored_polygon(PackedVector2Array([
		-direction * 8.0, perp * 2.4, direction * 6.0, -perp * 2.4,
	]), Color(glow, 0.85))
	draw_line(-direction * 6.0, direction * 5.0, Color(1, 1, 1, 0.9), 1)
	draw_circle(direction * 4.0, 1.6, Color(1, 1, 1, 0.95))
	# Crackle flicker.
	var flick := 0.5 + sin(phase * 40.0) * 0.5
	draw_circle(Vector2.ZERO, 1.2, Color(1, 1, 1, 0.4 + flick * 0.4))

