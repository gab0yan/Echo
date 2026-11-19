extends Node

const SOUNDS := ["jump", "land", "step1", "step2", "echo", "lock", "death", "thud", "plate_on", "plate_off",
	"door_open", "door_close", "win", "click", "hover", "rewind"]

var _streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for n in SOUNDS:
		_streams[n] = load("res://assets/audio/%s.ogg" % n)
	for i in 12:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new()
	var wav: AudioStreamWAV = load("res://assets/audio/ambient.wav")
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = int(wav.get_length() * wav.mix_rate)
	_music.stream = wav
	_music.volume_db = -9.0
	_music.bus = "Music"
	add_child(_music)
	_music.play()


func play(n: String, volume_db := 0.0, pitch := 1.0, jitter := 0.06) -> void:
	if not _streams.has(n):
		return
	for p in _pool:
		if not p.playing:
			p.stream = _streams[n]
			p.volume_db = volume_db
			p.pitch_scale = pitch * randf_range(1.0 - jitter, 1.0 + jitter)
			p.play()
			return


func duck(on: bool) -> void:
	var t := create_tween()
	t.tween_property(_music, "volume_db", -16.0 if on else -9.0, 0.4)
