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
const ROLES := ["fighter", "strike", "spaag", "sam", "flak", "boat", "ship"]
const ROLE_TITLES := {
	"fighter": "Истребитель", "strike": "Ударный самолёт", "spaag": "Зенитная установка", "sam": "Зенитный ракетный комплекс",
	"flak": "Зенитное орудие", "boat": "Катер", "ship": "Боевой корабль", "flagship": "Флагман",
}
## Заголовки групп в выборе техники.
const ROLE_GROUPS := {"fighter": "ИСТРЕБИТЕЛИ", "strike": "УДАРНЫЕ САМОЛЁТЫ", "spaag": "ЗЕНИТНЫЕ УСТАНОВКИ", "sam": "ЗЕНИТНЫЕ РАКЕТНЫЕ КОМПЛЕКСЫ", "flak": "ЗЕНИТНЫЕ ОРУДИЯ", "boat": "КАТЕРА", "ship": "БОЕВЫЕ КОРАБЛИ"}
## Ограничение числа машин одной роли в команде (дополнительно к лимиту слотов каждого типа).
const ROLE_LIMITS := {"fighter": 5, "strike": 3, "spaag": 2, "sam": 2, "flak": 2, "boat": 3, "ship": 1}
const ERA_NAMES := ["Смешанная", "1940-е (поршневая)", "Реактивная"]
const NATION_NAMES := {"su": "СССР", "ru": "Россия", "de": "Германия", "us": "США", "uk": "Великобритания", "jp": "Япония", "fr": "Франция", "ua": "Украина", "se": "Швеция"}

## Старые идентификаторы (аргументы автотестов и прежние типы техники).
const ALIASES := {"fighter": "mig29", "bomber": "su24m", "spaag": "gepard", "sam": "buk", "boat": "seababy", "warship": "ticonderoga"}

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
	# ============ Наземная ПВО: 1940-е ============
	"wirbelwind": {
		"category": Category.GROUND, "role": "spaag", "era": "prop", "nation": "de", "class": "Зенитный танк",
		"names": ["Flakpanzer IV «Wirbelwind»", "Flakpanzer IV «Wirbelwind»"], "max_slots": 1, "score": 22, "icon": "spaag",
		"weapons": "Счетверённая 2-см Flakvierling 38",
		"desc": "Зенитный танк на шасси Pz.Kpfw. IV: открытая девятигранная башня и счетверённая 20-мм установка с высокой плотностью огня.",
		"stats": [0.3, 0.55, 0.62, 0.4],
		"hp": 200.0, "hit_radius": 3.8, "armor": {"bullet": 0.5, "flak": 0.65, "missile": 0.85},
		"move": {"speed": 10.5, "reverse": 4.0, "accel": 4.5, "turn": 0.9},
		"turret": {"yaw": 1.6, "pitch": 1.4, "min": -10.0, "max": 90.0},
		"radar": 0.0, "camera": Vector2(14.0, 4.6),
		"guns": {"name": "4× 2-см Flak 38", "interval": 0.036, "magazine": 80, "reload": 5.5, "speed": 900.0, "drag": 0.0004, "damage": 5.5, "type": "flak", "prox": 2.5, "prox_damage": 6.0, "life": 2.4, "spread": 0.5, "tracer": Color(1.0, 0.55, 0.25), "tracer_w": 0.22, "sound": "cannon", "pitch": 1.35, "volume": -6.0, "flash": 0.9, "range": 1800.0},
	},
	"m16": {
		"category": Category.GROUND, "role": "spaag", "era": "prop", "nation": "us", "class": "Зенитная самоходная установка",
		"names": ["M16 MGMC", "M16 MGMC"], "max_slots": 2, "score": 20, "icon": "spaag",
		"weapons": "Счетверённая установка M45: 4× 12,7-мм M2",
		"desc": "Полугусеничный бронетранспортёр M3 со счетверённой пулемётной установкой M45 «Мясорубка»: быстрый, но слабо защищён.",
		"stats": [0.55, 0.3, 0.55, 0.55],
		"hp": 150.0, "hit_radius": 3.6, "armor": {"bullet": 0.7, "flak": 0.85},
		"move": {"speed": 16.0, "reverse": 5.0, "accel": 5.5, "turn": 0.9, "wheeled": true},
		"turret": {"yaw": 2.0, "pitch": 1.7, "min": -10.0, "max": 90.0},
		"radar": 0.0, "camera": Vector2(14.0, 4.6),
		"guns": {"name": "4× 12,7-мм M2", "interval": 0.027, "magazine": 200, "reload": 6.0, "speed": 890.0, "drag": 0.00045, "damage": 3.6, "type": "bullet", "life": 2.0, "spread": 0.55, "tracer": Color(1.0, 0.42, 0.3), "tracer_w": 0.18, "sound": "mg", "pitch": 1.0, "volume": -5.0, "flash": 0.7, "range": 1400.0},
	},
	"zsu37": {
		"category": Category.GROUND, "role": "spaag", "era": "prop", "nation": "su", "class": "Зенитная самоходная установка",
		"names": ["ЗСУ-37", "ЗСУ-37"], "max_slots": 1, "score": 22, "icon": "spaag",
		"weapons": "37-мм автоматическая пушка 61-К",
		"desc": "ЗСУ на шасси СУ-76М: бронированная рубка и 37-мм автомат 61-К — меньше темп, но тяжёлые снаряды с дистанционным подрывом.",
		"stats": [0.4, 0.45, 0.62, 0.45],
		"hp": 190.0, "hit_radius": 3.6, "armor": {"bullet": 0.55, "flak": 0.7, "missile": 0.9},
		"move": {"speed": 12.0, "reverse": 4.0, "accel": 5.0, "turn": 1.0},
		"turret": {"yaw": 1.5, "pitch": 1.3, "min": -5.0, "max": 85.0},
		"radar": 0.0, "camera": Vector2(14.0, 4.6),
		"guns": {"name": "37-мм 61-К", "interval": 0.38, "magazine": 30, "reload": 4.0, "speed": 880.0, "drag": 0.00035, "damage": 13.0, "type": "flak", "prox": 4.0, "prox_damage": 12.0, "life": 3.2, "spread": 0.25, "tracer": Color(1.0, 0.6, 0.25), "tracer_w": 0.3, "sound": "cannon", "pitch": 0.9, "volume": -2.0, "flash": 1.2, "range": 2400.0},
	},
	"flak88": {
		"category": Category.GROUND, "role": "flak", "era": "prop", "nation": "de", "class": "Зенитное орудие",
		"names": ["8,8-cm Flak 37", "8,8-cm Flak 37"], "max_slots": 1, "score": 25, "icon": "flak",
		"weapons": "88-мм орудие · прибор управления огнём",
		"desc": "Знаменитая «ахт-ахт» на крестообразном лафете: стационарная позиция, снаряды с дистанционным взрывателем поражают бомбардировщики на высоте.",
		"stats": [0.0, 0.4, 0.88, 0.15],
		"hp": 170.0, "hit_radius": 4.0, "armor": {"bullet": 0.8, "flak": 0.8, "missile": 0.9},
		"move": {"speed": 0.0},
		"turret": {"yaw": 0.75, "pitch": 0.55, "min": -3.0, "max": 85.0},
		"radar": 5500.0, "camera": Vector2(16.0, 5.0),
		"guns": {"name": "8,8-см Flak 37", "interval": 3.0, "magazine": 10, "reload": 5.0, "speed": 820.0, "drag": 0.00012, "damage": 0.0, "type": "flak", "prox": 16.0, "blast": 14.0, "blast_damage": 95.0, "life": 9.0, "spread": 0.15, "tracer": Color(1.0, 0.8, 0.45), "tracer_w": 0.2, "sound": "cannon", "pitch": 0.55, "volume": 4.0, "flash": 2.4, "range": 6500.0},
	},
	"k52": {
		"category": Category.GROUND, "role": "flak", "era": "prop", "nation": "su", "class": "Зенитное орудие",
		"names": ["85-мм 52-К", "85-мм 52-К"], "max_slots": 1, "score": 25, "icon": "flak",
		"weapons": "85-мм орудие · ПУАЗО",
		"desc": "Зенитная пушка образца 1939 года на четырёхколёсной повозке с выносными опорами: дальний заградительный огонь дистанционными гранатами.",
		"stats": [0.0, 0.4, 0.85, 0.15],
		"hp": 170.0, "hit_radius": 4.0, "armor": {"bullet": 0.8, "flak": 0.8, "missile": 0.9},
		"move": {"speed": 0.0},
		"turret": {"yaw": 0.8, "pitch": 0.6, "min": -3.0, "max": 82.0},
		"radar": 5200.0, "camera": Vector2(16.0, 5.0),
		"guns": {"name": "85-мм 52-К", "interval": 3.4, "magazine": 10, "reload": 5.0, "speed": 800.0, "drag": 0.00012, "damage": 0.0, "type": "flak", "prox": 16.0, "blast": 14.0, "blast_damage": 100.0, "life": 9.0, "spread": 0.15, "tracer": Color(1.0, 0.8, 0.45), "tracer_w": 0.2, "sound": "cannon", "pitch": 0.6, "volume": 4.0, "flash": 2.4, "range": 6000.0},
	},
	# ============ Наземная ПВО: реактивная эпоха ============
	"gepard": {
		"category": Category.GROUND, "role": "spaag", "era": "jet", "nation": "de", "class": "Зенитная самоходная установка",
		"names": ["Flakpanzer Gepard", "Flakpanzer Gepard"], "max_slots": 1, "score": 25, "icon": "spaag",
		"weapons": "2× 35-мм Oerlikon KDA · РЛС обнаружения и сопровождения",
		"desc": "ЗСУ на шасси Leopard 1: скорострельные 35-мм пушки с неконтактными снарядами и РЛС сопровождения с индикатором упреждения.",
		"stats": [0.45, 0.7, 0.75, 0.45],
		"hp": 230.0, "hit_radius": 4.2, "armor": {"bullet": 0.45, "flak": 0.6, "missile": 0.8},
		"move": {"speed": 17.0, "reverse": 6.0, "accel": 6.0, "turn": 1.1},
		"turret": {"yaw": 2.4, "pitch": 1.8, "min": -6.0, "max": 85.0},
		"radar": 3200.0, "camera": Vector2(16.0, 5.0),
		"guns": {"name": "35-мм Oerlikon KDA", "interval": 0.0556, "magazine": 80, "reload": 4.5, "speed": 1175.0, "drag": 0.00022, "damage": 8.0, "type": "flak", "prox": 5.0, "prox_damage": 11.0, "life": 3.4, "spread": 0.3, "tracer": Color(1.0, 0.72, 0.25), "tracer_w": 0.32, "sound": "cannon", "pitch": 1.0, "volume": -3.0, "flash": 1.4, "range": 2300.0},
	},
	"shilka": {
		"category": Category.GROUND, "role": "spaag", "era": "jet", "nation": "su", "class": "Зенитная самоходная установка",
		"names": ["ЗСУ-23-4 «Шилка»", "ЗСУ-23-4 «Шилка»"], "max_slots": 1, "score": 25, "icon": "spaag",
		"weapons": "4× 23-мм АЗП-23 · РЛС «Тобол»",
		"desc": "Легендарная «Шилка»: четыре 23-мм автомата создают плотный огневой вал, РЛС сопровождения выдаёт упреждение.",
		"stats": [0.4, 0.6, 0.72, 0.45],
		"hp": 200.0, "hit_radius": 3.9, "armor": {"bullet": 0.5, "flak": 0.65, "missile": 0.85},
		"move": {"speed": 13.0, "reverse": 5.0, "accel": 5.5, "turn": 1.05},
		"turret": {"yaw": 2.0, "pitch": 1.6, "min": -4.0, "max": 85.0},
		"radar": 2500.0, "camera": Vector2(15.0, 4.8),
		"guns": {"name": "4× 23-мм АЗП-23", "interval": 0.028, "magazine": 100, "reload": 5.5, "speed": 970.0, "drag": 0.0003, "damage": 5.5, "type": "flak", "prox": 3.5, "prox_damage": 7.0, "life": 2.6, "spread": 0.4, "tracer": Color(1.0, 0.5, 0.25), "tracer_w": 0.25, "sound": "cannon", "pitch": 1.25, "volume": -5.0, "flash": 1.0, "range": 2000.0},
	},
	"m163": {
		"category": Category.GROUND, "role": "spaag", "era": "jet", "nation": "us", "class": "Зенитная самоходная установка",
		"names": ["M163 VADS", "M163 VADS"], "max_slots": 1, "score": 22, "icon": "spaag",
		"weapons": "20-мм M61 Vulcan · дальномерная РЛС",
		"desc": "Шестиствольная пушка «Вулкан» на шасси M113: огромный темп стрельбы на малой дальности, быстрый и лёгкий.",
		"stats": [0.52, 0.5, 0.62, 0.55],
		"hp": 170.0, "hit_radius": 3.6, "armor": {"bullet": 0.6, "flak": 0.75, "missile": 0.9},
		"move": {"speed": 18.0, "reverse": 6.0, "accel": 6.5, "turn": 1.2},
		"turret": {"yaw": 2.6, "pitch": 2.0, "min": -5.0, "max": 80.0},
		"radar": 1800.0, "camera": Vector2(13.0, 4.4),
		"guns": {"name": "20-мм M61 Vulcan", "interval": 0.022, "magazine": 160, "reload": 5.0, "speed": 1030.0, "drag": 0.0003, "damage": 4.2, "type": "flak", "prox": 2.5, "prox_damage": 5.0, "life": 2.2, "spread": 0.45, "tracer": Color(1.0, 0.8, 0.35), "tracer_w": 0.22, "sound": "mg", "pitch": 1.4, "volume": -4.0, "flash": 0.9, "range": 1700.0},
	},
	"tunguska": {
		"category": Category.GROUND, "role": "spaag", "era": "jet", "nation": "su", "class": "Зенитный пушечно-ракетный комплекс",
		"names": ["2К22 «Тунгуска»", "2К22 «Тунгуска»"], "max_slots": 1, "score": 32, "icon": "spaag",
		"weapons": "2× 30-мм 2А38 · 8× ЗУР 9М311",
		"desc": "Пушечно-ракетный комплекс: 30-мм автоматы для ближнего боя и восемь ЗУР с радиокомандным наведением — ловушки их не обманут.",
		"stats": [0.45, 0.75, 0.9, 0.45],
		"hp": 260.0, "hit_radius": 4.3, "armor": {"bullet": 0.45, "flak": 0.6, "missile": 0.8},
		"move": {"speed": 17.0, "reverse": 6.0, "accel": 6.0, "turn": 1.0},
		"turret": {"yaw": 2.2, "pitch": 1.7, "min": -9.0, "max": 87.0},
		"radar": 3500.0, "camera": Vector2(16.0, 5.0),
		"guns": {"name": "2× 30-мм 2А38", "interval": 0.04, "magazine": 120, "reload": 5.0, "speed": 960.0, "drag": 0.00025, "damage": 8.5, "type": "flak", "prox": 4.5, "prox_damage": 10.0, "life": 3.3, "spread": 0.35, "tracer": Color(1.0, 0.65, 0.25), "tracer_w": 0.3, "sound": "cannon", "pitch": 1.1, "volume": -3.0, "flash": 1.3, "range": 2600.0},
		"missiles": {"name": "ЗУР 9М311", "count": 8, "interval": 1.5, "reload": 12.0, "lock": 1.4, "radar": 6000.0, "cone": 18.0, "guidance": "command", "thrust": 240.0, "burn": 2.2, "max_speed": 900.0, "max_g": 28.0, "blast": 9.0, "damage": 150.0, "prox": 9.0, "life": 12.0, "fov": 160.0, "flare_res": 0.95, "mesh": "sam_small", "trail": "small", "launcher": "gun", "speed0": 60.0},
	},
	"pantsir": {
		"category": Category.GROUND, "role": "spaag", "era": "jet", "nation": "ru", "class": "Зенитный пушечно-ракетный комплекс",
		"names": ["«Панцирь-С1»", "«Панцирь-С1»"], "max_slots": 1, "score": 35, "icon": "spaag_wheeled",
		"weapons": "2× 30-мм 2А38М · 12× ЗУР 57Э6",
		"desc": "Колёсный пушечно-ракетный комплекс на шасси КАМАЗ: двенадцать скоростных ЗУР и спаренные автоматы на одном боевом модуле.",
		"stats": [0.6, 0.72, 0.95, 0.4],
		"hp": 280.0, "hit_radius": 4.8, "armor": {"bullet": 0.5, "flak": 0.6, "missile": 0.8},
		"move": {"speed": 20.0, "reverse": 6.0, "accel": 5.0, "turn": 0.75, "wheeled": true},
		"turret": {"yaw": 2.2, "pitch": 1.7, "min": -5.0, "max": 82.0},
		"radar": 3500.0, "camera": Vector2(20.0, 6.0),
		"guns": {"name": "2× 30-мм 2А38М", "interval": 0.04, "magazine": 120, "reload": 5.0, "speed": 960.0, "drag": 0.00025, "damage": 8.5, "type": "flak", "prox": 4.5, "prox_damage": 10.0, "life": 3.3, "spread": 0.35, "tracer": Color(1.0, 0.65, 0.25), "tracer_w": 0.3, "sound": "cannon", "pitch": 1.1, "volume": -3.0, "flash": 1.3, "range": 2600.0},
		"missiles": {"name": "ЗУР 57Э6", "count": 12, "interval": 1.2, "reload": 11.0, "lock": 1.2, "radar": 7000.0, "cone": 18.0, "guidance": "command", "thrust": 300.0, "burn": 2.0, "max_speed": 1100.0, "max_g": 30.0, "blast": 10.0, "damage": 160.0, "prox": 10.0, "life": 14.0, "fov": 160.0, "flare_res": 0.95, "mesh": "sam_small", "trail": "small", "launcher": "gun", "speed0": 60.0},
	},
	"patriot": {
		"category": Category.GROUND, "role": "sam", "era": "jet", "nation": "us", "class": "Зенитный ракетный комплекс",
		"names": ["Patriot PAC-2", "Patriot PAC-2"], "max_slots": 1, "score": 35, "icon": "sam",
		"weapons": "4× ЗУР MIM-104 · РЛС 7,5 км",
		"desc": "Пусковая установка комплекса Patriot на колёсном шасси: четыре тяжёлые ЗУР в контейнерах, пуск под фиксированным углом.",
		"stats": [0.4, 0.6, 0.9, 0.3],
		"hp": 240.0, "hit_radius": 5.2, "armor": {"bullet": 0.55, "flak": 0.65, "missile": 0.85},
		"move": {"speed": 16.0, "reverse": 5.0, "accel": 4.0, "turn": 0.6, "wheeled": true},
		"turret": {"yaw": 1.3, "pitch": 1.0, "min": 0.0, "max": 60.0},
		"radar": 0.0, "camera": Vector2(20.0, 6.0),
		"missiles": {"name": "ЗУР MIM-104 PAC-2", "count": 4, "interval": 2.0, "reload": 9.0, "lock": 1.8, "radar": 7500.0, "cone": 16.0, "guidance": "radar", "thrust": 180.0, "burn": 3.2, "sustain": 40.0, "sustain_time": 5.0, "max_speed": 1100.0, "max_g": 24.0, "blast": 18.0, "damage": 230.0, "prox": 13.0, "life": 22.0, "fov": 140.0, "flare_res": 0.8, "mesh": "sam", "trail": "large", "launcher": "fixed", "angle": 38.0, "speed0": 40.0},
	},
	"buk": {
		"category": Category.GROUND, "role": "sam", "era": "jet", "nation": "su", "class": "Зенитный ракетный комплекс",
		"names": ["Бук-М1", "Бук-М1"], "max_slots": 1, "score": 35, "icon": "sam",
		"weapons": "4× ЗУР 9М38 · РЛС подсвета 7 км",
		"desc": "Самоходная огневая установка 9А310М1: собственная РЛС сопровождения и четыре ЗУР на пусковой, следящей за целью.",
		"stats": [0.35, 0.65, 0.88, 0.35],
		"hp": 250.0, "hit_radius": 5.0, "armor": {"bullet": 0.5, "flak": 0.6, "missile": 0.85},
		"move": {"speed": 14.0, "reverse": 5.0, "accel": 4.5, "turn": 0.8},
		"turret": {"yaw": 1.3, "pitch": 1.0, "min": 0.0, "max": 70.0},
		"radar": 0.0, "camera": Vector2(18.0, 5.6),
		"missiles": {"name": "ЗУР 9М38", "count": 4, "interval": 2.0, "reload": 9.0, "lock": 1.8, "radar": 7000.0, "cone": 16.0, "guidance": "radar", "thrust": 170.0, "burn": 3.0, "sustain": 45.0, "sustain_time": 5.0, "max_speed": 1000.0, "max_g": 26.0, "blast": 17.0, "damage": 220.0, "prox": 12.0, "life": 20.0, "fov": 140.0, "flare_res": 0.75, "mesh": "sam", "trail": "large", "launcher": "track", "speed0": 40.0},
	},
	"s300": {
		"category": Category.GROUND, "role": "sam", "era": "jet", "nation": "su", "class": "Зенитная ракетная система",
		"names": ["С-300ПС", "С-300ПС"], "max_slots": 1, "score": 40, "icon": "sam_vertical",
		"weapons": "4× ЗУР 5В55 · вертикальный пуск · 9,5 км",
		"desc": "Пусковая 5П85С на шасси МАЗ-543: контейнеры поднимаются вертикально, миномётный старт, самая дальнобойная и быстрая ЗУР — но долгий захват.",
		"stats": [0.3, 0.55, 1.0, 0.25],
		"hp": 230.0, "hit_radius": 5.8, "armor": {"bullet": 0.55, "flak": 0.65, "missile": 0.85},
		"move": {"speed": 13.0, "reverse": 4.0, "accel": 3.5, "turn": 0.5, "wheeled": true},
		"turret": {"yaw": 0.0, "pitch": 0.35, "min": 0.0, "max": 90.0},
		"radar": 0.0, "camera": Vector2(24.0, 7.0),
		"missiles": {"name": "ЗУР 5В55", "count": 4, "interval": 3.0, "reload": 16.0, "lock": 2.6, "radar": 9500.0, "cone": 14.0, "guidance": "radar", "thrust": 260.0, "burn": 4.0, "sustain": 30.0, "sustain_time": 5.0, "max_speed": 1500.0, "max_g": 22.0, "blast": 22.0, "damage": 280.0, "prox": 15.0, "life": 26.0, "fov": 170.0, "flare_res": 0.85, "mesh": "sam_big", "trail": "large", "launcher": "erect", "vertical": true, "speed0": 30.0},
	},
	"tor": {
		"category": Category.GROUND, "role": "sam", "era": "jet", "nation": "su", "class": "Зенитный ракетный комплекс",
		"names": ["Тор-М1", "Тор-М1"], "max_slots": 1, "score": 35, "icon": "sam_vertical",
		"weapons": "8× ЗУР 9М331 · вертикальный пуск · 5,5 км",
		"desc": "Комплекс ближнего рубежа: ЗУР в вертикальных ячейках башни, мгновенный захват и радиокомандное наведение, устойчивое к ловушкам.",
		"stats": [0.42, 0.7, 0.85, 0.4],
		"hp": 260.0, "hit_radius": 4.6, "armor": {"bullet": 0.45, "flak": 0.6, "missile": 0.8},
		"move": {"speed": 16.0, "reverse": 5.0, "accel": 5.0, "turn": 0.95},
		"turret": {"yaw": 2.0, "pitch": 1.0, "min": 0.0, "max": 0.0},
		"radar": 0.0, "camera": Vector2(17.0, 5.6),
		"missiles": {"name": "ЗУР 9М331", "count": 8, "interval": 1.2, "reload": 10.0, "lock": 1.0, "radar": 5500.0, "cone": 20.0, "guidance": "command", "thrust": 260.0, "burn": 2.5, "max_speed": 900.0, "max_g": 32.0, "blast": 12.0, "damage": 170.0, "prox": 10.0, "life": 14.0, "fov": 170.0, "flare_res": 0.95, "mesh": "sam_small", "trail": "small", "launcher": "vertical", "vertical": true, "speed0": 30.0},
	},
	"avenger": {
		"category": Category.GROUND, "role": "sam", "era": "jet", "nation": "us", "class": "ЗРК малой дальности",
		"names": ["AN/TWQ-1 Avenger", "AN/TWQ-1 Avenger"], "max_slots": 1, "score": 28, "icon": "sam_wheeled",
		"weapons": "8× FIM-92 Stinger · 12,7-мм M3P",
		"desc": "Турель на армейском «Хамви»: восемь ракет «Стингер» с тепловой ГСН и крупнокалиберный пулемёт. Быстр, но ловушки уводят ракеты.",
		"stats": [0.65, 0.35, 0.65, 0.65],
		"hp": 150.0, "hit_radius": 3.2, "armor": {"bullet": 0.8, "flak": 0.9},
		"move": {"speed": 22.0, "reverse": 6.0, "accel": 7.0, "turn": 0.9, "wheeled": true},
		"turret": {"yaw": 2.4, "pitch": 1.8, "min": -10.0, "max": 70.0},
		"radar": 0.0, "camera": Vector2(12.0, 4.2),
		"missiles": {"name": "FIM-92 Stinger", "count": 8, "interval": 1.2, "reload": 8.0, "lock": 1.3, "radar": 4500.0, "cone": 20.0, "guidance": "ir", "thrust": 300.0, "burn": 1.8, "max_speed": 750.0, "max_g": 30.0, "blast": 5.0, "damage": 120.0, "prox": 6.0, "life": 9.0, "fov": 110.0, "flare_res": 0.45, "mesh": "aam", "trail": "small", "launcher": "gun", "speed0": 50.0},
		"guns": {"name": "12,7-мм M3P", "interval": 0.06, "magazine": 200, "reload": 5.0, "speed": 890.0, "drag": 0.00045, "damage": 4.0, "type": "bullet", "life": 2.0, "spread": 0.4, "tracer": Color(1.0, 0.45, 0.3), "tracer_w": 0.18, "sound": "mg", "pitch": 1.0, "volume": -6.0, "flash": 0.7, "range": 1200.0},
		"primary": "missiles",
	},
	# ============ Флот: 1940-е ============
	"g5": {
		"category": Category.NAVAL, "role": "boat", "era": "prop", "nation": "su", "class": "Торпедный катер",
		"names": ["Г-5", "Г-5"], "max_slots": 2, "score": 20, "icon": "boat",
		"weapons": "2× 12,7-мм ДШК · 2× 533-мм торпеды · РС М-8",
		"desc": "Глиссирующий дюралевый катер конструкции Туполева: торпеды сбрасываются с кормы, залп реактивных снарядов бьёт по метке.",
		"stats": [0.95, 0.25, 0.72, 0.85],
		"hp": 110.0, "hit_radius": 5.0, "armor": {"bullet": 0.9, "flak": 0.95},
		"move": {"speed": 27.0, "reverse": 5.0, "accel": 8.0, "turn": 1.25, "planing": 1.0},
		"camera": Vector2(15.0, 4.5),
		"guns": {"name": "2× 12,7-мм ДШК", "interval": 0.075, "magazine": 100, "reload": 3.5, "speed": 850.0, "drag": 0.0006, "damage": 5.5, "type": "bullet", "life": 2.2, "spread": 0.45, "tracer": Color(0.55, 1.0, 0.5), "tracer_w": 0.2, "sound": "mg", "pitch": 1.0, "volume": -4.0, "flash": 0.8, "range": 1100.0},
		"torpedoes": {"name": "Торпеды 53-38", "count": 2, "interval": 1.2, "reload": 18.0},
		"special": {"type": "rockets", "name": "РС М-8 (залп)", "count": 1, "interval": 1.0, "reload": 40.0, "min": 500.0, "max": 4000.0, "salvo": 8, "blast": 12.0, "damage": 110.0},
	},
	"sboot": {
		"category": Category.NAVAL, "role": "boat", "era": "prop", "nation": "de", "class": "Торпедный катер",
		"names": ["Schnellboot S-100", "Schnellboot S-100"], "max_slots": 1, "score": 24, "icon": "boat",
		"weapons": "2-см Flak 38 · 2× 533-мм торпеды G7a",
		"desc": "Мореходный «шнельбот» с округлым корпусом и бронированной рубкой: крепче лёгких катеров, торпеды из носовых аппаратов.",
		"stats": [0.8, 0.45, 0.7, 0.6],
		"hp": 190.0, "hit_radius": 7.0, "armor": {"bullet": 0.75, "flak": 0.85},
		"move": {"speed": 22.0, "reverse": 5.0, "accel": 5.0, "turn": 0.9, "planing": 0.3},
		"camera": Vector2(22.0, 6.0),
		"guns": {"name": "2-см Flak 38", "interval": 0.12, "magazine": 40, "reload": 4.0, "speed": 900.0, "drag": 0.0004, "damage": 7.0, "type": "flak", "prox": 2.5, "prox_damage": 5.0, "life": 2.4, "spread": 0.4, "tracer": Color(1.0, 0.55, 0.25), "tracer_w": 0.22, "sound": "cannon", "pitch": 1.3, "volume": -4.0, "flash": 0.9, "range": 1600.0},
		"torpedoes": {"name": "Торпеды G7a", "count": 2, "interval": 1.2, "reload": 20.0},
	},
	"pt109": {
		"category": Category.NAVAL, "role": "boat", "era": "prop", "nation": "us", "class": "Торпедный катер",
		"names": ["PT-109 (Elco 80')", "PT-109 (Elco 80')"], "max_slots": 2, "score": 22, "icon": "boat",
		"weapons": "2× спарка 12,7-мм M2 · 4× торпеды Mk 8 · НУРС Mk 50",
		"desc": "Фанерный глиссер «Элко»: четыре торпедных аппарата по бортам, спаренные пулемёты и пусковые реактивных снарядов для удара по метке.",
		"stats": [0.8, 0.35, 0.78, 0.7],
		"hp": 150.0, "hit_radius": 6.0, "armor": {"bullet": 0.85, "flak": 0.9},
		"move": {"speed": 21.0, "reverse": 5.0, "accel": 6.0, "turn": 1.05, "planing": 0.8},
		"camera": Vector2(18.0, 5.2),
		"guns": {"name": "2× спарка 12,7-мм M2", "interval": 0.055, "magazine": 150, "reload": 4.0, "speed": 890.0, "drag": 0.00045, "damage": 5.0, "type": "bullet", "life": 2.2, "spread": 0.45, "tracer": Color(1.0, 0.42, 0.3), "tracer_w": 0.2, "sound": "mg", "pitch": 1.0, "volume": -4.0, "flash": 0.8, "range": 1300.0},
		"torpedoes": {"name": "Торпеды Mk 8", "count": 4, "interval": 0.8, "reload": 18.0},
		"special": {"type": "rockets", "name": "НУРС Mk 50 (залп)", "count": 1, "interval": 1.0, "reload": 40.0, "min": 500.0, "max": 3500.0, "salvo": 8, "blast": 11.0, "damage": 105.0},
	},
	"fletcher": {
		"category": Category.NAVAL, "role": "ship", "era": "prop", "nation": "us", "class": "Эсминец",
		"names": ["Эсминец типа Fletcher", "Эсминец типа Fletcher"], "max_slots": 1, "score": 60, "icon": "ship",
		"weapons": "5× 127-мм 5\"/38 · 40-мм Bofors · 5× 533-мм торпеды",
		"desc": "Гладкопалубный эсминец US Navy: пять универсальных 127-мм установок, автоматическая зенитная артиллерия и торпедный залп.",
		"stats": [0.5, 0.8, 0.85, 0.25],
		"hp": 1500.0, "hit_radius": 12.0, "armor": {"bullet": 0.1, "flak": 0.15, "missile": 0.55, "shell": 0.55, "torpedo": 1.3, "cruise": 0.8, "bomb": 0.9, "ballistic": 0.6},
		"move": {"speed": 18.0, "reverse": 5.0, "accel": 1.4, "turn": 0.14},
		"camera": Vector2(75.0, 24.0),
		"main": {"name": "127-мм 5\"/38", "interval": 1.1, "speed": 790.0, "blast": 9.0, "blast_damage": 105.0, "life": 14.0, "spread": 0.35, "range": 5000.0},
		"aa": {"name": "40-мм Bofors · 20-мм Oerlikon", "interval": 0.07, "speed": 880.0, "damage": 5.0, "prox": 3.5, "prox_damage": 7.0, "life": 2.8, "range": 2200.0, "missile_kill": 0.02},
		"torpedoes": {"name": "Торпеды Mk 15", "count": 5, "interval": 0.6, "reload": 25.0},
	},
	"gnevny": {
		"category": Category.NAVAL, "role": "ship", "era": "prop", "nation": "su", "class": "Эсминец",
		"names": ["Эсминец пр. 7 «Гневный»", "Эсминец пр. 7 «Гневный»"], "max_slots": 1, "score": 60, "icon": "ship",
		"weapons": "4× 130-мм Б-13 · 76-мм и 45-мм зенитки · 6× 533-мм торпеды",
		"desc": "Эсминец-«семёрка» с полубаком: четыре 130-мм орудия, два трёхтрубных торпедных аппарата, быстрее «Флетчера».",
		"stats": [0.55, 0.75, 0.82, 0.25],
		"hp": 1450.0, "hit_radius": 12.0, "armor": {"bullet": 0.1, "flak": 0.15, "missile": 0.55, "shell": 0.55, "torpedo": 1.3, "cruise": 0.8, "bomb": 0.9, "ballistic": 0.6},
		"move": {"speed": 19.0, "reverse": 5.0, "accel": 1.5, "turn": 0.14},
		"camera": Vector2(75.0, 24.0),
		"main": {"name": "130-мм Б-13", "interval": 1.4, "speed": 870.0, "blast": 10.0, "blast_damage": 120.0, "life": 14.0, "spread": 0.35, "range": 5500.0},
		"aa": {"name": "76-мм 34-К · 45-мм 21-К", "interval": 0.12, "speed": 800.0, "damage": 7.0, "prox": 4.0, "prox_damage": 8.0, "life": 3.0, "range": 2400.0, "missile_kill": 0.02},
		"torpedoes": {"name": "Торпеды 53-38", "count": 6, "interval": 0.6, "reload": 25.0},
	},
	# ============ Флот: реактивная эпоха ============
	"seababy": {
		"category": Category.NAVAL, "role": "boat", "era": "jet", "nation": "ua", "class": "Безэкипажный катер",
		"names": ["Sea Baby", "Sea Baby"], "max_slots": 2, "score": 20, "icon": "boat",
		"weapons": "12,7-мм модуль · 2× торпеды · баллистическая ракета",
		"desc": "Безэкипажный скоростной катер: пулемётный модуль, торпеды против крупных кораблей и баллистическая ракета для ударов по метке.",
		"stats": [0.9, 0.2, 0.78, 0.9],
		"hp": 100.0, "hit_radius": 4.5, "armor": {"bullet": 0.8, "flak": 0.9},
		"move": {"speed": 25.0, "reverse": 7.0, "accel": 9.0, "turn": 1.35, "planing": 0.7},
		"camera": Vector2(13.0, 4.2),
		"guns": {"name": "12,7-мм пулемёт", "interval": 0.085, "magazine": 100, "reload": 3.5, "speed": 850.0, "drag": 0.0006, "damage": 6.0, "type": "bullet", "life": 2.2, "spread": 0.45, "tracer": Color(0.55, 1.0, 0.5), "tracer_w": 0.2, "sound": "mg", "pitch": 1.0, "volume": -4.0, "flash": 0.8, "range": 1100.0},
		"torpedoes": {"name": "Торпеды 533-мм", "count": 2, "interval": 1.2, "reload": 16.0},
		"special": {"type": "ballistic", "name": "Баллистическая ракета", "count": 1, "interval": 1.0, "reload": 45.0, "min": 600.0, "max": 9000.0},
	},
	"markvi": {
		"category": Category.NAVAL, "role": "boat", "era": "jet", "nation": "us", "class": "Патрульный катер",
		"names": ["Mark VI", "Mark VI"], "max_slots": 1, "score": 24, "icon": "boat",
		"weapons": "2× 25-мм Mk 38 Mod 2 · 12,7-мм M2",
		"desc": "Патрульный катер US Navy с двумя дистанционными 25-мм установками: сильнейшая артиллерия среди катеров, поражает и авиацию.",
		"stats": [0.78, 0.45, 0.68, 0.62],
		"hp": 180.0, "hit_radius": 6.5, "armor": {"bullet": 0.7, "flak": 0.8},
		"move": {"speed": 20.0, "reverse": 6.0, "accel": 5.0, "turn": 0.95, "planing": 0.6},
		"camera": Vector2(20.0, 6.0),
		"guns": {"name": "2× 25-мм Mk 38", "interval": 0.16, "magazine": 50, "reload": 5.0, "speed": 1100.0, "drag": 0.00022, "damage": 12.0, "type": "flak", "prox": 3.5, "prox_damage": 8.0, "life": 3.0, "spread": 0.25, "tracer": Color(1.0, 0.7, 0.3), "tracer_w": 0.28, "sound": "cannon", "pitch": 1.15, "volume": -3.0, "flash": 1.1, "range": 2200.0},
		"guns2": {"name": "12,7-мм M2", "interval": 0.07, "magazine": 100, "reload": 4.0, "speed": 890.0, "drag": 0.00045, "damage": 4.5, "type": "bullet", "life": 2.0, "spread": 0.45, "tracer": Color(1.0, 0.42, 0.3), "tracer_w": 0.18, "sound": "mg", "pitch": 1.0, "volume": -6.0, "flash": 0.7, "range": 1200.0},
	},
	"cb90": {
		"category": Category.NAVAL, "role": "boat", "era": "jet", "nation": "se", "class": "Штурмовой катер",
		"names": ["Stridsbåt 90 (CB 90)", "Stridsbåt 90 (CB 90)"], "max_slots": 2, "score": 22, "icon": "boat",
		"weapons": "Спарка 12,7-мм · 40-мм гранатомёт Mk 19 · ПТУР RBS 17",
		"desc": "Шведский водомётный катер: разворачивается почти на месте, гранатомёт накрывает берег, ракеты RBS 17 бьют по метке.",
		"stats": [0.9, 0.35, 0.62, 1.0],
		"hp": 130.0, "hit_radius": 5.0, "armor": {"bullet": 0.75, "flak": 0.85},
		"move": {"speed": 24.0, "reverse": 8.0, "accel": 9.0, "turn": 1.6, "planing": 0.8},
		"camera": Vector2(15.0, 4.8),
		"guns": {"name": "Спарка 12,7-мм", "interval": 0.06, "magazine": 150, "reload": 4.0, "speed": 890.0, "drag": 0.00045, "damage": 4.5, "type": "bullet", "life": 2.0, "spread": 0.45, "tracer": Color(1.0, 0.45, 0.3), "tracer_w": 0.18, "sound": "mg", "pitch": 1.0, "volume": -5.0, "flash": 0.7, "range": 1200.0},
		"guns2": {"name": "40-мм Mk 19", "interval": 0.18, "magazine": 32, "reload": 6.0, "speed": 240.0, "drag": 0.0, "damage": 0.0, "type": "shell", "blast": 5.0, "blast_damage": 32.0, "life": 9.0, "spread": 0.6, "tracer": Color(1.0, 0.85, 0.5), "tracer_w": 0.14, "sound": "cannon", "pitch": 1.6, "volume": -8.0, "flash": 0.6, "range": 1500.0, "lob": true},
		"special": {"type": "cruise", "name": "ПТУР RBS 17", "count": 2, "interval": 1.5, "reload": 28.0, "min": 500.0, "max": 7000.0, "direct": true},
	},
	"molniya": {
		"category": Category.NAVAL, "role": "ship", "era": "jet", "nation": "su", "class": "Ракетный катер",
		"names": ["Р-60 пр. 12411 «Молния»", "Р-60 пр. 12411 «Молния»"], "max_slots": 1, "score": 50, "icon": "missile_boat",
		"weapons": "76-мм АК-176 · 2× АК-630 · 4× ПКР П-270 «Москит»",
		"desc": "Ракетный катер: четыре сверхзвуковые противокорабельные ракеты по метке, 76-мм артустановка и автоматы АК-630 для самообороны.",
		"stats": [0.6, 0.6, 0.92, 0.35],
		"hp": 700.0, "hit_radius": 9.0, "armor": {"bullet": 0.2, "flak": 0.3, "missile": 0.65, "shell": 0.6, "torpedo": 1.3, "cruise": 0.85, "bomb": 0.9, "ballistic": 0.7},
		"move": {"speed": 19.0, "reverse": 5.0, "accel": 2.2, "turn": 0.3},
		"camera": Vector2(42.0, 13.0),
		"main": {"name": "76-мм АК-176", "interval": 0.55, "speed": 980.0, "blast": 6.0, "blast_damage": 60.0, "prox": 7.0, "life": 8.0, "spread": 0.3, "range": 4500.0},
		"aa": {"name": "2× 30-мм АК-630", "interval": 0.025, "speed": 900.0, "damage": 4.0, "prox": 3.0, "prox_damage": 5.0, "life": 2.0, "range": 1600.0, "missile_kill": 0.035},
		"special": {"type": "cruise", "name": "ПКР П-270 «Москит»", "count": 4, "interval": 1.2, "reload": 35.0, "min": 1500.0, "max": 9000.0},
	},
	"burke": {
		"category": Category.NAVAL, "role": "ship", "era": "jet", "nation": "us", "class": "Эсминец УРО",
		"names": ["Эсминец типа Arleigh Burke", "Эсминец типа Arleigh Burke"], "max_slots": 1, "score": 70, "icon": "ship",
		"weapons": "127-мм Mk 45 · Phalanx CIWS · ЗУР SM-2 · ПКР Harpoon",
		"desc": "Эсминец с системой «Иджис»: ЗУР SM-2 из ячеек вертикального пуска по воздушным целям, «Гарпуны» по метке, «Фаланкс» сбивает ракеты.",
		"stats": [0.45, 0.9, 1.0, 0.2],
		"hp": 1800.0, "hit_radius": 14.0, "armor": {"bullet": 0.08, "flak": 0.12, "missile": 0.5, "shell": 0.5, "torpedo": 1.3, "cruise": 0.8, "bomb": 0.9, "ballistic": 0.6},
		"move": {"speed": 16.0, "reverse": 5.0, "accel": 1.2, "turn": 0.12},
		"camera": Vector2(95.0, 28.0),
		"main": {"name": "127-мм Mk 45", "interval": 1.6, "speed": 800.0, "blast": 10.0, "blast_damage": 120.0, "life": 14.0, "spread": 0.3, "range": 6000.0},
		"aa": {"name": "20-мм Phalanx CIWS", "interval": 0.022, "speed": 1100.0, "damage": 3.5, "prox": 3.0, "prox_damage": 5.0, "life": 1.8, "range": 1500.0, "missile_kill": 0.04},
		"sam": {"name": "ЗУР SM-2", "count": 6, "interval": 1.5, "reload": 12.0, "lock": 1.6, "radar": 8000.0, "cone": 18.0, "guidance": "radar", "thrust": 220.0, "burn": 3.0, "sustain": 40.0, "sustain_time": 6.0, "max_speed": 1200.0, "max_g": 25.0, "blast": 16.0, "damage": 220.0, "prox": 12.0, "life": 22.0, "fov": 170.0, "flare_res": 0.8, "mesh": "sam", "trail": "large", "vertical": true, "speed0": 30.0},
		"special": {"type": "cruise", "name": "ПКР RGM-84 Harpoon", "count": 4, "interval": 1.2, "reload": 35.0, "min": 1500.0, "max": 9000.0},
	},
	"sovremenny": {
		"category": Category.NAVAL, "role": "ship", "era": "jet", "nation": "su", "class": "Эсминец",
		"names": ["Эсминец пр. 956 «Современный»", "Эсминец пр. 956 «Современный»"], "max_slots": 1, "score": 70, "icon": "ship",
		"weapons": "2× 130-мм АК-130 · 4× АК-630 · ЗУР «Ураган» · ПКР «Москит»",
		"desc": "Ударный эсминец: две спаренные 130-мм установки, ЗУР 9М38 с однобалочных пусковых и сверхзвуковые «Москиты» по метке.",
		"stats": [0.48, 0.88, 1.0, 0.2],
		"hp": 1800.0, "hit_radius": 14.0, "armor": {"bullet": 0.08, "flak": 0.12, "missile": 0.5, "shell": 0.5, "torpedo": 1.3, "cruise": 0.8, "bomb": 0.9, "ballistic": 0.6},
		"move": {"speed": 17.0, "reverse": 5.0, "accel": 1.3, "turn": 0.12},
		"camera": Vector2(95.0, 28.0),
		"main": {"name": "130-мм АК-130", "interval": 1.0, "speed": 850.0, "blast": 11.0, "blast_damage": 125.0, "life": 14.0, "spread": 0.3, "range": 6000.0},
		"aa": {"name": "4× 30-мм АК-630", "interval": 0.02, "speed": 900.0, "damage": 4.0, "prox": 3.0, "prox_damage": 5.0, "life": 2.0, "range": 1600.0, "missile_kill": 0.04},
		"sam": {"name": "ЗУР 9М38 «Ураган»", "count": 6, "interval": 2.0, "reload": 12.0, "lock": 1.8, "radar": 8000.0, "cone": 16.0, "guidance": "radar", "thrust": 170.0, "burn": 3.0, "sustain": 45.0, "sustain_time": 5.0, "max_speed": 1000.0, "max_g": 26.0, "blast": 17.0, "damage": 220.0, "prox": 12.0, "life": 20.0, "fov": 150.0, "flare_res": 0.75, "mesh": "sam", "trail": "large", "speed0": 40.0},
		"special": {"type": "cruise", "name": "ПКР П-270 «Москит»", "count": 4, "interval": 1.2, "reload": 35.0, "min": 1500.0, "max": 9000.0},
	},
	# ============ Флагманы (стратегические цели, под управлением встроенного ИИ) ============
	"cleveland": {
		"category": Category.NAVAL, "role": "flagship", "era": "prop", "nation": "us", "class": "Лёгкий крейсер",
		"names": ["Крейсер «Кливленд»", "Крейсер «Кливленд»"], "max_slots": 0, "score": 150, "icon": "cruiser",
		"weapons": "12× 152-мм Mk 16 · 127-мм и 40-мм зенитная артиллерия",
		"desc": "Флагман команды в эпоху 1940-х: четыре трёхорудийные башни главного калибра и плотная зенитная артиллерия.",
		"stats": [0.3, 1.0, 1.0, 0.1],
		"hp": 4000.0, "hit_radius": 16.0, "armor": {"bullet": 0.08, "flak": 0.12, "missile": 0.5, "shell": 0.5, "torpedo": 1.4, "cruise": 0.8, "bomb": 0.9, "ballistic": 0.6},
		"move": {"speed": 5.0},
		"main": {"name": "152-мм Mk 16", "interval": 3.2, "speed": 760.0, "blast": 12.0, "blast_damage": 130.0, "life": 14.0, "spread": 0.35, "range": 3200.0},
		"aa": {"name": "40-мм Bofors", "interval": 0.06, "speed": 880.0, "damage": 5.0, "prox": 3.5, "prox_damage": 6.0, "life": 2.2, "range": 1600.0, "missile_kill": 0.03},
	},
	"kirov26": {
		"category": Category.NAVAL, "role": "flagship", "era": "prop", "nation": "su", "class": "Крейсер",
		"names": ["Крейсер «Киров» (пр. 26)", "Крейсер «Киров» (пр. 26)"], "max_slots": 0, "score": 150, "icon": "cruiser",
		"weapons": "9× 180-мм Б-1-П · 100-мм и 45-мм зенитная артиллерия",
		"desc": "Флагман команды в эпоху 1940-х: три трёхорудийные 180-мм башни и универсальные 100-мм установки.",
		"stats": [0.3, 1.0, 1.0, 0.1],
		"hp": 4000.0, "hit_radius": 16.0, "armor": {"bullet": 0.08, "flak": 0.12, "missile": 0.5, "shell": 0.5, "torpedo": 1.4, "cruise": 0.8, "bomb": 0.9, "ballistic": 0.6},
		"move": {"speed": 5.0},
		"main": {"name": "180-мм Б-1-П", "interval": 3.4, "speed": 800.0, "blast": 13.0, "blast_damage": 135.0, "life": 14.0, "spread": 0.35, "range": 3200.0},
		"aa": {"name": "45-мм 21-К", "interval": 0.08, "speed": 760.0, "damage": 5.0, "prox": 3.5, "prox_damage": 6.0, "life": 2.4, "range": 1600.0, "missile_kill": 0.03},
	},
	"ticonderoga": {
		"category": Category.NAVAL, "role": "flagship", "era": "jet", "nation": "us", "class": "Крейсер УРО",
		"names": ["Крейсер «Тикондерога»", "Крейсер «Тикондерога»"], "max_slots": 0, "score": 150, "icon": "cruiser",
		"weapons": "2× 127-мм Mk 45 · 2× Phalanx · ЗУР SM-2",
		"desc": "Флагман команды: крейсер УРО с системой «Иджис», установками вертикального пуска и зенитными автоматами «Фаланкс».",
		"stats": [0.3, 1.0, 1.0, 0.1],
		"hp": 4000.0, "hit_radius": 16.0, "armor": {"bullet": 0.08, "flak": 0.12, "missile": 0.5, "shell": 0.5, "torpedo": 1.4, "cruise": 0.8, "bomb": 0.9, "ballistic": 0.6},
		"move": {"speed": 5.0},
		"main": {"name": "127-мм Mk 45", "interval": 3.2, "speed": 700.0, "blast": 8.0, "blast_damage": 95.0, "life": 12.0, "spread": 0.35, "range": 2800.0},
		"aa": {"name": "20-мм Phalanx CIWS", "interval": 0.06, "speed": 1100.0, "damage": 5.0, "prox": 3.5, "prox_damage": 6.0, "life": 1.8, "range": 1500.0, "missile_kill": 0.035},
		"sam": {"name": "ЗУР SM-2", "count": 2, "interval": 3.0, "reload": 18.0, "lock": 2.0, "radar": 6000.0, "cone": 180.0, "guidance": "radar", "thrust": 220.0, "burn": 3.0, "sustain": 40.0, "sustain_time": 6.0, "max_speed": 1100.0, "max_g": 24.0, "blast": 15.0, "damage": 190.0, "prox": 12.0, "life": 20.0, "fov": 170.0, "flare_res": 0.75, "mesh": "sam", "trail": "large", "vertical": true, "speed0": 30.0},
	},
	"slava": {
		"category": Category.NAVAL, "role": "flagship", "era": "jet", "nation": "su", "class": "Ракетный крейсер",
		"names": ["Крейсер пр. 1164 «Слава»", "Крейсер пр. 1164 «Слава»"], "max_slots": 0, "score": 150, "icon": "cruiser",
		"weapons": "130-мм АК-130 · 6× АК-630 · ЗУР С-300Ф",
		"desc": "Флагман команды: ракетный крейсер с шестнадцатью пусковыми «Вулкан» вдоль бортов и зенитной системой С-300Ф.",
		"stats": [0.3, 1.0, 1.0, 0.1],
		"hp": 4000.0, "hit_radius": 16.0, "armor": {"bullet": 0.08, "flak": 0.12, "missile": 0.5, "shell": 0.5, "torpedo": 1.4, "cruise": 0.8, "bomb": 0.9, "ballistic": 0.6},
		"move": {"speed": 5.0},
		"main": {"name": "130-мм АК-130", "interval": 3.0, "speed": 850.0, "blast": 9.0, "blast_damage": 100.0, "life": 12.0, "spread": 0.35, "range": 2800.0},
		"aa": {"name": "30-мм АК-630", "interval": 0.05, "speed": 900.0, "damage": 5.0, "prox": 3.5, "prox_damage": 6.0, "life": 2.0, "range": 1500.0, "missile_kill": 0.035},
		"sam": {"name": "ЗУР 5В55РМ (С-300Ф)", "count": 2, "interval": 3.0, "reload": 18.0, "lock": 2.0, "radar": 6000.0, "cone": 180.0, "guidance": "radar", "thrust": 260.0, "burn": 4.0, "sustain": 30.0, "sustain_time": 5.0, "max_speed": 1300.0, "max_g": 22.0, "blast": 16.0, "damage": 200.0, "prox": 13.0, "life": 22.0, "fov": 170.0, "flare_res": 0.8, "mesh": "sam_big", "trail": "large", "vertical": true, "speed0": 30.0},
	},
}
const VEHICLE_ORDER := [
	"bf109", "fw190", "yak9", "la5", "p51", "p40", "spitfire", "zero",
	"mig29", "su27", "f16", "f4e", "mirage2000", "rafale",
	"il2", "b25", "su24m", "su25", "a10",
	"wirbelwind", "m16", "zsu37", "flak88", "k52",
	"gepard", "shilka", "m163", "tunguska", "pantsir", "patriot", "buk", "s300", "tor", "avenger",
	"g5", "sboot", "pt109", "fletcher", "gnevny",
	"seababy", "markvi", "cb90", "molniya", "burke", "sovremenny",
]
## Флагманы команд (стратегические цели, не занимают слотов): [эпоха 1940-х, реактивная] × [синие, красные].
const FLAGSHIPS := [["cleveland", "kirov26"], ["ticonderoga", "slava"]]
const FLAGSHIP_ORDER := ["cleveland", "kirov26", "ticonderoga", "slava"]

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
	var info := vehicle_info(type_id)
	if info.is_empty():
		return "—"
	var names: Array = info["names"]
	return str(names[clampi(team, 0, names.size() - 1)])


static func role_of(type_id: String) -> String:
	return str(vehicle_info(type_id).get("role", ""))


## Класс техники для интерфейса («Торпедный катер», «Эсминец УРО»…), иначе — название роли.
static func vehicle_role(type_id: String) -> String:
	var info := vehicle_info(type_id)
	if info.has("class"):
		return str(info["class"])
	return str(ROLE_TITLES.get(role_of(type_id), ""))


static func is_aircraft(type_id: String) -> bool:
	return category_of(type_id) == Category.AIR


## Крупный корабль (боевой корабль игрока или флагман) — приоритетная цель торпед и ПКР.
static func is_major_ship(type_id: String) -> bool:
	var r := role_of(type_id)
	return r == "ship" or r == "flagship"


static func is_flagship(type_id: String) -> bool:
	return role_of(type_id) == "flagship"


## Флагман команды для эпохи боя (1940-е — артиллерийские крейсера, иначе — ракетные).
static func flagship_for(team: int, era: int) -> String:
	var row: Array = FLAGSHIPS[0 if era == 1 else 1]
	return str(row[clampi(team, 0, 1)])


static func max_slots(type_id: String) -> int:
	return int(vehicle_info(type_id).get("max_slots", 0))


static func category_of(type_id: String) -> int:
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
