class_name TouchControls
extends CanvasLayer

const CYAN := Color(0.35, 0.95, 1.0)
const ECHO := Color(0.75, 0.55, 1.0)
const JUMP := Color(1.0, 0.75, 0.4)

var _buttons: Array[TouchScreenButton] = []
var _specs: Array = []


func _ready() -> void:
	layer = 11
	_add("arrowLeft", "move_left", 120.0, CYAN)
	_add("arrowRight", "move_right", 120.0, CYAN)
	_add("rewind", "echo", 104.0, ECHO)
	_add("arrowUp", "jump", 148.0, JUMP)
	get_viewport().size_changed.connect(_layout)
	_layout()


func _add(icon: String, action: String, d: float, col: Color) -> void:
	var b := TouchScreenButton.new()
	b.texture_normal = _make_texture(icon, d, col, false)
	b.texture_pressed = _make_texture(icon, d, col, true)
	var shape := CircleShape2D.new()
	shape.radius = d * 0.55
	b.shape = shape
	b.shape_centered = true
	b.action = action
	b.passby_press = action == "move_left" or action == "move_right"
	b.visibility_mode = TouchScreenButton.VISIBILITY_ALWAYS
	add_child(b)
	_buttons.append(b)
	_specs.append(d)


func _layout() -> void:
	var vp := get_viewport().get_visible_rect().size
	var m := 34.0
	var bottom := vp.y - m
	_buttons[0].position = Vector2(m, bottom - _specs[0])
	_buttons[1].position = Vector2(m + _specs[0] + 22.0, bottom - _specs[1])
	_buttons[3].position = Vector2(vp.x - m - _specs[3], bottom - _specs[3])
	_buttons[2].position = Vector2(vp.x - m - _specs[3] - 26.0 - _specs[2], bottom - _specs[2] - 6.0)


func _make_texture(icon: String, d: float, col: Color, pressed: bool) -> ImageTexture:
	var size := int(d)
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(size, size) * 0.5
	var r := size * 0.5 - 2.0
	var fill := Color(0.04, 0.03, 0.1, 0.55 if not pressed else 0.8)
	var ring := Color(col, 0.55 if not pressed else 1.0)
	for y in size:
		for x in size:
			var dist := Vector2(x + 0.5, y + 0.5).distance_to(c)
			if dist > r + 1.0:
				continue
			var a := clampf(r + 1.0 - dist, 0.0, 1.0)
			var px := fill
			if dist > r - 4.0:
				px = ring
			elif pressed:
				px = fill.lerp(Color(col, 0.8), 0.35)
			img.set_pixel(x, y, Color(px, px.a * a))
	var tex: Texture2D = load("res://assets/icons/%s.png" % icon)
	var ic := tex.get_image()
	ic.decompress()
	ic.convert(Image.FORMAT_RGBA8)
	var isz := int(size * 0.46)
	ic.resize(isz, isz, Image.INTERPOLATE_BILINEAR)
	var tint := Color(1, 1, 1) if pressed else col.lerp(Color.WHITE, 0.35)
	for y in isz:
		for x in isz:
			var p := ic.get_pixel(x, y)
			if p.a > 0.0:
				ic.set_pixel(x, y, Color(tint, p.a * (1.0 if pressed else 0.9)))
	img.blend_rect(ic, Rect2i(0, 0, isz, isz), Vector2i((size - isz) / 2, (size - isz) / 2))
	return ImageTexture.create_from_image(img)
