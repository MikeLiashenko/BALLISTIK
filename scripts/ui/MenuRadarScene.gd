class_name MenuRadarScene
extends Node3D
## 3D-фон главного меню «Командный центр»: голографическая тактическая карта арены (уменьшенный
## процедурный рельеф с неоновыми изолиниями), 3D-сетка радара с вращающимся лучом развёртки,
## маркеры баз, мигающие отметки целей и облетающие голограммы самолётов. Всё — процедурно.

const GRID_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 color : source_color = vec4(0.1, 0.9, 1.0, 1.0);
uniform float sweep_speed = 1.1;
varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	vec2 p = local_pos.xz;
	float r = length(p);
	float fade = 1.0 - smoothstep(70.0, 110.0, r);
	vec2 gp = p / 10.0;
	vec2 g = abs(fract(gp - 0.5) - 0.5) / max(fwidth(gp), vec2(0.0001));
	float grid = (1.0 - min(min(g.x, g.y), 1.0)) * 0.25;
	float rr = abs(fract(r / 25.0 - 0.5) - 0.5) / max(fwidth(r / 25.0), 0.0001);
	float rings = (1.0 - min(rr, 1.0)) * 0.55;
	float ang = atan(p.x, -p.y);
	float sweep_ang = mod(TIME * sweep_speed, 6.2831853);
	float diff = mod(sweep_ang - ang + 12.5663706, 6.2831853);
	float sweep = exp(-diff * 2.5) * 0.55 * (1.0 - step(105.0, r));
	float a = clamp((grid + rings + sweep) * fade, 0.0, 1.0);
	ALBEDO = color.rgb * 1.6;
	ALPHA = a;
}
"""

const HOLO_TERRAIN_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 land_color : source_color = vec4(0.1, 0.9, 1.0, 1.0);
uniform vec4 sea_color : source_color = vec4(0.05, 0.3, 0.8, 1.0);
varying vec3 wp;

void vertex() {
	wp = VERTEX;
}

void fragment() {
	float h = wp.y;
	float c = abs(fract(h / 14.0 - 0.5) - 0.5) / max(fwidth(h / 14.0), 0.0001);
	float contour = 1.0 - min(c, 1.0);
	vec2 gp = wp.xz / 400.0;
	vec2 g = abs(fract(gp - 0.5) - 0.5) / max(fwidth(gp), vec2(0.0001));
	float grid = 1.0 - min(min(g.x, g.y), 1.0);
	float land = smoothstep(-0.5, 1.5, h);
	float coast = 1.0 - smoothstep(0.0, 3.0, abs(h));
	vec3 col = mix(sea_color.rgb, land_color.rgb, land);
	ALBEDO = col * 1.4 + vec3(1.0, 0.7, 0.2) * coast * 1.5;
	ALPHA = clamp(0.06 + contour * 0.7 * land + grid * 0.18 + coast * 0.8, 0.0, 1.0);
}
"""

var camera: Camera3D = null
var _time: float = 0.0
var _blips: Array[Dictionary] = []
var _planes: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_rng.seed = 42
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.015, 0.03, 0.05)
	env.glow_enabled = true
	env.glow_intensity = 1.0
	env.glow_bloom = 0.15
	env.glow_hdr_threshold = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	camera = Camera3D.new()
	camera.fov = 55.0
	camera.far = 2000.0
	camera.h_offset = -58.0
	add_child(camera)
	camera.make_current()
	_build_grid()
	_build_hologram_map()
	_build_markers()
	_build_planes()


func _build_grid() -> void:
	var shader := Shader.new()
	shader.code = GRID_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = shader
	var plane := PlaneMesh.new()
	plane.size = Vector2(230.0, 230.0)
	plane.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.position = Vector3(0.0, -2.0, 0.0)
	add_child(mi)


func _build_hologram_map() -> void:
	var terrain := Terrain.new(7, 96)
	var shader := Shader.new()
	shader.code = HOLO_TERRAIN_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = shader
	var mi := MeshInstance3D.new()
	mi.mesh = terrain.build_mesh(mat)
	mi.scale = Vector3(0.022, 0.05, 0.022)
	add_child(mi)


func _build_markers() -> void:
	for team in 2:
		var s := GameDB.team_side(team)
		var col := GameDB.team_color(team)
		for p: Vector2 in [Vector2(2250.0 * s, -1500.0), Vector2(2650.0 * s, -700.0), Vector2(2300.0 * s, 0.0)]:
			var pillar := MeshInstance3D.new()
			pillar.mesh = MeshFactory.cylinder(0.35, 0.35, 14.0, 8)
			pillar.material_override = MeshFactory.glow(col, 3.0)
			pillar.position = Vector3(p.x * 0.022, 7.0, p.y * 0.022)
			add_child(pillar)
			var ring := MeshInstance3D.new()
			ring.mesh = MeshFactory.torus(2.2, 2.6, 24, 4)
			ring.material_override = MeshFactory.glow(col, 2.0)
			ring.position = Vector3(p.x * 0.022, 0.3, p.y * 0.022)
			add_child(ring)
	for i in 14:
		var blip := MeshInstance3D.new()
		blip.mesh = MeshFactory.sphere(0.9, -1.0, 10, 5)
		var team := i % 2
		blip.material_override = MeshFactory.glow(GameDB.team_color(team), 4.0)
		var pos := Vector3(_rng.randf_range(-70.0, 70.0), _rng.randf_range(2.0, 14.0), _rng.randf_range(-60.0, 60.0))
		blip.position = pos
		add_child(blip)
		_blips.append({"node": blip, "pos": pos, "vel": Vector3(_rng.randf_range(-3.0, 3.0), 0.0, _rng.randf_range(-3.0, 3.0))})


func _build_planes() -> void:
	var holo := MeshFactory.fade_material(Color(0.2, 0.95, 1.0, 0.55), true)
	for i in 3:
		var parts := VehicleModels.build_fighter(i % 2)
		var model: Node3D = parts["root"]
		_holo_override(model, holo)
		model.scale = Vector3.ONE * 0.45
		add_child(model)
		_planes.append({"node": model, "radius": 45.0 + float(i) * 18.0, "height": 22.0 + float(i) * 6.0, "speed": 0.25 + float(i) * 0.07, "phase": float(i) * 2.1})


func _holo_override(node: Node, mat: Material) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).material_override = mat
		_holo_override(child, mat)


func _process(delta: float) -> void:
	_time += delta
	var cam_angle := _time * 0.05
	camera.position = Vector3(sin(cam_angle) * 150.0, 78.0, cos(cam_angle) * 150.0)
	camera.look_at(Vector3(0.0, 0.0, 0.0), Vector3.UP)
	var sweep := fposmod(_time * 1.1, TAU)
	for b in _blips:
		var node: MeshInstance3D = b["node"]
		var pos: Vector3 = b["pos"]
		var vel: Vector3 = b["vel"]
		pos += vel * delta
		if absf(pos.x) > 80.0:
			vel.x = -vel.x
		if absf(pos.z) > 70.0:
			vel.z = -vel.z
		b["pos"] = pos
		b["vel"] = vel
		node.position = pos
		var ang := atan2(pos.x, -pos.z)
		var since := fposmod(sweep - ang, TAU)
		node.scale = Vector3.ONE * (0.4 + 1.2 * exp(-since * 2.0))
	for p in _planes:
		var node: Node3D = p["node"]
		var a := _time * float(p["speed"]) + float(p["phase"])
		var r := float(p["radius"])
		var pos := Vector3(cos(a) * r, float(p["height"]) + sin(a * 2.0) * 3.0, sin(a) * r)
		var tangent := Vector3(-sin(a), 0.0, cos(a))
		node.position = pos
		node.basis = GameDB.basis_from_forward(tangent).rotated(tangent.normalized(), 0.35).scaled(Vector3.ONE * 0.45)
