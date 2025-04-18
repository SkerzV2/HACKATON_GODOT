extends Node3D

# Références aux groupes spécifiques
@onready var group_presents = get_node("group_presents")
@onready var group_presents2 = get_node("group_presents2")

@onready var instruction_label = get_node("../../../UI/InstructionLabel")
@onready var counter_label = get_node("../../../UI/CounterLabel")

@onready var porte_salon = get_node("../../Portes/Porte Salon")
@onready var animation_porte_salon = porte_salon.get_node("AnimationPlayer")

@onready var fmod_emitter = get_node("FmodListener3D/FmodEventEmitter3D")
@onready var fmod_porte = porte_salon.get_node("cabin-door-rotate/door/FmodListener3D/FmodEventEmitter3D")


var cadeaux_poses = 0
var total_cadeaux_a_poser = 28 # Définissez le nombre total de cadeaux requis

# Référence à l'UI qui montre le bouton "Appuyer sur E"
@export var interaction_prompt: Control

# Distance à laquelle le joueur peut interagir avec les cadeaux
@export var distance_interaction: float = 5.0

# Variable pour suivre le cadeau actuellement sélectionné
var cadeau_selectionne = null

# Pour les marqueurs lumineux
var marqueurs_lumineux = []

func _ready():
	animation_porte_salon.play("close")
	# Assurez-vous que les labels ont été trouvés
	if not instruction_label or not counter_label:
		printerr("Erreur : Les labels d'instruction ou de compteur n'ont pas été trouvés. Vérifiez les noms et les chemins dans la scène.")
		set_process(false) # Désactiver le process si l'UI n'est pas trouvée

	# Mettre à jour l'affichage initial du compteur
	_update_counter_label()
	
	# Cacher tous les cadeaux au démarrage
	cacher_tous_les_cadeaux()
	
	# Attendre une frame avant de créer les marqueurs lumineux
	# pour s'assurer que tous les nœuds sont bien dans l'arbre de scène
	call_deferred("creer_marqueurs_lumineux")
	
	# Cacher l'interface d'interaction
	if interaction_prompt:
		interaction_prompt.visible = false
	else:
		push_warning("Cadeau_Manager: Aucun prompt d'interaction assigné")

func cacher_tous_les_cadeaux():
	if group_presents:
		for cadeau in group_presents.get_children():
			cadeau.visible = false
	
	if group_presents2:
		for cadeau in group_presents2.get_children():
			cadeau.visible = false

func creer_marqueurs_lumineux():
	# Attendre que tout soit initialisé
	await get_tree().process_frame
	
	# Créer les marqueurs lumineux pour chaque emplacement de cadeau
	creer_marqueurs_pour_groupe(group_presents)
	creer_marqueurs_pour_groupe(group_presents2)

func creer_marqueurs_pour_groupe(groupe):
	if not groupe:
		return
		
	for cadeau in groupe.get_children():
		# Créer un nouveau marqueur lumineux
		var marqueur = creer_marqueur_lumineux()
		
		# Ajouter d'abord le marqueur à la scène
		add_child(marqueur)
		
		# Puis positionner le marqueur sous le cadeau
		marqueur.global_position = cadeau.global_position
		# Abaisser légèrement le marqueur pour qu'il soit sous le cadeau
		marqueur.global_position.y -= 0.05
		
		# Associer le marqueur au cadeau
		marqueur.set_meta("cadeau_associe", cadeau)
		
		# Garder une référence pour pouvoir les supprimer plus tard
		marqueurs_lumineux.append(marqueur)

func creer_marqueur_lumineux():
	# Créer un nœud Area3D pour le marqueur
	var area = Area3D.new()
	area.name = "MarqueurLumineux"
	
	# Ajouter un CollisionShape3D pour définir la zone
	var collision = CollisionShape3D.new()
	var shape = CylinderShape3D.new()
	shape.radius = 0.2  # Rayon du cylindre
	shape.height = 0.1  # Hauteur du cylindre
	collision.shape = shape
	area.add_child(collision)
	
	# Ajouter un MeshInstance3D pour la visualisation
	var mesh_instance = MeshInstance3D.new()
	var cylinder_mesh = CylinderMesh.new()
	cylinder_mesh.top_radius = 0.2
	cylinder_mesh.bottom_radius = 0.4
	cylinder_mesh.height = 0.05
	mesh_instance.mesh = cylinder_mesh
	
	# Créer un matériau pour le glow effect
	var material = StandardMaterial3D.new()
	material.emission_enabled = true
	material.emission = Color(0.2, 0.7, 0.9, 0.5)  # Couleur bleu clair
	material.emission_energy = 2.0
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.2, 0.7, 0.9, 0.3)  # Légèrement transparent
	mesh_instance.material_override = material
	
	area.add_child(mesh_instance)
	
	return area

func _process(_delta):
	# Vérifier si le joueur est proche d'un cadeau
	check_proximity_to_presents()
	
	# Vérifier l'interaction via la touche E
	if (Input.is_action_just_pressed("interagir") or ArduinoManager.bouton2) and cadeau_selectionne:
		await get_tree().create_timer(0.2).timeout
		deposer_cadeau()
	
	# Mettre à jour les marqueurs lumineux
	update_marqueurs_lumineux()

func update_marqueurs_lumineux():
	for marqueur in marqueurs_lumineux:
		# Utiliser get_meta pour accéder au cadeau associé
		if marqueur.has_meta("cadeau_associe"):
			var cadeau = marqueur.get_meta("cadeau_associe")
			# Si le cadeau associé est visible, cacher le marqueur
			if cadeau.visible:
				marqueur.visible = false

func check_proximity_to_presents():
	var joueur = g_vars.joueur
	if not joueur:
		return
	
	# Réinitialiser la sélection
	var precedent_cadeau = cadeau_selectionne
	cadeau_selectionne = null
	
	# Vérifier la proximité avec les cadeaux du premier groupe
	if group_presents:
		check_group_proximity(group_presents, joueur)
	
	# Vérifier la proximité avec les cadeaux du deuxième groupe si aucun cadeau n'est encore sélectionné
	if group_presents2 and not cadeau_selectionne:
		check_group_proximity(group_presents2, joueur)
	
	# Mettre à jour l'interface utilisateur uniquement si l'état a changé
	if interaction_prompt and precedent_cadeau != cadeau_selectionne:
		interaction_prompt.visible = cadeau_selectionne != null

func check_group_proximity(group, joueur):
	for cadeau in group.get_children():
		if not cadeau.visible:  # Ne considérer que les cadeaux invisibles
			var distance = joueur.global_position.distance_to(cadeau.global_position)
			if distance < distance_interaction:
				cadeau_selectionne = cadeau
				break

func deposer_cadeau():
	if cadeau_selectionne:
		# Rendre le cadeau visible
		cadeau_selectionne.visible = true
		
		# Mise à jour texte UI
		cadeaux_poses += 1
		print(cadeaux_poses)
		_update_counter_label()
		
		# Vérifier si tous les cadeaux sont posés
		if cadeaux_poses >= total_cadeaux_a_poser:
			instruction_label.text = "Tous les cadeaux ont été posés !" # Message de fin
			supprimer_tous_marqueurs() # Supprimer tous les marqueurs quand tout est fini
			animation_porte_salon.play("open")
			fmod_porte.play()
		
		# Jouer un son ou une animation si nécessaire
		fmod_emitter.play()
		
		# Réinitialiser la sélection et cacher le prompt
		cadeau_selectionne = null
		if interaction_prompt:
			interaction_prompt.visible = false

func supprimer_tous_marqueurs():
	# Supprimer tous les marqueurs lumineux
	for marqueur in marqueurs_lumineux:
		marqueur.queue_free()
	
	# Vider la liste
	marqueurs_lumineux.clear()

func _update_counter_label():
	counter_label.text = "Cadeaux posés : " + str(cadeaux_poses) + "/" + str(total_cadeaux_a_poser)
