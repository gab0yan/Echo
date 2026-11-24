extends MenuBase

const STORY := [
	"Subject 712.  Call sign: Black Dolphin.",
	"The ship broke apart over Nyx-4, a red moon very far from home.",
	"The old crews had a name for its magnetic field.  They called it the Echo.",
	"It remembers everything that dies here.  And it plays it back.",
	"Every life you lose comes back to help you.",
]

var _story: Control
var _story_i := 0
var _story_label: Label
var _story_tween: Tween


var _hint: Label
var _cards: Array[Button] = []


func _ready() -> void:
	build_backdrop(0, true)
	var title := label("ECHO", 112, Color(1, 1, 1), Game.font_title)
	title.add_theme_color_override("font_outline_color", Color(0.3, 0.9, 1.0, 0.5))
	title.add_theme_constant_override("outline_size", 10)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	title.offset_left = -400 + 190
	title.offset_right = 400 + 190
	title.offset_top = 36
	title.offset_bottom = 170
	ui.add_child(title)
	var tag := label("Every life you lose comes back to help you.", 22, Color(0.7, 0.95, 1.0, 0.85), Game.font_body)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	tag.offset_left = -500 + 190
	tag.offset_right = 500 + 190
	tag.offset_top = 168
	tag.offset_bottom = 200
	ui.add_child(tag)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 36)
	row.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	row.offset_left = -480 + 190
	row.offset_right = 480 + 190
	row.offset_top = -110
	row.offset_bottom = 150
	ui.add_child(row)
	var single_sub := "%d levels  -  2 chapters\n%d / %d stars" % [Levels.count(), Game.total_stars(), Levels.count() * 3]
	var single := _card("SINGLE PLAYER", single_sub, "res://assets/icons/singleplayer.png", Color(0.35, 0.95, 1.0))
	single.pressed.connect(_on_play)
	row.add_child(single)
	var web := OS.get_name() == "Web"
	var multi_sub := "Online co-op with a friend\n%d levels for two" % Levels.coop_count()
	var multi := _card("MULTIPLAYER", multi_sub, "res://assets/icons/multiplayer.png", Color(1.0, 0.65, 0.3))
	multi.pressed.connect(func() -> void: Game.go_coop_menu())
	row.add_child(multi)
	var icons := HBoxContainer.new()
	icons.alignment = BoxContainer.ALIGNMENT_CENTER
	icons.add_theme_constant_override("separation", 18)
	icons.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	icons.offset_left = -400 + 190
	icons.offset_right = 400 + 190
	icons.offset_top = -150
	icons.offset_bottom = -80
	ui.add_child(icons)
	_hint = label("", 18, Color(0.85, 0.9, 1.0, 0.8), Game.font_title)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.offset_left = -300 + 190
	_hint.offset_right = 300 + 190
	_hint.offset_top = -70
	_hint.offset_bottom = -40
	ui.add_child(_hint)
	_icon_button(icons, "information", "Story", _show_story.bind(false))
	var gear := _icon_button(icons, "gear", "Settings", func() -> void: pass)
	gear.pressed.connect(func() -> void:
		var sp := SettingsPanel.new()
		ui.add_child(sp)
		sp.closed.connect(func() -> void: gear.grab_focus()))
	_icon_button(icons, "trophy", "Credits", func() -> void: Game.change_scene("res://scenes/credits.tscn"))
	if not web:
		_icon_button(icons, "power", "Quit", func() -> void: get_tree().quit())
	single.call_deferred("grab_focus")
	_build_hero()
	var t := title.create_tween().set_loops()
	t.tween_property(title, "offset_top", 30.0, 2.0).set_trans(Tween.TRANS_SINE)
	t.tween_property(title, "offset_top", 36.0, 2.0).set_trans(Tween.TRANS_SINE)
	for i in _cards.size():
		var c := _cards[i]
		c.modulate.a = 0.0
		var tw := c.create_tween()
		tw.tween_interval(0.15 + i * 0.12)
		tw.tween_property(c, "modulate:a", 1.0, 0.4)


func _card_style(col: Color, bg_a: float, border_a: float, width: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.04, 0.1, bg_a)
	sb.border_color = Color(col, border_a)
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(22)
	sb.shadow_color = Color(col, 0.25 * border_a)
	sb.shadow_size = 18 if width > 2 else 6
	sb.set_content_margin_all(20)
	return sb


func _card(title_text: String, sub: String, icon: String, col: Color) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(370, 250)
	b.add_theme_stylebox_override("normal", _card_style(col, 0.78, 0.45, 2))
	b.add_theme_stylebox_override("hover", _card_style(col, 0.9, 1.0, 3))
	b.add_theme_stylebox_override("focus", _card_style(col, 0.0, 1.0, 3))
	b.add_theme_stylebox_override("pressed", _card_style(col, 1.0, 1.0, 4))
	b.add_theme_stylebox_override("disabled", _card_style(Color(0.5, 0.5, 0.55), 0.6, 0.3, 2))
	b.pivot_offset = Vector2(185, 125)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 8)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var tr := TextureRect.new()
	tr.texture = load(icon)
	tr.custom_minimum_size = Vector2(96, 96)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.modulate = col
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tr.pivot_offset = Vector2(48, 48)
	v.add_child(tr)
	var t := label(title_text, 34, Color(1, 1, 1), Game.font_title)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(t)
	var s := label(sub, 18, Color(col.lerp(Color.WHITE, 0.45), 0.9), Game.font_body)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(s)
	var grow := func(on: bool) -> void:
		var tw := b.create_tween().set_parallel()
		tw.tween_property(b, "scale", Vector2.ONE * (1.04 if on else 1.0), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(tr, "scale", Vector2.ONE * (1.08 if on else 1.0), 0.15)
	b.focus_entered.connect(func() -> void:
		Sfx.play("hover", -14.0)
		grow.call(true))
	b.focus_exited.connect(func() -> void: grow.call(false))
	b.mouse_entered.connect(func() -> void:
		if not b.disabled:
			b.grab_focus())
	b.pressed.connect(func() -> void: Sfx.play("click", -4.0))
	_cards.append(b)
	return b


func _icon_button(parent: Container, icon: String, tip: String, cb: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(72, 72)
	b.tooltip_text = tip
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.06, 0.05, 0.12, 0.8)
	normal.border_color = Color(0.35, 0.95, 1.0, 0.35)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(36)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.12, 0.12, 0.24, 0.95)
	hover.border_color = Color(0.35, 0.95, 1.0, 1.0)
	var focus := hover.duplicate() as StyleBoxFlat
	focus.draw_center = false
	focus.border_color = Color(1.0, 0.75, 0.35, 1.0)
	focus.set_border_width_all(3)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_stylebox_override("focus", focus)
	b.pivot_offset = Vector2(36, 36)
	var tr := TextureRect.new()
	tr.texture = load("res://assets/icons/%s.png" % icon)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tr.offset_left = 18
	tr.offset_top = 18
	tr.offset_right = -18
	tr.offset_bottom = -18
	tr.modulate = Color(0.85, 0.95, 1.0)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(tr)
	var show := func(on: bool) -> void:
		if on:
			_hint.text = tip.to_upper()
		elif _hint.text == tip.to_upper():
			_hint.text = ""
		var tw := b.create_tween()
		tw.tween_property(b, "scale", Vector2.ONE * (1.12 if on else 1.0), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	b.focus_entered.connect(func() -> void:
		Sfx.play("hover", -14.0)
		show.call(true))
	b.focus_exited.connect(func() -> void: show.call(false))
	b.mouse_entered.connect(func() -> void: b.grab_focus())
	b.pressed.connect(func() -> void: Sfx.play("click", -4.0))
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _on_play() -> void:
	if Game.seen_intro:
		Game.go_level_select()
	else:
		_show_story(true)


func _show_story(then_play: bool) -> void:
	_story = Control.new()
	_story.set_anchors_preset(Control.PRESET_FULL_RECT)
	_story.set_meta("play", then_play)
	ui.add_child(_story)
	var bg := ColorRect.new()
	bg.color = Color(0.01, 0.005, 0.03, 0.94)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_story.add_child(bg)
	_story_label = label("", 34, Color(0.92, 0.95, 1.0), Game.font_body)
	_story_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_story_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_story_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_story_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_story_label.offset_left = 160
	_story_label.offset_right = -160
	_story.add_child(_story_label)
	var skip := label("click / space to continue      esc to skip", 16, Color(0.7, 0.8, 1.0, 0.5), Game.font_body)
	skip.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	skip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skip.offset_left = -400
	skip.offset_right = 400
	skip.offset_top = -60
	skip.offset_bottom = -30
	_story.add_child(skip)
	_story_i = -1
	_next_line()


func _next_line() -> void:
	_story_i += 1
	if _story_i >= STORY.size():
		_end_story()
		return
	_story_label.text = STORY[_story_i]
	_story_label.visible_ratio = 0.0
	if _story_tween:
		_story_tween.kill()
	_story_tween = create_tween()
	_story_tween.tween_property(_story_label, "visible_ratio", 1.0, 0.04 * STORY[_story_i].length())
	_story_tween.tween_interval(2.4)
	_story_tween.tween_callback(_next_line)


func _end_story() -> void:
	if _story_tween:
		_story_tween.kill()
	var play: bool = _story.get_meta("play")
	_story.queue_free()
	_story = null
	Game.mark_intro_seen()
	if play:
		Game.go_level_select()


func _unhandled_input(event: InputEvent) -> void:
	if _story == null:
		return
	if event.is_action_pressed("pause"):
		_end_story()
	elif event.is_action_pressed("jump") or event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed):
		if _story_label.visible_ratio < 1.0:
			_story_tween.kill()
			_story_label.visible_ratio = 1.0
			_story_tween = create_tween()
			_story_tween.tween_interval(2.4)
			_story_tween.tween_callback(_next_line)
		else:
			_next_line()
	get_viewport().set_input_as_handled()


var _hero_root: Node3D
var _hero_anims: Array[AnimationPlayer] = []
var _hero_time := 0.0
var _hero_wave := 4.0


func _build_hero() -> void:
	var cam := backdrop.camera
	_hero_root = Node3D.new()
	_hero_root.position = Vector3(-2.5, -1.75, -7.2)
	_hero_root.rotation_degrees = Vector3(5, 0, 0)
	cam.add_child(_hero_root)
	var disc := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(3.4, 2.4)
	disc.mesh = pm
	disc.material_override = Props.shader_mat("res://shaders/ring.gdshader", {"tint": Color(0.35, 0.95, 1.0), "power": 1.4})
	disc.position = Vector3(-0.7, 0.01, -0.5)
	_hero_root.add_child(disc)
	var beam := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(2.2, 3.2)
	beam.mesh = q
	beam.material_override = Props.shader_mat("res://shaders/glow.gdshader", {"tint": Color(0.3, 0.8, 1.0), "power": 0.35})
	beam.position = Vector3(-0.4, 1.6, -1.6)
	_hero_root.add_child(beam)
	for k in range(3, 0, -1):
		var ghost := Props.character("res://assets/models/kit/character-oopi.glb")
		var holder := Node3D.new()
		holder.add_child(ghost)
		holder.scale = Vector3.ONE * 1.7
		holder.position = Vector3(-0.55 * k, 0.03 * k, -0.42 * k)
		holder.rotation.y = 0.75
		var col: Color = Game.ECHO_COLORS[(k - 1) % Game.ECHO_COLORS.size()]
		Props.override_material(ghost, Props.shader_mat("res://shaders/ghost.gdshader", {"tint": col, "strength": 1.35 - 0.22 * k, "flicker": 1.0}))
		_hero_root.add_child(holder)
		var ap := Props.find_anim(ghost)
		if ap:
			ap.play("idle")
			ap.seek(0.35 * k, true)
		_hero_anims.append(ap)
	var hero := Props.character("res://assets/models/kit/character-oopi.glb")
	var hh := Node3D.new()
	hh.add_child(hero)
	hh.scale = Vector3.ONE * 1.7
	hh.rotation.y = 0.75
	Props.set_shadows(hero, false)
	_hero_root.add_child(hh)
	var hap := Props.find_anim(hero)
	if hap:
		hap.play("idle")
	_hero_anims.append(hap)
	for spec in [[Vector3(1.2, 1.6, 1.4), Color(1.0, 0.85, 0.75), 2.2], [Vector3(-1.4, 1.2, -0.6), Color(0.35, 0.9, 1.0), 2.6], [Vector3(0.2, 0.2, 1.0), Color(0.5, 0.7, 1.0), 0.8]]:
		var l := OmniLight3D.new()
		l.position = spec[0]
		l.light_color = spec[1]
		l.light_energy = spec[2]
		l.omni_range = 4.0
		_hero_root.add_child(l)
	_hero_root.scale = Vector3.ONE * 0.001
	var tw := create_tween()
	tw.tween_interval(0.2)
	tw.tween_property(_hero_root, "scale", Vector3.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	super._process(delta)
	if _hero_root == null:
		return
	_hero_time += delta
	_hero_root.position.y = -1.75 + sin(_hero_time * 1.4) * 0.05
	_hero_wave -= delta
	if _hero_wave <= 0.0:
		_hero_wave = 6.0
		var n := _hero_anims.size()
		for i in n:
			var ap := _hero_anims[i]
			if ap == null or not ap.has_animation("emote-yes"):
				continue
			var delay := 0.3 * (n - 1 - i)
			var t := create_tween()
			t.tween_interval(delay)
			t.tween_callback(func() -> void:
				ap.play("emote-yes", 0.15)
				ap.queue("idle"))
