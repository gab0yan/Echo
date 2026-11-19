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


func _start() -> void:
	if OS.get_environment("ECHO_ROLE") == "host":
		await _host()
	else:
		await _client()
	get_tree().quit()


func _host() -> void:
	await _wait(1.0)
	Net.create_room()
	var ok := await _until(func() -> bool: return Net.room_code != "", 15.0)
	print("[host] room created: %s code=%s" % [ok, Net.room_code])
	var f := FileAccess.open(OS.get_environment("ECHO_CODE_FILE"), FileAccess.WRITE)
	f.store_string(Net.room_code)
	f.close()
	ok = await _until(func() -> bool: return Net.peer_connected, 30.0)
	print("[host] friend joined with the code: ", ok)
	await _wait(0.5)
	Net.start_level(0)
	ok = await _until(func() -> bool: return Net.level != null and Net.level.players.size() == 2, 10.0)
	print("[host] level started: ", ok)
	var start: float = Net.level.players[1].position.x
	ok = await _until(func() -> bool: return Net.level.players[1].position.x > start + 2.0, 15.0)
	print("[host] P2 moved by friend's input through the server: %s (%.2f -> %.2f)" % [ok, start, Net.level.players[1].position.x])
	ok = await _until(func() -> bool: return Net.level.done[1], 10.0)
	print("[host] P2 left an echo: ", ok)
	Input.action_press("echo")
	await _wait(0.2)
	Input.action_release("echo")
	ok = await _until(func() -> bool: return Net.level.echoes.size() == 2, 5.0)
	print("[host] two echoes after shared timeline: ", ok)
	await _wait(3.0)


func _client() -> void:
	var path := OS.get_environment("ECHO_CODE_FILE")
	var ok := await _until(func() -> bool: return FileAccess.file_exists(path) and FileAccess.get_file_as_string(path).length() == 5, 30.0)
	var code := FileAccess.get_file_as_string(path)
	print("[guest] got code from host: ", code)
	Net.join_room("zz")
	print("[guest] short code rejected: ", Net.status_is_error)
	Net.join_room(code.to_lower())
	ok = await _until(func() -> bool: return Net.level != null and Net.level.players.size() == 2, 25.0)
	print("[guest] joined room and level loaded: ", ok)
	await _wait(1.0)
	var lvl: Level = Net.level
	var before: float = lvl.players[1].position.x
	Input.action_press("move_right")
	await _wait(1.2)
	Input.action_release("move_right")
	await _wait(0.6)
	print("[guest] my player moved on screen: %s (%.2f -> %.2f)" % [lvl.players[1].position.x > before + 2.0, before, lvl.players[1].position.x])
	Input.action_press("echo")
	await _wait(0.2)
	Input.action_release("echo")
	ok = await _until(func() -> bool: return lvl.echoes.size() == 2, 10.0)
	print("[guest] received both echoes: ", ok)
	await _wait(1.0)
