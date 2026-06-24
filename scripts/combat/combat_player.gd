class_name CombatPlayer
extends CyberPlayer

signal health_changed(value: float, maximum: float)
signal energy_changed(value: float, maximum: float)
signal combo_changed(count: int)
signal sfx_requested(id: String)
signal impact_requested(strength: float, duration: float)
signal died

const MAX_HEALTH := 100.0
const MAX_ENERGY := 100.0

var health := MAX_HEALTH
var energy := 76.0
var attack_lock := 0.0
var hit_delay := 0.0
var pending_attack := ""
var combo_step := 0
var combo_window := 0.0
var combo_hits := 0
var combo_display := 0.0
var skill_cooldown := 0.0
var dodge_cooldown := 0.0
var dodge_time := 0.0
var dodge_direction := Vector2.RIGHT
var hitstun := 0.0
var invulnerable := false
var defeated := false


func _ready() -> void:
	super._ready()


# Combat states take priority over the base idle/walk animation.
func _desired_anim() -> String:
	if defeated:
		return "death"
	if hitstun > 0.0:
		return "hurt"
	if dodge_time > 0.0:
		return "jump"
	if attack_lock > 0.04 or pending_attack != "":
		if pending_attack == "skill":
			return "attack3"
		return ["attack1", "attack2", "attack3"][clampi(combo_step, 0, 2)]
	return super._desired_anim()


func _input(event: InputEvent) -> void:
	if defeated or not movement_enabled:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_J: basic_attack()
			KEY_K: use_skill()
			KEY_L: dodge()


func _physics_process(delta: float) -> void:
	attack_lock = maxf(0.0, attack_lock - delta)
	combo_window = maxf(0.0, combo_window - delta)
	combo_display = maxf(0.0, combo_display - delta)
	skill_cooldown = maxf(0.0, skill_cooldown - delta)
	dodge_cooldown = maxf(0.0, dodge_cooldown - delta)
	energy = minf(MAX_ENERGY, energy + delta * 4.5)
	if combo_display <= 0.0 and combo_hits > 0:
		combo_hits = 0
		combo_changed.emit(0)

	if hit_delay > 0.0:
		hit_delay -= delta
		if hit_delay <= 0.0:
			_deal_pending_attack()

	if hitstun > 0.0:
		hitstun -= delta
		velocity = velocity.move_toward(Vector2.ZERO, 180.0 * delta)
		move_and_slide()
		queue_redraw()
		return
	if dodge_time > 0.0:
		dodge_time -= delta
		invulnerable = true
		velocity = dodge_direction * 185.0
		move_and_slide()
		if dodge_time <= 0.0:
			invulnerable = false
		queue_redraw()
		return
	if attack_lock > 0.0:
		velocity = velocity.move_toward(Vector2.ZERO, 220.0 * delta)
		move_and_slide()
		queue_redraw()
		return
	super._physics_process(delta)


func basic_attack() -> bool:
	if attack_lock > 0.06 or hitstun > 0.0 or dodge_time > 0.0 or defeated:
		return false
	combo_step = (combo_step + 1) % 3 if combo_window > 0.0 else 0
	combo_window = 0.62
	attack_lock = 0.16 if combo_step < 2 else 0.24
	hit_delay = 0.045 if combo_step < 2 else 0.075
	pending_attack = "basic"
	sfx_requested.emit("swing")
	queue_redraw()
	return true


func use_skill() -> bool:
	if skill_cooldown > 0.0 or energy < 24.0 or attack_lock > 0.0 or hitstun > 0.0 or dodge_time > 0.0 or defeated:
		return false
	energy -= 24.0
	energy_changed.emit(energy, MAX_ENERGY)
	skill_cooldown = 1.8
	attack_lock = 0.38
	hit_delay = 0.12
	pending_attack = "skill"
	sfx_requested.emit("skill")
	queue_redraw()
	return true


func dodge() -> bool:
	if dodge_cooldown > 0.0 or hitstun > 0.0 or attack_lock > 0.08 or defeated:
		return false
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	dodge_direction = input.normalized() if input.length_squared() > 0.05 else Vector2(facing, 0)
	if absf(dodge_direction.x) > 0.05:
		facing = signf(dodge_direction.x)
	dodge_time = 0.22
	dodge_cooldown = 0.72
	invulnerable = true
	sfx_requested.emit("dodge")
	queue_redraw()
	return true


func take_damage(amount: float, source_position: Vector2, knockback: float) -> bool:
	if invulnerable or defeated:
		return false
	health = maxf(0.0, health - amount)
	health_changed.emit(health, MAX_HEALTH)
	hitstun = 0.24
	attack_lock = 0.0
	pending_attack = ""
	var direction := signf(position.x - source_position.x)
	if direction == 0.0:
		direction = 1.0
	velocity = Vector2(direction * knockback, -8.0)
	sfx_requested.emit("hurt")
	impact_requested.emit(5.0, 0.04)
	if health <= 0.0:
		defeated = true
		movement_enabled = false
		died.emit()
	queue_redraw()
	return true


func _deal_pending_attack() -> void:
	if pending_attack == "":
		return
	var is_skill := pending_attack == "skill"
	var reach: float = 78.0 if is_skill else [28.0, 32.0, 39.0][combo_step]
	var damage: float = 32.0 if is_skill else [12.0, 15.0, 23.0][combo_step]
	var knockback: float = 55.0 if is_skill else [24.0, 30.0, 48.0][combo_step]
	var connected := 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.dead:
			continue
		var offset: Vector2 = enemy.position - position
		if offset.x * facing >= -5.0 and absf(offset.x) <= reach and absf(offset.y) <= (31.0 if is_skill else 21.0):
			if enemy.take_damage(damage, position, knockback):
				connected += 1
	if connected > 0:
		combo_hits += connected
		combo_display = 1.7
		combo_changed.emit(combo_hits)
		sfx_requested.emit("hit")
		impact_requested.emit(9.0 if is_skill or combo_step == 2 else 5.0, 0.065 if is_skill else 0.04)
	pending_attack = ""


# Body + attack motion come from the sprite animation; base draws the shadow.
# A brief energy flourish is kept for the skill to sell its heavier hit.
func _draw() -> void:
	super._draw()
	if pending_attack == "skill" or (current_anim == "attack3" and attack_lock > 0.1):
		for i in range(3):
			draw_arc(Vector2(facing * 16, -16), 20.0 + i * 6.0, -1.1 if facing > 0 else 2.0, 1.1 if facing > 0 else 4.2, 14, Color(0.32, 0.95, 0.86, 0.5 - i * 0.13), 2)
