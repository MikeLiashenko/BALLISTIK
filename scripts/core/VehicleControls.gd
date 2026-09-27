class_name VehicleControls
extends RefCounted
## Унифицированные команды управления техникой. Заполняются игроком (PlayerController)
## или ботом (BotAI) перед физическим шагом техники — техника не знает, кто ею управляет.

var throttle: float = 0.0          ## Наземная/морская техника: ход -1..1. Авиация: РУД 0..1
var steer: float = 0.0             ## Поворот корпуса / руль: -1 влево .. 1 вправо
var pitch: float = 0.0             ## Авиация: тангаж, +1 — нос вверх
var roll: float = 0.0              ## Авиация: крен, +1 — вправо
var yaw: float = 0.0               ## Авиация: рыскание, +1 — вправо
var use_autopilot: bool = false    ## Авиация: автоматически лететь к fly_target
var fly_target: Vector3 = Vector3.ZERO
var aim_point: Vector3 = Vector3.ZERO   ## Мировая точка прицеливания башни/оружия
var has_aim: bool = false
var fire_primary: bool = false     ## Основное оружие (удерживается)
var fire_secondary: bool = false   ## Дополнительное оружие (удерживается)
var fire_special: bool = false     ## Пуск по тактической метке (одиночное событие)
var special_target: Vector3 = Vector3.ZERO
var deploy_flares: bool = false    ## Отстрел ловушек (одиночное событие)
var lock_target: Node3D = null     ## Желаемая цель для захвата ракетами


func clear() -> void:
	throttle = 0.0
	steer = 0.0
	pitch = 0.0
	roll = 0.0
	yaw = 0.0
	use_autopilot = false
	has_aim = false
	fire_primary = false
	fire_secondary = false
	fire_special = false
	deploy_flares = false
	lock_target = null


## Сбрасывает одиночные события после того, как техника их обработала.
func consume_triggers() -> void:
	fire_special = false
	deploy_flares = false
