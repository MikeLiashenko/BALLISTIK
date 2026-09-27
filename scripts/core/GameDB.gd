class_name GameDB
extends RefCounted
## Статическая база данных BALLISTIK: команды, классы и роли техники, лимиты слотов, лётные данные
## и вооружение самолётов, уровни сложности ботов, позывные и общие математические утилиты.

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
const MAP_HALF := 7000.0            ## Половина зоны боя по умолчанию (фактическая — MapLayout.bounds)
const GRAVITY := 9.8

# --- Категории, роли и эпохи --------------------------------------------------------------------
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
const ROLES := ["fighter", "strike", "spaag", "sam", "boat"]
const ROLE_TITLES := {"fighter": "Истребитель", "strike": "Ударный самолёт", "spaag": "Зенитная установка", "sam": "Зенитный ракетный комплекс", "boat": "Бронекатер"}
## Ограничение числа машин одной роли в команде (дополнительно к лимиту слотов каждого типа).
const ROLE_LIMITS := {"fighter": 5, "strike": 3, "spaag": 2, "sam": 1, "boat": 3}
const ERA_NAMES := ["Смешанная", "Поршневая (1940-е)", "Реактивная"]
const NATION_NAMES := {"su": "СССР", "de": "Германия", "us": "США", "uk": "Великобритания", "jp": "Япония", "fr": "Франция"}

## Старые идентификаторы (аргументы автотестов).
const ALIASES := {"fighter": "mig29", "bomber": "su24m"}

const STAT_NAMES := ["Скорость", "Живучесть", "Огневая мощь", "Манёвренность"]

# --- Техника ------------------------------------------------------------------------------------
const VEHICLES := {
	# ============ Поршневые истребители ============
	"bf109": {
		"category": Category.AIR, "role": "fighter", "era": "prop", "nation": "de", "engine": "prop",
		"names": ["Bf 109 G-6", "Bf 109 G-6"], "max_slots": 1, "score": 25, "icon": "prop_fighter",
		"weapons": "MG 151/20 · 2× MG 131 · SC 250",
		"desc": "Лёгкий и быстрый истребитель с мотор-пушкой. Отличная скороподъёмность, стремительные атаки сверху.",
		"stats": [0.62, 0.35, 0.55, 0.72],
		"flight": {"min": 46.0, "cruise": 125.0, "max": 178.0, "thrust": 27.0, "pitch": 1.75, "roll": 3.5, "yaw": 0.55},
		"hp": 115.0, "hit_radius": 5.0, "collision": Vector3(10.0, 2.6, 9.2), "camera": Vector2(19.0, 4.6),
		"primary": {"type": "guns", "name": "MG 151/20 + 2× MG 131", "interval": 0.075, "damage": 9.5, "speed": 800.0, "drag": 0.0004, "magazine": 160, "reload": 4.0, "spread": 0.4},
		"secondary": {"type": "bombs", "name": "SC 250", "count": 1, "interval": 0.5, "reload": 18.0, "damage": 230.0, "blast": 24.0},
		"flares": 0,
	},
	"fw190": {
		"category": Category.AIR, "role": "fighter", "era": "prop", "nation": "de", "engine": "radial",
		"names": ["Fw 190 A-8", "Fw 190 A-8"], "max_slots": 1, "score": 25, "icon": "prop_fighter",
		"weapons": "4× MG 151/20 · 2× MG 131 · SC 250",
		"desc": "Прочный истребитель с мощным звездообразным мотором и тяжёлым залпом четырёх пушек. Быстрый крен.",
		"stats": [0.64, 0.55, 0.78, 0.62],
		"flight": {"min": 50.0, "cruise": 128.0, "max": 182.0, "thrust": 27.5, "pitch": 1.55, "roll": 4.1, "yaw": 0.5},
		"hp": 145.0, "hit_radius": 5.0, "collision": Vector3(10.5, 2.8, 9.0), "camera": Vector2(19.0, 4.6),
		"primary": {"type": "guns", "name": "4× MG 151/20 + 2× MG 131", "interval": 0.055, "damage": 10.0, "speed": 790.0, "drag": 0.00042, "magazine": 180, "reload": 4.5, "spread": 0.45},
		"secondary": {"type": "bombs", "name": "SC 250", "count": 1, "interval": 0.5, "reload": 18.0, "damage": 230.0, "blast": 24.0},
		"flares": 0,
	},
	"yak9": {
		"category": Category.AIR, "role": "fighter", "era": "prop", "nation": "su", "engine": "prop",
		"names": ["Як-9Т", "Як-9Т"], "max_slots": 1, "score": 25, "icon": "prop_fighter",
		"weapons": "НС-37 · УБС · 2× ФАБ-100",
		"desc": "Манёвренный фронтовой истребитель с 37-мм мотор-пушкой: немногие попадания решают исход боя.",
		"stats": [0.6, 0.38, 0.7, 0.78],
		"flight": {"min": 44.0, "cruise": 124.0, "max": 172.0, "thrust": 26.0, "pitch": 1.85, "roll": 3.5, "yaw": 0.58},
		"hp": 110.0, "hit_radius": 5.0, "collision": Vector3(10.0, 2.6, 8.8), "camera": Vector2(19.0, 4.6),
		"primary": {"type": "guns", "name": "НС-37 + УБС", "interval": 0.11, "damage": 16.0, "speed": 760.0, "drag": 0.00045, "magazine": 80, "reload": 4.5, "spread": 0.35},
		"secondary": {"type": "bombs", "name": "ФАБ-100", "count": 2, "interval": 0.3, "reload": 14.0, "damage": 150.0, "blast": 18.0},
		"flares": 0,
	},
	"la5": {
		"category": Category.AIR, "role": "fighter", "era": "prop", "nation": "su", "engine": "radial",
		"names": ["Ла-5ФН", "Ла-5ФН"], "max_slots": 1, "score": 25, "icon": "prop_fighter",
		"weapons": "2× ШВАК · 4× РС-82",
		"desc": "Деревянный истребитель с мотором воздушного охлаждения: живуч, быстр у земли, несёт реактивные снаряды.",
		"stats": [0.62, 0.5, 0.62, 0.72],
		"flight": {"min": 47.0, "cruise": 126.0, "max": 176.0, "thrust": 26.5, "pitch": 1.8, "roll": 3.6, "yaw": 0.55},
		"hp": 130.0, "hit_radius": 5.0, "collision": Vector3(10.0, 2.7, 8.8), "camera": Vector2(19.0, 4.6),
		"primary": {"type": "guns", "name": "2× ШВАК", "interval": 0.07, "damage": 9.0, "speed": 780.0, "drag": 0.00042, "magazine": 170, "reload": 4.0, "spread": 0.4},
		"secondary": {"type": "rockets", "name": "РС-82", "count": 4, "interval": 0.22, "reload": 12.0, "damage": 95.0, "blast": 9.0, "speed": 360.0},
		"flares": 0,
	},
	"p51": {
		"category": Category.AIR, "role": "fighter", "era": "prop", "nation": "us", "engine": "prop",
		"names": ["P-51D Mustang", "P-51D Mustang"], "max_slots": 1, "score": 25, "icon": "prop_fighter",
		"weapons": "6× M2 Browning · 6× HVAR",
		"desc": "Скоростной дальний истребитель сопровождения с каплевидным фонарём. Лучший на высоте и в разгоне.",
		"stats": [0.7, 0.42, 0.66, 0.6],
		"flight": {"min": 50.0, "cruise": 135.0, "max": 192.0, "thrust": 28.0, "pitch": 1.6, "roll": 3.3, "yaw": 0.5},
		"hp": 125.0, "hit_radius": 5.2, "collision": Vector3(11.3, 2.8, 9.8), "camera": Vector2(20.0, 4.8),
		"primary": {"type": "guns", "name": "6× M2 Browning", "interval": 0.05, "damage": 7.0, "speed": 870.0, "drag": 0.00035, "magazine": 240, "reload": 4.0, "spread": 0.45},
		"secondary": {"type": "rockets", "name": "HVAR", "count": 6, "interval": 0.2, "reload": 14.0, "damage": 110.0, "blast": 10.0, "speed": 420.0},
		"flares": 0,
	},
	"p40": {
		"category": Category.AIR, "role": "fighter", "era": "prop", "nation": "us", "engine": "prop",
		"names": ["P-40E Warhawk", "P-40E Warhawk"], "max_slots": 1, "score": 25, "icon": "prop_fighter",
		"weapons": "6× M2 Browning · бомба 500 lb",
		"desc": "Надёжный «Уорхок» с подфюзеляжным радиатором: прочный, хорошо пикирует, опасен на встречных курсах.",
		"stats": [0.56, 0.55, 0.66, 0.55],
		"flight": {"min": 45.0, "cruise": 118.0, "max": 164.0, "thrust": 24.5, "pitch": 1.6, "roll": 3.2, "yaw": 0.52},
		"hp": 140.0, "hit_radius": 5.2, "collision": Vector3(11.4, 3.0, 9.7), "camera": Vector2(20.0, 4.8),
		"primary": {"type": "guns", "name": "6× M2 Browning", "interval": 0.05, "damage": 7.0, "speed": 870.0, "drag": 0.00035, "magazine": 240, "reload": 4.0, "spread": 0.45},
		"secondary": {"type": "bombs", "name": "AN-M64 500 lb", "count": 1, "interval": 0.5, "reload": 18.0, "damage": 240.0, "blast": 24.0},
		"flares": 0,
	},
	"spitfire": {
		"category": Category.AIR, "role": "fighter", "era": "prop", "nation": "uk", "engine": "prop",
		"names": ["Spitfire Mk IX", "Spitfire Mk IX"], "max_slots": 1, "score": 25, "icon": "prop_fighter",
		"weapons": "2× Hispano · 2× M2 · 2× 250 lb",
		"desc": "Эллиптическое крыло и великолепная горизонтальная манёвренность — король виражного боя.",
		"stats": [0.62, 0.36, 0.64, 0.86],
		"flight": {"min": 42.0, "cruise": 125.0, "max": 180.0, "thrust": 26.5, "pitch": 1.95, "roll": 3.3, "yaw": 0.58},
		"hp": 110.0, "hit_radius": 5.0, "collision": Vector3(11.2, 2.6, 9.5), "camera": Vector2(19.0, 4.6),
		"primary": {"type": "guns", "name": "2× Hispano + 2× M2", "interval": 0.065, "damage": 9.5, "speed": 840.0, "drag": 0.0004, "magazine": 160, "reload": 4.0, "spread": 0.4},
		"secondary": {"type": "bombs", "name": "250 lb GP", "count": 2, "interval": 0.3, "reload": 15.0, "damage": 140.0, "blast": 17.0},
		"flares": 0,
	},
	"zero": {
		"category": Category.AIR, "role": "fighter", "era": "prop", "nation": "jp", "engine": "radial",
		"names": ["A6M5 Zero", "A6M5 Zero"], "max_slots": 1, "score": 25, "icon": "prop_fighter",
		"weapons": "2× Тип 99 · 2× Тип 3 · 2× 60 кг",
		"desc": "Очень лёгкий палубный истребитель: непревзойдённый вираж на малой скорости ценой слабой защиты.",
		"stats": [0.54, 0.25, 0.58, 0.95],
		"flight": {"min": 38.0, "cruise": 115.0, "max": 160.0, "thrust": 24.0, "pitch": 2.1, "roll": 3.0, "yaw": 0.62},
		"hp": 90.0, "hit_radius": 5.2, "collision": Vector3(11.0, 2.6, 9.0), "camera": Vector2(19.0, 4.6),
		"primary": {"type": "guns", "name": "2× Тип 99 + 2× Тип 3", "interval": 0.07, "damage": 8.5, "speed": 760.0, "drag": 0.00045, "magazine": 180, "reload": 4.0, "spread": 0.45},
		"secondary": {"type": "bombs", "name": "Тип 97 60 кг", "count": 2, "interval": 0.3, "reload": 14.0, "damage": 110.0, "blast": 14.0},
		"flares": 0,
	},
	# ============ Реактивные истребители ============
	"mig29": {
		"category": Category.AIR, "role": "fighter", "era": "jet", "nation": "su", "engine": "jet",
		"names": ["МиГ-29", "МиГ-29"], "max_slots": 1, "score": 30, "icon": "fighter",
		"weapons": "ГШ-30-1 · 4× Р-73 · ЛТЦ",
		"desc": "Манёвренный фронтовой истребитель: курсовая автопушка и ракеты «воздух-воздух» с тепловой ГСН.",
		"stats": [0.94, 0.4, 0.72, 0.8],
		"flight": {"min": 75.0, "cruise": 175.0, "max": 285.0, "thrust": 52.0, "pitch": 1.6, "roll": 3.6, "yaw": 0.5},
		"hp": 160.0, "hit_radius": 7.0, "collision": Vector3(11.4, 3.0, 17.0), "camera": Vector2(27.0, 6.0),
		"primary": {"type": "guns", "name": "ГШ-30-1", "interval": 0.05, "damage": 11.0, "speed": 900.0, "drag": 0.00028, "magazine": 150, "reload": 3.5, "spread": 0.35},
		"secondary": {"type": "aam", "name": "Р-73", "count": 4, "interval": 0.9, "reload": 22.0, "range": 3200.0},
		"flares": 6,
	},
	"su27": {
		"category": Category.AIR, "role": "fighter", "era": "jet", "nation": "su", "engine": "jet",
		"names": ["Су-27", "Су-27"], "max_slots": 1, "score": 30, "icon": "fighter",
		"weapons": "ГШ-30-1 · 6× Р-73 · ЛТЦ",
		"desc": "Тяжёлый истребитель завоевания господства: большой боекомплект ракет и высокая живучесть.",
		"stats": [0.95, 0.55, 0.82, 0.72],
		"flight": {"min": 78.0, "cruise": 180.0, "max": 290.0, "thrust": 50.0, "pitch": 1.5, "roll": 3.2, "yaw": 0.48},
		"hp": 190.0, "hit_radius": 8.0, "collision": Vector3(14.7, 3.4, 21.9), "camera": Vector2(30.0, 6.6),
		"primary": {"type": "guns", "name": "ГШ-30-1", "interval": 0.05, "damage": 11.0, "speed": 900.0, "drag": 0.00028, "magazine": 150, "reload": 3.5, "spread": 0.35},
		"secondary": {"type": "aam", "name": "Р-73", "count": 6, "interval": 0.9, "reload": 20.0, "range": 3200.0},
		"flares": 8,
	},
	"f16": {
		"category": Category.AIR, "role": "fighter", "era": "jet", "nation": "us", "engine": "jet",
		"names": ["F-16C", "F-16C"], "max_slots": 1, "score": 30, "icon": "fighter",
		"weapons": "M61A1 Vulcan · 4× AIM-9M · ЛТЦ",
		"desc": "Лёгкий многоцелевой истребитель с подфюзеляжным воздухозаборником и лучшим креном в классе.",
		"stats": [0.93, 0.38, 0.72, 0.86],
		"flight": {"min": 72.0, "cruise": 176.0, "max": 286.0, "thrust": 53.0, "pitch": 1.65, "roll": 4.3, "yaw": 0.5},
		"hp": 150.0, "hit_radius": 6.5, "collision": Vector3(10.0, 3.0, 15.0), "camera": Vector2(26.0, 5.8),
		"primary": {"type": "guns", "name": "M61A1 Vulcan", "interval": 0.035, "damage": 8.0, "speed": 1030.0, "drag": 0.00026, "magazine": 200, "reload": 3.5, "spread": 0.4},
		"secondary": {"type": "aam", "name": "AIM-9M", "count": 4, "interval": 0.9, "reload": 22.0, "range": 3300.0},
		"flares": 6,
	},
	"f4e": {
		"category": Category.AIR, "role": "fighter", "era": "jet", "nation": "us", "engine": "jet",
		"names": ["F-4E Phantom II", "F-4E Phantom II"], "max_slots": 1, "score": 30, "icon": "fighter",
		"weapons": "M61A1 Vulcan · 4× AIM-9J · ЛТЦ",
		"desc": "Тяжёлый двухдвигательный «Фантом»: мощная тяга и живучесть, но инертен в затяжном вираже.",
		"stats": [0.9, 0.62, 0.72, 0.52],
		"flight": {"min": 80.0, "cruise": 170.0, "max": 278.0, "thrust": 50.0, "pitch": 1.35, "roll": 2.9, "yaw": 0.45},
		"hp": 205.0, "hit_radius": 8.0, "collision": Vector3(11.8, 5.0, 19.2), "camera": Vector2(29.0, 6.4),
		"primary": {"type": "guns", "name": "M61A1 Vulcan", "interval": 0.035, "damage": 8.0, "speed": 1030.0, "drag": 0.00026, "magazine": 200, "reload": 3.5, "spread": 0.4},
		"secondary": {"type": "aam", "name": "AIM-9J", "count": 4, "interval": 0.9, "reload": 24.0, "range": 2900.0},
		"flares": 6,
	},
	"mirage2000": {
		"category": Category.AIR, "role": "fighter", "era": "jet", "nation": "fr", "engine": "jet",
		"names": ["Mirage 2000C", "Mirage 2000C"], "max_slots": 1, "score": 30, "icon": "delta",
		"weapons": "2× DEFA 554 · 2× Magic II · ЛТЦ",
		"desc": "Бесхвостка с треугольным крылом: быстрый разгон и отличная управляемость на больших углах атаки.",
		"stats": [0.92, 0.4, 0.66, 0.82],
		"flight": {"min": 70.0, "cruise": 172.0, "max": 282.0, "thrust": 51.0, "pitch": 1.65, "roll": 4.0, "yaw": 0.5},
		"hp": 150.0, "hit_radius": 6.5, "collision": Vector3(9.2, 3.4, 14.4), "camera": Vector2(25.0, 5.8),
		"primary": {"type": "guns", "name": "2× DEFA 554", "interval": 0.042, "damage": 10.0, "speed": 820.0, "drag": 0.0003, "magazine": 170, "reload": 3.5, "spread": 0.4},
		"secondary": {"type": "aam", "name": "Magic II", "count": 2, "interval": 0.9, "reload": 16.0, "range": 3000.0},
		"flares": 8,
	},
	"rafale": {
		"category": Category.AIR, "role": "fighter", "era": "jet", "nation": "fr", "engine": "jet",
		"names": ["Rafale C", "Rafale C"], "max_slots": 1, "score": 30, "icon": "delta",
		"weapons": "GIAT 30M791 · 4× MICA IR · ЛТЦ",
		"desc": "Современный истребитель схемы «утка» с передним горизонтальным оперением: энергичный и точный.",
		"stats": [0.94, 0.45, 0.8, 0.88],
		"flight": {"min": 68.0, "cruise": 178.0, "max": 288.0, "thrust": 55.0, "pitch": 1.7, "roll": 4.0, "yaw": 0.52},
		"hp": 165.0, "hit_radius": 6.8, "collision": Vector3(10.9, 3.4, 15.3), "camera": Vector2(26.0, 5.8),
		"primary": {"type": "guns", "name": "GIAT 30M791", "interval": 0.04, "damage": 11.0, "speed": 1025.0, "drag": 0.00027, "magazine": 125, "reload": 3.5, "spread": 0.35},
		"secondary": {"type": "aam", "name": "MICA IR", "count": 4, "interval": 0.9, "reload": 20.0, "range": 3500.0},
		"flares": 8,
	},
	# ============ Ударные самолёты ============
	"il2": {
		"category": Category.AIR, "role": "strike", "era": "prop", "nation": "su", "engine": "prop",
		"names": ["Ил-2", "Ил-2"], "max_slots": 1, "score": 35, "icon": "prop_bomber",
		"weapons": "2× ВЯ-23 · 4× ФАБ-100",
		"desc": "Бронированный штурмовик: бронекорпус держит огонь зениток, пушки и бомбы — против техники и кораблей.",
		"stats": [0.42, 0.9, 0.72, 0.42],
		"flight": {"min": 42.0, "cruise": 108.0, "max": 148.0, "thrust": 21.0, "pitch": 1.25, "roll": 2.4, "yaw": 0.45},
		"hp": 270.0, "hit_radius": 6.0, "collision": Vector3(14.6, 3.2, 11.6), "camera": Vector2(22.0, 5.4),
		"armor": {"bullet": 0.55, "flak": 0.7},
		"primary": {"type": "guns", "name": "2× ВЯ-23", "interval": 0.1, "damage": 13.0, "speed": 900.0, "drag": 0.0004, "magazine": 120, "reload": 4.5, "spread": 0.45},
		"secondary": {"type": "bombs", "name": "ФАБ-100", "count": 4, "interval": 0.28, "reload": 11.0, "damage": 160.0, "blast": 18.0},
		"flares": 0,
	},
	"b25": {
		"category": Category.AIR, "role": "strike", "era": "prop", "nation": "us", "engine": "prop",
		"names": ["B-25J Mitchell", "B-25J Mitchell"], "max_slots": 1, "score": 40, "icon": "prop_bomber",
		"weapons": "6× AN-M64 500 lb · 8× HVAR",
		"desc": "Двухмоторный средний бомбардировщик: тяжёлая бомбовая нагрузка и реактивные снаряды против кораблей.",
		"stats": [0.46, 0.75, 0.95, 0.3],
		"flight": {"min": 46.0, "cruise": 110.0, "max": 150.0, "thrust": 20.0, "pitch": 1.0, "roll": 1.9, "yaw": 0.38},
		"hp": 310.0, "hit_radius": 9.0, "collision": Vector3(20.6, 4.8, 16.1), "camera": Vector2(32.0, 7.6),
		"armor": {"bullet": 0.8, "flak": 0.85},
		"primary": {"type": "bombs", "name": "AN-M64 500 lb", "count": 6, "interval": 0.3, "reload": 10.0, "damage": 240.0, "blast": 24.0},
		"secondary": {"type": "rockets", "name": "HVAR", "count": 8, "interval": 0.18, "reload": 12.0, "damage": 110.0, "blast": 10.0, "speed": 420.0},
		"flares": 0,
	},
	"su24m": {
		"category": Category.AIR, "role": "strike", "era": "jet", "nation": "su", "engine": "jet",
		"names": ["Су-24М", "Су-24М"], "max_slots": 1, "score": 40, "icon": "bomber",
		"weapons": "8× ФАБ-500 · 2× Х-59 · ЛТЦ",
		"desc": "Фронтовой бомбардировщик: тяжёлые бомбы и крылатые ракеты Х-59 для ударов по кораблям и ПВО.",
		"stats": [0.72, 0.62, 1.0, 0.42],
		"flight": {"min": 65.0, "cruise": 150.0, "max": 240.0, "thrust": 38.0, "pitch": 1.0, "roll": 2.1, "yaw": 0.35},
		"hp": 270.0, "hit_radius": 9.0, "collision": Vector3(17.6, 5.0, 22.6), "camera": Vector2(34.0, 8.0),
		"armor": {"bullet": 0.85, "flak": 0.9},
		"primary": {"type": "bombs", "name": "ФАБ-500", "count": 8, "interval": 0.35, "reload": 11.0, "damage": 290.0, "blast": 30.0},
		"secondary": {"type": "agm", "name": "Х-59", "count": 2, "interval": 1.5, "reload": 32.0, "min": 600.0, "max": 9000.0},
		"special": "secondary",
		"flares": 5,
	},
	"su25": {
		"category": Category.AIR, "role": "strike", "era": "jet", "nation": "su", "engine": "jet",
		"names": ["Су-25", "Су-25"], "max_slots": 1, "score": 40, "icon": "bomber",
		"weapons": "ГШ-30-2 · 6× ОФАБ-250 · 2× Х-25МЛ · ЛТЦ",
		"desc": "Бронированный штурмовик «Грач»: двуствольная пушка, бомбы и управляемые ракеты по тактической метке.",
		"stats": [0.62, 0.9, 0.9, 0.5],
		"flight": {"min": 58.0, "cruise": 145.0, "max": 225.0, "thrust": 36.0, "pitch": 1.2, "roll": 2.6, "yaw": 0.4},
		"hp": 320.0, "hit_radius": 8.0, "collision": Vector3(14.4, 4.8, 15.5), "camera": Vector2(28.0, 7.0),
		"armor": {"bullet": 0.55, "flak": 0.7},
		"primary": {"type": "guns", "name": "ГШ-30-2", "interval": 0.045, "damage": 12.0, "speed": 870.0, "drag": 0.0003, "magazine": 125, "reload": 4.0, "spread": 0.45},
		"secondary": {"type": "bombs", "name": "ОФАБ-250", "count": 6, "interval": 0.3, "reload": 11.0, "damage": 220.0, "blast": 24.0},
		"special_weapon": {"type": "agm", "name": "Х-25МЛ", "count": 2, "interval": 1.2, "reload": 30.0, "min": 500.0, "max": 7000.0, "direct": true},
		"special": "special_weapon",
		"flares": 8,
	},
	"a10": {
		"category": Category.AIR, "role": "strike", "era": "jet", "nation": "us", "engine": "jet",
		"names": ["A-10A Thunderbolt II", "A-10A Thunderbolt II"], "max_slots": 1, "score": 40, "icon": "bomber",
		"weapons": "GAU-8 Avenger · 6× Mk 82 · 2× AGM-65 · ЛТЦ",
		"desc": "Летающая пушка: 30-мм GAU-8, живучий планер, бомбы и ракеты «Мейверик» по тактической метке.",
		"stats": [0.55, 0.95, 0.95, 0.52],
		"flight": {"min": 52.0, "cruise": 140.0, "max": 208.0, "thrust": 33.0, "pitch": 1.25, "roll": 2.5, "yaw": 0.42},
		"hp": 360.0, "hit_radius": 9.0, "collision": Vector3(17.5, 4.5, 16.3), "camera": Vector2(30.0, 7.2),
		"armor": {"bullet": 0.5, "flak": 0.65},
		"primary": {"type": "guns", "name": "GAU-8 Avenger", "interval": 0.03, "damage": 11.0, "speed": 1010.0, "drag": 0.00028, "magazine": 180, "reload": 4.5, "spread": 0.5},
		"secondary": {"type": "bombs", "name": "Mk 82", "count": 6, "interval": 0.3, "reload": 11.0, "damage": 230.0, "blast": 24.0},
		"special_weapon": {"type": "agm", "name": "AGM-65 Maverick", "count": 2, "interval": 1.2, "reload": 30.0, "min": 500.0, "max": 7000.0, "direct": true},
		"special": "special_weapon",
		"flares": 8,
	},
	# ============ Наземная ПВО ============
	"spaag": {
		"category": Category.GROUND, "role": "spaag", "era": "any",
		"names": ["Гепард", "Гепард"], "max_slots": 2, "score": 25, "icon": "spaag",
		"weapons": "2× 35-мм автопушки · РЛС сопровождения",
		"desc": "Скорострельные трассирующие пушки с неконтактными снарядами. Высокая плотность огня по низколетящим целям.",
		"stats": [0.35, 0.7, 0.75, 0.45],
	},
	"sam": {
		"category": Category.GROUND, "role": "sam", "era": "any",
		"names": ["Patriot", "Бук-М1"], "max_slots": 1, "score": 35, "icon": "sam",
		"weapons": "4× ЗУР · РЛС захвата 7 км",
		"desc": "Дальнобойные зенитные управляемые ракеты с физикой разгона и радиолокационным захватом цели.",
		"stats": [0.25, 0.6, 0.9, 0.3],
	},
	# ============ Флот ============
	"boat": {
		"category": Category.NAVAL, "role": "boat", "era": "any",
		"names": ["Sea Baby", "G-5"], "max_slots": 3, "score": 20, "icon": "boat",
		"weapons": "Пулемёт · 2× торпеды · баллистическая ракета",
		"desc": "Высокая манёвренность на воде. Торпеды против крупных кораблей и баллистические удары по суше и морю.",
		"stats": [0.8, 0.3, 0.8, 0.85],
	},
}
const VEHICLE_ORDER := [
	"bf109", "fw190", "yak9", "la5", "p51", "p40", "spitfire", "zero",
	"mig29", "su27", "f16", "f4e", "mirage2000", "rafale",
	"il2", "b25", "su24m", "su25", "a10",
	"spaag", "sam", "boat",
]
const WARSHIP_SCORE := 150

# --- Уровни сложности ботов --------------------------------------------------------------------
## aim_error_deg — разброс наводки; reaction — задержка реакции (с); detect — множитель дальности
## обнаружения; burst — дисциплина огня; missile_delay — пауза перед пусками ракет; damage — множитель
## урона ботов по игроку; lock_time — множитель времени захвата ЗРК; player_focus — склонность выбирать игрока.
const DIFFICULTY_LEVELS := [
	{"name": "Новобранец", "aim_error_deg": 5.5, "reaction": 2.0, "detect": 0.6, "burst": 0.35, "missile_delay": 9.0, "damage": 0.45, "lock_time": 1.9, "player_focus": 0.55, "evade": 0.25},
	{"name": "Ветеран", "aim_error_deg": 3.4, "reaction": 1.2, "detect": 0.8, "burst": 0.55, "missile_delay": 5.0, "damage": 0.7, "lock_time": 1.45, "player_focus": 0.8, "evade": 0.5},
	{"name": "Ас", "aim_error_deg": 1.8, "reaction": 0.7, "detect": 1.0, "burst": 0.8, "missile_delay": 2.5, "damage": 0.95, "lock_time": 1.1, "player_focus": 1.0, "evade": 0.8},
]

const BOT_CALLSIGNS := [
	"Беркут", "Сокол", "Гром", "Вихрь", "Кречет", "Ястреб", "Тайфун", "Буран", "Шторм",
	"Молния", "Рубин", "Кобальт", "Сапсан", "Скиф", "Барс", "Кедр", "Прибой", "Зенит",
	"Штиль", "Гранит", "Аргон", "Орлан", "Кондор", "Фрегат", "Стриж", "Пурга", "Алмаз", "Витязь",
]

const SIDES: Array[float] = [-1.0, 1.0]


# --- Данные техники ----------------------------------------------------------------------------
static func resolve_id(type_id: String) -> String:
	return str(ALIASES.get(type_id, type_id))


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


static func role_of(type_id: String) -> String:
	if type_id == "warship":
		return "warship"
	return str(vehicle_info(type_id).get("role", ""))


static func vehicle_role(type_id: String) -> String:
	return str(ROLE_TITLES.get(role_of(type_id), ""))


static func is_aircraft(type_id: String) -> bool:
	return category_of(type_id) == Category.AIR


static func max_slots(type_id: String) -> int:
	return int(vehicle_info(type_id).get("max_slots", 0))


static func category_of(type_id: String) -> int:
	if type_id == "warship":
		return Category.NAVAL
	return int(vehicle_info(type_id).get("category", Category.GROUND))


## Доступна ли техника в выбранной эпохе авиации (0 — смешанная, 1 — поршневая, 2 — реактивная).
static func in_era(type_id: String, era: int) -> bool:
	var e := str(vehicle_info(type_id).get("era", "any"))
	match era:
		1:
			return e != "jet"
		2:
			return e != "prop"
	return true


static func types_in_category(category: int, era: int = 0) -> Array[String]:
	var result: Array[String] = []
	for t: String in VEHICLE_ORDER:
		if category_of(t) == category and in_era(t, era):
			result.append(t)
	return result


static func types_with_role(role: String, era: int = 0) -> Array[String]:
	var result: Array[String] = []
	for t: String in VEHICLE_ORDER:
		if role_of(t) == role and in_era(t, era):
			result.append(t)
	return result


## Суммарная вместимость команды с учётом лимитов ролей.
static func total_slots(era: int = 0) -> int:
	var total := 0
	for role: String in ROLES:
		var by_types := 0
		for t in types_with_role(role, era):
			by_types += max_slots(t)
		total += mini(by_types, int(ROLE_LIMITS.get(role, 99)))
	return total


static func score_for_vehicle(type_id: String) -> int:
	if type_id == "warship":
		return WARSHIP_SCORE
	return int(vehicle_info(type_id).get("score", 10))


static func difficulty(level: int) -> Dictionary:
	return DIFFICULTY_LEVELS[clampi(level, 0, DIFFICULTY_LEVELS.size() - 1)]


static func nation_name(type_id: String) -> String:
	return str(NATION_NAMES.get(str(vehicle_info(type_id).get("nation", "")), ""))


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
