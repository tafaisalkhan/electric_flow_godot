# confetti_cannons.gd
# Procedural confetti system for celebration moments in Electric Flow.
extends Control
class_name ConfettiCannons

const COLORS: Array[Color] = [
	Color(0.0, 0.9, 1.0, 1.0),   # Cyan
	Color(1.0, 0.84, 0.0, 1.0),  # Gold / Yellow
	Color(1.0, 0.25, 0.65, 1.0), # Pink / Magenta
	Color(0.2, 0.95, 0.45, 1.0), # Green
	Color(1.0, 0.5, 0.1, 1.0),   # Orange
	Color(0.4, 0.6, 1.0, 1.0),   # Sky Blue
	Color(0.95, 0.95, 1.0, 1.0)  # Pure White
]

class ConfettiPiece:
	var pos: Vector2
	var vel: Vector2
	var rot: float
	var rot_speed: float
	var flip_speed: float
	var flip_phase: float
	var size: Vector2
	var color: Color

var pieces: Array[ConfettiPiece] = []
var is_active: bool = false
var elapsed: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)

func burst(count: int = 120) -> void:
	pieces.clear()
	elapsed = 0.0
	is_active = true
	set_process(true)
	
	var screen_w := size.x if size.x > 0 else 540.0
	for _i in range(count):
		var p := ConfettiPiece.new()
		# Emit from top region or random across top width
		p.pos = Vector2(randf_range(screen_w * 0.1, screen_w * 0.9), randf_range(-40.0, 120.0))
		p.vel = Vector2(randf_range(-140.0, 140.0), randf_range(-220.0, 180.0))
		p.rot = randf_range(0, TAU)
		p.rot_speed = randf_range(-5.0, 5.0)
		p.flip_speed = randf_range(4.0, 10.0)
		p.flip_phase = randf_range(0, TAU)
		p.size = Vector2(randf_range(10.0, 18.0), randf_range(6.0, 12.0))
		p.color = COLORS.pick_random()
		pieces.append(p)
	
	queue_redraw()

func stop() -> void:
	is_active = false
	pieces.clear()
	set_process(false)
	queue_redraw()

func _process(delta: float) -> void:
	if not is_active:
		return
	
	elapsed += delta
	var gravity := 450.0
	var drag := 0.985
	
	for p in pieces:
		p.vel.y += gravity * delta
		p.vel.x *= drag
		p.pos += p.vel * delta
		p.rot += p.rot_speed * delta
		p.flip_phase += p.flip_speed * delta
	
	# Stop after 4.5 seconds or when pieces fall off
	if elapsed > 4.5:
		is_active = false
		set_process(false)
		pieces.clear()
	
	queue_redraw()

func _draw() -> void:
	if not is_active or pieces.is_empty():
		return
	
	for p in pieces:
		var flip := cos(p.flip_phase)
		var s := Vector2(p.size.x, p.size.y * absf(flip))
		var rect := Rect2(-s * 0.5, s)
		
		draw_set_transform(p.pos, p.rot, Vector2.ONE)
		# Ribbon face
		draw_rect(rect, p.color)
		# Edge highlight
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, 2)), Color(1.0, 1.0, 1.0, 0.4))
	
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
