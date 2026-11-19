class_name Echo
extends AnimatableBody3D

signal locked(echo: Echo)

const SLIME_COLOR := Color(0.45, 1.0, 0.35)

var frames := PackedVector3Array()
var anims := PackedByteArray()
var died := false
var slime := false
var dark := false
var tint := Color(0.35, 0.95, 1.0)
var solid := false
var frozen := false
var feet := Vector3.ZERO
var top := 0.0
var model_path := "res://assets/models/kit/character-oopi.glb"

var _model: Node3D
var _anim: AnimationPlayer
var _shape: CollisionShape3D
var _mat: ShaderMaterial
var _light: OmniLight3D
var _blob: MeshInstance3D
var _cur_anim := ""
var _fade := 1.0
var _wobble := 0.0


func setup(rec_frames: PackedVector3Array, rec_anims: PackedByteArray, did_die: bool, color: Color, cause := "") -> void:
	frames = rec_frames
	anims = rec_anims
	died = did_die
	slime = did_die and cause == "acid"
	tint = SLIME_COLOR if slime else color


func height() -> float:
	if slime:
		return 0.5
	return 0.55 if died else Player.HEIGHT


func _ready() -> void:
	sync_to_physics = false
	collision_layer = 0
	collision_mask = 0
	_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	var h := height()
	box.size = Vector3(0.95 if died else 0.8, h, 1.0)
	_shape.shape = box
	_shape.position.y = h * 0.5
	_shape.disabled = true
	add_child(_shape)
	_model = Node3D.new()
	add_child(_model)
	var c := Props.character(model_path)
	_model.add_child(c)
	_anim = Props.find_anim(c)
	_mat = Props.shader_mat("res://shaders/ghost.gdshader", {"tint": tint, "strength": 0.9, "flicker": 1.0})
	Props.override_material(c, _mat)
	if slime:
		_model.visible = false
		_blob = MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.5
		sm.height = 1.0
		sm.radial_segments = 24
		sm.rings = 12
		_blob.mesh = sm
		_blob.material_override = Props.shader_mat("res://shaders/slime.gdshader")
		_blob.scale = Vector3(1.0, 0.6, 1.2)
		_blob.position.y = 0.28
		_blob.visible = false
		add_child(_blob)
	elif died:
		var crystal := Props.model("res://assets/models/space/rock_crystalsLargeA.glb", 1.0)
		crystal.name = "Crystal"
		crystal.scale = Vector3(1.0, 0.9, 1.0)
		crystal.visible = false
		Props.override_material(crystal, Props.shader_mat("res://shaders/ghost.gdshader", {"tint": tint, "strength": 2.0, "flicker": 0.2}))
		add_child(crystal)
	_light = OmniLight3D.new()
	_light.light_color = tint
	_light.light_energy = 0.5
	_light.omni_range = 4.5 if dark else 2.2
	_light.position = Vector3(0, 0.6, 0.4)
	add_child(_light)
	restart()


func restart() -> void:
	solid = false
	frozen = false
	_shape.disabled = true
	collision_layer = 0
	_fade = 0.0
	if has_node("Crystal"):
		$Crystal.visible = false
	if _blob:
		_blob.visible = false
	apply_tick(0, null)


func squish() -> void:
	_wobble = 1.0


func _process(delta: float) -> void:
	if _blob and _wobble > 0.0:
		_wobble = maxf(0.0, _wobble - delta * 2.5)
		var k := sin(_wobble * 18.0) * _wobble * 0.35
		_blob.scale = Vector3(1.0 + k, 0.6 - k * 0.8, 1.2 + k)


func apply_tick(t: int, player: Variant) -> void:
	if frames.is_empty():
		return
	var i := frames.size() - 1 if died else mini(t, frames.size() - 1)
	var f := frames[i]
	feet = Vector3(f.x, f.y, 0.0)
	top = feet.y + height()
	position = feet
	_model.rotation.y = f.z * PI * 0.5 * 0.78
	_fade = minf(1.0, _fade + 0.08)
	var boost := 2.2 if dark else 1.0
	if died or t >= frames.size() - 1:
		if not frozen:
			frozen = true
			var last: String = Props.ANIMS[clampi(anims[i], 0, Props.ANIMS.size() - 1)]
			_set_anim("die" if died else ("holding-both" if last == "holding-both" else "idle"))
			if died and _anim:
				_anim.seek(_anim.current_animation_length, true)
				_anim.pause()
			if has_node("Crystal"):
				$Crystal.visible = true
			if _blob:
				_blob.visible = true
			locked.emit(self)
		if not solid and player != null and not _overlaps_any(player):
			solid = true
			_shape.disabled = false
			collision_layer = 4
		_mat.set_shader_parameter("flicker", 0.25)
		_mat.set_shader_parameter("strength", (1.25 if died else 1.1) * _fade)
		_light.light_energy = 0.9 * boost
	else:
		_set_anim(Props.ANIMS[clampi(anims[i], 0, Props.ANIMS.size() - 1)])
		_mat.set_shader_parameter("flicker", 1.0)
		_mat.set_shader_parameter("strength", 0.75 * _fade)
		_light.light_energy = 0.45 * boost


func _overlaps_any(who: Variant) -> bool:
	if who is Array:
		for b in who:
			if b is Node3D and (b as Node3D).visible and _overlaps((b as Node3D).position):
				return true
		return false
	return who is Node3D and _overlaps((who as Node3D).position)


func _overlaps(p: Vector3) -> bool:
	return absf(p.x - feet.x) < 0.45 + Player.RADIUS and p.y < feet.y + height() - 0.02 and p.y + Player.HEIGHT > feet.y + 0.02


func _set_anim(n: String) -> void:
	if n == _cur_anim:
		return
	_cur_anim = n
	if _anim and _anim.has_animation(n):
		_anim.play(n, 0.1)
