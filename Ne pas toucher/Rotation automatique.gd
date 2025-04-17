extends Node3D

enum RotationAxis {
	X_AXIS,
	Y_AXIS,
	Z_AXIS
}
@export_enum("X Axis", "Y Axis", "Z Axis") var Axe_De_Rotation := 1
@export var Temps_De_Rotation:float = 2.0

func _ready():
	if get_parent() is objet_base:
		rotation_objet()

func rotation_objet():
	var tween := create_tween()
	tween.set_loops(1)
	tween.connect("finished", Callable(self, "_on_tween_completed"))
	match Axe_De_Rotation:
		RotationAxis.X_AXIS:
			tween.tween_property(get_parent(), "rotation", get_parent().rotation + Vector3(PI * 2, 0, 0), Temps_De_Rotation).set_trans(Tween.TRANS_LINEAR)
		RotationAxis.Y_AXIS:
			tween.tween_property(get_parent(), "rotation", get_parent().rotation + Vector3(0, PI * 2, 0), Temps_De_Rotation).set_trans(Tween.TRANS_LINEAR)
		RotationAxis.Z_AXIS:
			tween.tween_property(get_parent(), "rotation", get_parent().rotation + Vector3(0, 0, PI * 2), Temps_De_Rotation).set_trans(Tween.TRANS_LINEAR)

func _on_tween_completed():
	rotation_objet()
