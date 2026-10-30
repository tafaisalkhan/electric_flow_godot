# electric_tile.gd
# Interactive puzzle tile for Electric Flow circuits with high-fidelity visuals.
extends Control

const ElectricEnums = preload("res://scripts/electric_enums.gd")

signal tile_clicked(row: int, col: int)

@export var tile_size: float = 120.0

var grid_row: int = 0
var grid_col: int = 0
var tile_type: int = ElectricEnums.TileType.EMPTY
var channel: int = ElectricEnums.Channel.NONE
var current_rotation_step: int = 0 # 0, 1, 2, 3 (each is 90 deg CW)
var is_rotatable: bool = true
var custom_ports: int = 0 # If non-zero, overrides base ports

# Circuit state
var is_powered: bool = false
var active_channel: int = ElectricEnums.Channel.NONE
var inlet_port_world: int = 0
var current_flow_progress: float = 0.0
var _flow_tween: Tween = null

# Animation state
var visual_rotation_rad: float = 0.0
var is_animating_rotation: bool = false
var bulb_pulse_timer: float = 0.0
var bulb_scale_bounce: float = 1.0
var target_rot: int = -1
var hint_highlight_alpha: float = 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(tile_size, tile_size)
	size = Vector2(tile_size, tile_size)
	mouse_filter = Control.MOUSE_FILTER_STOP
	pivot_offset = size * 0.5
	set_process(true)

func _process(delta: float) -> void:
	if is_animating_rotation:
		queue_redraw()
	if is_powered or current_flow_progress > 0.001:
		if tile_type == ElectricEnums.TileType.FAN:
			bulb_pulse_timer += delta * 14.0 # High speed aerodynamic spin!
		elif tile_type == ElectricEnums.TileType.TESLA_COIL:
			bulb_pulse_timer += delta * 7.5
		elif tile_type == ElectricEnums.TileType.HEATER:
			bulb_pulse_timer += delta * 4.8
		else:
			bulb_pulse_timer += delta * 4.0 # Continuous electric flow & wire current animation
		queue_redraw()
	elif tile_type == ElectricEnums.TileType.BATTERY:
		bulb_pulse_timer += delta * 3.0
		queue_redraw()
	elif tile_type == ElectricEnums.TileType.SOLAR:
		bulb_pulse_timer += delta * 2.8
		queue_redraw()

func configure(r: int, c: int, data: Dictionary, size_px: float) -> void:
	grid_row = r
	grid_col = c
	tile_size = size_px
	custom_minimum_size = Vector2(tile_size, tile_size)
	size = Vector2(tile_size, tile_size)
	pivot_offset = size * 0.5
	
	tile_type = int(data.get("type", ElectricEnums.TileType.EMPTY))
	channel = int(data.get("channel", ElectricEnums.Channel.NONE))
	current_rotation_step = int(data.get("rot", 0)) % 4
	target_rot = int(data.get("target_rot", -1))
	is_rotatable = bool(data.get("rotatable", true))
	custom_ports = int(data.get("ports", 0))
	
	visual_rotation_rad = current_rotation_step * (PI / 2.0)
	is_powered = false
	active_channel = ElectricEnums.Channel.NONE
	queue_redraw()

func get_connected_ports() -> int:
	if tile_type == ElectricEnums.TileType.EMPTY:
		return 0
	var base := custom_ports if custom_ports != 0 else ElectricEnums.get_base_ports(tile_type)
	return ElectricEnums.rotate_mask_cw(base, current_rotation_step)

func set_power_state(powered: bool, p_channel: int, delay: float = 0.0, p_inlet_world: int = 0, animate: bool = true) -> void:
	var was_powered := is_powered
	is_powered = powered
	active_channel = p_channel if powered else ElectricEnums.Channel.NONE
	inlet_port_world = p_inlet_world
	
	if _flow_tween and _flow_tween.is_valid():
		_flow_tween.kill()
		
	if not animate:
		current_flow_progress = 1.0 if powered else 0.0
		queue_redraw()
		return
		
	if delay > 0.001:
		current_flow_progress = 0.0
		_flow_tween = create_tween()
		_flow_tween.tween_interval(delay)
		if powered:
			_flow_tween.tween_property(self, "current_flow_progress", 1.0, 0.22).set_trans(Tween.TRANS_LINEAR)
			_flow_tween.tween_callback(func():
				_trigger_element_ignite()
				queue_redraw()
			)
		else:
			_flow_tween.tween_property(self, "current_flow_progress", 0.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			_flow_tween.tween_callback(queue_redraw)
	else:
		if powered:
			if was_powered and current_flow_progress >= 0.99:
				current_flow_progress = 1.0
			else:
				current_flow_progress = 0.0
				_flow_tween = create_tween()
				_flow_tween.tween_property(self, "current_flow_progress", 1.0, 0.22).set_trans(Tween.TRANS_LINEAR)
				_flow_tween.tween_callback(func():
					_trigger_element_ignite()
					queue_redraw()
				)
		else:
			if not was_powered and current_flow_progress <= 0.01:
				current_flow_progress = 0.0
			else:
				_flow_tween = create_tween()
				_flow_tween.tween_property(self, "current_flow_progress", 0.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				_flow_tween.tween_callback(queue_redraw)
	queue_redraw()

func _trigger_element_ignite() -> void:
	if tile_type in [
		ElectricEnums.TileType.BULB,
		ElectricEnums.TileType.HEATER,
		ElectricEnums.TileType.FAN,
		ElectricEnums.TileType.VACUUM_TUBE,
		ElectricEnums.TileType.TESLA_COIL
	]:
		var tw := create_tween()
		tw.tween_property(self, "bulb_scale_bounce", 1.25, 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "bulb_scale_bounce", 1.0, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if is_rotatable and not is_animating_rotation:
			rotate_clockwise()

func rotate_clockwise() -> void:
	is_animating_rotation = true
	current_rotation_step = (current_rotation_step + 1) % 4
	var target_rad := visual_rotation_rad + (PI / 2.0)
	
	var tw := create_tween()
	tw.set_parallel(true)
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "visual_rotation_rad", target_rad, 0.22)
	# Tactile physical click scale bounce
	tw.tween_property(self, "scale", Vector2(0.92, 0.92), 0.08).set_trans(Tween.TRANS_SINE)
	tw.chain().tween_property(self, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.finished.connect(func():
		visual_rotation_rad = current_rotation_step * (PI / 2.0)
		is_animating_rotation = false
		scale = Vector2.ONE
		queue_redraw()
	)
	
	tile_clicked.emit(grid_row, grid_col)

func apply_hint_rotation(correct_rot: int) -> void:
	current_rotation_step = correct_rot % 4
	is_animating_rotation = true
	var start_rot := visual_rotation_rad
	var end_rot := current_rotation_step * (PI / 2.0)
	if end_rot < start_rot:
		end_rot += TAU
	var tw := create_tween()
	tw.tween_property(self, "visual_rotation_rad", end_rot, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.finished.connect(func():
		visual_rotation_rad = current_rotation_step * (PI / 2.0)
		is_animating_rotation = false
		queue_redraw()
	)
	flash_hint_pulse()

func flash_hint_pulse() -> void:
	hint_highlight_alpha = 1.0
	var tw := create_tween()
	tw.tween_property(self, "hint_highlight_alpha", 0.0, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(self, "scale", Vector2(1.15, 1.15), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2.ONE, 0.18)

# -------------------------------------------------------------
# DRAWING PROCEDURAL HIGH-QUALITY GRAPHICS
# -------------------------------------------------------------
func _draw() -> void:
	if hint_highlight_alpha > 0.001:
		var h_rect := Rect2(1, 1, size.x - 2, size.y - 2)
		draw_rect(h_rect, Color(1.0, 0.85, 0.2, 0.3 * hint_highlight_alpha), true)
		draw_rect(h_rect, Color(1.0, 0.9, 0.3, hint_highlight_alpha), false, 3.5)
	var s := size
	var center := s * 0.5
	var r := Rect2(Vector2.ZERO, s)
	var radius := s.x * 0.15
	
	if tile_type == ElectricEnums.TileType.EMPTY:
		# Draw solid, high-visibility recessed module bay socket
		var bay_bg := Color(0.06, 0.09, 0.15, 1.0)
		var bay_border := Color(0.14, 0.22, 0.35, 1.0)
		draw_style_tile_plate(r, radius, bay_bg, bay_border)
		
		# Inner recessed socket tray
		var inner_slot := r.grow(-s.x * 0.18)
		draw_rounded_rect(inner_slot, radius * 0.6, Color(0.04, 0.06, 0.11, 1.0))
		draw_rounded_rect_outline(inner_slot, radius * 0.6, Color(0.08, 0.13, 0.22, 1.0), 1.5)
		
		# Diagonal heat-sink ventilation ribs across the recessed floor
		var rib_col := Color(0.10, 0.16, 0.26, 0.5)
		var rib_spacing := s.x * 0.14
		var slot_w := inner_slot.size.x
		var slot_h := inner_slot.size.y
		for i in range(-2, 5):
			var rx := inner_slot.position.x + float(i) * rib_spacing
			var p_start := Vector2(clampf(rx, inner_slot.position.x, inner_slot.end.x), inner_slot.position.y)
			var p_end := Vector2(clampf(rx + slot_h, inner_slot.position.x, inner_slot.end.x), inner_slot.end.y)
			if p_start != p_end:
				draw_line(p_start, p_end, rib_col, 1.5)
				
		# Center docking key receptacle
		var key_rad := s.x * 0.08
		draw_circle(center + Vector2(0, 1), key_rad + 1.5, Color(0.02, 0.03, 0.06, 0.8))
		draw_circle(center, key_rad, Color(0.12, 0.18, 0.28, 1.0))
		draw_circle(center, key_rad * 0.55, Color(0.04, 0.06, 0.10, 1.0))
		return
	
	# 1. Base Tile Plate (Tactile 2.5D Shaded PCB Module)
	var plate_bg := Color(0.13, 0.21, 0.38, 1.0)
	var plate_border := Color(0.24, 0.40, 0.65, 1.0)
	draw_style_tile_plate(r, radius, plate_bg, plate_border)
	
	# Draw internal contents rotated by visual_rotation_rad around center
	draw_set_transform(center, visual_rotation_rad, Vector2.ONE)
	
	var ports_base := custom_ports if custom_ports != 0 else ElectricEnums.get_base_ports(tile_type)
	draw_tile_contents(ports_base, s.x)
	
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func draw_style_tile_plate(rect: Rect2, corner_rad: float, bg_col: Color, border_col: Color) -> void:
	# 1. Multi-Stage Soft Drop Shadow
	var shadow_rect1 := rect.grow(-1.0)
	shadow_rect1.position.y += 4.5
	draw_rounded_rect(shadow_rect1, corner_rad + 1.0, Color(0.01, 0.02, 0.05, 0.45))
	
	var shadow_rect2 := rect.grow(-2.5)
	shadow_rect2.position.y += 2.5
	draw_rounded_rect(shadow_rect2, corner_rad, Color(0.02, 0.03, 0.08, 0.75))
	
	# 2. Outer 3D Bevel Rim (Shadow lip on bottom-right, light lip on top-left)
	var main_rect := rect.grow(-3.0)
	draw_rounded_rect(main_rect, corner_rad, Color(0.06, 0.09, 0.16, 1.0))
	
	# 3. Tactile Tile Body (Subtle vertical lighting gradient)
	var body_rect := main_rect.grow(-2.0)
	draw_rounded_rect(body_rect, corner_rad * 0.85, bg_col)
	
	# Top-half ambient specular sheen
	var top_sheen := Rect2(body_rect.position.x + 2, body_rect.position.y + 1, body_rect.size.x - 4, body_rect.size.y * 0.48)
	draw_rounded_rect(top_sheen, corner_rad * 0.7, Color(1.0, 1.0, 1.0, 0.09))
	
	# Bottom-half ambient shadow gradation
	var bot_shade := Rect2(body_rect.position.x + 2, body_rect.position.y + body_rect.size.y * 0.52, body_rect.size.x - 4, body_rect.size.y * 0.46)
	draw_rounded_rect(bot_shade, corner_rad * 0.7, Color(0.0, 0.0, 0.0, 0.10))
	
	# 4. Inset Hairline Bevel Outline
	draw_rounded_rect_outline(body_rect, corner_rad * 0.85, border_col, 1.8)
	draw_rounded_rect_outline(main_rect, corner_rad, Color(0.26, 0.42, 0.66, 0.9), 1.2)
	
	# 5. Corner Micro-Rivets / Screws (4 corners)
	var screw_inset := corner_rad * 0.68
	var screw_rad := 2.5
	var s_col := Color(0.65, 0.72, 0.82, 0.85)
	var s_glint := Color(1.0, 1.0, 1.0, 0.75)
	var screw_corners := [
		body_rect.position + Vector2(screw_inset, screw_inset),
		Vector2(body_rect.end.x - screw_inset, body_rect.position.y + screw_inset),
		Vector2(body_rect.end.x - screw_inset, body_rect.end.y - screw_inset),
		Vector2(body_rect.position.x + screw_inset, body_rect.end.y - screw_inset)
	]
	for sc in screw_corners:
		draw_circle(sc + Vector2(0, 0.8), screw_rad + 0.8, Color(0.03, 0.05, 0.09, 0.7))
		draw_circle(sc, screw_rad, s_col)
		draw_circle(sc + Vector2(-0.5, -0.5), screw_rad * 0.45, s_glint)

func get_active_color(ch: int) -> Color:
	return ElectricEnums.get_channel_color(ch, GameState.selected_theme)

func draw_contact_terminals(ports: int, half_w: float) -> void:
	var wire_radius := half_w * 0.16
	var casing_width := wire_radius * 2.3
	var term_rad := casing_width * 0.52
	var term_col := get_active_color(active_channel if is_powered else ElectricEnums.Channel.NONE)
	
	var port_dirs := [
		{"dir": ElectricEnums.DIR_UP, "pos": Vector2(0, -half_w)},
		{"dir": ElectricEnums.DIR_RIGHT, "pos": Vector2(half_w, 0)},
		{"dir": ElectricEnums.DIR_DOWN, "pos": Vector2(0, half_w)},
		{"dir": ElectricEnums.DIR_LEFT, "pos": Vector2(-half_w, 0)}
	]
	
	for pd in port_dirs:
		if (ports & pd["dir"]) == 0:
			continue
		var p: Vector2 = pd["pos"]
		
		# Dark rubber/insulator flange at tile seam
		draw_circle(p, term_rad + 2.0, Color(0.06, 0.08, 0.14, 1.0))
		# Outer metallic contact sleeve
		draw_circle(p, term_rad, Color(0.24, 0.32, 0.45, 1.0))
		
		# Inner contact pin
		if is_powered and current_flow_progress > 0.3:
			var pulse := (sin(bulb_pulse_timer * 3.5) + 1.0) * 0.5
			var glow_col := term_col
			glow_col.a = 0.5 + 0.3 * pulse
			draw_circle(p, term_rad * (1.2 + 0.2 * pulse), glow_col)
			draw_circle(p, term_rad * 0.7, term_col)
			draw_circle(p, term_rad * 0.35, Color.WHITE)
		else:
			# Polished brass/copper unpowered contact pad
			draw_circle(p, term_rad * 0.7, Color(0.82, 0.68, 0.35, 1.0))
			draw_circle(p, term_rad * 0.35, Color(0.45, 0.36, 0.18, 1.0))

func draw_tile_contents(ports: int, tile_w: float) -> void:
	var half_w := tile_w * 0.5
	var wire_col := get_active_color(active_channel if is_powered else ElectricEnums.Channel.NONE)
	
	match tile_type:
		ElectricEnums.TileType.WIRE_STRAIGHT, \
		ElectricEnums.TileType.WIRE_CORNER, \
		ElectricEnums.TileType.WIRE_TEE, \
		ElectricEnums.TileType.WIRE_CROSS:
			draw_wire_network(ports, half_w, wire_col)
			
		ElectricEnums.TileType.BATTERY:
			draw_battery(half_w, ports)
			
		ElectricEnums.TileType.BULB:
			draw_bulb(half_w, ports)

		ElectricEnums.TileType.SOLAR:
			draw_solar_panel(half_w, ports)

		ElectricEnums.TileType.RESISTOR:
			draw_resistor(half_w, ports)

		ElectricEnums.TileType.HEATER:
			draw_heater_element(half_w, ports)

		ElectricEnums.TileType.CAPACITOR:
			draw_capacitor(half_w, ports)

		ElectricEnums.TileType.FAN:
			draw_electric_fan(half_w, ports)

		ElectricEnums.TileType.VACUUM_TUBE:
			draw_vacuum_tube(half_w, ports)

		ElectricEnums.TileType.TESLA_COIL:
			draw_tesla_coil(half_w, ports)
			
		ElectricEnums.TileType.HOUSE_SMALL:
			draw_house_small(half_w, ports)
			
		ElectricEnums.TileType.HOUSE_BIG:
			draw_house_big(half_w, ports)
			
		ElectricEnums.TileType.BUILDING:
			draw_building(half_w, ports)
			
	# Seamless hardware coupling terminals at active ports
	draw_contact_terminals(ports, half_w)

# Helper: Draw a continuous straight conduit pipe segment with realistic high-voltage electric neon current
func draw_conduit_segment(p1: Vector2, p2: Vector2, half_w: float, color: Color, flow_offset: float) -> void:
	var wire_radius := half_w * 0.16
	var casing_width := wire_radius * 2.3
	var groove_w := wire_radius * 1.5
	var shadow_col := Color(0.03, 0.05, 0.1, 0.65)
	var casing_col := Color(0.12, 0.16, 0.24, 1.0)
	var groove_col := Color(0.06, 0.08, 0.14, 1.0)
	
	# Pass 1: Drop Shadow
	draw_line(p1 + Vector2(1, 2), p2 + Vector2(1, 2), shadow_col, casing_width, true)
	
	# Pass 2: Outer Conduit Casing (Smooth seamless metal line from edge to edge)
	draw_line(p1, p2, casing_col, casing_width, true)
	
	# 3D Cylindrical Specular Glint Ridge
	var seg_dir := (p2 - p1).normalized()
	var perp := Vector2(-seg_dir.y, seg_dir.x)
	draw_line(p1 - perp * (casing_width * 0.32), p2 - perp * (casing_width * 0.32), Color(0.35, 0.45, 0.62, 0.65), 1.2, true)
	draw_line(p1 + perp * (casing_width * 0.35), p2 + perp * (casing_width * 0.35), Color(0.04, 0.06, 0.10, 0.85), 1.2, true)
	
	# Pass 3: Inner Conduit Track
	draw_line(p1, p2, groove_col, groove_w, true)
	
	# Pass 4: Electric Current (Dynamic traveling fluid flow wave)
	if (is_powered or current_flow_progress > 0.001) and current_flow_progress > 0.001:
		var prog := clampf(current_flow_progress, 0.0, 1.0)
		var p_end_actual := p1 + (p2 - p1) * prog
		var pulse := (sin(bulb_pulse_timer * 3.5) + 1.0) * 0.5
		
		# 1. Wide ambient volumetric neon glow
		var glow_col := color
		glow_col.a = (0.32 + 0.16 * pulse) * clampf(prog * 1.4, 0.0, 1.0)
		var glow_width := casing_width * (1.8 + 0.25 * pulse)
		draw_line(p1, p_end_actual, glow_col, glow_width, true)
		
		# 2. Saturated vibrant electric plasma core
		var core_col := color
		core_col.a = 0.98 * clampf(prog * 1.4, 0.0, 1.0)
		var core_width := wire_radius * 1.35
		draw_line(p1, p_end_actual, core_col, core_width, true)
		
		# 3. Dynamic traveling electric current surges along the wire conduit
		var dir := (p2 - p1).normalized()
		var seg_len := (p_end_actual - p1).length()
		if seg_len > 1.0:
			var phase := fposmod(bulb_pulse_timer * 2.2 - flow_offset, 1.0)
			for k in range(2):
				var k_phase := fposmod(phase + float(k) * 0.5, 1.0)
				var surge_center := p1 + dir * (seg_len * k_phase)
				var surge_len := seg_len * 0.35
				var s_start := surge_center - dir * (surge_len * 0.5)
				var s_end := surge_center + dir * (surge_len * 0.5)
				var d_start := (s_start - p1).dot(dir)
				var d_end := (s_end - p1).dot(dir)
				if d_end > 0.0 and d_start < seg_len:
					var c_start := p1 + dir * clampf(d_start, 0.0, seg_len)
					var c_end := p1 + dir * clampf(d_end, 0.0, seg_len)
					draw_line(c_start, c_end, Color.WHITE.lerp(color, 0.3), core_width * 1.25, true)
		
		# 4. Pure white-hot electric core stream
		var hot_white := Color(1.0, 1.0, 1.0, 0.95 * clampf(prog * 1.4, 0.0, 1.0))
		var fil_w := wire_radius * (0.42 + 0.08 * pulse)
		draw_line(p1, p_end_actual, hot_white, fil_w, true)
		
		# 5. Electric Leading Spark Head (when current is actively surging forward)
		if prog < 0.98 and prog > 0.02:
			var spark_rad := wire_radius * 2.0
			draw_circle(p_end_actual, spark_rad * 1.4, Color(color.r, color.g, color.b, 0.55))
			draw_circle(p_end_actual, spark_rad * 0.8, color)
			draw_circle(p_end_actual, spark_rad * 0.45, Color.WHITE)
			var ortho := Vector2(-dir.y, dir.x)
			var jitter := sin(bulb_pulse_timer * 35.0) * spark_rad * 0.6
			draw_line(p_end_actual, p_end_actual + ortho * jitter + dir * (spark_rad * 0.8), Color.WHITE, 1.8)
			draw_line(p_end_actual, p_end_actual - ortho * jitter + dir * (spark_rad * 0.8), color, 1.8)
		
		# 6. High-frequency micro-spark jitter
		var spark_a := 0.4 + 0.3 * sin(bulb_pulse_timer * 20.0 + flow_offset * 3.0)
		draw_line(p1, p_end_actual, Color(1.0, 1.0, 1.0, spark_a), fil_w * 0.5, true)
	else:
		# Unpowered subtle dark inner track reflection
		var dim_col := Color(0.18, 0.22, 0.32, 0.35)
		draw_line(p1, p2, dim_col, wire_radius * 0.5, true)

# Helper: Draw a smooth curved corner conduit with traveling electric neon current
func draw_conduit_curve(p1: Vector2, p2: Vector2, half_w: float, color: Color, flow_offset: float) -> void:
	var wire_radius := half_w * 0.16
	var casing_width := wire_radius * 2.3
	var groove_w := wire_radius * 1.5
	var shadow_col := Color(0.03, 0.05, 0.1, 0.65)
	var casing_col := Color(0.12, 0.16, 0.24, 1.0)
	var groove_col := Color(0.06, 0.08, 0.14, 1.0)
	
	# Generate 13-point smooth curved bend
	var curve_pts := PackedVector2Array()
	var shadow_pts := PackedVector2Array()
	for i in range(13):
		var t := float(i) / 12.0
		# Quadratic bezier with control point at Vector2.ZERO
		var pt := (1.0 - t) * (1.0 - t) * p1 + 2.0 * (1.0 - t) * t * Vector2.ZERO + t * t * p2
		curve_pts.append(pt)
		shadow_pts.append(pt + Vector2(1, 2))
		
	# Pass 1: Drop Shadow
	draw_polyline(shadow_pts, shadow_col, casing_width)
	
	# Pass 2: Outer Conduit Casing
	draw_polyline(curve_pts, casing_col, casing_width)
	
	# 3D Cylindrical Glint on curve
	var glint_pts := PackedVector2Array()
	for pt in curve_pts:
		glint_pts.append(pt * 0.90)
	draw_polyline(glint_pts, Color(0.35, 0.45, 0.62, 0.65), 1.2)
	
	# Pass 3: Inner Track
	draw_polyline(curve_pts, groove_col, groove_w)
	
	# Pass 4: Electric Current (Dynamic traveling fluid flow wave around bend)
	if (is_powered or current_flow_progress > 0.001) and current_flow_progress > 0.001:
		var prog := clampf(current_flow_progress, 0.0, 1.0)
		var num_pts := maxi(2, int(ceil(prog * 12.0)) + 1)
		var energized_curve := curve_pts.slice(0, num_pts)
		var pulse := (sin(bulb_pulse_timer * 3.5) + 1.0) * 0.5
		
		# 1. Wide ambient volumetric neon glow
		var glow_col := color
		glow_col.a = (0.32 + 0.16 * pulse) * clampf(prog * 1.4, 0.0, 1.0)
		var glow_width := casing_width * (1.8 + 0.25 * pulse)
		draw_polyline(energized_curve, glow_col, glow_width)
		
		# 2. Saturated vibrant electric plasma core
		var core_col := color
		core_col.a = 0.98 * clampf(prog * 1.4, 0.0, 1.0)
		var core_width := wire_radius * 1.35
		draw_polyline(energized_curve, core_col, core_width)
		
		# 3. Dynamic traveling electric current surges gliding around the bend
		if energized_curve.size() >= 2:
			var phase := fposmod(bulb_pulse_timer * 2.2 - flow_offset, 1.0)
			for k in range(2):
				var k_phase := fposmod(phase + float(k) * 0.5, 1.0)
				var center_idx := int(k_phase * float(energized_curve.size() - 1))
				var sub_pts := PackedVector2Array()
				for idx in range(maxi(0, center_idx - 2), mini(energized_curve.size(), center_idx + 3)):
					sub_pts.append(energized_curve[idx])
				if sub_pts.size() >= 2:
					draw_polyline(sub_pts, Color.WHITE.lerp(color, 0.3), core_width * 1.25)
		
		# 4. Pure white-hot electric core stream
		var hot_white := Color(1.0, 1.0, 1.0, 0.95 * clampf(prog * 1.4, 0.0, 1.0))
		var fil_w := wire_radius * (0.42 + 0.08 * pulse)
		draw_polyline(energized_curve, hot_white, fil_w)
		
		# 5. Electric Leading Spark Head (around curve)
		if prog < 0.98 and prog > 0.02 and energized_curve.size() >= 2:
			var tip_pt := energized_curve[energized_curve.size() - 1]
			var spark_rad := wire_radius * 2.0
			draw_circle(tip_pt, spark_rad * 1.4, Color(color.r, color.g, color.b, 0.55))
			draw_circle(tip_pt, spark_rad * 0.8, color)
			draw_circle(tip_pt, spark_rad * 0.45, Color.WHITE)
		
		# 6. Micro-spark voltage jitter
		var spark_a := 0.4 + 0.3 * sin(bulb_pulse_timer * 20.0 + flow_offset * 3.0)
		draw_polyline(energized_curve, Color(1.0, 1.0, 1.0, spark_a), fil_w * 0.5)
	else:
		var dim_col := Color(0.18, 0.22, 0.32, 0.35)
		draw_polyline(curve_pts, dim_col, wire_radius * 0.5)

# Wire rendering with glowing high-voltage neon electric plasma flow
func draw_wire_network(ports: int, half_w: float, color: Color) -> void:
	var wire_radius := half_w * 0.16
	var center := Vector2.ZERO
	var flow_offset := float(grid_col + grid_row) * 0.45
	
	var p_up := (ports & ElectricEnums.DIR_UP) != 0
	var p_right := (ports & ElectricEnums.DIR_RIGHT) != 0
	var p_down := (ports & ElectricEnums.DIR_DOWN) != 0
	var p_left := (ports & ElectricEnums.DIR_LEFT) != 0
	var count := (1 if p_up else 0) + (1 if p_right else 0) + (1 if p_down else 0) + (1 if p_left else 0)
	
	# Determine local inlet port direction
	var inlet_local: int = 0
	if inlet_port_world != 0:
		inlet_local = ElectricEnums.rotate_mask_cw(inlet_port_world, (4 - current_rotation_step) % 4)
	
	var get_port_vec := func(d: int) -> Vector2:
		match d:
			ElectricEnums.DIR_UP: return Vector2(0, -half_w)
			ElectricEnums.DIR_RIGHT: return Vector2(half_w, 0)
			ElectricEnums.DIR_DOWN: return Vector2(0, half_w)
			ElectricEnums.DIR_LEFT: return Vector2(-half_w, 0)
		return Vector2.ZERO
	
	# Case 1: Straight Horizontal Wire
	if p_left and p_right and not p_up and not p_down:
		if inlet_local == ElectricEnums.DIR_RIGHT:
			draw_conduit_segment(Vector2(half_w, 0), Vector2(-half_w, 0), half_w, color, float(grid_col) * 0.5)
		else:
			draw_conduit_segment(Vector2(-half_w, 0), Vector2(half_w, 0), half_w, color, float(grid_col) * 0.5)
		return
		
	# Case 2: Straight Vertical Wire
	if p_up and p_down and not p_left and not p_right:
		if inlet_local == ElectricEnums.DIR_DOWN:
			draw_conduit_segment(Vector2(0, half_w), Vector2(0, -half_w), half_w, color, float(grid_row) * 0.5)
		else:
			draw_conduit_segment(Vector2(0, -half_w), Vector2(0, half_w), half_w, color, float(grid_row) * 0.5)
		return
		
	# Case 3: Corner Bends (Smooth 90-degree curved conduit)
	if count == 2:
		var d1 := 0
		var d2 := 0
		if p_up:
			if d1 == 0: d1 = ElectricEnums.DIR_UP
			else: d2 = ElectricEnums.DIR_UP
		if p_right:
			if d1 == 0: d1 = ElectricEnums.DIR_RIGHT
			else: d2 = ElectricEnums.DIR_RIGHT
		if p_down:
			if d1 == 0: d1 = ElectricEnums.DIR_DOWN
			else: d2 = ElectricEnums.DIR_DOWN
		if p_left:
			if d1 == 0: d1 = ElectricEnums.DIR_LEFT
			else: d2 = ElectricEnums.DIR_LEFT
		
		# If inlet port is d2, flow goes d2 -> d1. Otherwise flow goes d1 -> d2.
		if inlet_local == d2:
			draw_conduit_curve(get_port_vec.call(d2), get_port_vec.call(d1), half_w, color, flow_offset)
		else:
			draw_conduit_curve(get_port_vec.call(d1), get_port_vec.call(d2), half_w, color, flow_offset)
		return
			
	# Case 4: T-Junction (3 ports)
	if count == 3:
		var all_dirs := [ElectricEnums.DIR_UP, ElectricEnums.DIR_RIGHT, ElectricEnums.DIR_DOWN, ElectricEnums.DIR_LEFT]
		if inlet_local != 0 and (ports & inlet_local) != 0:
			# Surge flows from inlet into center, then branches out to other open ports
			draw_conduit_segment(get_port_vec.call(inlet_local), center, half_w, color, flow_offset)
			for d in all_dirs:
				if (ports & d) != 0 and d != inlet_local:
					draw_conduit_segment(center, get_port_vec.call(d), half_w, color, flow_offset)
		else:
			if not p_up:
				draw_conduit_segment(Vector2(-half_w, 0), Vector2(half_w, 0), half_w, color, flow_offset)
				draw_conduit_segment(center, Vector2(0, half_w), half_w, color, flow_offset)
			elif not p_down:
				draw_conduit_segment(Vector2(-half_w, 0), Vector2(half_w, 0), half_w, color, flow_offset)
				draw_conduit_segment(center, Vector2(0, -half_w), half_w, color, flow_offset)
			elif not p_left:
				draw_conduit_segment(Vector2(0, -half_w), Vector2(0, half_w), half_w, color, flow_offset)
				draw_conduit_segment(center, Vector2(half_w, 0), half_w, color, flow_offset)
			elif not p_right:
				draw_conduit_segment(Vector2(0, -half_w), Vector2(0, half_w), half_w, color, flow_offset)
				draw_conduit_segment(center, Vector2(-half_w, 0), half_w, color, flow_offset)
			
		# Compact junction collar at center
		var casing_width := wire_radius * 2.3
		var groove_w := wire_radius * 1.5
		draw_circle(center, casing_width * 0.52, Color(0.12, 0.16, 0.24, 1.0))
		draw_circle(center, groove_w * 0.52, Color(0.06, 0.08, 0.14, 1.0))
		if is_powered:
			var pulse := (sin(bulb_pulse_timer * 3.5) + 1.0) * 0.5
			var glow_col := color
			glow_col.a = 0.4 + 0.15 * pulse
			draw_circle(center, casing_width * (0.8 + 0.15 * pulse), glow_col)
			draw_circle(center, wire_radius * 0.9, color)
			draw_circle(center, wire_radius * 0.5, Color.WHITE)
		return
		
	# Case 5: 4-Way Cross
	if count == 4:
		var all_dirs := [ElectricEnums.DIR_UP, ElectricEnums.DIR_RIGHT, ElectricEnums.DIR_DOWN, ElectricEnums.DIR_LEFT]
		if inlet_local != 0 and (ports & inlet_local) != 0:
			draw_conduit_segment(get_port_vec.call(inlet_local), center, half_w, color, flow_offset)
			for d in all_dirs:
				if d != inlet_local:
					draw_conduit_segment(center, get_port_vec.call(d), half_w, color, flow_offset)
		else:
			draw_conduit_segment(Vector2(-half_w, 0), Vector2(half_w, 0), half_w, color, flow_offset)
			draw_conduit_segment(Vector2(0, -half_w), Vector2(0, half_w), half_w, color, flow_offset)
		var casing_width := wire_radius * 2.3
		var groove_w := wire_radius * 1.5
		draw_circle(center, casing_width * 0.55, Color(0.12, 0.16, 0.24, 1.0))
		draw_circle(center, groove_w * 0.55, Color(0.06, 0.08, 0.14, 1.0))
		if is_powered:
			var pulse := (sin(bulb_pulse_timer * 3.5) + 1.0) * 0.5
			var glow_col := color
			glow_col.a = 0.4 + 0.15 * pulse
			draw_circle(center, casing_width * (0.85 + 0.15 * pulse), glow_col)
			draw_circle(center, wire_radius * 0.95, color)
			draw_circle(center, wire_radius * 0.52, Color.WHITE)
		return
		
	# Case 6: Fallback for single stubs or other configurations
	var points: Array[Vector2] = []
	if p_up: points.append(Vector2(0, -half_w))
	if p_right: points.append(Vector2(half_w, 0))
	if p_down: points.append(Vector2(0, half_w))
	if p_left: points.append(Vector2(-half_w, 0))
	for p in points:
		if inlet_local != 0 and (ports & inlet_local) != 0:
			draw_conduit_segment(p, center, half_w, color, flow_offset)
		else:
			draw_conduit_segment(center, p, half_w, color, flow_offset)

# Battery rendering matching the 3D mobile look
func draw_battery(half_w: float, ports: int) -> void:
	var bat_w := half_w * 0.72
	var bat_h := half_w * 1.15
	var bat_col := get_active_color(channel)
	
	# Terminal leads connecting to all active port edges
	if (ports & ElectricEnums.DIR_UP) != 0:
		draw_conduit_segment(Vector2(0, -bat_h * 0.5), Vector2(0, -half_w), half_w, bat_col, 0.0)
		var pulse := (sin(bulb_pulse_timer * 2.0) + 1.0) * 0.5
		var spark_col := bat_col
		spark_col.a = 0.5 + 0.3 * pulse
		draw_arc(Vector2(0, -bat_h * 0.5), half_w * (0.16 + 0.06 * pulse), 0, TAU, 16, spark_col, 2.5)
	if (ports & ElectricEnums.DIR_DOWN) != 0:
		draw_conduit_segment(Vector2(0, bat_h * 0.5), Vector2(0, half_w), half_w, bat_col, 0.0)
		var pulse := (sin(bulb_pulse_timer * 2.0) + 1.0) * 0.5
		var spark_col := bat_col
		spark_col.a = 0.5 + 0.3 * pulse
		draw_arc(Vector2(0, bat_h * 0.5), half_w * (0.16 + 0.06 * pulse), 0, TAU, 16, spark_col, 2.5)
	if (ports & ElectricEnums.DIR_LEFT) != 0:
		draw_conduit_segment(Vector2(-bat_w * 0.5, 0), Vector2(-half_w, 0), half_w, bat_col, 0.0)
		var pulse := (sin(bulb_pulse_timer * 2.0) + 1.0) * 0.5
		var spark_col := bat_col
		spark_col.a = 0.5 + 0.3 * pulse
		draw_arc(Vector2(-bat_w * 0.5, 0), half_w * (0.16 + 0.06 * pulse), 0, TAU, 16, spark_col, 2.5)
	if (ports & ElectricEnums.DIR_RIGHT) != 0:
		draw_conduit_segment(Vector2(bat_w * 0.5, 0), Vector2(half_w, 0), half_w, bat_col, 0.0)
		var pulse := (sin(bulb_pulse_timer * 2.0) + 1.0) * 0.5
		var spark_col := bat_col
		spark_col.a = 0.5 + 0.3 * pulse
		draw_arc(Vector2(bat_w * 0.5, 0), half_w * (0.16 + 0.06 * pulse), 0, TAU, 16, spark_col, 2.5)
	
	# Battery cylinder shadow
	draw_rounded_rect(Rect2(-bat_w * 0.5 + 3, -bat_h * 0.5 + 4, bat_w, bat_h), 10.0, Color(0.04, 0.07, 0.12, 0.7))
	
	# Battery metallic casing base
	var metal_col := Color(0.75, 0.8, 0.86, 1.0)
	draw_rounded_rect(Rect2(-bat_w * 0.5, -bat_h * 0.5, bat_w, bat_h), 12.0, metal_col)
	
	# Battery colored jacket / label
	var jacket_margin := bat_h * 0.12
	var jacket_rect := Rect2(-bat_w * 0.5 + 2, -bat_h * 0.5 + jacket_margin, bat_w - 4, bat_h - (jacket_margin * 2))
	draw_rounded_rect(jacket_rect, 6.0, bat_col)
	
	# Lightning bolt symbol in center
	var bolt_pts := PackedVector2Array([
		Vector2(2, -bat_h * 0.22),
		Vector2(-bat_w * 0.22, 0),
		Vector2(-2, 0),
		Vector2(-4, bat_h * 0.22),
		Vector2(bat_w * 0.22, -2),
		Vector2(2, -2)
	])
	draw_colored_polygon(bolt_pts, Color(1.0, 1.0, 1.0, 0.95))
	
	# Cylinder top gloss shine
	var shine_rect := Rect2(-bat_w * 0.38, -bat_h * 0.5 + 4, bat_w * 0.25, bat_h - 8)
	draw_rounded_rect(shine_rect, 4.0, Color(1.0, 1.0, 1.0, 0.25))

# Ultra-Realistic 3D Pear-Shaped Incandescent Light Bulb with Edison Screw Base & Glowing Coiled Filament
func draw_bulb(half_w: float, ports: int) -> void:
	var bulb_col := get_active_color(channel if channel != ElectricEnums.Channel.NONE else ElectricEnums.Channel.CYAN)
	var wire_conn_col := bulb_col if is_powered else Color(0.18, 0.22, 0.3, 1.0)
	
	# Terminal conduit connections to connected tile ports
	var points: Array[Vector2] = []
	if (ports & ElectricEnums.DIR_UP) != 0:
		points.append(Vector2(0, -half_w))
	if (ports & ElectricEnums.DIR_RIGHT) != 0:
		points.append(Vector2(half_w, 0))
	if (ports & ElectricEnums.DIR_DOWN) != 0:
		points.append(Vector2(0, half_w))
	if (ports & ElectricEnums.DIR_LEFT) != 0:
		points.append(Vector2(-half_w, 0))
		
	for p in points:
		draw_conduit_segment(p, Vector2.ZERO, half_w, wire_conn_col, 0.0)

	var scale_factor := bulb_scale_bounce
	var bulb_center_y := -half_w * 0.10
	var bulb_dome_rad := half_w * 0.44 * scale_factor
	
	# -----------------------------------------------------------------
	# 1. EDISON BRASS SCREW BASE (Threaded socket collar at bottom)
	# -----------------------------------------------------------------
	var socket_top_y := bulb_center_y + bulb_dome_rad * 0.65
	var socket_w := half_w * 0.44 * scale_factor
	var socket_h := half_w * 0.40 * scale_factor
	
	# Socket drop shadow
	draw_rounded_rect(Rect2(-socket_w * 0.5 + 2, socket_top_y + 3, socket_w, socket_h), 5.0, Color(0.04, 0.07, 0.12, 0.65))
	
	# Brass socket body
	var brass_col := Color(0.78, 0.65, 0.32, 1.0)
	draw_rounded_rect(Rect2(-socket_w * 0.5, socket_top_y, socket_w, socket_h), 4.0, brass_col)
	
	# Realistic screw threads (grooved ridges)
	var thread_count := 4
	var thread_spacing := socket_h / float(thread_count + 1)
	for ti in range(thread_count):
		var ty := socket_top_y + float(ti + 1) * thread_spacing
		var tw := socket_w * 0.94
		draw_line(Vector2(-tw * 0.5, ty), Vector2(tw * 0.5, ty), Color(0.45, 0.34, 0.15, 1.0), 2.5)
		draw_line(Vector2(-tw * 0.5, ty - 1.5), Vector2(tw * 0.5, ty - 1.5), Color(0.95, 0.85, 0.5, 0.8), 1.5)
		
	# Black ceramic insulator contact tip at the bottom of the screw
	var tip_w := socket_w * 0.5
	var tip_h := socket_h * 0.22
	var tip_y := socket_top_y + socket_h - 2
	draw_rounded_rect(Rect2(-tip_w * 0.5, tip_y, tip_w, tip_h), 3.0, Color(0.1, 0.1, 0.12, 1.0))
	draw_circle(Vector2(0, tip_y + tip_h * 0.5), tip_w * 0.22, Color(0.85, 0.75, 0.4, 1.0))

	# -----------------------------------------------------------------
	# 2. PEAR-SHAPED 3D GLASS BULB SILHOUETTE
	# -----------------------------------------------------------------
	# Generate realistic pear/teardrop outline points
	var bulb_pts := PackedVector2Array()
	var neck_top_w := socket_w * 0.52
	var neck_top_y := socket_top_y + 1.0
	
	# Left neck upward
	bulb_pts.append(Vector2(-neck_top_w, neck_top_y))
	bulb_pts.append(Vector2(-neck_top_w * 0.95, bulb_center_y + bulb_dome_rad * 0.45))
	bulb_pts.append(Vector2(-bulb_dome_rad * 0.92, bulb_center_y + bulb_dome_rad * 0.15))
	
	# Upper spherical dome arc
	var dome_steps := 20
	for di in range(dome_steps + 1):
		var ang := -PI * 0.88 + (float(di) / float(dome_steps)) * (PI * 1.76)
		bulb_pts.append(Vector2(cos(ang) * bulb_dome_rad, bulb_center_y + sin(ang) * bulb_dome_rad))
		
	# Right neck downward
	bulb_pts.append(Vector2(bulb_dome_rad * 0.92, bulb_center_y + bulb_dome_rad * 0.15))
	bulb_pts.append(Vector2(neck_top_w * 0.95, bulb_center_y + bulb_dome_rad * 0.45))
	bulb_pts.append(Vector2(neck_top_w, neck_top_y))

	# Glass drop shadow
	var shadow_pts := PackedVector2Array()
	for pt in bulb_pts:
		shadow_pts.append(pt + Vector2(2, 4))
	draw_colored_polygon(shadow_pts, Color(0.04, 0.07, 0.12, 0.5))

	# -----------------------------------------------------------------
	# 3. POWERED INCANDESCENCE & RADIANT LIGHT BLOOM
	# -----------------------------------------------------------------
	if is_powered and current_flow_progress > 0.85:
		var pulse := (sin(bulb_pulse_timer) + 1.0) * 0.5
		var bloom_rad := bulb_dome_rad * (2.4 + 0.35 * pulse)
		
		# 4 volumetric radial glow halos
		for i in range(4):
			var r_step := lerpf(bulb_dome_rad * 1.1, bloom_rad, float(i + 1) / 4.0)
			var a_step := lerpf(0.38, 0.03, float(i + 1) / 4.0)
			var halo_col := bulb_col
			halo_col.a = a_step
			draw_circle(Vector2(0, bulb_center_y), r_step, halo_col)
		
		# Vibrant warm/channel tinted incandescent glass body
		var body_col := bulb_col.lerp(Color.WHITE, 0.45)
		body_col.a = 0.92
		draw_colored_polygon(bulb_pts, body_col)
		
		# Intense white-hot spherical core
		draw_circle(Vector2(0, bulb_center_y), bulb_dome_rad * 0.58, Color(1.0, 1.0, 1.0, 0.96))
		
		# Radiating 8-point sparkle starburst rays with glint tips
		var ray_count := 8
		for i in range(ray_count):
			var angle := (float(i) / float(ray_count)) * TAU + (bulb_pulse_timer * 0.15)
			var dir := Vector2(cos(angle), sin(angle))
			var ray_start := Vector2(0, bulb_center_y) + dir * (bulb_dome_rad * 0.9)
			var ray_len := bulb_dome_rad * (0.65 + 0.35 * sin(bulb_pulse_timer * 3.5 + i))
			var ray_col := Color(1.0, 1.0, 1.0, 0.8)
			draw_line(ray_start, ray_start + dir * ray_len, ray_col, 2.5, true)
			draw_circle(ray_start + dir * ray_len, 2.0, Color.WHITE)
	else:
		# -------------------------------------------------------------
		# UNPOWERED REALISTIC TINTED GLASS
		# -------------------------------------------------------------
		var dark_glass_col := Color(0.14, 0.20, 0.32, 0.88)
		draw_colored_polygon(bulb_pts, dark_glass_col)
		
		# Channel identification colored ring at base of glass
		var ring_col := bulb_col
		ring_col.a = 0.65
		draw_arc(Vector2(0, bulb_center_y + bulb_dome_rad * 0.4), bulb_dome_rad * 0.55, -0.4, PI + 0.4, 20, ring_col, 2.5)

	# -----------------------------------------------------------------
	# 4. INTERNAL GLASS STEM & TUNGSTEN COILED FILAMENT
	# -----------------------------------------------------------------
	# Glass stem mount rising from screw base
	var stem_col := Color(0.4, 0.5, 0.65, 0.65)
	var stem_rect := Rect2(-neck_top_w * 0.35, bulb_center_y + bulb_dome_rad * 0.18, neck_top_w * 0.7, bulb_dome_rad * 0.45)
	draw_rounded_rect(stem_rect, 3.0, stem_col)
	
	# Molybdenum lead wires branching upwards
	var lead_left_start := Vector2(-neck_top_w * 0.22, stem_rect.position.y + 4)
	var lead_left_top := Vector2(-bulb_dome_rad * 0.35, bulb_center_y - 2)
	var lead_right_start := Vector2(neck_top_w * 0.22, stem_rect.position.y + 4)
	var lead_right_top := Vector2(bulb_dome_rad * 0.35, bulb_center_y - 2)
	
	var moly_col := Color(0.7, 0.75, 0.85, 0.9) if is_powered else Color(0.35, 0.4, 0.48, 0.9)
	draw_line(lead_left_start, lead_left_top, moly_col, 1.8)
	draw_line(lead_right_start, lead_right_top, moly_col, 1.8)
	
	# Coiled tungsten filament bridge (hairpin/omega loop shape)
	var fil_steps := 12
	var fil_pts := PackedVector2Array()
	for fi in range(fil_steps + 1):
		var t := float(fi) / float(fil_steps)
		var fil_x := lerpf(lead_left_top.x, lead_right_top.x, t)
		var arch_y := bulb_center_y - (bulb_dome_rad * 0.36) * sin(t * PI)
		# Small curly zigzag vibration in tungsten coil
		var coil_wiggle := sin(t * 18.0) * 1.5
		fil_pts.append(Vector2(fil_x, arch_y + coil_wiggle))
		
	if is_powered and current_flow_progress > 0.85:
		# Ultra-bright white-hot glowing filament
		draw_polyline(fil_pts, Color(1.0, 0.6, 0.1, 1.0), 4.5)
		draw_polyline(fil_pts, Color(1.0, 1.0, 1.0, 1.0), 2.2)
	else:
		# Dark cold coiled tungsten wire
		draw_polyline(fil_pts, Color(0.28, 0.32, 0.38, 1.0), 2.0)

	# -----------------------------------------------------------------
	# 5. SPECULAR CURVED 3D GLASS HIGHLIGHTS (Curved reflections)
	# -----------------------------------------------------------------
	# Outer glass dome boundary contour
	draw_polyline(bulb_pts, Color(0.75, 0.85, 0.95, 0.55 if not is_powered else 0.85), 2.0)
	
	# Primary upper-left curved glass glare streak
	var glare_pts := PackedVector2Array()
	var glare_rad := bulb_dome_rad * 0.82
	var glare_center := Vector2(-2, bulb_center_y - 2)
	for gi in range(8):
		var ang := -PI * 0.82 + (float(gi) / 7.0) * (PI * 0.45)
		glare_pts.append(glare_center + Vector2(cos(ang) * glare_rad, sin(ang) * glare_rad))
	draw_polyline(glare_pts, Color(1.0, 1.0, 1.0, 0.65), 3.0)
	
	# Secondary soft bottom-right rim highlight
	var rim_pts := PackedVector2Array()
	for ri in range(6):
		var ang := 0.2 + (float(ri) / 5.0) * (PI * 0.35)
		rim_pts.append(Vector2(cos(ang) * (bulb_dome_rad * 0.84), bulb_center_y + sin(ang) * (bulb_dome_rad * 0.84)))
	draw_polyline(rim_pts, Color(1.0, 1.0, 1.0, 0.25), 2.0)

# Helper geometry drawers
# -------------------------------------------------------------
# SOLAR PANEL RENDERING
# -------------------------------------------------------------
func draw_solar_panel(half_w: float, ports: int) -> void:
	var sol_col := get_active_color(channel)
	var panel_w := half_w * 1.25
	var panel_h := half_w * 1.05
	
	# Terminal stubs connecting to connected edges
	var sol_wire_col := sol_col
	if (ports & ElectricEnums.DIR_UP) != 0:
		draw_conduit_segment(Vector2(0, -panel_h * 0.5), Vector2(0, -half_w), half_w, sol_wire_col, 0.0)
		var pulse := (sin(bulb_pulse_timer * 2.2) + 1.0) * 0.5
		var spark_col := sol_col
		spark_col.a = 0.5 + 0.35 * pulse
		draw_arc(Vector2(0, -panel_h * 0.5), half_w * (0.16 + 0.06 * pulse), 0, TAU, 16, spark_col, 2.5)
	if (ports & ElectricEnums.DIR_DOWN) != 0:
		draw_conduit_segment(Vector2(0, panel_h * 0.5), Vector2(0, half_w), half_w, sol_wire_col, 0.0)
		var pulse := (sin(bulb_pulse_timer * 2.2) + 1.0) * 0.5
		var spark_col := sol_col
		spark_col.a = 0.5 + 0.35 * pulse
		draw_arc(Vector2(0, panel_h * 0.5), half_w * (0.16 + 0.06 * pulse), 0, TAU, 16, spark_col, 2.5)
	if (ports & ElectricEnums.DIR_RIGHT) != 0:
		draw_conduit_segment(Vector2(panel_w * 0.5, 0), Vector2(half_w, 0), half_w, sol_wire_col, 0.0)
	if (ports & ElectricEnums.DIR_LEFT) != 0:
		draw_conduit_segment(Vector2(-panel_w * 0.5, 0), Vector2(-half_w, 0), half_w, sol_wire_col, 0.0)

	# Drop shadow
	draw_rounded_rect(Rect2(-panel_w * 0.5 + 3, -panel_h * 0.5 + 4, panel_w, panel_h), 8.0, Color(0.04, 0.07, 0.12, 0.7))
	
	# Aluminum outer frame
	var frame_rect := Rect2(-panel_w * 0.5, -panel_h * 0.5, panel_w, panel_h)
	draw_rounded_rect(frame_rect, 8.0, Color(0.72, 0.78, 0.88, 1.0))
	draw_rounded_rect_outline(frame_rect, 8.0, Color(0.45, 0.52, 0.62, 1.0), 2.0)
	
	# Silicon wafer surface (deep solar blue)
	var silicon_rect := Rect2(-panel_w * 0.5 + 4, -panel_h * 0.5 + 4, panel_w - 8, panel_h - 8)
	draw_rounded_rect(silicon_rect, 5.0, Color(0.07, 0.14, 0.28, 1.0))
	
	# Solar cells division (2 rows x 3 columns)
	var cell_w := silicon_rect.size.x / 3.0
	var cell_h := silicon_rect.size.y / 2.0
	var busbar_col := Color(0.35, 0.55, 0.8, 0.6)
	
	for col_i in range(1, 3):
		var gx := silicon_rect.position.x + col_i * cell_w
		draw_line(Vector2(gx, silicon_rect.position.y), Vector2(gx, silicon_rect.end.y), busbar_col, 1.5)
	var gy := silicon_rect.position.y + cell_h
	draw_line(Vector2(silicon_rect.position.x, gy), Vector2(silicon_rect.end.x, gy), busbar_col, 1.5)
	
	# Fine conductive fingers inside cells
	var finger_col := Color(0.2, 0.35, 0.55, 0.4)
	for col_i in range(3):
		for row_i in range(2):
			var cx := silicon_rect.position.x + col_i * cell_w
			var cy := silicon_rect.position.y + row_i * cell_h
			draw_line(Vector2(cx + 4, cy + cell_h * 0.33), Vector2(cx + cell_w - 4, cy + cell_h * 0.33), finger_col, 1.0)
			draw_line(Vector2(cx + 4, cy + cell_h * 0.67), Vector2(cx + cell_w - 4, cy + cell_h * 0.67), finger_col, 1.0)

	# Sun glare shimmer sweep across panel
	var sweep := fposmod(bulb_pulse_timer * 0.6, 2.5) - 0.7
	var sweep_x := silicon_rect.position.x + silicon_rect.size.x * sweep
	var glare_p1 := Vector2(sweep_x - 12, silicon_rect.position.y)
	var glare_p2 := Vector2(sweep_x + 12, silicon_rect.position.y)
	var glare_p3 := Vector2(sweep_x + 24, silicon_rect.end.y)
	var glare_p4 := Vector2(sweep_x, silicon_rect.end.y)
	draw_colored_polygon(PackedVector2Array([glare_p1, glare_p2, glare_p3, glare_p4]), Color(1.0, 1.0, 1.0, 0.15))

	# Center Solar Crest / Sun symbol
	var sun_rad := half_w * 0.16
	draw_circle(Vector2.ZERO, sun_rad * 1.3, Color(0.05, 0.1, 0.2, 0.7))
	draw_circle(Vector2.ZERO, sun_rad, sol_col)
	draw_circle(Vector2.ZERO, sun_rad * 0.6, Color.WHITE)
	for i in range(8):
		var ang := float(i) * TAU / 8.0 + (bulb_pulse_timer * 0.4)
		var dir := Vector2(cos(ang), sin(ang))
		draw_line(dir * (sun_rad * 1.2), dir * (sun_rad * 1.65), sol_col, 2.0)

# -------------------------------------------------------------
# RESISTOR RENDERING
# -------------------------------------------------------------
func draw_resistor(half_w: float, ports: int) -> void:
	var res_col := get_active_color(active_channel if is_powered else channel)
	var lead_col := res_col if is_powered else Color(0.55, 0.6, 0.68, 1.0)
	
	var points: Array[Vector2] = []
	if (ports & ElectricEnums.DIR_UP) != 0:
		points.append(Vector2(0, -half_w))
	if (ports & ElectricEnums.DIR_DOWN) != 0:
		points.append(Vector2(0, half_w))
	if (ports & ElectricEnums.DIR_LEFT) != 0:
		points.append(Vector2(-half_w, 0))
	if (ports & ElectricEnums.DIR_RIGHT) != 0:
		points.append(Vector2(half_w, 0))
		
	for p in points:
		draw_conduit_segment(p, Vector2.ZERO, half_w, lead_col, 0.0)

	var res_w := half_w * 0.46
	var res_h := half_w * 1.05
	
	# Drop shadow
	draw_rounded_rect(Rect2(-res_w * 0.5 + 3, -res_h * 0.5 + 4, res_w, res_h), 12.0, Color(0.04, 0.07, 0.12, 0.6))
	
	# Ceramic dogbone body
	var body_col := Color(0.88, 0.83, 0.74, 1.0)
	draw_rounded_rect(Rect2(-res_w * 0.5, -res_h * 0.5, res_w, res_h), 12.0, body_col)
	
	# Metallic endcaps
	var cap_h := res_h * 0.16
	var cap_col := Color(0.7, 0.74, 0.82, 1.0)
	draw_rounded_rect(Rect2(-res_w * 0.5, -res_h * 0.5, res_w, cap_h), 6.0, cap_col)
	draw_rounded_rect(Rect2(-res_w * 0.5, res_h * 0.5 - cap_h, res_w, cap_h), 6.0, cap_col)
	
	# 4 Color code bands
	var band_h := res_h * 0.09
	var band_colors: Array[Color] = [
		Color(0.5, 0.28, 0.12, 1.0), # Brown
		Color(0.9, 0.18, 0.18, 1.0), # Red
		res_col if active_channel != ElectricEnums.Channel.NONE else Color(0.95, 0.55, 0.1, 1.0),
		Color(0.85, 0.72, 0.22, 1.0)  # Gold
	]
	var band_y_offsets: Array[float] = [
		-res_h * 0.25,
		-res_h * 0.10,
		res_h * 0.05,
		res_h * 0.24
	]
	
	for i in range(4):
		var by: float = band_y_offsets[i]
		var b_col: Color = band_colors[i]
		var band_rect := Rect2(-res_w * 0.5 + 1, by, res_w - 2, band_h)
		draw_rect(band_rect, b_col)
		draw_rect(Rect2(-res_w * 0.35, by, res_w * 0.25, band_h), Color(1.0, 1.0, 1.0, 0.25))

	# 3D gloss shine
	draw_rounded_rect(Rect2(-res_w * 0.35, -res_h * 0.48, res_w * 0.22, res_h * 0.96), 4.0, Color(1.0, 1.0, 1.0, 0.2))

	# Powered thermal dissipation glow
	if is_powered:
		var pulse := (sin(bulb_pulse_timer * 1.5) + 1.0) * 0.5
		var heat_col := res_col
		heat_col.a = 0.28 + 0.18 * pulse
		draw_rounded_rect(Rect2(-res_w * 0.65, -res_h * 0.55, res_w * 1.3, res_h * 1.1), 16.0, heat_col)

# -------------------------------------------------------------
# ELECTRIC HEATER ELEMENT RENDERING
# -------------------------------------------------------------
func draw_heater_element(half_w: float, ports: int) -> void:
	var heater_col := get_active_color(active_channel if is_powered else channel)
	if not is_powered and channel == ElectricEnums.Channel.NONE:
		heater_col = Color(0.4, 0.45, 0.55, 1.0)
		
	var points: Array[Vector2] = []
	if (ports & ElectricEnums.DIR_UP) != 0:
		points.append(Vector2(0, -half_w))
	if (ports & ElectricEnums.DIR_DOWN) != 0:
		points.append(Vector2(0, half_w))
	if (ports & ElectricEnums.DIR_LEFT) != 0:
		points.append(Vector2(-half_w, 0))
	if (ports & ElectricEnums.DIR_RIGHT) != 0:
		points.append(Vector2(half_w, 0))
		
	var lead_col := heater_col if is_powered else Color(0.18, 0.22, 0.28, 1.0)
	for p in points:
		draw_conduit_segment(p, Vector2.ZERO, half_w, lead_col, 0.0)

	var plate_rad := half_w * 0.58 * bulb_scale_bounce
	
	# Ceramic burner plate
	draw_circle(Vector2(2, 4), plate_rad, Color(0.04, 0.07, 0.12, 0.6))
	draw_circle(Vector2.ZERO, plate_rad, Color(0.16, 0.2, 0.26, 1.0))
	draw_arc(Vector2.ZERO, plate_rad, 0, TAU, 32, Color(0.35, 0.42, 0.5, 1.0), 3.0)
	draw_arc(Vector2.ZERO, plate_rad * 0.88, 0, TAU, 32, Color(0.1, 0.13, 0.18, 1.0), 2.0)
	
	var coil_radii: Array[float] = [plate_rad * 0.72, plate_rad * 0.5, plate_rad * 0.28]
	
	if is_powered:
		var pulse := (sin(bulb_pulse_timer) + 1.0) * 0.5
		var thermal_col := Color(1.0, 0.35, 0.08, 0.3 + 0.15 * pulse)
		draw_circle(Vector2.ZERO, plate_rad * (1.3 + 0.15 * pulse), thermal_col)
		
		var fire_hot := Color(1.0, 0.45, 0.1, 1.0)
		var core_hot := Color(1.0, 0.95, 0.5, 1.0)
		
		for cr in coil_radii:
			draw_arc(Vector2.ZERO, cr, 0, TAU, 28, Color(1.0, 0.25, 0.05, 0.6), half_w * 0.16)
			draw_arc(Vector2.ZERO, cr, 0, TAU, 28, fire_hot, half_w * 0.10)
			draw_arc(Vector2.ZERO, cr, 0, TAU, 28, core_hot, half_w * 0.04)
			
		draw_circle(Vector2.ZERO, plate_rad * 0.16, Color(1.0, 0.9, 0.6, 1.0))
		
		var wave_phase := fposmod(bulb_pulse_timer * 1.5, 1.0)
		var wave_rad := lerpf(plate_rad * 0.5, plate_rad * 1.5, wave_phase)
		var wave_alpha := (1.0 - wave_phase) * 0.4
		draw_arc(Vector2.ZERO, wave_rad, 0, TAU, 24, Color(1.0, 0.6, 0.1, wave_alpha), 2.0)
	else:
		var cold_coil := Color(0.3, 0.34, 0.4, 1.0)
		for cr in coil_radii:
			draw_arc(Vector2.ZERO, cr, 0, TAU, 28, Color(0.08, 0.1, 0.14, 1.0), half_w * 0.11)
			draw_arc(Vector2.ZERO, cr, 0, TAU, 28, cold_coil, half_w * 0.07)
		draw_circle(Vector2.ZERO, plate_rad * 0.14, Color(0.22, 0.26, 0.32, 1.0))

# -------------------------------------------------------------
# CAPACITOR RENDERING
# -------------------------------------------------------------
func draw_capacitor(half_w: float, ports: int) -> void:
	var cap_col := get_active_color(active_channel if is_powered else channel)
	var lead_col := cap_col if is_powered else Color(0.55, 0.6, 0.68, 1.0)
	
	var points: Array[Vector2] = []
	if (ports & ElectricEnums.DIR_UP) != 0:
		points.append(Vector2(0, -half_w))
	if (ports & ElectricEnums.DIR_DOWN) != 0:
		points.append(Vector2(0, half_w))
	if (ports & ElectricEnums.DIR_LEFT) != 0:
		points.append(Vector2(-half_w, 0))
	if (ports & ElectricEnums.DIR_RIGHT) != 0:
		points.append(Vector2(half_w, 0))
		
	for p in points:
		draw_conduit_segment(p, Vector2.ZERO, half_w, lead_col, 0.0)

	var cap_rad := half_w * 0.48
	
	draw_circle(Vector2(2, 4), cap_rad, Color(0.04, 0.07, 0.12, 0.6))
	
	var can_col := Color(0.72, 0.78, 0.86, 1.0)
	draw_circle(Vector2.ZERO, cap_rad, can_col)
	
	draw_arc(Vector2.ZERO, cap_rad * 0.94, 0, TAU, 32, Color(0.12, 0.18, 0.28, 1.0), 3.5)
	
	var vent_col := Color(0.45, 0.5, 0.58, 1.0)
	draw_line(Vector2(-cap_rad * 0.55, 0), Vector2(cap_rad * 0.55, 0), vent_col, 2.0)
	draw_line(Vector2(0, -cap_rad * 0.55), Vector2(0, cap_rad * 0.55), vent_col, 2.0)
	
	var stripe_col := Color(0.1, 0.15, 0.25, 0.9)
	draw_arc(Vector2.ZERO, cap_rad * 0.72, -PI * 0.35, PI * 0.35, 16, stripe_col, 5.0)
	draw_line(Vector2(cap_rad * 0.72 - 3, -4), Vector2(cap_rad * 0.72 + 3, -4), Color.WHITE, 1.5)
	draw_line(Vector2(cap_rad * 0.72 - 3, 4), Vector2(cap_rad * 0.72 + 3, 4), Color.WHITE, 1.5)

	if is_powered:
		var pulse := (sin(bulb_pulse_timer * 2.0) + 1.0) * 0.5
		var halo_col := cap_col
		halo_col.a = 0.35 + 0.25 * pulse
		draw_circle(Vector2.ZERO, cap_rad * (1.25 + 0.15 * pulse), halo_col)
		draw_circle(Vector2.ZERO, cap_rad * 0.35, Color(1.0, 1.0, 1.0, 0.9))

# -------------------------------------------------------------
# ELECTRIC FAN / COOLING MOTOR RENDERING
# -------------------------------------------------------------
func draw_electric_fan(half_w: float, ports: int) -> void:
	var fan_col := get_active_color(active_channel if is_powered else channel)
	var lead_col := fan_col if is_powered else Color(0.18, 0.22, 0.28, 1.0)
	
	# Terminal leads
	var points: Array[Vector2] = []
	if (ports & ElectricEnums.DIR_UP) != 0:
		points.append(Vector2(0, -half_w))
	if (ports & ElectricEnums.DIR_DOWN) != 0:
		points.append(Vector2(0, half_w))
	if (ports & ElectricEnums.DIR_LEFT) != 0:
		points.append(Vector2(-half_w, 0))
	if (ports & ElectricEnums.DIR_RIGHT) != 0:
		points.append(Vector2(half_w, 0))
		
	for p in points:
		draw_conduit_segment(p, Vector2.ZERO, half_w, lead_col, 0.0)

	var fan_rad := half_w * 0.58 * bulb_scale_bounce
	
	# Fan outer frame / casing (square bezel with rounded corners)
	var frame_size := fan_rad * 1.85
	var frame_rect := Rect2(-frame_size * 0.5, -frame_size * 0.5, frame_size, frame_size)
	draw_rounded_rect(Rect2(-frame_size * 0.5 + 2, -frame_size * 0.5 + 4, frame_size, frame_size), 10.0, Color(0.04, 0.07, 0.12, 0.6))
	draw_rounded_rect(frame_rect, 10.0, Color(0.14, 0.18, 0.26, 1.0))
	draw_rounded_rect_outline(frame_rect, 10.0, Color(0.28, 0.35, 0.46, 1.0), 2.0)
	
	# Corner mounting screws
	var screw_offset := frame_size * 0.4
	var screw_rad := frame_size * 0.045
	var screw_pts := [
		Vector2(-screw_offset, -screw_offset),
		Vector2(screw_offset, -screw_offset),
		Vector2(screw_offset, screw_offset),
		Vector2(-screw_offset, screw_offset)
	]
	for sp in screw_pts:
		draw_circle(sp, screw_rad, Color(0.55, 0.6, 0.7, 1.0))
		draw_line(sp + Vector2(-screw_rad * 0.6, 0), sp + Vector2(screw_rad * 0.6, 0), Color(0.1, 0.15, 0.2, 1.0), 1.0)

	# Circular intake tunnel
	draw_circle(Vector2.ZERO, fan_rad, Color(0.07, 0.09, 0.14, 1.0))
	draw_arc(Vector2.ZERO, fan_rad, 0, TAU, 32, Color(0.25, 0.32, 0.42, 1.0), 2.5)
	
	# Concentric safety wire grille
	draw_arc(Vector2.ZERO, fan_rad * 0.72, 0, TAU, 28, Color(0.2, 0.26, 0.35, 0.6), 1.2)
	draw_arc(Vector2.ZERO, fan_rad * 0.45, 0, TAU, 24, Color(0.2, 0.26, 0.35, 0.6), 1.2)
	
	# Fan blades
	var blade_count := 4
	var base_angle := bulb_pulse_timer if is_powered else 0.0
	var blade_len := fan_rad * 0.88
	var blade_col := Color(0.32, 0.4, 0.52, 1.0)
	
	# When powered: draw motion blur trails
	if is_powered:
		for b in range(blade_count):
			var ang := base_angle + float(b) * TAU / float(blade_count)
			for trail_i in range(3):
				var t_ang := ang - float(trail_i + 1) * 0.18
				var trail_pts := PackedVector2Array([
					Vector2(cos(t_ang) * (fan_rad * 0.2), sin(t_ang) * (fan_rad * 0.2)),
					Vector2(cos(t_ang + 0.3) * blade_len, sin(t_ang + 0.3) * blade_len),
					Vector2(cos(t_ang - 0.1) * blade_len, sin(t_ang - 0.1) * blade_len)
				])
				draw_colored_polygon(trail_pts, Color(fan_col.r, fan_col.g, fan_col.b, 0.12 / float(trail_i + 1)))

	# Sharp main blades
	for b in range(blade_count):
		var ang := base_angle + float(b) * TAU / float(blade_count)
		var p_root1 := Vector2(cos(ang - 0.35) * (fan_rad * 0.22), sin(ang - 0.35) * (fan_rad * 0.22))
		var p_root2 := Vector2(cos(ang + 0.35) * (fan_rad * 0.22), sin(ang + 0.35) * (fan_rad * 0.22))
		var p_tip1 := Vector2(cos(ang + 0.45) * blade_len, sin(ang + 0.45) * blade_len)
		var p_tip2 := Vector2(cos(ang - 0.15) * (blade_len * 0.95), sin(ang - 0.15) * (blade_len * 0.95))
		
		var blade_poly := PackedVector2Array([p_root1, p_tip2, p_tip1, p_root2])
		draw_colored_polygon(blade_poly, blade_col)
		draw_line(p_root2, p_tip1, Color(1.0, 1.0, 1.0, 0.25), 1.5)

	# Center motor hub
	var hub_rad := fan_rad * 0.32
	draw_circle(Vector2.ZERO, hub_rad, Color(0.18, 0.22, 0.3, 1.0))
	draw_circle(Vector2.ZERO, hub_rad * 0.85, Color(0.65, 0.7, 0.78, 1.0))
	
	if is_powered:
		# Center glowing active motor status LED
		draw_circle(Vector2.ZERO, hub_rad * 0.5, fan_col)
		draw_circle(Vector2.ZERO, hub_rad * 0.25, Color.WHITE)
		
		# Swirling wind vortex arcs around the fan
		var vortex_ang := base_angle * 1.5
		draw_arc(Vector2.ZERO, fan_rad * 1.08, vortex_ang, vortex_ang + PI * 0.6, 16, Color(0.7, 0.9, 1.0, 0.35), 2.0)
		draw_arc(Vector2.ZERO, fan_rad * 1.15, vortex_ang + PI, vortex_ang + PI * 1.6, 16, Color(0.7, 0.9, 1.0, 0.35), 2.0)
	else:
		draw_circle(Vector2.ZERO, hub_rad * 0.45, Color(0.2, 0.25, 0.32, 1.0))

# -------------------------------------------------------------
# VACUUM TUBE / VINTAGE VALVE RENDERING
# -------------------------------------------------------------
func draw_vacuum_tube(half_w: float, ports: int) -> void:
	var tube_col := get_active_color(active_channel if is_powered else channel)
	if not is_powered and channel == ElectricEnums.Channel.NONE:
		tube_col = Color(0.95, 0.55, 0.15, 1.0)
		
	# Terminal leads
	var points: Array[Vector2] = []
	if (ports & ElectricEnums.DIR_UP) != 0:
		points.append(Vector2(0, -half_w))
	if (ports & ElectricEnums.DIR_DOWN) != 0:
		points.append(Vector2(0, half_w))
	if (ports & ElectricEnums.DIR_LEFT) != 0:
		points.append(Vector2(-half_w, 0))
	if (ports & ElectricEnums.DIR_RIGHT) != 0:
		points.append(Vector2(half_w, 0))
		
	var lead_col := tube_col if is_powered else Color(0.2, 0.25, 0.32, 1.0)
	for p in points:
		draw_conduit_segment(p, Vector2.ZERO, half_w, lead_col, 0.0)

	var tube_w := half_w * 0.58 * bulb_scale_bounce
	var tube_h := half_w * 1.18 * bulb_scale_bounce
	
	# Drop shadow
	draw_rounded_rect(Rect2(-tube_w * 0.5 + 3, -tube_h * 0.5 + 4, tube_w, tube_h), tube_w * 0.45, Color(0.04, 0.07, 0.12, 0.6))
	
	# Bakelite black octal base at bottom
	var base_h := tube_h * 0.22
	var base_rect := Rect2(-tube_w * 0.52, tube_h * 0.5 - base_h, tube_w * 1.04, base_h)
	draw_rounded_rect(base_rect, 5.0, Color(0.12, 0.1, 0.08, 1.0))
	draw_line(Vector2(-tube_w * 0.48, tube_h * 0.5 - base_h), Vector2(tube_w * 0.48, tube_h * 0.5 - base_h), Color(0.7, 0.6, 0.35, 1.0), 2.0)
	
	# Glass dome envelope
	var glass_h := tube_h - base_h + 2.0
	var glass_rect := Rect2(-tube_w * 0.5, -tube_h * 0.5, tube_w, glass_h)
	draw_rounded_rect(glass_rect, tube_w * 0.48, Color(0.15, 0.2, 0.3, 0.45))
	
	# Warm thermionic vacuum glow cloud when powered
	if is_powered:
		var pulse := (sin(bulb_pulse_timer) + 1.0) * 0.5
		var glow_rad := tube_w * (1.1 + 0.15 * pulse)
		var halo_col := tube_col
		halo_col.a = 0.28 + 0.12 * pulse
		draw_circle(Vector2(0, -tube_h * 0.08), glow_rad, halo_col)
		
		# Inner amber vacuum heat
		var amber_col := Color(1.0, 0.55, 0.1, 0.35 + 0.15 * pulse)
		draw_rounded_rect(glass_rect.grow(-4.0), tube_w * 0.4, amber_col)

	# Internal metal anode cage plate
	var plate_w := tube_w * 0.58
	var plate_h := glass_h * 0.55
	var plate_rect := Rect2(-plate_w * 0.5, -tube_h * 0.35, plate_w, plate_h)
	draw_rounded_rect(plate_rect, 4.0, Color(0.25, 0.28, 0.35, 0.85))
	draw_rounded_rect_outline(plate_rect, 4.0, Color(0.4, 0.46, 0.55, 0.9), 1.5)
	
	for vh in range(3):
		var vy := plate_rect.position.y + plate_h * (0.25 + float(vh) * 0.25)
		draw_circle(Vector2(0, vy), plate_w * 0.15, Color(0.08, 0.1, 0.15, 0.9))

	# Center glowing filament (cathode heater)
	var fil_top := -tube_h * 0.28
	var fil_bot := plate_rect.end.y - 4
	if is_powered:
		var fil_col := Color(1.0, 0.6, 0.15, 1.0)
		var fil_hot := Color(1.0, 0.95, 0.8, 1.0)
		var fil_pts := PackedVector2Array([
			Vector2(-4, fil_bot),
			Vector2(-4, fil_top),
			Vector2(0, fil_top - 3),
			Vector2(4, fil_top),
			Vector2(4, fil_bot)
		])
		draw_polyline(fil_pts, fil_col, 3.5)
		draw_polyline(fil_pts, fil_hot, 1.5)
	else:
		var fil_pts := PackedVector2Array([
			Vector2(-3, fil_bot),
			Vector2(-3, fil_top),
			Vector2(0, fil_top - 2),
			Vector2(3, fil_top),
			Vector2(3, fil_bot)
		])
		draw_polyline(fil_pts, Color(0.35, 0.38, 0.45, 1.0), 1.5)

	# Top "getter" mirrored chrome flash
	var getter_rect := Rect2(-tube_w * 0.38, -tube_h * 0.5 + 3, tube_w * 0.76, tube_h * 0.14)
	draw_rounded_rect(getter_rect, tube_w * 0.3, Color(0.85, 0.88, 0.96, 0.55))
	
	# Glass outline and 3D reflection
	draw_rounded_rect_outline(glass_rect, tube_w * 0.48, Color(0.65, 0.75, 0.9, 0.55), 2.0)
	var spec_rect := Rect2(-tube_w * 0.38, -tube_h * 0.46, tube_w * 0.16, glass_h * 0.72)
	draw_rounded_rect(spec_rect, 4.0, Color(1.0, 1.0, 1.0, 0.28))

# -------------------------------------------------------------
# TESLA COIL / ELECTRIC SPARK GAP RENDERING
# -------------------------------------------------------------
func draw_tesla_coil(half_w: float, ports: int) -> void:
	var tesla_col := get_active_color(active_channel if is_powered else channel)
	if not is_powered and channel == ElectricEnums.Channel.NONE:
		tesla_col = Color(0.0, 0.88, 1.0, 1.0)
		
	# Terminal leads
	var points: Array[Vector2] = []
	if (ports & ElectricEnums.DIR_UP) != 0:
		points.append(Vector2(0, -half_w))
	if (ports & ElectricEnums.DIR_DOWN) != 0:
		points.append(Vector2(0, half_w))
	if (ports & ElectricEnums.DIR_LEFT) != 0:
		points.append(Vector2(-half_w, 0))
	if (ports & ElectricEnums.DIR_RIGHT) != 0:
		points.append(Vector2(half_w, 0))
		
	var lead_col := tesla_col if is_powered else Color(0.2, 0.25, 0.32, 1.0)
	for p in points:
		draw_conduit_segment(p, Vector2.ZERO, half_w, lead_col, 0.0)

	var coil_w := half_w * 0.42
	var coil_h := half_w * 0.78
	var toroid_y := -half_w * 0.48
	
	# Drop shadow
	draw_rounded_rect(Rect2(-coil_w * 0.8 + 2, half_w * 0.25 + 3, coil_w * 1.6, half_w * 0.2), 6.0, Color(0.04, 0.07, 0.12, 0.6))
	
	# Insulated base stand
	var base_rect := Rect2(-coil_w * 0.75, half_w * 0.25, coil_w * 1.5, half_w * 0.18)
	draw_rounded_rect(base_rect, 6.0, Color(0.15, 0.18, 0.25, 1.0))
	draw_rounded_rect_outline(base_rect, 6.0, Color(0.35, 0.4, 0.5, 1.0), 1.5)
	
	# Vertical secondary coil cylinder
	var coil_rect := Rect2(-coil_w * 0.5, toroid_y + 12, coil_w, coil_h)
	draw_rounded_rect(coil_rect, 6.0, Color(0.2, 0.12, 0.08, 1.0))
	
	# Copper wire turns
	var turn_count := 9
	var turn_h := coil_h / float(turn_count)
	for ti in range(turn_count):
		var ty := coil_rect.position.y + float(ti) * turn_h
		var copper_col := Color(0.85, 0.5, 0.22, 1.0)
		draw_line(Vector2(-coil_w * 0.48, ty + turn_h * 0.5), Vector2(coil_w * 0.48, ty + turn_h * 0.5), copper_col, turn_h * 0.72)
		draw_line(Vector2(-coil_w * 0.25, ty + turn_h * 0.5), Vector2(-coil_w * 0.05, ty + turn_h * 0.5), Color(1.0, 0.8, 0.5, 0.6), turn_h * 0.72)

	# Toroid top terminal
	var toroid_rad := half_w * 0.32
	draw_circle(Vector2(0, toroid_y), toroid_rad, Color(0.75, 0.82, 0.92, 1.0))
	draw_arc(Vector2(0, toroid_y), toroid_rad, 0, TAU, 28, Color(0.4, 0.48, 0.6, 1.0), 2.5)
	draw_circle(Vector2(-toroid_rad * 0.3, toroid_y - toroid_rad * 0.3), toroid_rad * 0.35, Color(1.0, 1.0, 1.0, 0.45))
	
	# When powered: crackling plasma electric arcs & lightning bolts!
	if is_powered:
		var pulse := (sin(bulb_pulse_timer) + 1.0) * 0.5
		var spark_halo := tesla_col
		spark_halo.a = 0.4 + 0.25 * pulse
		draw_circle(Vector2(0, toroid_y), toroid_rad * (1.4 + 0.2 * pulse), spark_halo)
		
		var arc_count := 4
		for a in range(arc_count):
			var a_seed := float(a) * 1.57 + (bulb_pulse_timer * 1.8)
			var start_pt := Vector2(cos(a_seed) * toroid_rad, toroid_y + sin(a_seed) * toroid_rad)
			var mid_pt1 := start_pt + Vector2(cos(a_seed + sin(bulb_pulse_timer * 4.0 + a) * 0.6), sin(a_seed) - 0.4) * (half_w * 0.22)
			var mid_pt2 := mid_pt1 + Vector2(cos(a_seed - 0.4), sin(a_seed + 0.3)) * (half_w * 0.2)
			var end_pt := mid_pt2 + Vector2(cos(a_seed), sin(a_seed)) * (half_w * 0.16)
			
			var arc_pts := PackedVector2Array([start_pt, mid_pt1, mid_pt2, end_pt])
			draw_polyline(arc_pts, tesla_col, 3.0)
			draw_polyline(arc_pts, Color.WHITE, 1.2)
			draw_circle(end_pt, 2.5, Color.WHITE)

# Helper geometry drawers
func draw_rounded_rect(rect: Rect2, radius: float, color: Color) -> void:
	var r := clampf(radius, 1.0, minf(rect.size.x, rect.size.y) * 0.5)
	var pts := PackedVector2Array()
	var corners: Array[Vector2] = [
		Vector2(rect.end.x - r, rect.position.y + r),
		Vector2(rect.end.x - r, rect.end.y - r),
		Vector2(rect.position.x + r, rect.end.y - r),
		Vector2(rect.position.x + r, rect.position.y + r)
	]
	var start_angles: Array[float] = [-PI * 0.5, 0.0, PI * 0.5, PI]
	for c_idx in range(4):
		var center: Vector2 = corners[c_idx]
		var start_ang: float = start_angles[c_idx]
		for step in range(6):
			var ang: float = start_ang + (float(step) / 5.0) * (PI * 0.5)
			pts.append(center + Vector2(cos(ang), sin(ang)) * r)
	draw_colored_polygon(pts, color)

func draw_rounded_rect_outline(rect: Rect2, radius: float, color: Color, width: float) -> void:
	var r := clampf(radius, 1.0, minf(rect.size.x, rect.size.y) * 0.5)
	var pts := PackedVector2Array()
	var corners: Array[Vector2] = [
		Vector2(rect.end.x - r, rect.position.y + r),
		Vector2(rect.end.x - r, rect.end.y - r),
		Vector2(rect.position.x + r, rect.end.y - r),
		Vector2(rect.position.x + r, rect.position.y + r)
	]
	var start_angles: Array[float] = [-PI * 0.5, 0.0, PI * 0.5, PI]
	for c_idx in range(4):
		var center: Vector2 = corners[c_idx]
		var start_ang: float = start_angles[c_idx]
		for step in range(6):
			var ang: float = start_ang + (float(step) / 5.0) * (PI * 0.5)
			pts.append(center + Vector2(cos(ang), sin(ang)) * r)
	pts.append(pts[0])
	draw_polyline(pts, color, width, true)

# -------------------------------------------------------------
# HOUSES & BUILDINGS PROCEDURAL RENDERING
# -------------------------------------------------------------
# Cozy Small Cottage House with warm glowing windows and smoking chimney when powered
func draw_house_small(half_w: float, ports: int) -> void:
	var house_col := get_active_color(channel)
	var wire_conn_col := house_col if is_powered else Color(0.18, 0.22, 0.3, 1.0)
	
	# Terminal conduit connections to connected ports
	var points: Array[Vector2] = []
	if (ports & ElectricEnums.DIR_UP) != 0: points.append(Vector2(0, -half_w))
	if (ports & ElectricEnums.DIR_RIGHT) != 0: points.append(Vector2(half_w, 0))
	if (ports & ElectricEnums.DIR_DOWN) != 0: points.append(Vector2(0, half_w))
	if (ports & ElectricEnums.DIR_LEFT) != 0: points.append(Vector2(-half_w, 0))
	for p in points:
		draw_conduit_segment(p, Vector2.ZERO, half_w, wire_conn_col, 0.0)
		
	var scale_factor := bulb_scale_bounce
	var hw := half_w * 0.72 * scale_factor
	var hh := half_w * 0.44 * scale_factor
	var hy := half_w * 0.08
	
	# Drop Shadow
	draw_rounded_rect(Rect2(-hw * 0.5 + 2, hy - hh * 0.5 + 4, hw, hh), 6.0, Color(0.04, 0.07, 0.12, 0.65))
	
	# Chimney on top-left of roof
	var chim_w := hw * 0.18
	var chim_h := hh * 0.55
	var chim_x := -hw * 0.38
	var chim_y := hy - hh * 0.5 - chim_h * 0.6
	draw_rounded_rect(Rect2(chim_x, chim_y, chim_w, chim_h), 2.0, Color(0.48, 0.25, 0.20, 1.0))
	draw_rect(Rect2(chim_x - 1, chim_y - 2, chim_w + 2, 3), Color(0.35, 0.18, 0.15, 1.0))
	
	# Chimney smoke when powered
	if is_powered:
		for sm in range(2):
			var sm_t := fposmod(bulb_pulse_timer * 0.8 + float(sm) * 0.5, 1.0)
			var sm_pos := Vector2(chim_x + chim_w * 0.5 + sin(sm_t * 6.0) * 4.0 - sm_t * 6.0, chim_y - 3.0 - sm_t * 14.0)
			draw_circle(sm_pos, 2.5 + sm_t * 3.5, Color(0.9, 0.92, 0.95, (1.0 - sm_t) * 0.6))
			
	# House Main Body
	var body_rect := Rect2(-hw * 0.5, hy - hh * 0.5, hw, hh)
	draw_rounded_rect(body_rect, 4.0, Color(0.85, 0.78, 0.68, 1.0))
	
	# Pitch Gable Roof
	var roof_pts := PackedVector2Array([
		Vector2(-hw * 0.58, hy - hh * 0.5),
		Vector2(0, hy - hh * 0.5 - hh * 0.65),
		Vector2(hw * 0.58, hy - hh * 0.5)
	])
	draw_colored_polygon(roof_pts, Color(0.72, 0.24, 0.20, 1.0))
	draw_line(Vector2(-hw * 0.58, hy - hh * 0.5), Vector2(0, hy - hh * 0.5 - hh * 0.65), Color(0.95, 0.45, 0.40, 1.0), 2.5)
	draw_line(Vector2(0, hy - hh * 0.5 - hh * 0.65), Vector2(hw * 0.58, hy - hh * 0.5), Color(0.55, 0.16, 0.14, 1.0), 2.5)
	
	# Wood Door in center
	var door_w := hw * 0.22
	var door_h := hh * 0.58
	var door_x := -door_w * 0.5
	var door_y := hy + hh * 0.5 - door_h
	draw_rounded_rect(Rect2(door_x, door_y, door_w, door_h), 2.0, Color(0.40, 0.22, 0.14, 1.0))
	draw_circle(Vector2(door_x + door_w - 2.5, door_y + door_h * 0.55), 1.2, Color(0.95, 0.82, 0.35, 1.0))
	
	# 2 Cottage Windows (Left & Right)
	var win_w := hw * 0.24
	var win_h := hh * 0.42
	var win_y := hy - hh * 0.30
	var win_xs: Array[float] = [-hw * 0.40, hw * 0.40 - win_w]
	
	for wx: float in win_xs:
		var wr := Rect2(wx, win_y, win_w, win_h)
		draw_rect(wr.grow(1.5), Color(0.28, 0.20, 0.16, 1.0))
		if is_powered:
			var pulse := (sin(bulb_pulse_timer * 4.0) + 1.0) * 0.5
			# Golden glowing window
			draw_rect(wr.grow(4.0), Color(1.0, 0.85, 0.35, 0.4 + 0.2 * pulse))
			draw_rect(wr, Color(1.0, 0.92, 0.45, 1.0))
		else:
			draw_rect(wr, Color(0.12, 0.18, 0.28, 1.0))
		# Cross panes
		var cross_c := Color(0.4, 0.3, 0.2, 0.95) if is_powered else Color(0.25, 0.2, 0.16, 0.9)
		draw_line(Vector2(wx + win_w * 0.5, win_y), Vector2(wx + win_w * 0.5, win_y + win_h), cross_c, 1.2)
		draw_line(Vector2(wx, win_y + win_h * 0.5), Vector2(wx + win_w, win_y + win_h * 0.5), cross_c, 1.2)

# Two-Story Modern Suburban Villa with multi-window illumination
func draw_house_big(half_w: float, ports: int) -> void:
	var villa_col := get_active_color(channel)
	var wire_conn_col := villa_col if is_powered else Color(0.18, 0.22, 0.3, 1.0)
	
	var points: Array[Vector2] = []
	if (ports & ElectricEnums.DIR_UP) != 0: points.append(Vector2(0, -half_w))
	if (ports & ElectricEnums.DIR_RIGHT) != 0: points.append(Vector2(half_w, 0))
	if (ports & ElectricEnums.DIR_DOWN) != 0: points.append(Vector2(0, half_w))
	if (ports & ElectricEnums.DIR_LEFT) != 0: points.append(Vector2(-half_w, 0))
	for p in points:
		draw_conduit_segment(p, Vector2.ZERO, half_w, wire_conn_col, 0.0)
		
	var scale_factor := bulb_scale_bounce
	var vw := half_w * 0.84 * scale_factor
	var vh := half_w * 0.62 * scale_factor
	var vy := half_w * 0.06
	
	# Drop Shadow
	draw_rounded_rect(Rect2(-vw * 0.5 + 2, vy - vh * 0.5 + 4, vw, vh), 8.0, Color(0.04, 0.07, 0.12, 0.65))
	
	# Main Two-Story Facade
	draw_rounded_rect(Rect2(-vw * 0.5, vy - vh * 0.5, vw, vh), 4.0, Color(0.88, 0.85, 0.80, 1.0))
	# Mid-floor dividing line
	draw_line(Vector2(-vw * 0.5, vy), Vector2(vw * 0.5, vy), Color(0.55, 0.52, 0.48, 1.0), 2.0)
	
	# Twin Gable Roof
	var roof_l := PackedVector2Array([
		Vector2(-vw * 0.54, vy - vh * 0.5),
		Vector2(-vw * 0.18, vy - vh * 0.5 - vh * 0.42),
		Vector2(vw * 0.12, vy - vh * 0.5)
	])
	var roof_r := PackedVector2Array([
		Vector2(0, vy - vh * 0.5),
		Vector2(vw * 0.32, vy - vh * 0.5 - vh * 0.42),
		Vector2(vw * 0.54, vy - vh * 0.5)
	])
	draw_colored_polygon(roof_l, Color(0.24, 0.32, 0.46, 1.0))
	draw_colored_polygon(roof_r, Color(0.28, 0.36, 0.52, 1.0))
	
	# 4 Large Windows (2 upstairs, 2 downstairs)
	var win_w := vw * 0.22
	var win_h := vh * 0.30
	var win_pos: Array[Vector2] = [
		Vector2(-vw * 0.38, vy - vh * 0.42), Vector2(vw * 0.38 - win_w, vy - vh * 0.42),
		Vector2(-vw * 0.38, vy + 4), Vector2(vw * 0.38 - win_w, vy + 4)
	]
	for wp: Vector2 in win_pos:
		var wr := Rect2(wp.x, wp.y, win_w, win_h)
		draw_rect(wr.grow(1.5), Color(0.2, 0.25, 0.35, 1.0))
		if is_powered:
			var pulse := (sin(bulb_pulse_timer * 4.0) + 1.0) * 0.5
			draw_rect(wr.grow(3.5), Color(1.0, 0.85, 0.35, 0.4 + 0.2 * pulse))
			draw_rect(wr, Color(1.0, 0.90, 0.42, 1.0))
		else:
			draw_rect(wr, Color(0.12, 0.16, 0.25, 1.0))
			
	# Center Entrance Door
	var door_w := vw * 0.20
	var door_h := vh * 0.38
	var door_x := -door_w * 0.5
	var door_y := vy + vh * 0.5 - door_h
	draw_rect(Rect2(door_x, door_y, door_w, door_h), Color(0.25, 0.30, 0.40, 1.0))
	if is_powered:
		draw_rect(Rect2(door_x + 2, door_y + 2, door_w - 4, door_h - 4), Color(1.0, 0.88, 0.45, 0.95))

# High-Tech City Building / Skyscraper with illuminated office window grid & rooftop antenna
func draw_building(half_w: float, ports: int) -> void:
	var bld_col := get_active_color(channel)
	var wire_conn_col := bld_col if is_powered else Color(0.18, 0.22, 0.3, 1.0)
	
	var points: Array[Vector2] = []
	if (ports & ElectricEnums.DIR_UP) != 0: points.append(Vector2(0, -half_w))
	if (ports & ElectricEnums.DIR_RIGHT) != 0: points.append(Vector2(half_w, 0))
	if (ports & ElectricEnums.DIR_DOWN) != 0: points.append(Vector2(0, half_w))
	if (ports & ElectricEnums.DIR_LEFT) != 0: points.append(Vector2(-half_w, 0))
	for p in points:
		draw_conduit_segment(p, Vector2.ZERO, half_w, wire_conn_col, 0.0)
		
	var scale_factor := bulb_scale_bounce
	var bw := half_w * 0.72 * scale_factor
	var bh := half_w * 0.84 * scale_factor
	var by := half_w * 0.04
	
	# Drop Shadow
	draw_rounded_rect(Rect2(-bw * 0.5 + 3, by - bh * 0.5 + 4, bw, bh), 6.0, Color(0.04, 0.07, 0.12, 0.65))
	
	# Rooftop Antenna
	var spire_top := by - bh * 0.5 - bh * 0.25
	draw_line(Vector2(0, by - bh * 0.5), Vector2(0, spire_top), Color(0.65, 0.72, 0.82, 1.0), 2.5)
	var beacon_pulse := (sin(bulb_pulse_timer * 6.0) + 1.0) * 0.5
	var beacon_col := Color(0.0, 0.95, 1.0, 1.0) if is_powered else Color(1.0, 0.2, 0.2, 0.8)
	draw_circle(Vector2(0, spire_top), 2.5 + 1.5 * beacon_pulse, beacon_col)
	if is_powered:
		draw_arc(Vector2(0, spire_top), 6.0 + 6.0 * beacon_pulse, 0, TAU, 12, Color(0.2, 0.85, 1.0, 0.5 * (1.0 - beacon_pulse)), 1.5)
		
	# Tower Body
	draw_rounded_rect(Rect2(-bw * 0.5, by - bh * 0.5, bw, bh), 4.0, Color(0.16, 0.22, 0.32, 1.0))
	
	# Window Grid (3 columns x 3 rows)
	var win_w := bw * 0.22
	var win_h := bh * 0.18
	var gap_x := (bw - 3.0 * win_w) / 4.0
	var gap_y := (bh - 12.0 - 3.0 * win_h) / 4.0
	
	for r in range(3):
		for c in range(3):
			var wx := -bw * 0.5 + gap_x + float(c) * (win_w + gap_x)
			var wy := by - bh * 0.5 + 6.0 + float(r) * (win_h + gap_y)
			var wr := Rect2(wx, wy, win_w, win_h)
			
			if is_powered:
				var pulse := (sin(bulb_pulse_timer * 4.0 + float(r + c) * 0.8) + 1.0) * 0.5
				var win_col := Color(1.0, 0.86, 0.35, 1.0) if (c != 1) else Color(0.45, 0.92, 1.0, 1.0)
				draw_rect(wr.grow(2.5), win_col.blend(Color(1, 1, 1, 0.3 * pulse)))
				draw_rect(wr, win_col)
			else:
				draw_rect(wr, Color(0.10, 0.14, 0.22, 1.0))
				draw_rect(Rect2(wx, wy, win_w, 2), Color(0.16, 0.22, 0.32, 1.0))
				
	# Lobby Entrance
	var lw := bw * 0.34
	var lh := bh * 0.16
	draw_rect(Rect2(-lw * 0.5, by + bh * 0.5 - lh, lw, lh), Color(0.08, 0.12, 0.18, 1.0))
	if is_powered:
		draw_rect(Rect2(-lw * 0.5 + 2, by + bh * 0.5 - lh + 2, lw - 4, lh - 2), Color(1.0, 0.95, 0.7, 0.95))
