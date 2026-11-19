extends MenuBase

@export var kind := "credits"

const ENDING := [
	"The beacon answers.  A light opens in the red sky.",
	"Behind me, every version of Subject 712 stands still on the ridge.",
	"They fell so I could climb.  They waited so I could pass.",
	"The Echo lets them go, one by one.",
	"I am going home.  All of us are.",
]


func _ready() -> void:
	build_backdrop(Levels.count() - 1 if kind == "ending" else 3)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(760, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	var title := label("EPILOGUE" if kind == "ending" else "CREDITS", 48, Color(1, 1, 1), Game.font_title)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var lines: Array = ENDING if kind == "ending" else [
		"A game by Alen Gevorgyan, David Ghazaryan & Koryun Gaboyan",
		"Music: placeholder ambient loop (soundtrack coming)",
		"Sound effects: Kenney (kenney.nl), CC0",
		"3D models and fonts: Kenney (kenney.nl), CC0",
		"Made with Godot Engine",
		"Thank you for playing.",
	]
	for i in lines.size():
		var l := label(lines[i], 24, Color(0.9, 0.92, 1.0), Game.font_body)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.modulate.a = 0.0
		box.add_child(l)
		var t := l.create_tween()
		t.tween_interval(0.4 + i * (1.4 if kind == "ending" else 0.25))
		t.tween_property(l, "modulate:a", 1.0, 0.8)
	var b := button(box, "Back to menu", Game.go_menu)
	b.call_deferred("grab_focus")
	if kind == "ending":
		var c := button(box, "Credits", func() -> void: Game.change_scene("res://scenes/credits.tscn"))
		c.size_flags_horizontal = Control.SIZE_FILL


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		Game.go_menu()
		get_viewport().set_input_as_handled()
