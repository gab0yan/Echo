extends MenuBase

const CYAN := Color(0.35, 0.95, 1.0)
const ORANGE := Color(1.0, 0.65, 0.3)
const ERROR := Color(1.0, 0.5, 0.45)

var _status: Label
var _stage: Control
var _server_chip: Label
var _code_edit: LineEdit
var _dots: Label
var _dots_t := 0.0
var _spinner: Control
var _popup: Control


func _ready() -> void:
	build_backdrop(12, true)
	var title := label("MULTIPLAYER", 60, Color(1, 1, 1), Game.font_title)
	title.add_theme_color_override("font_outline_color", Color(1.0, 0.65, 0.3, 0.45))
	title.add_theme_constant_override("outline_size", 8)
	_center_top(title, 34, 110)
	ui.add_child(title)
	var sub := label("Play online with a friend. Both of you must reach a beacon.", 20, Color(0.75, 0.92, 1.0, 0.85), Game.font_body)
	_center_top(sub, 106, 136)
	ui.add_child(sub)
	_status = label("", 20, CYAN, Game.font_title)
	_center_top(_status, 146, 176)
	ui.add_child(_status)
	_stage = Control.new()
	_stage.position = Vector2(140, 190)
	_stage.size = Vector2(1000, 440)
	ui.add_child(_stage)
	var back := _round_button("exitLeft", "Back", _on_back)
	back.position = Vector2(40, 630)
	ui.add_child(back)
	var srv := _round_button("wrench", "Room server", _open_server_popup)
	srv.position = Vector2(1168, 630)
	ui.add_child(srv)
	_server_chip = label("", 15, Color(0.75, 0.85, 1.0, 0.7), Game.font_title)
	_server_chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_server_chip.position = Vector2(760, 648)
	_server_chip.size = Vector2(390, 30)
	ui.add_child(_server_chip)
	Net.state_changed.connect(_rebuild)
	Net.status_changed.connect(_on_status)
	Net.session_ended.connect(func(_r: String) -> void: _rebuild())
	if Game.menu_message != "":
		_on_status(Game.menu_message, true)
		Game.menu_message = ""
	elif Net.status != "" and Net.state != Net.State.OFFLINE:
		_on_status(Net.status, Net.status_is_error)
	else:
		_on_status("Create a room, or join one with a code.")
	_rebuild()


func _center_top(l: Label, top: float, bottom: float) -> void:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	l.offset_left = -600
	l.offset_right = 600
	l.offset_top = top
	l.offset_bottom = bottom


func _on_status(t: String, error := false) -> void:
	if not is_instance_valid(_status):
		return
	_status.text = t
	var bad := error or (t == Net.status and Net.status_is_error)
	_status.add_theme_color_override("font_color", ERROR if bad else CYAN)


func _style(col: Color, bg_a: float, border_a: float, width: int, radius := 22) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.04, 0.1, bg_a)
	sb.border_color = Color(col, border_a)
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(radius)
	sb.shadow_color = Color(col, 0.2 * border_a)
	sb.shadow_size = 14
	sb.set_content_margin_all(24)
	return sb


func _card(col: Color) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _style(col, 0.82, 0.6, 2))
	return p


func _icon(name: String, size: float, col: Color) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = load("res://assets/icons/%s.png" % name)
	tr.custom_minimum_size = Vector2(size, size)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.modulate = col
	tr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


func _action(text: String, col: Color, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 54)
	b.add_theme_stylebox_override("normal", _style(col, 0.6, 0.55, 2, 14))
	b.add_theme_stylebox_override("hover", _style(col, 0.9, 1.0, 3, 14))
	b.add_theme_stylebox_override("pressed", _style(col, 1.0, 1.0, 3, 14))
	var f := _style(col, 0.0, 1.0, 3, 14)
	f.draw_center = false
	b.add_theme_stylebox_override("focus", f)
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(func() -> void: Sfx.play("click", -4.0))
	b.pressed.connect(cb)
	b.focus_entered.connect(func() -> void: Sfx.play("hover", -14.0))
	b.mouse_entered.connect(func() -> void: b.grab_focus())
	return b


func _round_button(icon: String, tip: String, cb: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(64, 64)
	b.size = Vector2(64, 64)
	b.tooltip_text = tip
	var n := StyleBoxFlat.new()
	n.bg_color = Color(0.06, 0.05, 0.12, 0.85)
	n.border_color = Color(CYAN, 0.4)
	n.set_border_width_all(2)
	n.set_corner_radius_all(32)
	var h := n.duplicate() as StyleBoxFlat
	h.border_color = CYAN
	h.bg_color = Color(0.12, 0.12, 0.24, 0.95)
	var fo := h.duplicate() as StyleBoxFlat
	fo.draw_center = false
	fo.border_color = Color(1.0, 0.75, 0.35)
	fo.set_border_width_all(3)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", h)
	b.add_theme_stylebox_override("focus", fo)
	var tr := _icon(icon, 30, Color(0.85, 0.95, 1.0))
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tr.offset_left = 16
	tr.offset_top = 16
	tr.offset_right = -16
	tr.offset_bottom = -16
	b.add_child(tr)
	b.pressed.connect(func() -> void: Sfx.play("click", -4.0))
	b.pressed.connect(cb)
	b.focus_entered.connect(func() -> void: Sfx.play("hover", -14.0))
	return b


func _clear_stage() -> void:
	for c in _stage.get_children():
		c.queue_free()
	_dots = null
	_spinner = null
	_code_edit = null


func _rebuild() -> void:
	if not is_instance_valid(_stage):
		return
	_clear_stage()
	_server_chip.text = "ROOM SERVER  %s" % Net.server_address()
	match Net.state:
		Net.State.OFFLINE:
			_view_choose()
		Net.State.CONNECTING:
			_view_connecting()
		Net.State.WAITING:
			_view_waiting()
		Net.State.PAIRED:
			_view_paired()
	_stage.modulate.a = 0.0
	create_tween().tween_property(_stage, "modulate:a", 1.0, 0.25)


func _view_choose() -> void:
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 40)
	_stage.add_child(row)
	var create := _card(CYAN)
	create.custom_minimum_size = Vector2(420, 380)
	row.add_child(create)
	var cv := VBoxContainer.new()
	cv.alignment = BoxContainer.ALIGNMENT_CENTER
	cv.add_theme_constant_override("separation", 14)
	create.add_child(cv)
	cv.add_child(_icon("plus", 84, CYAN))
	var ct := label("CREATE ROOM", 32, Color(1, 1, 1), Game.font_title)
	ct.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(ct)
	var cd := label("Get a room code\nand send it to your friend.", 19, Color(0.8, 0.95, 1.0, 0.85), Game.font_body)
	cd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(cd)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 52)
	cv.add_child(gap)
	var cb := _action("Create", CYAN, func() -> void: Net.create_room())
	cv.add_child(cb)
	var join := _card(ORANGE)
	join.custom_minimum_size = Vector2(420, 380)
	row.add_child(join)
	var jv := VBoxContainer.new()
	jv.alignment = BoxContainer.ALIGNMENT_CENTER
	jv.add_theme_constant_override("separation", 14)
	join.add_child(jv)
	jv.add_child(_icon("import", 84, ORANGE))
	var jt := label("JOIN ROOM", 32, Color(1, 1, 1), Game.font_title)
	jt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	jv.add_child(jt)
	var jd := label("Type the code\nyour friend sent you.", 19, Color(1.0, 0.9, 0.8, 0.85), Game.font_body)
	jd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	jv.add_child(jd)
	_code_edit = LineEdit.new()
	_code_edit.placeholder_text = "CODE"
	_code_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_code_edit.max_length = Net.CODE_LENGTH
	_code_edit.custom_minimum_size = Vector2(0, 58)
	_code_edit.add_theme_font_override("font", Game.font_title)
	_code_edit.add_theme_font_size_override("font_size", 34)
	_code_edit.add_theme_stylebox_override("normal", _style(ORANGE, 0.7, 0.5, 2, 14))
	_code_edit.add_theme_stylebox_override("focus", _style(ORANGE, 0.85, 1.0, 3, 14))
	_code_edit.text_changed.connect(func(t: String) -> void:
		var clean := Net.clean_code(t)
		if clean != t:
			_code_edit.text = clean
			_code_edit.caret_column = clean.length())
	_code_edit.text_submitted.connect(func(_t: String) -> void: Net.join_room(_code_edit.text))
	jv.add_child(_code_edit)
	var jb := _action("Join", ORANGE, func() -> void: Net.join_room(_code_edit.text))
	jv.add_child(jb)
	cb.call_deferred("grab_focus")


func _view_connecting() -> void:
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 22)
	_stage.add_child(v)
	var holder := CenterContainer.new()
	holder.custom_minimum_size = Vector2(0, 110)
	v.add_child(holder)
	_spinner = _icon("signal3", 90, CYAN)
	_spinner.pivot_offset = Vector2(45, 45)
	holder.add_child(_spinner)
	var l := label("Talking to the room server", 26, Color(1, 1, 1), Game.font_title)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	_dots = label("", 26, CYAN, Game.font_title)
	_dots.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_dots)
	var c := CenterContainer.new()
	v.add_child(c)
	var cancel := _action("Cancel", ERROR, func() -> void:
		Net.leave()
		_on_status("Cancelled."))
	cancel.custom_minimum_size = Vector2(240, 54)
	c.add_child(cancel)
	cancel.call_deferred("grab_focus")


func _view_waiting() -> void:
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage.add_child(c)
	var card := _card(CYAN)
	card.custom_minimum_size = Vector2(640, 400)
	c.add_child(card)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 16)
	card.add_child(v)
	var t := label("YOUR ROOM CODE", 20, Color(CYAN, 0.9), Game.font_title)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var letters := HBoxContainer.new()
	letters.alignment = BoxContainer.ALIGNMENT_CENTER
	letters.add_theme_constant_override("separation", 12)
	v.add_child(letters)
	for i in Net.room_code.length():
		var box := PanelContainer.new()
		var sb := _style(CYAN, 0.9, 0.9, 2, 14)
		sb.set_content_margin_all(8)
		box.add_theme_stylebox_override("panel", sb)
		box.custom_minimum_size = Vector2(84, 100)
		var ch := label(Net.room_code[i], 64, Color(1, 1, 1), Game.font_title)
		ch.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ch.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		box.add_child(ch)
		letters.add_child(box)
		box.pivot_offset = Vector2(42, 50)
		box.scale = Vector2(0.3, 0.3)
		box.modulate.a = 0.0
		var tw := box.create_tween().set_parallel()
		tw.tween_property(box, "scale", Vector2.ONE, 0.35).set_delay(0.06 * i).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(box, "modulate:a", 1.0, 0.2).set_delay(0.06 * i)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	v.add_child(row)
	var copy := _action("Copy code", CYAN, func() -> void:
		DisplayServer.clipboard_set(Net.room_code)
		_on_status("Code %s copied. Paste it to your friend." % Net.room_code))
	copy.custom_minimum_size = Vector2(240, 54)
	row.add_child(copy)
	var close := _action("Close room", ERROR, func() -> void:
		Net.leave()
		_on_status("Room closed."))
	close.custom_minimum_size = Vector2(240, 54)
	row.add_child(close)
	_dots = label("", 22, Color(1.0, 0.85, 0.55), Game.font_title)
	_dots.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dots.set_meta("base", "Waiting for your friend")
	v.add_child(_dots)
	copy.call_deferred("grab_focus")


func _player_chip(idx: int, col: Color, sub: String, ready: bool) -> PanelContainer:
	var p := _card(col)
	p.custom_minimum_size = Vector2(330, 0)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	p.add_child(h)
	h.add_child(_icon("singleplayer", 48, col))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	v.add_child(label("PLAYER %d" % idx, 24, Color(1, 1, 1), Game.font_title))
	v.add_child(label(sub, 17, Color(col.lerp(Color.WHITE, 0.4), 0.9), Game.font_body))
	if ready:
		h.add_child(_icon("checkmark", 34, Color(0.5, 1.0, 0.6)))
	return p


func _view_paired() -> void:
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("separation", 18)
	_stage.add_child(v)
	var chips := HBoxContainer.new()
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	chips.add_theme_constant_override("separation", 22)
	v.add_child(chips)
	chips.add_child(_player_chip(1, CYAN, "You  -  host" if Net.is_host else "Your friend  -  host", true))
	var vs := label("ROOM\n%s" % Net.room_code, 18, Color(0.85, 0.9, 1.0, 0.8), Game.font_title)
	vs.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vs.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chips.add_child(vs)
	chips.add_child(_player_chip(2, ORANGE, "Your friend" if Net.is_host else "You", true))
	if Net.is_host:
		var t := label("CHOOSE A LEVEL", 22, Color(1, 1, 1), Game.font_title)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(t)
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 16)
		grid.add_theme_constant_override("v_separation", 14)
		var gc := CenterContainer.new()
		gc.add_child(grid)
		v.add_child(gc)
		var first: Button
		for i in Levels.coop_count():
			var b := _level_card(i)
			grid.add_child(b)
			if first == null:
				first = b
		first.call_deferred("grab_focus")
	else:
		var holder := CenterContainer.new()
		holder.custom_minimum_size = Vector2(0, 120)
		v.add_child(holder)
		_spinner = _icon("multiplayer", 80, ORANGE)
		_spinner.pivot_offset = Vector2(40, 40)
		holder.add_child(_spinner)
		_dots = label("", 24, Color(1.0, 0.85, 0.55), Game.font_title)
		_dots.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_dots.set_meta("base", "The host is choosing a level")
		v.add_child(_dots)
	var c := CenterContainer.new()
	v.add_child(c)
	var leave := _action("Leave room", ERROR, func() -> void:
		Net.leave()
		_on_status("You left the room."))
	leave.custom_minimum_size = Vector2(240, 50)
	c.add_child(leave)


func _level_card(i: int) -> Button:
	var lv: Dictionary = Levels.get_coop(i)
	var b := Button.new()
	b.custom_minimum_size = Vector2(300, 84)
	b.add_theme_stylebox_override("normal", _style(ORANGE, 0.7, 0.4, 2, 16))
	b.add_theme_stylebox_override("hover", _style(ORANGE, 0.9, 1.0, 3, 16))
	b.add_theme_stylebox_override("pressed", _style(ORANGE, 1.0, 1.0, 3, 16))
	var f := _style(ORANGE, 0.0, 1.0, 3, 16)
	f.draw_center = false
	b.add_theme_stylebox_override("focus", f)
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 18
	h.offset_right = -14
	h.add_theme_constant_override("separation", 12)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	var num := label(str(i + 1), 40, ORANGE, Game.font_title)
	num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(num)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	var n := label(String(lv.name).to_upper(), 19, Color(1, 1, 1), Game.font_title)
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(n)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(row)
	for k in 3:
		var s := StarIcon.new()
		s.custom_minimum_size = Vector2(18, 18)
		s.lit = k < Game.coop_stars_of(i)
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(s)
	var par := label("   par %d" % int(lv.par), 15, Color(1.0, 0.9, 0.8, 0.7), Game.font_body)
	par.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(par)
	b.pivot_offset = Vector2(150, 42)
	b.focus_entered.connect(func() -> void:
		Sfx.play("hover", -14.0)
		b.create_tween().tween_property(b, "scale", Vector2.ONE * 1.04, 0.12))
	b.focus_exited.connect(func() -> void: b.create_tween().tween_property(b, "scale", Vector2.ONE, 0.12))
	b.mouse_entered.connect(func() -> void: b.grab_focus())
	b.pressed.connect(func() -> void:
		Sfx.play("click", -4.0)
		Net.start_level(i))
	return b


func _open_server_popup() -> void:
	if _popup:
		return
	_popup = Control.new()
	_popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(_popup)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.01, 0.06, 0.7)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_popup.add_child(shade)
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_popup.add_child(c)
	var card := _card(CYAN)
	card.custom_minimum_size = Vector2(560, 0)
	c.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	card.add_child(v)
	var t := label("ROOM SERVER", 30, Color(1, 1, 1), Game.font_title)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var d := label("The address of the PC running the Echo room server.\nUse 127.0.0.1 if the server runs on this PC.", 17, Color(0.8, 0.9, 1.0, 0.85), Game.font_body)
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(d)
	var edit := LineEdit.new()
	edit.text = Net.server_address()
	edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	edit.custom_minimum_size = Vector2(0, 54)
	edit.add_theme_font_override("font", Game.font_title)
	edit.add_theme_font_size_override("font_size", 24)
	v.add_child(edit)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	v.add_child(row)
	var save := _action("Save", CYAN, func() -> void:
		Game.set_setting("server", edit.text.strip_edges())
		_close_popup()
		_rebuild())
	save.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(save)
	var cancel := _action("Cancel", ERROR, _close_popup)
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(cancel)
	edit.text_submitted.connect(func(_t: String) -> void: save.pressed.emit())
	edit.call_deferred("grab_focus")


func _close_popup() -> void:
	if _popup:
		_popup.queue_free()
		_popup = null


func _process(delta: float) -> void:
	super._process(delta)
	_dots_t += delta
	if _dots and is_instance_valid(_dots):
		var base := str(_dots.get_meta("base", ""))
		_dots.text = base + ".".repeat(int(_dots_t * 2.5) % 4)
	if _spinner and is_instance_valid(_spinner):
		_spinner.scale = Vector2.ONE * (1.0 + 0.08 * sin(_dots_t * 4.0))
		_spinner.modulate.a = 0.7 + 0.3 * sin(_dots_t * 3.0)


func _on_back() -> void:
	if _popup:
		_close_popup()
		return
	Net.leave()
	Game.go_menu()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		if _code_edit and is_instance_valid(_code_edit) and _code_edit.has_focus():
			_code_edit.release_focus()
		else:
			_on_back()
		get_viewport().set_input_as_handled()
