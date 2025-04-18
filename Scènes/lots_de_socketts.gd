extends Node

@onready var porte_final = get_node("../../Portes/Porte de sortie final")
@onready var porte_final_anim_player = porte_final.get_node("AnimationPlayer")
# Références aux chaussettes
@onready var chaussettes = []
# Référence au label d'interaction

# Distance à laquelle le joueur peut interagir avec les chaussettes
@export var distance_interaction: float = 2.0

# Variable pour stocker l'index de la chaussette qui contient la clé
var chaussette_avec_clef = -1

# Variable pour suivre si la clé a été trouvée
var clef_trouvee = false

func _ready():
	porte_final_anim_player.play("close")
	# Récupérer toutes les chaussettes
	for i in range(1, 8):
		var chaussette = get_node("Sockett" + str(i))
		if chaussette:
			chaussettes.append(chaussette)	
			# Cacher le label d'instruction au démarrage
			var interaction_prompt = get_node("../../../UI/label_sockett" + str(i))
			if interaction_prompt:
				interaction_prompt.visible = false
				interaction_prompt.text = "'E' pour chercher"
			else:
				push_warning("Chaussettes_Manager: Label d'instruction non trouvé")
	
	# Choisir aléatoirement une chaussette qui contiendra la clé
	randomize()
	chaussette_avec_clef = randi() % chaussettes.size()
	

func _process(_delta):
	var joueur = g_vars.joueur
	if not joueur:
		return
	
	# Variable pour suivre si le joueur est proche d'une chaussette
	var est_proche = false
	var chaussette_proche = null
	var index_chaussette_proche = -1
	
	# Vérifier la distance avec chaque chaussette
	for i in range(0,7):
		var nbSockett = i+1
		var chaussette = chaussettes[i]
		var distance = joueur.global_position.distance_to(chaussette.global_position)
		var interaction_prompt = get_node("../../../UI/label_sockett" + str(nbSockett))
		if distance < distance_interaction:
			est_proche = true
			chaussette_proche = chaussette
			index_chaussette_proche = i
			interaction_prompt.visible = true
		else :
			interaction_prompt.visible = false
	
	# Gérer l'affichage du label d'interaction
	if est_proche and !clef_trouvee:	
		var interaction_prompt = get_node("../../../UI/label_sockett" + str(index_chaussette_proche+1))	
		# Si le joueur appuie sur E près d'une chaussette
		if Input.is_action_just_pressed("interagir") or ArduinoManager.bouton2:
			if index_chaussette_proche == chaussette_avec_clef:
				# Bonne chaussette!
				interaction_prompt.text = "Clef trouvée"
				clef_trouvee = true
				porte_final_anim_player.play("open")
				porte_final.get_node("FmodListener3D/FmodEventEmitter3D").play()
			else:
				# Mauvaise chaussette
				interaction_prompt.text = "Chaussette vide"
				
			# Attendre un peu avant de revenir à "E" ou cacher le label
			await get_tree().create_timer(2.0).timeout
			if clef_trouvee:
				interaction_prompt.visible = false
			else:
				interaction_prompt.text = "'E' pour chercher"
