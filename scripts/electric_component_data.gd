# electric_component_data.gd
# Educational reference database for electronic components in Electric Flow.
class_name ElectricComponentData
extends RefCounted

static func get_component_info(tile_type: int) -> Dictionary:
	match tile_type:
		ElectricEnums.TileType.RESISTOR:
			return {
				"name": "Resistor",
				"symbol": "—[ /\\/\\/\\ ]—",
				"category": "Current Control & Protection",
				"unit": "Ohms (Ω)",
				"short_purpose": "Limits electric current to protect delicate circuit parts.",
				"how_it_works": "Made of resistive carbon or metal film. By Ohm's Law (V = I × R), it converts excess electrical energy into mild heat, preventing delicate microchips and bulbs from blowing up.",
				"fun_fact": "The 4 colored stripes on every resistor are a universal code (Black=0, Brown=1, Red=2, Gold=5% precision) that tells engineers its exact resistance value without needing a meter!"
			}
		ElectricEnums.TileType.CAPACITOR:
			return {
				"name": "Capacitor",
				"symbol": "—[ | ( ]—",
				"category": "Electrostatic Energy Storage",
				"unit": "Farads (F)",
				"short_purpose": "Stores electric charge and releases it in rapid energy bursts.",
				"how_it_works": "Contains two conductive aluminum plates separated by a non-conducting dielectric layer. When voltage is applied, electrons accumulate on one plate, storing energy in an electrostatic field.",
				"fun_fact": "Camera flashes and defibrillators use capacitors because they can dump all their stored energy in a few milliseconds—much faster than a chemical battery could ever discharge!"
			}
		ElectricEnums.TileType.BULB:
			return {
				"name": "Incandescent Bulb",
				"symbol": "—( ⊗ )—",
				"category": "Light Load (Consumer)",
				"unit": "Lumens / Watts (W)",
				"short_purpose": "Converts electrical current into visible radiant light.",
				"how_it_works": "Electric current pushes through an ultra-thin tungsten filament. High electrical resistance heats the wire to over 2,500°C, causing it to incandesce and shine brightly inside an inert argon gas envelope.",
				"fun_fact": "Thomas Edison and Joseph Swan perfected the first practical electric lightbulb in 1879 after testing over 6,000 different carbonized plant filaments, including bamboo!"
			}
		ElectricEnums.TileType.HEATER:
			return {
				"name": "Electric Heater Element",
				"symbol": "—[ §§§§ ]—",
				"category": "Thermal Load (Consumer)",
				"unit": "Watts (W) / Joules (J)",
				"short_purpose": "Converts electric current directly into high-temperature heat.",
				"how_it_works": "Uses Joule heating (Power = I² × R). Electricity forces its way through tightly wound Nichrome alloy wire (nickel + chromium), which offers high resistance and glows radiant orange.",
				"fun_fact": "Nichrome wire is used in toasters, ovens, and space heaters because it forms a self-protecting microscopic chromium oxide layer that stops it from melting or burning in open air!"
			}
		ElectricEnums.TileType.FAN:
			return {
				"name": "Electric Cooling Motor",
				"symbol": "—( M )—",
				"category": "Kinetic Load (Consumer)",
				"unit": "RPM / CFM",
				"short_purpose": "Converts electrical power into rotational kinetic air flow.",
				"how_it_works": "Current flowing through copper stator coils creates a dynamic magnetic field. This exerts magnetic torque on permanent magnets attached to the rotor shaft, spinning the aerodynamic fan blades.",
				"fun_fact": "Schuyler Wheeler invented the electric fan in 1882 at age 22. Today, ultra-quiet brushless DC cooling fans protect every modern computer processor and game console from overheating!"
			}
		ElectricEnums.TileType.VACUUM_TUBE:
			return {
				"name": "Thermionic Vacuum Tube",
				"symbol": "—◯ [ ⏚ ⊞ ]—",
				"category": "Electronic Valve / Amplifier",
				"unit": "Gain / Transconductance",
				"short_purpose": "Amplifies electrical signals and acts as a one-way electronic valve.",
				"how_it_works": "Inside a glass vacuum, a heated filament (cathode) boils off a cloud of free electrons (thermionic emission). A positive metal plate (anode) pulls the electrons across the empty gap, creating current.",
				"fun_fact": "The very first electronic computers, like ENIAC in 1945, used over 17,000 vacuum tubes and filled an entire room! Audiophiles still cherish vacuum tube amplifiers for their warm, rich acoustic sound."
			}
		ElectricEnums.TileType.TESLA_COIL:
			return {
				"name": "Tesla Coil",
				"symbol": "—[ ⚡ ∿ ⚡ ]—",
				"category": "High-Voltage Plasma Transformer",
				"unit": "Kilovolts (kV) / Megahertz",
				"short_purpose": "Generates ultra-high voltage, high-frequency electric plasma arcs.",
				"how_it_works": "Uses two resonant inductive coils tuned to the exact same frequency. Low input voltage resonates up into hundreds of thousands of volts at the top toroid, tearing apart air molecules into electric lightning sparks.",
				"fun_fact": "Nikola Tesla invented the coil in 1891 to demonstrate wireless power transmission. In demonstrations, he held wireless fluorescent bulbs in his hands and lit them up through the air!"
			}
		ElectricEnums.TileType.BATTERY:
			return {
				"name": "Chemical Battery",
				"symbol": "—[ + | i - ]—",
				"category": "DC Power Source",
				"unit": "Volts (V) / Amp-hours",
				"short_purpose": "Supplies Direct Current (DC) electrical energy to drive the circuit.",
				"how_it_works": "Chemical redox reactions inside the battery separate positive and negative ions, building electrical potential (voltage) between the positive (+) and negative (-) terminals.",
				"fun_fact": "Alessandro Volta built the first true chemical battery in 1800 using alternating discs of zinc, copper, and saltwater-soaked cardboard—giving his name to the electrical unit 'Volt'!"
			}
		ElectricEnums.TileType.SOLAR:
			return {
				"name": "Photovoltaic Solar Cell",
				"symbol": "—[ ☀️⤹▦ ]—",
				"category": "Renewable Energy Generator",
				"unit": "Watts-Peak (Wp)",
				"short_purpose": "Converts sunlight directly into electrical current without moving parts.",
				"how_it_works": "Sunlight photons hit the silicon semiconductor wafer and knock electrons free from atomic bonds (the photoelectric effect), generating a steady flow of clean direct-current electricity.",
				"fun_fact": "Albert Einstein won his 1921 Nobel Prize in Physics not for his theory of relativity, but for mathematically proving how photons in light liberate electrons in the photoelectric effect!"
			}
		ElectricEnums.TileType.HOUSE_SMALL:
			return {
				"name": "Cozy Small House",
				"symbol": "—[ ⌂ ]—",
				"category": "Residential Load",
				"unit": "Kilowatt-hours (kWh)",
				"short_purpose": "Distributes electrical energy to household appliances, lighting, and heating.",
				"how_it_works": "Electricity from the power source feeds into the house service weatherhead, distributing current through breaker circuits to illuminate windows and power amenities.",
				"fun_fact": "The average residential home uses roughly 30 kilowatt-hours of electrical energy per day to keep all its lights, refrigerators, and electronics running!"
			}
		ElectricEnums.TileType.HOUSE_BIG:
			return {
				"name": "Suburban Villa Estate",
				"symbol": "—[ 🏡 ]—",
				"category": "High-Demand Residential Grid",
				"unit": "Kilowatt-hours (kWh)",
				"short_purpose": "Energizes multi-room lighting, air conditioning, and smart appliances.",
				"how_it_works": "Utilizes a heavy-duty split-phase service panel to supply high-amperage current across multiple living floors and outdoor circuits.",
				"fun_fact": "Modern smart suburban estates can intelligently combine rooftop solar generation with home battery banks to achieve near net-zero electrical grid demand!"
			}
		ElectricEnums.TileType.BUILDING:
			return {
				"name": "Metropolitan Skyscraper",
				"symbol": "—[ 🏢 ]—",
				"category": "Commercial Mega-Grid Consumer",
				"unit": "Megawatt-hours (MWh)",
				"short_purpose": "Powers commercial elevators, office illumination, HVAC chillers, and telecom antennas.",
				"how_it_works": "Receives high-voltage municipal feeder lines connected to internal step-down transformers to distribute megawatts of electricity across dozens of office floors.",
				"fun_fact": "A busy 100-story commercial skyscraper can consume as much electricity as a small town of 20,000 residents during peak business hours!"
			}
		_:
			return {
				"name": "Circuit Conduit",
				"symbol": "—[ ━━ ]—",
				"category": "Electrical Conductor",
				"unit": "Amperes (A)",
				"short_purpose": "Conducts electrical current between components with low resistance.",
				"how_it_works": "Made of high-purity copper coated with insulation. Copper contains loosely bound valence electrons that drift freely when electrical voltage is applied across the wire.",
				"fun_fact": "Although electrical signals and energy travel along wires at near the speed of light (~90% c), the individual electrons themselves actually drift forward at just a few centimeters per hour!"
			}

static func get_unlock_level(tile_type: int) -> int:
	match tile_type:
		ElectricEnums.TileType.BATTERY, ElectricEnums.TileType.SOLAR, ElectricEnums.TileType.BULB:
			return 1
		ElectricEnums.TileType.FAN:
			return 2
		ElectricEnums.TileType.HEATER:
			return 3
		ElectricEnums.TileType.HOUSE_SMALL:
			return 4
		ElectricEnums.TileType.RESISTOR:
			return 5
		ElectricEnums.TileType.VACUUM_TUBE:
			return 6
		ElectricEnums.TileType.CAPACITOR:
			return 7
		ElectricEnums.TileType.HOUSE_BIG:
			return 8
		ElectricEnums.TileType.TESLA_COIL:
			return 9
		ElectricEnums.TileType.BUILDING:
			return 10
		_:
			return 1

static func is_newly_unlocked_at_level(level_num: int) -> int:
	match level_num:
		1:
			return ElectricEnums.TileType.SOLAR
		2:
			return ElectricEnums.TileType.FAN
		3:
			return ElectricEnums.TileType.HEATER
		4:
			return ElectricEnums.TileType.HOUSE_SMALL
		5:
			return ElectricEnums.TileType.RESISTOR
		6:
			return ElectricEnums.TileType.VACUUM_TUBE
		7:
			return ElectricEnums.TileType.CAPACITOR
		8:
			return ElectricEnums.TileType.HOUSE_BIG
		9:
			return ElectricEnums.TileType.TESLA_COIL
		10:
			return ElectricEnums.TileType.BUILDING
		_:
			return -1

static func get_primary_component_for_level(level_num: int) -> int:
	# Returns the featured component for a given level
	var data := ElectricLevels.get_level(level_num)
	var tiles: Array = data.get("tiles", [])
	
	# Priority to highlight interesting components:
	var priority_types := [
		ElectricEnums.TileType.BUILDING,
		ElectricEnums.TileType.TESLA_COIL,
		ElectricEnums.TileType.HOUSE_BIG,
		ElectricEnums.TileType.HOUSE_SMALL,
		ElectricEnums.TileType.VACUUM_TUBE,
		ElectricEnums.TileType.CAPACITOR,
		ElectricEnums.TileType.RESISTOR,
		ElectricEnums.TileType.HEATER,
		ElectricEnums.TileType.FAN,
		ElectricEnums.TileType.SOLAR,
		ElectricEnums.TileType.BULB,
		ElectricEnums.TileType.BATTERY
	]
	
	for p_type in priority_types:
		for t in tiles:
			if int(t.get("type", 0)) == p_type:
				return p_type
				
	return ElectricEnums.TileType.BULB
