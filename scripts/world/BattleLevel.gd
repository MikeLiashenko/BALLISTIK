class_name BattleLevel
extends Node3D
## Боевая арена BALLISTIK — полностью процедурная генерация 3D-карты при каждом запуске боя:
##  * рельеф суши и морского дна с береговой линией и островами (Terrain), тактическая сетка-шейдер;
##  * вода (шейдер с бликами волн), небо, солнце, туман и свечение (glow);
##  * базы обеих команд: ВПП, ангары, КДП, топливо, штаб, РЛС, бункеры, причал, маяк, склады;
##  * нейтральная деревня, маяк на острове, нефтяная платформа; деревья и облака (MultiMesh);
##  * эсминцы команд, точки спавна (аэродром / берег / причал);
##  * камера, управление игрока и HUD. После генерации уровень передаётся в GlobalBattleManager.

const TERRAIN_SHADER := """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 grid_color : source_color = vec4(0.1, 0.9, 1.0, 1.0);
uniform float grid_size = 250.0;
uniform float grid_strength = 0.1;
varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 base = pow(COLOR.rgb, vec3(2.2));
	vec2 coord = world_pos.xz / grid_size;
	vec2 g = abs(fract(coord - 0.5) - 0.5) / max(fwidth(coord), vec2(0.0001));
	float line = 1.0 - min(min(g.x, g.y), 1.0);
	float fade = clamp(1.0 - length(world_pos - CAMERA_POSITION_WORLD) / 5000.0, 0.0, 1.0);
	ALBEDO = base;
	ROUGHNESS = 0.93;
	SPECULAR = 0.2;
	EMISSION = grid_color.rgb * line * grid_strength * fade;
}
"""

const WATER_SHADER := """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;

uniform vec4 deep_color : source_color = vec4(0.02, 0.1, 0.17, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.06, 0.3, 0.36, 1.0);
uniform vec4 grid_color : source_color = vec4(0.1, 0.9, 1.0, 1.0);
uniform float grid_size = 250.0;
uniform float grid_strength = 0.07;
varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

vec3 wave_normal(vec2 p, float t) {
	vec2 d1 = normalize(vec2(1.0, 0.3));
	vec2 d2 = normalize(vec2(-0.4, 1.0));
	vec2 d3 = normalize(vec2(0.7, -0.8));
	vec2 grad = d1 * 1.2 * 0.05 * cos(dot(d1, p) * 0.05 + t * 1.1)
		+ d2 * 0.8 * 0.083 * cos(dot(d2, p) * 0.083 + t * 1.5)
		+ d3 * 0.35 * 0.17 * cos(dot(d3, p) * 0.17 + t * 2.3);
	return normalize(vec3(-grad.x, 1.0, -grad.y));
}

void fragment() {
	vec3 n_world = wave_normal(world_pos.xz, TIME);
	NORMAL = normalize((VIEW_MATRIX * vec4(n_world, 0.0)).xyz);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	vec2 coord = world_pos.xz / grid_size;
	vec2 g = abs(fract(coord - 0.5) - 0.5) / max(fwidth(coord), vec2(0.0001));
	float line = 1.0 - min(min(g.x, g.y), 1.0);
	float fade = clamp(1.0 - length(world_pos - CAMERA_POSITION_WORLD) / 4500.0, 0.0, 1.0);
	ALBEDO = mix(deep_color.rgb, shallow_color.rgb, 0.3 + 0.5 * fres);
	ROUGHNESS = 0.07;
	METALLIC = 0.05;
	SPECULAR = 0.75;
	EMISSION = grid_color.rgb * line * grid_strength * fade;
}
"""

const WARSHIP_NAMES := ["«Буревестник»", "«Грозный»"]

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
var spawn_points: Dictionary = {}
var warships: Array[Warship] = []
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.seed = GlobalBattleManager.map_seed
	GlobalBattleManager.level = self
	GameSettings.apply_viewport_quality(get_viewport())
	_create_roots()
	_build_environment()
	terrain = Terrain.new(GlobalBattleManager.map_seed, GameSettings.terrain_resolution())
	_build_terrain_mesh()
	_build_water()
	_build_bases()
	_build_neutral()
	_build_vegetation()
	_build_clouds()
	_build_spawn_points()
	_spawn_warships()
	_create_player_systems()
	GlobalBattleManager.on_level_ready(self)


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


# --- Окружение ------------------------------------------------------------------------------------------
func _build_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.07, 0.13, 0.27)
	sky_mat.sky_horizon_color = Color(0.78, 0.56, 0.44)
	sky_mat.sky_curve = 0.12
	sky_mat.ground_bottom_color = Color(0.03, 0.05, 0.08)
	sky_mat.ground_horizon_color = Color(0.45, 0.37, 0.34)
	sky_mat.sun_angle_max = 25.0
	sky_mat.sun_curve = 0.08
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.75
	env.ambient_light_energy = 1.15
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 6.0
	env.glow_enabled = GameSettings.quality >= 1
	env.glow_intensity = 0.75
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.1
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.fog_enabled = true
	env.fog_light_color = Color(0.52, 0.52, 0.6)
	env.fog_density = 0.00022
	env.fog_sky_affect = 0.25
	env.fog_aerial_perspective = 0.3
	env.ssao_enabled = GameSettings.quality >= 2
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	env.adjustment_contrast = 1.05
	world_env = WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-26.0, -45.0, 0.0)
	sun.light_color = Color(1.0, 0.87, 0.74)
	sun.light_energy = 1.15
	sun.shadow_enabled = GameSettings.quality >= 1
	sun.directional_shadow_max_distance = 650.0
	add_child(sun)


func _build_terrain_mesh() -> void:
	var shader := Shader.new()
	shader.code = TERRAIN_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = shader
	var mi := MeshInstance3D.new()
	mi.name = "Terrain"
	mi.mesh = terrain.build_mesh(mat)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if GameSettings.quality >= 2 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _build_water() -> void:
	var shader := Shader.new()
	shader.code = WATER_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = shader
	var plane := PlaneMesh.new()
	plane.size = Vector2(24000.0, 24000.0)
	plane.material = mat
	var mi := MeshInstance3D.new()
	mi.name = "Water"
	mi.mesh = plane
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


# --- Базы и сооружения ------------------------------------------------------------------------------------
func _add_building(kind: String, team: int, pos: Vector3, yaw: float, fixed_y: bool = false, variant: int = 0) -> Building:
	var b := Building.new().setup(kind, team, variant)
	b.name = "%s_%d" % [kind, structures_root.get_child_count()]
	var y := pos.y if fixed_y else terrain.get_height(pos.x, pos.z)
	b.position = Vector3(pos.x, y, pos.z)
	b.rotation = Vector3(0.0, yaw, 0.0)
	structures_root.add_child(b)
	return b


func _build_bases() -> void:
	for team in 2:
		var s := MapLayout.side(team)
		var face_enemy := GameDB.yaw_of(Vector3(-s, 0.0, 0.0))
		var af := MapLayout.airfield_center(team)
		var runway := StructureModels.build_runway(team, MapLayout.RUNWAY_LENGTH, MapLayout.RUNWAY_WIDTH)
		runway.position = Vector3(af.x, MapLayout.AIRFIELD_HEIGHT + 0.12, af.z)
		structures_root.add_child(runway)
		_add_building("hangar", team, Vector3(af.x - s * 150.0, 0.0, af.z - 118.0), PI)
		_add_building("hangar", team, Vector3(af.x + s * 30.0, 0.0, af.z - 118.0), PI)
		_add_building("tower", team, Vector3(af.x + s * 210.0, 0.0, af.z - 96.0), PI)
		for i in 3:
			_add_building("fuel", team, Vector3(af.x + s * (330.0 + float(i) * 28.0), 0.0, af.z - 125.0 + float(i % 2) * 22.0), 0.0)
		var hq := MapLayout.hq_center(team)
		_add_building("hq", team, Vector3(hq.x, 0.0, hq.y), face_enemy)
		var rc := MapLayout.radar_center(team)
		_add_building("radar", team, Vector3(rc.x, 0.0, rc.y), 0.0)
		for bx: float in [1500.0, 2050.0]:
			var x := s * bx
			_add_building("bunker", team, Vector3(x, 0.0, terrain.coast_z(x) - 60.0), PI)
		var root := MapLayout.pier_root(terrain, team)
		var pier := StructureModels.build_pier(team, MapLayout.PIER_LENGTH, MapLayout.PIER_DECK_HEIGHT)
		pier.position = Vector3(root.x, 0.0, root.y)
		structures_root.add_child(pier)
		var tip := MapLayout.pier_tip(terrain, team)
		_add_building("lighthouse", team, Vector3(tip.x, MapLayout.PIER_DECK_HEIGHT, tip.y - 8.0), 0.0, true)
		_add_building("warehouse", team, Vector3(root.x - 62.0, 0.0, root.y - 72.0), PI)
		_add_building("warehouse", team, Vector3(root.x + 62.0, 0.0, root.y - 72.0), PI)


func _build_neutral() -> void:
	for i in 9:
		var ang := float(i) / 9.0 * TAU + rng.randf_range(-0.2, 0.2)
		var r := rng.randf_range(45.0, 140.0)
		var p := MapLayout.VILLAGE + Vector2(cos(ang), sin(ang)) * r
		_add_building("house", GameDB.NEUTRAL, Vector3(p.x, 0.0, p.y), rng.randf() * TAU, false, i)
	var ci := MapLayout.CENTRAL_ISLAND
	_add_building("lighthouse", GameDB.NEUTRAL, Vector3(ci.x, 0.0, ci.y), 0.0)
	_add_building("oil_rig", GameDB.NEUTRAL, Vector3(MapLayout.OIL_RIG.x, 0.0, MapLayout.OIL_RIG.y), 0.35, true)


# --- Растительность и облака (MultiMesh) --------------------------------------------------------------------
func _tree_mesh() -> Mesh:
	var trunk := MeshFactory.mat(Color(0.3, 0.22, 0.15), 0.9)
	var leaves := StandardMaterial3D.new()
	leaves.albedo_color = Color(0.17, 0.31, 0.14)
	leaves.roughness = 0.95
	leaves.vertex_color_use_as_albedo = true
	var b := ModelBuilder.new()
	b.add(MeshFactory.cylinder(0.25, 0.35, 3.0, 6), MeshFactory.xf(Vector3(0.0, 1.5, 0.0)), trunk)
	b.add(MeshFactory.cylinder(0.0, 2.6, 5.5, 7), MeshFactory.xf(Vector3(0.0, 4.8, 0.0)), leaves)
	b.add(MeshFactory.cylinder(0.0, 2.0, 4.2, 7), MeshFactory.xf(Vector3(0.0, 7.3, 0.0)), leaves)
	return b.build()


func _build_vegetation() -> void:
	var target_count: int = [260, 520, 850][GameSettings.quality]
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	var tries := 0
	while transforms.size() < target_count and tries < target_count * 14:
		tries += 1
		var x := rng.randf_range(-GameDB.MAP_HALF - 400.0, GameDB.MAP_HALF + 400.0)
		var z := rng.randf_range(-GameDB.MAP_HALF - 400.0, 300.0)
		var h := terrain.get_height(x, z)
		if h < 4.0 or h > 160.0:
			continue
		if terrain.get_normal(x, z).y < 0.82:
			continue
		if MapLayout.near_any_zone(terrain.flat_zones, Vector2(x, z), 45.0):
			continue
		var s := rng.randf_range(0.7, 1.6)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.85, 1.3), s))
		transforms.append(Transform3D(basis, Vector3(x, h - 0.3, z)))
		colors.append(Color(rng.randf_range(0.75, 1.1), rng.randf_range(0.85, 1.15), rng.randf_range(0.7, 1.0)))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _tree_mesh()
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
		mm.set_instance_color(i, colors[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Trees"
	mmi.multimesh = mm
	add_child(mmi)


func _build_clouds() -> void:
	var clouds: int = [16, 28, 40][GameSettings.quality]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.93, 0.92)
	mat.roughness = 1.0
	mat.emission_enabled = true
	mat.emission = Color(0.55, 0.45, 0.45)
	mat.emission_energy_multiplier = 0.35
	mat.disable_receive_shadows = true
	var transforms: Array[Transform3D] = []
	for c in clouds:
		var center := Vector3(rng.randf_range(-3800.0, 3800.0), rng.randf_range(950.0, 1550.0), rng.randf_range(-3800.0, 3800.0))
		var puffs := rng.randi_range(3, 6)
		for i in puffs:
			var offset := Vector3(rng.randf_range(-110.0, 110.0), rng.randf_range(-12.0, 18.0), rng.randf_range(-70.0, 70.0))
			var puff_scale := Vector3(rng.randf_range(60.0, 130.0), rng.randf_range(18.0, 36.0), rng.randf_range(45.0, 100.0))
			var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(puff_scale)
			transforms.append(Transform3D(basis, center + offset))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = MeshFactory.sphere(1.0, -1.0, 12, 6)
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Clouds"
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


# --- Спавн -----------------------------------------------------------------------------------------------
func _build_spawn_points() -> void:
	for team in 2:
		for cat: int in GameDB.CATEGORY_ORDER:
			spawn_points["%d:%d" % [team, cat]] = MapLayout.spawn_transforms(terrain, team, cat)


## Свободная точка спавна своей базы для категории техники (аэродром / берег / причал).
func pick_spawn_transform(team: int, category: int) -> Transform3D:
	var list: Array = spawn_points.get("%d:%d" % [team, category], [])
	if list.is_empty():
		return Transform3D(Basis(), Vector3(0.0, 400.0, 0.0))
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
		w.team = team
		w.pilot_name = "Эсминец %s" % WARSHIP_NAMES[team]
		var anchor := MapLayout.warship_anchor(terrain, team)
		w.anchor = anchor
		var start := anchor + Vector3(w.patrol_radius, 0.0, 0.0)
		w.transform = Transform3D(Basis(Vector3.UP, 0.0), start)
		add_unit(w)
		warships.append(w)


func add_unit(v: Vehicle) -> void:
	units_root.add_child(v)


## Тактический вид: убрать облака и туман, чтобы карта читалась сверху.
func set_tactical_view(active: bool) -> void:
	var clouds := get_node_or_null("Clouds") as Node3D
	if clouds != null:
		clouds.visible = not active
	if world_env != null and world_env.environment != null:
		world_env.environment.fog_density = 0.00003 if active else 0.00022


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
