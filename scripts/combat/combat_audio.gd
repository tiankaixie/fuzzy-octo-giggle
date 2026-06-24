class_name CombatAudio
extends Node

var streams: Dictionary = {}
var players: Array[AudioStreamPlayer] = []
var pool_index := 0


func _ready() -> void:
	streams = {
		"swing": _make_sound(170.0, 85.0, 0.10, 0.18),
		"hit": _make_sound(95.0, 42.0, 0.09, 0.55),
		"skill": _make_sound(260.0, 620.0, 0.22, 0.12),
		"dodge": _make_sound(420.0, 150.0, 0.13, 0.25),
		"hurt": _make_sound(120.0, 70.0, 0.16, 0.4),
		"shot": _make_sound(540.0, 320.0, 0.12, 0.08),
		"clear": _make_sound(310.0, 780.0, 0.42, 0.04),
	}
	for i in range(8):
		var player := AudioStreamPlayer.new()
		player.volume_db = -7.0
		add_child(player)
		players.append(player)


func play_sfx(id: String) -> void:
	if not streams.has(id) or players.is_empty():
		return
	var player := players[pool_index]
	pool_index = (pool_index + 1) % players.size()
	player.stream = streams[id]
	player.pitch_scale = 0.96 + randf() * 0.08
	player.play()


func _make_sound(start_frequency: float, end_frequency: float, duration: float, noise_amount: float) -> AudioStreamWAV:
	var mix_rate := 22050
	var sample_count := maxi(1, int(duration * mix_rate))
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	var phase := 0.0
	for i in range(sample_count):
		var t := float(i) / float(sample_count)
		var frequency := lerpf(start_frequency, end_frequency, t)
		phase += TAU * frequency / float(mix_rate)
		var envelope := pow(1.0 - t, 2.2) * minf(1.0, t * 45.0)
		var sample := sin(phase) * (1.0 - noise_amount) + randf_range(-1.0, 1.0) * noise_amount
		var pcm := int(clampf(sample * envelope * 0.72, -1.0, 1.0) * 32767.0)
		if pcm < 0:
			pcm += 65536
		bytes[i * 2] = pcm & 0xff
		bytes[i * 2 + 1] = (pcm >> 8) & 0xff
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = mix_rate
	stream.stereo = false
	stream.data = bytes
	return stream

