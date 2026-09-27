class_name MapPresets
extends RefCounted
## Каталог карт BALLISTIK. Карта задаёт форму суши и рельеф, климат (палитра, растительность, поля),
## освещение и погоду, а также расположение базы команды 0; база команды 1 — зеркальная копия
## (mirror: "x" — отражение по оси X, "point" — центральная симметрия). Координаты — метры,
## X — восток, Z — юг. Всё остальное (рельеф, леса, облака) генерируется процедурно из зерна карты.

const ORDER: Array[String] = ["coast", "archipelago", "desert", "fjords", "strait"]
const RANDOM_ID := "random"

## Палитры климатических зон: цвета поверхности, деревья, поля.
const BIOMES := {
	"temperate": {
		"grass": Color(0.24, 0.33, 0.14), "grass2": Color(0.33, 0.39, 0.17), "dry": Color(0.45, 0.43, 0.25),
		"forest": Color(0.13, 0.21, 0.09), "dirt": Color(0.36, 0.3, 0.22), "rock": Color(0.42, 0.41, 0.39),
		"rock2": Color(0.3, 0.29, 0.28), "sand": Color(0.72, 0.66, 0.51), "snow": Color(0.92, 0.94, 0.97),
		"fields": [Color(0.48, 0.47, 0.22), Color(0.33, 0.42, 0.16), Color(0.42, 0.33, 0.22), Color(0.6, 0.54, 0.3), Color(0.27, 0.36, 0.14)],
		"trees": {"broadleaf": Color(0.2, 0.3, 0.11), "pine": Color(0.12, 0.22, 0.12), "bush": Color(0.22, 0.3, 0.12)},
		"trunk": Color(0.3, 0.23, 0.17),
	},
	"tropical": {
		"grass": Color(0.2, 0.36, 0.1), "grass2": Color(0.3, 0.43, 0.13), "dry": Color(0.46, 0.44, 0.2),
		"forest": Color(0.1, 0.24, 0.07), "dirt": Color(0.45, 0.3, 0.19), "rock": Color(0.47, 0.44, 0.4),
		"rock2": Color(0.35, 0.31, 0.27), "sand": Color(0.86, 0.8, 0.64), "snow": Color(0.9, 0.9, 0.9),
		"fields": [Color(0.36, 0.46, 0.14), Color(0.52, 0.5, 0.22), Color(0.3, 0.4, 0.12)],
		"trees": {"palm": Color(0.22, 0.36, 0.12), "broadleaf": Color(0.14, 0.3, 0.09), "bush": Color(0.2, 0.34, 0.1)},
		"trunk": Color(0.42, 0.34, 0.25),
	},
	"desert": {
		"grass": Color(0.56, 0.49, 0.33), "grass2": Color(0.64, 0.55, 0.38), "dry": Color(0.5, 0.45, 0.29),
		"forest": Color(0.36, 0.38, 0.2), "dirt": Color(0.58, 0.44, 0.3), "rock": Color(0.62, 0.47, 0.35),
		"rock2": Color(0.5, 0.37, 0.28), "sand": Color(0.82, 0.72, 0.53), "snow": Color(0.95, 0.94, 0.9),
		"fields": [Color(0.31, 0.42, 0.16), Color(0.43, 0.48, 0.2), Color(0.6, 0.52, 0.3), Color(0.26, 0.37, 0.14), Color(0.52, 0.42, 0.28)],
		"trees": {"palm": Color(0.28, 0.36, 0.14), "bush": Color(0.36, 0.38, 0.2)},
		"trunk": Color(0.46, 0.38, 0.28),
	},
	"arctic": {
		"grass": Color(0.26, 0.3, 0.19), "grass2": Color(0.34, 0.35, 0.24), "dry": Color(0.4, 0.38, 0.3),
		"forest": Color(0.1, 0.16, 0.1), "dirt": Color(0.3, 0.27, 0.23), "rock": Color(0.38, 0.39, 0.4),
		"rock2": Color(0.25, 0.26, 0.28), "sand": Color(0.52, 0.5, 0.45), "snow": Color(0.93, 0.95, 0.98),
		"fields": [Color(0.34, 0.37, 0.2), Color(0.4, 0.38, 0.26)],
		"trees": {"pine": Color(0.09, 0.17, 0.1), "bush": Color(0.2, 0.25, 0.14)},
		"trunk": Color(0.26, 0.2, 0.16),
	},
	"mediterranean": {
		"grass": Color(0.35, 0.37, 0.17), "grass2": Color(0.45, 0.43, 0.22), "dry": Color(0.56, 0.49, 0.3),
		"forest": Color(0.17, 0.24, 0.1), "dirt": Color(0.5, 0.38, 0.26), "rock": Color(0.58, 0.54, 0.47),
		"rock2": Color(0.44, 0.4, 0.35), "sand": Color(0.8, 0.72, 0.56), "snow": Color(0.94, 0.94, 0.95),
		"fields": [Color(0.52, 0.48, 0.24), Color(0.38, 0.42, 0.18), Color(0.58, 0.44, 0.28), Color(0.64, 0.58, 0.34)],
		"trees": {"cypress": Color(0.13, 0.2, 0.09), "broadleaf": Color(0.22, 0.29, 0.12), "bush": Color(0.28, 0.32, 0.15)},
		"trunk": Color(0.34, 0.27, 0.2),
	},
}

const MAPS := {
	"coast": {
		"name": "Северное побережье",
		"subtitle": "Умеренный климат · утро",
		"desc": "Холмы и смешанные леса спускаются к морю. Базы на флангах побережья; в центре — деревни, поля и остров с маяком.",
		"shape": "coast",
		"mirror": "x",
		"bounds": 7200.0,
		"world": 13500.0,
		"coast": {"z0": 120.0, "a1": 520.0, "f1": 0.00048, "a2": 210.0, "f2": 0.00131, "noise": 160.0},
		"terrain": {"hills": 150.0, "mountains": 560.0, "mountain_mask": 0.55, "mountain_start": 1600.0, "sea_floor": -48.0, "shelf": 900.0, "coast_noise": 150.0, "warp": 650.0},
		"islands": [
			{"c": Vector2(0.0, 2600.0), "r": 520.0, "h": 46.0},
			{"c": Vector2(-1900.0, 3300.0), "r": 260.0, "h": 22.0, "sym": true},
		],
		"biome": "temperate",
		"trees": {"kinds": ["broadleaf", "pine"], "density": 1.0, "treeline": 480.0, "forest": 0.52},
		"fields": 0.55,
		"fields_max_h": 230.0,
		"field_angle": 0.35,
		"snow_line": 760.0,
		"sky": {
			"sun_elevation": 25.0, "sun_azimuth": 128.0, "sun_energy": 1.35, "sun_color": Color(1.0, 0.91, 0.8),
			"top": Color(0.15, 0.33, 0.66), "horizon": Color(0.63, 0.74, 0.87), "ground": Color(0.37, 0.41, 0.44),
			"fog": Color(0.64, 0.73, 0.84), "fog_density": 0.000085, "haze": 0.0009, "ambient": 1.0, "exposure": 1.0,
		},
		"clouds": {"coverage": 0.5, "base": 1350.0, "thickness": 520.0, "high": 0.42, "tint": Color(1.0, 0.98, 0.95)},
		"water": {"deep": Color(0.025, 0.1, 0.15), "shallow": Color(0.07, 0.27, 0.28)},
		"base": {
			"airfield": Vector2(-4700.0, -2350.0), "runway": Vector2(1.0, 0.0),
			"hq": Vector2(-5750.0, -1150.0),
			"radar": Vector2(-3950.0, -1450.0),
			"ad": Vector2(-3050.0, -330.0),
			"pier": Vector2(-3900.0, 40.0), "pier_dir": Vector2(0.0, 1.0),
			"warship": Vector2(-3350.0, 1450.0),
			"bunkers": [Vector2(-2350.0, -30.0), Vector2(-1500.0, -10.0)],
			"defense": [Vector2(-4300.0, -1850.0), Vector2(-5300.0, -800.0), Vector2(-3500.0, -950.0), Vector2(-2600.0, -600.0)],
		},
		"neutral": {
			"villages": [Vector2(0.0, -1900.0), Vector2(0.0, -4700.0)],
			"towns": [Vector2(-2200.0, -3600.0), Vector2(2200.0, -3600.0), Vector2(-1200.0, -700.0), Vector2(1200.0, -700.0)],
			"lighthouses": [Vector2(0.0, 2600.0)],
			"oil_rigs": [Vector2(0.0, 4700.0)],
		},
	},
	"archipelago": {
		"name": "Тропический архипелаг",
		"subtitle": "Тропики · полдень",
		"desc": "Гористые острова в бирюзовом море, пальмовые леса и белые пляжи. Каждая сторона удерживает свой большой остров; между ними — цепь островков.",
		"shape": "islands",
		"mirror": "x",
		"bounds": 7400.0,
		"world": 13500.0,
		"terrain": {"hills": 90.0, "mountains": 520.0, "mountain_mask": 0.3, "mountain_start": 500.0, "sea_floor": -60.0, "shelf": 650.0, "coast_noise": 150.0, "warp": 420.0},
		"islands": [
			{"c": Vector2(-5200.0, 0.0), "r": 2650.0, "h": 0.0, "sym": true},
			{"c": Vector2(0.0, 0.0), "r": 950.0, "h": 0.0},
			{"c": Vector2(0.0, -3700.0), "r": 760.0, "h": 0.0},
			{"c": Vector2(0.0, 3900.0), "r": 700.0, "h": 0.0},
			{"c": Vector2(-2500.0, -2700.0), "r": 520.0, "h": 0.0, "sym": true},
			{"c": Vector2(-2300.0, 3100.0), "r": 470.0, "h": 0.0, "sym": true},
			{"c": Vector2(-1300.0, 1500.0), "r": 260.0, "h": 0.0, "sym": true},
			{"c": Vector2(-3700.0, -4600.0), "r": 600.0, "h": 0.0, "sym": true},
			{"c": Vector2(-3900.0, 4700.0), "r": 560.0, "h": 0.0, "sym": true},
			{"c": Vector2(-9800.0, -6200.0), "r": 1900.0, "h": 0.0, "sym": true},
			{"c": Vector2(-8200.0, 7600.0), "r": 1500.0, "h": 0.0, "sym": true},
			{"c": Vector2(0.0, -10200.0), "r": 1700.0, "h": 0.0},
		],
		"biome": "tropical",
		"trees": {"kinds": ["palm", "broadleaf"], "density": 1.25, "treeline": 600.0, "forest": 0.62},
		"fields": 0.2,
		"fields_max_h": 60.0,
		"field_angle": -0.2,
		"snow_line": 5000.0,
		"sky": {
			"sun_elevation": 63.0, "sun_azimuth": 205.0, "sun_energy": 1.45, "sun_color": Color(1.0, 0.97, 0.92),
			"top": Color(0.09, 0.3, 0.7), "horizon": Color(0.6, 0.77, 0.92), "ground": Color(0.3, 0.42, 0.5),
			"fog": Color(0.66, 0.78, 0.9), "fog_density": 0.00007, "haze": 0.0012, "ambient": 1.05, "exposure": 0.95,
		},
		"clouds": {"coverage": 0.58, "base": 1150.0, "thickness": 650.0, "high": 0.3, "tint": Color(1.0, 1.0, 1.0)},
		"water": {"deep": Color(0.015, 0.1, 0.2), "shallow": Color(0.06, 0.52, 0.5)},
		"base": {
			"airfield": Vector2(-5100.0, -950.0), "runway": Vector2(1.0, 0.0),
			"hq": Vector2(-6250.0, -1650.0),
			"radar": Vector2(-4250.0, -1950.0),
			"ad": Vector2(-3150.0, -700.0),
			"pier": Vector2(-2700.0, 450.0), "pier_dir": Vector2(1.0, 0.0),
			"warship": Vector2(-1650.0, 1050.0),
			"bunkers": [Vector2(-2750.0, -350.0), Vector2(-2900.0, 1250.0)],
			"defense": [Vector2(-4400.0, -500.0), Vector2(-5800.0, -1300.0), Vector2(-3600.0, 300.0), Vector2(-4700.0, -2000.0)],
		},
		"neutral": {
			"villages": [Vector2(0.0, 150.0), Vector2(0.0, -3650.0)],
			"towns": [Vector2(-6000.0, 900.0), Vector2(6000.0, 900.0), Vector2(0.0, 3850.0)],
			"lighthouses": [Vector2(0.0, -350.0), Vector2(0.0, 4250.0)],
			"oil_rigs": [],
		},
	},
	"desert": {
		"name": "Пустынный залив",
		"subtitle": "Засушливый климат · дымка",
		"desc": "Выжженные плато и столовые горы вокруг широкого залива. У воды — орошаемые поля и пальмовые рощи, в глубине — каньоны.",
		"shape": "gulf",
		"mirror": "x",
		"bounds": 7400.0,
		"world": 13500.0,
		"gulf": {"top": -3600.0, "w0": 2300.0, "k": 0.2},
		"terrain": {"hills": 120.0, "mountains": 380.0, "mountain_mask": 0.5, "mountain_start": 900.0, "sea_floor": -40.0, "shelf": 800.0, "coast_noise": 170.0, "terrace": 42.0, "warp": 750.0},
		"islands": [
			{"c": Vector2(0.0, 1500.0), "r": 420.0, "h": 0.0},
			{"c": Vector2(0.0, 4600.0), "r": 300.0, "h": 0.0},
		],
		"biome": "desert",
		"trees": {"kinds": ["palm", "bush"], "density": 0.45, "treeline": 260.0, "forest": 0.34, "near_water": true},
		"fields": 0.9,
		"fields_max_h": 38.0,
		"field_angle": 0.12,
		"snow_line": 5000.0,
		"sky": {
			"sun_elevation": 38.0, "sun_azimuth": 245.0, "sun_energy": 1.4, "sun_color": Color(1.0, 0.93, 0.8),
			"top": Color(0.24, 0.43, 0.7), "horizon": Color(0.8, 0.79, 0.74), "ground": Color(0.55, 0.49, 0.4),
			"fog": Color(0.79, 0.75, 0.67), "fog_density": 0.00013, "haze": 0.0014, "ambient": 1.0, "exposure": 0.92,
		},
		"clouds": {"coverage": 0.22, "base": 1900.0, "thickness": 380.0, "high": 0.55, "tint": Color(1.0, 0.97, 0.92)},
		"water": {"deep": Color(0.02, 0.12, 0.2), "shallow": Color(0.12, 0.42, 0.42)},
		"base": {
			"airfield": Vector2(-5350.0, -1400.0), "runway": Vector2(0.0, 1.0),
			"hq": Vector2(-6300.0, 300.0),
			"radar": Vector2(-4300.0, -3500.0),
			"ad": Vector2(-3900.0, 450.0),
			"pier": Vector2(-3380.0, 1150.0), "pier_dir": Vector2(1.0, 0.0),
			"warship": Vector2(-2100.0, 2600.0),
			"bunkers": [Vector2(-3450.0, 2100.0), Vector2(-3000.0, -900.0)],
			"defense": [Vector2(-4800.0, -700.0), Vector2(-5600.0, 700.0), Vector2(-4200.0, -2600.0), Vector2(-3700.0, 1600.0)],
		},
		"neutral": {
			"villages": [Vector2(0.0, -4700.0), Vector2(0.0, 1500.0)],
			"towns": [Vector2(-3700.0, 3600.0), Vector2(3700.0, 3600.0), Vector2(-2400.0, -3900.0), Vector2(2400.0, -3900.0)],
			"lighthouses": [Vector2(0.0, 4600.0)],
			"oil_rigs": [Vector2(0.0, 6000.0)],
		},
	},
	"fjords": {
		"name": "Северные фьорды",
		"subtitle": "Субарктика · пасмурно",
		"desc": "Заснеженные хребты и глубокие фьорды. Базы в долинах на концах главного фьорда, флот выходит к морю через южный пролив.",
		"shape": "fjords",
		"mirror": "x",
		"bounds": 7000.0,
		"world": 13000.0,
		"fjord": {"z0": -700.0, "a": 420.0, "f": 0.00058, "hw": 720.0, "hw_a": 220.0, "south_w": 620.0, "sea_z": 5400.0, "branch_x": 2600.0},
		"terrain": {"hills": 170.0, "mountains": 820.0, "mountain_mask": 0.42, "mountain_start": 450.0, "sea_floor": -120.0, "shelf": 260.0, "coast_noise": 130.0, "cliff": 55.0, "warp": 1250.0},
		"islands": [],
		"biome": "arctic",
		"trees": {"kinds": ["pine"], "density": 1.1, "treeline": 380.0, "forest": 0.5},
		"fields": 0.25,
		"fields_max_h": 70.0,
		"field_angle": 0.0,
		"snow_line": 560.0,
		"sky": {
			"sun_elevation": 17.0, "sun_azimuth": 160.0, "sun_energy": 0.95, "sun_color": Color(0.96, 0.91, 0.86),
			"top": Color(0.33, 0.43, 0.56), "horizon": Color(0.73, 0.77, 0.81), "ground": Color(0.42, 0.45, 0.48),
			"fog": Color(0.7, 0.74, 0.79), "fog_density": 0.00012, "haze": 0.0011, "ambient": 1.15, "exposure": 1.05,
		},
		"clouds": {"coverage": 0.78, "base": 1250.0, "thickness": 700.0, "high": 0.75, "tint": Color(0.93, 0.95, 0.98)},
		"water": {"deep": Color(0.02, 0.07, 0.1), "shallow": Color(0.06, 0.18, 0.2)},
		"base": {
			"airfield": Vector2(-4700.0, -3350.0), "runway": Vector2(1.0, 0.0),
			"hq": Vector2(-6000.0, -2700.0),
			"radar": Vector2(-3500.0, -3800.0),
			"ad": Vector2(-3300.0, -2150.0),
			"pier": Vector2(-4300.0, -1900.0), "pier_dir": Vector2(0.0, 1.0),
			"warship": Vector2(-4300.0, -950.0),
			"bunkers": [Vector2(-2400.0, -1850.0), Vector2(-5300.0, -1950.0)],
			"defense": [Vector2(-4200.0, -2800.0), Vector2(-5600.0, -2300.0), Vector2(-3000.0, -2600.0)],
		},
		"neutral": {
			"villages": [Vector2(0.0, -2100.0)],
			"towns": [Vector2(-900.0, 3200.0), Vector2(900.0, 3200.0), Vector2(-2600.0, -3700.0), Vector2(2600.0, -3700.0)],
			"lighthouses": [Vector2(-800.0, 5150.0)],
			"oil_rigs": [],
		},
	},
	"strait": {
		"name": "Закатный пролив",
		"subtitle": "Средиземноморье · закат",
		"desc": "Широкий пролив между двумя берегами на закате. Стороны базируются на противоположных берегах — море в центре становится главной ареной.",
		"shape": "strait",
		"mirror": "point",
		"bounds": 7200.0,
		"world": 13500.0,
		"strait": {"a": 700.0, "f": 0.00034, "w": 1900.0, "w_a": 380.0, "w_f": 0.00078},
		"terrain": {"hills": 170.0, "mountains": 470.0, "mountain_mask": 0.5, "mountain_start": 1300.0, "sea_floor": -55.0, "shelf": 700.0, "coast_noise": 150.0, "warp": 520.0},
		"islands": [
			{"c": Vector2(0.0, 0.0), "r": 380.0, "h": 0.0},
			{"c": Vector2(-1700.0, 900.0), "r": 240.0, "h": 0.0, "sym": true},
		],
		"biome": "mediterranean",
		"trees": {"kinds": ["cypress", "broadleaf"], "density": 0.8, "treeline": 520.0, "forest": 0.45},
		"fields": 0.5,
		"fields_max_h": 200.0,
		"field_angle": -0.5,
		"snow_line": 5000.0,
		"sky": {
			"sun_elevation": 6.5, "sun_azimuth": 283.0, "sun_energy": 1.25, "sun_color": Color(1.0, 0.63, 0.38),
			"top": Color(0.13, 0.17, 0.36), "horizon": Color(0.96, 0.58, 0.38), "ground": Color(0.35, 0.28, 0.3),
			"fog": Color(0.66, 0.5, 0.46), "fog_density": 0.0001, "haze": 0.0008, "ambient": 0.95, "exposure": 1.1,
		},
		"clouds": {"coverage": 0.36, "base": 1500.0, "thickness": 420.0, "high": 0.5, "tint": Color(1.0, 0.8, 0.66)},
		"water": {"deep": Color(0.03, 0.07, 0.13), "shallow": Color(0.09, 0.24, 0.28)},
		"base": {
			"airfield": Vector2(-4500.0, -4750.0), "runway": Vector2(1.0, 0.0),
			"hq": Vector2(-5850.0, -3700.0),
			"radar": Vector2(-2900.0, -4300.0),
			"ad": Vector2(-2600.0, -2700.0),
			"pier": Vector2(-3700.0, -2200.0), "pier_dir": Vector2(0.0, 1.0),
			"warship": Vector2(-3400.0, -1050.0),
			"bunkers": [Vector2(-1700.0, -2520.0), Vector2(-4700.0, -2350.0)],
			"defense": [Vector2(-4300.0, -4200.0), Vector2(-5400.0, -3100.0), Vector2(-3300.0, -3200.0)],
		},
		"neutral": {
			"villages": [Vector2(-1300.0, -3800.0), Vector2(1300.0, 3800.0)],
			"towns": [Vector2(-5200.0, -2600.0), Vector2(5200.0, 2600.0), Vector2(900.0, -3300.0), Vector2(-900.0, 3300.0)],
			"lighthouses": [Vector2(0.0, 0.0)],
			"oil_rigs": [],
		},
	},
}


static func get_map(map_id: String) -> Dictionary:
	return MAPS.get(map_id, MAPS["coast"])


static func map_name(map_id: String) -> String:
	if map_id == RANDOM_ID:
		return "Случайная карта"
	return str(get_map(map_id).get("name", map_id))


static func biome(map_id: String) -> Dictionary:
	return BIOMES.get(str(get_map(map_id).get("biome", "temperate")), BIOMES["temperate"])


static func resolve(map_id: String, rng: RandomNumberGenerator) -> String:
	if MAPS.has(map_id):
		return map_id
	return ORDER[rng.randi() % ORDER.size()]
