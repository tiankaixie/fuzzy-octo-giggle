class_name CombatPlayer
extends CyberPlayer

signal health_changed(value: float, maximum: float)
signal energy_changed(value: float, maximum: float)
signal combo_changed(count: int)
signal sfx_requested(id: String)
signal impact_requested(strength: float, duration: float)
signal hit_landed(world_pos: Vector2, amount: int)
signal damaged(amount: int)
signal shoot_requested(origin: Vector2, direction: Vector2, damage: float, knockback: float)
signal died

const MAX_HEALTH := 100.0
const MAX_ENERGY := 100.0

var health := MAX_HEALTH
var energy := 76.0
var max_health := MAX_HEALTH
var max_energy := MAX_ENERGY
var damage_mult := 1.0
var energy_regen := 4.5
var hp_regen := 0.0
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


# Applies the bunker loadout (room bonuses) before an expedition.
func apply_loadout(lo: Dictionary) -> void:
	max_health = MAX_HEALTH + lo.get("bonus_hp", 0.0)
	max_energy = MAX_ENERGY + lo.get("bonus_energy", 0.0)
	energy_regen = 4.5 + lo.get("energy_regen", 0.0)
	hp_regen = lo.get("hp_regen", 0.0)
	damage_mult = lo.get("damage_mult", 1.0)
	health = max_health
	energy = max_energy
	health_changed.emit(health, max_health)
	energy_changed.emit(energy, max_energy)


# Combat states take priority over the base idle/walk animation.
func _desired_anim() -> String:
	if defeated or hitstun > 0.0:
		return "hurt"
	if dodge_time > 0.0:
		return "jump"
	if attack_lock > 0.04 or pending_attack != "":
		return "shoot"
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
	energy = minf(max_energy, energy + delta * energy_regen)
	if hp_regen > 0.0 and not defeated and health > 0.0:
		health = minf(max_health, health + hp_regen * delta)
		health_changed.emit(health, max_health)
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
	attack_lock = 0.16
	hit_delay = 0.05
	pending_attack = "basic"
	sfx_requested.emit("shot")
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
	health_changed.emit(health, max_health)
	damaged.emit(int(round(amount)))
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
	var muzzle := position + Vector2(facing * 12.0, -16.0)
	if pending_attack == "skill":
		# Three-round spread across the depth lanes.
		for dy in [-0.16, 0.0, 0.16]:
			shoot_requested.emit(muzzle, Vector2(facing, dy).normalized(), 18.0 * damage_mult, 34.0)
		impact_requested.emit(6.0, 0.05)
	else:
		shoot_requested.emit(muzzle, Vector2(facing, 0.0), 14.0 * damage_mult, 22.0)
		impact_requested.emit(3.0, 0.03)
	pending_attack = ""


# Body + recoil come from the sprite animation; base draws the shadow. A brief
# muzzle flash sells each shot.
func _draw() -> void:
	super._draw()
	if pending_attack != "" or attack_lock > 0.08:
		var m := Vector2(facing * 13.0, -16.0)
		draw_circle(m, 3.0, Color(1.0, 0.88, 0.5, 0.85))
		draw_circle(m + Vector2(facing * 3.0, 0.0), 2.0, Color(1.0, 1.0, 0.85, 0.7))
