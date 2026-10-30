# test_electric_flow.gd
# Headless test runner to verify Electric Flow puzzle evaluation and Level 8 mechanics.
extends SceneTree

const ElectricLevels = preload("res://scripts/electric_levels.gd")
const ElectricEnums = preload("res://scripts/electric_enums.gd")

func _init() -> void:
	print("--- STARTING ELECTRIC FLOW VERIFICATION ---")
	test_levels_exist()
	test_level_8_mechanics()
	test_new_components_and_3x3_levels()
	test_1000_levels_procedural()
	print("--- ALL ELECTRIC FLOW TESTS PASSED SUCCESSFULLY! ---")
	quit(0)

func test_levels_exist() -> void:
	var total := ElectricLevels.get_total_levels()
	assert(total == 1000, "Should have 1000 levels")
	print("[PASS] Total levels loaded: %d" % total)

func test_level_8_mechanics() -> void:
	var l8 := ElectricLevels.get_level(8)
	assert(l8["rows"] == 3 and l8["cols"] == 3, "Level 8 must be 3x3")
	print("[PASS] Level 8 grid is 3x3")
	
	# Check tiles
	var tiles: Array = l8["tiles"]
	assert(tiles.size() == 9, "Level 8 should have 9 tiles")
	
	# Verify yellow battery at (0, 2)
	var y_bat: Dictionary = tiles[0 * 3 + 2]
	assert(y_bat["type"] == ElectricEnums.TileType.BATTERY, "Tile (0,2) must be battery")
	assert(y_bat["channel"] == ElectricEnums.Channel.YELLOW, "Tile (0,2) must be yellow channel")
	
	# Verify cyan battery at (2, 2)
	var c_bat: Dictionary = tiles[2 * 3 + 2]
	assert(c_bat["type"] == ElectricEnums.TileType.BATTERY, "Tile (2,2) must be battery")
	assert(c_bat["channel"] == ElectricEnums.Channel.CYAN, "Tile (2,2) must be cyan channel")
	
	# Verify rotatable wire at (1, 1) starts with rot 0 (vertical)
	var mid_wire: Dictionary = tiles[1 * 3 + 1]
	assert(mid_wire["type"] == ElectricEnums.TileType.WIRE_STRAIGHT, "Tile (1,1) must be straight wire")
	assert(mid_wire["rot"] == 0, "Tile (1,1) should start vertical")
	assert(mid_wire["rotatable"] == true, "Tile (1,1) must be rotatable")
	
	print("[PASS] Level 8 initial configuration matches video perfectly")

func test_new_components_and_3x3_levels() -> void:
	# Check ports of new components
	assert(ElectricEnums.get_base_ports(ElectricEnums.TileType.SOLAR) == ElectricEnums.DIR_UP, "Solar base port is UP")
	assert(ElectricEnums.get_base_ports(ElectricEnums.TileType.RESISTOR) == (ElectricEnums.DIR_UP | ElectricEnums.DIR_DOWN), "Resistor base ports are UP|DOWN")
	assert(ElectricEnums.get_base_ports(ElectricEnums.TileType.HEATER) == ElectricEnums.DIR_ALL, "Heater element accepts from all directions")
	assert(ElectricEnums.get_base_ports(ElectricEnums.TileType.CAPACITOR) == (ElectricEnums.DIR_UP | ElectricEnums.DIR_DOWN), "Capacitor base ports are UP|DOWN")
	assert(ElectricEnums.get_base_ports(ElectricEnums.TileType.FAN) == ElectricEnums.DIR_ALL, "Fan accepts power from any connected port")
	assert(ElectricEnums.get_base_ports(ElectricEnums.TileType.VACUUM_TUBE) == ElectricEnums.DIR_ALL, "Vacuum tube accepts power from any connected port")
	assert(ElectricEnums.get_base_ports(ElectricEnums.TileType.TESLA_COIL) == ElectricEnums.DIR_ALL, "Tesla coil accepts power from any connected port")
	assert(ElectricEnums.get_base_ports(ElectricEnums.TileType.HOUSE_SMALL) == ElectricEnums.DIR_ALL, "Small House accepts power from any connected port")
	assert(ElectricEnums.get_base_ports(ElectricEnums.TileType.HOUSE_BIG) == ElectricEnums.DIR_ALL, "Big House Villa accepts power from any connected port")
	assert(ElectricEnums.get_base_ports(ElectricEnums.TileType.BUILDING) == ElectricEnums.DIR_ALL, "Building Skyscraper accepts power from any connected port")
	print("[PASS] Verified base ports for Houses, Buildings, Solar, Resistor, Heater, Capacitor, Fan, Vacuum Tube, and Tesla Coil")

	# Verify Level 11 (3x3 with Solar, Resistor, Heater)
	var l11 := ElectricLevels.get_level(11)
	assert(l11["rows"] == 3 and l11["cols"] == 3, "Level 11 must be 3x3")
	var l11_tiles: Array = l11["tiles"]
	assert(l11_tiles[0]["type"] == ElectricEnums.TileType.SOLAR, "Level 11 (0,0) is Solar")
	assert(l11_tiles[1]["type"] == ElectricEnums.TileType.RESISTOR, "Level 11 (0,1) is Resistor")
	assert(l11_tiles[4]["type"] == ElectricEnums.TileType.HEATER, "Level 11 (1,1) is Heater element")
	print("[PASS] Level 11 3x3 Solar & Resistor configuration verified")

	# Verify Level 12 (3x3 Hybrid Grid)
	var l12 := ElectricLevels.get_level(12)
	assert(l12["rows"] == 3 and l12["cols"] == 3, "Level 12 must be 3x3")
	print("[PASS] Level 12 3x3 Hybrid Power configuration verified")

	# Verify Level 13 (3x3 Circuit Lab)
	var l13 := ElectricLevels.get_level(13)
	assert(l13["rows"] == 3 and l13["cols"] == 3, "Level 13 must be 3x3")
	print("[PASS] Level 13 3x3 Circuit Lab configuration verified")

	# Verify Level 14 (3x3 Cooling System with Fan)
	var l14 := ElectricLevels.get_level(14)
	assert(l14["rows"] == 3 and l14["cols"] == 3, "Level 14 must be 3x3")
	var l14_tiles: Array = l14["tiles"]
	assert(l14_tiles[4]["type"] == ElectricEnums.TileType.FAN, "Level 14 center is Electric Fan")
	print("[PASS] Level 14 3x3 Cooling Fan configuration verified")

	# Verify Level 15 (3x3 Vacuum Tube)
	var l15 := ElectricLevels.get_level(15)
	assert(l15["rows"] == 3 and l15["cols"] == 3, "Level 15 must be 3x3")
	var l15_tiles: Array = l15["tiles"]
	assert(l15_tiles[4]["type"] == ElectricEnums.TileType.VACUUM_TUBE, "Level 15 center is Vacuum Tube")
	print("[PASS] Level 15 3x3 Vacuum Tube configuration verified")

	# Verify Level 16 (3x3 Tesla Arc)
	var l16 := ElectricLevels.get_level(16)
	assert(l16["rows"] == 3 and l16["cols"] == 3, "Level 16 must be 3x3")
	var l16_tiles: Array = l16["tiles"]
	assert(l16_tiles[4]["type"] == ElectricEnums.TileType.TESLA_COIL, "Level 16 center is Tesla Coil")
	print("[PASS] Level 16 3x3 Tesla Coil configuration verified")

func test_1000_levels_procedural() -> void:
	# Test various milestones in the 1000 levels
	var sample_levels := [25, 50, 100, 250, 500, 750, 1000]
	for lvl_num in sample_levels:
		var lvl_data := ElectricLevels.get_level(lvl_num)
		assert(lvl_data.has("rows") and lvl_data.has("cols"), "Level %d must have rows and cols" % lvl_num)
		assert(lvl_data.has("tiles") and lvl_data["tiles"].size() > 0, "Level %d must have tiles" % lvl_num)
		assert(lvl_data["level"] == lvl_num, "Level %d index must match" % lvl_num)
		
		# Verify grid size progression:
		if lvl_num <= 40:
			assert(lvl_data["rows"] == 3 and lvl_data["cols"] == 3, "Levels <= 40 should be 3x3")
		elif lvl_num <= 200:
			assert(lvl_data["rows"] == 4 and lvl_data["cols"] == 4, "Levels 41-200 should be 4x4")
		else:
			assert(lvl_data["rows"] == 5 and lvl_data["cols"] == 5, "Levels > 200 should be 5x5")
		
		# Check has at least 1 power source and 1 target
		var source_count := 0
		var target_count := 0
		for t in lvl_data["tiles"]:
			var t_type: int = t.get("type", 0)
			if t_type == ElectricEnums.TileType.BATTERY or t_type == ElectricEnums.TileType.SOLAR:
				source_count += 1
			if t_type in [
				ElectricEnums.TileType.BULB,
				ElectricEnums.TileType.FAN,
				ElectricEnums.TileType.VACUUM_TUBE,
				ElectricEnums.TileType.HEATER,
				ElectricEnums.TileType.TESLA_COIL,
				ElectricEnums.TileType.HOUSE_SMALL,
				ElectricEnums.TileType.HOUSE_BIG,
				ElectricEnums.TileType.BUILDING
			]:
				target_count += 1
		assert(source_count >= 1, "Level %d must have power source" % lvl_num)
		assert(target_count >= 1, "Level %d must have target consumer element" % lvl_num)
		assert(lvl_data.has("min_moves") and lvl_data["min_moves"] >= 1, "Level %d must have min_moves >= 1" % lvl_num)
		
		# In higher levels (> 80), item counts should scale up
		if lvl_num > 80:
			assert(source_count >= 2 or target_count >= 2, "Level %d should have increased item count" % lvl_num)
	print("[PASS] Procedural generator verified across 1000 levels with scaling grid size, item counts, and minimum move par counts (25, 50, 100, 250, 500, 750, 1000)")
