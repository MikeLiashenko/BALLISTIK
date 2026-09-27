class_name Bomb
extends Projectile
## Свободнопадающая фугасная бомба (ФАБ-500): наследует скорость носителя, падает под действием
## гравитации с сопротивлением воздуха, при ударе — мощный взрыв с большим радиусом поражения.


func _init() -> void:
	show_tracer = false
	gravity_scale = 1.0
	drag = 0.00006
	damage = 0.0
	damage_type = "bomb"
	blast_radius = 30.0
	blast_damage = 290.0
	structure_multiplier = 1.5
	max_lifetime = 45.0


func _build_visual() -> void:
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = VehicleModels.missile_mesh("bomb")
	add_child(body)
