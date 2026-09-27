class_name Weapon
extends RefCounted
## Модель оружия: боекомплект, магазин, скорострельность и перезарядка.
## Два режима:
##  * магазинный (magazine_size > 0) — бесконечный запас, перезарядка магазина после опустошения;
##  * штучный (ракеты, бомбы, торпеды, ловушки) — боеприпасы восстанавливаются по одному.

var id: String = ""
var display_name: String = ""
var max_ammo: int = 0
var ammo: int = 0
var magazine_size: int = 0
var magazine: int = 0
var fire_interval: float = 0.1
var reload_time: float = 1.0
var cooldown: float = 0.0
var reload_timer: float = 0.0
var reloading: bool = false


func _init(p_id: String, p_name: String, p_max_ammo: int, p_fire_interval: float, p_reload_time: float, p_magazine_size: int = 0) -> void:
	id = p_id
	display_name = p_name
	max_ammo = p_max_ammo
	ammo = p_max_ammo
	fire_interval = p_fire_interval
	reload_time = maxf(p_reload_time, 0.01)
	magazine_size = p_magazine_size
	magazine = p_magazine_size


func is_magazine_fed() -> bool:
	return magazine_size > 0


func can_fire() -> bool:
	if cooldown > 0.0 or reloading:
		return false
	if is_magazine_fed():
		return magazine > 0
	return ammo > 0


func has_ammo() -> bool:
	return magazine > 0 if is_magazine_fed() else ammo > 0


func consume() -> void:
	cooldown = fire_interval
	if is_magazine_fed():
		magazine -= 1
		if magazine <= 0:
			start_reload()
	else:
		ammo = maxi(ammo - 1, 0)


func start_reload() -> void:
	if not is_magazine_fed() or reloading or magazine >= magazine_size:
		return
	reloading = true
	reload_timer = reload_time


func update(delta: float) -> void:
	cooldown = maxf(cooldown - delta, 0.0)
	if is_magazine_fed():
		if reloading:
			reload_timer -= delta
			if reload_timer <= 0.0:
				reloading = false
				reload_timer = 0.0
				magazine = magazine_size
	elif ammo < max_ammo:
		reload_timer += delta
		if reload_timer >= reload_time:
			reload_timer = 0.0
			ammo += 1
	else:
		reload_timer = 0.0


## 1.0 — оружие готово; меньше — прогресс перезарядки / восстановления следующего боеприпаса.
func get_ready_ratio() -> float:
	if is_magazine_fed():
		if reloading:
			return clampf(1.0 - reload_timer / reload_time, 0.0, 1.0)
		return 1.0
	if ammo >= max_ammo:
		return 1.0
	return clampf(reload_timer / reload_time, 0.0, 1.0)


func get_ammo_text() -> String:
	if is_magazine_fed():
		if reloading:
			return "ПЕРЕЗАРЯДКА"
		return "%d / %d" % [magazine, magazine_size]
	return "%d / %d" % [ammo, max_ammo]
