class_name CircuitLogo
extends Control

var pulse_timer: float = 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(220, 180)
	size = Vector2(220, 180)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)

func _process(delta: float) -> void:
	pulse_timer += delta * 3.5
	queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	var w := size.x
	var h := size.y
	
	# Current active theme electric color
	var cyan_col := Color(0.0, 0.90, 1.0, 1.0)
	var yellow_col := Color(1.0, 0.85, 0.20, 1.0)
	
	# Background glowing high-tech backplate
	var plate_rect := Rect2(Vector2(10, 10), size - Vector2(20, 20))
	draw_rect(plate_rect, Color(0.03, 0.07, 0.14, 0.85), true)
	draw_rect(plate_rect, Color(0.12, 0.28, 0.48, 0.70), false, 2.0)
	
	# Circuit PCB tracks layout
	# Top track: from Battery (left) across to Bulb (right)
	var bat_pos := Vector2(center.x - 65, center.y)
	var bulb_pos := Vector2(center.x + 65, center.y)
	
	# Polyline track loops
	# Top rail wire: bat_pos.y - 45
	var p_top_start := Vector2(bat_pos.x, bat_pos.y - 35)
	var p_top_corner1 := Vector2(bat_pos.x, center.y - 52)
	var p_top_corner2 := Vector2(bulb_pos.x, center.y - 52)
	var p_top_end := Vector2(bulb_pos.x, bulb_pos.y - 35)
	
	# Bottom rail wire: bat_pos.y + 45
	var p_bot_start := Vector2(bat_pos.x, bat_pos.y + 35)
	var p_bot_corner1 := Vector2(bat_pos.x, center.y + 52)
	var p_bot_corner2 := Vector2(bulb_pos.x, center.y + 52)
	var p_bot_end := Vector2(bulb_pos.x, bulb_pos.y + 35)
	
	var top_track := PackedVector2Array([p_top_start, p_top_corner1, p_top_corner2, p_top_end])
	var bot_track := PackedVector2Array([p_bot_end, p_bot_corner2, p_bot_corner1, p_bot_start])
	
	# Draw unpowered track grooves
	var track_dark := Color(0.06, 0.12, 0.20, 1.0)
	draw_polyline(top_track, track_dark, 8.0)
	draw_polyline(bot_track, track_dark, 8.0)
	
	# Electric animated glow along tracks
	var pulse := (sin(pulse_timer * 2.0) + 1.0) * 0.5
	var neon_glow := Color(cyan_col.r, cyan_col.g, cyan_col.b, 0.35 + 0.20 * pulse)
	draw_polyline(top_track, neon_glow, 12.0)
	draw_polyline(bot_track, neon_glow, 12.0)
	
	# High voltage inner core stream
	draw_polyline(top_track, cyan_col, 4.0)
	draw_polyline(bot_track, cyan_col, 4.0)
	draw_polyline(top_track, Color.WHITE, 1.5)
	draw_polyline(bot_track, Color.WHITE, 1.5)
	
	# Flowing current sparks traveling around the loop!
	_draw_spark_along_track(top_track, fposmod(pulse_timer * 0.45, 1.0), cyan_col)
	_draw_spark_along_track(top_track, fposmod(pulse_timer * 0.45 + 0.5, 1.0), cyan_col)
	_draw_spark_along_track(bot_track, fposmod(pulse_timer * 0.45, 1.0), cyan_col)
	_draw_spark_along_track(bot_track, fposmod(pulse_timer * 0.45 + 0.5, 1.0), cyan_col)
	
	# -------------------------------------------------------------
	# 1. DRAW POWER SOURCE (BATTERY MODULE) AT LEFT
	# -------------------------------------------------------------
	var bat_w := 38.0
	var bat_h := 58.0
	var bat_rect := Rect2(bat_pos.x - bat_w * 0.5, bat_pos.y - bat_h * 0.5, bat_w, bat_h)
	# Battery drop shadow & outer casing
	draw_rect(bat_rect.grow(1.5), Color(0.02, 0.04, 0.08, 0.8), true)
	draw_rect(bat_rect, Color(0.14, 0.18, 0.26, 1.0), true)
	draw_rect(bat_rect, Color(0.25, 0.35, 0.52, 1.0), false, 2.0)
	
	# Terminal studs
	draw_rect(Rect2(bat_pos.x - 7, bat_pos.y - bat_h * 0.5 - 6, 14, 6), Color(0.85, 0.70, 0.30, 1.0), true)
	draw_rect(Rect2(bat_pos.x - 7, bat_pos.y + bat_h * 0.5, 14, 6), Color(0.40, 0.48, 0.60, 1.0), true)
	
	# Battery energy level neon bars inside
	for i in range(3):
		var bar_y := bat_pos.y - 15.0 + float(i) * 12.0
		var bar_rect := Rect2(bat_pos.x - bat_w * 0.36, bar_y, bat_w * 0.72, 8.0)
		draw_rect(bar_rect, cyan_col, true)
		draw_rect(bar_rect.grow(-1.5), Color.WHITE, true)
		
	# Lightning bolt symbol on battery
	var bolt := PackedVector2Array([
		Vector2(bat_pos.x + 2, bat_pos.y - 12),
		Vector2(bat_pos.x - 6, bat_pos.y + 1),
		Vector2(bat_pos.x - 1, bat_pos.y + 1),
		Vector2(bat_pos.x - 3, bat_pos.y + 12),
		Vector2(bat_pos.x + 6, bat_pos.y - 1),
		Vector2(bat_pos.x + 1, bat_pos.y - 1)
	])
	draw_colored_polygon(bolt, yellow_col)
	
	# -------------------------------------------------------------
	# 2. DRAW TARGET ELEMENT (INCANDESCENT BULB) AT RIGHT
	# -------------------------------------------------------------
	var bulb_rad := 24.0
	# Radiant incandescent light bloom
	var bloom_rad := bulb_rad * (1.8 + 0.35 * pulse)
	draw_circle(bulb_pos, bloom_rad, Color(yellow_col.r, yellow_col.g, yellow_col.b, 0.22 + 0.12 * pulse))
	draw_circle(bulb_pos, bulb_rad * 1.35, Color(1.0, 0.95, 0.5, 0.45))
	
	# Glass dome
	draw_circle(bulb_pos, bulb_rad, Color(0.98, 0.90, 0.45, 0.90))
	draw_circle(bulb_pos, bulb_rad * 0.65, Color.WHITE)
	
	# Filament coil inside
	var fil_pts := PackedVector2Array([
		Vector2(bulb_pos.x - 8, bulb_pos.y + 10),
		Vector2(bulb_pos.x - 5, bulb_pos.y - 8),
		Vector2(bulb_pos.x, bulb_pos.y - 12),
		Vector2(bulb_pos.x + 5, bulb_pos.y - 8),
		Vector2(bulb_pos.x + 8, bulb_pos.y + 10)
	])
	draw_polyline(fil_pts, Color(1.0, 0.5, 0.1, 1.0), 3.0)
	draw_polyline(fil_pts, Color.WHITE, 1.5)
	
	# Screw base collar
	var base_rect := Rect2(bulb_pos.x - 10, bulb_pos.y + bulb_rad * 0.7, 20, 14)
	draw_rect(base_rect, Color(0.80, 0.65, 0.25, 1.0), true)
	draw_rect(base_rect, Color(0.45, 0.35, 0.15, 1.0), false, 1.5)

func _draw_spark_along_track(track: PackedVector2Array, progress: float, spark_color: Color) -> void:
	if track.size() < 2:
		return
	# Calculate total polyline length
	var total_len := 0.0
	var seg_lens: Array[float] = []
	for i in range(track.size() - 1):
		var d := track[i].distance_to(track[i + 1])
		seg_lens.append(d)
		total_len += d
	
	if total_len <= 0.001:
		return
		
	var target_dist := progress * total_len
	var curr_dist := 0.0
	var spark_pos := track[0]
	
	for i in range(seg_lens.size()):
		var sl: float = seg_lens[i]
		if curr_dist + sl >= target_dist:
			var seg_t := (target_dist - curr_dist) / sl
			spark_pos = track[i].lerp(track[i + 1], seg_t)
			break
		curr_dist += sl
		
	# Draw prominent plasma spark ball & energetic corona
	draw_circle(spark_pos, 8.0, Color(spark_color.r, spark_color.g, spark_color.b, 0.55))
	draw_circle(spark_pos, 4.5, spark_color)
	draw_circle(spark_pos, 2.2, Color.WHITE)
