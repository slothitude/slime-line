class_name Art
extends Object
## Asset front for spec law "original_assets" (Flux sprites in
## assets/generated/). If a png is missing — or not imported yet — we hand back
## a flat code-drawn placeholder and NEVER block. Milestone gate never waits
## on art.

const GENERATED_DIR := "res://assets/generated/"
const PLACEHOLDER_SIZE := 48
const PLACEHOLDER_TILE_SIZE := 32


## Texture for an art key ("slug_player", "bug_green", ...): the generated png
## when present, else a placeholder blob.
static func tex(key: String) -> Texture2D:
	var path := GENERATED_DIR + key + ".png"
	if FileAccess.file_exists(path) and ResourceLoader.exists(path):
		var res: Texture2D = load(path)
		if res != null:
			return res
	return placeholder(key)


static func placeholder(key: String) -> Texture2D:
	var size := PLACEHOLDER_SIZE
	if key == "tile_garden":
		size = PLACEHOLDER_TILE_SIZE
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var fill := _color_for(key)
	var rim := fill.darkened(0.45)
	var half := float(size) * 0.5
	for y in size:
		for x in size:
			var dx := (float(x) + 0.5 - half) / (half - 1.0)
			var dy := (float(y) + 0.5 - half) / (half - 1.0)
			var d := dx * dx + dy * dy
			if d <= 1.0:
				if d > 0.72:
					img.set_pixel(x, y, rim)
				else:
					img.set_pixel(x, y, fill)
			elif key == "tile_garden":
				img.set_pixel(x, y, fill.darkened(0.25))
	return ImageTexture.create_from_image(img)


static func _color_for(key: String) -> Color:
	match key:
		"slug_player":
			return Color(0.42, 0.78, 0.36)
		"bug_green":
			return Color(0.35, 0.72, 0.30)
		"bug_gold":
			return Color(0.95, 0.78, 0.22)
		"salt_crystal":
			return Color(0.96, 0.97, 1.0)
		"tile_garden":
			return Color(0.13, 0.28, 0.14)
		"title_logo":
			return Color(0.80, 0.85, 0.70)
	return Color(0.6, 0.6, 0.6)
