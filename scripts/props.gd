class_name Props
extends RefCounted

const ANIMS := ["idle", "walk", "sprint", "jump", "fall", "die", "holding-both", "emote-yes"]
const LOOPING := ["idle", "walk", "sprint", "fall"]

static var _cache := {}


static func scene(path: String) -> PackedScene:
	if not _cache.has(path):
		_cache[path] = load(path)
	return _cache[path]


static func aabb_of(root: Node) -> AABB:
	var acc := [null]
	_collect(root, Transform3D.IDENTITY, acc, true)
	return acc[0] if acc[0] != null else AABB()


static func _collect(n: Node, xf: Transform3D, acc: Array, is_root: bool) -> void:
	var t := xf
	if n is Node3D and not is_root:
		t = xf * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		var a: AABB = t * (n as MeshInstance3D).mesh.get_aabb()
		acc[0] = a if acc[0] == null else (acc[0] as AABB).merge(a)
	for c in n.get_children():
		_collect(c, t, acc, false)


static func model(path: String, size := 1.0, by_height := false) -> Node3D:
	var holder := Node3D.new()
	var inst: Node3D = scene(path).instantiate()
	holder.add_child(inst)
	var box := aabb_of(inst)
	var extent := box.size.y if by_height else maxf(box.size.x, box.size.z)
	var k := size / maxf(extent, 0.001)
	inst.scale = Vector3.ONE * k
	var center := box.position + box.size * 0.5
	inst.position = Vector3(-center.x * k, -box.position.y * k, -center.z * k)
	return holder


static func character(path: String) -> Node3D:
	var inst: Node3D = scene(path).instantiate()
	var ap := find_anim(inst)
	if ap:
		for n in LOOPING:
			if ap.has_animation(n):
				ap.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	return inst


static func find_anim(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var r := find_anim(c)
		if r:
			return r
	return null


static func override_material(n: Node, mat: Material) -> void:
	if n is MeshInstance3D:
		(n as MeshInstance3D).material_override = mat
		(n as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		override_material(c, mat)


static func set_shadows(n: Node, on: bool) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if on else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		set_shadows(c, on)


static func shader_mat(path: String, params := {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(path)
	for k in params:
		m.set_shader_parameter(k, params[k])
	return m
