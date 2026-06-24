class_name CombatFX
extends Node2D

# Lightweight combat juice: hit sparks, kill bursts and floating damage numbers.
# One instance lives in the dungeon above the actors; the dungeon calls hit() /
# player_hit() / burst() and this ages + draws everything.

var items: Array = []


func _ready() -> void:
	z_index = 400


func _process(delta: float) -> void:
	var alive: Array = []
	for it in items:
		it.life -= delta
		match it.type:
			"spark":
				it.pos += it.vel * delta
				it.vel *= 0.86
			"burst":
				for p in it.parts:
					p.vel.y += 130.0 * delta
					p.vel *= 0.9
					p.pos += p.vel * delta
			"number":
				it.pos.y -= 28.0 * delta
		if it.life > 0.0:
			alive.append(it)
	items = alive
	queue_redraw()


func hit(pos: Vector2, amount: int, color: Color) -> void:
	for i in range(6):
		var a := randf() * TAU
		items.append({"type": "spark", "pos": pos, "vel": Vector2(cos(a), sin(a)) * randf_range(70.0, 150.0), "life": 0.22, "t0": 0.22, "color": color})
	items.append({"type": "spark", "pos": pos, "vel": Vector2.ZERO, "life": 0.12, "t0": 0.12, "color": Color.WHITE})
	number(pos, amount, Color(1.0, 0.95, 0.6))


func player_hit(pos: Vector2, amount: int) -> void:
	for i in range(4):
		var a := randf() * TAU
		items.append({"type": "spark", "pos": pos, "vel": Vector2(cos(a), sin(a)) * randf_range(50.0, 110.0), "life": 0.2, "t0": 0.2, "color": Color(1.0, 0.4, 0.4)})
	number(pos, amount, Color(1.0, 0.45, 0.45))


func number(pos: Vector2, amount: int, color: Color) -> void:
	items.append({"type": "number", "pos": pos + Vector2(randf_range(-4.0, 4.0), -16.0), "life": 0.7, "t0": 0.7, "text": str(amount), "color": color})


func burst(pos: Vector2, color: Color) -> void:
	var parts: Array = []
	for i in range(16):
		var a := randf() * TAU
		parts.append({"pos": pos, "vel": Vector2(cos(a), sin(a)) * randf_range(40.0, 160.0) - Vector2(0, 20)})
	items.append({"type": "burst", "pos": pos, "parts": parts, "life": 0.5, "t0": 0.5, "color": color})
	items.append({"type": "ring", "pos": pos, "life": 0.32, "t0": 0.32, "color": color})


func _draw() -> void:
	var font := ThemeDB.fallback_font
	for it in items:
		var f: float = clampf(it.life / it.t0, 0.0, 1.0)
		match it.type:
			"spark":
				draw_line(it.pos, it.pos - it.vel * 0.03, Color(it.color, f), maxf(1.0, 2.0 * f))
				draw_circle(it.pos, 0.6 + f, Color(it.color, f * 0.85))
			"burst":
				for p in it.parts:
					draw_rect(Rect2(p.pos - Vector2(1, 1), Vector2(2, 2)), Color(it.color, f))
			"ring":
				var r := (1.0 - f) * 16.0 + 4.0
				draw_arc(it.pos, r, 0.0, TAU, 18, Color(it.color, f * 0.7), 2)
			"number":
				var rise := 1.0 - f
				var scale := 1.2 - rise * 0.3
				for o in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
					draw_string(font, it.pos + o, it.text, HORIZONTAL_ALIGNMENT_CENTER, -1, int(9 * scale), Color(0, 0, 0, f))
				draw_string(font, it.pos, it.text, HORIZONTAL_ALIGNMENT_CENTER, -1, int(9 * scale), Color(it.color, f))
