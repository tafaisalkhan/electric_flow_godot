# electric_landmark.gd
# Interactive animated landmark display positioned at the bottom of the puzzle board.
# Shows a Small House, Big House (Villa), or City Skyscraper with Big Solar Panel Array
# connected via electrical feeder conduits directly from the board above that lights up
# with glowing electricity when the circuit is completed!
class_name ElectricLandmark
extends Control

const ElectricEnums = preload("res://scripts/electric_enums.gd")
const LANDMARK_FONT: Font = preload("res://assets/fonts/LuckiestGuy-Regular.ttf")

# Structure Types
enum StructureType {
	SMALL_HOUSE = 0,
	BIG_HOUSE = 1,
	CITY_BUILDING = 2
}

var current_structure: int = StructureType.SMALL_HOUSE
var power_ratio: float = 0.0 # 0.0 (no targets powered) to 1.0 (all targets powered)
var is_fully_powered: bool = false
var anim_timer: float = 0.0
var power_surge_anim: float = 0.0
var window_ignite_progress: float = 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(490, 170)
	size = Vector2(490, 170)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)

func _process(delta: float) -> void:
	anim_timer += delta
	if is_fully_powered:
		power_surge_anim = minf(1.0, power_surge_anim + delta * 2.5)
		window_ignite_progress = minf(1.0, window_ignite_progress + delta * 3.5)
	else:
		power_surge_anim = maxf(0.0, power_surge_anim - delta * 3.0)
		window_ignite_progress = maxf(0.0, window_ignite_progress - delta * 4.0)
	queue_redraw()

func configure_level(level_num: int, rows: int, cols: int) -> void:
	var total_tiles := rows * cols
	if total_tiles <= 9 or level_num <= 10:
		current_structure = StructureType.SMALL_HOUSE
	elif total_tiles <= 16 or level_num <= 40:
		current_structure = StructureType.BIG_HOUSE
	else:
		current_structure = StructureType.CITY_BUILDING
	
	is_fully_powered = false
	power_ratio = 0.0
	power_surge_anim = 0.0
	window_ignite_progress = 0.0
	queue_redraw()

func set_circuit_status(powered_targets: int, total_targets: int, solved: bool) -> void:
	var was_powered := is_fully_powered
	is_fully_powered = solved
	if total_targets > 0:
		power_ratio = clampf(float(powered_targets) / float(total_targets), 0.0, 1.0)
	else:
		power_ratio = 1.0 if solved else 0.0
		
	if not was_powered and is_fully_powered:
		# Satisfying celebratory bounce when power floods the house
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector2(1.03, 1.03), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	queue_redraw()

func _draw() -> void:
	var s := size
	var rect := Rect2(Vector2.ZERO, s)
	
	# 1. Scenic Night Sky & Horizon Backdrop
	draw_scenic_backdrop(rect)
	
	# 2. Power Feeders / Conduit cables connecting FROM THE BOARD (y=0) down into the house
	draw_power_feeders(s)
	
	# 3. Structure based on level type (Small House, Big Villa, or Skyscraper with Solar Panels)
	match current_structure:
		StructureType.SMALL_HOUSE:
			draw_small_cottage(s)
		StructureType.BIG_HOUSE:
			draw_big_villa(s)
		StructureType.CITY_BUILDING:
			draw_skyscraper_with_solar_panels(s)
			
	# 4. Status Glow Banner
	draw_power_status_badge(s)

# -------------------------------------------------------------
# SCENIC BACKDROP & NIGHT SKY
# -------------------------------------------------------------
func draw_scenic_backdrop(r: Rect2) -> void:
	var bg_col := Color(0.05, 0.09, 0.18, 0.96)
	var border_col := Color(0.18, 0.32, 0.52, 0.85)
	var corner_rad := 16.0
	
	# Drop shadow
	draw_style_box_rect(Rect2(r.position.x + 2, r.position.y + 4, r.size.x - 4, r.size.y - 4), corner_rad, Color(0.02, 0.04, 0.08, 0.65))
	# Main plate
	draw_style_box_rect(Rect2(r.position.x, r.position.y, r.size.x, r.size.y - 2), corner_rad, bg_col, border_col, 2.0)
	
	# Twinkling night sky stars
	var star_positions: Array[Vector2] = [
		Vector2(32, 28), Vector2(80, 20), Vector2(125, 42), Vector2(175, 24),
		Vector2(310, 26), Vector2(355, 44), Vector2(405, 22), Vector2(450, 34)
	]
	for i in range(star_positions.size()):
		var sp: Vector2 = star_positions[i]
		var star_twinkle := (sin(anim_timer * 2.5 + float(i) * 1.7) + 1.0) * 0.5
		var star_alpha := 0.35 + 0.5 * star_twinkle
		draw_circle(sp, 1.4, Color(1.0, 1.0, 1.0, star_alpha))
		
	# Ground Lawn / Concrete Foundation
	var ground_y := r.size.y - 18.0
	var ground_col := Color(0.10, 0.22, 0.18, 1.0) if current_structure != StructureType.CITY_BUILDING else Color(0.12, 0.16, 0.22, 1.0)
	draw_rect(Rect2(6, ground_y, r.size.x - 12, 14.0), ground_col)
	draw_line(Vector2(6, ground_y), Vector2(r.size.x - 6, ground_y), Color(0.2, 0.35, 0.3, 0.8), 1.5)

# -------------------------------------------------------------
# FEEDER POWER CONDUITS CONNECTING FROM THE BOARD (y=0) TO THE HOUSE
# -------------------------------------------------------------
func draw_power_feeders(s: Vector2) -> void:
	var wire_active := is_fully_powered
	var glow_col := Color(0.0, 0.92, 1.0, 1.0)
	var yellow_current_col := Color(1.0, 0.92, 0.35, 1.0)
	var ground_y := s.y - 18.0
	
	# Target electrical service entrance on the house / structure:
	# For cottage: cx = s.x * 0.5, house_w = 116.0 -> service weatherhead at hx - 6
	var cx := s.x * 0.50
	var house_entrance := Vector2(cx - 62.0, ground_y - 48.0)
	if current_structure == StructureType.BIG_HOUSE:
		house_entrance = Vector2(cx - 82.0, ground_y - 56.0)
	elif current_structure == StructureType.CITY_BUILDING:
		house_entrance = Vector2(cx - 64.0, ground_y - 68.0)
	
	# 1. Top Board Terminals at y = 0 (Connecting directly with the bottom of the board panel)
	var drop_xs: Array[float] = [s.x * 0.15, s.x * 0.85]
	for dx: float in drop_xs:
		var board_conn_pt := Vector2(dx, 0.0)
		var pole_top := Vector2(dx, 34.0)
		var pole_bot := Vector2(dx, ground_y)
		
		# Board Terminal Junction Socket at y = 0
		draw_rect(Rect2(dx - 10, 0, 20, 7), Color(0.25, 0.32, 0.45, 1.0))
		draw_rect(Rect2(dx - 6, 0, 12, 4), Color(0.12, 0.16, 0.24, 1.0))
		
		# Steel Utility Pole with Cross-Arm
		draw_line(pole_top, pole_bot, Color(0.22, 0.26, 0.36, 1.0), 4.0)
		# Cross-arm with ceramic insulators
		draw_line(Vector2(dx - 14, pole_top.y), Vector2(dx + 14, pole_top.y), Color(0.35, 0.42, 0.54, 1.0), 3.0)
		draw_circle(Vector2(dx - 12, pole_top.y), 2.5, Color(0.8, 0.85, 0.9, 1.0))
		draw_circle(Vector2(dx + 12, pole_top.y), 2.5, Color(0.8, 0.85, 0.9, 1.0))
		
		# Vertical conduit drop coming straight down FROM the board (y=0) to the utility pole
		var wire_col := Color(0.28, 0.34, 0.46, 1.0)
		draw_line(board_conn_pt, pole_top, wire_col, 2.5)
		
		# Catenary Feeder Cable swooping down from utility pole to house service entrance
		var wire_mid := (pole_top + house_entrance) * 0.5 + Vector2(0, 14.0)
		draw_line(pole_top, wire_mid, wire_col, 2.0)
		draw_line(wire_mid, house_entrance, wire_col, 2.0)
		
		if wire_active:
			var pulse := (sin(anim_timer * 6.0) + 1.0) * 0.5
			var c_glow := glow_col
			c_glow.a = 0.5 + 0.3 * pulse
			
			# Glowing high-voltage wire from board down to pole
			draw_line(board_conn_pt, pole_top, c_glow, 5.0)
			draw_line(board_conn_pt, pole_top, Color.WHITE, 1.8)
			
			# Glowing wire from pole to house
			draw_line(pole_top, wire_mid, c_glow, 4.5)
			draw_line(wire_mid, house_entrance, c_glow, 4.5)
			draw_line(pole_top, wire_mid, Color.WHITE, 1.6)
			draw_line(wire_mid, house_entrance, Color.WHITE, 1.6)
			
			# Sparks at board socket connection
			draw_circle(board_conn_pt + Vector2(0, 4), 3.5 + 1.5 * pulse, yellow_current_col)
			
			# Animated traveling neon spark pulses FLOWING DOWN from the board into the house
			for p_i in range(3):
				var t := fposmod(anim_timer * 2.2 + float(p_i) * 0.35, 1.0)
				var spark_pos: Vector2
				if t < 0.35:
					var sub_t := t / 0.35
					spark_pos = board_conn_pt.lerp(pole_top, sub_t)
				elif t < 0.68:
					var sub_t := (t - 0.35) / 0.33
					spark_pos = pole_top.lerp(wire_mid, sub_t)
				else:
					var sub_t := (t - 0.68) / 0.32
					spark_pos = wire_mid.lerp(house_entrance, sub_t)
				
				draw_circle(spark_pos, 2.5, Color.WHITE)
				draw_circle(spark_pos, 5.5, Color(0.2, 0.9, 1.0, 0.6))
	
	# House Electric Service Weatherhead / Breaker Box on wall
	draw_rect(Rect2(house_entrance.x - 5, house_entrance.y - 4, 10, 16), Color(0.25, 0.32, 0.44, 1.0))
	draw_rect(Rect2(house_entrance.x - 3, house_entrance.y - 2, 6, 12), Color(0.14, 0.18, 0.26, 1.0))
	# Electric meter glass disc
	var meter_col := Color(0.0, 1.0, 0.7, 1.0) if wire_active else Color(0.8, 0.2, 0.2, 0.7)
	draw_circle(house_entrance + Vector2(0, 4), 3.0, meter_col)
	if wire_active:
		var m_pulse := (sin(anim_timer * 8.0) + 1.0) * 0.5
		draw_circle(house_entrance + Vector2(0, 4), 5.5 + 2.0 * m_pulse, Color(0.0, 0.9, 1.0, 0.5))

# -------------------------------------------------------------
# STRUCTURE 0: SMALL COTTAGE / HOUSE
# -------------------------------------------------------------
func draw_small_cottage(s: Vector2) -> void:
	var cx := s.x * 0.50
	var ground_y := s.y - 18.0
	var house_w := 116.0
	var house_h := 66.0
	var hx := cx - house_w * 0.5
	var hy := ground_y - house_h
	
	# Chimney on left of roof
	var chim_x := hx + 16.0
	var chim_w := 16.0
	var chim_h := 32.0
	var chim_y := hy - 16.0
	draw_rect(Rect2(chim_x, chim_y, chim_w, chim_h), Color(0.48, 0.25, 0.20, 1.0))
	draw_rect(Rect2(chim_x - 2, chim_y - 2, chim_w + 4, 4), Color(0.35, 0.18, 0.15, 1.0))
	
	# Chimney Smoke when powered!
	if is_fully_powered:
		for sm in range(4):
			var smoke_t := fposmod(anim_timer * 1.1 + float(sm) * 0.28, 1.0)
			var sm_x := chim_x + chim_w * 0.5 + sin(smoke_t * 6.0) * 10.0 - (smoke_t * 14.0)
			var sm_y := chim_y - 4.0 - smoke_t * 32.0
			var sm_rad := 3.2 + smoke_t * 7.0
			var sm_alpha := (1.0 - smoke_t) * 0.65
			draw_circle(Vector2(sm_x, sm_y), sm_rad, Color(0.92, 0.94, 0.97, sm_alpha))
	
	# Main House Body (Warm Cottage Walls)
	var wall_col := Color(0.86, 0.80, 0.70, 1.0)
	draw_rect(Rect2(hx, hy, house_w, house_h), wall_col)
	# Wall foundation trim
	draw_rect(Rect2(hx, ground_y - 4, house_w, 4), Color(0.45, 0.42, 0.40, 1.0))
	
	# Triangular Pitch Gable Roof
	var roof_pts := PackedVector2Array([
		Vector2(hx - 12.0, hy),
		Vector2(cx, hy - 40.0),
		Vector2(hx + house_w + 12.0, hy)
	])
	var roof_col := Color(0.72, 0.24, 0.20, 1.0)
	draw_colored_polygon(roof_pts, roof_col)
	# Roof ridge highlights
	draw_line(Vector2(hx - 12.0, hy), Vector2(cx, hy - 40.0), Color(0.95, 0.45, 0.40, 1.0), 3.0)
	draw_line(Vector2(cx, hy - 40.0), Vector2(hx + house_w + 12.0, hy), Color(0.55, 0.16, 0.14, 1.0), 3.0)
	
	# Front Door in center
	var door_w := 22.0
	var door_h := 36.0
	var door_x := cx - door_w * 0.5
	var door_y := ground_y - door_h
	draw_rect(Rect2(door_x, door_y, door_w, door_h), Color(0.40, 0.22, 0.14, 1.0))
	draw_rect(Rect2(door_x + 1, door_y + 1, door_w - 2, door_h - 2), Color(0.52, 0.30, 0.18, 1.0))
	# Brass doorknob
	draw_circle(Vector2(door_x + door_w - 5, door_y + door_h * 0.55), 2.0, Color(0.95, 0.82, 0.35, 1.0))
	
	# Porch Light above door
	var porch_light_pos := Vector2(cx, door_y - 7.0)
	draw_circle(porch_light_pos, 4.0, Color(0.2, 0.25, 0.35, 1.0))
	if is_fully_powered:
		var pl_glow := Color(1.0, 0.88, 0.35, 0.95)
		draw_circle(porch_light_pos, 4.5, pl_glow)
		draw_circle(porch_light_pos, 14.0, Color(1.0, 0.85, 0.3, 0.4 * window_ignite_progress))
	
	# 2 Large Front Windows (Left and Right of door)
	var win_w := 26.0
	var win_h := 28.0
	var win_y := hy + 14.0
	var win_xs: Array[float] = [hx + 12.0, hx + house_w - 12.0 - win_w]
	
	for wx: float in win_xs:
		draw_cottage_window(Rect2(wx, win_y, win_w, win_h))
		
	# Garden Trees on Left and Right
	draw_garden_tree(Vector2(hx - 30.0, ground_y))
	draw_garden_tree(Vector2(hx + house_w + 30.0, ground_y))

func draw_cottage_window(rect: Rect2) -> void:
	# Window Frame
	draw_rect(rect.grow(2.5), Color(0.28, 0.20, 0.16, 1.0))
	draw_rect(rect.grow(1.2), Color(0.95, 0.95, 0.98, 1.0))
	
	if is_fully_powered or window_ignite_progress > 0.05:
		var p := window_ignite_progress
		var pulse := (sin(anim_timer * 4.0) + 1.0) * 0.5
		# Radiant warm golden-yellow glow
		var glow_col := Color(1.0, 0.85, 0.35, 0.45 * p)
		draw_rect(rect.grow(9.0 * p), glow_col)
		
		# Illuminated glass
		var glass_col := Color(1.0, 0.92, 0.42, 1.0).lerp(Color(1.0, 1.0, 0.85, 1.0), pulse * 0.3)
		draw_rect(rect, glass_col)
		
		# Warm light spill on ground
		var spill_rect := Rect2(rect.position.x - 4, rect.position.y + rect.size.y + 4, rect.size.x + 8, 10)
		draw_rect(spill_rect, Color(1.0, 0.85, 0.3, 0.3 * p))
	else:
		# Dark night glass
		draw_rect(rect, Color(0.12, 0.18, 0.28, 1.0))
		draw_rect(Rect2(rect.position.x, rect.position.y, rect.size.x, rect.size.y * 0.4), Color(0.08, 0.12, 0.20, 0.8))
		
	# Window mullions (cross bars)
	var cross_col := Color(0.3, 0.22, 0.18, 0.85) if (not is_fully_powered and window_ignite_progress < 0.2) else Color(0.4, 0.3, 0.2, 0.95)
	draw_line(Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y), Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y + rect.size.y), cross_col, 2.0)
	draw_line(Vector2(rect.position.x, rect.position.y + rect.size.y * 0.5), Vector2(rect.position.x + rect.size.x, rect.position.y + rect.size.y * 0.5), cross_col, 2.0)

func draw_garden_tree(pos: Vector2) -> void:
	# Trunk
	draw_line(pos, pos - Vector2(0, 22), Color(0.35, 0.22, 0.14, 1.0), 4.0)
	# Foliage
	var fol_col := Color(0.15, 0.38, 0.22, 1.0)
	draw_circle(pos - Vector2(0, 28), 13.0, fol_col)
	draw_circle(pos - Vector2(-5, 33), 10.0, fol_col.lightened(0.1))
	draw_circle(pos - Vector2(5, 30), 11.0, fol_col.darkened(0.1))

# -------------------------------------------------------------
# STRUCTURE 1: BIG TWO-STORY VILLA (MEDIUM BOARD)
# -------------------------------------------------------------
func draw_big_villa(s: Vector2) -> void:
	var cx := s.x * 0.50
	var ground_y := s.y - 18.0
	var villa_w := 156.0
	var villa_h := 78.0
	var vx := cx - villa_w * 0.5
	var vy := ground_y - villa_h
	
	# Main Villa Structure (Two Floors)
	var villa_col := Color(0.88, 0.85, 0.80, 1.0)
	draw_rect(Rect2(vx, vy, villa_w, villa_h), villa_col)
	# Inter-floor dividing ledge
	draw_line(Vector2(vx, vy + 38.0), Vector2(vx + villa_w, vy + 38.0), Color(0.55, 0.52, 0.48, 1.0), 2.5)
	
	# Twin-Gable Modern Tiled Roof
	var roof_pts_left := PackedVector2Array([
		Vector2(vx - 8, vy), Vector2(vx + villa_w * 0.32, vy - 28), Vector2(vx + villa_w * 0.64, vy)
	])
	var roof_pts_right := PackedVector2Array([
		Vector2(vx + villa_w * 0.48, vy), Vector2(vx + villa_w * 0.78, vy - 28), Vector2(vx + villa_w + 8, vy)
	])
	var roof_col := Color(0.24, 0.32, 0.46, 1.0)
	draw_colored_polygon(roof_pts_left, roof_col)
	draw_colored_polygon(roof_pts_right, roof_col.lightened(0.08))
	draw_line(Vector2(vx - 8, vy), Vector2(vx + villa_w * 0.32, vy - 28), Color(0.45, 0.55, 0.72, 1.0), 2.5)
	draw_line(Vector2(vx + villa_w * 0.48, vy), Vector2(vx + villa_w * 0.78, vy - 28), Color(0.45, 0.55, 0.72, 1.0), 2.5)
	
	# Center Balcony with railings
	var balc_w := 40.0
	var balc_h := 12.0
	var balc_x := cx - balc_w * 0.5
	var balc_y := vy + 28.0
	draw_rect(Rect2(balc_x, balc_y, balc_w, balc_h), Color(0.65, 0.65, 0.70, 1.0))
	for r_i in range(5):
		var rx := balc_x + float(r_i) * (balc_w / 4.0)
		draw_line(Vector2(rx, balc_y - 10), Vector2(rx, balc_y), Color(0.25, 0.30, 0.40, 1.0), 1.5)
	draw_line(Vector2(balc_x, balc_y - 10), Vector2(balc_x + balc_w, balc_y - 10), Color(0.35, 0.40, 0.50, 1.0), 2.0)
	
	# Entrance Canopy & Glass Double Doors
	var door_w := 30.0
	var door_h := 32.0
	var door_x := cx - door_w * 0.5
	var door_y := ground_y - door_h
	draw_rect(Rect2(door_x - 4, door_y - 4, door_w + 8, 5), Color(0.25, 0.30, 0.40, 1.0))
	draw_rect(Rect2(door_x, door_y, door_w, door_h), Color(0.18, 0.22, 0.30, 1.0))
	if is_fully_powered or window_ignite_progress > 0.1:
		draw_rect(Rect2(door_x + 2, door_y + 2, door_w - 4, door_h - 4), Color(1.0, 0.88, 0.42, 0.95))
	
	# 4 Large Windows (2 upper floor, 2 ground floor)
	var win_coords: Array[Vector2] = [
		Vector2(vx + 16, vy + 8), Vector2(vx + villa_w - 44, vy + 8),
		Vector2(vx + 16, vy + 46), Vector2(vx + villa_w - 44, vy + 46)
	]
	for wp: Vector2 in win_coords:
		draw_cottage_window(Rect2(wp.x, wp.y, 28, 22))
		
	# Balcony Door window
	draw_cottage_window(Rect2(cx - 12, vy + 6, 24, 22))
	
	# Garden trees
	draw_garden_tree(Vector2(vx - 24.0, ground_y))
	draw_garden_tree(Vector2(vx + villa_w + 24.0, ground_y))

# -------------------------------------------------------------
# STRUCTURE 2: METROPOLITAN SKYSCRAPER WITH BIG SOLAR PANEL ARRAY
# -------------------------------------------------------------
func draw_skyscraper_with_solar_panels(s: Vector2) -> void:
	var cx := s.x * 0.52
	var ground_y := s.y - 18.0
	var tower_w := 118.0
	var tower_h := 104.0
	var tx := cx - tower_w * 0.5
	var ty := ground_y - tower_h
	
	# ---------------------------------------------------------
	# 1. BIG HIGH-CAPACITY SOLAR PANEL ARRAY ON THE LEFT
	# ---------------------------------------------------------
	var panel_x := tx - 76.0
	var panel_y := ground_y - 48.0
	var panel_w := 62.0
	var panel_h := 40.0
	
	# Solar mounting truss
	draw_line(Vector2(panel_x + panel_w * 0.5, ground_y), Vector2(panel_x + panel_w * 0.5, panel_y + panel_h * 0.5), Color(0.35, 0.42, 0.52, 1.0), 3.5)
	draw_line(Vector2(panel_x + 6, ground_y), Vector2(panel_x + panel_w * 0.5, panel_y + panel_h * 0.6), Color(0.25, 0.32, 0.42, 1.0), 2.0)
	draw_line(Vector2(panel_x + panel_w - 6, ground_y), Vector2(panel_x + panel_w * 0.5, panel_y + panel_h * 0.6), Color(0.25, 0.32, 0.42, 1.0), 2.0)
	
	# Angled Solar Panel Frame
	var solar_pts := PackedVector2Array([
		Vector2(panel_x + 10, panel_y),
		Vector2(panel_x + panel_w + 10, panel_y - 8),
		Vector2(panel_x + panel_w, panel_y + panel_h - 8),
		Vector2(panel_x, panel_y + panel_h)
	])
	draw_colored_polygon(solar_pts, Color(0.12, 0.16, 0.24, 1.0))
	
	# Photovoltaic Solar Cells (4x3 matrix)
	var cell_col := Color(0.0, 0.78, 1.0, 1.0) if is_fully_powered else Color(0.14, 0.28, 0.44, 1.0)
	var solar_inner := PackedVector2Array([
		Vector2(panel_x + 12, panel_y + 2),
		Vector2(panel_x + panel_w + 8, panel_y - 6),
		Vector2(panel_x + panel_w - 2, panel_y + panel_h - 10),
		Vector2(panel_x + 2, panel_y + panel_h - 2)
	])
	draw_colored_polygon(solar_inner, cell_col)
	
	if is_fully_powered:
		# Pulsing Cyan Energy Wave across Solar Panel
		var p_pulse := (sin(anim_timer * 5.0) + 1.0) * 0.5
		draw_polyline(solar_inner, Color(0.5, 0.95, 1.0, 0.85 + 0.15 * p_pulse), 2.5)
	
	# ---------------------------------------------------------
	# 2. SKYSCRAPER TOWER
	# ---------------------------------------------------------
	# Tower Drop Shadow
	draw_rect(Rect2(tx + 4, ty + 4, tower_w, tower_h), Color(0.02, 0.04, 0.08, 0.5))
	
	# Tower Main Facade
	var facade_col := Color(0.16, 0.22, 0.32, 1.0)
	draw_rect(Rect2(tx, ty, tower_w, tower_h), facade_col)
	# Architectural vertical mullions
	draw_line(Vector2(tx + tower_w * 0.33, ty), Vector2(tx + tower_w * 0.33, ground_y), Color(0.12, 0.16, 0.24, 1.0), 2.0)
	draw_line(Vector2(tx + tower_w * 0.66, ty), Vector2(tx + tower_w * 0.66, ground_y), Color(0.12, 0.16, 0.24, 1.0), 2.0)
	
	# Rooftop Spire / Antenna
	var spire_x := cx
	var spire_top := ty - 26.0
	draw_line(Vector2(spire_x, ty), Vector2(spire_x, spire_top), Color(0.65, 0.72, 0.82, 1.0), 2.5)
	draw_line(Vector2(spire_x - 8, ty - 10), Vector2(spire_x + 8, ty - 10), Color(0.5, 0.6, 0.7, 1.0), 2.0)
	
	# Blinking Rooftop Aircraft Warning Beacon
	var beacon_pulse := (sin(anim_timer * 7.0) + 1.0) * 0.5
	var beacon_col := Color(0.0, 0.95, 1.0, 1.0) if is_fully_powered else Color(1.0, 0.2, 0.2, 0.8)
	draw_circle(Vector2(spire_x, spire_top), 3.5 + 1.5 * beacon_pulse, beacon_col)
	if is_fully_powered:
		draw_arc(Vector2(spire_x, spire_top), 10.0 + 8.0 * beacon_pulse, 0, TAU, 16, Color(0.2, 0.85, 1.0, 0.5 * (1.0 - beacon_pulse)), 2.0)
		
	# Matrix of Office Windows (4 Rows x 3 Columns)
	var cols := 3
	var rows := 4
	var win_w := 24.0
	var win_h := 14.0
	var gap_x := (tower_w - float(cols) * win_w) / float(cols + 1)
	var gap_y := (tower_h - 22.0 - float(rows) * win_h) / float(rows + 1)
	
	for r in range(rows):
		for c in range(cols):
			var wx := tx + gap_x + float(c) * (win_w + gap_x)
			var wy := ty + 10.0 + float(r) * (win_h + gap_y)
			var w_rect := Rect2(wx, wy, win_w, win_h)
			
			if is_fully_powered or window_ignite_progress > 0.05:
				var floor_delay := float(3 - r) * 0.15
				var lit_amount := clampf((window_ignite_progress - floor_delay) / 0.4, 0.0, 1.0)
				if lit_amount > 0.05:
					var win_base := Color(1.0, 0.86, 0.35, 1.0) if (c != 1) else Color(0.45, 0.92, 1.0, 1.0)
					draw_rect(w_rect.grow(4.0 * lit_amount), win_base.blend(Color(1, 1, 1, 0.3)))
					draw_rect(w_rect, win_base)
				else:
					draw_rect(w_rect, Color(0.10, 0.14, 0.22, 1.0))
			else:
				draw_rect(w_rect, Color(0.10, 0.14, 0.22, 1.0))
				draw_rect(Rect2(wx, wy, win_w, 2), Color(0.16, 0.22, 0.32, 1.0))
				
	# Ground Lobby Entrance
	var lobby_w := 38.0
	var lobby_h := 16.0
	var lobby_x := cx - lobby_w * 0.5
	var lobby_y := ground_y - lobby_h
	draw_rect(Rect2(lobby_x, lobby_y, lobby_w, lobby_h), Color(0.08, 0.12, 0.18, 1.0))
	if is_fully_powered or window_ignite_progress > 0.2:
		draw_rect(Rect2(lobby_x + 2, lobby_y + 2, lobby_w - 4, lobby_h - 2), Color(1.0, 0.95, 0.7, 0.95))

# -------------------------------------------------------------
# STATUS GLOW BADGE
# -------------------------------------------------------------
func draw_power_status_badge(s: Vector2) -> void:
	if not is_fully_powered:
		return
		
	var badge_w := 280.0
	var badge_h := 24.0
	var bx := (s.x - badge_w) * 0.5
	var by := 6.0
	
	var badge_text := ""
	var badge_col := Color(1.0, 0.85, 0.2, 1.0)
	
	match current_structure:
		StructureType.SMALL_HOUSE:
			badge_text = "💡 BOARD SOLVED — HOUSE POWERED!"
		StructureType.BIG_HOUSE:
			badge_text = "💡 BOARD SOLVED — VILLA ENERGIZED!"
		StructureType.CITY_BUILDING:
			badge_text = "⚡ BOARD SOLVED — CITY ONLINE!"
		
	# Semi-transparent pill background
	var pill_rect := Rect2(bx, by, badge_w, badge_h)
	draw_style_box_rect(pill_rect, 10.0, Color(0.05, 0.08, 0.16, 0.92), badge_col, 1.5)
	
	# Glow text using game font
	var font: Font = LANDMARK_FONT
	var font_size := 14
	if font:
		var text_size: Vector2 = font.get_string_size(badge_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var text_pos := Vector2(bx + (badge_w - text_size.x) * 0.5, by + 17.0)
		draw_string(font, text_pos, badge_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, badge_col)

# -------------------------------------------------------------
# DRAWING PRIMITIVES
# -------------------------------------------------------------
func draw_style_box_rect(r: Rect2, corner_rad: float, bg: Color, border: Color = Color.TRANSPARENT, border_w: float = 0.0) -> void:
	draw_rounded_rect(r, corner_rad, bg)
	if border.a > 0.0 and border_w > 0.0:
		draw_rounded_rect_outline(r, corner_rad, border, border_w)

func draw_rounded_rect(rect: Rect2, radius: float, color: Color) -> void:
	var pts := PackedVector2Array()
	var r := minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	var x0 := rect.position.x + r
	var x1 := rect.position.x + rect.size.x - r
	var y0 := rect.position.y + r
	var y1 := rect.position.y + rect.size.y - r
	
	for i in range(5):
		var a := PI + float(i) * (PI * 0.5 / 4.0)
		pts.append(Vector2(x0 + cos(a) * r, y0 + sin(a) * r))
	for i in range(5):
		var a := PI * 1.5 + float(i) * (PI * 0.5 / 4.0)
		pts.append(Vector2(x1 + cos(a) * r, y0 + sin(a) * r))
	for i in range(5):
		var a := 0.0 + float(i) * (PI * 0.5 / 4.0)
		pts.append(Vector2(x1 + cos(a) * r, y1 + sin(a) * r))
	for i in range(5):
		var a := PI * 0.5 + float(i) * (PI * 0.5 / 4.0)
		pts.append(Vector2(x0 + cos(a) * r, y1 + sin(a) * r))
		
	draw_colored_polygon(pts, color)

func draw_rounded_rect_outline(rect: Rect2, radius: float, color: Color, width: float) -> void:
	var pts := PackedVector2Array()
	var r := minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	var x0 := rect.position.x + r
	var x1 := rect.position.x + rect.size.x - r
	var y0 := rect.position.y + r
	var y1 := rect.position.y + rect.size.y - r
	
	for i in range(5):
		var a := PI + float(i) * (PI * 0.5 / 4.0)
		pts.append(Vector2(x0 + cos(a) * r, y0 + sin(a) * r))
	for i in range(5):
		var a := PI * 1.5 + float(i) * (PI * 0.5 / 4.0)
		pts.append(Vector2(x1 + cos(a) * r, y0 + sin(a) * r))
	for i in range(5):
		var a := 0.0 + float(i) * (PI * 0.5 / 4.0)
		pts.append(Vector2(x1 + cos(a) * r, y1 + sin(a) * r))
	for i in range(5):
		var a := PI * 0.5 + float(i) * (PI * 0.5 / 4.0)
		pts.append(Vector2(x0 + cos(a) * r, y1 + sin(a) * r))
	pts.append(pts[0])
	
	draw_polyline(pts, color, width)
