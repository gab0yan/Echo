class_name Hud
extends CanvasLayer

var level: Level
var root: Control
var _title: Label
var _sub: Label
var _life: Label
var _pips: HBoxContainer
var _toast: Label
var _flash: ColorRect
var _intro: Control
var _pause: Control
var _win: Control
var _keys: Label
var _toast_tween: Tween
var _flash_tween: Tween
var _status: Label


func setup(l: Level) -> void:
	level = l
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.theme = Game.ui_theme
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_flash)
	var vig := TextureRect.new()
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vig.texture = _vignette()
	vig.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vig.stretch_mode = TextureRect.STRETCH_SCALE
	root.add_child(vig)
	var box := VBoxContainer.new()
	box.position = Vector2(28, 20)
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(box)
	_sub = _label(_level_tag(), 16, Color(0.55, 0.9, 1.0, 0.9), Game.font_title)
	box.add_child(_sub)
	_title = _label(String(level.data.name).to_upper(), 30, Color(1, 1, 1), Game.font_title)
	box.add_child(_title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(row)
	_life = _label("LIFE 1", 20, Color(1.0, 0.85, 0.6), Game.font_body)
	row.add_child(_life)
	_pips = HBoxContainer.new()
	_pips.add_theme_constant_override("separation", 6)
	_pips.alignment = BoxContainer.ALIGNMENT_CENTER
	_pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_pips)
	_status = _label("", 18, Color(1.0, 0.8, 0.55, 0.95), Game.font_title)
	_status.visible = level.coop
	box.add_child(_status)
	var pause_btn := Button.new()
	var pause_icon := TextureRect.new()
	pause_icon.texture = load("res://assets/icons/pause.png")
	pause_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pause_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pause_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_icon.offset_left = 14
	pause_icon.offset_top = 13
	pause_icon.offset_right = -14
	pause_icon.offset_bottom = -13
	pause_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_btn.add_child(pause_icon)
	pause_btn.custom_minimum_size = Vector2(56, 52)
	pause_btn.anchor_left = 1.0
	pause_btn.anchor_right = 1.0
	pause_btn.offset_left = -84
	pause_btn.offset_right = -28
	pause_btn.offset_top = 24
	pause_btn.offset_bottom = 76
	pause_btn.focus_mode = Control.FOCUS_NONE
	pause_btn.pressed.connect(toggle_pause)
	root.add_child(pause_btn)
	_keys = _label("A D  move     SPACE  jump     Q  leave an echo     R  clear echoes" + ("     -     both of you must reach a beacon" if level.coop else ""), 17, Color(0.8, 0.85, 1.0, 0.6), Game.font_body)
	_keys.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_keys.offset_left = -500
	_keys.offset_right = 500
	_keys.offset_top = -44
	_keys.offset_bottom = -16
	root.add_child(_keys)
	_keys.visible = bool(Game.settings.key_hints)
	Game.settings_changed.connect(func() -> void:
		if is_instance_valid(_keys) and not level.finished:
			_keys.visible = bool(Game.settings.key_hints))
	_toast = _label("", 30, Color(0.7, 1.0, 1.0), Game.font_title)
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.offset_left = -500
	_toast.offset_right = 500
	_toast.offset_top = 110
	_toast.offset_bottom = 160
	_toast.modulate.a = 0.0
	root.add_child(_toast)
	refresh()


func _label(text: String, size: int, color: Color, font: Font) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _vignette() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0))
	g.add_point(0.62, Color(0, 0, 0, 0))
	g.set_color(g.get_point_count() - 1, Color(0.02, 0.0, 0.05, 0.55))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.05, 1.05)
	t.width = 256
	t.height = 256
	return t


func refresh() -> void:
	if not _life:
		return
	_life.text = "LIFE %d" % (level.lives_used + 1)
	for c in _pips.get_children():
		c.queue_free()
	for i in level.max_echoes:
		var p := Panel.new()
		p.custom_minimum_size = Vector2(16, 16)
		p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(8)
		if i < level.echoes.size():
			sb.bg_color = level.echoes[i].tint
			sb.shadow_color = Color(level.echoes[i].tint, 0.6)
			sb.shadow_size = 6
		else:
			sb.bg_color = Color(1, 1, 1, 0.08)
			sb.border_color = Color(0.6, 0.9, 1.0, 0.45)
			sb.set_border_width_all(2)
		p.add_theme_stylebox_override("panel", sb)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_pips.add_child(p)


func toast(text: String) -> void:
	_toast.text = text
	if _toast_tween:
		_toast_tween.kill()
	_toast.modulate.a = 0.0
	_toast.scale = Vector2.ONE
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.15)
	_toast_tween.tween_interval(1.4)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.5)


func flash(c: Color) -> void:
	if _flash_tween:
		_flash_tween.kill()
	_flash.color = c
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash, "color:a", 0.0, 0.45)


func show_intro() -> void:
	_intro = Control.new()
	_intro.set_anchors_preset(Control.PRESET_FULL_RECT)
	_intro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_intro)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.01, 0.05, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intro.add_child(shade)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER)
	v.offset_left = -520
	v.offset_right = 520
	v.offset_top = -110
	v.offset_bottom = 110
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 10)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intro.add_child(v)
	var a := _label(_level_tag(), 20, Color(0.55, 0.9, 1.0), Game.font_title)
	a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(a)
	var b := _label(String(level.data.name).to_upper(), 58, Color(1, 1, 1), Game.font_title)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(b)
	var c := _label(level.data.get("log", ""), 22, Color(0.9, 0.8, 1.0, 0.85), Game.font_body)
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(c)
	_intro.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(_intro, "modulate:a", 1.0, 0.35)
	t.tween_interval(2.2)
	t.tween_property(_intro, "modulate:a", 0.0, 0.7)
	t.tween_callback(_intro.queue_free)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not (_win and _win.visible) and not root.get_children().any(func(c: Node) -> bool: return c is SettingsPanel):
		toggle_pause()
		get_viewport().set_input_as_handled()


func _level_tag() -> String:
	return ("CO-OP %d" if level.coop else "LEVEL %d") % (level.level_index + 1)


func set_status(t: String) -> void:
	if _status:
		_status.text = t


func toggle_pause() -> void:
	if level.finished:
		return
	if level.coop:
		_toggle_coop_pause()
		return
	var tree := get_tree()
	if tree.paused:
		tree.paused = false
		if _pause:
			_pause.queue_free()
			_pause = null
		return
	tree.paused = true
	Sfx.play("click", -6.0)
	_pause = _panel("PAUSED", "Subject 712 is waiting.")
	var box: VBoxContainer = _pause.get_meta("box")
	_button(box, "Resume", toggle_pause)
	_button(box, "Clear echoes", func() -> void:
		toggle_pause()
		level.full_restart())
	var settings_btn := _button(box, "Settings", func() -> void: pass)
	settings_btn.pressed.connect(func() -> void:
		var sp := SettingsPanel.new()
		root.add_child(sp)
		sp.closed.connect(func() -> void: settings_btn.grab_focus()))
	_button(box, "Levels", Game.go_level_select)
	_button(box, "Main menu", Game.go_menu)
	(box.get_child(2) as Button).call_deferred("grab_focus")


func _toggle_coop_pause() -> void:
	if _pause:
		_pause.queue_free()
		_pause = null
		return
	Sfx.play("click", -6.0)
	_pause = _panel("MENU", "The game keeps running for your partner.")
	var box: VBoxContainer = _pause.get_meta("box")
	_button(box, "Resume", _toggle_coop_pause)
	_button(box, "Clear echoes", func() -> void:
		_toggle_coop_pause()
		if level.net_role == "client":
			Net.request_reset()
		else:
			level.full_restart())
	var settings_btn := _button(box, "Settings", func() -> void: pass)
	settings_btn.pressed.connect(func() -> void:
		var sp := SettingsPanel.new()
		root.add_child(sp)
		sp.closed.connect(func() -> void: settings_btn.grab_focus()))
	_button(box, "Leave session" if Net.is_online else "Co-op menu", func() -> void:
		if Net.is_online:
			Net.request_leave()
		else:
			Game.go_coop_menu())
	(box.get_child(2) as Button).call_deferred("grab_focus")


func _panel(title: String, subtitle: String) -> Control:
	var wrap := Control.new()
	wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(wrap)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.01, 0.06, 0.6)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	wrap.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	wrap.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(440, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var t := _label(title, 40, Color(1, 1, 1), Game.font_title)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	var s := _label(subtitle, 20, Color(0.8, 0.85, 1.0, 0.8), Game.font_body)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(s)
	wrap.set_meta("box", box)
	wrap.set_meta("panel", panel)
	panel.pivot_offset = Vector2(220, 150)
	panel.scale = Vector2(0.92, 0.92)
	panel.modulate.a = 0.0
	var tw := wrap.create_tween().set_parallel()
	tw.tween_property(panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "modulate:a", 1.0, 0.2)
	return wrap


func _button(box: Container, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 50)
	b.pressed.connect(func() -> void: Sfx.play("click", -4.0))
	b.pressed.connect(cb)
	b.focus_entered.connect(func() -> void: Sfx.play("hover", -14.0))
	b.mouse_entered.connect(func() -> void: b.grab_focus())
	box.add_child(b)
	return b


func show_win(stars: int, lives: int) -> void:
	var last := level.level_index >= Levels.count() - 1
	var lines := ["Lives used: %d   (par %d)" % [lives, level.data.par]]
	_win = _panel("BEACON REACHED", lines[0])
	var box: VBoxContainer = _win.get_meta("box")
	var star_row := HBoxContainer.new()
	star_row.alignment = BoxContainer.ALIGNMENT_CENTER
	star_row.add_theme_constant_override("separation", 14)
	box.add_child(star_row)
	box.move_child(star_row, 1)
	for i in 3:
		var s := StarIcon.new()
		s.custom_minimum_size = Vector2(54, 54)
		s.lit = i < stars
		star_row.add_child(s)
		s.pivot_offset = Vector2(27, 27)
		s.scale = Vector2.ZERO
		var tw := s.create_tween()
		tw.tween_interval(0.25 + i * 0.18)
		tw.tween_property(s, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var note := _label(_win_line(stars), 19, Color(0.75, 1.0, 0.95, 0.9), Game.font_body)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(note)
	var first: Button
	if level.coop:
		_coop_win_buttons(box)
		return
	if last:
		first = _button(box, "Epilogue", func() -> void: Game.change_scene("res://scenes/ending.tscn"))
	else:
		first = _button(box, "Next level", func() -> void: Game.play_level(level.level_index + 1))
	_button(box, "Retry", func() -> void: Game.play_level(level.level_index))
	_button(box, "Levels", Game.go_level_select)
	first.call_deferred("grab_focus")
	_keys.visible = false


func _coop_win_buttons(box: VBoxContainer) -> void:
	_keys.visible = false
	if _pause:
		_pause.queue_free()
		_pause = null
	var i := level.level_index
	if level.net_role == "client":
		var w := _label("Waiting for the host to choose what is next...", 18, Color(1.0, 0.85, 0.55), Game.font_body)
		w.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(w)
		_button(box, "Leave session", Net.request_leave).call_deferred("grab_focus")
		return
	var go := func(n: int) -> void:
		if Net.is_online:
			Net.start_level(n)
		else:
			Game.play_coop(n)
	var first: Button
	if i < Levels.coop_count() - 1:
		first = _button(box, "Next co-op level", func() -> void: go.call(i + 1))
		_button(box, "Retry", func() -> void: go.call(i))
	else:
		var fin := _label("You finished every co-op level together!", 18, Color(1.0, 0.85, 0.55), Game.font_body)
		fin.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(fin)
		first = _button(box, "Play again", func() -> void: go.call(0))
	_button(box, "Co-op menu", func() -> void: Game.go_coop_menu())
	first.call_deferred("grab_focus")


func _win_line(stars: int) -> String:
	match stars:
		3:
			return "Perfect. Not a single wasted life."
		2:
			return "Good. Can you do it with fewer echoes?"
	return "You made it. The Echo remembers."
