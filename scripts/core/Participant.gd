class_name Participant
extends RefCounted
## Участник боя — игрок или бот. Хранит занятый слот техники, статистику и таймер возрождения.
## В сетевой игре человек (is_human) связан с пиром ENet (peer_id); is_player — только участник,
## которым управляют на этом устройстве.

var id: int = 0
var name: String = ""
var team: int = 0
var is_player: bool = false
var is_human: bool = false
var peer_id: int = 0                ## Пир ENet человека (1 — хост); 0 — бот
var net_ready: bool = false         ## Клиент загрузил карту и готов к появлению техники
var vehicle_type: String = ""      ## Тип техники в занятом слоте ("" — слот не занят)
var vehicle: Vehicle = null         ## Текущая техника на поле боя
var alive: bool = false
var respawn_timer: float = 0.0
var kills: int = 0
var deaths: int = 0
var score: int = 0


func _init(p_id: int, p_name: String, p_team: int, p_is_player: bool) -> void:
	id = p_id
	name = p_name
	team = p_team
	is_player = p_is_player
	is_human = p_is_player


func get_vehicle_label() -> String:
	if vehicle_type == "":
		return "—"
	return GameDB.vehicle_name(vehicle_type, team)


func has_live_vehicle() -> bool:
	return alive and vehicle != null and is_instance_valid(vehicle) and not vehicle.is_dead
