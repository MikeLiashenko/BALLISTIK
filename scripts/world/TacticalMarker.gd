class_name TacticalMarker
extends Node3D
## Тактический маркер баллистического прицеливания: пульсирующее кольцо радиуса поражения на поверхности,
## вертикальный световой столб и подпись (дистанция, подлётное время). Используется в тактическом режиме
## игрока и как метка точки падения уже запущенных ракет.

const COLOR_OK := Color(1.0, 0.36, 0.2, 0.9)
const COLOR_BAD := Color(0.55, 0.58, 0.6, 0.7)

var radius: float = 38.0
var show_label: bool = true
var valid: bool = true

var _ring: MeshInstance3D = null
var _inner: MeshInstance3D = null
var _beam: MeshInstance3D = null
var _label: Label3D = null
var _ring_mat: StandardMaterial3D = null
var _beam_mat: StandardMaterial3D = null
var _time: float = 0.0


static func create_impact_marker(pos: Vector3, blast_radius: float) -> TacticalMarker:
	var parent := GlobalBattleManager.get_fx_parent()
	if parent == null:
		return null
	var m := TacticalMarker.new()
	m.radius = blast_radius
	m.show_label = false
	parent.add_child(m)
	m.place(pos)
	return m


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_ring_mat = MeshFactory.fade_material(COLOR_OK, true)
	_beam_mat = MeshFactory.fade_material(Color(COLOR_OK, 0.2), true)
	_ring = MeshInstance3D.new()
	_ring.mesh = MeshFactory.torus(0.9, 1.0, 48, 6)
	_ring.material_override = _ring_mat
	_ring.scale = Vector3(radius, radius * 0.5, radius)
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)
	_inner = MeshInstance3D.new()
	_inner.mesh = MeshFactory.torus(0.75, 1.0, 24, 4)
	_inner.material_override = _ring_mat
	_inner.scale = Vector3(4.0, 2.0, 4.0)
	_inner.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_inner)
	_beam = MeshInstance3D.new()
	_beam.mesh = MeshFactory.cylinder(1.0, 1.0, 1.0, 10)
	_beam.material_override = _beam_mat
	_beam.scale = Vector3(0.9, 160.0, 0.9)
	_beam.position = Vector3(0.0, 80.0, 0.0)
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_beam)
	if show_label:
		_label = Label3D.new()
		_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_label.fixed_size = true
		_label.pixel_size = 0.0009
		_label.font_size = 26
		_label.outline_size = 8
		_label.no_depth_test = true
		_label.modulate = Color(1.0, 0.85, 0.6)
		_label.position = Vector3(0.0, 60.0, 0.0)
		add_child(_label)


func place(pos: Vector3) -> void:
	global_position = Vector3(pos.x, pos.y + 0.6, pos.z)


func set_valid(is_valid: bool) -> void:
	valid = is_valid
	if _ring_mat != null:
		_ring_mat.albedo_color = COLOR_OK if is_valid else COLOR_BAD
		_beam_mat.albedo_color = Color(_ring_mat.albedo_color, 0.2)


func set_text(text: String) -> void:
	if _label != null:
		_label.text = text


func _process(delta: float) -> void:
	_time += delta
	var pulse := 1.0 + 0.06 * sin(_time * 6.0)
	if _ring != null:
		_ring.scale = Vector3(radius * pulse, radius * 0.5, radius * pulse)
	if _inner != null:
		_inner.rotate_y(delta * 2.0)
