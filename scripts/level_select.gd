extends MenuBase

var _info: Label


func _ready() -> void:
	build_backdrop(2)
	var box := VBoxContainer.new()
	box.position = Vector2(70, 70)
	box.add_theme_constant_override("separation", 14)
	ui.add_child(box)
	box.add_child(label("LEVELS", 64, Color(1, 1, 1), Game.font_title))
	box.add_child(label("%d / %d stars" % [Game.total_stars(), Levels.count() * 3], 20, Color(1.0, 0.85, 0.5, 0.9), Game.font_body))
	var grid := GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	box.add_child(grid)
	var first: Button
	for i in Levels.count():
		var b := _level_button(i)
		grid.add_child(b)
		if i == mini(Game.unlocked - 1, Levels.count() - 1):
			first = b
	_info = label("", 22, Color(0.8, 0.9, 1.0, 0.9), Game.font_body)
	_info.custom_minimum_size = Vector2(620, 60)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_info)
	var back := button(box, "Back", Game.go_menu)
	back.custom_minimum_size = Vector2(200, 50)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	(first if first else back).call_deferred("grab_focus")


func _level_button(i: int) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(124, 104)
	var locked := i >= Game.unlocked
	b.disabled = locked
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var n := label(str(i + 1), 34, Color(1, 1, 1) if not locked else Color(0.5, 0.5, 0.6), Game.font_title)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(n)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(row)
	var got := Game.stars_of(i)
	for k in 3:
		var s := StarIcon.new()
		s.custom_minimum_size = Vector2(19, 19)
		s.lit = k < got
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(s)
	var lv: Dictionary = Levels.get_level(i)
	var chapter := "Chapter %d" % int(lv.get("chapter", 1))
	var info := "Locked" if locked else "%s   -   %d.  %s      par %d lives%s" % [chapter, i + 1, lv.name, lv.par, "      dark" if lv.get("dark", false) else ""]
	b.focus_entered.connect(func() -> void: _info.text = info)
	b.mouse_entered.connect(func() -> void:
		_info.text = info
		if not locked:
			b.grab_focus())
	b.focus_entered.connect(func() -> void: Sfx.play("hover", -14.0))
	b.pressed.connect(func() -> void:
		Sfx.play("click", -4.0)
		Game.play_level(i))
	return b


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		Game.go_menu()
		get_viewport().set_input_as_handled()
