class_name SpriteSheet
extends RefCounted

# Helpers to turn imported PNG sprite sheets / strips (e.g. ansimuz packs) into
# Godot SpriteFrames for AnimatedSprite2D. Pixel art stays crisp because the
# project forces nearest-neighbour texture filtering globally.
#
# Two common layouts are supported:
#   - one horizontal STRIP per animation (frame_w x frame_h, N frames in a row)
#   - a packed GRID sheet (rows = animations, columns = frames)
#
# Frame size and counts come from the asset's docs / page; nothing is guessed.


# Add one animation built from a horizontal strip texture. If frame_count <= 0,
# it is inferred from the texture width (texture must be exactly N frames wide).
static func add_strip(frames: SpriteFrames, anim: String, texture: Texture2D, frame_w: int, frame_h: int, fps: float = 12.0, loop: bool = true, frame_count: int = 0) -> void:
	if texture == null:
		push_warning("SpriteSheet.add_strip: missing texture for '%s'" % anim)
		return
	var count := frame_count
	if count <= 0:
		count = int(texture.get_width() / maxi(1, frame_w))
	_ensure_anim(frames, anim, fps, loop)
	for i in range(count):
		var region := Rect2(i * frame_w, 0, frame_w, frame_h)
		frames.add_frame(anim, _atlas(texture, region))


# Add one animation from a row of a packed grid sheet.
static func add_grid_row(frames: SpriteFrames, anim: String, texture: Texture2D, frame_w: int, frame_h: int, row: int, frame_count: int, fps: float = 12.0, loop: bool = true) -> void:
	if texture == null:
		push_warning("SpriteSheet.add_grid_row: missing texture for '%s'" % anim)
		return
	_ensure_anim(frames, anim, fps, loop)
	for i in range(frame_count):
		var region := Rect2(i * frame_w, row * frame_h, frame_w, frame_h)
		frames.add_frame(anim, _atlas(texture, region))


# Build a SpriteFrames from a per-animation strip manifest. Each entry:
#   { name, path, frame_w, frame_h, fps?, loop?, count? }
static func from_strip_manifest(entries: Array) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for entry in entries:
		var texture: Texture2D = load(entry.path)
		add_strip(frames, entry.name, texture, entry.frame_w, entry.frame_h,
			entry.get("fps", 12.0), entry.get("loop", true), entry.get("count", 0))
	return frames


static func _ensure_anim(frames: SpriteFrames, anim: String, fps: float, loop: bool) -> void:
	if not frames.has_animation(anim):
		frames.add_animation(anim)
	frames.set_animation_speed(anim, fps)
	frames.set_animation_loop(anim, loop)


static func _atlas(texture: Texture2D, region: Rect2) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = region
	atlas.filter_clip = true
	return atlas
