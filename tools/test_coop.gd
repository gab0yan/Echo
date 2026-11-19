extends Node

var level: Level
var st := [{}, {}]
var _token := 0
var log_lines: Array[String] = []


func _ready() -> void:
	Game.save_enabled = false
	var only := OS.get_environment("ECHO_ONLY")
	for idx in Levels.coop_count():
		if only != "" and str(idx + 1) != only:
			continue
		await _run(idx)
	for l in log_lines:
		print(l)
	get_tree().quit()


func P(i: int) -> Player:
	return level.players[i]


func on_floor(i: int) -> bool:
	return P(i).is_on_floor() and absf(P(i).velocity.x) < 0.2


func solutions(idx: int) -> Array:
	match idx:
		0:
			return [[
				[["rt", 9.3], ["until", func() -> bool: return P(1).position.x > 16.0 and on_floor(1)], ["rt", 14.0], ["until", func() -> bool: return P(1).position.x > 22.0], ["rt", 21.3]],
				[["rt", 16.3], ["until", func() -> bool: return P(0).position.x > 13.6], ["rt", 23.3]],
			]]
		1:
			return [
				[
					[["lt", 2.7], ["until", func() -> bool: return P(1).position.x < 3.9 and on_floor(1)], ["q"]],
					[["until", func() -> bool: return P(0).position.x < 3.0], ["lt", 3.7], ["w", 10], ["q"]],
				],
				[[["rt", 19.3]], [["rt", 21.3]]],
			]
		2:
			return [[
				[["jr", 9.0], ["wait_floor"], ["rt", 12.5], ["until", func() -> bool: return level.channels.a], ["lift_down", 0], ["hop", -11.3], ["lift_up", 0], ["jn"], ["wait_floor"], ["hold", 0.0], ["until", func() -> bool: return P(1).position.x > 24.5], ["rt", 24.3]],
				[["until", func() -> bool: return P(0).position.x > 12.5 and on_floor(0)], ["rt", 9.2], ["hop", 10.8], ["jn"], ["jn"], ["wait_floor"], ["rt", 18.3], ["until", func() -> bool: return P(0).position.x > 15.2 and P(0).is_on_floor()], ["rt", 26.3]],
			]]
		3:
			return [
				[[["lt", 2.7], ["q"]], [["lt", 18.7], ["q"]]],
				[[["rt", 13.3]], [["rt", 30.3]]],
			]
		4:
			return [
				[[["lt", 1.7], ["q"]], [["until", func() -> bool: return not P(0).visible], ["jr", 6.8], ["die"]]],
				[[["w", 20], ["q"]], [["lt", 2.7], ["w", 10], ["q"]]],
				[
					[["until", func() -> bool: return P(1).position.x > 15.5], ["jr", 6.8], ["jn"], ["rt", 28.3]],
					[["until", func() -> bool: return level.channels.a], ["jr", 6.8], ["jn"], ["rt", 30.3]],
				],
			]
		5:
			return [
				[
					[["lt", 2.7], ["until", func() -> bool: return P(1).position.x < 3.9 and on_floor(1)], ["q"]],
					[["until", func() -> bool: return P(0).position.x < 3.0], ["lt", 3.7], ["w", 10], ["q"]],
				],
				[
					[["rt", 8.4], ["lift_down", 0], ["hop", 10.4], ["lift_up", 0], ["until", func() -> bool: return P(1).position.x > 18.4 and on_floor(1)], ["jr", 17.2], ["jn"], ["rt", 20.3]],
					[["rt", 9.4], ["lift_down", 0], ["hop", 11.5], ["lift_up", 0], ["rt", 18.3], ["until", func() -> bool: return P(0).position.y > 8.8], ["lt", 16.7]],
				],
			]
	return []


func _f(n := 1) -> void:
	for i in n:
		await get_tree().physics_frame


func _hold(i: int, d: float) -> void:
	st[i].axis = d


func _feed() -> void:
	for i in 2:
		var s: Dictionary = st[i]
		P(i).feed(s.axis, s.jump, s.jn, s.en, 0)


func _wait_floor(i: int, tok: int) -> void:
	await _f(3)
	var n := 0
	while tok == _token and not P(i).is_on_floor() and n < 240 and not P(i).dead:
		await _f()
		n += 1


func _jump(i: int, tok: int) -> void:
	await _wait_floor(i, tok)
	st[i].jump = true
	st[i].jn += 1
	await _f(20)
	st[i].jump = false


func _do(i: int, cmd: Array, tok: int) -> void:
	var p := P(i)
	match cmd[0]:
		"rt", "lt":
			var d := 1.0 if cmd[0] == "rt" else -1.0
			_hold(i, d)
			var n := 0
			while tok == _token and (p.position.x - cmd[1]) * d < 0.0 and n < 1200:
				await _f()
				n += 1
			_hold(i, 0.0)
			await _f(25)
		"jr":
			_hold(i, 1.0)
			var n := 0
			while tok == _token and p.position.x < cmd[1] and n < 900:
				await _f()
				n += 1
			await _jump(i, tok)
		"jn":
			_hold(i, 1.0)
			await _jump(i, tok)
		"hop":
			var tgt: float = absf(cmd[1])
			var d := 1.0 if cmd[1] > 0 else -1.0
			_hold(i, d)
			st[i].jump = true
			st[i].jn += 1
			var n := 0
			while tok == _token and (p.position.x - tgt) * d < 0.0 and n < 120:
				await _f()
				n += 1
			_hold(i, 0.0)
			await _f(10)
			st[i].jump = false
			await _wait_floor(i, tok)
		"q":
			await _wait_floor(i, tok)
			st[i].en += 1
			await _f(3)
		"until":
			var c: Callable = cmd[1]
			var n := 0
			while tok == _token and not c.call() and n < 1500:
				await _f()
				n += 1
		"w":
			await _f(cmd[1])
		"wait_floor":
			await _wait_floor(i, tok)
		"hold":
			_hold(i, cmd[1])
		"die":
			_hold(i, 1.0)
		"lift_down":
			var n := 0
			while tok == _token and level.lifts[cmd[1]].t > 0.02 and n < 900:
				await _f()
				n += 1
		"lift_up":
			var n := 0
			while tok == _token and level.lifts[cmd[1]].t < 0.98 and n < 900:
				await _f()
				n += 1


func _runner(i: int, cmds: Array, tok: int) -> void:
	for c in cmds:
		if tok != _token:
			return
		await _do(i, c, tok)


func _physics_process(_d: float) -> void:
	if level and is_instance_valid(level) and level.players.size() == 2:
		_feed()


func _run(idx: int) -> void:
	Game.coop = true
	Game.current_level = idx
	level = load("res://scenes/level.tscn").instantiate()
	add_child(level)
	for i in 2:
		level.players[i].input_mode = "remote"
	st = [{"axis": 0.0, "jump": false, "jn": 0, "en": 0}, {"axis": 0.0, "jump": false, "jn": 0, "en": 0}]
	await _f(10)
	var trace := []
	for life in solutions(idx):
		_token += 1
		var tok := _token
		var start: int = level.lives_used
		_runner(0, life[0], tok)
		_runner(1, life[1], tok)
		var n := 0
		while level.lives_used == start and not level.finished and n < 2400:
			await _f()
			n += 1
			if OS.get_environment("ECHO_TRACE") != "" and n % 60 == 0:
				print("  t=%d P1=(%.2f,%.2f) P2=(%.2f,%.2f) done=%s ch=%s" % [n, P(0).position.x, P(0).position.y, P(1).position.x, P(1).position.y, level.done, level.channels])
		_token += 1
		for i in 2:
			_hold(i, 0.0)
			st[i].jump = false
		trace.append("life%d: P1=(%.1f,%.1f) P2=(%.1f,%.1f) echoes=%d" % [start + 1, P(0).position.x, P(0).position.y, P(1).position.x, P(1).position.y, level.echoes.size()])
		if level.finished:
			break
		await _f(5)
	log_lines.append("COOP %d %s  lives=%d  %s" % [idx + 1, "PASS" if level.finished else "FAIL", level.lives_used + 1, " | ".join(trace)])
	level.queue_free()
	await _f(3)
