# electric_levels.gd
# Level database and procedural solver for Electric Flow (Levels 1 to 1000).
# Loads curated full-board levels directly from res://assets/data/electric_levels.json
# and generates dynamic progressive full-board levels up to Level 1000.
class_name ElectricLevels

const ElectricEnums = preload("res://scripts/electric_enums.gd")

static var _cached_json_levels: Array[Dictionary] = []
static var _json_loaded: bool = false

static func get_total_levels() -> int:
	return 99999

static func get_daily_challenge() -> Dictionary:
	var date_dict := Time.get_date_dict_from_system()
	var y: int = int(date_dict.get("year", 2026))
	var m: int = int(date_dict.get("month", 1))
	var d: int = int(date_dict.get("day", 1))
	var daily_seed: int = absi(y * 10000 + m * 100 + d)
	var daily_num: int = 200000 + (daily_seed % 50000)
	var lvl := _generate_procedural_level(daily_num)
	lvl["title"] = "Daily %02d/%02d" % [m, d]
	lvl["is_daily"] = true
	return lvl

static func _ensure_json_loaded() -> void:
	if _json_loaded:
		return
	_json_loaded = true
	_cached_json_levels = []
	
	var file_path := "res://assets/data/electric_levels.json"
	if not FileAccess.file_exists(file_path):
		return
		
	var file := FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return
		
	var json_str := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	var err := json.parse(json_str)
	if err != OK:
		push_warning("Failed to parse electric_levels.json: %s" % json.get_error_message())
		return
		
	var data = json.data
	if data is Dictionary and data.has("levels"):
		var raw_levels: Array = data["levels"]
		for raw_lvl in raw_levels:
			if raw_lvl is Dictionary:
				_cached_json_levels.append(_sanitize_level_dict(raw_lvl))
	elif data is Array:
		for raw_lvl in data:
			if raw_lvl is Dictionary:
				_cached_json_levels.append(_sanitize_level_dict(raw_lvl))

static func _sanitize_level_dict(lvl: Dictionary) -> Dictionary:
	var clean := lvl.duplicate(true)
	clean["level"] = int(clean.get("level", 1))
	clean["rows"] = int(clean.get("rows", 3))
	clean["cols"] = int(clean.get("cols", 3))
	clean["min_moves"] = int(clean.get("min_moves", 2))
	var clean_tiles: Array = []
	for t in clean.get("tiles", []):
		if t is Dictionary:
			var ct: Dictionary = t.duplicate()
			ct["type"] = int(ct.get("type", 0))
			ct["rot"] = int(ct.get("rot", 0))
			ct["rotatable"] = bool(ct.get("rotatable", true))
			if ct.has("channel"):
				ct["channel"] = int(ct.get("channel", 0))
			if ct.has("ports"):
				ct["ports"] = int(ct.get("ports", 0))
			clean_tiles.append(ct)
	clean["tiles"] = clean_tiles
	return clean

static func get_level(level_num: int) -> Dictionary:
	level_num = clampi(level_num, 1, 999999)
	_ensure_json_loaded()
	
	if level_num <= _cached_json_levels.size():
		var lvl: Dictionary = _cached_json_levels[level_num - 1].duplicate(true)
		if not lvl.has("min_moves"):
			lvl["min_moves"] = 2
		return lvl
	return _generate_procedural_level(level_num)

static func get_all_levels() -> Array[Dictionary]:
	_ensure_json_loaded()
	return _cached_json_levels

# -------------------------------------------------------------
# HELPER: Check if a tile array is currently solved in its given rotation state
# -------------------------------------------------------------
static func _is_level_solved(tiles: Array, rows: int, cols: int) -> bool:
	rows = int(rows)
	cols = int(cols)
	var queue: Array[Dictionary] = []
	var visited := {}
	
	for i in range(tiles.size()):
		var t: Dictionary = tiles[i]
		var t_type: int = int(t.get("type", 0))
		if t_type == ElectricEnums.TileType.BATTERY or t_type == ElectricEnums.TileType.SOLAR:
			var ch: int = int(t.get("channel", ElectricEnums.Channel.NONE))
			queue.append({"idx": i, "ch": ch})
			visited["%d:%d" % [i, ch]] = true
			
	var get_ports := func(idx: int) -> int:
		var t: Dictionary = tiles[idx]
		var t_type: int = int(t.get("type", 0))
		if t_type == ElectricEnums.TileType.EMPTY:
			return 0
		var base_p: int = int(t.get("ports", 0))
		if base_p == 0:
			base_p = ElectricEnums.get_base_ports(t_type)
		return ElectricEnums.rotate_mask_cw(base_p, int(t.get("rot", 0)))
		
	var powered := {}
	var dirs := [ElectricEnums.DIR_UP, ElectricEnums.DIR_RIGHT, ElectricEnums.DIR_DOWN, ElectricEnums.DIR_LEFT]
	
	while not queue.is_empty():
		var curr: Dictionary = queue.pop_front()
		var curr_idx: int = curr["idx"]
		var curr_ch: int = curr["ch"]
		var curr_r: int = int(curr_idx / cols)
		var curr_c: int = curr_idx % cols
		var curr_p: int = get_ports.call(curr_idx)
		
		for d in dirs:
			if (curr_p & d) == 0:
				continue
			var off := ElectricEnums.get_dir_offset(d)
			var nr := curr_r + off.x
			var nc := curr_c + off.y
			if nr < 0 or nr >= rows or nc < 0 or nc >= cols:
				continue
			var n_idx := nr * cols + nc
			var n_tile: Dictionary = tiles[n_idx]
			var n_type: int = n_tile.get("type", 0)
			if n_type == ElectricEnums.TileType.EMPTY:
				continue
			var opp_d := ElectricEnums.get_opposite_dir(d)
			var n_p: int = get_ports.call(n_idx)
			if (n_p & opp_d) == 0:
				continue
				
			var is_target := (
				n_type == ElectricEnums.TileType.BULB or
				n_type == ElectricEnums.TileType.FAN or
				n_type == ElectricEnums.TileType.VACUUM_TUBE or
				n_type == ElectricEnums.TileType.HEATER or
				n_type == ElectricEnums.TileType.TESLA_COIL
			)
			if is_target:
				var t_ch: int = n_tile.get("channel", ElectricEnums.Channel.NONE)
				if t_ch == ElectricEnums.Channel.NONE or t_ch == curr_ch:
					powered[n_idx] = true
					var key := "%d:%d" % [n_idx, curr_ch]
					if not visited.has(key):
						visited[key] = true
						queue.append({"idx": n_idx, "ch": curr_ch})
			elif n_type != ElectricEnums.TileType.BATTERY and n_type != ElectricEnums.TileType.SOLAR:
				powered[n_idx] = true
				var key := "%d:%d" % [n_idx, curr_ch]
				if not visited.has(key):
					visited[key] = true
					queue.append({"idx": n_idx, "ch": curr_ch})
					
	var targets: Array[int] = []
	for i in range(tiles.size()):
		var t_type: int = tiles[i].get("type", 0)
		if (
			t_type == ElectricEnums.TileType.BULB or
			t_type == ElectricEnums.TileType.FAN or
			t_type == ElectricEnums.TileType.VACUUM_TUBE or
			t_type == ElectricEnums.TileType.HEATER or
			t_type == ElectricEnums.TileType.TESLA_COIL
		):
			targets.append(i)
			
	if targets.is_empty():
		return false
	for t_idx in targets:
		if not powered.has(t_idx):
			return false
	return true

# -------------------------------------------------------------
# PROCEDURAL SOLVABLE LEVEL GENERATOR (Levels 31 to 1000)
# Progressive Grid Scaling Every 3 Levels, 100% Board Utilization, Guaranteed Scramble
# -------------------------------------------------------------
static func _generate_procedural_level(level_num: int) -> Dictionary:
	var seed_val: int = (level_num * 104729 + 7919) % 2147483647
	if seed_val <= 0:
		seed_val += 2147483646
	
	var next_rand := func() -> float:
		seed_val = (seed_val * 16807) % 2147483647
		return float(seed_val - 1) / 2147483646.0
	
	var rand_i := func(max_v: int) -> int:
		return int(next_rand.call() * max_v)
	
	# Board size increases every 3 levels!
	var group := int((level_num - 1) / 3)
	var rows := 2
	var cols := 2
	if group == 0: rows = 2; cols = 2
	elif group == 1: rows = 3; cols = 3
	elif group == 2: rows = 3; cols = 4
	elif group == 3: rows = 4; cols = 4
	elif group == 4: rows = 4; cols = 5
	elif group == 5: rows = 5; cols = 5
	elif group == 6: rows = 5; cols = 6
	else: rows = 6; cols = 6 # Capped at 6x6 for optimal touch mobile scale
	
	var total_tiles := rows * cols
	var all_channels := [
		ElectricEnums.Channel.CYAN,
		ElectricEnums.Channel.GREEN,
		ElectricEnums.Channel.YELLOW,
		ElectricEnums.Channel.ORANGE,
		ElectricEnums.Channel.MAGENTA
	]
	var channel: int = all_channels[(level_num - 1) % all_channels.size()]
	
	# Generate Hamiltonian / Serpentine path filling 100% of the board
	var path: Array[Vector2i] = []
	for r in range(rows):
		if r % 2 == 0:
			for c in range(cols):
				path.append(Vector2i(r, c))
		else:
			for c in range(cols - 1, -1, -1):
				path.append(Vector2i(r, c))
				
	var tiles: Array[Dictionary] = []
	for i in range(total_tiles):
		tiles.append({
			"type": ElectricEnums.TileType.EMPTY,
			"channel": ElectricEnums.Channel.NONE,
			"rot": 0,
			"rotatable": false
		})
		
	# Determine required ports for path
	var req_ports := {}
	for i in range(path.size()):
		var p: Vector2i = path[i]
		var req := 0
		if i > 0:
			var prev_p: Vector2i = path[i - 1]
			var diff := prev_p - p
			if diff == Vector2i(-1, 0): req |= ElectricEnums.DIR_UP
			elif diff == Vector2i(1, 0): req |= ElectricEnums.DIR_DOWN
			elif diff == Vector2i(0, -1): req |= ElectricEnums.DIR_LEFT
			elif diff == Vector2i(0, 1): req |= ElectricEnums.DIR_RIGHT
		if i < path.size() - 1:
			var next_p: Vector2i = path[i + 1]
			var diff := next_p - p
			if diff == Vector2i(-1, 0): req |= ElectricEnums.DIR_UP
			elif diff == Vector2i(1, 0): req |= ElectricEnums.DIR_DOWN
			elif diff == Vector2i(0, -1): req |= ElectricEnums.DIR_LEFT
			elif diff == Vector2i(0, 1): req |= ElectricEnums.DIR_RIGHT
		req_ports[p] = req
		
	# 1. Source at path[0]
	var s_pos: Vector2i = path[0]
	var s_idx := s_pos.x * cols + s_pos.y
	var s_out: int = req_ports.get(s_pos, ElectricEnums.DIR_RIGHT)
	var s_rot := 0
	if s_out == ElectricEnums.DIR_UP: s_rot = 0
	elif s_out == ElectricEnums.DIR_RIGHT: s_rot = 1
	elif s_out == ElectricEnums.DIR_DOWN: s_rot = 2
	elif s_out == ElectricEnums.DIR_LEFT: s_rot = 3
	
	var source_type := ElectricEnums.TileType.SOLAR if (level_num % 2 == 1) else ElectricEnums.TileType.BATTERY
	tiles[s_idx] = {
		"type": source_type,
		"channel": channel,
		"rot": s_rot,
		"rotatable": false
	}
	
	# 2. Target at path[path.size() - 1]
	var e_pos: Vector2i = path[path.size() - 1]
	var e_idx := e_pos.x * cols + e_pos.y
	var target_pool := [ElectricEnums.TileType.BULB, ElectricEnums.TileType.FAN]
	if level_num >= 3: target_pool.append(ElectricEnums.TileType.HEATER)
	if level_num >= 5: target_pool.append(ElectricEnums.TileType.VACUUM_TUBE)
	if level_num >= 7: target_pool.append(ElectricEnums.TileType.TESLA_COIL)
	
	var chosen_target: int = target_pool[(level_num - 1) % target_pool.size()]
	tiles[e_idx] = {
		"type": chosen_target,
		"channel": channel,
		"rot": 0,
		"rotatable": false
	}
	
	# 3. Intermediate components along the path (filling 100% of all cells)
	var solved_rots := {}
	var rotatable_indices: Array[int] = []
	
	for i in range(1, path.size() - 1):
		var p: Vector2i = path[i]
		var idx := p.x * cols + p.y
		var req: int = req_ports.get(p, 0)
		
		var t_type := ElectricEnums.TileType.WIRE_STRAIGHT
		var solved_rot := 0
		
		if req == (ElectricEnums.DIR_UP | ElectricEnums.DIR_DOWN):
			if level_num >= 4 and i % 4 == 0: t_type = ElectricEnums.TileType.RESISTOR
			elif level_num >= 8 and i % 5 == 0: t_type = ElectricEnums.TileType.CAPACITOR
			else: t_type = ElectricEnums.TileType.WIRE_STRAIGHT
			solved_rot = 0
		elif req == (ElectricEnums.DIR_LEFT | ElectricEnums.DIR_RIGHT):
			if level_num >= 4 and i % 4 == 0: t_type = ElectricEnums.TileType.RESISTOR
			elif level_num >= 8 and i % 5 == 0: t_type = ElectricEnums.TileType.CAPACITOR
			else: t_type = ElectricEnums.TileType.WIRE_STRAIGHT
			solved_rot = 1
		elif req == (ElectricEnums.DIR_DOWN | ElectricEnums.DIR_RIGHT):
			t_type = ElectricEnums.TileType.WIRE_CORNER
			solved_rot = 0
		elif req == (ElectricEnums.DIR_DOWN | ElectricEnums.DIR_LEFT):
			t_type = ElectricEnums.TileType.WIRE_CORNER
			solved_rot = 1
		elif req == (ElectricEnums.DIR_UP | ElectricEnums.DIR_LEFT):
			t_type = ElectricEnums.TileType.WIRE_CORNER
			solved_rot = 2
		elif req == (ElectricEnums.DIR_UP | ElectricEnums.DIR_RIGHT):
			t_type = ElectricEnums.TileType.WIRE_CORNER
			solved_rot = 3
			
		solved_rots[idx] = solved_rot
		rotatable_indices.append(idx)
		
		tiles[idx] = {
			"type": t_type,
			"channel": ElectricEnums.Channel.NONE,
			"rot": solved_rot,
			"target_rot": solved_rot,
			"rotatable": true
		}
		
	# 4. Scramble rotatable tiles so initiallyLit == 0
	for idx in rotatable_indices:
		var s_r: int = solved_rots[idx]
		var delta: int = 1 + int(rand_i.call(3))
		tiles[idx]["rot"] = (s_r + delta) % 4
		
	# Guarantee initial unlit state
	var scramble_attempts := 0
	while _is_level_solved(tiles, rows, cols) and scramble_attempts < 10:
		for idx in rotatable_indices:
			tiles[idx]["rot"] = (tiles[idx]["rot"] + 1) % 4
		scramble_attempts += 1
		
	# Calculate min moves
	var min_moves := 0
	for idx in rotatable_indices:
		var cur: int = tiles[idx]["rot"]
		var tgt: int = solved_rots[idx]
		var t_type: int = tiles[idx]["type"]
		if t_type == ElectricEnums.TileType.WIRE_STRAIGHT or t_type == ElectricEnums.TileType.RESISTOR or t_type == ElectricEnums.TileType.CAPACITOR:
			if (cur % 2) != (tgt % 2): min_moves += 1
		else:
			min_moves += (tgt - cur + 4) % 4
			
	var titles := ["Voltage Stream", "Grid Matrix", "Power Circuit", "Tesla Loop", "Energy Surge"]
	var title_str := "%s %d" % [titles[(level_num - 1) % titles.size()], level_num]
	
	return {
		"level": level_num,
		"rows": rows,
		"cols": cols,
		"title": title_str,
		"tiles": tiles,
		"min_moves": maxi(min_moves, 1)
	}
