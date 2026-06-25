class_name SiegeCore
extends Node2D

# The reactor at the bottom of the bunker. Everything the zombies do funnels
# toward this; if its HP hits zero the run is over (permadeath).
signal destroyed

var health := 220.0
var max_health := 220.0
var flash := 0.0
var phase := 0.0
var dead := false


func setup(hp: float) -> void:
	max_health = hp
	health = hp


func _process(delta: float) -> void:
	phase += delta
	flash = maxf(0.0, flash - delta * 4.0)
	queue_redraw()


# Same signature as the combat actors so zombies can attack it uniformly.
func take_damage(amount: float, _source := Vector2.ZERO, _knockback := 0.0) -> bool:
	if dead:
		return false
	health = maxf(0.0, health - amount)
	flash = 1.0
	if health <= 0.0:
		dead = true
		destroyed.emit()
	queue_redraw()
	return true


func _draw() -> void:
	var ratio := health / max_health if max_health > 0.0 else 0.0
	var pulse := 0.55 + sin(phase * 3.0) * 0.45
	# Hot core color shifts toward red as the reactor is damaged.
	var hot := Color(1.0, 0.86, 0.5).lerp(Color(1.0, 0.36, 0.3), 1.0 - ratio)
	hot = hot.lerp(Color(1, 1, 1), flash * 0.6)
	# Armored casing.
	draw_rect(Rect2(-20, -34, 40, 36), Color("141826"))
	draw_rect(Rect2(-20, -34, 40, 36), Color("2c3550"), false, 1.0)
	draw_rect(Rect2(-22, 0, 44, 4), Color("0c0f1a"))
	# Concentric pulsing rings (reactor language from the POWER room).
	for i in range(5, 0, -1):
		var r := float(i) * 3.4 * (0.85 + pulse * 0.3)
		draw_circle(Vector2(0, -16), r, Color(hot, 0.07 * float(i) * (0.6 + ratio * 0.6)))
	draw_circle(Vector2(0, -16), 5.0 + pulse * 1.5, Color(hot, 0.95))
	draw_circle(Vector2(0, -16), 2.4, Color(1, 1, 1, 0.95))
	# Vertical conduits.
	for cx in [-13, 13]:
		draw_rect(Rect2(cx - 1.5, -30, 3, 28), Color(hot, 0.25 + pulse * 0.25))
	# HP bar above the casing.
	draw_rect(Rect2(-22, -46, 44, 5), Color("0a0d16"))
	draw_rect(Rect2(-22, -46, 44, 5), Color("39435f"), false, 1.0)
	var bar := Color("ffce5a").lerp(Color("ff4d4d"), 1.0 - ratio)
	draw_rect(Rect2(-21, -45, 42.0 * ratio, 3), bar)
