class_name MenuBase
extends Node

var backdrop: Level
var ui: Control


func build_backdrop(index: int, centered := false) -> void:
	backdrop = Level.new()
	backdrop.menu_mode = true
	backdrop.level_index = index
	add_child(backdrop)
	var demo := _demo_echoes(index)
	for e in demo:
		backdrop.get_node("Echoes").add_child(e)
		backdrop.echoes.append(e)
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	ui = Control.new()
	ui.theme = Game.ui_theme
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(ui)
	var shade := TextureRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var g := Gradient.new()
	var t := GradientTexture2D.new()
	if centered:
		g.set_color(0, Color(0.02, 0.01, 0.06, 0.7))
		g.add_point(0.35, Color(0.02, 0.01, 0.06, 0.25))
		g.add_point(0.7, Color(0.02, 0.01, 0.06, 0.35))
		g.set_color(g.get_point_count() - 1, Color(0.02, 0.01, 0.06, 0.9))
		t.fill_from = Vector2(0, 0)
		t.fill_to = Vector2(0, 1)
	else:
		g.set_color(0, Color(0.02, 0.01, 0.06, 0.85))
		g.add_point(0.45, Color(0.02, 0.01, 0.06, 0.35))
		g.set_color(g.get_point_count() - 1, Color(0.02, 0.01, 0.06, 0.0))
		t.fill_from = Vector2(0, 0)
		t.fill_to = Vector2(1, 0)
	t.gradient = g
	shade.texture = t
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ui.add_child(shade)


func _demo_echoes(index: int) -> Array[Echo]:
	var out: Array[Echo] = []
	var lvl := backdrop
	for k in 3:
		var frames := PackedVector3Array()
		var anims := PackedByteArray()
		var x := lvl.spawn.x + 1.0 + k * 2.5
		var y := lvl.spawn.y
		var dir := 1.0
		for i in 2400:
			var nx := x + dir * 0.045
			var c := int(floor(nx + dir * 0.3))
			var r := Level.ROWS - 1 - int(round(y))
			if lvl.is_solid(c, r) or not lvl.is_solid(c, r + 1) or nx < 2.0 or nx > lvl.cols - 2.0:
				dir = -dir
				anims.append(0)
			else:
				x = nx
				anims.append(1)
			frames.append(Vector3(x, y, dir))
		var e := Echo.new()
		e.setup(frames, anims, false, Game.ECHO_COLORS[k])
		out.append(e)
	return out


func _process(_delta: float) -> void:
	if backdrop:
		var t := int(Time.get_ticks_msec() / 16.6667) % 2399
		for e in backdrop.echoes:
			e.apply_tick(t, null)


func label(text: String, size: int, color: Color, font: Font) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func button(parent: Container, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(300, 46)
	b.pressed.connect(func() -> void: Sfx.play("click", -4.0))
	b.pressed.connect(cb)
	b.focus_entered.connect(func() -> void: Sfx.play("hover", -14.0))
	b.mouse_entered.connect(func() -> void: b.grab_focus())
	parent.add_child(b)
	return b
