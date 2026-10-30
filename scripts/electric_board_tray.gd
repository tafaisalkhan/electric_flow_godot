# electric_board_tray.gd
# Dedicated industrial console chassis / tray for Electric Flow puzzle boards.
# Renders a sleek 2.5D hardware console chassis with corner hex bolts,
# recessed module sockets, conduit grooves, and power output terminals.
class_name ElectricBoardTray
extends Control

@export var board_rows: int = 3
@export var board_cols: int = 3
@export var tile_size: float = 100.0
@export var tile_spacing: float = 6.0
@export var tray_padding: float = 14.0

var is_board_powered: bool = false
var pulse_timer: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	set_process(true)

func _process(delta: float) -> void:
	if is_board_powered:
		pulse_timer += delta * 3.5
		queue_redraw()

func configure_tray(rows: int, cols: int, t_size: float, spacing: float, padding: float = 14.0) -> void:
	board_rows = rows
	board_cols = cols
	tile_size = t_size
	tile_spacing = spacing
	tray_padding = padding
	
	var total_w := board_cols * tile_size + (board_cols - 1) * tile_spacing + tray_padding * 2.0
	var total_h := board_rows * tile_size + (board_rows - 1) * tile_spacing + tray_padding * 2.0
	
	custom_minimum_size = Vector2(total_w, total_h)
	size = Vector2(total_w, total_h)
	queue_redraw()

func set_powered(powered: bool) -> void:
	var changed := (is_board_powered != powered)
	is_board_powered = powered
	if changed:
		queue_redraw()

func _draw() -> void:
	if board_rows <= 0 or board_cols <= 0:
		return
		
	var s := size
	var chassis_corner_rad := 20.0
	
	# -------------------------------------------------------------
	# 1. CHASSIS DROP SHADOW (Multi-stage soft depth)
	# -------------------------------------------------------------
	var shadow_rect1 := Rect2(2.0, 8.0, s.x - 4.0, s.y - 4.0)
	draw_rounded_rect(shadow_rect1, chassis_corner_rad + 2.0, Color(0.01, 0.02, 0.05, 0.55))
	
	var shadow_rect2 := Rect2(4.0, 14.0, s.x - 8.0, s.y - 8.0)
	draw_rounded_rect(shadow_rect2, chassis_corner_rad + 4.0, Color(0.01, 0.02, 0.05, 0.35))
	
	# -------------------------------------------------------------
	# 2. MAIN CONSOLE CHASSIS FRAME (Brushed titanium slate blue)
	# -------------------------------------------------------------
	var chassis_rect := Rect2(Vector2.ZERO, s).grow(-2.0)
	var chassis_bg := Color(0.10, 0.15, 0.24, 1.0)
	draw_rounded_rect(chassis_rect, chassis_corner_rad, chassis_bg)
	
	# Top-left specular highlight edge
	draw_rounded_rect_outline(chassis_rect, chassis_corner_rad, Color(0.24, 0.38, 0.58, 0.95), 2.5)
	
	# Bottom-right shadow lip
	var shadow_lip := Rect2(chassis_rect.position.x + 2, chassis_rect.position.y + 3, chassis_rect.size.x - 4, chassis_rect.size.y - 3)
	draw_rounded_rect_outline(shadow_lip, chassis_corner_rad, Color(0.04, 0.06, 0.11, 0.9), 1.8)
	
	# Subtle top chassis sheen
	var top_sheen := Rect2(chassis_rect.position.x + 8, chassis_rect.position.y + 4, chassis_rect.size.x - 16, 12.0)
	draw_rounded_rect(top_sheen, 6.0, Color(1.0, 1.0, 1.0, 0.06))
	
	# -------------------------------------------------------------
	# 3. INDUSTRIAL CORNER HEX BOLTS (4 Chassis Corners)
	# -------------------------------------------------------------
	var bolt_inset := 10.0
	var bolt_radius := 4.5
	var bolt_positions: Array[Vector2] = [
		Vector2(bolt_inset, bolt_inset),
		Vector2(s.x - bolt_inset, bolt_inset),
		Vector2(s.x - bolt_inset, s.y - bolt_inset),
		Vector2(bolt_inset, s.y - bolt_inset)
	]
	
	for bp in bolt_positions:
		# Recessed washer
		draw_circle(bp + Vector2(0, 1), bolt_radius + 2.0, Color(0.04, 0.06, 0.10, 0.8))
		draw_circle(bp, bolt_radius + 1.2, Color(0.20, 0.28, 0.40, 1.0))
		# Hex bolt head
		draw_circle(bp, bolt_radius, Color(0.68, 0.74, 0.84, 1.0))
		# Specular glint
		draw_circle(bp + Vector2(-1, -1), bolt_radius * 0.4, Color(1.0, 1.0, 1.0, 0.75))
		# Center hex socket
		draw_circle(bp, bolt_radius * 0.45, Color(0.12, 0.16, 0.24, 1.0))
	
	# -------------------------------------------------------------
	# 4. INNER RECESSED TILE BED (Dark recessed chassis tray)
	# -------------------------------------------------------------
	var bed_x := tray_padding - 4.0
	var bed_y := tray_padding - 4.0
	var bed_w := s.x - (tray_padding * 2.0) + 8.0
	var bed_h := s.y - (tray_padding * 2.0) + 8.0
	var bed_rect := Rect2(bed_x, bed_y, bed_w, bed_h)
	var bed_corner_rad := 14.0
	
	# Recessed bed drop shadow
	draw_rounded_rect(bed_rect, bed_corner_rad, Color(0.04, 0.06, 0.10, 1.0))
	
	# Inner shadow rim (inset feeling)
	draw_rounded_rect_outline(bed_rect, bed_corner_rad, Color(0.02, 0.03, 0.07, 0.95), 2.5)
	
	# Bottom-right highlight lip of the recessed cavity
	var bed_inner_highlight := Rect2(bed_x + 1, bed_y + 1, bed_w - 2, bed_h - 2)
	draw_rounded_rect_outline(bed_inner_highlight, bed_corner_rad, Color(0.18, 0.26, 0.40, 0.45), 1.0)
	
	# -------------------------------------------------------------
	# 5. INTER-SOCKET CONDUIT TRACKS (Deep trenches between cells)
	# -------------------------------------------------------------
	var conduit_w := tile_size * 0.24
	var conduit_col := Color(0.03, 0.05, 0.09, 1.0)
	var conduit_rim := Color(0.12, 0.18, 0.28, 0.6)
	
	# Horizontal conduit channels
	for r in range(board_rows):
		var cy := tray_padding + r * (tile_size + tile_spacing) + tile_size * 0.5
		var x_start := tray_padding + tile_size * 0.5
		var x_end := tray_padding + (board_cols - 1) * (tile_size + tile_spacing) + tile_size * 0.5
		draw_line(Vector2(x_start, cy), Vector2(x_end, cy), conduit_col, conduit_w, true)
		draw_line(Vector2(x_start, cy - conduit_w * 0.5), Vector2(x_end, cy - conduit_w * 0.5), conduit_rim, 1.0)
		draw_line(Vector2(x_start, cy + conduit_w * 0.5), Vector2(x_end, cy + conduit_w * 0.5), conduit_rim, 1.0)
		
	# Vertical conduit channels
	for c in range(board_cols):
		var cx := tray_padding + c * (tile_size + tile_spacing) + tile_size * 0.5
		var y_start := tray_padding + tile_size * 0.5
		var y_end := tray_padding + (board_rows - 1) * (tile_size + tile_spacing) + tile_size * 0.5
		draw_line(Vector2(cx, y_start), Vector2(cx, y_end), conduit_col, conduit_w, true)
		draw_line(Vector2(cx - conduit_w * 0.5, y_start), Vector2(cx - conduit_w * 0.5, y_end), conduit_rim, 1.0)
		draw_line(Vector2(cx + conduit_w * 0.5, y_start), Vector2(cx + conduit_w * 0.5, y_end), conduit_rim, 1.0)
		
	# -------------------------------------------------------------
	# 6. RECESSED SOCKET WELLS (Underneath every tile position)
	# -------------------------------------------------------------
	var socket_rad := tile_size * 0.14
	for r in range(board_rows):
		for c in range(board_cols):
			var sx := tray_padding + c * (tile_size + tile_spacing)
			var sy := tray_padding + r * (tile_size + tile_spacing)
			var s_rect := Rect2(sx, sy, tile_size, tile_size)
			
			# Recessed socket bed
			draw_rounded_rect(s_rect, socket_rad, Color(0.06, 0.09, 0.16, 0.95))
			
			# Socket inner bevel rim
			draw_rounded_rect_outline(s_rect, socket_rad, Color(0.03, 0.05, 0.09, 0.9), 2.0)
			
			# Precision corner L-brackets (Module alignment guides)
			var arm := tile_size * 0.10
			var b_col := Color(0.22, 0.32, 0.48, 0.7)
			# Top-Left L
			draw_line(Vector2(sx + 5, sy + 5), Vector2(sx + 5 + arm, sy + 5), b_col, 1.5)
			draw_line(Vector2(sx + 5, sy + 5), Vector2(sx + 5, sy + 5 + arm), b_col, 1.5)
			# Top-Right L
			draw_line(Vector2(sx + tile_size - 5, sy + 5), Vector2(sx + tile_size - 5 - arm, sy + 5), b_col, 1.5)
			draw_line(Vector2(sx + tile_size - 5, sy + 5), Vector2(sx + tile_size - 5, sy + 5 + arm), b_col, 1.5)
			# Bottom-Left L
			draw_line(Vector2(sx + 5, sy + tile_size - 5), Vector2(sx + 5 + arm, sy + tile_size - 5), b_col, 1.5)
			draw_line(Vector2(sx + 5, sy + tile_size - 5), Vector2(sx + 5, sy + tile_size - 5 - arm), b_col, 1.5)
			# Bottom-Right L
			draw_line(Vector2(sx + tile_size - 5, sy + tile_size - 5), Vector2(sx + tile_size - 5 - arm, sy + tile_size - 5), b_col, 1.5)
			draw_line(Vector2(sx + tile_size - 5, sy + tile_size - 5), Vector2(sx + tile_size - 5, sy + tile_size - 5 - arm), b_col, 1.5)
			
	# -------------------------------------------------------------
	# 7. BOTTOM POWER OUTPUT FEEDER BUS TERMINALS
	# -------------------------------------------------------------
	var term_count := mini(board_cols, 3)
	var term_spacing := (s.x - tray_padding * 2.0) / float(term_count + 1)
	var term_y := s.y - 2.0
	
	for ti in range(term_count):
		var tx := tray_padding + float(ti + 1) * term_spacing
		var term_pos := Vector2(tx, term_y)
		
		# Heavy terminal clamp collar
		draw_rect(Rect2(tx - 9, term_y - 6, 18, 8), Color(0.04, 0.06, 0.10, 1.0))
		draw_rect(Rect2(tx - 7, term_y - 4, 14, 6), Color(0.25, 0.35, 0.48, 1.0))
		
		# Brass/gold contact pin
		var pin_col := Color(0.9, 0.75, 0.35, 1.0)
		if is_board_powered:
			var pulse := (sin(pulse_timer * 3.0 + ti) + 1.0) * 0.5
			# Glowing neon halo discharging downwards toward the landmark
			var halo_col := Color(0.2, 0.95, 1.0, 0.45 + 0.25 * pulse)
			draw_circle(term_pos, 10.0 + 3.0 * pulse, halo_col)
			pin_col = Color(1.0, 1.0, 1.0, 1.0)
			
		draw_circle(term_pos, 3.5, pin_col)

# Helper: Draw smooth rounded rectangle
func draw_rounded_rect(r: Rect2, rad: float, col: Color) -> void:
	rad = minf(rad, minf(r.size.x * 0.5, r.size.y * 0.5))
	var pts := PackedVector2Array()
	var steps := 8
	var corners := [
		Vector2(r.position.x + rad, r.position.y + rad),
		Vector2(r.end.x - rad, r.position.y + rad),
		Vector2(r.end.x - rad, r.end.y - rad),
		Vector2(r.position.x + rad, r.end.y - rad)
	]
	var angles := [PI, PI * 1.5, 0.0, PI * 0.5]
	for c_idx in range(4):
		var c_pt: Vector2 = corners[c_idx]
		var base_ang: float = angles[c_idx]
		for step in range(steps + 1):
			var a: float = base_ang + (float(step) / float(steps)) * (PI * 0.5)
			pts.append(c_pt + Vector2(cos(a) * rad, sin(a) * rad))
	draw_colored_polygon(pts, col)

# Helper: Draw smooth rounded rectangle outline
func draw_rounded_rect_outline(r: Rect2, rad: float, col: Color, width: float) -> void:
	rad = minf(rad, minf(r.size.x * 0.5, r.size.y * 0.5))
	var pts := PackedVector2Array()
	var steps := 8
	var corners := [
		Vector2(r.position.x + rad, r.position.y + rad),
		Vector2(r.end.x - rad, r.position.y + rad),
		Vector2(r.end.x - rad, r.end.y - rad),
		Vector2(r.position.x + rad, r.end.y - rad)
	]
	var angles := [PI, PI * 1.5, 0.0, PI * 0.5]
	for c_idx in range(4):
		var c_pt: Vector2 = corners[c_idx]
		var base_ang: float = angles[c_idx]
		for step in range(steps + 1):
			var a: float = base_ang + (float(step) / float(steps)) * (PI * 0.5)
			pts.append(c_pt + Vector2(cos(a) * rad, sin(a) * rad))
	pts.append(pts[0])
	draw_polyline(pts, col, width)
