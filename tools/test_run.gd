extends Node

const SOL := {
	0: [[["jr", 6.0], ["jr", 10.9], ["jr", 18.0], ["jn"], ["win"]]],
	1: [[["rt", 9.3], ["q"]], [["win"]]],
	2: [[["rt", 13.4], ["q"]], [["rt", 11.5], ["wait_echo", 0], ["jr", 12.0], ["jn"], ["win"]]],
	3: [[["rt", 6.3], ["q"]], [["rt", 14.3], ["q"]], [["win"]]],
	4: [[["jr", 8.6], ["die"]], [["jr", 8.6], ["jn"], ["die"]], [["jr", 8.6], ["jn"], ["jn"], ["win"]]],
	5: [[["rt", 6.3], ["q"]], [["rt", 15.0], ["lift_down", 0], ["hop", 16.8], ["lift_up", 0], ["win"]]],
	6: [[["rt", 9.4], ["q"]], [["rt", 7.5], ["wait_echo", 0], ["jr", 8.0], ["jn"], ["rt", 12.4], ["q"]], [["rt", 7.5], ["wait_echo", 0], ["jr", 8.0], ["jn"], ["wait_echo", 1], ["jn"], ["jn"], ["win"]]],
	7: [[["rt", 5.3], ["q"]], [["jr", 12.6], ["die"]], [["jr", 12.6], ["jn"], ["rt", 25.4], ["q"]], [["jr", 12.6], ["jn"], ["rt", 23.5], ["wait_echo", 2], ["jr", 24.2], ["jn"], ["win"]]],
	8: [[["rt", 11.0], ["jn"], ["climb", 8.7, 1], ["win"]]],
	9: [[["win"]]],
	10: [[["die"]], [["win"]]],
	11: [[["lt_y", 6.0], ["rt", 6.3], ["q"]], [["win"]]],
	12: [[["rt", 3.3], ["lift_down", 0], ["hop", 4.9], ["lift_up", 0], ["rt", 20.4], ["q"]], [["rt", 3.3], ["lift_down", 0], ["hop", 4.9], ["lift_up", 0], ["rt", 19.0], ["wait_echo", 0], ["jr", 19.2], ["jn"], ["win"]]],
	13: [[["rt", 5.3], ["q"]], [["jr", 11.6], ["die"]], [["jr", 11.6], ["jn"], ["win"]]],
	14: [[["die"]], [["cling_r"], ["climb", 9.6, 1], ["win"]]],
	15: [[["rt", 8.4], ["wait_y", 9.0], ["lt", 4.7], ["q"]], [["die"]], [["win"]]],
}

const NEG := {
	8: [[["rt", 11.0], ["jn"], ["w", 200], ["win"]]],
	10: [[["win"]]],
	11: [[["win"]]],
	12: [[["rt", 3.3], ["lift_down", 0], ["hop", 4.9], ["lift_up", 0], ["jr", 19.0], ["jn"], ["win"]]],
	13: [[["rt", 5.3], ["q"]], [["jr", 11.6], ["win"]]],
	14: [[["jr", 12.2], ["jn"], ["climb", 9.6, 1], ["win"]]],
	15: [[["rt", 8.4], ["wait_y", 9.0], ["lt", 4.7], ["q"]], [["win"]]],
	1: [[["win"]]],
	2: [[["jr", 12.0], ["jn"], ["jn"], ["win"]]],
	3: [[["rt", 6.3], ["q"]], [["win"]]],
	4: [[["jr", 8.6], ["win"]]],
	5: [[["rt", 15.0], ["lift_down", 0], ["hop", 16.8], ["w", 200], ["win"]]],
	6: [[["rt", 9.4], ["q"]], [["rt", 7.5], ["wait_echo", 0], ["jr", 8.0], ["jn"], ["jn"], ["jn"], ["win"]]],
	7: [[["jr", 12.6], ["win"]]],
}

var level: Level
var log_lines: Array[String] = []


func _ready() -> void:
	Game.save_enabled = false
	var only := OS.get_environment("ECHO_ONLY")
	var neg := OS.get_environment("ECHO_NEG") != ""
	var table: Dictionary = NEG if neg else SOL
	for idx in table:
		if only != "" and str(idx + 1) != only:
			continue
		await _run(idx, table)
	for l in log_lines:
		print(l)
	get_tree().quit()


func _f(n := 1) -> void:
	for i in n:
		await get_tree().physics_frame


func _hold(d: float) -> void:
	if d > 0.0:
		Input.action_release("move_left")
		Input.action_press("move_right")
	elif d < 0.0:
		Input.action_release("move_right")
		Input.action_press("move_left")
	else:
		Input.action_release("move_left")
		Input.action_release("move_right")


func _release() -> void:
	for a in ["move_left", "move_right", "jump", "echo"]:
		Input.action_release(a)


func _wait_floor() -> void:
	await _f(3)
	var n := 0
	while not level.player.is_on_floor() and n < 240 and not level.player.dead:
		await _f()
		n += 1


func _jump() -> void:
	await _wait_floor()
	Input.action_press("jump")
	await _f(20)
	Input.action_release("jump")


func _do(cmd: Array) -> void:
	var p := level.player
	match cmd[0]:
		"jr":
			Input.action_press("move_right")
			var n := 0
			while p.position.x < cmd[1] and n < 900:
				await _f()
				n += 1
			await _jump()
		"jn":
			Input.action_press("move_right")
			await _jump()
		"rt":
			Input.action_press("move_right")
			var n := 0
			while p.position.x < cmd[1] and n < 900:
				await _f()
				n += 1
			Input.action_release("move_right")
			await _f(25)
		"q":
			await _wait_floor()
			Input.action_press("echo")
			await _f(2)
			Input.action_release("echo")
			await _f(2)
		"win":
			Input.action_press("move_right")
			var n := 0
			while not level.finished and n < 1200 and not p.dead:
				await _f()
				n += 1
		"w":
			await _f(cmd[1])
		"lt":
			_hold(-1.0)
			var n := 0
			while p.position.x > cmd[1] and n < 900:
				await _f()
				n += 1
			_hold(0.0)
			await _f(25)
		"lt_y":
			_hold(-1.0)
			var n := 0
			while p.position.y < cmd[1] and n < 900:
				await _f()
				n += 1
			await _f(10)
			_hold(0.0)
		"wait_y":
			var n := 0
			while p.position.y < cmd[1] and n < 900:
				await _f()
				n += 1
		"cling_r":
			_hold(1.0)
			var n := 0
			while not p.clinging and n < 600 and not p.dead:
				await _f()
				n += 1
		"climb":
			var n := 0
			while p.position.y < cmd[1] and n < 1500 and not p.dead:
				if p.clinging:
					var d := p.wall_dir
					Input.action_press("jump")
					await _f(6)
					Input.action_release("jump")
					_hold(-d)
				else:
					await _f()
				n += 1
			_hold(cmd[2])
			await _wait_floor()
		"die":
			Input.action_press("move_right")
		"wait_echo":
			var n := 0
			while not level.echoes[cmd[1]].solid and n < 900:
				await _f()
				n += 1
		"lift_down":
			var n := 0
			while level.lifts[cmd[1]].t > 0.02 and n < 900:
				await _f()
				n += 1
		"lift_up":
			var n := 0
			while level.lifts[cmd[1]].t < 0.98 and n < 900:
				await _f()
				n += 1
		"hop":
			Input.action_press("move_right")
			Input.action_press("jump")
			var n := 0
			while p.position.x < cmd[1] and n < 120:
				await _f()
				n += 1
			Input.action_release("move_right")
			await _f(10)
			Input.action_release("jump")
			await _wait_floor()


func _run(idx: int, table: Dictionary) -> void:
	Game.current_level = idx
	level = load("res://scenes/level.tscn").instantiate()
	add_child(level)
	await _f(10)
	var trace := []
	var out := OS.get_environment("ECHO_OUT")
	var li := 0
	for life in table[idx]:
		li += 1
		if out != "" and li == table[idx].size():
			_shot_later(out, "%d_mid" % (idx + 1), 150)
		var start: int = level.lives_used
		for cmd in life:
			await _do(cmd)
			if level.finished:
				break
		if level.finished:
			break
		var n := 0
		while level.lives_used == start and n < 1200:
			await _f()
			n += 1
			if OS.get_environment("ECHO_TRACE") != "" and n % 30 == 0:
				print("  t=%d pos=(%.2f, %.2f) wind=%s floor=%s doorA=%s" % [n, level.player.position.x, level.player.position.y, level.player.in_wind, level.player.is_on_floor(), level.channels.get("a")])
		_release()
		var last: Echo = level.echoes[-1] if level.echoes.size() > 0 else null
		trace.append("life%d -> echo at (%.2f, %.2f)%s" % [start + 1, last.frames[-1].x if last else -1.0, last.frames[-1].y if last else -1.0, " died" if last and last.died else ""])
		await _f(5)
	_release()
	if out != "" and level.finished:
		await _f(70)
		get_viewport().get_texture().get_image().save_png("%s/play_%d_win.png" % [out, idx + 1])
	var rec_dir := OS.get_environment("ECHO_REC")
	if rec_dir != "" and level.finished:
		var lives := []
		for h in level.history:
			var flat := []
			for v in (h.f as PackedVector3Array):
				flat.append_array([snappedf(v.x, 0.001), snappedf(v.y, 0.001), v.z])
			lives.append({"f": flat, "a": Array(h.a as PackedByteArray), "died": h.died, "cause": h.cause, "win": h.get("win", false)})
		var fa := FileAccess.open("%s/level_%d.json" % [rec_dir, idx + 1], FileAccess.WRITE)
		fa.store_string(JSON.stringify(lives))
		fa.close()
	log_lines.append("LEVEL %d %s  lives=%d  player=(%.2f, %.2f)  %s" % [idx + 1, "PASS" if level.finished else "FAIL", level.lives_used + 1, level.player.position.x, level.player.position.y, " | ".join(trace)])
	level.queue_free()
	await _f(3)


func _shot_later(out: String, tag: String, frames: int) -> void:
	await _f(frames)
	get_viewport().get_texture().get_image().save_png("%s/play_%s.png" % [out, tag])
