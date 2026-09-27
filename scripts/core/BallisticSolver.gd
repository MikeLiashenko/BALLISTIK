class_name BallisticSolver
extends RefCounted
## Баллистика: интегрирование полёта с гравитацией и квадратичным сопротивлением воздуха,
## решение задачи «попасть в точку по параболе», прогноз траектории и точки упреждения.
## Снаряды (Projectile) используют тот же закон ускорения, что и решатель.

const SOLVER_DT := 1.0 / 30.0
const PREVIEW_DT := 1.0 / 20.0


## Ускорение снаряда: гравитация + квадратичное сопротивление (a = -k·|v|·v).
static func acceleration(velocity: Vector3, gravity: float, drag: float) -> Vector3:
	return Vector3(0.0, -gravity, 0.0) - velocity * (velocity.length() * drag)


## Начальная скорость для попадания из from в target при заданном угле возвышения.
## Скорость подбирается бисекцией по результату численного моделирования (с учётом сопротивления).
## Возвращает Vector3.ZERO, если цель недостижима в диапазоне [min_speed, max_speed].
static func solve_launch_velocity(from: Vector3, target: Vector3, elevation_deg: float, gravity: float, drag: float, min_speed: float, max_speed: float) -> Vector3:
	var flat := Vector3(target.x - from.x, 0.0, target.z - from.z)
	var dist := flat.length()
	if dist < 1.0:
		return Vector3.ZERO
	var dir := flat / dist
	var elev := deg_to_rad(elevation_deg)
	if _range_for_speed(from, dir, elev, max_speed, target.y, gravity, drag) < dist:
		return Vector3.ZERO
	var lo := min_speed
	var hi := max_speed
	for i in 26:
		var mid := (lo + hi) * 0.5
		if _range_for_speed(from, dir, elev, mid, target.y, gravity, drag) < dist:
			lo = mid
		else:
			hi = mid
	var speed := (lo + hi) * 0.5
	return dir * (speed * cos(elev)) + Vector3.UP * (speed * sin(elev))


static func _range_for_speed(from: Vector3, dir: Vector3, elev: float, speed: float, target_y: float, gravity: float, drag: float) -> float:
	var v := dir * (speed * cos(elev)) + Vector3.UP * (speed * sin(elev))
	var p := from
	var t := 0.0
	while t < 90.0:
		var prev := p
		v += acceleration(v, gravity, drag) * SOLVER_DT
		p += v * SOLVER_DT
		t += SOLVER_DT
		if v.y < 0.0 and p.y <= target_y:
			var k := (prev.y - target_y) / maxf(prev.y - p.y, 0.0001)
			var hit := prev.lerp(p, clampf(k, 0.0, 1.0))
			return Vector2(hit.x - from.x, hit.z - from.z).length()
	return Vector2(p.x - from.x, p.z - from.z).length()


## Направление выстрела при фиксированной начальной скорости (настильная траектория, без сопротивления).
## Возвращает Vector3.ZERO, если цель вне досягаемости.
static func solve_direction(from: Vector3, target: Vector3, speed: float, gravity: float) -> Vector3:
	var flat := Vector3(target.x - from.x, 0.0, target.z - from.z)
	var x := flat.length()
	var y := target.y - from.y
	if x < 0.5:
		return (target - from).normalized()
	var v2 := speed * speed
	var disc := v2 * v2 - gravity * (gravity * x * x + 2.0 * y * v2)
	if disc < 0.0:
		return Vector3.ZERO
	var angle := atan((v2 - sqrt(disc)) / (gravity * x))
	return flat / x * cos(angle) + Vector3.UP * sin(angle)


## Примерное время полёта до цели (для индикации в тактическом режиме).
static func estimate_flight_time(from: Vector3, v0: Vector3, target_y: float, gravity: float, drag: float) -> float:
	var v := v0
	var p := from
	var t := 0.0
	while t < 90.0:
		v += acceleration(v, gravity, drag) * SOLVER_DT
		p += v * SOLVER_DT
		t += SOLVER_DT
		if v.y < 0.0 and p.y <= target_y:
			return t
	return t


## Прогноз траектории (для отрисовки дуги и прицела бомбометания CCIP).
## Останавливается при касании поверхности рельефа/воды, если передан terrain.
static func predict_path(from: Vector3, v0: Vector3, gravity: float, drag: float, max_time: float, terrain: Terrain = null, dt: float = PREVIEW_DT) -> PackedVector3Array:
	var pts := PackedVector3Array()
	var p := from
	var v := v0
	var t := 0.0
	pts.append(p)
	while t < max_time:
		var prev := p
		v += acceleration(v, gravity, drag) * dt
		p += v * dt
		t += dt
		var ground := -1000.0
		if terrain != null:
			ground = terrain.get_surface_height(p.x, p.z)
		if p.y <= ground:
			var k := (prev.y - ground) / maxf(prev.y - p.y, 0.0001)
			pts.append(prev.lerp(p, clampf(k, 0.0, 1.0)))
			return pts
		pts.append(p)
	return pts


## Время полёта снаряда на дистанцию distance при квадратичном сопротивлении
## (скорость убывает как v = v0 / (1 + k·v0·t), путь s = ln(1 + k·v0·t) / k).
static func flight_time(distance: float, muzzle_speed: float, drag: float) -> float:
	if drag <= 0.0000001:
		return distance / maxf(muzzle_speed, 1.0)
	var x := minf(drag * distance, 6.0)
	return (exp(x) - 1.0) / (drag * maxf(muzzle_speed, 1.0))


## Точка упреждения: куда целиться, чтобы снаряд встретил движущуюся цель.
## Учитывает относительную скорость стрелка (снаряды наследуют скорость носителя) и падение снаряда.
static func compute_lead(shooter_pos: Vector3, shooter_vel: Vector3, target_pos: Vector3, target_vel: Vector3, muzzle_speed: float, drag: float, gravity: float) -> Vector3:
	var aim := target_pos
	var t := 0.0
	for i in 5:
		t = flight_time(shooter_pos.distance_to(aim), muzzle_speed, drag)
		aim = target_pos + (target_vel - shooter_vel) * t
	aim.y += 0.5 * gravity * t * t
	return aim
