class_name ElectricShineRays
extends Control

## Celebratory rotating sunburst shine rays for victory screens

@export var ray_count: int = 16
@export var rotation_speed: float = 0.45
@export var ray_radius: float = 460.0
@export var color_gold: Color = Color(1.0, 0.84, 0.25, 0.28)
@export var color_cyan: Color = Color(0.0, 0.88, 1.0, 0.16)

func _ready() -> void:
	custom_minimum_size = Vector2(ray_radius * 2, ray_radius * 2)
	pivot_offset = custom_minimum_size * 0.5
	mouse_filter = MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	rotation += rotation_speed * delta

func _draw() -> void:
	var center := size * 0.5
	if center == Vector2.ZERO:
		center = Vector2(ray_radius, ray_radius)
	var angle_step := TAU / float(ray_count)
	
	for i in range(ray_count):
		var a0 := float(i) * angle_step
		var a1 := a0 + angle_step * 0.55
		var col := color_gold if (i % 2 == 0) else color_cyan
		var r := ray_radius if (i % 2 == 0) else (ray_radius * 0.82)
		
		var p0 := center
		var p1 := center + Vector2(cos(a0), sin(a0)) * r
		var p2 := center + Vector2(cos(a1), sin(a1)) * r
		draw_colored_polygon(PackedVector2Array([p0, p1, p2]), col)
		
	# Center soft ambient bloom
	draw_circle(center, ray_radius * 0.38, Color(1.0, 0.9, 0.4, 0.22))
	draw_circle(center, ray_radius * 0.22, Color(1.0, 0.98, 0.8, 0.32))
