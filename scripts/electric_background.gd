# electric_background.gd
# Dynamic high-tech ambient backdrop for Electric Flow.
# Renders a dark blueprint vignette, subtle radial board lighting,
# electronic grid dots, and vertical power bus rails.
class_name ElectricBackground
extends Control

var anim_timer: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)

func _process(delta: float) -> void:
	anim_timer += delta
	# Very subtle slow pulse for ambient glow
	queue_redraw()

func _draw() -> void:
	var s := size
	if s.x <= 0 or s.y <= 0:
		return
		
	# 1. Base deep-space dark gradient fill
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.04, 0.06, 0.12, 1.0))
	
	# 2. Ambient radial glow centered behind the puzzle board (y approx 42% height)
	var glow_center := Vector2(s.x * 0.5, s.y * 0.42)
	var glow_rad := s.x * 0.75
	var glow_pulse := 0.08 + 0.02 * sin(anim_timer * 1.5)
	
	for i in range(5):
		var r_step := lerpf(glow_rad * 0.2, glow_rad, float(i + 1) / 5.0)
		var a_step := lerpf(glow_pulse, 0.0, float(i + 1) / 5.0)
		draw_circle(glow_center, r_step, Color(0.12, 0.22, 0.42, a_step))
		
	# 3. Futuristic blueprint dot grid (every 32px)
	var dot_spacing := 32.0
	var dot_col := Color(0.35, 0.55, 0.85, 0.045)
	var start_x := fmod(s.x * 0.5, dot_spacing)
	var start_y := fmod(s.y * 0.5, dot_spacing)
	
	var x := start_x
	while x < s.x:
		var y := start_y
		while y < s.y:
			draw_circle(Vector2(x, y), 1.0, dot_col)
			y += dot_spacing
		x += dot_spacing
		
	# 4. Vertical cybernetic power bus rails on left and right screen borders
	var rail_w := 3.0
	var rail_margin := 8.0
	var rail_col := Color(0.15, 0.25, 0.40, 0.35)
	
	draw_line(Vector2(rail_margin, 0), Vector2(rail_margin, s.y), rail_col, rail_w)
	draw_line(Vector2(s.x - rail_margin, 0), Vector2(s.x - rail_margin, s.y), rail_col, rail_w)
	
	# Small circuit ticks on the power rails
	var tick_spacing := 64.0
	var ty := 32.0
	while ty < s.y:
		draw_line(Vector2(rail_margin, ty), Vector2(rail_margin + 6, ty), rail_col, 1.5)
		draw_line(Vector2(s.x - rail_margin - 6, ty), Vector2(s.x - rail_margin, ty), rail_col, 1.5)
		ty += tick_spacing
