extends Node

func _ready() -> void:
	Game.save_enabled = false
	var out := OS.get_environment("ECHO_OUT")
	var which := OS.get_environment("ECHO_SHOT").split(",")
	for w in which:
		var node: Node
		if w == "menu" or w == "settings":
			node = load("res://scenes/main_menu.tscn").instantiate()
		elif w in ["select", "ending", "credits"]:
			node = load("res://scenes/%s.tscn" % ("level_select" if w == "select" else w)).instantiate()
		elif w.begins_with("lobby"):
			node = load("res://scenes/coop_menu.tscn").instantiate()
			if w == "lobby_wait":
				Net.room_code = "NFD74"
				Net.is_host = true
				Net.state = Net.State.WAITING
				Net.status = "Room created. Send the code to your friend."
			elif w == "lobby_paired":
				Net.room_code = "NFD74"
				Net.is_host = true
				Net.state = Net.State.PAIRED
				Net.status = "Your friend joined! Pick a level."
			else:
				Net.state = Net.State.OFFLINE
				Net.status = ""
		elif w.begins_with("c"):
			Game.coop = true
			Game.current_level = int(w.substr(1)) - 1
			node = load("res://scenes/level.tscn").instantiate()
		else:
			Game.coop = false
			Game.current_level = int(w) - 1
			node = load("res://scenes/level.tscn").instantiate()
		add_child(node)
		if w == "settings":
			await get_tree().process_frame
			node.ui.add_child(SettingsPanel.new())
		for i in 240:
			await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s/shot_%s.png" % [out, w])
		node.queue_free()
		await get_tree().process_frame
	get_tree().quit()
