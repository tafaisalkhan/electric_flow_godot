# electric_enums.gd
# Enums, bitmasks and geometric helpers for Electric Flow circuits.
class_name ElectricEnums

enum TileType {
	EMPTY,
	WIRE_STRAIGHT,
	WIRE_CORNER,
	WIRE_TEE,
	WIRE_CROSS,
	BATTERY,
	BULB,
	SOLAR,
	RESISTOR,
	HEATER,
	CAPACITOR,
	FAN,
	VACUUM_TUBE,
	TESLA_COIL,
	HOUSE_SMALL,
	HOUSE_BIG,
	BUILDING
}

enum Channel {
	NONE,
	CYAN,
	YELLOW,
	ORANGE,
	MAGENTA,
	GREEN
}

# Bitmask directions: UP=1, RIGHT=2, DOWN=4, LEFT=8
const DIR_UP: int = 1
const DIR_RIGHT: int = 2
const DIR_DOWN: int = 4
const DIR_LEFT: int = 8
const DIR_ALL: int = 15

# Channel Colors
const COLOR_OFF := Color(0.22, 0.26, 0.33, 1.0)
const COLOR_CYAN := Color(0.0, 0.88, 1.0, 1.0)
const COLOR_YELLOW := Color(1.0, 0.86, 0.18, 1.0)
const COLOR_ORANGE := Color(1.0, 0.55, 0.15, 1.0)
const COLOR_MAGENTA := Color(1.0, 0.25, 0.85, 1.0)
const COLOR_GREEN := Color(0.2, 0.95, 0.45, 1.0)
const COLOR_PURPLE := Color(0.72, 0.35, 1.0, 1.0)

static func get_theme_color(theme_id: String) -> Color:
	match theme_id:
		"SolarGold":
			return COLOR_YELLOW
		"PlasmaPink":
			return COLOR_MAGENTA
		"EmeraldMatrix":
			return COLOR_GREEN
		"InfernoOrange":
			return COLOR_ORANGE
		"HyperViolet":
			return COLOR_PURPLE
		_:
			return COLOR_CYAN

static func get_channel_color(ch: int, user_theme: String = "") -> Color:
	if user_theme != "" and user_theme != "Classic":
		if ch == Channel.CYAN or ch == Channel.NONE:
			return get_theme_color(user_theme)
	match ch:
		Channel.CYAN:
			return COLOR_CYAN
		Channel.YELLOW:
			return COLOR_YELLOW
		Channel.ORANGE:
			return COLOR_ORANGE
		Channel.MAGENTA:
			return COLOR_MAGENTA
		Channel.GREEN:
			return COLOR_GREEN
		_:
			return COLOR_OFF

static func get_opposite_dir(dir: int) -> int:
	match dir:
		DIR_UP:
			return DIR_DOWN
		DIR_RIGHT:
			return DIR_LEFT
		DIR_DOWN:
			return DIR_UP
		DIR_LEFT:
			return DIR_RIGHT
		_:
			return 0

static func get_dir_offset(dir: int) -> Vector2i:
	match dir:
		DIR_UP:
			return Vector2i(-1, 0)
		DIR_RIGHT:
			return Vector2i(0, 1)
		DIR_DOWN:
			return Vector2i(1, 0)
		DIR_LEFT:
			return Vector2i(0, -1)
		_:
			return Vector2i.ZERO

static func rotate_mask_cw(mask: int, steps: int = 1) -> int:
	var result: int = mask
	var s: int = int(steps)
	s = (s % 4 + 4) % 4
	for _i in range(s):
		var next_mask: int = 0
		if (result & DIR_UP) != 0:
			next_mask |= DIR_RIGHT
		if (result & DIR_RIGHT) != 0:
			next_mask |= DIR_DOWN
		if (result & DIR_DOWN) != 0:
			next_mask |= DIR_LEFT
		if (result & DIR_LEFT) != 0:
			next_mask |= DIR_UP
		result = next_mask
	return result

static func get_base_ports(type: int) -> int:
	match type:
		TileType.WIRE_STRAIGHT:
			return DIR_UP | DIR_DOWN
		TileType.WIRE_CORNER:
			return DIR_DOWN | DIR_RIGHT # Down-Right elbow
		TileType.WIRE_TEE:
			return DIR_UP | DIR_RIGHT | DIR_DOWN # T-junction pointing Right
		TileType.WIRE_CROSS:
			return DIR_ALL
		TileType.BATTERY:
			return DIR_UP # Single terminal pointing Up at rotation 0
		TileType.SOLAR:
			return DIR_UP # Solar panel terminal pointing Up at rotation 0
		TileType.BULB:
			return DIR_ALL # Bulbs can accept power from any connected port
		TileType.RESISTOR:
			return DIR_UP | DIR_DOWN # Straight inline resistor
		TileType.HEATER:
			return DIR_ALL # Electric heating element accepts power from any connected port
		TileType.CAPACITOR:
			return DIR_UP | DIR_DOWN # Inline capacitor element
		TileType.FAN:
			return DIR_ALL # Electric cooling fan accepts power from any connected port
		TileType.VACUUM_TUBE:
			return DIR_ALL # Vacuum tube valve accepts power from any connected port
		TileType.TESLA_COIL:
			return DIR_ALL # Tesla coil accepts power from any connected port
		TileType.HOUSE_SMALL:
			return DIR_ALL # Small house connects electricity from any side
		TileType.HOUSE_BIG:
			return DIR_ALL # Big house villa connects electricity from any side
		TileType.BUILDING:
			return DIR_ALL # Metropolitan building connects electricity from any side
		_:
			return 0
