class_name GameDB
extends RefCounted
## Статическая база данных BALLISTIK: команды, классы техники и лимиты слотов, слои физики,
## уровни сложности ботов, позывные и общие математические утилиты.

# --- Слои физики (битовые маски) ---------------------------------------------------------------
const LAYER_WORLD := 1
const LAYER_UNITS := 2
const LAYER_STRUCTURES := 4
const MASK_DAMAGEABLE := LAYER_UNITS | LAYER_STRUCTURES

# --- Команды -----------------------------------------------------------------------------------
const TEAM_BLUE := 0
const TEAM_RED := 1
const NEUTRAL := -1
const TEAM_NAMES := ["СИНИЕ", "КРАСНЫЕ"]
const TEAM_COLORS := [Color(0.2, 0.72, 1.0), Color(1.0, 0.3, 0.24)]
const NEUTRAL_COLOR := Color(0.78, 0.78, 0.72)

# --- Карта -------------------------------------------------------------------------------------
const MAP_HALF := 3000.0            ## Половина размера игровой зоны (м)
const TERRAIN_HALF := 3800.0        ## Половина размера сгенерированного рельефа (м)
const GRAVITY := 9.8

# --- Категории техники -------------------------------------------------------------------------
enum Category { AIR, GROUND, NAVAL }

const CATEGORY_ORDER := [Category.AIR, Category.GROUND, Category.NAVAL]
const CATEGORY_TITLES := {
	Category.AIR: "Авиация",
	Category.GROUND: "Наземная ПВО",
	Category.NAVAL: "Военный Флот",
}
const CATEGORY_ICONS := {
	Category.AIR: "tab_air",
	Category.GROUND: "tab_ground",
	Category.NAVAL: "tab_naval",
}
const CATEGORY_SPAWN := {
	Category.AIR: "Аэродром · воздушный старт",
	Category.GROUND: "Береговые позиции",
	Category.NAVAL: "Причал военно-морской базы",
}

# --- Классы техники и лимиты слотов на команду ------------------------------------------------
const VEHICLE_ORDER := ["fighter", "bomber", "spaag", "sam", "boat"]
const STAT_NAMES := ["Скорость", "Живучесть", "Огневая мощь", "Дальность"]
const VEHICLES := {
	"fighter": {
		"category": Category.AIR,
		"names": ["МиГ-29", "МиГ-29"],
		"role": "Истребитель",
		"max_slots": 2,
		"score": 30,
		"icon": "fighter",
		"weapons": "ГШ-30-1 · 4× Р-73 · ЛТЦ",
		"desc": "Высокая скорость и манёвренность. Курсовая автопушка и ракеты «воздух-воздух» для перехвата бомбардировщиков и защиты неба.",
		"stats": [0.95, 0.35, 0.6, 0.7],
	},
	"bomber": {
		"category": Category.AIR,
		"names": ["Су-24М", "Су-24М"],
		"role": "Бомбардировщик",
		"max_slots": 1,
		"score": 40,
		"icon": "bomber",
		"weapons": "8× ФАБ-500 · 2× Х-59 · ЛТЦ",
		"desc": "Медленнее истребителя, но несёт тяжёлые бомбы и крылатые ракеты для уничтожения кораблей и береговой ПВО.",
		"stats": [0.6, 0.55, 1.0, 0.9],
	},
	"spaag": {
		"category": Category.GROUND,
		"names": ["Гепард", "Гепард"],
		"role": "Зенитная установка",
		"max_slots": 2,
		"score": 25,
		"icon": "spaag",
		"weapons": "2× 35-мм автопушки · РЛС сопровождения",
		"desc": "Скорострельные трассирующие пушки с неконтактными снарядами. Высокая плотность огня по низколетящим целям.",
		"stats": [0.35, 0.7, 0.75, 0.45],
	},
	"sam": {
		"category": Category.GROUND,
		"names": ["Patriot", "Бук-М1"],
		"role": "Зенитный ракетный комплекс",
		"max_slots": 1,
		"score": 35,
		"icon": "sam",
		"weapons": "4× ЗУР · РЛС захвата 7 км",
		"desc": "Дальнобойные зенитные управляемые ракеты с физикой разгона и радиолокационным захватом цели.",
		"stats": [0.25, 0.6, 0.9, 1.0],
	},
	"boat": {
		"category": Category.NAVAL,
		"names": ["Sea Baby", "G-5"],
		"role": "Бронекатер",
		"max_slots": 3,
		"score": 20,
		"icon": "boat",
		"weapons": "Пулемёт · 2× торпеды · баллистическая ракета",
		"desc": "Высокая манёвренность на воде. Торпеды против крупных кораблей и баллистические удары по суше и морю.",
		"stats": [0.8, 0.3, 0.8, 0.85],
	},
}
const WARSHIP_SCORE := 150

# --- Уровни сложности ботов --------------------------------------------------------------------
const DIFFICULTY_LEVELS := [
	{"name": "Новобранец", "aim_error_deg": 2.8, "reaction": 1.1, "detect": 0.8, "burst": 0.55},
	{"name": "Ветеран", "aim_error_deg": 1.5, "reaction": 0.65, "detect": 1.0, "burst": 0.8},
	{"name": "Ас", "aim_error_deg": 0.7, "reaction": 0.35, "detect": 1.2, "burst": 1.0},
]

const BOT_CALLSIGNS := [
	"Беркут", "Сокол", "Гром", "Вихрь", "Кречет", "Ястреб", "Тайфун", "Буран", "Шторм",
	"Молния", "Рубин", "Кобальт", "Сапсан", "Скиф", "Барс", "Кедр", "Прибой", "Зенит",
	"Штиль", "Гранит", "Аргон", "Орлан", "Кондор", "Фрегат",
]

const SIDES: Array[float] = [-1.0, 1.0]


# --- Данные техники ----------------------------------------------------------------------------
static func vehicle_info(type_id: String) -> Dictionary:
	return VEHICLES.get(type_id, {})


static func vehicle_name(type_id: String, team: int) -> String:
	if type_id == "warship":
		return "Эсминец"
	var info := vehicle_info(type_id)
	if info.is_empty():
		return "—"
	var names: Array = info["names"]
	return str(names[clampi(team, 0, names.size() - 1)])


static func vehicle_role(type_id: String) -> String:
	return str(vehicle_info(type_id).get("role", ""))


static func max_slots(type_id: String) -> int:
	return int(vehicle_info(type_id).get("max_slots", 0))


static func category_of(type_id: String) -> int:
	if type_id == "warship":
		return Category.NAVAL
	return int(vehicle_info(type_id).get("category", Category.GROUND))


static func types_in_category(category: int) -> Array[String]:
	var result: Array[String] = []
	for t: String in VEHICLE_ORDER:
		if category_of(t) == category:
			result.append(t)
	return result


static func total_slots() -> int:
	var total := 0
	for t: String in VEHICLE_ORDER:
		total += max_slots(t)
	return total


static func score_for_vehicle(type_id: String) -> int:
	if type_id == "warship":
		return WARSHIP_SCORE
	return int(vehicle_info(type_id).get("score", 10))


static func difficulty(level: int) -> Dictionary:
	return DIFFICULTY_LEVELS[clampi(level, 0, DIFFICULTY_LEVELS.size() - 1)]


# --- Команды -----------------------------------------------------------------------------------
static func team_color(team: int) -> Color:
	if team == TEAM_BLUE or team == TEAM_RED:
		return TEAM_COLORS[team]
	return NEUTRAL_COLOR


static func team_name(team: int) -> String:
	if team == TEAM_BLUE or team == TEAM_RED:
		return TEAM_NAMES[team]
	return "НЕЙТРАЛЫ"


static func enemy_team(team: int) -> int:
	return TEAM_RED if team == TEAM_BLUE else TEAM_BLUE


static func team_side(team: int) -> float:
	return -1.0 if team == TEAM_BLUE else 1.0


# --- Математика --------------------------------------------------------------------------------
## Базис, у которого ось -Z смотрит вдоль forward (соглашение Godot «вперёд = -Z»).
static func basis_from_forward(forward: Vector3, up_hint: Vector3 = Vector3.UP) -> Basis:
	if forward.length_squared() < 0.000001:
		return Basis()
	var f := forward.normalized()
	var up := up_hint
	if absf(f.dot(up.normalized())) > 0.985:
		up = Vector3.FORWARD if absf(f.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	return Basis.looking_at(f, up)


## Поворачивает направление from_dir к to_dir не более чем на max_angle радиан.
static func rotate_toward(from_dir: Vector3, to_dir: Vector3, max_angle: float) -> Vector3:
	var a := from_dir.normalized()
	var b := to_dir.normalized()
	var angle := a.angle_to(b)
	if angle <= max_angle or angle < 0.00001:
		return b
	var axis := a.cross(b)
	if axis.length_squared() < 0.0000001:
		axis = a.cross(Vector3.UP)
		if axis.length_squared() < 0.0000001:
			axis = a.cross(Vector3.RIGHT)
	return a.rotated(axis.normalized(), max_angle)


## Случайное отклонение направления в пределах конуса spread_deg (разброс стрельбы).
static func spread_direction(dir: Vector3, spread_deg: float, rng: RandomNumberGenerator) -> Vector3:
	if spread_deg <= 0.0:
		return dir.normalized()
	var b := basis_from_forward(dir)
	var ang := deg_to_rad(spread_deg) * sqrt(rng.randf())
	var phi := rng.randf() * TAU
	var local := Vector3(sin(ang) * cos(phi), sin(ang) * sin(phi), -cos(ang))
	return (b * local).normalized()


## Угол рыскания направления (0 — вдоль -Z, положительный — поворот влево).
static func yaw_of(dir: Vector3) -> float:
	return atan2(-dir.x, -dir.z)


static func dir_from_yaw_pitch(yaw: float, pitch: float) -> Vector3:
	return Vector3(-sin(yaw) * cos(pitch), sin(pitch), -cos(yaw) * cos(pitch))


static func flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


static func flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


static func format_distance(meters: float) -> String:
	if meters >= 1000.0:
		return "%.1f км" % (meters / 1000.0)
	return "%d м" % int(meters)


static func format_time(seconds: float) -> String:
	var s := maxi(int(ceil(seconds)), 0)
	return "%02d:%02d" % [floori(s / 60.0), s % 60]


static func now() -> float:
	return Time.get_ticks_msec() * 0.001
