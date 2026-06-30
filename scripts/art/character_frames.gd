class_name CharacterFrames
extends RefCounted

# Builds (and caches) a SpriteFrames per character id from the imported CraftPix
# cyberpunk sprite strips (assets/cyberpunk_chars/, OGA-BY 3.0 — see CREDITS.md).
# Every strip is 48x48 frames laid out horizontally.

const SpriteSheetClass := preload("res://scripts/art/sprite_sheet.gd")
const BASE := "res://assets/cyberpunk_chars/"
const FRAME := 48

# anim name -> [file, frame_count, fps, loop]
const ANIMS := {
	"idle": ["idle", 4, 7.0, true],
	"run": ["run", 6, 13.0, true],
	"attack1": ["attack1", 6, 18.0, false],
	"attack2": ["attack2", 8, 18.0, false],
	"attack3": ["attack3", 8, 17.0, false],
	"punch": ["punch", 6, 20.0, false],
	"hurt": ["hurt", 2, 9.0, false],
	"jump": ["jump", 4, 13.0, false],
	"death": ["death", 6, 12.0, false],
}

static var _cache := {}


static func get_frames(character_id: String) -> SpriteFrames:
	if _cache.has(character_id):
		return _cache[character_id]
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for anim in ANIMS:
		var spec: Array = ANIMS[anim]
		var texture: Texture2D = load(BASE + character_id + "/" + spec[0] + ".png")
		SpriteSheetClass.add_strip(sf, anim, texture, FRAME, FRAME, spec[2], spec[3], spec[1])
	_cache[character_id] = sf
	return sf


# Warped City player (ansimuz, CC0): one PNG per frame under
# assets/warped_city/player/<anim>/. Ranged gunner — attack states use "shoot".
const WC_PLAYER_DIR := "res://assets/warped_city/player/"
const WC_ANIMS := {
	"idle": [4.0, 7.0, true],
	"run": [8.0, 13.0, true],
	"shoot": [1.0, 14.0, false],
	"jump": [4.0, 12.0, false],
	"hurt": [1.0, 9.0, false],
}
static var _wc_player: SpriteFrames


static func get_warped_player() -> SpriteFrames:
	if _wc_player:
		return _wc_player
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for anim in WC_ANIMS:
		var spec: Array = WC_ANIMS[anim]
		sf.add_animation(anim)
		sf.set_animation_speed(anim, spec[1])
		sf.set_animation_loop(anim, spec[2])
		for frame_path in _wc_frame_paths(WC_PLAYER_DIR + anim):
			sf.add_frame(anim, load(frame_path))
	_wc_player = sf
	return sf


static func _wc_frame_paths(dir_path: String) -> Array:
	var out: Array = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	for f in dir.get_files():
		if f.ends_with(".png"):
			out.append(dir_path + "/" + f)
	out.sort()
	return out


# User-authored operator (sprite-ai.art, 64x64 transparent): an 8-frame idle
# cycle under assets/bunker/chars/operator/. Only idle exists, so every state
# aliases to it (clean look now; richer anims swap in when the user adds them).
const OP_DIR := "res://assets/bunker/chars/operator/"
static var _operator: SpriteFrames


static func get_operator() -> SpriteFrames:
	if _operator:
		return _operator
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var frames: Array = []
	for i in range(8):
		var p := OP_DIR + "idle_%d.png" % i
		if ResourceLoader.exists(p):
			frames.append(load(p))
	for anim in ["idle", "run", "shoot", "jump", "hurt", "death"]:
		sf.add_animation(anim)
		sf.set_animation_speed(anim, 8.0)
		sf.set_animation_loop(anim, anim == "idle" or anim == "run")
		for fr in frames:
			sf.add_frame(anim, fr)
	_operator = sf
	return sf
