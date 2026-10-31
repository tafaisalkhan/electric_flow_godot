class_name UIPalette
extends RefCounted

const THEMES := [
	{"id": "Classic", "price": 0, "color": Color("#00e0ff"), "description": "Classic neon cyan energy glow"},
	{"id": "SolarGold", "price": 30, "color": Color("#ffdc2e"), "description": "Warm solar filament & golden cables"},
	{"id": "PlasmaPink", "price": 50, "color": Color("#ff40d9"), "description": "Vibrant magenta plasma discharge"},
	{"id": "EmeraldMatrix", "price": 75, "color": Color("#33f373"), "description": "Cybernetic jade phosphor flow"},
	{"id": "InfernoOrange", "price": 100, "color": Color("#ff8c26"), "description": "Incandescent blazing thermal flow"},
	{"id": "HyperViolet", "price": 150, "color": Color("#b859ff"), "description": "Cosmic ultraviolet electric beams"}
]

static func color_for(theme_id: String) -> Color:
	for theme_data in THEMES:
		if theme_data["id"] == theme_id:
			return theme_data["color"]
	return Color.WHITE

static func apply_background(background: Control, theme_id: String) -> void:
	if is_instance_valid(background):
		background.modulate = color_for(theme_id)
