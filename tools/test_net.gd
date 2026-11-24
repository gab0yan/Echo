extends Node


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _until(c: Callable, timeout: float) -> bool:
	var t := 0.0
	while not c.call() and t < timeout:
		await get_tree().process_frame
		t += get_process_delta_time()
	return c.call()


func _ready() -> void:
	Game.save_enabled = false
	_detach.call_deferred()


func _detach() -> void:
	var tree := get_tree()
	var dummy := Node.new()
	tree.root.add_child(dummy)
	tree.current_scene = dummy
	get_parent().remove_child(self)
	tree.root.add_child(self)
	await _start()


func _flag(n: String) -> String:
	return OS.get_environment("ECHO_FLAGS") + "/" + n


func _start() -> void:
	if OS.get_environment("ECHO_SERVER") != "":
		Game.settings.server = OS.get_environment("ECHO_SERVER")
	match OS.get_environment("ECHO_ROLE"):
		"host":
			await _host()
		"a":
			await _guest_a()
		"b":
			await _guest_b()
	get_tree().quit()


func _host() -> void:
	Game.settings.player_name = "Alen"
	Net.connect_server()
	var ok := await _until(func() -> bool: return Net.state == Net.State.BROWSING, 15.0)
	print("[host] connected and browsing: ", ok)
	Net.create_lobby("Alen's lobby", true)
	ok = await _until(func() -> bool: return Net.state == Net.State.WAITING, 10.0)
	print("[host] public lobby created: %s code=%s" % [ok, Net.room_code])
	ok = await _until(func() -> bool: return Net.state == Net.State.PAIRED, 30.0)
	print("[host] first player joined: %s (%s)" % [ok, Net.partner_name])
	await _wait(0.5)
	Net.kick_partner()
	ok = await _until(func() -> bool: return Net.state == Net.State.WAITING, 10.0)
	print("[host] kicked them, lobby open again: %s  status: %s" % [ok, Net.status])
	ok = await _until(func() -> bool: return Net.state == Net.State.PAIRED, 40.0)
	print("[host] second player joined: %s (%s)" % [ok, Net.partner_name])
	await _wait(0.5)
	Net.start_level(0)
	ok = await _until(func() -> bool: return Net.level != null and Net.level.players.size() == 2, 10.0)
	print("[host] level started: ", ok)
	var start: float = Net.level.players[1].position.x
	ok = await _until(func() -> bool: return Net.level.players[1].position.x > start + 2.0, 15.0)
	print("[host] P2 moved by the guest's input: ", ok)
	ok = await _until(func() -> bool: return Net.level.done[1], 10.0)
	Input.action_press("echo")
	await _wait(0.2)
	Input.action_release("echo")
	ok = await _until(func() -> bool: return Net.level.echoes.size() == 2, 5.0)
	print("[host] shared timeline echoes: ", ok)
	await _wait(3.0)


func _alen_lobby() -> Dictionary:
	for l in Net.lobbies:
		if l.get("host") == "Alen":
			return l
	return {}


func _guest_a() -> void:
	Game.settings.player_name = "Koryun"
	await _wait(1.5)
	Net.connect_server()
	var ok := await _until(func() -> bool: return Net.state == Net.State.BROWSING, 15.0)
	ok = await _until(func() -> bool: return _alen_lobby() != {}, 10.0)
	var lob: Dictionary = _alen_lobby()
	print("[koryun] sees public lobby in the list: %s  %s" % [ok, lob])
	Net.join_lobby(str(lob.get("code", "")))
	ok = await _until(func() -> bool: return Net.state == Net.State.PAIRED, 10.0)
	print("[koryun] joined from the list: %s, host is %s" % [ok, Net.partner_name])
	ok = await _until(func() -> bool: return Net.state == Net.State.BROWSING, 10.0)
	print("[koryun] got kicked: %s  status: %s" % [ok, Net.status])
	Net.join_lobby(str(lob.get("code", "")))
	ok = await _until(func() -> bool: return Net.status.contains("removed"), 5.0)
	print("[koryun] cannot rejoin after kick: %s  status: %s" % [ok, Net.status])
	Net.create_lobby("Secret base", false, "lion")
	ok = await _until(func() -> bool: return Net.state == Net.State.WAITING, 10.0)
	print("[koryun] private lobby with custom code: %s code=%s public=%s" % [ok, Net.room_code, Net.room_public])
	var f := FileAccess.open(_flag("a_done"), FileAccess.WRITE)
	f.store_string(str(lob.get("code", "")))
	f.close()
	await _wait(20.0)


func _guest_b() -> void:
	Game.settings.player_name = "David"
	var ok := await _until(func() -> bool: return FileAccess.file_exists(_flag("a_done")), 40.0)
	var host_code := FileAccess.get_file_as_string(_flag("a_done"))
	Net.connect_server()
	ok = await _until(func() -> bool: return Net.state == Net.State.BROWSING, 15.0)
	await _wait(1.0)
	# Real players may have lobbies open on a live server, so only judge the test's own lobbies.
	var names := []
	for l in Net.lobbies:
		if l.name in ["Alen's lobby", "Secret base"]:
			names.append(l.name)
	print("[david] public list shows only public lobbies: %s  %s" % [names == ["Alen's lobby"], names])
	Net.create_lobby("Copycat", false, "LION")
	ok = await _until(func() -> bool: return Net.status.contains("taken"), 5.0)
	print("[david] taken custom code rejected: %s  status: %s" % [ok, Net.status])
	Net.join_lobby(host_code)
	ok = await _until(func() -> bool: return Net.level != null and Net.level.players.size() == 2, 20.0)
	print("[david] joined and the host started the level: ", ok)
	await _wait(1.0)
	var lvl: Level = Net.level
	var before: float = lvl.players[1].position.x
	Input.action_press("move_right")
	await _wait(1.2)
	Input.action_release("move_right")
	await _wait(0.6)
	print("[david] my player moved on screen: ", lvl.players[1].position.x > before + 2.0)
	Input.action_press("echo")
	await _wait(0.2)
	Input.action_release("echo")
	ok = await _until(func() -> bool: return lvl.echoes.size() == 2, 10.0)
	print("[david] received both echoes: ", ok)
	await _wait(1.0)
