extends Node

const REC_DIR := "res://tools/rec"

var level: Level
var ui: Control
var fade: ColorRect
var flash_rect: ColorRect
var cap_box: Control
var cap_kicker: Label
var cap_text: Label
var cap_bar: ColorRect

var _frames := PackedVector3Array()
var _anims := PackedByteArray()
var _i := 0
var _playing := false
var _last_lives := 0
var _ff: Label


func _ready() -> void:
	Game.save_enabled = false
	Game.settings.shake = true
	process_physics_priority = -20
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	_build_overlay()
	_run()


func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color(0, 0, 0)
		bar.anchor_right = 1.0
		if top:
			bar.offset_bottom = 58
		else:
			bar.anchor_top = 1.0
			bar.anchor_bottom = 1.0
			bar.offset_top = -58
		ui.add_child(bar)
	flash_rect = ColorRect.new()
	flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash_rect.color = Color(1, 1, 1, 0)
	ui.add_child(flash_rect)
	cap_box = Control.new()
	cap_box.position = Vector2(84, 520)
	ui.add_child(cap_box)
	cap_bar = ColorRect.new()
	cap_bar.color = Color(0.35, 0.95, 1.0)
	cap_bar.size = Vector2(0, 4)
	cap_bar.position = Vector2(0, 40)
	cap_box.add_child(cap_bar)
	cap_kicker = _label("", 18, Color(0.45, 0.95, 1.0), Game.font_title)
	cap_kicker.position = Vector2(0, 10)
	cap_box.add_child(cap_kicker)
	cap_text = _label("", 46, Color(1, 1, 1), Game.font_title)
	cap_text.position = Vector2(0, 50)
	cap_box.add_child(cap_text)
	cap_box.modulate.a = 0.0
	_ff = _label(">>  FAST FORWARD", 18, Color(1.0, 0.85, 0.55), Game.font_title)
	_ff.position = Vector2(1010, 74)
	_ff.visible = false
	ui.add_child(_ff)
	fade = ColorRect.new()
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.color = Color(0, 0, 0, 1)
	ui.add_child(fade)


func _label(text: String, size: int, color: Color, font: Font) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.02, 0.01, 0.05))
	l.add_theme_constant_override("outline_size", 10)
	return l


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, true).timeout


func _fade_to(a: float, sec: float) -> void:
	var t := create_tween()
	t.tween_property(fade, "color:a", a, sec)
	await t.finished


func _flash(c: Color) -> void:
	flash_rect.color = c
	create_tween().tween_property(flash_rect, "color:a", 0.0, 0.5)


func caption(kicker: String, text: String) -> void:
	cap_kicker.text = kicker
	cap_text.text = text
	cap_text.visible_ratio = 0.0
	cap_box.modulate.a = 0.0
	cap_box.position.x = 54
	cap_bar.size.x = 0
	var t := create_tween().set_parallel()
	t.tween_property(cap_box, "modulate:a", 1.0, 0.3)
	t.tween_property(cap_box, "position:x", 84.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(cap_bar, "size:x", 120.0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(cap_text, "visible_ratio", 1.0, 0.03 * text.length()).set_delay(0.15)


func caption_out() -> void:
	var t := create_tween().set_parallel()
	t.tween_property(cap_box, "modulate:a", 0.0, 0.3)
	t.tween_property(cap_box, "position:x", 114.0, 0.3)


func _load_rec(n: int) -> Array:
	var f := FileAccess.open("%s/level_%d.json" % [REC_DIR, n], FileAccess.READ)
	return JSON.parse_string(f.get_as_text())


func _unpack(life: Dictionary) -> Array:
	var flat: Array = life.f
	var fr := PackedVector3Array()
	var i := 0
	while i < flat.size():
		fr.append(Vector3(flat[i], flat[i + 1], flat[i + 2]))
		i += 3
	var an := PackedByteArray()
	for v in life.a:
		an.append(int(v))
	return [fr, an]


func open_level(n: int) -> void:
	print("[trailer] level %d at frame %d" % [n, Engine.get_physics_frames()])
	if level:
		level.queue_free()
		await get_tree().process_frame
	Game.current_level = n - 1
	level = load("res://scenes/level.tscn").instantiate()
	add_child(level)
	await get_tree().process_frame
	level.hud.visible = false
	for h in level._hints:
		h.visible = false
	level.player.puppet = true
	_last_lives = 0


func inject(life: Dictionary) -> void:
	var u := _unpack(life)
	var e := Echo.new()
	level.lives_used += 1
	e.setup(u[0], u[1], life.died, Game.ECHO_COLORS[(level.lives_used - 1) % Game.ECHO_COLORS.size()], life.cause)
	e.dark = level.dark
	level._echo_root.add_child(e)
	level.echoes.append(e)
	e.locked.connect(level._on_echo_locked)
	_last_lives = level.lives_used


func restart_timeline() -> void:
	level._reset_world()
	level.player.puppet = true
	level._snap_camera()


func play_life(life: Dictionary, hold_after := 0.6) -> void:
	var u := _unpack(life)
	_frames = u[0]
	_anims = u[1]
	_i = 0
	_playing = true
	print("[trailer]   life frames=%d died=%s win=%s" % [_frames.size(), life.died, life.get("win", false)])
	while _playing:
		await get_tree().physics_frame
	if life.died:
		var n := 0
		while level.lives_used == _last_lives and n < 150:
			await get_tree().physics_frame
			n += 1
			if n == 20 and not level.player.dead:
				level._kill(life.cause if life.cause != "" else "spikes")
		level.player.puppet = true
	elif life.get("win", false):
		print("[trailer]   reached beacon: %s" % level.finished)
		await _wait(hold_after)
	else:
		await _wait(0.15)
		level._end_life(false)
		level.player.puppet = true


func _puppet_step() -> void:
	var f := _frames[_i]
	var a: String = Props.ANIMS[clampi(_anims[_i], 0, Props.ANIMS.size() - 1)]
	level.player.puppet_to(Vector3(f.x, f.y, 0.0), f.z, a)
	_i += 1


func _is_still(i: int) -> bool:
	var ahead := mini(i + 36, _frames.size() - 1)
	return i > 30 and _frames[i].distance_to(_frames[ahead]) < 0.05 and _frames[i].distance_to(_frames[i - 6]) < 0.05


func _physics_process(delta: float) -> void:
	if not _playing or level == null:
		return
	if _i >= _frames.size():
		_playing = false
		_ff.visible = false
		return
	var still := _is_still(_i)
	_ff.visible = still
	if still:
		for k in 4:
			if _i >= _frames.size() - 2 or level.finished or level.player.dead:
				break
			_puppet_step()
			level._physics_process(delta)
	_puppet_step()


func _process(_delta: float) -> void:
	if DisplayServer.get_name() != "headless" and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MINIMIZED:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	if level and level.lives_used > _last_lives:
		_last_lives = level.lives_used
		var died := level.echoes.size() > 0 and level.echoes[-1].died
		_flash(Color(1.0, 0.35, 0.4, 0.35) if died else Color(0.45, 0.95, 1.0, 0.45))


func title_card(title: String, sub: String, ghosts := true, size := 150) -> Control:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(root)
	ui.move_child(root, ui.get_child_count() - 2)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.02, 0.01, 0.05, 0.55)
	root.add_child(shade)
	var copies: Array[Label] = []
	var count := 4 if ghosts else 1
	for k in count:
		var l := _label(title, size, Color(1, 1, 1) if k == 0 else Game.ECHO_COLORS[k - 1], Game.font_title)
		l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.offset_top = -60
		l.offset_bottom = -60
		l.pivot_offset = Vector2(640, 300)
		l.modulate.a = 0.0
		copies.append(l)
	for k in range(count - 1, -1, -1):
		root.add_child(copies[k])
	var s := _label(sub, 26, Color(0.75, 0.95, 1.0), Game.font_body)
	s.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	s.offset_top = 70 + (size - 150) * 0.3
	s.offset_bottom = 70 + (size - 150) * 0.3
	s.visible_ratio = 0.0
	root.add_child(s)
	var main := copies[0]
	main.scale = Vector2(1.25, 1.25)
	var t := create_tween().set_parallel()
	t.tween_property(main, "modulate:a", 1.0, 0.5)
	t.tween_property(main, "scale", Vector2.ONE, 0.9).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	for k in range(1, count):
		var g := copies[k]
		g.modulate.a = 0.0
		t.tween_property(g, "modulate:a", 0.55, 0.2).set_delay(0.35 + k * 0.12)
		t.tween_property(g, "position", Vector2(k * 16.0, k * 9.0), 0.6).set_delay(0.35 + k * 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.tween_property(g, "modulate:a", 0.0, 0.8).set_delay(1.1 + k * 0.12)
	t.tween_property(s, "visible_ratio", 1.0, 0.035 * sub.length()).set_delay(0.8)
	return root


func card_out(root: Control, sec := 0.5) -> void:
	var t := create_tween()
	t.tween_property(root, "modulate:a", 0.0, sec)
	t.tween_callback(root.queue_free)


func _run() -> void:
	await open_level(1)
	var l1 := _load_rec(1)
	restart_timeline()
	_fade_to(0.0, 1.2)
	var c0 := title_card("SUBJECT 712", "Call sign: Black Dolphin.  Crash-landed on Nyx-4.", false, 64)
	await _wait(2.6)
	card_out(c0)
	await _wait(0.3)
	caption("NYX-4", "Alone on a red moon.")
	await play_life(l1[0], 0.3)
	caption_out()

	await _fade_to(1.0, 0.35)
	await open_level(3)
	restart_timeline()
	_fade_to(0.0, 0.4)
	var title := title_card("ECHO", "Every life you lose comes back to help you.")
	_flash(Color(0.45, 0.95, 1.0, 0.5))
	await _wait(3.6)
	card_out(title)

	await _fade_to(1.0, 0.35)
	await open_level(2)
	var l2 := _load_rec(2)
	restart_timeline()
	_fade_to(0.0, 0.35)
	caption("PRESS Q", "Leave an echo.")
	await play_life(l2[0])
	caption("REPLAY", "It repeats everything you did.")
	await play_life(l2[1], 0.8)
	caption_out()

	await _fade_to(1.0, 0.35)
	await open_level(5)
	var l5 := _load_rec(5)
	inject(l5[0])
	restart_timeline()
	_fade_to(0.0, 0.35)
	caption("FALL", "Every death leaves a body.")
	await play_life(l5[1])
	caption("BRIDGE", "Walk on what you were.")
	await play_life(l5[2], 0.6)
	caption_out()

	await _fade_to(1.0, 0.35)
	await open_level(7)
	var l7 := _load_rec(7)
	inject(l7[0])
	inject(l7[1])
	restart_timeline()
	_fade_to(0.0, 0.35)
	caption("TOWER", "Build a staircase out of yourself.")
	await play_life(l7[2], 0.6)
	caption_out()

	await _fade_to(1.0, 0.35)
	await open_level(9)
	var l9 := _load_rec(9)
	restart_timeline()
	_fade_to(0.0, 0.3)
	var ch2 := title_card("CHAPTER 2", "The Deep Echo", false, 72)
	await _wait(1.6)
	card_out(ch2, 0.4)
	caption("GRIP", "Climb the moss.")
	await play_life(l9[0], 0.5)
	caption_out()

	await _fade_to(1.0, 0.35)
	await open_level(11)
	var l11 := _load_rec(11)
	restart_timeline()
	_fade_to(0.0, 0.35)
	caption("ACID", "Dissolve...")
	await play_life(l11[0])
	caption("BOUNCE BACK", "...and use the slime you leave behind.")
	await play_life(l11[1], 0.6)
	caption_out()

	await _fade_to(1.0, 0.35)
	await open_level(12)
	var l12 := _load_rec(12)
	restart_timeline()
	_fade_to(0.0, 0.35)
	caption("PORTALS", "Send your echo where you can't go.")
	await play_life(l12[0])
	await play_life(l12[1], 0.5)
	caption_out()

	await _fade_to(1.0, 0.35)
	await open_level(14)
	var l14 := _load_rec(14)
	inject(l14[0])
	inject(l14[1])
	restart_timeline()
	_fade_to(0.0, 0.5)
	caption("LIGHTS OUT", "Your past lives light the way.")
	await play_life(l14[2], 0.6)
	caption_out()

	await _fade_to(1.0, 0.35)
	await open_level(16)
	var l16 := _load_rec(16)
	inject(l16[0])
	inject(l16[1])
	restart_timeline()
	_fade_to(0.0, 0.35)
	caption("16 LEVELS", "Everything at once.")
	await play_life(l16[2], 1.0)
	caption_out()

	await _fade_to(1.0, 0.5)
	await open_level(4)
	level.player.visible = false
	restart_timeline()
	level.player.visible = false
	_fade_to(0.0, 0.6)
	var end := title_card("ECHO", "A game by Alen Gevorgyan, David Ghazaryan & Koryun Gaboyan")
	await _wait(1.6)
	var tag := _label("16 levels   -   2 chapters   -   every death counts", 22, Color(1.0, 0.85, 0.55), Game.font_title)
	tag.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.offset_left = -600
	tag.offset_right = 600
	tag.offset_top = -130
	tag.offset_bottom = -96
	tag.modulate.a = 0.0
	end.add_child(tag)
	create_tween().tween_property(tag, "modulate:a", 1.0, 0.8)
	await _wait(3.4)
	await _fade_to(1.0, 1.2)
	await _wait(0.4)
	print("[trailer] done at frame %d" % Engine.get_physics_frames())
	get_tree().quit()
