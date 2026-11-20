class_name Level
extends Node3D

const ROWS := 12
const SPIKE_KILL := 0.35
const DOOR_SPEED := 7.0
const LIFT_SPEED := 2.2
const LIFT_PAUSE := 0.9
const DEATH_DELAY := 0.8
const CAM_DIST := 12.5
const CAM_FOV := 40.0

const BACK_PROPS := [
	["rock_largeA", 0.9], ["rock_largeB", 0.8], ["rock_crystals", 0.6], ["rock_crystalsLargeA", 0.8],
	["rock_crystalsLargeB", 0.75], ["satelliteDish", 0.8], ["machine_generator", 0.9],
	["barrels", 0.7], ["meteor_detailed", 0.8], ["rocks_smallB", 0.6], ["machine_wireless", 0.7],
	["rock", 0.6], ["crater", 0.9],
]
const FRONT_PROPS := [["rocks_smallA", 0.55], ["rocks_smallB", 0.45], ["meteor_half", 0.45], ["rock", 0.4], ["crater", 0.7]]
const FAR_PROPS := ["rock_largeA", "rock_largeB", "meteor", "meteor_detailed", "rock_crystalsLargeA"]

var menu_mode := false
var level_index := -1

var data: Dictionary
var map: Array
var cols := 0
var solid := {}
var spawn := Vector3.ZERO
var exit_pos := Vector3.ZERO
var player: Player
var players: Array[Player] = []
var spawns: Array[Vector3] = []
var exits: Array[Vector3] = []
var coop := false
var net_role := ""
var recs: Array[Dictionary] = []
var done: Array[bool] = []
var died_f: Array[bool] = []
var causes: Array[String] = []
var death_timers: Array[float] = []
var camera: Camera3D
var hud: Hud
var echoes: Array[Echo] = []
var tick := 0
var lives_used := 0
var max_echoes := 3
var finished := false
var channels := {}
var spikes: Array[Vector2] = []
var plates: Array[Dictionary] = []
var doors: Array[Dictionary] = []
var lifts: Array[Dictionary] = []
var grip := {}
var wind := {}
var acid: Array[Vector2] = []
var portals: Array[Dictionary] = []
var dark := false
var death_cause := ""
var history: Array[Dictionary] = []

var _shake := 0.0
var _hints: Array[Label3D] = []
var _echo_root: Node3D
var _rng := RandomNumberGenerator.new()
var _menu_time := 0.0
var _rock_mat: ShaderMaterial
var _beam: MeshInstance3D
var _spawn_fx: CPUParticles3D
var _portal_cds: Array[int] = []
var _ended := false
var _snap_plates := 0
var _last_status := ""


func _ready() -> void:
	process_physics_priority = -10
	if level_index < 0:
		level_index = Game.current_level
	coop = Game.coop and not menu_mode
	data = Levels.get_coop(level_index) if coop else Levels.get_level(level_index)
	if coop and Net.is_online:
		net_role = "host" if Net.is_host else "client"
		Net.level = self
	map = data.map
	cols = (map[0] as String).length()
	max_echoes = int(data.get("echoes", 3))
	_rng.seed = 7919 * (level_index + 1)
	_rock_mat = Props.shader_mat("res://shaders/rock.gdshader")
	dark = bool(data.get("dark", false))
	_build_environment()
	_parse()
	_build_terrain()
	_build_background()
	_build_decor()
	_build_entities()
	_build_camera()
	_build_motes()
	_echo_root = Node3D.new()
	_echo_root.name = "Echoes"
	add_child(_echo_root)
	if menu_mode:
		return
	_build_players()
	_build_hints()
	hud = Hud.new()
	add_child(hud)
	hud.setup(self)
	_reset_world()
	_snap_camera()
	hud.show_intro()


func cell_floor(c: int, r: int) -> Vector3:
	return Vector3(c + 0.5, ROWS - 1 - r, 0.0)


func is_solid(c: int, r: int) -> bool:
	return solid.has(Vector2i(c, r))


func _parse() -> void:
	var door_cells := {}
	for r in ROWS:
		var row: String = map[r]
		for c in cols:
			var ch := row[c]
			match ch:
				"#":
					solid[Vector2i(c, r)] = true
				"G":
					solid[Vector2i(c, r)] = true
					grip[Vector2i(c, r)] = true
				"~":
					wind[Vector2i(c, r)] = true
				"%":
					var af := cell_floor(c, r)
					acid.append(Vector2(af.x, af.y))
				"1", "2", "3", "4":
					portals.append({"n": int(ch), "pos": cell_floor(c, r)})
				"S":
					spawn = cell_floor(c, r)
				"T":
					spawns.append(cell_floor(c, r))
				"X":
					exit_pos = cell_floor(c, r)
					exits.append(exit_pos)
				"^":
					var f := cell_floor(c, r)
					spikes.append(Vector2(f.x, f.y))
				_:
					if ch >= "a" and ch <= "d":
						plates.append({"x": c + 0.5, "x0": c + 0.5, "x1": c + 0.5, "y": float(ROWS - 1 - r), "ch": ch, "need": 1, "pressed": false})
					elif ch == "e" or ch == "f":
						var chan := "a" if ch == "e" else "b"
						var yy := float(ROWS - 1 - r)
						var merged := false
						for pl in plates:
							if pl.need == 2 and pl.ch == chan and pl.y == yy and absf(pl.x1 - (c - 0.5)) < 0.01:
								pl.x1 = c + 0.5
								pl.x = (pl.x0 + pl.x1) * 0.5
								merged = true
						if not merged:
							plates.append({"x": c + 0.5, "x0": c + 0.5, "x1": c + 0.5, "y": yy, "ch": chan, "need": 2, "pressed": false})
					elif ch >= "A" and ch <= "D":
						var key := "%s_%d" % [ch, c]
						if not door_cells.has(key):
							door_cells[key] = {"ch": ch.to_lower(), "c": c, "rows": []}
						door_cells[key].rows.append(r)
	for key in door_cells:
		var d: Dictionary = door_cells[key]
		var rows: Array = d.rows
		var bottom: float = ROWS - 1 - rows.max()
		doors.append({"ch": d.ch, "x": d.c + 0.5, "bottom": bottom, "h": float(rows.size())})
	for ch in ["a", "b", "c", "d"]:
		channels[ch] = false
	spawns.push_front(spawn)
	if spawns.size() < 2:
		spawns.append(spawn + Vector3(1.0, 0, 0))
	for pt in portals:
		pt.entrance = int(pt.n) % 2 == 1
		pt.target = null
		for other in portals:
			if int(other.n) == int(pt.n) + 1 and pt.entrance:
				pt.target = other


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky.sky_material = Props.shader_mat("res://shaders/sky.gdshader")
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.38, 0.6)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.glow_enabled = Game.high_quality()
	env.glow_intensity = 0.9
	env.glow_strength = 1.1
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 0.85
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.2, 0.08, 0.2)
	env.fog_density = 1.0
	env.fog_depth_begin = 17.0
	env.fog_depth_end = 75.0
	env.fog_depth_curve = 1.2
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.05
	if dark:
		env.ambient_light_color = Color(0.25, 0.2, 0.4)
		env.ambient_light_energy = 0.12
		env.fog_light_color = Color(0.02, 0.01, 0.04)
		env.fog_depth_begin = 13.0
		env.fog_depth_end = 40.0
		env.glow_intensity = 1.2
		(sky.sky_material as ShaderMaterial).set_shader_parameter("dim", 0.3)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -38, 0)
	sun.light_color = Color(1.0, 0.86, 0.74)
	sun.light_energy = 0.06 if dark else 1.25
	sun.shadow_enabled = not dark and Game.high_quality()
	sun.shadow_bias = 0.04
	sun.directional_shadow_max_distance = 45.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	add_child(sun)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-15, 150, 0)
	rim.light_color = Color(0.45, 0.6, 1.0)
	rim.light_energy = 0.1 if dark else 0.35
	add_child(rim)


func _build_terrain() -> void:
	var cells: Array[Transform3D] = []
	for key in solid:
		var v: Vector2i = key
		if v.y == 0:
			continue
		cells.append(_block_xf(v.x, ROWS - 1 - v.y))
	for c in cols:
		if is_solid(c, 1) or c == 0 or c == cols - 1:
			for extra in range(ROWS - 1, ROWS + 6):
				cells.append(_block_xf(c, extra))
	_add_blocks(cells, _rock_mat)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	for r in ROWS:
		var c := 0
		while c < cols:
			if is_solid(c, r):
				var start := c
				while c < cols and is_solid(c, r):
					c += 1
				var shape := CollisionShape3D.new()
				var box := BoxShape3D.new()
				box.size = Vector3(c - start, 1.0, 3.0)
				shape.shape = box
				shape.position = Vector3((start + c) * 0.5, ROWS - 1 - r + 0.5, 0.0)
				body.add_child(shape)
			else:
				c += 1
	for c in range(-1, cols + 1):
		if c == -1 or c == cols:
			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(1, 40, 3)
			shape.shape = box
			shape.position = Vector3(c + 0.5, 10, 0)
			body.add_child(shape)


func _block_xf(c: int, y: int) -> Transform3D:
	var depth := 3.0 + _rng.randf_range(0.0, 0.35)
	var xf := Transform3D(Basis.from_scale(Vector3(1.0, 1.0, depth)), Vector3(c + 0.5, y + 0.5, -1.5 + depth * 0.5))
	return xf


func _add_blocks(xfs: Array[Transform3D], mat: Material, shadows := true) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	box.material = mat
	mm.mesh = box
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


func _ground_height(c: int) -> int:
	var cc := clampi(c, 1, cols - 2)
	for r in range(1, ROWS):
		if is_solid(cc, r):
			return ROWS - r
	return 1


func _back_height(c: int) -> int:
	return maxi(1, _ground_height(c) + int(1.2 + 1.4 * sin(c * 0.31 + level_index) + 0.9 * sin(c * 0.11 + 2.0)))


func _build_background() -> void:
	var back_mat := Props.shader_mat("res://shaders/rock.gdshader", {"darken": 0.45})
	var xfs: Array[Transform3D] = []
	for c in range(-16, cols + 16):
		var h := _back_height(c) + (1 if _rng.randf() < 0.3 else 0)
		for y in range(0, maxi(h, 1)):
			var depth := 3.0 + _rng.randf_range(0.0, 1.0)
			xfs.append(Transform3D(Basis.from_scale(Vector3(1, 1, depth)), Vector3(c + 0.5, y + 0.5, -8.0 - depth * 0.5)))
	_add_blocks(xfs, back_mat, false)
	var far_mat := Props.shader_mat("res://shaders/rock.gdshader", {"darken": 0.7})
	var far: Array[Transform3D] = []
	for c in range(-30, cols + 30, 2):
		var h := 3 + int(3.0 + 2.5 * sin(c * 0.07 + level_index * 1.7) + 1.5 * sin(c * 0.19))
		for y in range(0, h):
			far.append(Transform3D(Basis.from_scale(Vector3(2, 1, 4)), Vector3(c + 1.0, y + 0.5, -26.0)))
	_add_blocks(far, far_mat, false)
	for i in 10:
		var p := Props.model("res://assets/models/space/%s.glb" % FAR_PROPS[i % FAR_PROPS.size()], _rng.randf_range(7.0, 14.0))
		p.position = Vector3(_rng.randf_range(-20, cols + 20), _rng.randf_range(-1.5, 2.0), _rng.randf_range(-60, -45))
		p.rotation.y = _rng.randf() * TAU
		Props.set_shadows(p, false)
		add_child(p)


func _build_decor() -> void:
	var reserved := {}
	reserved[int(spawn.x)] = true
	reserved[int(exit_pos.x)] = true
	for p in plates:
		reserved[int(p.x)] = true
	for r in range(1, ROWS):
		for c in range(1, cols - 1):
			if not is_solid(c, r) or is_solid(c, r - 1):
				continue
			var top := float(ROWS - r)
			if _rng.randf() < 0.42:
				var pick: Array = BACK_PROPS[_rng.randi() % BACK_PROPS.size()]
				var m := Props.model("res://assets/models/space/%s.glb" % pick[0], pick[1] * _rng.randf_range(0.8, 1.25))
				m.position = Vector3(c + 0.5 + _rng.randf_range(-0.3, 0.3), top, _rng.randf_range(-1.25, -0.7))
				m.rotation.y = _rng.randf() * TAU
				Props.set_shadows(m, true)
				add_child(m)
			if not reserved.has(c) and _rng.randf() < 0.3:
				var pick2: Array = FRONT_PROPS[_rng.randi() % FRONT_PROPS.size()]
				var f := Props.model("res://assets/models/space/%s.glb" % pick2[0], pick2[1])
				f.position = Vector3(c + 0.5 + _rng.randf_range(-0.3, 0.3), top, _rng.randf_range(0.9, 1.35))
				f.rotation.y = _rng.randf() * TAU
				add_child(f)
	for c in range(-12, cols + 12, 3):
		if _rng.randf() < 0.45:
			var pick3: Array = BACK_PROPS[_rng.randi() % BACK_PROPS.size()]
			var b := Props.model("res://assets/models/space/%s.glb" % pick3[0], pick3[1] * 2.2)
			var h := _back_height(c)
			b.position = Vector3(c + 0.5, float(h), -9.2)
			b.rotation.y = _rng.randf() * TAU
			Props.set_shadows(b, false)
			add_child(b)
	if data.get("wreck", false):
		var ship := Props.model("res://assets/models/space/craft_cargoA.glb", 3.2)
		ship.position = spawn + Vector3(-0.2, -0.35, -1.6)
		ship.rotation_degrees = Vector3(8, 70, -18)
		add_child(ship)
		var smoke := _particles(Color(0.35, 0.3, 0.35, 0.5), 40, 3.0, Vector3(0, 1.4, 0), 0.25, 0.6)
		smoke.position = spawn + Vector3(0.4, 0.6, -1.6)
		add_child(smoke)
		var fire := OmniLight3D.new()
		fire.light_color = Color(1.0, 0.5, 0.2)
		fire.light_energy = 1.5
		fire.omni_range = 4.0
		fire.position = spawn + Vector3(0.3, 0.8, -1.0)
		add_child(fire)
	if level_index == Levels.count() - 1:
		var rocket := Node3D.new()
		var parts := [["rocket_baseA", 1.8], ["rocket_fuelA", 1.0], ["rocket_fuelA", 1.0], ["rocket_topA", 1.0]]
		var y := 0.0
		for part in parts:
			var m := Props.model("res://assets/models/space/%s.glb" % part[0], part[1])
			m.position.y = y
			rocket.add_child(m)
			y += Props.aabb_of(m).size.y * 0.98
		rocket.scale = Vector3.ONE * 2.2
		rocket.position = Vector3(exit_pos.x + 3.0, exit_pos.y, -4.2)
		add_child(rocket)


func _particles(color: Color, amount: int, life: float, vel: Vector3, size: float, spread: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color.WHITE
	quad.material = mat
	p.mesh = quad
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = spread
	p.direction = vel.normalized() if vel.length() > 0.0 else Vector3.UP
	p.spread = 25.0
	p.initial_velocity_min = vel.length() * 0.6
	p.initial_velocity_max = vel.length()
	p.gravity = Vector3.ZERO
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	var grad := Gradient.new()
	grad.set_color(0, Color(color, 0.0))
	grad.add_point(0.2, color)
	grad.set_color(grad.get_point_count() - 1, Color(color, 0.0))
	p.color_ramp = grad
	return p


func _build_entities() -> void:
	for f in spikes:
		var s := Props.model("res://assets/models/kit/trap-spikes-large.glb", 0.98)
		s.position = Vector3(f.x, f.y, 0.0)
		s.scale = Vector3(1.0, 1.5, 2.6)
		add_child(s)
		var ap := Props.find_anim(s)
		if ap and ap.has_animation("show"):
			ap.play("show")
			ap.seek(ap.get_animation("show").length, true)
			ap.pause()
		if spikes.find(f) % 2 == 0:
			var glow := OmniLight3D.new()
			glow.light_color = Color(1.0, 0.25, 0.3)
			glow.light_energy = 1.2 if dark else 0.6
			glow.omni_range = 2.4
			glow.position = Vector3(f.x + 0.5, f.y + 0.5, 0.8)
			add_child(glow)
	_build_mechanics()
	for p in plates:
		var col: Color = Game.CHANNEL_COLORS[p.ch]
		p.anims = []
		var cx: float = p.x0
		while cx <= p.x1 + 0.01:
			var m := Props.model("res://assets/models/kit/button-square.glb", 0.9)
			m.position = Vector3(cx, p.y, 0.0)
			add_child(m)
			p.anims.append(Props.find_anim(m))
			cx += 1.0
		p.anim = p.anims[0]
		if p.need > 1:
			var tag := Label3D.new()
			tag.text = "x%d" % p.need
			tag.font = Game.font_title
			tag.font_size = 64
			tag.outline_size = 14
			tag.pixel_size = 0.006
			tag.modulate = col
			tag.position = Vector3(p.x, p.y + 1.4, -0.3)
			add_child(tag)
		var ring := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(1.6 + (p.x1 - p.x0), 1.6)
		ring.mesh = pm
		p.mat = Props.shader_mat("res://shaders/ring.gdshader", {"tint": col, "power": 0.6})
		ring.material_override = p.mat
		ring.position = Vector3(p.x, p.y + 0.03, 0.0)
		add_child(ring)
		var light := OmniLight3D.new()
		light.light_color = col
		light.light_energy = 0.3
		light.omni_range = 2.0
		light.position = Vector3(p.x, p.y + 0.4, 0.6)
		add_child(light)
		p.light = light
	for d in doors:
		var col: Color = Game.CHANNEL_COLORS[d.ch]
		var body := AnimatableBody3D.new()
		body.sync_to_physics = false
		body.collision_layer = 1
		body.collision_mask = 0
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.6, d.h, 2.0)
		shape.shape = box
		body.add_child(shape)
		var mesh := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.36, d.h, 1.6)
		mesh.mesh = bm
		d.mat = Props.shader_mat("res://shaders/barrier.gdshader", {"tint": col, "power": 1.0})
		mesh.material_override = d.mat
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		body.add_child(mesh)
		d.closed = Vector3(d.x, d.bottom + d.h * 0.5, 0.0)
		d.open = d.closed + Vector3(0, d.h + 0.05, 0)
		body.position = d.closed
		add_child(body)
		d.body = body
		var base := MeshInstance3D.new()
		var basem := BoxMesh.new()
		basem.size = Vector3(0.8, 0.14, 1.9)
		base.mesh = basem
		var bmat := StandardMaterial3D.new()
		bmat.albedo_color = Color(0.2, 0.2, 0.25)
		bmat.emission_enabled = true
		bmat.emission = col
		bmat.emission_energy_multiplier = 0.8
		base.material_override = bmat
		base.position = Vector3(d.x, d.bottom + 0.05, 0.0)
		add_child(base)
		var light := OmniLight3D.new()
		light.light_color = col
		light.light_energy = 0.9
		light.omni_range = 3.0
		light.position = Vector3(d.x, d.bottom + d.h * 0.5, 1.2)
		add_child(light)
		d.light = light
	for l in data.get("lifts", []):
		var c: int = l[0]
		var r: int = l[1]
		var body := AnimatableBody3D.new()
		body.sync_to_physics = true
		body.collision_layer = 1
		body.collision_mask = 0
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(2.0, 0.3, 2.0)
		shape.shape = box
		body.add_child(shape)
		var vis := Props.model("res://assets/models/kit/block-moving-large.glb", 1.0)
		vis.scale = Vector3(2.0, 0.6, 1.8)
		vis.position.y = -0.15
		Props.set_shadows(vis, true)
		body.add_child(vis)
		var ch: String = l[4]
		var col: Color = Game.CHANNEL_COLORS.get(ch, Color(0.8, 0.8, 1.0))
		var light := OmniLight3D.new()
		light.light_color = col
		light.light_energy = 0.7
		light.omni_range = 2.5
		light.position = Vector3(0, -0.4, 0.9)
		body.add_child(light)
		var a := Vector3(c + 1.0, ROWS - 1 - r + 0.15, 0.0)
		var b := a + Vector3(l[2], -l[3], 0)
		body.position = a
		add_child(body)
		lifts.append({"body": body, "a": a, "b": b, "ch": ch, "t": 0.0, "dir": 1.0, "wait": 0.0, "len": a.distance_to(b)})
	var beam_mat := Props.shader_mat("res://shaders/glow.gdshader", {"tint": Color(0.4, 1.0, 0.8), "power": 1.2})
	for ex in exits:
		var beacon := Props.model("res://assets/models/space/machine_wireless.glb", 1.3)
		beacon.position = ex
		add_child(beacon)
		var beam := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(1.4, 10.0)
		beam.mesh = q
		beam.material_override = beam_mat
		beam.position = ex + Vector3(0, 5.0, -0.2)
		add_child(beam)
		if _beam == null:
			_beam = beam
		var bl := OmniLight3D.new()
		bl.light_color = Color(0.45, 1.0, 0.8)
		bl.light_energy = 1.6
		bl.omni_range = 4.5
		bl.position = ex + Vector3(0, 1.2, 0.8)
		add_child(bl)
		var sparks := _particles(Color(0.5, 1.0, 0.85, 0.9), 28, 2.4, Vector3(0, 1.6, 0), 0.09, 0.5)
		sparks.position = ex + Vector3(0, 0.4, 0)
		add_child(sparks)


func _build_camera() -> void:
	camera = Camera3D.new()
	camera.fov = CAM_FOV
	camera.near = 0.3
	camera.far = 400.0
	camera.rotation_degrees = Vector3(-5, 0, 0)
	add_child(camera)
	camera.make_current()
	camera.position = Vector3(cols * 0.5, 6.2, CAM_DIST)


func _build_motes() -> void:
	var m := _particles(Color(1.0, 0.85, 0.75, 0.55), 90 if Game.high_quality() else 30, 7.0, Vector3(0.25, 0.15, 0), 0.05, 0.0)
	m.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(cols * 0.5 + 4, 6, 3)
	m.position = Vector3(cols * 0.5, 6, 0.5)
	m.preprocess = 7.0
	add_child(m)


func grip_at(x: float, y: float, dir: float) -> bool:
	var c := int(floor(x + dir * (Player.RADIUS + 0.12)))
	var r := ROWS - 1 - int(floor(y + 0.45))
	return grip.has(Vector2i(c, r))


func _in_wind(p: Vector3) -> bool:
	return wind.has(Vector2i(int(floor(p.x)), ROWS - 1 - int(floor(p.y + 0.45))))


func _build_mechanics() -> void:
	var grip_mat := Props.shader_mat("res://shaders/grip.gdshader")
	for key in grip:
		var v: Vector2i = key
		for side in [-1, 1]:
			if is_solid(v.x + side, v.y):
				continue
			var strip := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.14, 1.0, 3.7)
			strip.mesh = bm
			strip.material_override = grip_mat
			strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			strip.position = Vector3(v.x + (1.04 if side > 0 else -0.04), ROWS - 1 - v.y + 0.5, 0.1)
			add_child(strip)
	var acid_mat := Props.shader_mat("res://shaders/acid.gdshader")
	for i in acid.size():
		var a: Vector2 = acid[i]
		var pool := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(1.0, 0.6, 3.3)
		pool.mesh = bm
		pool.material_override = acid_mat
		pool.position = Vector3(a.x, a.y + 0.3, 0.0)
		add_child(pool)
		var l := OmniLight3D.new()
		l.light_color = Color(0.4, 1.0, 0.3)
		l.light_energy = 1.4 if dark else 0.9
		l.omni_range = 2.8
		l.position = Vector3(a.x, a.y + 0.8, 0.9)
		add_child(l)
		var bub := _particles(Color(0.5, 1.0, 0.4, 0.8), 10, 1.4, Vector3(0, 0.8, 0), 0.07, 0.35)
		bub.position = Vector3(a.x, a.y + 0.55, 0.3)
		add_child(bub)
	var cols_done := {}
	for key in wind:
		var v: Vector2i = key
		if cols_done.has(v) or wind.has(Vector2i(v.x, v.y - 1)):
			continue
		var r1 := v.y
		while wind.has(Vector2i(v.x, r1 + 1)):
			r1 += 1
		for rr in range(v.y, r1 + 1):
			cols_done[Vector2i(v.x, rr)] = true
		var h := float(r1 - v.y + 1)
		var bottom := float(ROWS - 1 - r1)
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(1.0, h + 1.2)
		q.mesh = qm
		q.material_override = Props.shader_mat("res://shaders/wind.gdshader", {"height": h + 1.2, "power": 1.6 if dark else 1.0})
		q.position = Vector3(v.x + 0.5, bottom + (h + 1.2) * 0.5, -0.3)
		add_child(q)
		var vent := MeshInstance3D.new()
		var vm := BoxMesh.new()
		vm.size = Vector3(0.96, 0.12, 2.4)
		vent.mesh = vm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.18, 0.2, 0.26)
		mat.emission_enabled = true
		mat.emission = Color(0.55, 0.8, 1.0)
		mat.emission_energy_multiplier = 0.7
		vent.material_override = mat
		vent.position = Vector3(v.x + 0.5, bottom + 0.06, 0.0)
		add_child(vent)
		var puffs := _particles(Color(0.75, 0.9, 1.0, 0.45), 18, 1.6, Vector3(0, 4.5, 0), 0.06, 0.0)
		puffs.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		puffs.emission_box_extents = Vector3(0.45, 0.1, 0.8)
		puffs.position = Vector3(v.x + 0.5, bottom + 0.2, 0.2)
		add_child(puffs)
	for pt in portals:
		var col := Color(1.0, 0.55, 0.25) if pt.entrance else Color(0.55, 0.5, 1.0)
		if int(pt.n) > 2:
			col = Color(0.35, 1.0, 0.7) if pt.entrance else Color(0.3, 0.8, 1.0)
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(1.3, 1.6)
		q.mesh = qm
		q.material_override = Props.shader_mat("res://shaders/portal.gdshader", {"tint": col, "spin": 1.0 if pt.entrance else -1.0, "power": 1.3})
		q.position = pt.pos + Vector3(0, 0.8, -0.15)
		add_child(q)
		var ring := Props.model("res://assets/models/space/gate_simple.glb", 1.5)
		ring.position = pt.pos + Vector3(0, 0, -0.35)
		add_child(ring)
		var l := OmniLight3D.new()
		l.light_color = col
		l.light_energy = 1.3
		l.omni_range = 3.0
		l.position = pt.pos + Vector3(0, 0.9, 0.8)
		add_child(l)


func _fx(kind: String, a: Variant = null, b: Variant = null, c: Variant = null) -> void:
	_play_fx(kind, a, b, c)
	if net_role == "host":
		Net.send_fx(kind, a, b, c)


func _play_fx(kind: String, a: Variant = null, b: Variant = null, c: Variant = null) -> void:
	match kind:
		"sfx":
			Sfx.play(str(a), 0.0 if b == null else float(b), 1.0 if c == null else float(c))
		"flash":
			if hud:
				hud.flash(a)
		"toast":
			if hud:
				hud.toast(str(a))
		"shake":
			_shake = maxf(_shake, float(a))
		"squish":
			var i := int(a)
			if i >= 0 and i < echoes.size():
				echoes[i].squish()
		"echo_pop":
			if net_role == "client" and echoes.size() > 0:
				var old: Echo = echoes.pop_front()
				old.queue_free()
		"clear_echoes":
			if net_role == "client":
				for e in echoes:
					e.queue_free()
				echoes.clear()
		"win":
			if net_role == "client":
				finished = true
				for p in players:
					p._play("emote-yes")
				Sfx.play("win", -2.0, 1.0, 0.0)
				hud.show_win(int(a), int(b))


func _check_portals(i: int) -> void:
	if _portal_cds[i] > 0:
		_portal_cds[i] -= 1
		return
	var p := players[i]
	var pos := p.position
	for pt in portals:
		if not pt.entrance or pt.target == null:
			continue
		var pp: Vector3 = pt.pos
		if absf(pos.x - pp.x) < 0.42 and pos.y > pp.y - 0.3 and pos.y < pp.y + 1.1:
			var out: Vector3 = (pt.target as Dictionary).pos
			p.position = Vector3(out.x, out.y + 0.02, 0.0)
			_portal_cds[i] = 12
			_fx("sfx", "echo", -8.0, 1.6)
			_fx("flash", Color(0.7, 0.5, 1.0, 0.25))
			return


func _check_slime(i: int) -> void:
	var p := players[i]
	if not p.is_on_floor() or p.dead:
		return
	for k in echoes.size():
		var e := echoes[k]
		if e.slime and e.solid and absf(p.position.x - e.feet.x) < 0.7 and absf(p.position.y - e.top) < 0.15:
			p.bounce()
			_fx("squish", k)
			_fx("sfx", "land", -4.0, 1.6)
			_fx("sfx", "jump", -6.0, 0.7)
			return


func _build_players() -> void:
	var count := 2 if coop else 1
	for i in count:
		var p := Player.new()
		p.index = i
		p.coop = coop
		p.level = self
		if i == 1:
			p.model_path = "res://assets/models/kit/character-oodi.glb"
		add_child(p)
		if i == 1:
			p.lamp.light_color = Color(1.0, 0.75, 0.5)
		if dark:
			p.lamp.light_energy = 2.4
			p.lamp.omni_range = 6.5
		p.landed.connect(_on_landed.bind(p))
		p.jumped.connect(_on_jumped.bind(p))
		players.append(p)
		recs.append({"f": [], "a": []})
		done.append(false)
		died_f.append(false)
		causes.append("")
		death_timers.append(-1.0)
		_portal_cds.append(0)
	player = players[0]
	if net_role == "host":
		players[1].input_mode = "remote"
	elif net_role == "client":
		for p in players:
			p.puppet = true
			p.input_mode = "none"
	_spawn_fx = _particles(Color(0.4, 0.95, 1.0, 0.9), 30, 0.7, Vector3(0, 2.5, 0), 0.08, 0.4)
	_spawn_fx.one_shot = true
	_spawn_fx.emitting = false
	_spawn_fx.explosiveness = 0.9
	add_child(_spawn_fx)


func _touch_text(t: String) -> String:
	var out := t.replace("A / D  to move\nSPACE  to jump", "Arrow buttons to move\nbig button to jump")
	out = out.replace("press  Q", "tap the echo button").replace("press Q", "tap the echo button")
	return out.replace("press SPACE to wall-jump", "tap jump to wall-jump")


func _build_hints() -> void:
	for h in data.get("hints", []):
		var l := Label3D.new()
		l.text = _touch_text(h[2]) if Game.touch_enabled() else h[2]
		l.font = Game.font_body
		l.font_size = 44
		l.outline_size = 12
		l.pixel_size = 0.0055
		l.modulate = Color(0.85, 0.88, 1.0, 0.0)
		l.outline_modulate = Color(0.05, 0.03, 0.1, 0.0)
		l.line_spacing = -6
		l.position = Vector3(h[0] + 0.5, ROWS - 1 - h[1] + 0.5, -0.4)
		add_child(l)
		_hints.append(l)


func _set_player_active(p: Player, on: bool) -> void:
	p.visible = on
	p.collision_layer = 2 if on else 0
	p.set_physics_process(on)


func _reset_world() -> void:
	tick = 0
	death_cause = ""
	for i in players.size():
		recs[i] = {"f": [], "a": []}
		done[i] = false
		died_f[i] = false
		causes[i] = ""
		death_timers[i] = -1.0
		_portal_cds[i] = 0
		var p := players[i]
		p.reset_to(spawns[i])
		_set_player_active(p, true)
		if net_role == "client":
			p.set_physics_process(false)
	for e in echoes:
		e.restart()
	for d in doors:
		d.body.position = d.closed
	for l in lifts:
		l.t = 0.0
		l.dir = 1.0
		l.wait = 0.0
		l.body.position = l.a
	for p in plates:
		p.pressed = false
	_spawn_fx.position = spawn + Vector3(0, 0.3, 0)
	_spawn_fx.restart()
	_spawn_fx.emitting = true
	if hud:
		hud.refresh()


func full_restart() -> void:
	for e in echoes:
		e.queue_free()
	echoes.clear()
	lives_used = 0
	finished = false
	_reset_world()
	_ended = true
	if net_role == "host":
		Net.send_fx("clear_echoes")
	_fx("sfx", "rewind", -4.0)
	_fx("toast", "Timeline cleared")


func _all_done() -> bool:
	for d in done:
		if not d:
			return false
	return true


func _echo_color(i: int) -> Color:
	var pal: Array = Game.ECHO_COLORS_P2 if i == 1 else Game.ECHO_COLORS
	return pal[(lives_used - 1) % pal.size()]


func _finish_player(i: int, died: bool) -> void:
	if done[i]:
		return
	done[i] = true
	died_f[i] = died
	var p := players[i]
	if not died:
		_fx("sfx", "lock", -6.0, 1.2)
	if not _all_done():
		_set_player_active(p, false)
		p.controllable = false
		_fx("toast", "Player %d will wait for the next life" % (i + 1))
		return
	_end_timeline()


func _end_life(died: bool) -> void:
	_finish_player(0, died)


func _end_timeline() -> void:
	lives_used += 1
	var any_died := false
	var cause := ""
	for i in players.size():
		var rf := _packed_frames(i)
		var ra := _packed_anims(i)
		history.append({"f": rf, "a": ra, "died": died_f[i], "cause": causes[i], "player": i})
		if died_f[i]:
			any_died = true
			cause = causes[i]
		if rf.size() > 2:
			if echoes.size() >= max_echoes:
				var old: Echo = echoes.pop_front()
				old.queue_free()
				if net_role == "host":
					Net.send_fx("echo_pop")
			var col := _echo_color(i)
			var why := causes[i] if died_f[i] else ""
			_add_echo(rf, ra, died_f[i], col, why, players[i].model_path)
			if net_role == "host":
				Net.send_echo(rf, ra, died_f[i], col, why, players[i].model_path)
	_reset_world()
	_ended = true
	_fx("sfx", "echo", -3.0)
	_fx("sfx", "rewind", -10.0, 1.3)
	_fx("flash", Color(1.0, 0.3, 0.4, 0.35) if any_died and not coop else Color(0.4, 0.95, 1.0, 0.35))
	if coop:
		_fx("toast", "Life %d. Your echoes remember." % (lives_used + 1))
	elif not any_died:
		_fx("toast", "Echo %d recorded" % lives_used)
	elif cause == "acid":
		_fx("toast", "Dissolved. Something bouncy remains.")
	else:
		_fx("toast", "You fell. Your body remains.")


func _packed_frames(i: int) -> PackedVector3Array:
	return PackedVector3Array(recs[i].f as Array)


func _packed_anims(i: int) -> PackedByteArray:
	return PackedByteArray(recs[i].a as Array)


func _add_echo(f: PackedVector3Array, a: PackedByteArray, died: bool, col: Color, cause: String, model: String) -> void:
	var e := Echo.new()
	e.model_path = model
	e.setup(f, a, died, col, cause)
	e.dark = dark
	_echo_root.add_child(e)
	echoes.append(e)
	e.locked.connect(_on_echo_locked)


func add_remote_echo(f: PackedVector3Array, a: PackedByteArray, died: bool, col: Color, cause: String, model: String) -> void:
	_add_echo(f, a, died, col, cause, model)
	if hud:
		hud.refresh()


func _active(i: int) -> bool:
	return not done[i] and death_timers[i] < 0.0


func _physics_process(delta: float) -> void:
	if menu_mode:
		_update_lifts(delta)
		return
	if net_role == "client":
		return
	if finished:
		_update_doors(delta)
		_update_lifts(delta)
		_send_snapshot()
		return
	_ended = false
	for p in players:
		if p.reset_just():
			full_restart()
			_send_snapshot()
			return
	for i in players.size():
		if done[i]:
			continue
		var p := players[i]
		if death_timers[i] >= 0.0:
			death_timers[i] -= delta
			if death_timers[i] < 0.0:
				_finish_player(i, true)
				if _ended:
					_send_snapshot()
					return
			continue
		if p.echo_just() and tick > 8 and (p.is_on_floor() or p.clinging):
			_finish_player(i, false)
			if _ended:
				_send_snapshot()
				return
			continue
		(recs[i].f as Array).append(Vector3(p.position.x, p.position.y, p.facing))
		(recs[i].a as Array).append(p.anim_index())
	for e in echoes:
		e.apply_tick(tick, players)
	for i in players.size():
		players[i].in_wind = _active(i) and _in_wind(players[i].position)
		if _active(i):
			_check_slime(i)
	_update_channels()
	_update_doors(delta)
	_update_lifts(delta)
	for i in players.size():
		if _active(i):
			_check_player(i)
	for i in players.size():
		if _active(i) and not finished:
			_check_portals(i)
	if not finished:
		_check_win()
	tick += 1
	_send_snapshot()


func _send_snapshot() -> void:
	if net_role != "host":
		return
	var s := [tick, lives_used, finished]
	for i in players.size():
		var p := players[i]
		var st := 2 if done[i] else (1 if p.dead else 0)
		s.append_array([snappedf(p.position.x, 0.001), snappedf(p.position.y, 0.001), p.facing, p.anim_index(), st])
	for d in doors:
		s.append(snappedf((d.body as Node3D).position.y, 0.001))
	for l in lifts:
		var lp: Vector3 = (l.body as Node3D).position
		s.append_array([snappedf(lp.x, 0.001), snappedf(lp.y, 0.001)])
	var bits := 0
	for k in plates.size():
		if plates[k].pressed:
			bits |= 1 << k
	s.append(bits)
	Net.send_snapshot(s)


func apply_snapshot(s: Array) -> void:
	var t := int(s[0])
	if t < tick:
		for e in echoes:
			e.restart()
	tick = t
	var lives := int(s[1])
	if lives != lives_used:
		lives_used = lives
		if hud:
			hud.refresh()
	var k := 3
	for i in players.size():
		var p := players[i]
		var pos := Vector3(float(s[k]), float(s[k + 1]), 0.0)
		var fac := float(s[k + 2])
		var an := int(s[k + 3])
		var st := int(s[k + 4])
		k += 5
		done[i] = st == 2
		p.visible = st != 2
		if st == 1:
			if not p.dead:
				p.dead = true
				p._play("die")
			p.position = pos
		else:
			p.dead = false
			p.puppet_to(pos, fac, Props.ANIMS[clampi(an, 0, Props.ANIMS.size() - 1)])
	for d in doors:
		(d.body as Node3D).position.y = float(s[k])
		k += 1
		_door_visual(d)
	for l in lifts:
		(l.body as Node3D).position = Vector3(float(s[k]), float(s[k + 1]), 0.0)
		k += 2
	var bits := int(s[k])
	for idx in plates.size():
		var on := (bits & (1 << idx)) != 0
		if on != plates[idx].pressed:
			plates[idx].pressed = on
			_plate_visual(plates[idx], true)
	for e in echoes:
		e.apply_tick(tick, null)


func _weight_count(pl: Dictionary) -> int:
	var x0: float = pl.x0
	var x1: float = pl.x1
	var y: float = pl.y
	var n := 0
	for i in players.size():
		if done[i]:
			continue
		var p := players[i].position
		if p.x > x0 - 0.5 and p.x < x1 + 0.5 and p.y > y - 0.3 and p.y < y + 0.6:
			n += 1
	for e in echoes:
		if e.feet.x > x0 - 0.5 and e.feet.x < x1 + 0.5 and e.feet.y > y - 0.3 and e.feet.y < y + 0.6:
			n += 1
	return n


func _plate_visual(p: Dictionary, changed: bool) -> void:
	var on: bool = p.pressed
	if changed:
		Sfx.play("plate_on" if on else "plate_off", -6.0)
		var n := "toggle-on" if on else "toggle-off"
		for ap in p.anims:
			if ap and (ap as AnimationPlayer).has_animation(n):
				(ap as AnimationPlayer).play(n)
	p.mat.set_shader_parameter("power", 2.2 if on else 0.6)
	p.light.light_energy = 1.2 if on else 0.3


func _update_channels() -> void:
	for ch in channels:
		channels[ch] = false
	for p in plates:
		var on := _weight_count(p) >= int(p.need)
		var changed: bool = on != p.pressed
		p.pressed = on
		_plate_visual(p, changed)
		if on:
			channels[p.ch] = true


func _door_visual(d: Dictionary) -> void:
	var body: AnimatableBody3D = d.body
	var k: float = 1.0 - (body.position.y - d.closed.y) / maxf(0.01, d.h)
	d.mat.set_shader_parameter("power", 0.4 + 0.8 * k)
	d.light.light_energy = 0.2 + 0.8 * k


func _update_doors(delta: float) -> void:
	for d in doors:
		var open: bool = channels.get(d.ch, false)
		var body: AnimatableBody3D = d.body
		if not open and _anyone_in_doorway(d):
			open = body.position.y > d.closed.y + 0.05
		if open != d.get("was_open", false):
			d.was_open = open
			if not menu_mode and tick > 1:
				Sfx.play("door_open" if open else "door_close", -8.0)
		var target: Vector3 = d.open if open else d.closed
		body.position = body.position.move_toward(target, DOOR_SPEED * delta)
		_door_visual(d)


func _anyone_in_doorway(d: Dictionary) -> bool:
	for i in players.size():
		if done[i]:
			continue
		var px := players[i].position.x
		var py := players[i].position.y
		if absf(px - d.x) < 0.3 + Player.RADIUS and py < d.bottom + d.h and py + Player.HEIGHT > d.bottom:
			return true
	return false


func _update_lifts(delta: float) -> void:
	for l in lifts:
		var active: bool = l.ch == "" or channels.get(l.ch, false)
		var step: float = LIFT_SPEED * delta / maxf(0.01, l.len)
		if active:
			if l.wait > 0.0:
				l.wait -= delta
			else:
				l.t += l.dir * step
				if l.t >= 1.0:
					l.t = 1.0
					l.dir = -1.0
					l.wait = LIFT_PAUSE
				elif l.t <= 0.0:
					l.t = 0.0
					l.dir = 1.0
					l.wait = LIFT_PAUSE
		else:
			l.t = move_toward(l.t, 0.0, step)
			l.dir = 1.0
			l.wait = 0.0
		var t: float = l.t
		var eased := t * t * (3.0 - 2.0 * t)
		(l.body as AnimatableBody3D).position = (l.a as Vector3).lerp(l.b, eased)


func _check_player(i: int) -> void:
	var p := players[i].position
	if p.y < -2.0:
		_kill_player(i, "fall")
		return
	for s in spikes:
		if absf(p.x - s.x) < 0.5 + 0.1 and p.y < s.y + SPIKE_KILL and p.y > s.y - 0.6:
			_kill_player(i, "spikes")
			return
	for a in acid:
		if absf(p.x - a.x) < 0.5 and p.y < a.y + 0.45 and p.y > a.y - 0.6:
			_kill_player(i, "acid")
			return


func _at_exit(p: Vector3) -> bool:
	for ex in exits:
		if absf(p.x - ex.x) < 0.6 and p.y > ex.y - 0.3 and p.y < ex.y + 1.6:
			return true
	return false


func _exit_index(p: Vector3) -> int:
	for k in exits.size():
		var ex := exits[k]
		if absf(p.x - ex.x) < 0.6 and p.y > ex.y - 0.3 and p.y < ex.y + 1.6:
			return k
	return -1


func _check_win() -> void:
	var used := {}
	for i in players.size():
		if not _active(i):
			return
		var k := _exit_index(players[i].position)
		if k < 0 or (used.has(k) and exits.size() > 1):
			return
		used[k] = true
	_win()


func _kill_player(i: int, cause: String) -> void:
	causes[i] = cause
	death_cause = cause
	players[i].die()
	death_timers[i] = DEATH_DELAY
	_fx("sfx", "death", -2.0)
	_fx("sfx", "thud", -8.0)
	_fx("shake", 0.35)
	_fx("flash", Color(1.0, 0.25, 0.3, 0.3))


func _kill(cause := "spikes", p: Player = null) -> void:
	var i := 0 if p == null else players.find(p)
	_kill_player(maxi(i, 0), cause)


func _win() -> void:
	for i in players.size():
		history.append({"f": _packed_frames(i), "a": _packed_anims(i), "died": false, "cause": "", "win": true, "player": i})
	finished = true
	for p in players:
		p.controllable = false
		p._play("emote-yes")
	var lives := lives_used + 1
	var stars := Game.complete_coop(level_index, lives) if coop else Game.complete_level(level_index, lives)
	Sfx.play("win", -2.0, 1.0, 0.0)
	hud.show_win(stars, lives)
	if net_role == "host":
		Net.send_fx("win", stars, lives)


func _on_landed(impact: float, _p: Player) -> void:
	if impact > 3.0:
		_fx("sfx", "land", lerpf(-16.0, -6.0, clampf(impact / 12.0, 0.0, 1.0)))
	if impact > 7.0:
		_fx("shake", 0.12)


func _on_jumped(_p: Player) -> void:
	_fx("sfx", "jump", -8.0, 1.2)


func _on_echo_locked(e: Echo) -> void:
	if tick < 2 or e.died:
		return
	Sfx.play("lock", -6.0, 0.9 + 0.1 * echoes.find(e))
	var ring := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.6, 1.6)
	ring.mesh = q
	var mat := Props.shader_mat("res://shaders/ring.gdshader", {"tint": e.tint, "power": 2.0})
	ring.material_override = mat
	ring.position = e.feet + Vector3(0, 0.5, 0.3)
	add_child(ring)
	var t := ring.create_tween().set_parallel()
	t.tween_property(ring, "scale", Vector3.ONE * 2.2, 0.5).set_ease(Tween.EASE_OUT)
	t.tween_method(func(v: float) -> void: mat.set_shader_parameter("power", v), 2.0, 0.0, 0.5)
	t.chain().tween_callback(ring.queue_free)


func status_text() -> String:
	if not coop:
		return ""
	var parts: Array[String] = []
	for i in players.size():
		var st := "waiting" if done[i] else ("down" if players[i].dead else "go")
		parts.append("P%d %s" % [i + 1, st])
	return "   ".join(parts)


func _process(delta: float) -> void:
	if menu_mode:
		_menu_time += delta
		var span := maxf(0.0, cols - 18.0)
		camera.position = Vector3(9.0 + span * (0.5 - 0.5 * cos(_menu_time * 0.07)), 6.4, CAM_DIST + 1.5)
		return
	_update_camera(delta)
	if net_role != "client":
		_footsteps(delta)
	for l in _hints:
		var dmin := 99.0
		for p in players:
			if p.visible:
				dmin = minf(dmin, Vector2(l.position.x - p.position.x, l.position.y - p.position.y - 1.0).length())
		var a := 1.0 - smoothstep(4.5, 8.0, dmin)
		l.modulate.a = lerpf(l.modulate.a, a, minf(1.0, delta * 5.0))
		l.outline_modulate.a = l.modulate.a * 0.9
	if _beam:
		_beam.material_override.set_shader_parameter("power", 1.0 + 0.25 * sin(Time.get_ticks_msec() * 0.003))
	if coop and hud:
		var st := status_text()
		if st != _last_status:
			_last_status = st
			hud.set_status(st)


var _step_t := 0.0
var _step_i := 0


func _footsteps(delta: float) -> void:
	var p := players[0]
	if p.dead or not p.visible or not p.is_on_floor() or absf(p.velocity.x) < 1.0:
		_step_t = 0.12
		return
	_step_t -= delta
	if _step_t <= 0.0:
		_step_t = 0.27
		_step_i += 1
		Sfx.play("step1" if _step_i % 2 == 0 else "step2", -20.0, 1.1)


func _view_players() -> Array[Player]:
	var out: Array[Player] = []
	for p in players:
		if p.visible:
			out.append(p)
	if out.is_empty():
		out.append(players[0])
	return out


func _camera_target() -> Vector3:
	var vis := _view_players()
	var minx := 1e9
	var maxx := -1e9
	var ysum := 0.0
	for p in vis:
		minx = minf(minx, p.position.x)
		maxx = maxf(maxx, p.position.x)
		ysum += p.position.y
	var spread := maxx - minx
	var dist := CAM_DIST + clampf(spread - 7.0, 0.0, 9.0) * 0.75
	var half_h := dist * tan(deg_to_rad(CAM_FOV * 0.5))
	var vp := get_viewport().get_visible_rect().size
	var half_w := half_h * vp.x / maxf(1.0, vp.y)
	var x := (minx + maxx) * 0.5
	if vis.size() == 1:
		x += vis[0].facing * 1.2
	var lo := half_w - 0.6
	var hi := cols - half_w + 0.6
	x = cols * 0.5 if lo > hi else clampf(x, lo, hi)
	var y := clampf(ysum / vis.size() + 2.4 + (dist - CAM_DIST) * 0.15, 5.0, 8.0)
	return Vector3(x, y, dist)


func _snap_camera() -> void:
	camera.position = _camera_target()


func _update_camera(delta: float) -> void:
	var t := _camera_target()
	camera.position = camera.position.lerp(t, minf(1.0, delta * 3.5))
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta)
		if Game.settings.shake:
			camera.position += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake * 0.5


func _exit_tree() -> void:
	if Net.level == self:
		Net.level = null
