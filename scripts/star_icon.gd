class_name StarIcon
extends Control

var lit := true:
	set(v):
		lit = v
		queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI * 0.5 + i * PI / 5.0
		var rr := r if i % 2 == 0 else r * 0.45
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	if lit:
		draw_colored_polygon(pts, Color(1.0, 0.8, 0.35))
		var inner := PackedVector2Array()
		for p in pts:
			inner.append(c + (p - c) * 0.55 + Vector2(0, -r * 0.06))
		draw_colored_polygon(inner, Color(1.0, 0.93, 0.65))
	else:
		draw_colored_polygon(pts, Color(1, 1, 1, 0.08))
	pts.append(pts[0])
	draw_polyline(pts, Color(1.0, 0.85, 0.5, 0.9) if lit else Color(0.6, 0.7, 0.9, 0.4), 2.0, true)
