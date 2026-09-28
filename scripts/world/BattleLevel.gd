class_name BattleLevel
extends Node3D
## Боевая арена BALLISTIK — процедурная генерация выбранной карты при каждом запуске боя:
##  * рельеф (Terrain + TerrainMeshBuilder: чанки с LOD) — в фоновом потоке, с экраном загрузки;
##  * атмосфера (небо, солнце, туман, тонмаппинг), море до горизонта, кучевые облака и их тени;
##  * леса и рощи (MultiMesh), базы обеих команд, деревни, посёлки, маяки, нефтяные платформы;
##  * флагманы команд (крейсера под встроенным ИИ), точки спавна, камера, управление игрока и HUD.
## После генерации уровень передаётся в GlobalBattleManager.

const TIPS := [
	"Тактическая карта (G): баллистические, крылатые ракеты и залпы РС бьют по метке на карте.",
	"Ловушки (X) сбивают с курса ракеты с тепловой головкой самонаведения — но не радиокомандные ЗУР.",
	"ЗРК захватывает цель, пока она удерживается в прицеле, — затем пуск.",
	"Флагманы — главные цели: торпеды, крылатые ракеты и бомбы наносят им повышенный урон.",
	"Корабли медленно разгоняются и поворачивают: главный калибр бьёт по навесной траектории.",
	"Поршневые истребители маневреннее реактивных на малой скорости — затягивайте их в вираж.",
	"Облака скрывают самолёт от глаз, но не от радара.",
]

var layout: MapLayout = null
var terrain: Terrain = null
var units_root: Node3D = null
var projectiles_root: Node3D = null
var fx_root: Node3D = null
var structures_root: Node3D = null
var player_controller: PlayerController = null
var camera_rig: CameraRig = null
var hud: HUD = null
var world_env: WorldEnvironment = null
var sun: DirectionalLight3D = null
var sun_dir: Vector3 = Vector3.UP
var clouds: CloudField = null
var spawn_points: Dictionary = {}
var warships: Array[Warship] = []
var ready_for_battle: bool = false
var rng := RandomNumberGenerator.new()

const STAGES := ["Рельеф и береговая линия", "Детализация рельефа", "Растительность", "Облачность", "Сборка мира", "Леса и базы", "Развёртывание сил"]

var _quality: int = 2
var _progress: float = 0.0
var _stage: int = 0
var _loading: CanvasLayer = null
var _loading_bar: ProgressBar = null
var _loading_stage: Label = null
var _base_fog: float = 0.0001


func _ready() -> void:
	rng.seed = GlobalBattleManager.map_seed
	GlobalBattleManager.level = self
	_quality = GameSettings.quality
	GameSettings.apply_viewport_quality(get_viewport())
	_create_roots()
	layout = MapLayout.new(GlobalBattleManager.map_id)
	_build_loading_overlay()
	_generate.call_deferred()


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _create_roots() -> void:
	structures_root = Node3D.new()
	structures_root.name = "Structures"
	add_child(structures_root)
	units_root = Node3D.new()
	units_root.name = "Units"
	add_child(units_root)
	projectiles_root = Node3D.new()
	projectiles_root.name = "Projectiles"
	add_child(projectiles_root)
	fx_root = Node3D.new()
	fx_root.name = "Effects"
	fx_root.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(fx_root)


# --- Генерация -------------------------------------------------------------------------------------------
func _generate() -> void:
	var t0 := Time.get_ticks_msec()
	var res: int = GameSettings.terrain_resolution()
	terrain = Terrain.new(layout, GlobalBattleManager.map_seed, res)
	var atmo := Atmosphere.create(self, layout.preset, _quality)
	world_env = atmo["world_env"]
	sun = atmo["sun"]
	sun_dir = atmo["sun_dir"]
	_base_fog = (atmo["env"] as Environment).fog_density
	_set_stage(0, 0.05)
	var thread := Thread.new()
	thread.start(_background_generation)
	while thread.is_alive():
		_update_loading()
		await get_tree().process_frame
	var data: Dictionary = thread.wait_to_finish()
	_set_stage(4, 0.8)
	await get_tree().process_frame
	clouds = CloudField.new()
	add_child(clouds)
	clouds.build(data["clouds"], layout, sun_dir, atmo["sun_color"], _quality)
	var renderer := TerrainRenderer.new()
	renderer.name = "Terrain"
	add_child(renderer)
	renderer.setup_material(layout, clouds.shadow_texture, clouds.shadow_params, sun_dir, _quality)
	renderer.commit(data["builder"], data["meshes"], 2 if _quality >= 2 else 0)
	var water := WaterSurface.new()
	add_child(water)
	water.setup(terrain, clouds.shadow_texture, clouds.shadow_params, sun_dir)
	_set_stage(5, 0.88)
	await get_tree().process_frame
	var veg := Vegetation.new()
	add_child(veg)
	veg.build(data["vegetation"], layout)
	_build_bases()
	_build_neutral()
	_set_stage(6, 0.96)
	await get_tree().process_frame
	_build_spawn_points()
	_spawn_warships()
	_create_player_systems()
	ready_for_battle = true
	print("[LEVEL] %s (%s): %d ms, сетка %d, чанков %d" % [layout.map_id, MapPresets.map_name(layout.map_id), Time.get_ticks_msec() - t0, res, (data["meshes"] as Array).size()])
	_hide_loading()
	GlobalBattleManager.on_level_ready(self)


## Тяжёлая часть генерации (фоновый поток, без доступа к сцене).
func _background_generation() -> Dictionary:
	terrain.generate()
	_set_stage(1, 0.45)
	var chunks: int = [8, 12, 16, 16][clampi(_quality, 0, 3)]
	var lods := 3 if _quality == 0 else 4
	var builder := TerrainMeshBuilder.new(terrain, chunks, lods)
	var meshes := builder.build_all()
	_set_stage(2, 0.65)
	var veg := Vegetation.plan(terrain, _quality, GlobalBattleManager.map_seed)
	_set_stage(3, 0.75)
	var cloud_plan := CloudField.plan(layout, _quality, GlobalBattleManager.map_seed + 3)
	return {"builder": builder, "meshes": meshes, "vegetation": veg, "clouds": cloud_plan}


## Этап генерации (вызывается и из фонового потока — только простые числа, без строк).
func _set_stage(stage: int, progress: float) -> void:
	_stage = stage
	_progress = progress


# --- Экран загрузки ---------------------------------------------------------------------------------------
func _build_loading_overlay() -> void:
	_loading = CanvasLayer.new()
	_loading.layer = 50
	add_child(_loading)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = UITheme.get_theme()
	_loading.add_child(root)
	var bg := ColorRect.new()
	bg.color = Color(0.012, 0.022, 0.035, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var preview := TextureRect.new()
	preview.texture = MapPreview.thumbnail(layout.map_id, 256)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	preview.modulate = Color(1.0, 1.0, 1.0, 0.22)
	preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(preview)
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.01, 0.02, 0.55)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	box.position = Vector2(64.0, 0.0)
	box.anchor_top = 0.5
	box.anchor_bottom = 0.5
	box.offset_top = -150.0
	box.offset_left = 64.0
	box.custom_minimum_size = Vector2(620.0, 0.0)
	box.add_theme_constant_override("separation", 10)
	root.add_child(box)
	box.add_child(UITheme.make_label("ПОДГОТОВКА К БОЮ", 16, UITheme.ACCENT))
	var title := UITheme.make_label(MapPresets.map_name(layout.map_id).to_upper(), 46, UITheme.TEXT)
	UITheme.glow_label(title, UITheme.NEON, 2, 12)
	box.add_child(title)
	box.add_child(UITheme.make_label(str(layout.preset.get("subtitle", "")), 18, UITheme.NEON))
	var desc := UITheme.make_label(str(layout.preset.get("desc", "")), 16, UITheme.TEXT_DIM)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(600.0, 0.0)
	box.add_child(desc)
	var sep := UITheme.separator()
	box.add_child(sep)
	_loading_stage = UITheme.make_label("", 16, UITheme.TEXT)
	box.add_child(_loading_stage)
	_loading_bar = UITheme.progress_bar(UITheme.NEON, 8.0)
	box.add_child(_loading_bar)
	var tip := UITheme.make_label("СОВЕТ: " + str(TIPS[rng.randi() % TIPS.size()]), 15, UITheme.TEXT_DIM)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.custom_minimum_size = Vector2(600.0, 0.0)
	box.add_child(tip)
	_update_loading()


func _update_loading() -> void:
	if _loading_bar == null:
		return
	_loading_bar.value = lerpf(_loading_bar.value, _progress, 0.25)
	_loading_stage.text = "%s…" % STAGES[clampi(_stage, 0, STAGES.size() - 1)]


func _hide_loading() -> void:
	if _loading == null:
		return
	var overlay := _loading
	_loading = null
	var root := overlay.get_child(0) as Control
	var tw := root.create_tween()
	tw.tween_property(root, "modulate:a", 0.0, 0.6)
	tw.tween_callback(overlay.queue_free)


# --- Базы и сооружения ------------------------------------------------------------------------------------
func _add_building(kind: String, team: int, pos: Vector3, yaw: float, fixed_y: bool = false, variant: int = 0) -> Building:
	var b := Building.new().setup(kind, team, variant)
	b.name = "%s_%d" % [kind, structures_root.get_child_count()]
	var y := pos.y if fixed_y else terrain.get_height(pos.x, pos.z)
	b.position = Vector3(pos.x, y, pos.z)
	b.rotation = Vector3(0.0, yaw, 0.0)
	structures_root.add_child(b)
	return b


func _v3(p: Vector2) -> Vector3:
	return Vector3(p.x, 0.0, p.y)


func _build_bases() -> void:
	for team in 2:
		var af := layout.airfield[team]
		var u := layout.runway_dir[team]
		var v := Vector2(-u.y, u.x)
		if (layout.hq[team] - af).dot(v) < 0.0:
			v = -v
		var runway := StructureModels.build_runway(team, MapLayout.RUNWAY_LENGTH, MapLayout.RUNWAY_WIDTH)
		runway.position = Vector3(af.x, layout.airfield_height[team] + 0.12, af.y)
		runway.rotation = Vector3(0.0, atan2(-u.y, u.x), 0.0)
		structures_root.add_child(runway)
		var face_runway := GameDB.yaw_of(_v3(-v))
		_add_building("hangar", team, _v3(af + u * -170.0 + v * 128.0), face_runway)
		_add_building("hangar", team, _v3(af + u * 20.0 + v * 128.0), face_runway)
		_add_building("tower", team, _v3(af + u * 215.0 + v * 104.0), face_runway)
		for i in 3:
			_add_building("fuel", team, _v3(af + u * (340.0 + float(i) * 30.0) + v * (130.0 + float(i % 2) * 24.0)), 0.0)
		var enemy_yaw := GameDB.yaw_of(layout.enemy_dir(team))
		_add_building("hq", team, _v3(layout.hq[team]), enemy_yaw)
		_add_building("radar", team, _v3(layout.radar[team]), 0.0)
		var pd := layout.pier_dir[team]
		var sea_yaw := GameDB.yaw_of(_v3(pd))
		for b: Vector2 in layout.bunkers[team]:
			_add_building("bunker", team, _v3(b), sea_yaw)
		var root := layout.pier_root[team]
		var pier := StructureModels.build_pier(team, MapLayout.PIER_LENGTH, MapLayout.PIER_DECK_HEIGHT)
		pier.position = _v3(root)
		pier.rotation = Vector3(0.0, atan2(pd.x, pd.y), 0.0)
		structures_root.add_child(pier)
		var tip := layout.pier_tip(team) - pd * 8.0
		_add_building("lighthouse", team, Vector3(tip.x, MapLayout.PIER_DECK_HEIGHT, tip.y), 0.0, true)
		var lat := Vector2(-pd.y, pd.x)
		_add_building("warehouse", team, _v3(root - pd * 75.0 + lat * 62.0), sea_yaw + PI)
		_add_building("warehouse", team, _v3(root - pd * 75.0 - lat * 62.0), sea_yaw + PI)


func _build_neutral() -> void:
	for village in layout.villages:
		var houses := 11
		for i in houses:
			var ang := float(i) / float(houses) * TAU + rng.randf_range(-0.2, 0.2)
			var r := rng.randf_range(40.0, 150.0)
			var p := village + Vector2(cos(ang), sin(ang)) * r
			if terrain.get_height(p.x, p.y) < 2.0 or terrain.get_normal(p.x, p.y).y < 0.9:
				continue
			_add_building("house", GameDB.NEUTRAL, _v3(p), rng.randf() * TAU, false, i)
	for l in layout.lighthouses:
		if terrain.get_height(l.x, l.y) > 1.0:
			_add_building("lighthouse", GameDB.NEUTRAL, _v3(l), 0.0)
	for o in layout.oil_rigs:
		_add_building("oil_rig", GameDB.NEUTRAL, _v3(o), 0.35, true)
	_build_towns()


## Декоративные посёлки: скопления домов (MultiMesh, без физики) на пригодных участках.
func _build_towns() -> void:
	var per_variant: Array = [[], [], [], []]
	for town in layout.towns:
		var count: int = [14, 24, 36, 44][clampi(_quality, 0, 3)]
		for i in count:
			var ang := rng.randf() * TAU
			var r := sqrt(rng.randf()) * 360.0
			var p := town + Vector2(cos(ang), sin(ang)) * r
			var h := terrain.get_height(p.x, p.y)
			if h < 2.5 or terrain.get_normal(p.x, p.y).y < 0.93 or layout.near_flat_zone(p, 40.0):
				continue
			var street := snappedf(ang, PI * 0.5) + rng.randf_range(-0.1, 0.1)
			var s := rng.randf_range(0.85, 1.25)
			per_variant[i % 4].append(Transform3D(Basis(Vector3.UP, street).scaled(Vector3(s, rng.randf_range(0.9, 1.3), s)), Vector3(p.x, h - 0.2, p.y)))
	for variant in 4:
		var list: Array = per_variant[variant]
		if list.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = StructureModels.house_mesh(variant)
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, list[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Town_%d" % variant
		mmi.multimesh = mm
		mmi.visibility_range_end = 9000.0
		structures_root.add_child(mmi)


# --- Спавн -----------------------------------------------------------------------------------------------
func _build_spawn_points() -> void:
	for team in 2:
		for cat: int in GameDB.CATEGORY_ORDER:
			spawn_points["%d:%d" % [team, cat]] = layout.spawn_transforms(terrain, team, cat)
		spawn_points["%d:ship" % team] = layout.ship_spawn_transforms(team)


## Свободная точка спавна своей базы для категории техники (аэродром / берег / причал; крупные
## корабли — на рейде дальше от причала).
func pick_spawn_transform(team: int, category: int, large_ship: bool = false) -> Transform3D:
	var key := "%d:ship" % team if large_ship else "%d:%d" % [team, category]
	var list: Array = spawn_points.get(key, [])
	if list.is_empty():
		return Transform3D(Basis(), Vector3(0.0, 600.0, 0.0))
	var order := range(list.size())
	order.shuffle()
	for i: int in order:
		var xf: Transform3D = list[i]
		var free := true
		for v in GlobalBattleManager.units:
			if is_instance_valid(v) and not v.is_dead and v.global_position.distance_to(xf.origin) < 32.0:
				free = false
				break
		if free:
			return xf
	var fallback: Transform3D = list[rng.randi() % list.size()]
	fallback.origin += Vector3(rng.randf_range(-18.0, 18.0), 0.0, rng.randf_range(-18.0, 18.0))
	return fallback


func _spawn_warships() -> void:
	for team in 2:
		var w := Warship.new()
		w.vehicle_type = GameDB.flagship_for(team, GlobalBattleManager.air_era)
		w.autonomous = true
		w.team = team
		w.pilot_name = "Флагман"
		var anchor := layout.warship_anchor(team)
		w.anchor = anchor
		w.patrol_radius = MapLayout.WARSHIP_PATROL_RADIUS
		var start := anchor + Vector3(w.patrol_radius, 0.0, 0.0)
		w.transform = Transform3D(Basis(Vector3.UP, 0.0), start)
		add_unit(w)
		warships.append(w)


func add_unit(v: Vehicle) -> void:
	units_root.add_child(v)


## Тактический вид: убрать облака и туман, чтобы карта читалась сверху.
func set_tactical_view(active: bool) -> void:
	if clouds != null:
		clouds.visible = not active
	if world_env != null and world_env.environment != null:
		world_env.environment.fog_density = _base_fog * 0.2 if active else _base_fog


func spawn_projectile(p: Node3D) -> void:
	projectiles_root.add_child(p)
	if GlobalBattleManager.smoke_test:
		GlobalBattleManager.smoke_count("spawned_" + p.get_script().get_global_name())


# --- Игрок -------------------------------------------------------------------------------------------------
func _create_player_systems() -> void:
	camera_rig = CameraRig.new()
	camera_rig.name = "CameraRig"
	add_child(camera_rig)
	player_controller = PlayerController.new()
	player_controller.name = "PlayerController"
	add_child(player_controller)
	hud = HUD.new()
	hud.name = "HUD"
	add_child(hud)
	player_controller.setup(self, camera_rig, hud)
	hud.setup(self, player_controller, camera_rig)


func on_player_spawned(v: Vehicle, bot_driven: bool) -> void:
	player_controller.possess(v, bot_driven)
