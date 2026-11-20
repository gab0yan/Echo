extends Node

signal status_changed(text: String)
signal state_changed
signal lobbies_changed
signal session_ended(reason: String)

enum State { OFFLINE, CONNECTING, BROWSING, WAITING, PAIRED }

const PORT := 7777
const PROTOCOL := 3
const DEFAULT_SERVER := "37.186.113.43"
const CODE_CHARS := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
const CUSTOM_CHARS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
const CODE_LENGTH := 5
const CODE_MIN := 4
const CODE_MAX := 8
const NAME_MAX := 16

var state := State.OFFLINE
var server_mode := false
var is_online := false
var is_host := false
var peer_connected := false
var partner_id := 0
var partner_name := ""
var room_code := ""
var room_name := ""
var room_public := true
var lobbies: Array = []
var level: Level
var status := ""
var status_is_error := false

var _rooms := {}
var _peer_room := {}
var _rng := RandomNumberGenerator.new()
var _jump_n := 0
var _hello_t := -1.0
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
	var args := OS.get_cmdline_user_args() + OS.get_cmdline_args()
	if "--server" in args:
		var port := PORT
		for a in args:
			if a.begins_with("--port="):
				port = int(a.substr(7))
		start_server.call_deferred(port)


func _new_enet() -> Variant:
	if not ClassDB.class_exists("ENetMultiplayerPeer"):
		return null
	return ClassDB.instantiate("ENetMultiplayerPeer")


func _online_peer() -> bool:
	var p := multiplayer.multiplayer_peer
	return p != null and not p is OfflineMultiplayerPeer


func server_address() -> String:
	var s := str(Game.settings.get("server", DEFAULT_SERVER)).strip_edges()
	return s if s != "" else DEFAULT_SERVER


func _server_host_port() -> Array:
	var s := server_address()
	var host := s
	var port := PORT
	if s.count(":") == 1:
		host = s.get_slice(":", 0)
		var p := int(s.get_slice(":", 1))
		if p > 0 and p < 65536:
			port = p
	return [host, port]


func player_name() -> String:
	return clean_name(str(Game.settings.get("player_name", "")))


func clean_name(n: String) -> String:
	var s := n.strip_edges().substr(0, NAME_MAX)
	return s if s != "" else "Player"


func _set_status(t: String, error := false) -> void:
	status = t
	status_is_error = error
	status_changed.emit(t)


func _set_state(s: State) -> void:
	state = s
	state_changed.emit()


func clean_code(code: String) -> String:
	var out := ""
	for ch in code.to_upper():
		if CUSTOM_CHARS.contains(ch):
			out += ch
	return out.substr(0, CODE_MAX)


func connect_server() -> void:
	if state != State.OFFLINE:
		return
	leave()
	var hp := _server_host_port()
	var peer: Variant = _new_enet()
	if peer == null:
		_set_status("Online play is not available in this version.", true)
		return
	var err: int = peer.create_client(hp[0], hp[1])
	if err != OK:
		_set_status("Could not start a connection to %s" % server_address(), true)
		return
	multiplayer.multiplayer_peer = peer
	_set_state(State.CONNECTING)
	_set_status("Connecting to the room server...")


func _on_connected() -> void:
	if server_mode:
		return
	_hello_t = 6.0
	_srv_hello.rpc_id(1, PROTOCOL)


func refresh_lobbies() -> void:
	if state == State.BROWSING and _online_peer():
		_srv_list.rpc_id(1)


func create_lobby(lobby_name: String, public: bool, custom_code := "") -> void:
	if state != State.BROWSING:
		return
	var code := clean_code(custom_code)
	if not public and code != "" and code.length() < CODE_MIN:
		_set_status("A custom code needs %d to %d letters or numbers." % [CODE_MIN, CODE_MAX], true)
		return
	var nm := lobby_name.strip_edges().substr(0, 24)
	if nm == "":
		nm = "%s's lobby" % player_name()
	_set_status("Creating the lobby...")
	_srv_create.rpc_id(1, nm, public, code if not public else "", player_name())


func join_code(code: String) -> void:
	var c := clean_code(code)
	if c.length() < CODE_MIN:
		_set_status("Type the lobby code first.", true)
		return
	_join(c)


func join_lobby(code: String) -> void:
	_join(code)


func _join(code: String) -> void:
	if state != State.BROWSING:
		return
	_set_status("Joining %s..." % code)
	_srv_join.rpc_id(1, code, player_name())


func leave_room() -> void:
	if state == State.WAITING or state == State.PAIRED:
		_srv_leave.rpc_id(1)
	_clear_room()
	if _online_peer():
		_set_state(State.BROWSING)
		refresh_lobbies()


func kick_partner() -> void:
	if is_host and peer_connected:
		_srv_kick.rpc_id(1)


func _clear_room() -> void:
	is_online = false
	is_host = false
	peer_connected = false
	partner_id = 0
	partner_name = ""
	room_code = ""
	room_name = ""


func leave() -> void:
	var peer := multiplayer.multiplayer_peer
	if peer and not peer is OfflineMultiplayerPeer:
		if not server_mode and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			_srv_leave.rpc_id(1)
			var h: Variant = peer.get("host")
			if h:
				h.flush()
		peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_clear_room()
	level = null
	lobbies = []
	if state != State.OFFLINE:
		_set_state(State.OFFLINE)


func request_leave() -> void:
	leave_room()
	Game.go_coop_menu("You left the lobby.")


func _on_failed() -> void:
	var addr := server_address()
	leave()
	_set_status("Could not reach the room server at %s." % addr, true)
	session_ended.emit(status)


func _on_server_gone() -> void:
	var in_level := level != null
	leave()
	_set_status("Lost connection to the room server.", true)
	session_ended.emit(status)
	if in_level:
		Game.go_coop_menu(status)


func _on_peer_disconnected(id: int) -> void:
	if server_mode:
		_srv_drop(id)


func start_server(port := PORT) -> Error:
	server_mode = true
	var peer: Variant = _new_enet()
	if peer == null:
		_set_status("Online play is not available in this version.", true)
		print("[server] online play is not available in this build")
		return ERR_UNAVAILABLE
	var err: int = peer.create_server(port, 128)
	if err != OK:
		print("[server] could not listen on UDP %d (error %d)" % [port, err])
		return err
	multiplayer.multiplayer_peer = peer
	multiplayer.server_relay = true
	print("[server] Echo room server (protocol %d) listening on UDP port %d" % [PROTOCOL, port])
	get_tree().change_scene_to_file("res://scenes/server.tscn")
	return OK


func room_count() -> int:
	return _rooms.size()


func _new_code() -> String:
	while true:
		var c := ""
		for i in CODE_LENGTH:
			c += CODE_CHARS[_rng.randi() % CODE_CHARS.length()]
		if not _rooms.has(c):
			return c
	return ""


func _sender() -> int:
	return multiplayer.get_remote_sender_id()


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
			_cl_partner_left.rpc_id(room.guest, "closed")
			_peer_room.erase(room.guest)
		_rooms.erase(code)
		print("[server] lobby %s closed (%d open)" % [code, _rooms.size()])
	elif room.guest == id:
		room.guest = 0
		room.guest_name = ""
		room.in_game = false
		_cl_partner_left.rpc_id(room.host, "left")
		print("[server] guest left lobby %s" % code)


@rpc("any_peer", "call_remote", "reliable")
func _srv_hello(proto: int) -> void:
	if not server_mode:
		return
	_cl_welcome.rpc_id(_sender(), proto == PROTOCOL)


@rpc("any_peer", "call_remote", "reliable")
func _srv_list() -> void:
	if not server_mode:
		return
	var out := []
	for code in _rooms:
		var r: Dictionary = _rooms[code]
		if r.public:
			out.append({"code": code, "name": r.name, "host": r.host_name, "players": 1 if r.guest == 0 else 2, "in_game": r.in_game})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.players) < int(b.players))
	_cl_list.rpc_id(_sender(), out)


@rpc("any_peer", "call_remote", "reliable")
func _srv_create(lobby_name: String, public: bool, custom: String, host_name: String) -> void:
	if not server_mode:
		return
	var id := _sender()
	_srv_drop(id)
	var code := clean_code(custom)
	if code != "":
		if code.length() < CODE_MIN:
			_cl_error.rpc_id(id, "A custom code needs %d to %d letters or numbers." % [CODE_MIN, CODE_MAX])
			return
		if _rooms.has(code):
			_cl_error.rpc_id(id, "The code %s is already taken. Try another one." % code)
			return
	else:
		code = _new_code()
	var nm := lobby_name.strip_edges().substr(0, 24)
	_rooms[code] = {"host": id, "host_name": clean_name(host_name), "guest": 0, "guest_name": "", "public": public,
		"name": nm if nm != "" else "Lobby", "banned": {}, "in_game": false}
	_peer_room[id] = code
	print("[server] %s lobby %s \"%s\" created (%d open)" % ["public" if public else "private", code, nm, _rooms.size()])
	_cl_room.rpc_id(id, code, _rooms[code].name, public)


@rpc("any_peer", "call_remote", "reliable")
func _srv_join(code: String, guest_name: String) -> void:
	if not server_mode:
		return
	var id := _sender()
	code = clean_code(code)
	if not _rooms.has(code):
		_cl_error.rpc_id(id, "There is no lobby with the code %s." % code)
		return
	var room: Dictionary = _rooms[code]
	var gname := clean_name(guest_name)
	if room.host == id:
		_cl_error.rpc_id(id, "That is your own lobby.")
		return
	if room.banned.has(id) or room.banned.has(gname.to_lower()):
		_cl_error.rpc_id(id, "The host removed you from this lobby.")
		return
	if room.guest != 0:
		_cl_error.rpc_id(id, "That lobby is already full.")
		return
	_srv_drop(id)
	room.guest = id
	room.guest_name = gname
	_peer_room[id] = code
	print("[server] %s joined lobby %s" % [gname, code])
	_cl_paired.rpc_id(id, code, room.name, room.public, room.host, room.host_name, false)
	_cl_paired.rpc_id(room.host, code, room.name, room.public, id, gname, true)


@rpc("any_peer", "call_remote", "reliable")
func _srv_leave() -> void:
	if server_mode:
		_srv_drop(_sender())


@rpc("any_peer", "call_remote", "reliable")
func _srv_kick() -> void:
	if not server_mode:
		return
	var id := _sender()
	if not _peer_room.has(id):
		return
	var code: String = _peer_room[id]
	var room: Dictionary = _rooms.get(code, {})
	if room.is_empty() or room.host != id or room.guest == 0:
		return
	var g: int = room.guest
	room.banned[g] = true
	room.banned[str(room.guest_name).to_lower()] = true
	print("[server] host kicked %s from lobby %s" % [room.guest_name, code])
	_peer_room.erase(g)
	room.guest = 0
	room.guest_name = ""
	room.in_game = false
	_cl_kicked.rpc_id(g)
	_cl_partner_left.rpc_id(id, "kicked")


@rpc("any_peer", "call_remote", "reliable")
func _srv_in_game(on: bool) -> void:
	if not server_mode:
		return
	var id := _sender()
	if _peer_room.has(id) and _rooms.has(_peer_room[id]) and _rooms[_peer_room[id]].host == id:
		_rooms[_peer_room[id]].in_game = on


@rpc("authority", "call_remote", "reliable")
func _cl_welcome(ok: bool) -> void:
	_hello_t = -1.0
	if not ok:
		leave()
		_set_status("Your game version does not match the server. Update the game.", true)
		session_ended.emit(status)
		return
	_set_state(State.BROWSING)
	_set_status("Connected. Join a public lobby, or create your own.")
	refresh_lobbies()


@rpc("authority", "call_remote", "reliable")
func _cl_list(rooms: Array) -> void:
	lobbies = rooms
	lobbies_changed.emit()


@rpc("authority", "call_remote", "reliable")
func _cl_room(code: String, nm: String, public: bool) -> void:
	room_code = code
	room_name = nm
	room_public = public
	is_host = true
	_set_state(State.WAITING)
	_set_status("Lobby created. Waiting for a player." if public else "Private lobby created. Send the code to your friend.")


@rpc("authority", "call_remote", "reliable")
func _cl_paired(code: String, nm: String, public: bool, partner: int, pname: String, host: bool) -> void:
	room_code = code
	room_name = nm
	room_public = public
	partner_id = partner
	partner_name = pname
	is_host = host
	peer_connected = true
	is_online = true
	_set_state(State.PAIRED)
	_set_status(("%s joined! Pick a level." % pname) if host else ("Joined %s. Waiting for %s to pick a level." % [nm, pname]))
	Sfx.play("lock", -4.0, 1.2)


@rpc("authority", "call_remote", "reliable")
func _cl_partner_left(why: String) -> void:
	var in_level := level != null
	var who := partner_name
	peer_connected = false
	is_online = false
	partner_id = 0
	partner_name = ""
	if why == "closed":
		_clear_room()
		_set_state(State.BROWSING)
		_set_status("The host closed the lobby.", true)
		refresh_lobbies()
	else:
		_set_state(State.WAITING)
		_set_status(("You removed %s. The lobby is open again." % who) if why == "kicked" else ("%s left. The lobby is still open." % who), why != "kicked")
	session_ended.emit(status)
	if in_level:
		Game.go_coop_menu(status)


@rpc("authority", "call_remote", "reliable")
func _cl_kicked() -> void:
	var in_level := level != null
	_clear_room()
	_set_state(State.BROWSING)
	_set_status("The host removed you from the lobby.", true)
	refresh_lobbies()
	session_ended.emit(status)
	if in_level:
		Game.go_coop_menu(status)


@rpc("authority", "call_remote", "reliable")
func _cl_error(msg: String) -> void:
	_set_status(msg, true)
	refresh_lobbies()


func _from_partner() -> bool:
	return peer_connected and _sender() == partner_id


func start_level(i: int) -> void:
	if not is_host:
		return
	if peer_connected:
		_rpc_start.rpc_id(partner_id, i)
		_srv_in_game.rpc_id(1, true)
	Game.play_coop(i)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_start(i: int) -> void:
	if _from_partner():
		Game.play_coop(i)


func request_reset() -> void:
	_reset_n += 1


func _process(delta: float) -> void:
	if _hello_t > 0.0:
		_hello_t -= delta
		if _hello_t <= 0.0 and state == State.CONNECTING:
			leave()
			_set_status("The room server did not answer. It is probably running another version of Echo: update and restart it.", true)
			session_ended.emit(status)


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
