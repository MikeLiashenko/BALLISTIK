class_name Effects
extends RefCounted
## Процедурные визуальные эффекты:
##  * взрывы — огненный шар, вспышка света, искры/пламя/дым (GPUParticles3D), обломки, ударная волна, воронки;
##  * водяные всплески и пенные кольца;
##  * дымовые шлейфы ракет (GPUParticles3D в мировых координатах);
##  * пожары и дым повреждённой техники, кильватерный след катеров, вспышки выстрелов.
## Текстуры частиц генерируются в коде (радиальный GradientTexture2D).

static var _res: Dictionary = {}
static var _lights: int = 0
static var _puffs: int = 0
static var _scorches: int = 0


static func _parent() -> Node:
	return GlobalBattleManager.get_fx_parent()


static func _auto_free(node: Node, seconds: float) -> void:
	if node == null or not node.is_inside_tree():
		return
	node.get_tree().create_timer(seconds, false).timeout.connect(node.queue_free)


static func _pscale() -> float:
	return GameSettings.particle_scale()


# --- Общие ресурсы частиц --------------------------------------------------------------------------------
static func soft_texture() -> Texture2D:
	if _res.has("soft_tex"):
		return _res["soft_tex"]
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	g.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	g.add_point(0.4, Color(1.0, 1.0, 1.0, 0.6))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	_res["soft_tex"] = t
	return t


static func particle_quad(additive: bool) -> QuadMesh:
	var key := "quad_add" if additive else "quad_mix"
	if _res.has(key):
		return _res[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.particles_anim_h_frames = 1
	m.particles_anim_v_frames = 1
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = ProcTextures.smoke_puff()
	m.disable_receive_shadows = true
	if not additive:
		m.proximity_fade_enabled = true
		m.proximity_fade_distance = 3.0
	var q := QuadMesh.new()
	q.size = Vector2(1.0, 1.0)
	q.material = m
	_res[key] = q
	return q


static func _debris_mesh() -> BoxMesh:
	if _res.has("debris_mesh"):
		return _res["debris_mesh"]
	var b := BoxMesh.new()
	b.size = Vector3(0.7, 0.35, 0.5)
	b.material = MeshFactory.mat(Color(0.12, 0.11, 0.1), 0.9)
	_res["debris_mesh"] = b
	return b


static func _gradient(colors: Array, offsets: Array) -> GradientTexture1D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offsets)
	g.colors = PackedColorArray(colors)
	var t := GradientTexture1D.new()
	t.gradient = g
	return t


static func _curve(points: Array) -> CurveTexture:
	var c := Curve.new()
	for p: Vector2 in points:
		c.add_point(p)
	var t := CurveTexture.new()
	t.curve = c
	return t


static func _process_mat(key: String, cfg: Dictionary) -> ParticleProcessMaterial:
	if _res.has(key):
		return _res[key]
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = float(cfg.get("emit_radius", 0.5))
	if cfg.has("emit_box"):
		m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		m.emission_box_extents = cfg["emit_box"]
	m.direction = cfg.get("direction", Vector3.UP)
	m.spread = float(cfg.get("spread", 180.0))
	m.initial_velocity_min = float(cfg.get("vel_min", 1.0))
	m.initial_velocity_max = float(cfg.get("vel_max", 3.0))
	m.gravity = cfg.get("gravity", Vector3.ZERO)
	m.damping_min = float(cfg.get("damping", 0.0))
	m.damping_max = float(cfg.get("damping", 0.0))
	m.scale_min = float(cfg.get("scale_min", 1.0))
	m.scale_max = float(cfg.get("scale_max", 2.0))
	if cfg.has("scale_curve"):
		m.scale_curve = _curve(cfg["scale_curve"])
	if cfg.has("colors"):
		m.color_ramp = _gradient(cfg["colors"], cfg["offsets"])
	m.angle_min = 0.0
	m.angle_max = 360.0
	_res[key] = m
	return m


static func _particles(process: ParticleProcessMaterial, amount: int, lifetime: float, one_shot: bool, additive: bool, explosiveness: float = 0.0, draw_mesh: Mesh = null) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.process_material = process
	p.amount = maxi(int(float(amount) * _pscale()), 2)
	p.lifetime = lifetime
	p.one_shot = one_shot
	p.explosiveness = explosiveness
	p.randomness = 0.3
	p.draw_pass_1 = draw_mesh if draw_mesh != null else particle_quad(additive)
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-150.0, -150.0, -150.0), Vector3(300.0, 300.0, 300.0))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.emitting = true
	return p


# --- Материалы процессов частиц ---------------------------------------------------------------------------
static func _fire_burst(sf: float, key: String) -> ParticleProcessMaterial:
	return _process_mat("fire_" + key, {
		"emit_radius": 1.4 * sf, "spread": 180.0, "vel_min": 5.0 * sf, "vel_max": 15.0 * sf,
		"gravity": Vector3(0.0, 3.0, 0.0), "damping": 9.0 * sf, "scale_min": 3.0 * sf, "scale_max": 6.5 * sf,
		"scale_curve": [Vector2(0.0, 0.55), Vector2(0.25, 1.0), Vector2(1.0, 0.25)],
		"colors": [Color(1.0, 0.95, 0.75, 1.0), Color(1.0, 0.55, 0.15, 1.0), Color(0.45, 0.14, 0.05, 0.7), Color(0.1, 0.08, 0.07, 0.0)],
		"offsets": [0.0, 0.25, 0.6, 1.0],
	})


static func _smoke_burst(sf: float, key: String) -> ParticleProcessMaterial:
	return _process_mat("smoke_" + key, {
		"emit_radius": 2.0 * sf, "spread": 180.0, "vel_min": 1.5 * sf, "vel_max": 6.0 * sf,
		"gravity": Vector3(0.0, 2.5, 0.0), "damping": 1.2, "scale_min": 5.0 * sf, "scale_max": 10.0 * sf,
		"scale_curve": [Vector2(0.0, 0.35), Vector2(1.0, 1.0)],
		"colors": [Color(0.15, 0.13, 0.12, 0.0), Color(0.16, 0.15, 0.14, 0.8), Color(0.32, 0.31, 0.31, 0.5), Color(0.5, 0.5, 0.5, 0.0)],
		"offsets": [0.0, 0.08, 0.55, 1.0],
	})


## Медленно поднимающийся столб дыма после мощного взрыва.
static func _smoke_column(sf: float, key: String) -> ParticleProcessMaterial:
	return _process_mat("column_" + key, {
		"emit_radius": 3.0 * sf, "direction": Vector3.UP, "spread": 14.0, "vel_min": 4.0 * sf, "vel_max": 9.0 * sf,
		"gravity": Vector3(1.5, 1.2, 0.6), "damping": 0.4, "scale_min": 6.0 * sf, "scale_max": 11.0 * sf,
		"scale_curve": [Vector2(0.0, 0.4), Vector2(1.0, 1.6)],
		"colors": [Color(0.1, 0.09, 0.08, 0.0), Color(0.12, 0.11, 0.1, 0.75), Color(0.3, 0.29, 0.28, 0.45), Color(0.45, 0.45, 0.45, 0.0)],
		"offsets": [0.0, 0.1, 0.55, 1.0],
	})


static func _sparks(sf: float, key: String) -> ParticleProcessMaterial:
	return _process_mat("sparks_" + key, {
		"emit_radius": 0.8 * sf, "spread": 180.0, "vel_min": 18.0 * sf, "vel_max": 42.0 * sf,
		"gravity": Vector3(0.0, -9.8, 0.0), "damping": 2.0, "scale_min": 0.35 * sf, "scale_max": 0.8 * sf,
		"colors": [Color(1.0, 0.9, 0.55, 1.0), Color(1.0, 0.45, 0.1, 0.9), Color(0.6, 0.15, 0.05, 0.0)],
		"offsets": [0.0, 0.5, 1.0],
	})


static func _debris(sf: float, key: String) -> ParticleProcessMaterial:
	return _process_mat("debris_" + key, {
		"emit_radius": 1.0 * sf, "direction": Vector3.UP, "spread": 55.0, "vel_min": 12.0 * sf, "vel_max": 26.0 * sf,
		"gravity": Vector3(0.0, -19.6, 0.0), "scale_min": 0.6 * sf, "scale_max": 1.6 * sf,
	})


static func _splash_column(sf: float, key: String) -> ParticleProcessMaterial:
	return _process_mat("splash_" + key, {
		"emit_radius": 1.5 * sf, "direction": Vector3.UP, "spread": 16.0, "vel_min": 14.0 * sf, "vel_max": 34.0 * sf,
		"gravity": Vector3(0.0, -16.0, 0.0), "damping": 0.5, "scale_min": 2.0 * sf, "scale_max": 4.5 * sf,
		"scale_curve": [Vector2(0.0, 0.5), Vector2(1.0, 1.0)],
		"colors": [Color(0.95, 0.98, 1.0, 0.9), Color(0.75, 0.88, 0.95, 0.6), Color(0.7, 0.85, 0.9, 0.0)],
		"offsets": [0.0, 0.5, 1.0],
	})


static func _trail(kind: String) -> ParticleProcessMaterial:
	var big := kind == "large"
	return _process_mat("trail_" + kind, {
		"emit_radius": 0.3, "spread": 180.0, "vel_min": 0.3, "vel_max": 1.6,
		"gravity": Vector3(0.0, 0.7, 0.0), "damping": 0.4,
		"scale_min": 2.2 if big else 1.2, "scale_max": 3.6 if big else 2.0,
		"scale_curve": [Vector2(0.0, 0.3), Vector2(0.12, 0.7), Vector2(1.0, 1.0)],
		"colors": [Color(1.0, 0.8, 0.45, 0.95), Color(0.9, 0.88, 0.85, 0.75), Color(0.72, 0.72, 0.74, 0.35), Color(0.62, 0.62, 0.65, 0.0)],
		"offsets": [0.0, 0.06, 0.5, 1.0],
	})


static func _fire_loop() -> ParticleProcessMaterial:
	return _process_mat("fire_loop", {
		"emit_radius": 1.0, "direction": Vector3.UP, "spread": 18.0, "vel_min": 2.0, "vel_max": 5.0,
		"gravity": Vector3(0.0, 4.0, 0.0), "scale_min": 1.6, "scale_max": 3.2,
		"scale_curve": [Vector2(0.0, 0.8), Vector2(1.0, 0.2)],
		"colors": [Color(1.0, 0.85, 0.5, 1.0), Color(1.0, 0.45, 0.1, 0.9), Color(0.3, 0.1, 0.05, 0.0)],
		"offsets": [0.0, 0.45, 1.0],
	})


static func _smoke_loop() -> ParticleProcessMaterial:
	return _process_mat("smoke_loop", {
		"emit_radius": 0.8, "direction": Vector3.UP, "spread": 12.0, "vel_min": 3.0, "vel_max": 6.0,
		"gravity": Vector3(1.2, 1.2, 0.4), "scale_min": 3.0, "scale_max": 6.0,
		"scale_curve": [Vector2(0.0, 0.3), Vector2(1.0, 1.0)],
		"colors": [Color(0.12, 0.11, 0.1, 0.0), Color(0.12, 0.11, 0.1, 0.7), Color(0.3, 0.3, 0.3, 0.35), Color(0.4, 0.4, 0.4, 0.0)],
		"offsets": [0.0, 0.1, 0.6, 1.0],
	})


static func _wake() -> ParticleProcessMaterial:
	return _process_mat("wake", {
		"emit_box": Vector3(1.2, 0.05, 0.6), "direction": Vector3.UP, "spread": 70.0, "vel_min": 0.8, "vel_max": 2.5,
		"gravity": Vector3.ZERO, "damping": 0.6, "scale_min": 0.9, "scale_max": 2.0,
		"scale_curve": [Vector2(0.0, 0.4), Vector2(1.0, 1.0)],
		"colors": [Color(1.0, 1.0, 1.0, 0.38), Color(0.85, 0.93, 0.97, 0.2), Color(0.8, 0.9, 0.95, 0.0)],
		"offsets": [0.0, 0.4, 1.0],
	})


# --- Взрывы и попадания ------------------------------------------------------------------------------------
## Взрыв радиуса radius. over_water — водяной столб вместо обломков.
static func explosion(pos: Vector3, radius: float, over_water: bool = false, sound: bool = true) -> void:
	var parent := _parent()
	if parent == null:
		return
	var root := Node3D.new()
	root.name = "Explosion"
	parent.add_child(root)
	root.global_position = pos
	var bucket := 0 if radius < 8.0 else (1 if radius < 24.0 else 2)
	var sf: float = [0.5, 1.0, 2.0][bucket]
	var key := str(bucket)
	# Вспышка ядра: яркая сфера на доли секунды
	var ball := MeshInstance3D.new()
	ball.mesh = MeshFactory.sphere(1.0, -1.0, 16, 8)
	var ball_mat := MeshFactory.fade_material(Color(1.0, 0.85, 0.55, 1.0), true)
	ball.material_override = ball_mat
	ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ball)
	ball.scale = Vector3.ONE * radius * 0.25
	var tw := ball.create_tween()
	tw.tween_property(ball, "scale", Vector3.ONE * radius * 0.55, 0.12).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(ball_mat, "albedo_color:a", 0.0, 0.16)
	tw.tween_callback(ball.queue_free)
	# Вспышка света
	if GameSettings.quality >= 1 and _lights < 6:
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.65, 0.3)
		light.omni_range = radius * 5.0 + 12.0
		light.light_energy = 6.0
		root.add_child(light)
		_lights += 1
		var lt := light.create_tween()
		lt.tween_property(light, "light_energy", 0.0, 0.45)
		lt.tween_callback(func() -> void:
			Effects._lights -= 1
			light.queue_free()
		)
	# Частицы: огненный шар из клубов, дым, искры
	root.add_child(_particles(_fire_burst(sf, key), 34, 1.0, true, true, 0.95))
	root.add_child(_particles(_smoke_burst(sf, key), 26, 4.5, true, false, 0.8))
	root.add_child(_particles(_sparks(sf, key), 30, 1.3, true, true, 1.0))
	if radius >= 14.0 and not over_water:
		var column := _particles(_smoke_column(sf, key), 30, 9.0, true, false, 0.35)
		column.visibility_aabb = AABB(Vector3(-200.0, -50.0, -200.0), Vector3(400.0, 400.0, 400.0))
		root.add_child(column)
	if over_water:
		root.add_child(_particles(_splash_column(sf, key), 34, 2.4, true, false, 0.9))
		_ring(root, radius * 0.4, radius * 2.2, Color(0.9, 0.97, 1.0, 0.7), 1.4, false)
	else:
		root.add_child(_particles(_debris(sf, key), 12, 2.6, true, false, 1.0, _debris_mesh()))
		if radius >= 9.0:
			_scorch(pos, radius)
	if radius >= 18.0:
		_ring(root, radius * 0.3, radius * 2.6, Color(1.0, 0.75, 0.45, 0.8), 0.6, true)
	_auto_free(root, 10.0 if radius >= 14.0 else 5.0)
	if sound:
		var snd := "explosion_big" if radius >= 20.0 else ("explosion" if radius >= 6.0 else "flak")
		SoundFX.play_3d(snd, pos, 4.0 if radius >= 20.0 else 0.0, 1.0, 45.0 + radius * 2.0)
		if over_water:
			SoundFX.play_3d("splash", pos, -2.0, 0.8, 40.0)
	GlobalBattleManager.report_explosion(pos, radius)


static func _ring(parent: Node3D, from_radius: float, to_radius: float, color: Color, duration: float, additive: bool) -> void:
	var ring := MeshInstance3D.new()
	ring.mesh = MeshFactory.torus(0.86, 1.0, 40, 6)
	var m := MeshFactory.fade_material(color, additive)
	ring.material_override = m
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(ring)
	ring.position = Vector3(0.0, 0.4, 0.0)
	ring.scale = Vector3(from_radius, from_radius * 0.3, from_radius)
	var tw := ring.create_tween()
	tw.tween_property(ring, "scale", Vector3(to_radius, to_radius * 0.15, to_radius), duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_property(m, "albedo_color:a", 0.0, duration)
	tw.tween_callback(ring.queue_free)


static func _scorch(pos: Vector3, radius: float) -> void:
	if _scorches >= 30:
		return
	var parent := _parent()
	var level := GlobalBattleManager.level
	if parent == null or level == null:
		return
	var ground := level.terrain.get_height(pos.x, pos.z)
	if ground < 0.2 or absf(pos.y - ground) > radius:
		return
	var decal := Decal.new()
	decal.name = "Scorch"
	decal.texture_albedo = ProcTextures.scorch()
	var d := radius * 1.3
	decal.size = Vector3(d, radius * 1.2 + 6.0, d)
	decal.albedo_mix = 0.9
	decal.normal_fade = 0.2
	decal.cull_mask = 1
	decal.rotation = Vector3(0.0, randf() * TAU, 0.0)
	parent.add_child(decal)
	decal.global_position = Vector3(pos.x, ground, pos.z)
	_scorches += 1
	var tw := decal.create_tween()
	tw.tween_interval(26.0)
	tw.tween_property(decal, "modulate:a", 0.0, 5.0)
	tw.tween_callback(func() -> void:
		Effects._scorches -= 1
		decal.queue_free()
	)


## Дешёвая «вспышка-облачко» (попадания пуль, всплески): одна сфера, которая расширяется и тает.
static func puff(pos: Vector3, color: Color, size: float, duration: float = 0.35, additive: bool = true) -> void:
	if _puffs >= 70:
		return
	var parent := _parent()
	if parent == null:
		return
	var mi := MeshInstance3D.new()
	mi.mesh = MeshFactory.sphere(1.0, -1.0, 10, 5)
	var m := MeshFactory.fade_material(color, additive)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = pos
	mi.scale = Vector3.ONE * size * 0.3
	_puffs += 1
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE * size, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_property(m, "albedo_color:a", 0.0, duration)
	tw.tween_callback(func() -> void:
		Effects._puffs -= 1
		mi.queue_free()
	)


static func bullet_impact(pos: Vector3, on_water: bool, on_vehicle: bool) -> void:
	if on_water:
		puff(pos + Vector3(0.0, 0.6, 0.0), Color(0.85, 0.95, 1.0, 0.8), 1.8, 0.45, false)
		_column(pos, 0.35, 3.5, Color(0.9, 0.97, 1.0, 0.7))
	elif on_vehicle:
		puff(pos, Color(1.0, 0.8, 0.4, 1.0), 1.3, 0.18)
	else:
		puff(pos, Color(0.45, 0.4, 0.33, 0.8), 2.2, 0.6, false)


static func _column(pos: Vector3, width: float, height: float, color: Color) -> void:
	if _puffs >= 70:
		return
	var parent := _parent()
	if parent == null:
		return
	var mi := MeshInstance3D.new()
	mi.mesh = MeshFactory.cylinder(0.6, 1.0, 1.0, 8)
	var m := MeshFactory.fade_material(color, false)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = pos
	mi.scale = Vector3(width, 0.2, width)
	_puffs += 1
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3(width, height, width), 0.25).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(mi, "position:y", pos.y + height * 0.5, 0.25)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.5)
	tw.tween_callback(func() -> void:
		Effects._puffs -= 1
		mi.queue_free()
	)


## Разрыв зенитного снаряда: чёрное облачко + короткая вспышка.
static func flak_burst(pos: Vector3) -> void:
	puff(pos, Color(1.0, 0.7, 0.3, 1.0), 3.0, 0.12)
	puff(pos, Color(0.08, 0.08, 0.08, 0.85), 5.5, 1.4, false)
	SoundFX.play_3d("flak", pos, -6.0, 1.2, 25.0)


## Всплеск от падения/торпеды средней мощности.
static func water_splash(pos: Vector3, size: float) -> void:
	var parent := _parent()
	if parent == null:
		return
	var root := Node3D.new()
	root.name = "Splash"
	parent.add_child(root)
	root.global_position = Vector3(pos.x, 0.2, pos.z)
	var sf := clampf(size / 10.0, 0.4, 2.5)
	var bucket := "s%d" % int(sf * 4.0)
	root.add_child(_particles(_splash_column(sf, bucket), 26, 2.0, true, false, 0.95))
	_ring(root, size * 0.3, size * 1.8, Color(0.92, 0.97, 1.0, 0.7), 1.2, false)
	_auto_free(root, 3.0)
	SoundFX.play_3d("splash", pos, -3.0, 1.0, 30.0)


# --- Долгоживущие эффекты ------------------------------------------------------------------------------------
static func create_trail(kind: String = "small") -> GPUParticles3D:
	var big := kind == "large"
	var p := _particles(_trail(kind), 170 if big else 100, 3.4 if big else 2.0, false, false)
	p.name = "SmokeTrail"
	p.visibility_aabb = AABB(Vector3(-800.0, -800.0, -800.0), Vector3(1600.0, 1600.0, 1600.0))
	return p


## Инверсионный след на большой высоте (vortex = false) или срывающийся с законцовок вихрь при перегрузке.
static func create_contrail(vortex: bool) -> GPUParticles3D:
	var key := "contrail_vortex" if vortex else "contrail"
	var mat := _process_mat(key, {
		"emit_radius": 0.08, "spread": 180.0, "vel_min": 0.0, "vel_max": 0.3,
		"gravity": Vector3.ZERO, "damping": 0.0,
		"scale_min": 0.35 if vortex else 1.2, "scale_max": 0.55 if vortex else 2.0,
		"scale_curve": [Vector2(0.0, 0.4), Vector2(1.0, 1.0 if vortex else 2.4)],
		"colors": [Color(1.0, 1.0, 1.0, 0.0), Color(1.0, 1.0, 1.0, 0.45 if vortex else 0.55), Color(1.0, 1.0, 1.0, 0.0)],
		"offsets": [0.0, 0.08, 1.0],
	})
	var p := _particles(mat, 50 if vortex else 160, 0.6 if vortex else 6.0, false, false)
	p.name = "Contrail"
	p.visibility_aabb = AABB(Vector3(-900.0, -900.0, -900.0), Vector3(1800.0, 1800.0, 1800.0))
	return p


## Отцепляет шлейф от уничтоженной ракеты — дым плавно рассеивается на месте.
static func detach_trail(trail: GPUParticles3D) -> void:
	if trail == null or not is_instance_valid(trail) or not trail.is_inside_tree():
		return
	var parent := _parent()
	if parent == null:
		return
	trail.reparent(parent, true)
	trail.emitting = false
	_auto_free(trail, trail.lifetime + 0.5)


static func create_fire() -> Node3D:
	var root := Node3D.new()
	root.name = "Fire"
	root.add_child(_particles(_fire_loop(), 22, 1.0, false, true))
	root.add_child(_particles(_smoke_loop(), 18, 4.0, false, false))
	return root


static func create_smoke() -> GPUParticles3D:
	var p := _particles(_smoke_loop(), 14, 4.0, false, false)
	p.name = "DamageSmoke"
	return p


static func create_wake() -> GPUParticles3D:
	var p := _particles(_wake(), 90, 2.2, false, false)
	p.name = "Wake"
	return p


## Дульная вспышка: светящийся конус, который оружие включает на пару кадров.
static func create_muzzle_flash(size: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "MuzzleFlash"
	mi.mesh = MeshFactory.cylinder(size * 0.5, size * 0.12, size * 1.6, 8)
	mi.material_override = MeshFactory.glow(Color(1.0, 0.75, 0.35), 5.0)
	mi.transform = MeshFactory.along_forward(Vector3(0.0, 0.0, -size * 0.8))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	return mi


static func charred_material() -> StandardMaterial3D:
	return MeshFactory.mat(Color(0.06, 0.055, 0.05), 0.95)


## Перекрашивает модель в «обугленную» и убирает светящиеся элементы.
static func char_model(node: Node) -> void:
	for child in node.get_children():
		if child is GPUParticles3D or child is AudioStreamPlayer3D or child is Light3D:
			child.queue_free()
			continue
		if child is MeshInstance3D:
			var mi := child as MeshInstance3D
			mi.material_override = charred_material()
		char_model(child)


## Остов из реальной модели техники: модель перекрашивается, горит; на воде — тонет.
static func spawn_model_wreck(model: Node3D, sinking: bool, lifetime: float = 26.0, sink_depth: float = 25.0) -> void:
	var parent := _parent()
	if parent == null or model == null or not model.is_inside_tree():
		return
	var root := Node3D.new()
	root.name = "Wreck"
	parent.add_child(root)
	root.global_transform = model.global_transform
	model.reparent(root, true)
	char_model(model)
	var fire := create_fire()
	fire.position = Vector3(0.0, 2.0, 0.0)
	root.add_child(fire)
	if sinking:
		var tw := root.create_tween()
		var sink_time := 9.0 + sink_depth * 0.15
		tw.tween_property(root, "position:y", root.position.y - sink_depth, sink_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(root, "rotation:z", root.rotation.z + 0.5, sink_time)
		tw.tween_callback(root.queue_free)
	else:
		_auto_free(root, lifetime)


## Остов уничтоженной техники: обугленные обломки и пожар; катера и корабли тонут.
static func spawn_wreck(pos: Vector3, basis: Basis, size: Vector3, sinking: bool) -> void:
	var parent := _parent()
	if parent == null:
		return
	var root := Node3D.new()
	root.name = "Wreck"
	parent.add_child(root)
	root.global_transform = Transform3D(basis.orthonormalized(), pos)
	var charred := MeshFactory.mat(Color(0.07, 0.065, 0.06), 0.95)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var b := ModelBuilder.new()
	var pieces := 5 if size.length() < 20.0 else 9
	for i in pieces:
		var s := Vector3(size.x * rng.randf_range(0.2, 0.55), size.y * rng.randf_range(0.15, 0.4), size.z * rng.randf_range(0.15, 0.4))
		var p := Vector3(rng.randf_range(-0.4, 0.4) * size.x, s.y * 0.5, rng.randf_range(-0.45, 0.45) * size.z)
		b.add(MeshFactory.box(s), MeshFactory.xf(p, Vector3(rng.randf_range(-15.0, 15.0), rng.randf_range(0.0, 360.0), rng.randf_range(-15.0, 15.0))), charred)
	root.add_child(b.build_instance("WreckMesh"))
	var fire := create_fire()
	fire.position = Vector3(0.0, size.y * 0.4, 0.0)
	root.add_child(fire)
	if sinking:
		var tw := root.create_tween()
		tw.tween_property(root, "position:y", pos.y - size.y * 3.0 - 4.0, 7.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(root.queue_free)
	else:
		_auto_free(root, 28.0)
