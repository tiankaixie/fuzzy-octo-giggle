class_name CombatEnemy
extends CharacterBody2D

const CharacterFramesClass := preload("res://scripts/art/character_frames.gd")

# Each enemy archetype maps to a licensed CraftPix character (OGA-BY 3.0).
const ARCHETYPE_CHARACTER := {
	EnemyDefinition.Archetype.MELEE: "punk",
	EnemyDefinition.Archetype.RANGED: "cyborg",
	EnemyDefinition.Archetype.ELITE: "biker",
}

signal defeated(enemy: CombatEnemy, loot: int)
signal projectile_requested(origin: Vector2, direction: Vector2, damage: float, knockback: float, color: Color)
signal attack_connected(strength: float, duration: float)
signal sfx_requested(id: String)

var definition: EnemyDefinition
var target: Node2D
var health := 1.0
var attack_cooldown := 0.0
var windup := 0.0
var hitstun := 0.0
var flash := 0.0
var death_time := 0.0
var dead := false
var facing := -1.0
var phase := 0.0
var strike_time := 0.0
var sprite: AnimatedSprite2D
var current_anim := ""

# Siege mode: instead of chasing the player on one lane, the zombie follows a
# waypoint path down the bunker shaft toward the reactor core, attacking the
# core (or the player if they block the way).
var siege := false
var siege_waypoints: Array = []
var siege_wp := 0
var siege_core: Node2D
var siege_player: Node2D
var siege_attack_target: Node2D


func setup(enemy_definition: EnemyDefinition, victim: Node2D, spawn_position: Vector2) -> void:
	definition = enemy_definition
	target = victim
	position = spawn_position
	health = definition.max_health


func _ready() -> void:
	add_to_group("enemies")
	z_index = 210
	var collision := CollisionShape2D.new()
	var shape := CapsuleShape2D.new()
	shape.radius = 5.0 if definition.archetype != EnemyDefinition.Archetype.ELITE else 8.0
	shape.height = 16.0 if definition.archetype != EnemyDefinition.Archetype.ELITE else 23.0
	collision.position = Vector2(0, -8)
	collision.shape = shape
	add_child(collision)
	collision_layer = 0
	collision_mask = 0

	var is_elite := definition.archetype == EnemyDefinition.Archetype.ELITE
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = CharacterFramesClass.get_frames(ARCHETYPE_CHARACTER[definition.archetype])
	sprite.centered = true
	sprite.offset = Vector2(0, -20)
	sprite.scale = Vector2(1.35, 1.35) if is_elite else Vector2.ONE
	# Tint toward the archetype's signature glow so reused art still reads distinct.
	sprite.modulate = definition.body_color.lerp(Color.WHITE, 0.55)
	add_child(sprite)
	current_anim = "idle"
	sprite.play("idle")


func _physics_process(delta: float) -> void:
	phase += delta
	flash = maxf(0.0, flash - delta * 5.0)
	strike_time = maxf(0.0, strike_time - delta)
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	if dead:
		death_time -= delta
		modulate.a = clampf(death_time / 0.18, 0.0, 1.0)
		_update_anim()
		if death_time <= 0.0:
			queue_free()
		return

	if hitstun > 0.0:
		hitstun -= delta
		velocity = velocity.move_toward(Vector2.ZERO, 145.0 * delta)
		move_and_slide()
	else:
		_update_ai(delta)
	if siege:
		position.y = clampf(position.y, 40.0, 232.0)
	else:
		position.y = clampf(position.y, 176.0, 221.0)
	position.x = clampf(position.x, 18.0, 462.0)
	z_index = 20 + int(position.y)
	_update_anim()
	queue_redraw()


func _update_anim() -> void:
	if sprite == null:
		return
	sprite.flip_h = facing < 0
	var want := _enemy_anim()
	if want != current_anim:
		current_anim = want
		sprite.play(want)


func _enemy_anim() -> String:
	if dead:
		return "death"
	if hitstun > 0.0:
		return "hurt"
	if windup > 0.0 or strike_time > 0.0:
		return "attack2" if definition.archetype == EnemyDefinition.Archetype.RANGED else "attack1"
	if velocity.length() > 3.0:
		return "run"
	return "idle"


func _update_ai(delta: float) -> void:
	if siege:
		_siege_ai(delta)
		return
	if not is_instance_valid(target):
		velocity = Vector2.ZERO
		return
	if windup > 0.0:
		windup -= delta
		velocity = velocity.move_toward(Vector2.ZERO, 190.0 * delta)
		move_and_slide()
		if windup <= 0.0:
			_perform_attack()
		return

	var offset := target.position - position
	if absf(offset.x) > 1.0:
		facing = signf(offset.x)
	var depth_gap := absf(offset.y)
	if definition.archetype == EnemyDefinition.Archetype.RANGED:
		if attack_cooldown <= 0.0 and absf(offset.x) <= definition.attack_range and depth_gap < 25.0:
			_begin_attack(0.42)
			return
		var desired_x := 92.0
		var x_motion := 0.0
		if absf(offset.x) > desired_x + 18.0:
			x_motion = signf(offset.x)
		elif absf(offset.x) < desired_x - 18.0:
			x_motion = -signf(offset.x)
		velocity = Vector2(x_motion, signf(offset.y) * minf(1.0, depth_gap / 15.0)) * definition.move_speed
	else:
		if attack_cooldown <= 0.0 and absf(offset.x) <= definition.attack_range and depth_gap < 18.0:
			_begin_attack(0.27 if definition.archetype == EnemyDefinition.Archetype.MELEE else 0.48)
			return
		velocity = Vector2(signf(offset.x), signf(offset.y) * minf(0.8, depth_gap / 20.0)) * definition.move_speed
	move_and_slide()


# Walks the waypoint path down the shaft toward the core, attacking the core
# (or the player if they stand in the way).
func _siege_ai(delta: float) -> void:
	if windup > 0.0:
		windup -= delta
		velocity = Vector2.ZERO
		if windup <= 0.0:
			_siege_strike()
		return
	if is_instance_valid(siege_player) and not siege_player.defeated:
		var pd: Vector2 = siege_player.position - position
		if absf(pd.x) < 16.0 and absf(pd.y) < 16.0:
			if absf(pd.x) > 1.0:
				facing = signf(pd.x)
			if attack_cooldown <= 0.0:
				siege_attack_target = siege_player
				_begin_attack(0.32)
			else:
				velocity = Vector2.ZERO
			return
	if siege_wp < siege_waypoints.size():
		var wp: Vector2 = siege_waypoints[siege_wp]
		var to_wp: Vector2 = wp - position
		if to_wp.length() < 5.0:
			siege_wp += 1
			return
		if absf(to_wp.x) > 1.0:
			facing = signf(to_wp.x)
		velocity = to_wp.normalized() * definition.move_speed
		move_and_slide()
		return
	if is_instance_valid(siege_core):
		var cd: Vector2 = siege_core.position - position
		if absf(cd.x) > 1.0:
			facing = signf(cd.x)
		if cd.length() > 16.0:
			velocity = cd.normalized() * definition.move_speed
			move_and_slide()
		elif attack_cooldown <= 0.0:
			siege_attack_target = siege_core
			_begin_attack(0.34)
		else:
			velocity = Vector2.ZERO
	else:
		velocity = Vector2.ZERO


func _siege_strike() -> void:
	strike_time = 0.2
	if is_instance_valid(siege_attack_target) and siege_attack_target.has_method("take_damage"):
		siege_attack_target.take_damage(definition.damage, position, definition.knockback_force)
		sfx_requested.emit("shot" if definition.archetype == EnemyDefinition.Archetype.RANGED else "hit")


func _begin_attack(duration: float) -> void:
	windup = duration
	attack_cooldown = definition.attack_cooldown
	velocity = Vector2.ZERO


func _perform_attack() -> void:
	if not is_instance_valid(target) or dead:
		return
	strike_time = 0.2
	var offset := target.position - position
	if definition.archetype == EnemyDefinition.Archetype.RANGED:
		# Flat horizontal shot along the lane (no tracking) so it stays easy to
		# read and dodge by stepping up/down in depth.
		projectile_requested.emit(position + Vector2(facing * 10.0, -9), Vector2(facing, 0.0), definition.damage, definition.knockback_force, definition.glow_color)
		sfx_requested.emit("shot")
	elif absf(offset.x) < definition.attack_range + 10.0 and absf(offset.y) < 22.0:
		if target.take_damage(definition.damage, position, definition.knockback_force):
			attack_connected.emit(7.0 if definition.archetype == EnemyDefinition.Archetype.ELITE else 4.0, 0.045)


func take_damage(amount: float, source_position: Vector2, knockback: float) -> bool:
	if dead:
		return false
	health -= amount
	flash = 1.0
	hitstun = 0.18 if definition.archetype != EnemyDefinition.Archetype.ELITE else 0.11
	var direction := signf(position.x - source_position.x)
	if direction == 0.0:
		direction = 1.0
	velocity = Vector2(direction * knockback, -6.0)
	if health <= 0.0:
		_die()
	queue_redraw()
	return true


func _die() -> void:
	dead = true
	death_time = 0.5
	velocity = Vector2.ZERO
	remove_from_group("enemies")
	defeated.emit(self, definition.loot_value)


# The body is an AnimatedSprite2D child; here we only draw the diegetic shadow,
# health bar, elite aura and the wind-up telegraph ring above the head.
func _draw() -> void:
	if not definition:
		return
	var glow := definition.glow_color
	var is_elite := definition.archetype == EnemyDefinition.Archetype.ELITE
	var head_y := -58.0 if is_elite else -46.0
	draw_ellipse(Vector2(0, 3), 12.0 if not is_elite else 16.0, 4.0, Color(0.01, 0.02, 0.05, 0.6))
	draw_ellipse(Vector2(0, 3), 8.0 if not is_elite else 11.0, 2.5, Color(0.0, 0.01, 0.03, 0.4))
	if not is_elite:
		for i in range(3, 0, -1):
			draw_circle(Vector2(0, -20), 7.0 + float(i) * 3.0, Color(glow, 0.025 * float(4 - i)))
	if is_elite:
		for i in range(3, 0, -1):
			draw_circle(Vector2(0, -24), 18.0 + i * 3.0, Color(glow, 0.012 * i))
	if health < definition.max_health and not dead:
		draw_rect(Rect2(-13, head_y, 26, 3), Color("171827"))
		draw_rect(Rect2(-12, head_y + 1.0, 24.0 * maxf(0.0, health / definition.max_health), 1), glow)
	if windup > 0.0:
		var telegraph := 0.45 + sin(phase * 24.0) * 0.3
		draw_arc(Vector2(0, head_y - 6.0), 7, 0, TAU, 16, Color(glow, telegraph), 2)

