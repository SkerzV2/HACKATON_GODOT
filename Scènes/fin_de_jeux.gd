extends Node3D

# Distance de détection du joueur (en mètres)
@export var distance_detection: float = 1.0

func _process(_delta):
	
	# Récupérer le joueur (en supposant qu'il est stocké dans une variable globale g_vars.joueur)
	var joueur = g_vars.joueur
	if not joueur:
		return
	
	# Calculer la distance entre ce nœud et le joueur
	var distance = global_position.distance_to(joueur.global_position)
	
	# Vérifier si le joueur est à portée de détection
	if distance <= distance_detection:
		print("fin du jeux")
		get_tree().change_scene_to_file("res://Scènes/ecran_victory.tscn")
