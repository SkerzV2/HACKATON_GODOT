extends Node3D

# Référence à la lumière
@onready var lumiere = self

# Paramètres de la lumière
@export var intensite_normale: float = 2.0  # Intensité normale de la lumière
@export var intensite_min: float = 0.5     # Intensité minimale lors de la baisse
@export var temps_min_entre_variations: float = 0.2  # Temps minimum entre les variations
@export var temps_max_entre_variations: float = 1.0  # Temps maximum entre les variations
@export var duree_min_transition: float = 0.1  # Durée minimum d'une transition
@export var duree_max_transition: float = 0.5  # Durée maximum d'une transition
@export var probabilite_variation: float = 0.8  # Probabilité qu'une variation se produise

# Variables pour gérer l'état
var intensite_originale: float
var intensite_actuelle: float
var timer: float = 0.0
var prochain_temps_variation: float = 0.0
var est_en_transition: bool = false
var duree_transition: float = 0.0
var intensite_cible: float
var intensite_depart: float
var temps_ecoule_transition: float = 0.0

func _ready():
	# Récupérer l'intensité originale de la lumière
	if lumiere is Light3D:
		intensite_originale = lumiere.light_energy
		intensite_actuelle = intensite_originale
	else:
		# Si ce script est attaché à un nœud qui n'est pas une lumière
		var light_child = find_light_child(self)
		if light_child:
			lumiere = light_child
			intensite_originale = lumiere.light_energy
			intensite_actuelle = intensite_originale
		else:
			push_error("Aucune lumière trouvée pour la variation d'intensité")
	
	# Définir le temps de la première variation
	randomize()
	prochain_temps_variation = randf_range(temps_min_entre_variations, temps_max_entre_variations)

func _process(delta):
	# Mettre à jour le timer
	timer += delta
	
	if est_en_transition:
		# Si on est en train de faire une transition
		temps_ecoule_transition += delta
		
		# Calculer la progression de la transition (de 0 à 1)
		var progression = temps_ecoule_transition / duree_transition
		if progression > 1.0:
			progression = 1.0
			
		# Calculer la nouvelle intensité en fonction de la progression
		intensite_actuelle = lerp(intensite_depart, intensite_cible, progression)
		set_light_intensity(intensite_actuelle)
		
		# Vérifier si la transition est terminée
		if temps_ecoule_transition >= duree_transition:
			est_en_transition = false
			timer = 0.0
			
			# Si on vient de baisser l'intensité, prévoir de la remonter dans peu de temps
			if intensite_cible < intensite_normale:
				prochain_temps_variation = randf_range(0.2, 1.0)  # Délai court avant de remonter
			else:
				# Sinon, définir le temps de la prochaine baisse
				prochain_temps_variation = randf_range(temps_min_entre_variations, temps_max_entre_variations)
	else:
		# Si on n'est pas en transition, vérifier si c'est le moment de commencer une transition
		if timer >= prochain_temps_variation:
			# Déterminer si on fait une transition, selon la probabilité
			if randf() <= probabilite_variation:
				# Commencer une transition
				temps_ecoule_transition = 0.0
				duree_transition = randf_range(duree_min_transition, duree_max_transition)
				intensite_depart = intensite_actuelle
				
				# Si l'intensité est proche de la normale, on baisse
				if abs(intensite_actuelle - intensite_normale) < 0.1:
					intensite_cible = randf_range(intensite_min, intensite_normale * 0.7)
				else:
					# Sinon on remonte à la normale
					intensite_cible = intensite_normale
					
				est_en_transition = true
			
			# Réinitialiser le timer
			timer = 0.0

func set_light_intensity(intensity: float):
	# S'assurer que la lumière existe et définir son intensité
	if lumiere is Light3D:
		lumiere.light_energy = intensity

func find_light_child(node: Node) -> Light3D:
	# Recherche récursive d'une lumière parmi les enfants
	if node is Light3D:
		return node
	
	for child in node.get_children():
		var light = find_light_child(child)
		if light:
			return light
	
	return null
