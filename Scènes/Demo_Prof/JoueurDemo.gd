extends CharacterBody3D

# Constantes pour le mouvement et la physique
const SPEED = 10.0
const ALTITUDE_SMOOTHING_FACTOR = 0.1  # Facteur de lissage pour les changements d'altitude
const ROTATION_SMOOTHING_FACTOR = 0.1  # Facteur de lissage pour les rotations
const GROUND_LEVEL = 0.0  # Niveau du sol
const MAX_VIBRATION_DISTANCE = 15.0  # Distance maximale pour la détection de vibration
const MIN_VIBRATION_DISTANCE = 0.5   # Seuil minimal de distance pour la vibration

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var target_altitude = 0.0
var target_rotation = 0.0

var Is_Arduino_Mode_On = true # Variable pour basculer entre le contrôle Arduino et le contrôle souris/clavier
const SENSIBILITE = 0.002
const ALTITUDE_CHANGE_SPEED = 0.12

# Émetteurs d'événements FMOD
@onready var fmod_emitter_music = $FmodEventEmitter2D_music
@onready var fmod_emitter_footstep = $FmodEventEmitter3D_footstep
@onready var fmod_emitter_reward = $FmodEmitter2D_reward

@onready var BackgroundSoundPlayer: AudioStreamPlayer = $BackgroundSoundPlayer

# Pour compatibilité avec versions antérieures
@onready var AudioPlayer1: AudioStreamPlayer = $AudioStreamPlayer1
@onready var AudioPlayer2: AudioStreamPlayer = $AudioStreamPlayer2
@onready var AudioPlayer3: AudioStreamPlayer = $AudioStreamPlayer3

var AudioPlayers = []

# Suivi des objets collectés et états de la musique
var compteur_object_collecte = 0
const MUSIC_STATE_NAMES = ["Vide", "Etat1", "Etat2", "Etat3", "Etat4"]
const MUSIC_PARAMETER_NAME = "MusiqueEtat"

# Collectibles au sol
var ground_collectibles = [] # Tableau pour stocker les collectibles au sol
var last_vibration_time = 0.0 # Moment de la dernière commande de vibration
var vibration_active = false # Si la vibration est actuellement active
var vibration_on_duration = 0.5 # Durée de maintien de la vibration (secondes)
var vibration_off_duration = 1.0 # Durée d'arrêt de la vibration (secondes)
var near_collectible_distance = 5.0 # Seuil de distance pour être considéré "proche" d'un collectible
var is_playing_footstep = false # Suivi si le son de pas est en cours de lecture
var debug_ignore_floor_check = true # Pour tester la vibration indépendamment de l'état du sol

# Paramètres FMOD pour les pas
const FOOTSTEP_PARAMETER_NAME = "CharacterWalk" 
const FOOTSTEP_STATE_FLY = "CharacterFly"
const FOOTSTEP_STATE_WALK = "CharacterWalk"

func _ready():
	randomize()
	AudioPlayers = [AudioPlayer1, AudioPlayer2, AudioPlayer3]
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	%ArduinoModeTimer.timeout.connect(_on_ArduinoModeTimer_timeout)
	%ArduinoModeTimer.start(2.0)

	# Création des émetteurs FMOD requis
	create_missing_fmod_emitters()
	
	# Initialisation des événements FMOD
	initialize_fmod_sounds()
	
	# Affichage des propriétés de l'émetteur de pas pour débogage
	debug_footstep_emitter()
	
	# Recherche de tous les collectibles au sol dans la scène
	find_ground_collectibles()

func create_missing_fmod_emitters():
	# Vérification et création de l'émetteur de musique si nécessaire
	if !has_node("FmodEventEmitter2D_music"):
		fmod_emitter_music = FmodEventEmitter2D.new()
		fmod_emitter_music.name = "FmodEventEmitter2D_music"
		add_child(fmod_emitter_music)
		print("Created missing music emitter")
	else:
		fmod_emitter_music = $FmodEventEmitter2D_music
	
	# Vérification et création de l'émetteur de pas si nécessaire
	if !has_node("FmodEventEmitter3D_footstep"):
		fmod_emitter_footstep = FmodEventEmitter3D.new()
		fmod_emitter_footstep.name = "FmodEventEmitter3D_footstep"
		add_child(fmod_emitter_footstep)
		print("Created missing footstep emitter")
	else:
		fmod_emitter_footstep = $FmodEventEmitter3D_footstep
		print("Found existing footstep emitter: ", fmod_emitter_footstep)
		
	# Vérification et création de l'émetteur de récompense si nécessaire
	if !has_node("FmodEmitter2D_reward"):
		fmod_emitter_reward = FmodEventEmitter2D.new()
		fmod_emitter_reward.name = "FmodEmitter2D_reward"
		add_child(fmod_emitter_reward)
		print("Created missing reward emitter")
	else:
		fmod_emitter_reward = $FmodEmitter2D_reward

func initialize_fmod_sounds():
	# Démarrage de la musique dans l'état 1
	fmod_emitter_music.play()
	fmod_emitter_music.set_parameter(MUSIC_PARAMETER_NAME, "Etat1") # Commence avec Etat1
	
	# Initialisation du paramètre de pas (par défaut en vol)
	fmod_emitter_footstep.set_parameter(FOOTSTEP_PARAMETER_NAME, FOOTSTEP_STATE_FLY)
	
	print("FMOD sounds initialized")

func find_ground_collectibles():
	# Recherche de tous les nœuds correspondant à notre groupe de collectibles au sol
	ground_collectibles = get_tree().get_nodes_in_group("ground_collectibles")
	
	# Si nous n'en avons trouvé aucun, essayons une approche plus directe
	if ground_collectibles.size() == 0:
		var collectibles_node = get_node_or_null("/root/Principale_test/GroundCollectibles")
		if collectibles_node:
			for child in collectibles_node.get_children():
				if child.name.begins_with("GroundCollectible"):
					ground_collectibles.append(child)
					print("Debug: Added collectible: ", child.name)
	
	print("Total ground collectibles: ", ground_collectibles.size())

func Arduino_Mouvement():
	# Vérification si le capteur ultrasonique indique que la main est éloignée
	if ArduinoManager.ultrasonUn >= 130:
		target_altitude = GROUND_LEVEL # Par défaut au niveau du sol
	else:
		target_altitude = float(ArduinoManager.ultrasonUn) / 3
	
	target_rotation = deg_to_rad(ArduinoManager.potentiometreUn / 1.5)

func Play_Feedback_Sound():
	# Lecture du son de récompense FMOD
	fmod_emitter_reward.play()
	
	# Mise à jour de l'état de la musique en fonction du nombre de collectibles
	compteur_object_collecte += 1
	update_music_state()

func update_music_state():
	# Assurer que le compteur ne dépasse pas nos états définis
	var state_index = min(compteur_object_collecte, MUSIC_STATE_NAMES.size() - 1)
	
	# Obtenir la valeur de chaîne correspondante pour l'état
	var state_name = MUSIC_STATE_NAMES[state_index]
	
	# Mettre à jour le paramètre de musique FMOD avec la valeur de chaîne
	fmod_emitter_music.set_parameter(MUSIC_PARAMETER_NAME, state_name)
	print("Music state changed to: ", state_name)

func play_footstep_sound():
	# Lecture du son de pas FMOD
	if !is_playing_footstep:
		is_playing_footstep = true
		
		# Définir le paramètre correct pour la marche
		fmod_emitter_footstep.set_parameter(FOOTSTEP_PARAMETER_NAME, FOOTSTEP_STATE_WALK)
		
		# Lire le son de pas
		fmod_emitter_footstep.play()
		print("Playing footstep sound (CharacterWalk)")
		
		# Attendre un peu avant de permettre un autre pas
		await get_tree().create_timer(0.3).timeout
		is_playing_footstep = false

func find_nearest_collectible_distance():
	# Trouver le collectible le plus proche et renvoyer sa distance
	var min_distance = MAX_VIBRATION_DISTANCE
	var nearest_collectible = null
	
	for collectible in ground_collectibles:
		if is_instance_valid(collectible) and collectible.visible: # Uniquement les collectibles visibles
			var distance = global_position.distance_to(collectible.global_position)
			if distance < min_distance:
				min_distance = distance
				nearest_collectible = collectible
	
	# Vérifier également les objets collectibles ordinaires (Object_To_Catch_1)
	var regular_collectibles = get_tree().get_nodes_in_group("collectibles")
	if regular_collectibles.size() == 0:
		# Essayer de les trouver par type ou nom
		var all_nodes = get_tree().get_nodes_in_group("Object_To_Catch_1")
		for node in all_nodes:
			if node.has_method("play_object_sound") and node.visible:
				var distance = global_position.distance_to(node.global_position)
				if distance < min_distance:
					min_distance = distance
					nearest_collectible = node
	else:
		for collectible in regular_collectibles:
			if is_instance_valid(collectible) and collectible.visible:
				var distance = global_position.distance_to(collectible.global_position)
				if distance < min_distance:
					min_distance = distance
					nearest_collectible = collectible
	
	return min_distance

func is_near_collectible():
	# Trouver le collectible au sol le plus proche
	var min_distance = find_nearest_collectible_distance()
	
	# Si un collectible est à portée, renvoyer vrai
	if min_distance < near_collectible_distance:
		return true
	
	return false # Pas de collectibles à proximité

func update_arduino_nearest_collectible():
	# Calculer la distance du collectible le plus proche
	var nearest_distance = find_nearest_collectible_distance()
	
	# Mettre à jour le Arduino_Manager avec cette distance
	var arduino_manager = ArduinoManager
	if arduino_manager != null:
		arduino_manager.nearestCollectibleDistance = nearest_distance

func is_near_ground():
	# Utiliser la fonction intégrée is_on_floor() ou vérifier la position y
	return is_on_floor() or global_position.y < 2.1 # En supposant que le niveau du sol est d'environ 2.0

func _physics_process(delta):
	# Activer/désactiver le "mode Arduino", l'indiquer par du texte à l'écran
	if Input.is_action_just_pressed("ArduinoToggle"):
		Is_Arduino_Mode_On = !Is_Arduino_Mode_On
		if Is_Arduino_Mode_On:
			%Menus/Arduino_indicator.text = "Arduino mode on"
			%ArduinoModeTimer.start(2.0) # démarrer un minuteur pour effacer le texte après 2 secondes
		elif !Is_Arduino_Mode_On:
			%Menus/Arduino_indicator.text = "Arduino mode off"
			%ArduinoModeTimer.start(2.0) # démarrer un minuteur pour effacer le texte après 2 secondes
	
	# Gère les changements d'altitude contrôlés par Arduino et la rotation de la caméra
	if Is_Arduino_Mode_On:
		Arduino_Mouvement()
	
		# Lisser les changements d'altitude
		var current_altitude = global_position.y
		var smoothed_altitude = lerp(current_altitude, target_altitude, ALTITUDE_SMOOTHING_FACTOR)
		global_position.y = smoothed_altitude
		
		# Lisser les changements de rotation
		var current_rotation = rotation.y
		var rotation_difference = fmod(target_rotation - current_rotation, TAU)
		if rotation_difference > PI:
			rotation_difference -= TAU
		var smoothed_rotation = current_rotation + rotation_difference * ROTATION_SMOOTHING_FACTOR
		rotation.y = smoothed_rotation
		
	# Gère le changement d'altitude non-Arduino
	elif !Is_Arduino_Mode_On:
		if Input.is_action_pressed("Sauter"):
			global_position.y += ALTITUDE_CHANGE_SPEED
		elif Input.is_action_pressed("Courir") and !is_on_floor():
			global_position.y -= ALTITUDE_CHANGE_SPEED
	
	# Mouvement automatique vers l'avant dans la direction où le personnage regarde
	var forward_direction = -transform.basis.z.normalized()
	velocity.x = forward_direction.x * SPEED
	velocity.z = forward_direction.z * SPEED
	
	# Stocker la position avant move_and_slide pour détecter si nous avons réellement bougé
	var previous_position = Vector3(global_position)
	
	move_and_slide()
	
	# Calculer le mouvement réel qui s'est produit
	var actual_movement = global_position.distance_to(previous_position)
	var is_actually_moving = actual_movement > 0.01 # Petit seuil pour détecter le mouvement réel
	
	# Mettre à jour le Arduino Manager avec la distance du collectible le plus proche
	update_arduino_nearest_collectible()
	
	# Déterminer l'état de mouvement actuel pour le son
	var is_grounded = is_near_ground()
	var is_ascending = velocity.y > 0.1
	var is_flying = !is_grounded || is_ascending
	
	# Définir le paramètre de pas en fonction de l'état actuel
	if is_flying:
		fmod_emitter_footstep.set_parameter(FOOTSTEP_PARAMETER_NAME, FOOTSTEP_STATE_FLY)
	else:
		fmod_emitter_footstep.set_parameter(FOOTSTEP_PARAMETER_NAME, FOOTSTEP_STATE_WALK)
	
	# Jouer les sons de pas uniquement si au sol, en mouvement réel et pas en ascension
	if is_grounded && is_actually_moving && !is_ascending:
		play_footstep_sound()
	
	# REMARQUE: La vibration est maintenant gérée directement dans Arduino_Manager.cs
	# Nous n'avons plus besoin de mettre à jour la vibration à partir d'ici

# Gère la rotation de la caméra non-Arduino (avec la souris)
func _input(event):
	if event is InputEventMouseMotion and !Is_Arduino_Mode_On:
		rotate_y(-event.relative.x * SENSIBILITE)

# Fonction appelée pour effacer le texte "Arduino mode on/off" à l'écran lorsque le minuteur expire
func _on_ArduinoModeTimer_timeout():
	%Menus/Arduino_indicator.text = ""

func Play_Ground_Collectible_Sound():
	# Lire un son de collectible au sol en utilisant FMOD
	fmod_emitter_reward.play()
	print("Ground collectible collected!")

func debug_footstep_emitter():
	# Obtenir le nœud directement plutôt que par la variable onready
	var footstep_node = get_node_or_null("FmodEventEmitter3D_footstep")
	if footstep_node:
		print("Footstep emitter exists at path: ", footstep_node.get_path())
		print("Footstep emitter event name: ", footstep_node.event_name)
		
		# Imprimer le nom du paramètre que nous recherchons
		print("Checking for parameter: ", FOOTSTEP_PARAMETER_NAME)
		
		# En GDScript, nous ne pouvons pas facilement vérifier si un paramètre existe avant d'y accéder
		# Alors nous allons juste imprimer ce que nous voulons faire et laisser le code de paramétrage
		# des paramètres en place ailleurs
		print("Will attempt to use parameter in footstep code")
		
		# Pour le débogage, imprimer tous les paramètres disponibles
		print("Note: Make sure the FMOD event has the CharacterWalk parameter defined in FMOD Studio")
	else:
		print("Error: No footstep emitter found at path FmodEventEmitter3D_footstep")
