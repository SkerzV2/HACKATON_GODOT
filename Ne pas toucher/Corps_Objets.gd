extends Area3D

func _Quand_Collision(body):
	if body.name == "Joueur":
		if get_parent() is objet_base:
			print("_Quand_Collision and is joueur")
			get_parent().joueur_touche()
