extends Node

signal status_changed(text: String)
signal state_changed
signal session_ended(reason: String)

enum State { OFFLINE, CONNECTING, WAITING, PAIRED }

const PORT := 7777
const PROTOCOL := 2
const DEFAULT_SERVER := "127.0.0.1"
const CODE_CHARS := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
const CODE_LENGTH := 5

var state := State.OFFLINE
var server_mode := false
var is_online := false
var is_host := false
var peer_connected := false
var partner_id := 0
var room_code := ""
var level: Level
var status := ""
var status_is_error := false

var _pending := ""
var _rooms := {}
var _peer_room := {}
var _rng := RandomNumberGenerator.new()
var _jump_n := 0
var _echo_n := 0
var _reset_n := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = -30
	_rng.randomize()
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_failed)
	multiplayer.server_disconnected.connect(_on_server_gone)
	if "--server" in OS.get_cmdline_user_args() or "--server" in OS.get_cmdline_args():
		start_server.call_deferred()


func server_address() -> String:
	var s := str(Game.settings.get("server", DEFAULT_SERVER)).strip_edges()
	return s if s != "" else DEFAULT_SERVER


func _set_status(t: String, error := false) -> void:
	status = t
	status_is_error = error
	status_changed.emit(t)


func _set_state(s: State) -> void:
	state = s
	state_changed.emit()


func start_server(port := PORT) -> Error:
	server_mode = true
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, 64)
	if err != OK:
		print("[server] could not listen on UDP %d (error %d)" % [port, err])
		return err
	multiplayer.multiplayer_peer = peer
	multiplayer.server_relay = true
	print("[server] Echo room server listening on UDP port %d" % port)
	get_tree().change_scene_to_file("res://scenes/server.tscn")
	return OK


func create_room() -> void:
	_connect_then("create")


func join_room(code: String) -> void:
	var c := clean_code(code)
	if c.length() != CODE_LENGTH:
		_set_status("A room code has %d letters." % CODE_LENGTH, true)
		return
	_connect_then("join:" + c)


func clean_code(code: String) -> String:
	var out := ""
	for ch in code.to_upper():
		if CODE_CHARS.contains(ch):
			out += ch
	return out.substr(0, CODE_LENGTH)


func _connect_then(action: String) -> void:
	leave()
	_pending = action
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(server_address(), PORT)
	if err != OK:
		_set_status("Could not start a connection to %s" % server_address(), true)
		return
	multiplayer.multiplayer_peer = peer
	_set_state(State.CONNECTING)
	_set_status("Connecting to the room server...")


func leave() -> void:
	var peer := multiplayer.multiplayer_peer
	if peer and not peer is OfflineMultiplayerPeer:
		if not server_mode and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			_srv_leave.rpc_id(1)
			(peer as ENetMultiplayerPeer).host.flush()
		peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	is_online = false
	is_host = false
	peer_connected = false
	partner_id = 0
	room_code = ""
	level = null
	_pending = ""
	if state != State.OFFLINE:
		_set_state(State.OFFLINE)


func request_leave() -> void:
	leave()
	Game.go_coop_menu("You left the room.")


func _on_connected() -> void:
	if server_mode:
		return
	if _pending == "create":
		_set_status("Creating a room...")
		_srv_create.rpc_id(1, PROTOCOL)
	elif _pending.begins_with("join:"):
		_set_status("Joining room %s..." % _pending.substr(5))
		_srv_join.rpc_id(1, PROTOCOL, _pending.substr(5))


func _on_failed() -> void:
	var addr := server_address()
	leave()
	_set_status("Could not reach the room server at %s." % addr, true)
	session_ended.emit(status)


func _on_server_gone() -> void:
	_end("Lost connection to the room server.")


func _end(reason: String) -> void:
	var in_level := level != null
	leave()
	_set_status(reason, true)
	session_ended.emit(reason)
	if in_level:
		Game.go_coop_menu(reason)


func _on_peer_disconnected(id: int) -> void:
	if server_mode:
		_srv_drop(id)


func _new_code() -> String:
	while true:
		var c := ""
		for i in CODE_LENGTH:
			c += CODE_CHARS[_rng.randi() % CODE_CHARS.length()]
		if not _rooms.has(c):
			return c
	return ""


func _srv_drop(id: int) -> void:
	if not _peer_room.has(id):
		return
	var code: String = _peer_room[id]
	_peer_room.erase(id)
	if not _rooms.has(code):
		return
	var room: Dictionary = _rooms[code]
	if room.host == id:
		if room.guest != 0:
			_cl_partner_left.rpc_id(room.guest, true)
			_peer_room.erase(room.guest)
		_rooms.erase(code)
		print("[server] room %s closed (%d open)" % [code, _rooms.size()])
	elif room.guest == id:
		room.guest = 0
		_cl_partner_left.rpc_id(room.host, false)
		print("[server] guest left room %s" % code)


@rpc("any_peer", "call_remote", "reliable")
func _srv_create(proto: int) -> void:
	if not server_mode:
		return
	var id := multiplayer.get_remote_sender_id()
	if proto != PROTOCOL:
		_cl_error.rpc_id(id, "Your game version does not match the server. Update the game.")
		return
	_srv_drop(id)
	var code := _new_code()
	_rooms[code] = {"host": id, "guest": 0}
	_peer_room[id] = code
	print("[server] room %s created (%d open)" % [code, _rooms.size()])
	_cl_room.rpc_id(id, code)


@rpc("any_peer", "call_remote", "reliable")
func _srv_join(proto: int, code: String) -> void:
	if not server_mode:
		return
	var id := multiplayer.get_remote_sender_id()
	if proto != PROTOCOL:
		_cl_error.rpc_id(id, "Your game version does not match the server. Update the game.")
		return
	if not _rooms.has(code):
		_cl_error.rpc_id(id, "There is no room with the code %s." % code)
		return
	var room: Dictionary = _rooms[code]
	if room.guest != 0:
		_cl_error.rpc_id(id, "Room %s is already full." % code)
		return
	if room.host == id:
		_cl_error.rpc_id(id, "That is your own room.")
		return
	room.guest = id
	_peer_room[id] = code
	print("[server] room %s is full, game on" % code)
	_cl_paired.rpc_id(id, code, room.host, false)
	_cl_paired.rpc_id(room.host, code, id, true)


@rpc("any_peer", "call_remote", "reliable")
func _srv_leave() -> void:
	if server_mode:
		_srv_drop(multiplayer.get_remote_sender_id())


@rpc("authority", "call_remote", "reliable")
func _cl_room(code: String) -> void:
	room_code = code
	is_host = true
	_set_state(State.WAITING)
	_set_status("Room created. Send the code to your friend.")


@rpc("authority", "call_remote", "reliable")
func _cl_paired(code: String, partner: int, host: bool) -> void:
	room_code = code
	partner_id = partner
	is_host = host
	peer_connected = true
	is_online = true
	_set_state(State.PAIRED)
	_set_status("Your friend joined! Pick a level." if host else "Joined! Waiting for the host to pick a level.")
	Sfx.play("lock", -4.0, 1.2)


@rpc("authority", "call_remote", "reliable")
func _cl_partner_left(room_closed: bool) -> void:
	var in_level := level != null
	peer_connected = false
	is_online = false
	partner_id = 0
	if room_closed or not is_host:
		leave()
		_set_status("The host closed the room.", true)
	else:
		_set_state(State.WAITING)
		_set_status("Your friend left. The room is still open.", true)
	session_ended.emit(status)
	if in_level:
		Game.go_coop_menu(status)


@rpc("authority", "call_remote", "reliable")
func _cl_error(msg: String) -> void:
	leave()
	_set_status(msg, true)
	session_ended.emit(msg)


func _from_partner() -> bool:
	return peer_connected and multiplayer.get_remote_sender_id() == partner_id


func start_level(i: int) -> void:
	if not is_host:
		return
	if peer_connected:
		_rpc_start.rpc_id(partner_id, i)
	Game.play_coop(i)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_start(i: int) -> void:
	if _from_partner():
		Game.play_coop(i)


func request_reset() -> void:
	_reset_n += 1


func _physics_process(_delta: float) -> void:
	if server_mode or not is_online or is_host or not peer_connected or level == null:
		return
	if Input.is_action_just_pressed("jump"):
		_jump_n += 1
	if Input.is_action_just_pressed("echo"):
		_echo_n += 1
	if Input.is_action_just_pressed("restart"):
		_reset_n += 1
	_rpc_input.rpc_id(partner_id, Input.get_axis("move_left", "move_right"), Input.is_action_pressed("jump"), _jump_n, _echo_n, _reset_n)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _rpc_input(axis: float, held: bool, jn: int, en: int, rn: int) -> void:
	if not is_host or not _from_partner() or level == null or level.players.size() < 2:
		return
	level.players[1].feed(axis, held, jn, en, rn)


func send_snapshot(s: Array) -> void:
	if is_host and peer_connected:
		_rpc_snap.rpc_id(partner_id, s)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _rpc_snap(s: Array) -> void:
	if _from_partner() and level:
		level.apply_snapshot(s)


func send_echo(f: PackedVector3Array, a: PackedByteArray, died: bool, col: Color, cause: String, model: String) -> void:
	if is_host and peer_connected:
		_rpc_echo.rpc_id(partner_id, f, a, died, col, cause, model)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_echo(f: PackedVector3Array, a: PackedByteArray, died: bool, col: Color, cause: String, model: String) -> void:
	if _from_partner() and level:
		level.add_remote_echo(f, a, died, col, cause, model)


func send_fx(kind: String, a: Variant = null, b: Variant = null, c: Variant = null) -> void:
	if is_host and peer_connected:
		_rpc_fx.rpc_id(partner_id, kind, a, b, c)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_fx(kind: String, a: Variant, b: Variant, c: Variant) -> void:
	if _from_partner() and level:
		level._play_fx(kind, a, b, c)


func room_count() -> int:
	return _rooms.size()
