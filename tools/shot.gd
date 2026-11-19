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
			Game.settings.player_name = "Alen"
			Net.lobbies = [
				{"code": "MB593", "name": "Night shift", "host": "Koryun", "players": 1, "in_game": false},
				{"code": "QX7TA", "name": "Speedrunners", "host": "Mira", "players": 2, "in_game": true},
				{"code": "H2KDN", "name": "David's lobby", "host": "David", "players": 1, "in_game": false},
			]
			if w == "lobby_wait":
				Net.room_code = "LION"
				Net.room_name = "Secret base"
				Net.room_public = false
				Net.is_host = true
				Net.state = Net.State.WAITING
				Net.status = "Private lobby created. Send the code to your friend."
			elif w == "lobby_paired":
				Net.room_code = "MB593"
				Net.room_name = "Alen's lobby"
				Net.room_public = true
				Net.partner_name = "David"
				Net.is_host = true
				Net.state = Net.State.PAIRED
				Net.status = "David joined! Pick a level."
			else:
				Net.state = Net.State.BROWSING
				Net.status = "Connected. Join a public lobby, or create your own."
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
		if w == "lobby_create":
			await get_tree().process_frame
			node._open_create_popup()
		for i in 240:
			await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s/shot_%s.png" % [out, w])
		node.queue_free()
		await get_tree().process_frame
	get_tree().quit()
