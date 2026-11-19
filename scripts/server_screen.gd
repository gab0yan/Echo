extends Node

var _t := 0.0


func _ready() -> void:
	Sfx.process_mode = Node.PROCESS_MODE_DISABLED
	print("[server] ready. Players connect to this machine on UDP port %d." % Net.PORT)


func _process(delta: float) -> void:
	_t += delta
	if _t >= 60.0:
		_t = 0.0
		print("[server] %d open room(s)" % Net.room_count())
