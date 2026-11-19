extends MenuBase

const CYAN := Color(0.35, 0.95, 1.0)
const ORANGE := Color(1.0, 0.65, 0.3)
const ERROR := Color(1.0, 0.5, 0.45)
const GREEN := Color(0.5, 1.0, 0.6)

var _status: Label
var _stage: Control
var _server_chip: Label
var _code_edit: LineEdit
var _list_box: VBoxContainer
var _list_title: Label
var _dots: Label
var _dots_t := 0.0
var _refresh_t := 0.0
var _spinner: Control
var _popup: Control


func _ready() -> void:
	build_backdrop(12, true)
	var title := label("MULTIPLAYER", 54, Color(1, 1, 1), Game.font_title)
	title.add_theme_color_override("font_outline_color", Color(1.0, 0.65, 0.3, 0.45))
	title.add_theme_constant_override("outline_size", 8)
	_center_top(title, 26, 96)
	ui.add_child(title)
	_status = label("", 20, CYAN, Game.font_title)
	_center_top(_status, 98, 128)
	ui.add_child(_status)
	_stage = Control.new()
	_stage.position = Vector2(40, 140)
	_stage.size = Vector2(1200, 480)
	ui.add_child(_stage)
	var back := _round_button("exitLeft", "Back", _on_back)
	back.position = Vector2(40, 636)
	ui.add_child(back)
	var srv := _round_button("wrench", "Room server", _open_server_popup)
	srv.position = Vector2(1176, 636)
	ui.add_child(srv)
	_server_chip = label("", 15, Color(0.75, 0.85, 1.0, 0.7), Game.font_title)
	_server_chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_server_chip.position = Vector2(760, 655)
	_server_chip.size = Vector2(400, 30)
	ui.add_child(_server_chip)
	Net.state_changed.connect(_rebuild)
	Net.status_changed.connect(_on_status)
	Net.lobbies_changed.connect(_fill_list)
	Net.session_ended.connect(func(_r: String) -> void: _rebuild())
	if Game.menu_message != "":
		_on_status(Game.menu_message, true)
		Game.menu_message = ""
	elif Net.status != "":
		_on_status(Net.status, Net.status_is_error)
	if Net.state == Net.State.OFFLINE:
		Net.connect_server()
	elif Net.is_host and Net.peer_connected:
		Net._srv_in_game.rpc_id(1, false)
	_rebuild()


func _center_top(l: Label, top: float, bottom: float) -> void:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	l.offset_left = -620
	l.offset_right = 620
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
	sb.set_content_margin_all(20)
	return sb


func _card(col: Color) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _style(col, 0.82, 0.6, 2))
	return p


func _icon(n: String, size: float, col: Color) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = load("res://assets/icons/%s.png" % n)
	tr.custom_minimum_size = Vector2(size, size)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.modulate = col
	tr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


func _action(text: String, col: Color, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 50)
	b.add_theme_stylebox_override("normal", _style(col, 0.6, 0.55, 2, 14))
	b.add_theme_stylebox_override("hover", _style(col, 0.9, 1.0, 3, 14))
	b.add_theme_stylebox_override("pressed", _style(col, 1.0, 1.0, 3, 14))
	b.add_theme_stylebox_override("disabled", _style(Color(0.5, 0.5, 0.55), 0.5, 0.3, 2, 14))
	var f := _style(col, 0.0, 1.0, 3, 14)
	f.draw_center = false
	b.add_theme_stylebox_override("focus", f)
	b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(func() -> void: Sfx.play("click", -4.0))
	b.pressed.connect(cb)
	b.focus_entered.connect(func() -> void: Sfx.play("hover", -14.0))
	b.mouse_entered.connect(func() -> void:
		if not b.disabled:
			b.grab_focus())
	return b


func _edit(placeholder: String, col: Color, size := 22) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.custom_minimum_size = Vector2(0, 50)
	e.add_theme_font_override("font", Game.font_title)
	e.add_theme_font_size_override("font_size", size)
	var n := _style(col, 0.7, 0.5, 2, 14)
	n.set_content_margin_all(12)
	var fo := _style(col, 0.85, 1.0, 3, 14)
	fo.set_content_margin_all(12)
	e.add_theme_stylebox_override("normal", n)
	e.add_theme_stylebox_override("focus", fo)
	return e


func _round_button(icon: String, tip: String, cb: Callable, d := 64.0) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(d, d)
	b.size = Vector2(d, d)
	b.tooltip_text = tip
	var n := StyleBoxFlat.new()
	n.bg_color = Color(0.06, 0.05, 0.12, 0.85)
	n.border_color = Color(CYAN, 0.4)
	n.set_border_width_all(2)
	n.set_corner_radius_all(int(d / 2))
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
	var tr := _icon(icon, d * 0.45, Color(0.85, 0.95, 1.0))
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var m := d * 0.26
	tr.offset_left = m
	tr.offset_top = m
	tr.offset_right = -m
	tr.offset_bottom = -m
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
	_list_box = null
	_list_title = null


func _rebuild() -> void:
	if not is_instance_valid(_stage):
		return
	_close_popup()
	_clear_stage()
	_server_chip.text = "ROOM SERVER  %s" % Net.server_address()
	match Net.state:
		Net.State.OFFLINE:
			_view_offline()
		Net.State.CONNECTING:
			_view_connecting()
		Net.State.BROWSING:
			_view_browse()
		Net.State.WAITING:
			_view_waiting()
		Net.State.PAIRED:
			_view_paired()
	_stage.modulate.a = 0.0
	create_tween().tween_property(_stage, "modulate:a", 1.0, 0.22)


func _view_offline() -> void:
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage.add_child(c)
	var card := _card(ERROR)
	card.custom_minimum_size = Vector2(620, 300)
	c.add_child(card)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 16)
	card.add_child(v)
	v.add_child(_icon("signal3", 70, ERROR))
	var t := label("NOT CONNECTED", 30, Color(1, 1, 1), Game.font_title)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var d := label("Is the room server running? Check its address with the wrench button.", 18, Color(1.0, 0.85, 0.8, 0.85), Game.font_body)
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(d)
	var retry := _action("Try again", CYAN, func() -> void: Net.connect_server())
	v.add_child(retry)
	retry.call_deferred("grab_focus")


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
	_dots = label("", 26, Color(1, 1, 1), Game.font_title)
	_dots.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dots.set_meta("base", "Talking to the room server")
	v.add_child(_dots)
	var c := CenterContainer.new()
	v.add_child(c)
	var cancel := _action("Cancel", ERROR, func() -> void:
		Net.leave()
		_on_status("Cancelled."))
	cancel.custom_minimum_size = Vector2(240, 50)
	c.add_child(cancel)
	cancel.call_deferred("grab_focus")


func _view_browse() -> void:
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 26)
	_stage.add_child(row)
	var list_card := _card(CYAN)
	list_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(list_card)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 12)
	list_card.add_child(lv)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	lv.add_child(head)
	head.add_child(_icon("unlocked", 30, CYAN))
	_list_title = label("PUBLIC LOBBIES", 24, Color(1, 1, 1), Game.font_title)
	_list_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_list_title)
	head.add_child(_round_button("return", "Refresh", func() -> void: Net.refresh_lobbies(), 44.0))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lv.add_child(scroll)
	_list_box = VBoxContainer.new()
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_box.add_theme_constant_override("separation", 10)
	scroll.add_child(_list_box)
	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(430, 0)
	side.add_theme_constant_override("separation", 16)
	row.add_child(side)
	var me := _card(Color(0.8, 0.85, 1.0))
	side.add_child(me)
	var mv := VBoxContainer.new()
	mv.add_theme_constant_override("separation", 8)
	me.add_child(mv)
	mv.add_child(label("YOUR NAME", 16, Color(0.8, 0.88, 1.0, 0.85), Game.font_title))
	var name_edit := _edit("Player", Color(0.8, 0.85, 1.0))
	name_edit.max_length = Net.NAME_MAX
	name_edit.text = str(Game.settings.get("player_name", ""))
	name_edit.text_changed.connect(func(t: String) -> void: Game.set_setting("player_name", t.strip_edges()))
	mv.add_child(name_edit)
	var create := _card(CYAN)
	side.add_child(create)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 10)
	create.add_child(cv)
	var ch := HBoxContainer.new()
	ch.add_theme_constant_override("separation", 12)
	cv.add_child(ch)
	ch.add_child(_icon("plus", 34, CYAN))
	ch.add_child(label("CREATE LOBBY", 24, Color(1, 1, 1), Game.font_title))
	var cdesc := label("Public for anyone, or private with a code.", 17, Color(0.8, 0.95, 1.0, 0.8), Game.font_body)
	cv.add_child(cdesc)
	var cbtn := _action("Create lobby", CYAN, _open_create_popup)
	cv.add_child(cbtn)
	var join := _card(ORANGE)
	side.add_child(join)
	var jv := VBoxContainer.new()
	jv.add_theme_constant_override("separation", 10)
	join.add_child(jv)
	var jh := HBoxContainer.new()
	jh.add_theme_constant_override("separation", 12)
	jv.add_child(jh)
	jh.add_child(_icon("locked", 30, ORANGE))
	jh.add_child(label("JOIN WITH CODE", 24, Color(1, 1, 1), Game.font_title))
	var jrow := HBoxContainer.new()
	jrow.add_theme_constant_override("separation", 10)
	jv.add_child(jrow)
	_code_edit = _edit("CODE", ORANGE, 26)
	_code_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_code_edit.max_length = Net.CODE_MAX
	_code_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_code_edit.text_changed.connect(func(t: String) -> void:
		var clean := Net.clean_code(t)
		if clean != t:
			_code_edit.text = clean
			_code_edit.caret_column = clean.length())
	_code_edit.text_submitted.connect(func(_t: String) -> void: Net.join_code(_code_edit.text))
	jrow.add_child(_code_edit)
	var jb := _action("Join", ORANGE, func() -> void: Net.join_code(_code_edit.text))
	jb.custom_minimum_size = Vector2(110, 50)
	jrow.add_child(jb)
	_fill_list()
	cbtn.call_deferred("grab_focus")


func _fill_list() -> void:
	if _list_box == null or not is_instance_valid(_list_box):
		return
	for c in _list_box.get_children():
		c.queue_free()
	var rooms: Array = Net.lobbies
	_list_title.text = "PUBLIC LOBBIES  (%d)" % rooms.size()
	if rooms.is_empty():
		var e := label("No public lobbies right now.\nCreate one and other players will see it here.", 19, Color(0.8, 0.9, 1.0, 0.7), Game.font_body)
		e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		e.custom_minimum_size = Vector2(0, 160)
		e.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_list_box.add_child(e)
		return
	for r in rooms:
		_list_box.add_child(_lobby_row(r))


func _lobby_row(r: Dictionary) -> PanelContainer:
	var full := int(r.players) >= 2
	var p := PanelContainer.new()
	var sb := _style(CYAN, 0.55, 0.3, 1, 14)
	sb.set_content_margin_all(12)
	p.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	p.add_child(h)
	h.add_child(_icon("multiplayer", 36, ORANGE if not full else Color(0.6, 0.6, 0.65)))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	v.add_child(label(str(r.name).to_upper(), 20, Color(1, 1, 1), Game.font_title))
	v.add_child(label("host  %s" % r.host, 16, Color(0.8, 0.9, 1.0, 0.75), Game.font_body))
	var state_text := "PLAYING" if bool(r.in_game) else ("FULL" if full else "OPEN")
	var col := GREEN if not full else Color(1.0, 0.8, 0.5)
	var count := label("%d/2   %s" % [int(r.players), state_text], 17, col, Game.font_title)
	count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(count)
	var join := _action("Join", ORANGE, func() -> void: Net.join_lobby(str(r.code)))
	join.custom_minimum_size = Vector2(100, 44)
	join.disabled = full
	h.add_child(join)
	return p


func _code_tiles(code: String, col: Color) -> HBoxContainer:
	var letters := HBoxContainer.new()
	letters.alignment = BoxContainer.ALIGNMENT_CENTER
	letters.add_theme_constant_override("separation", 10)
	var w := 76.0 if code.length() <= 5 else 58.0
	for i in code.length():
		var box := PanelContainer.new()
		var sb := _style(col, 0.9, 0.9, 2, 12)
		sb.set_content_margin_all(6)
		box.add_theme_stylebox_override("panel", sb)
		box.custom_minimum_size = Vector2(w, 90)
		var ch := label(code[i], 54 if code.length() <= 5 else 42, Color(1, 1, 1), Game.font_title)
		ch.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ch.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		box.add_child(ch)
		letters.add_child(box)
		box.pivot_offset = Vector2(w / 2, 45)
		box.scale = Vector2(0.3, 0.3)
		box.modulate.a = 0.0
		var tw := box.create_tween().set_parallel()
		tw.tween_property(box, "scale", Vector2.ONE, 0.35).set_delay(0.05 * i).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(box, "modulate:a", 1.0, 0.2).set_delay(0.05 * i)
	return letters


func _badge(public: bool) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 8)
	var col := GREEN if public else ORANGE
	h.add_child(_icon("unlocked" if public else "locked", 22, col))
	h.add_child(label("PUBLIC LOBBY" if public else "PRIVATE LOBBY", 17, col, Game.font_title))
	return h


func _view_waiting() -> void:
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage.add_child(c)
	var card := _card(CYAN)
	card.custom_minimum_size = Vector2(680, 430)
	c.add_child(card)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 14)
	card.add_child(v)
	var t := label(Net.room_name.to_upper(), 30, Color(1, 1, 1), Game.font_title)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	v.add_child(_badge(Net.room_public))
	var hint := label("Anyone can find it in the lobby list, or join with this code:" if Net.room_public else "Only players with this code can join:", 17, Color(0.8, 0.92, 1.0, 0.85), Game.font_body)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hint)
	v.add_child(_code_tiles(Net.room_code, CYAN))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	v.add_child(row)
	var copy := _action("Copy code", CYAN, func() -> void:
		DisplayServer.clipboard_set(Net.room_code)
		_on_status("Code %s copied." % Net.room_code))
	copy.custom_minimum_size = Vector2(230, 50)
	row.add_child(copy)
	var close := _action("Close lobby", ERROR, func() -> void: Net.leave_room())
	close.custom_minimum_size = Vector2(230, 50)
	row.add_child(close)
	_dots = label("", 21, Color(1.0, 0.85, 0.55), Game.font_title)
	_dots.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dots.set_meta("base", "Waiting for a player")
	v.add_child(_dots)
	copy.call_deferred("grab_focus")


func _player_chip(idx: int, col: Color, pname: String, sub: String, admin: bool, kick: bool) -> PanelContainer:
	var p := _card(col)
	p.custom_minimum_size = Vector2(380, 0)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	p.add_child(h)
	h.add_child(_icon("singleplayer", 46, col))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	v.add_child(top)
	top.add_child(label(pname.to_upper(), 22, Color(1, 1, 1), Game.font_title))
	if admin:
		top.add_child(_icon("star", 20, Color(1.0, 0.85, 0.4)))
	v.add_child(label("PLAYER %d  -  %s" % [idx, sub], 15, Color(col.lerp(Color.WHITE, 0.4), 0.9), Game.font_body))
	if kick:
		var k := _round_button("cross", "Kick %s" % pname, _confirm_kick, 46.0)
		k.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(k)
	else:
		h.add_child(_icon("checkmark", 30, GREEN))
	return p


func _view_paired() -> void:
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("separation", 14)
	_stage.add_child(v)
	var info := HBoxContainer.new()
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 16)
	v.add_child(info)
	info.add_child(label(Net.room_name.to_upper(), 22, Color(1, 1, 1), Game.font_title))
	info.add_child(_badge(Net.room_public))
	info.add_child(label("CODE  %s" % Net.room_code, 17, Color(0.85, 0.9, 1.0, 0.8), Game.font_title))
	var chips := HBoxContainer.new()
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	chips.add_theme_constant_override("separation", 22)
	v.add_child(chips)
	var me := Net.player_name()
	if Net.is_host:
		chips.add_child(_player_chip(1, CYAN, me, "you  -  admin", true, false))
		chips.add_child(_player_chip(2, ORANGE, Net.partner_name, "guest", false, true))
	else:
		chips.add_child(_player_chip(1, CYAN, Net.partner_name, "admin", true, false))
		chips.add_child(_player_chip(2, ORANGE, me, "you", false, false))
	if Net.is_host:
		var t := label("CHOOSE A LEVEL", 20, Color(1, 1, 1), Game.font_title)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(t)
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 16)
		grid.add_theme_constant_override("v_separation", 12)
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
		holder.custom_minimum_size = Vector2(0, 110)
		v.add_child(holder)
		_spinner = _icon("multiplayer", 76, ORANGE)
		_spinner.pivot_offset = Vector2(38, 38)
		holder.add_child(_spinner)
		_dots = label("", 22, Color(1.0, 0.85, 0.55), Game.font_title)
		_dots.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_dots.set_meta("base", "%s is choosing a level" % Net.partner_name)
		v.add_child(_dots)
	var c := CenterContainer.new()
	v.add_child(c)
	var leave := _action("Close lobby" if Net.is_host else "Leave lobby", ERROR, func() -> void: Net.leave_room())
	leave.custom_minimum_size = Vector2(240, 48)
	c.add_child(leave)


func _level_card(i: int) -> Button:
	var lv: Dictionary = Levels.get_coop(i)
	var b := Button.new()
	b.custom_minimum_size = Vector2(300, 80)
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
	var num := label(str(i + 1), 38, ORANGE, Game.font_title)
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
	b.pivot_offset = Vector2(150, 40)
	b.focus_entered.connect(func() -> void:
		Sfx.play("hover", -14.0)
		b.create_tween().tween_property(b, "scale", Vector2.ONE * 1.04, 0.12))
	b.focus_exited.connect(func() -> void: b.create_tween().tween_property(b, "scale", Vector2.ONE, 0.12))
	b.mouse_entered.connect(func() -> void: b.grab_focus())
	b.pressed.connect(func() -> void:
		Sfx.play("click", -4.0)
		Net.start_level(i))
	return b


func _popup_card(col: Color, width: float) -> VBoxContainer:
	_close_popup()
	_popup = Control.new()
	_popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(_popup)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.01, 0.06, 0.72)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_popup.add_child(shade)
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_popup.add_child(c)
	var card := _card(col)
	card.custom_minimum_size = Vector2(width, 0)
	c.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	card.add_child(v)
	card.pivot_offset = Vector2(width / 2, 200)
	card.scale = Vector2(0.94, 0.94)
	create_tween().tween_property(card, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return v


func _open_create_popup() -> void:
	var v := _popup_card(CYAN, 600)
	var t := label("CREATE LOBBY", 30, Color(1, 1, 1), Game.font_title)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	v.add_child(label("LOBBY NAME", 15, Color(0.8, 0.9, 1.0, 0.85), Game.font_title))
	var name_edit := _edit("%s's lobby" % Net.player_name(), CYAN)
	name_edit.max_length = 24
	v.add_child(name_edit)
	v.add_child(label("WHO CAN JOIN", 15, Color(0.8, 0.9, 1.0, 0.85), Game.font_title))
	var toggles := HBoxContainer.new()
	toggles.add_theme_constant_override("separation", 12)
	v.add_child(toggles)
	var group := ButtonGroup.new()
	var pub := _action("Public", GREEN, func() -> void: pass)
	pub.toggle_mode = true
	pub.button_group = group
	pub.button_pressed = true
	pub.icon = load("res://assets/icons/unlocked.png")
	pub.expand_icon = false
	pub.add_theme_constant_override("icon_max_width", 22)
	pub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pub.add_theme_stylebox_override("pressed", _style(GREEN, 0.95, 1.0, 3, 14))
	toggles.add_child(pub)
	var priv := _action("Private", ORANGE, func() -> void: pass)
	priv.toggle_mode = true
	priv.button_group = group
	priv.icon = load("res://assets/icons/locked.png")
	priv.add_theme_constant_override("icon_max_width", 22)
	priv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	priv.add_theme_stylebox_override("pressed", _style(ORANGE, 0.95, 1.0, 3, 14))
	toggles.add_child(priv)
	var hint := label("", 16, Color(0.8, 0.9, 1.0, 0.8), Game.font_body)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(hint)
	var code_label := label("PRIVATE CODE  (optional)", 15, Color(1.0, 0.85, 0.65, 0.9), Game.font_title)
	v.add_child(code_label)
	var code_edit := _edit("Leave empty for a random code", ORANGE)
	code_edit.max_length = Net.CODE_MAX
	code_edit.text_changed.connect(func(tx: String) -> void:
		var clean := Net.clean_code(tx)
		if clean != tx:
			code_edit.text = clean
			code_edit.caret_column = clean.length())
	v.add_child(code_edit)
	var update := func() -> void:
		var is_private := priv.button_pressed
		code_label.visible = is_private
		code_edit.visible = is_private
		hint.text = "Hidden from the list. Players join with the code. Type your own (%d-%d letters or numbers) or leave it empty for a random one." % [Net.CODE_MIN, Net.CODE_MAX] if is_private else "Shown in the public lobby list. Anyone can join. You are the admin and can kick players."
	pub.toggled.connect(func(_on: bool) -> void: update.call())
	priv.toggled.connect(func(_on: bool) -> void: update.call())
	update.call()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	v.add_child(row)
	var go := _action("Create", CYAN, func() -> void:
		var nm := name_edit.text
		var is_public := pub.button_pressed
		var code := code_edit.text if not is_public else ""
		_close_popup()
		Net.create_lobby(nm, is_public, code))
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(go)
	var cancel := _action("Cancel", ERROR, _close_popup)
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(cancel)
	name_edit.call_deferred("grab_focus")


func _confirm_kick() -> void:
	var v := _popup_card(ERROR, 520)
	var t := label("KICK %s?" % Net.partner_name.to_upper(), 28, Color(1, 1, 1), Game.font_title)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var d := label("They will be removed and cannot rejoin this lobby.", 17, Color(1.0, 0.85, 0.8, 0.85), Game.font_body)
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(d)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	v.add_child(row)
	var yes := _action("Kick", ERROR, func() -> void:
		_close_popup()
		Net.kick_partner())
	yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(yes)
	var no := _action("Cancel", CYAN, _close_popup)
	no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(no)
	no.call_deferred("grab_focus")


func _open_server_popup() -> void:
	var v := _popup_card(CYAN, 560)
	var t := label("ROOM SERVER", 30, Color(1, 1, 1), Game.font_title)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var d := label("The address of the PC or Raspberry Pi running the Echo room server.\nUse 127.0.0.1 if it runs on this PC.", 17, Color(0.8, 0.9, 1.0, 0.85), Game.font_body)
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(d)
	var edit := _edit("127.0.0.1", CYAN, 24)
	edit.text = Net.server_address()
	edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(edit)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	v.add_child(row)
	var save := _action("Save and connect", CYAN, func() -> void:
		Game.set_setting("server", edit.text.strip_edges())
		_close_popup()
		Net.leave()
		Net.connect_server()
		_rebuild())
	save.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(save)
	var cancel := _action("Cancel", ERROR, _close_popup)
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(cancel)
	edit.text_submitted.connect(func(_t: String) -> void: save.pressed.emit())
	edit.call_deferred("grab_focus")


func _close_popup() -> void:
	if _popup and is_instance_valid(_popup):
		_popup.queue_free()
	_popup = null


func _process(delta: float) -> void:
	super._process(delta)
	_dots_t += delta
	if _dots and is_instance_valid(_dots):
		_dots.text = str(_dots.get_meta("base", "")) + ".".repeat(int(_dots_t * 2.5) % 4)
	if _spinner and is_instance_valid(_spinner):
		_spinner.scale = Vector2.ONE * (1.0 + 0.08 * sin(_dots_t * 4.0))
		_spinner.modulate.a = 0.7 + 0.3 * sin(_dots_t * 3.0)
	if Net.state == Net.State.BROWSING:
		_refresh_t += delta
		if _refresh_t >= 3.0:
			_refresh_t = 0.0
			Net.refresh_lobbies()


func _on_back() -> void:
	if _popup:
		_close_popup()
		return
	Net.leave()
	Game.go_menu()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		var f := get_viewport().gui_get_focus_owner()
		if f is LineEdit:
			f.release_focus()
		else:
			_on_back()
		get_viewport().set_input_as_handled()
