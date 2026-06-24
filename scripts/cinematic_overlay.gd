class_name CinematicOverlay
extends CanvasLayer

# Screen-space cinematic post layer shared by every world, pushing the look
# toward the reference art (cinematic pixel-noir): a per-scene colour grade, a
# fog/haze gradient, an edge vignette, atmospheric particles and thin letterbox
# bars. Sits below the HUD (layer 60) so UI stays crisp on top.

const W := 480.0
const H := 270.0

var grade_color := Color(0, 0, 0, 0)
var fog_color := Color(0.5, 0.5, 0.6)
var fog_strength := 0.12
var vignette_strength := 0.6
var particle_kind := "none"  # rain / snow / embers / dust
var particle_count := 50
var letterbox := 12.0
var time := 0.0
var _canvas: Node2D


func _ready() -> void:
	layer = 50
	_canvas = Node2D.new()
	_canvas.draw.connect(_draw_overlay)
	add_child(_canvas)


func configure(preset: Dictionary) -> void:
	grade_color = preset.get("grade", grade_color)
	fog_color = preset.get("fog", fog_color)
	fog_strength = preset.get("fog_strength", fog_strength)
	vignette_strength = preset.get("vignette", vignette_strength)
	particle_kind = preset.get("particles", particle_kind)
	particle_count = preset.get("count", particle_count)
	letterbox = preset.get("letterbox", letterbox)
	if is_instance_valid(_canvas):
		_canvas.queue_redraw()


func _process(delta: float) -> void:
	time += delta
	if is_instance_valid(_canvas):
		_canvas.queue_redraw()


func _draw_overlay() -> void:
	var c := _canvas
	# Monochromatic grade wash unifies the palette toward the scene's hue.
	if grade_color.a > 0.0:
		c.draw_rect(Rect2(0, 0, W, H), grade_color)
	# Atmospheric fog, densest around the horizon band.
	for i in range(12):
		var t := float(i) / 11.0
		var a := fog_strength * (0.25 + 0.75 * sin(t * PI))
		c.draw_rect(Rect2(0, t * H, W, H / 12.0 + 1.0), Color(fog_color.r, fog_color.g, fog_color.b, a))
	_draw_particles(c)
	_draw_vignette(c)
	if letterbox > 0.0:
		c.draw_rect(Rect2(0, 0, W, letterbox), Color(0, 0, 0, 1))
		c.draw_rect(Rect2(0, H - letterbox, W, letterbox), Color(0, 0, 0, 1))
		c.draw_rect(Rect2(0, letterbox, W, 1), Color(0, 0, 0, 0.35))
		c.draw_rect(Rect2(0, H - letterbox - 1.0, W, 1), Color(0, 0, 0, 0.35))


func _draw_vignette(c: Node2D) -> void:
	var n := 18
	for i in range(n):
		var edge := pow(float(n - i) / float(n), 2.2)
		c.draw_rect(Rect2(i, i, W - 2 * i, H - 2 * i), Color(0, 0, 0, vignette_strength * edge * 0.05), false, 1)


func _draw_particles(c: Node2D) -> void:
	match particle_kind:
		"rain":
			for i in range(particle_count):
				var x := fmod(float(i * 53), W)
				var y := fmod(float(i * 29) + time * 260.0, H + 20.0) - 10.0
				c.draw_line(Vector2(x, y), Vector2(x - 2.0, y + 9.0), Color(0.62, 0.72, 0.92, 0.22), 1)
		"snow":
			for i in range(particle_count):
				var x := fmod(float(i * 47) + sin(time * 0.6 + float(i)) * 10.0, W)
				var y := fmod(float(i * 31) + time * 26.0, H)
				c.draw_circle(Vector2(x, y), 1.0, Color(0.85, 0.88, 0.96, 0.5))
		"embers":
			for i in range(particle_count):
				var x := fmod(float(i * 43) + sin(time * 1.3 + float(i)) * 7.0, W)
				var y := H - fmod(float(i * 37) + time * 42.0, H + 20.0)
				var flick := 0.5 + 0.5 * sin(time * 6.0 + float(i) * 1.7)
				c.draw_circle(Vector2(x, y), 1.0, Color(1.0, 0.6 + 0.2 * flick, 0.25, 0.35 + flick * 0.4))
		"dust":
			for i in range(particle_count):
				var x := fmod(float(i * 61) + sin(time * 0.3 + float(i)) * 12.0, W)
				var y := fmod(float(i * 41) + sin(time * 0.22 + float(i) * 1.7) * 16.0, H)
				c.draw_circle(Vector2(x, y), 1.0, Color(0.9, 0.82, 0.66, 0.12))
