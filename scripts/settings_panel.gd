class_name SettingsPanel
extends Control

signal closed

var _first: Control
var _panel: PanelContainer


func _ready() -> void:
	theme = Game.ui_theme
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.01, 0.06, 0.7)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(620, 0)
	center.add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_panel.add_child(box)
	var title := _label("SETTINGS", 40, Color(1, 1, 1), Game.font_title)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	box.add_child(_section("AUDIO"))
	_first = _slider(box, "Master", "master")
	_slider(box, "Music", "music")
	_slider(box, "Sound effects", "sfx")
	box.add_child(_section("DISPLAY"))
	_toggle(box, "Fullscreen", "fullscreen")
	_toggle(box, "VSync", "vsync")
	_option(box, "Graphics", "quality", Game.QUALITY_NAMES)
	box.add_child(_section("GAMEPLAY"))
	_toggle(box, "Screen shake", "shake")
	_toggle(box, "Key hints on screen", "key_hints")
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	box.add_child(gap)
	var done := Button.new()
	done.text = "Done"
	done.custom_minimum_size = Vector2(0, 50)
	done.pressed.connect(close)
	done.focus_entered.connect(func() -> void: Sfx.play("hover", -14.0))
	box.add_child(done)
	_panel.pivot_offset = Vector2(310, 260)
	_panel.scale = Vector2(0.94, 0.94)
	modulate.a = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(_panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 1.0, 0.18)
	_first.call_deferred("grab_focus")


func close() -> void:
	Sfx.play("click", -4.0)
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _label(text: String, size: int, color: Color, font: Font) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _section(text: String) -> Label:
	var l := _label(text, 16, Color(0.55, 0.9, 1.0, 0.85), Game.font_title)
	l.custom_minimum_size = Vector2(0, 30)
	l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	return l


func _row(box: Container, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	var l := _label(text, 21, Color(0.9, 0.93, 1.0), Game.font_body)
	l.custom_minimum_size = Vector2(250, 0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	return row


func _slider(box: Container, text: String, key: String) -> HSlider:
	var row := _row(box, text)
	var s := HSlider.new()
	s.min_value = 0
	s.max_value = 100
	s.step = 5
	s.value = float(Game.settings[key]) * 100.0
	s.custom_minimum_size = Vector2(230, 30)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(s)
	var v := _label(str(int(s.value)), 19, Color(1.0, 0.85, 0.55), Game.font_title)
	v.custom_minimum_size = Vector2(64, 0)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(v)
	s.value_changed.connect(func(val: float) -> void:
		v.text = str(int(val))
		Game.set_setting(key, val / 100.0)
		if key != "music":
			Sfx.play("hover", -6.0, 1.0, 0.0))
	return s


func _toggle(box: Container, text: String, key: String) -> Button:
	var row := _row(box, text)
	var b := Button.new()
	b.toggle_mode = true
	b.button_pressed = bool(Game.settings[key])
	b.text = "ON" if b.button_pressed else "OFF"
	b.custom_minimum_size = Vector2(140, 42)
	b.add_theme_font_size_override("font_size", 18)
	row.add_child(b)
	b.toggled.connect(func(on: bool) -> void:
		b.text = "ON" if on else "OFF"
		Sfx.play("click", -6.0)
		Game.set_setting(key, on))
	b.focus_entered.connect(func() -> void: Sfx.play("hover", -14.0))
	return b


func _option(box: Container, text: String, key: String, names: Array) -> OptionButton:
	var row := _row(box, text)
	var o := OptionButton.new()
	for n in names:
		o.add_item(n)
	o.selected = int(Game.settings[key])
	o.custom_minimum_size = Vector2(140, 42)
	row.add_child(o)
	o.item_selected.connect(func(i: int) -> void:
		Sfx.play("click", -6.0)
		Game.set_setting(key, i))
	o.focus_entered.connect(func() -> void: Sfx.play("hover", -14.0))
	return o
