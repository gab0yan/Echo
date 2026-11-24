extends Node


func _ready() -> void:
	Game.save_enabled = false
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var which := OS.get_environment("ECHO_PERF").split(",")
	for w in which:
		var node: Node
		if w == "menu":
			node = load("res://scenes/main_menu.tscn").instantiate()
		else:
			Game.coop = w.begins_with("c")
			Game.current_level = int(w.trim_prefix("c")) - 1
			node = load("res://scenes/level.tscn").instantiate()
		add_child(node)
		await get_tree().process_frame
		_strip(node, OS.get_environment("ECHO_OFF"))
		for i in 120:
			await get_tree().process_frame
		var vrid := get_viewport().get_viewport_rid()
		RenderingServer.viewport_set_measure_render_time(vrid, true)
		var gpu := 0.0
		var rcpu := 0.0
		var proc := 0.0
		var phys := 0.0
		var draws := 0.0
		var objects := 0.0
		var prims := 0.0
		var t0 := Time.get_ticks_usec()
		var n := 240
		for i in n:
			await get_tree().process_frame
			draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
			gpu += RenderingServer.viewport_get_measured_render_time_gpu(vrid)
			rcpu += RenderingServer.viewport_get_measured_render_time_cpu(vrid) + RenderingServer.get_frame_setup_time_cpu()
			proc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
			phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
			objects += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
			prims += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		var ms := (Time.get_ticks_usec() - t0) / 1000.0 / n
		var lights := 0
		for l in node.find_children("*", "OmniLight3D", true, false):
			lights += 1
		var meshes := node.find_children("*", "MeshInstance3D", true, false).size()
		var kinds := {}
		for v in node.find_children("*", "VisualInstance3D", true, false):
			var k := v.get_class()
			if v is MultiMeshInstance3D:
				k += "(%d)" % (v as MultiMeshInstance3D).multimesh.instance_count if false else ""
			kinds[k] = kinds.get(k, 0) + 1
		print("[perf] %-5s visuals %s" % [w, kinds])
		print("[perf] %-5s gpu %.2f  render-cpu %.2f  scripts %.2f  physics %.2f ms" % [w, gpu / n, rcpu / n, proc / n, phys / n])
		print("[perf] %-5s frame %.2f ms (%4.0f fps)  draw calls %5.0f  objects %5.0f  primitives %7.0f  omni lights %3d  mesh nodes %4d" % [w, ms, 1000.0 / ms, draws / n, objects / n, prims / n, lights, meshes])
		node.queue_free()
		await get_tree().process_frame
	get_tree().quit()


func _strip(node: Node, off: String) -> void:
	if off == "":
		return
	var we: WorldEnvironment = node.find_children("*", "WorldEnvironment", true, false)[0]
	if off.contains("sky"):
		we.environment.background_mode = Environment.BG_COLOR
		we.environment.background_color = Color(0.1, 0.05, 0.15)
	if off.contains("glow"):
		we.environment.glow_enabled = false
	if off.contains("fog"):
		we.environment.fog_enabled = false
	if off.contains("msaa"):
		get_viewport().msaa_3d = Viewport.MSAA_DISABLED
	if off.contains("fxaa"):
		get_viewport().screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	if off.contains("scale75"):
		get_viewport().scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		get_viewport().scaling_3d_scale = 0.75
	if off.contains("scale60"):
		get_viewport().scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		get_viewport().scaling_3d_scale = 0.6
	for l in node.find_children("*", "DirectionalLight3D", true, false):
		if off.contains("shadow"):
			(l as DirectionalLight3D).shadow_enabled = false
	if off.contains("lights"):
		for l in node.find_children("*", "OmniLight3D", true, false):
			l.visible = false
	if off.contains("rock"):
		var plain := StandardMaterial3D.new()
		plain.albedo_color = Color(0.6, 0.35, 0.28)
		for mm in node.find_children("*", "MultiMeshInstance3D", true, false):
			(mm as MultiMeshInstance3D).material_override = plain
	if off.contains("props"):
		for m in node.get_children():
			if m is Node3D and m.get_child_count() == 1 and m.get_child(0) is Node3D and not m is Player:
				pass
