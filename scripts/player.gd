class_name Player
extends CharacterBody3D

signal jumped
signal landed(impact: float)
signal died
signal wall_jumped
signal bounced

const SPEED := 5.0
const GROUND_ACCEL := 45.0
const AIR_ACCEL := 24.0
const GRAVITY := 16.0
const JUMP_VELOCITY := 7.2
const JUMP_CUT := 1.8
const COYOTE := 0.1
const BUFFER := 0.12
const MAX_FALL := 14.0
const RADIUS := 0.28
const HEIGHT := 0.9
const CLING_SLIDE := 1.1
const WALL_JUMP_X := 5.5
const WALL_JUMP_LOCK := 0.2
const WIND_ACCEL := 38.0
const WIND_MAX := 6.0
const BOUNCE_VELOCITY := 11.0

var model: Node3D
var anim: AnimationPlayer
var lamp: OmniLight3D
var level: Node
var facing := 1.0
var dead := false
var controllable := true
var anim_name := "idle"
var clinging := false
var wall_dir := 0.0
var in_wind := false
var puppet := false
var index := 0
var coop := false
var model_path := "res://assets/models/kit/character-oopi.glb"
var input_mode := "local"
var r_axis := 0.0
var r_jump_held := false
var _r_jump_n := 0
var _r_jump_seen := 0
var _r_echo_n := 0
var _r_echo_seen := 0
var _r_reset_n := 0
var _r_reset_seen := 0

var _coyote := 0.0
var _buffer := 0.0
var _was_on_floor := true
var _fall_speed := 0.0
var _squash := 1.0
var _lock := 0.0
var _bounce_cd := 0.0
var _bouncing := false


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 4 | (2 if coop else 0)
	floor_snap_length = 0.15
	floor_max_angle = deg_to_rad(50)
	axis_lock_linear_z = true
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = RADIUS
	cap.height = HEIGHT
	shape.shape = cap
	shape.position.y = HEIGHT * 0.5
	add_child(shape)
	if coop:
		var head := CollisionShape3D.new()
		var hb := BoxShape3D.new()
		hb.size = Vector3(0.46, 0.1, 0.6)
		head.shape = hb
		head.position.y = HEIGHT - 0.05
		add_child(head)
	model = Node3D.new()
	add_child(model)
	var c := Props.character(model_path)
	model.add_child(c)
	anim = Props.find_anim(c)
	Props.set_shadows(c, true)
	lamp = OmniLight3D.new()
	lamp.light_color = Color(0.6, 0.95, 1.0)
	lamp.light_energy = 0.6
	lamp.omni_range = 2.5
	lamp.position = Vector3(0, 0.7, 0.6)
	add_child(lamp)
	_play("idle")


func reset_to(pos: Vector3) -> void:
	position = pos
	velocity = Vector3.ZERO
	dead = false
	controllable = true
	facing = 1.0
	clinging = false
	wall_dir = 0.0
	_coyote = 0.0
	_buffer = 0.0
	_lock = 0.0
	_bounce_cd = 0.0
	_bouncing = false
	_was_on_floor = true
	model.rotation = Vector3(0, PI * 0.5 * 0.78, 0)
	model.scale = Vector3.ONE
	_play("idle")


func die() -> void:
	if dead:
		return
	dead = true
	clinging = false
	velocity = Vector3(velocity.x * 0.3, 3.0, 0)
	_play("die")
	died.emit()


func bounce() -> void:
	if _bounce_cd > 0.0 or dead:
		return
	_bounce_cd = 0.25
	velocity.y = BOUNCE_VELOCITY
	_bouncing = true
	_coyote = 0.0
	_squash = 1.4
	bounced.emit()


func feed(axis: float, jump_held: bool, jump_n: int, echo_n: int, reset_n: int) -> void:
	r_axis = clampf(axis, -1.0, 1.0)
	r_jump_held = jump_held
	_r_jump_n = jump_n
	_r_echo_n = echo_n
	_r_reset_n = reset_n


func _axis() -> float:
	match input_mode:
		"local":
			return Input.get_axis("move_left", "move_right")
		"remote":
			return r_axis
	return 0.0


func _jump_just() -> bool:
	match input_mode:
		"local":
			return Input.is_action_just_pressed("jump")
		"remote":
			if _r_jump_n != _r_jump_seen:
				_r_jump_seen = _r_jump_n
				return true
	return false


func _jump_held() -> bool:
	match input_mode:
		"local":
			return Input.is_action_pressed("jump")
		"remote":
			return r_jump_held
	return false


func echo_just() -> bool:
	match input_mode:
		"local":
			return Input.is_action_just_pressed("echo")
		"remote":
			if _r_echo_n != _r_echo_seen:
				_r_echo_seen = _r_echo_n
				return true
	return false


func reset_just() -> bool:
	match input_mode:
		"local":
			return Input.is_action_just_pressed("restart")
		"remote":
			if _r_reset_n != _r_reset_seen:
				_r_reset_seen = _r_reset_n
				return true
	return false


func _grip_at(dir: float) -> bool:
	return level != null and level.has_method("grip_at") and level.grip_at(position.x, position.y, dir)


func puppet_to(pos: Vector3, f: float, a: String) -> void:
	if dead:
		return
	position = pos
	velocity = Vector3.ZERO
	facing = f
	var target := f * PI * 0.5 * (1.0 if a == "holding-both" else 0.78)
	model.rotation.y = lerp_angle(model.rotation.y, target, 0.3)
	_play(a)


func _physics_process(delta: float) -> void:
	if puppet and not dead:
		return
	if dead:
		velocity.y = maxf(velocity.y - GRAVITY * 0.6 * delta, -4.0)
		velocity.x = move_toward(velocity.x, 0.0, 8.0 * delta)
		move_and_slide()
		position.z = 0.0
		return
	_bounce_cd -= delta
	_lock -= delta
	var dir := _axis() if controllable else 0.0
	var on_floor := is_on_floor()
	_coyote = COYOTE if on_floor else _coyote - delta
	if _jump_just() and controllable:
		_buffer = BUFFER
	else:
		_buffer -= delta
	clinging = false
	if not on_floor and absf(dir) > 0.1 and _lock <= 0.0 and is_on_wall() and _grip_at(signf(dir)):
		clinging = true
		wall_dir = signf(dir)
	velocity.y -= GRAVITY * delta
	if in_wind:
		velocity.y = minf(velocity.y + WIND_ACCEL * delta, WIND_MAX)
	if clinging:
		velocity.y = maxf(velocity.y, -CLING_SLIDE)
		if _buffer > 0.0:
			velocity = Vector3(-wall_dir * WALL_JUMP_X, JUMP_VELOCITY, 0)
			facing = -wall_dir
			_buffer = 0.0
			_lock = WALL_JUMP_LOCK
			clinging = false
			_squash = 1.2
			wall_jumped.emit()
	elif _buffer > 0.0 and _coyote > 0.0:
		velocity.y = JUMP_VELOCITY
		_buffer = 0.0
		_coyote = 0.0
		_squash = 1.25
		jumped.emit()
	if velocity.y <= 0.0:
		_bouncing = false
	if velocity.y > 0.0 and not in_wind and not _bouncing and _lock <= 0.0 and not (controllable and _jump_held()):
		velocity.y -= GRAVITY * JUMP_CUT * delta
	velocity.y = maxf(velocity.y, -MAX_FALL)
	if _lock <= 0.0:
		velocity.x = move_toward(velocity.x, dir * SPEED, (GROUND_ACCEL if on_floor else AIR_ACCEL) * delta)
		if absf(dir) > 0.1:
			facing = signf(dir)
	if not on_floor:
		_fall_speed = -velocity.y
	move_and_slide()
	position.z = 0.0
	velocity.z = 0.0
	var now_floor := is_on_floor()
	if now_floor and not _was_on_floor:
		landed.emit(_fall_speed)
		_squash = 0.75 if _fall_speed > 6.0 else 0.88
	_was_on_floor = now_floor
	_update_visual(delta, now_floor)


func _update_visual(delta: float, on_floor: bool) -> void:
	var target := facing * PI * 0.5 * 0.78
	if clinging:
		target = wall_dir * PI * 0.5
	model.rotation.y = lerp_angle(model.rotation.y, target, minf(1.0, delta * 16.0))
	_squash = lerpf(_squash, 1.0, minf(1.0, delta * 12.0))
	model.scale = Vector3(1.0 / sqrt(_squash), _squash, 1.0 / sqrt(_squash))
	var a := "idle"
	if clinging:
		a = "holding-both"
	elif not on_floor:
		a = "jump" if velocity.y > 0.5 else "fall"
	elif absf(velocity.x) > 3.6:
		a = "sprint"
	elif absf(velocity.x) > 0.4:
		a = "walk"
	_play(a)


func _play(n: String) -> void:
	anim_name = n
	if anim and anim.has_animation(n) and anim.current_animation != n:
		anim.play(n, 0.12)


func anim_index() -> int:
	return maxi(0, Props.ANIMS.find(anim_name))
