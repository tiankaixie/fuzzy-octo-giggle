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
