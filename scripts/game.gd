extends Node

signal settings_changed

const SAVE_PATH := "user://echo_save.cfg"
const SETTINGS_PATH := "user://echo_settings.cfg"
const QUALITY_NAMES := ["Low", "High"]
const CHANNEL_COLORS := {
	"a": Color(1.0, 0.55, 0.18),
	"b": Color(0.25, 0.85, 1.0),
	"c": Color(1.0, 0.3, 0.75),
	"d": Color(0.55, 1.0, 0.3),
}
const ECHO_COLORS := [Color(0.35, 0.95, 1.0), Color(0.75, 0.5, 1.0), Color(1.0, 0.6, 0.85), Color(0.5, 1.0, 0.6)]
const ECHO_COLORS_P2 := [Color(1.0, 0.65, 0.3), Color(1.0, 0.85, 0.35), Color(1.0, 0.45, 0.45)]

var current_level := 0
var coop := false
var coop_best := {}
var menu_message := ""
var best := {}
var unlocked := 1
var seen_intro := false
var save_enabled := true
var settings := {
	"master": 0.8,
	"music": 0.7,
	"sfx": 0.8,
	"fullscreen": false,
	"vsync": true,
	"quality": 1,
	"shake": true,
	"key_hints": true,
	"server": "",
	"player_name": "",
}
var ui_theme: Theme
var font_title: FontFile
var font_body: FontFile

var _fade: ColorRect
var _fade_layer: CanvasLayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	font_title = load("res://assets/fonts/future.ttf")
	font_body = load("res://assets/fonts/future_narrow.ttf")
	_build_theme()
	_load()
	_load_settings()
	apply_settings()
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 100
	add_child(_fade_layer)
	_fade = ColorRect.new()
	_fade.color = Color(0.02, 0.02, 0.05, 0.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_layer.add_child(_fade)


func _build_theme() -> void:
	ui_theme = Theme.new()
	ui_theme.default_font = font_body
	ui_theme.default_font_size = 22
	var normal := _box(Color(0.08, 0.07, 0.14, 0.85), Color(0.35, 0.95, 1.0, 0.35))
	var hover := _box(Color(0.14, 0.12, 0.24, 0.95), Color(0.35, 0.95, 1.0, 0.9))
	var pressed := _box(Color(0.2, 0.5, 0.6, 0.95), Color(0.6, 1.0, 1.0, 1.0))
	var disabled := _box(Color(0.06, 0.06, 0.09, 0.6), Color(0.3, 0.3, 0.35, 0.3))
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = Color(1.0, 0.75, 0.35, 0.9)
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(10)
	focus.expand_margin_left = 3
	focus.expand_margin_right = 3
	focus.expand_margin_top = 3
	focus.expand_margin_bottom = 3
	ui_theme.set_stylebox("normal", "Button", normal)
	ui_theme.set_stylebox("hover", "Button", hover)
	ui_theme.set_stylebox("pressed", "Button", pressed)
	ui_theme.set_stylebox("disabled", "Button", disabled)
	ui_theme.set_stylebox("focus", "Button", focus)
	ui_theme.set_color("font_color", "Button", Color(0.85, 0.95, 1.0))
	ui_theme.set_color("font_hover_color", "Button", Color(1, 1, 1))
	ui_theme.set_color("font_focus_color", "Button", Color(1, 1, 1))
	ui_theme.set_color("font_pressed_color", "Button", Color(1, 1, 1))
	ui_theme.set_color("font_disabled_color", "Button", Color(0.45, 0.45, 0.5))
	ui_theme.set_font("font", "Button", font_title)
	ui_theme.set_font_size("font_size", "Button", 22)
	var panel := _box(Color(0.04, 0.035, 0.08, 0.92), Color(0.35, 0.95, 1.0, 0.4))
	panel.set_content_margin_all(28)
	panel.shadow_color = Color(0, 0, 0, 0.5)
	panel.shadow_size = 16
	ui_theme.set_stylebox("panel", "PanelContainer", panel)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.1)
	track.set_corner_radius_all(4)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.35, 0.95, 1.0, 0.85)
	fill.set_corner_radius_all(4)
	fill.content_margin_top = 4
	fill.content_margin_bottom = 4
	ui_theme.set_stylebox("slider", "HSlider", track)
	ui_theme.set_stylebox("grabber_area", "HSlider", fill)
	ui_theme.set_stylebox("grabber_area_highlight", "HSlider", fill)
	ui_theme.set_icon("grabber", "HSlider", _dot(Color(1, 1, 1)))
	ui_theme.set_icon("grabber_highlight", "HSlider", _dot(Color(1.0, 0.85, 0.5)))
	for t in ["OptionButton", "CheckButton"]:
		ui_theme.set_stylebox("normal", t, normal)
		ui_theme.set_stylebox("hover", t, hover)
		ui_theme.set_stylebox("pressed", t, normal)
		ui_theme.set_stylebox("hover_pressed", t, hover)
		ui_theme.set_stylebox("focus", t, focus)
		ui_theme.set_font("font", t, font_title)
		ui_theme.set_font_size("font_size", t, 18)
		ui_theme.set_color("font_color", t, Color(0.85, 0.95, 1.0))
		ui_theme.set_color("font_hover_color", t, Color(1, 1, 1))
		ui_theme.set_color("font_pressed_color", t, Color(1, 1, 1))
		ui_theme.set_color("font_focus_color", t, Color(1, 1, 1))
		ui_theme.set_color("font_hover_pressed_color", t, Color(1, 1, 1))
	var popup := _box(Color(0.06, 0.05, 0.12, 0.98), Color(0.35, 0.95, 1.0, 0.5))
	popup.set_content_margin_all(8)
	ui_theme.set_stylebox("panel", "PopupMenu", popup)
	ui_theme.set_font("font", "PopupMenu", font_title)
	ui_theme.set_font_size("font_size", "PopupMenu", 18)
	var sel := StyleBoxFlat.new()
	sel.bg_color = Color(0.35, 0.95, 1.0, 0.25)
	sel.set_corner_radius_all(6)
	ui_theme.set_stylebox("hover", "PopupMenu", sel)
	var edit := _box(Color(0.05, 0.05, 0.1, 0.9), Color(0.35, 0.95, 1.0, 0.45))
	ui_theme.set_stylebox("normal", "LineEdit", edit)
	ui_theme.set_stylebox("focus", "LineEdit", focus)
	ui_theme.set_color("font_color", "LineEdit", Color(1, 1, 1))
	ui_theme.set_color("font_placeholder_color", "LineEdit", Color(0.6, 0.65, 0.8, 0.7))
	ui_theme.set_color("caret_color", "LineEdit", Color(0.4, 1.0, 1.0))
	ui_theme.set_color("font_color", "Label", Color(0.9, 0.93, 1.0))
	ui_theme.set_color("font_outline_color", "Label", Color(0.02, 0.02, 0.05, 1))
	ui_theme.set_constant("outline_size", "Label", 4)


func _dot(c: Color) -> ImageTexture:
	var img := Image.create(22, 22, false, Image.FORMAT_RGBA8)
	for y in 22:
		for x in 22:
			var d := Vector2(x - 10.5, y - 10.5).length()
			var a := clampf(10.0 - d, 0.0, 1.0)
			var rim := clampf(d - 7.0, 0.0, 1.0)
			img.set_pixel(x, y, Color(c.lerp(Color(0.35, 0.95, 1.0), rim), a))
	return ImageTexture.create_from_image(img)


func _box(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(10)
	s.content_margin_left = 24
	s.content_margin_right = 24
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s


func change_scene(path: String) -> void:
	get_tree().paused = false
	var t := create_tween()
	t.tween_property(_fade, "color:a", 1.0, 0.28)
	t.tween_callback(func() -> void: get_tree().change_scene_to_file(path))
	t.tween_interval(0.05)
	t.tween_property(_fade, "color:a", 0.0, 0.4)


func play_level(i: int) -> void:
	coop = false
	current_level = clampi(i, 0, Levels.count() - 1)
	change_scene("res://scenes/level.tscn")


func play_coop(i: int) -> void:
	coop = true
	current_level = clampi(i, 0, Levels.coop_count() - 1)
	change_scene("res://scenes/level.tscn")


func go_coop_menu(message := "") -> void:
	coop = false
	menu_message = message
	change_scene("res://scenes/coop_menu.tscn")


func complete_coop(level: int, lives: int) -> int:
	var par: int = Levels.get_coop(level).par
	var stars := 3 if lives <= par else (2 if lives <= par + 2 else 1)
	var key := str(level)
	var prev: Dictionary = coop_best.get(key, {})
	if prev.is_empty() or lives < int(prev.get("lives", 999)):
		coop_best[key] = {"lives": lives, "stars": stars}
	_save()
	return stars


func coop_stars_of(level: int) -> int:
	return int(coop_best.get(str(level), {}).get("stars", 0))


func go_menu() -> void:
	coop = false
	change_scene("res://scenes/main_menu.tscn")


func go_level_select() -> void:
	change_scene("res://scenes/level_select.tscn")


func stars_for(level: int, lives: int) -> int:
	var par: int = Levels.get_level(level).par
	if lives <= par:
		return 3
	if lives <= par + 2:
		return 2
	return 1


func complete_level(level: int, lives: int) -> int:
	var stars := stars_for(level, lives)
	var key := str(level)
	var prev: Dictionary = best.get(key, {})
	if prev.is_empty() or lives < int(prev.get("lives", 999)):
		best[key] = {"lives": lives, "stars": stars}
	unlocked = maxi(unlocked, mini(level + 2, Levels.count()))
	_save()
	return stars


func stars_of(level: int) -> int:
	return int(best.get(str(level), {}).get("stars", 0))


func total_stars() -> int:
	var n := 0
	for k in best:
		n += int(best[k].get("stars", 0))
	return n


func mark_intro_seen() -> void:
	seen_intro = true
	_save()


func set_setting(key: String, value: Variant) -> void:
	if settings.get(key) == value:
		return
	settings[key] = value
	apply_settings()
	_save_settings()
	settings_changed.emit()


func _ensure_bus(bus: String) -> int:
	var i := AudioServer.get_bus_index(bus)
	if i == -1:
		AudioServer.add_bus()
		i = AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, bus)
		AudioServer.set_bus_send(i, "Master")
	return i


func apply_settings() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(float(settings.master), 0.0001)))
	AudioServer.set_bus_volume_db(_ensure_bus("Music"), linear_to_db(maxf(float(settings.music), 0.0001)))
	AudioServer.set_bus_volume_db(_ensure_bus("SFX"), linear_to_db(maxf(float(settings.sfx), 0.0001)))
	if DisplayServer.get_name() == "headless":
		return
	var want := DisplayServer.WINDOW_MODE_FULLSCREEN if settings.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	var mode := DisplayServer.window_get_mode()
	var is_full := mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if bool(settings.fullscreen) != is_full:
		DisplayServer.window_set_mode(want)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if settings.vsync else DisplayServer.VSYNC_DISABLED)
	get_viewport().msaa_3d = Viewport.MSAA_2X if int(settings.quality) >= 1 else Viewport.MSAA_DISABLED


func high_quality() -> bool:
	return int(settings.quality) >= 1


func _save_settings() -> void:
	if not save_enabled:
		return
	var c := ConfigFile.new()
	for k in settings:
		c.set_value("settings", k, settings[k])
	c.save(SETTINGS_PATH)


func _load_settings() -> void:
	var c := ConfigFile.new()
	if c.load(SETTINGS_PATH) != OK:
		return
	for k in settings:
		settings[k] = c.get_value("settings", k, settings[k])


func _save() -> void:
	if not save_enabled:
		return
	var c := ConfigFile.new()
	c.set_value("progress", "best", best)
	c.set_value("progress", "unlocked", unlocked)
	c.set_value("progress", "seen_intro", seen_intro)
	c.set_value("progress", "coop_best", coop_best)
	c.save(SAVE_PATH)


func _load() -> void:
	var c := ConfigFile.new()
	if c.load(SAVE_PATH) != OK:
		return
	best = c.get_value("progress", "best", {})
	unlocked = int(c.get_value("progress", "unlocked", 1))
	seen_intro = bool(c.get_value("progress", "seen_intro", false))
	coop_best = c.get_value("progress", "coop_best", {})
