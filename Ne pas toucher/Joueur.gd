extends CharacterBody3D
# Based on this tutorial: https://www.youtube.com/watch?v=A3HLeyaBCq4

var speed
const WALK_SPEED = 3.0
var noise_amount_walk = 0.3
const SPRINT_SPEED = 5.0
var noise_amount_speed = 0.8
const JUMP_VELOCITY = 4.5
const SENSIBILITE = 0.003

# Head bob variable
const BOB_FREQ = 2.0
const BOB_AMPLITUDE = 0.08
var time_bob = 0.0

const JOYSTICK_DEADZONE = 50 # Valeur de zone morte pour les joysticks
const JOYSTICK_SENSIBILITE = 0.00005 # Sensibilité pour la rotation de la caméra avec joystick

# Valeurs min/max pour les joysticks et levier
const JOYSTICK_MIN = 0
const JOYSTICK_MAX = 1023
const JOYSTICK_CENTER = 511.5 # Milieu calculé
const LEVIER_MIN = 0
const LEVIER_MAX = 1010

# FOV variables
const BASE_FOV = 75.0
const FOV_CHANGE = 1.5
const RECUL_COUP = 1.0

var gravity = 9.8

var noise_amount_grince = 5
@onready var fmod_listener = get_node("../Map/Sol/craque_parquet/FmodListener3D")
@onready var fmod_emitter = fmod_listener.get_node("FmodEventEmitter3D")

@onready var fmod_listener_pas = get_node("Tête/Camera3D/FmodListener3D")
@onready var emetteur_marche = fmod_listener_pas.get_node("FmodEventEmitter3D_pas_lent")
@onready var emetteur_course = fmod_listener_pas.get_node("FmodEventEmitter3D_pas_rapide")
@onready var cactus_list = []
@onready var lumiere = get_node("Tête/Camera3D/SpotLight3D")
@onready var animation_tete = get_node("AnimationPlayer")

var lampe_allumee = false
var last_bouton1_state = 0
var brightness = 1.0
const MIN_BRIGHTNESS = 0.1
const MAX_BRIGHTNESS = 4.0
const BRIGHTNESS_STEP = 0.5  # Pas d'augmentation/diminution de luminosité pour le clavier

# Son variables
var son_courir_actif = false
var son_marcher_actif = false

# Interaction
var last_bouton2_state = 0

# Référence ArduinoManager si c'est un singleton (Autoload)
var arduino_debug_timer = 0.0 # Pour éviter le spam console

@onready var tête = $"Tête"
@onready var camera = $"Tête/Camera3D"
@onready var rect_dégât = $"Interface_Joueur/rect_dégât"
# Distance d'interaction avec les cactus
const detection_distance: float = 2.5
# Variable pour suivre le dernier cactus activé
var last_activated_cactus = null
# Cooldown pour éviter de jouer le son trop souvent
var can_play_sound = true
var cooldown_time = 2.0

var speed_son = null
var is_moving = false
var was_moving = false

# Variables pour gérer l'état de la touche marcher
var marcher_pressed = false
var was_marcher_pressed = false
var animation_timer = 0.0
const ANIMATION_DURATION = 0.3  # Durée minimale de l'animation en secondes

var walk_timer: Timer  # Déclarer le timer
var speed_timer: Timer  # Déclarer le timer
var noise_interval = 0.3

func _init():
	g_vars.joueur = self

func _ready():	
	walk_timer = Timer.new()
	add_child(walk_timer)
	walk_timer.connect("timeout", _on_walk_timer_timeout)
	walk_timer.wait_time = noise_interval
	walk_timer.one_shot = false  # Répéter le timer
	walk_timer.autostart = false # Ne pas démarrer automatiquement
	
	speed_timer = Timer.new()
	add_child(speed_timer)
	speed_timer.connect("timeout", _on_speed_timer_timeout)
	speed_timer.wait_time = noise_interval
	speed_timer.one_shot = false  # Répéter le timer
	speed_timer.autostart = false # Ne pas démarrer automatiquement
	
	animation_tete.play("up")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	# Récupérer tous les cactus
	for i in range(1, 21):
		var cactus = get_node_or_null("../Map/Sol/craque_parquet/cactus_small_A" + str(i))
		if cactus:
			cactus_list.append(cactus)
		else:
			push_warning("Cactus_Manager: Cactus cactus_small_A" + str(i) + " non trouvé")
	# Désactiver la lampe au démarrage
	lumiere.visible = false

func _unhandled_input(event):
	# On garde la souris pour le débug, mais la vue sera aussi contrôlée par le joystick
	if event is InputEventMouseMotion:
		tête.rotate_y(-event.relative.x * SENSIBILITE)
		camera.rotate_x(-event.relative.y * SENSIBILITE)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-70), deg_to_rad(60))

	# Pour le débogage - touche L allume/éteint lampe
	if event is InputEventKey and event.pressed:
		if Input.is_action_pressed("Lampe"):
			toggle_lampe()
		# Ajouter contrôles pour augmenter/diminuer la luminosité de la lampe
		elif Input.is_action_pressed("Augmenter_lux"):
			if lumiere.visible:
				lumiere.light_energy = min(lumiere.light_energy + BRIGHTNESS_STEP, MAX_BRIGHTNESS)
		elif Input.is_action_pressed("Baisser_lux"):
			if lumiere.visible:
				lumiere.light_energy = max(lumiere.light_energy - BRIGHTNESS_STEP, MIN_BRIGHTNESS)

func _physics_process(delta):
	# Gérer le timer d'animation si nécessaire
	if animation_timer > 0:
		animation_timer -= delta
	
	# Vérifier l'état de la touche marcher
	marcher_pressed = Input.is_action_pressed("Marcher") or (ArduinoManager and ArduinoManager.connected and ArduinoManager.bouton3 == 1)
	
	# Si l'état de la touche a changé et que le timer n'est pas actif
	if marcher_pressed != was_marcher_pressed and animation_timer <= 0:
		if marcher_pressed:
			# La touche marcher est pressée
			animation_tete.play("down")
			animation_timer = ANIMATION_DURATION
		else:
			# La touche marcher est relâchée
			animation_tete.play("up")
			animation_timer = ANIMATION_DURATION
		
		# Mettre à jour l'état précédent
		was_marcher_pressed = marcher_pressed

	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle jump - si on utilise boutonJoystick1 pour sauter
	# if ArduinoManager and ArduinoManager.connected and ArduinoManager.boutonJoystick1 == 1 and is_on_floor():
	#	velocity.y = JUMP_VELOCITY
	#elif Input.is_action_just_pressed("Sauter") and is_on_floor():  # Garde le contrôle clavier pour debug
	#	velocity.y = JUMP_VELOCITY
	
	# Handle sprint/walk with Arduino button3 or keyboard
	if marcher_pressed:
		speed = WALK_SPEED  # Marche lente quand bouton3 est pressé ou touche marcher
		speed_son = emetteur_marche
	else:
		speed = SPRINT_SPEED
		speed_son = emetteur_course
		
	# Contrôle mouvement avec joystick Arduino ou clavier
	var input_dir = Vector2.ZERO
	
	if ArduinoManager and ArduinoManager.connected:
		# Normalisation et application d'une zone morte pour joystick1
		var joy1x = ArduinoManager.joystick1x
		var joy1y = ArduinoManager.joystick1y
		
		# Ajustement par rapport au centre
		joy1x -= JOYSTICK_CENTER
		joy1y -= JOYSTICK_CENTER
		
		# Application d'une zone morte
		if abs(joy1x) < JOYSTICK_DEADZONE:
			joy1x = 0
		if abs(joy1y) < JOYSTICK_DEADZONE:
			joy1y = 0
			
		# Normalisation entre -1 et 1 (on divise par la moitié de la plage)
		joy1x = joy1x / (JOYSTICK_MAX / 2.0)
		joy1y = joy1y / (JOYSTICK_MAX / 2.0)
		
		# Limiter à -1/1
		joy1x = clamp(joy1x, -1.0, 1.0)
		joy1y = clamp(joy1y, -1.0, 1.0)
		
		# Inverser Y pour correspondre aux contrôles habituels
		joy1y = -joy1y
		
		input_dir = Vector2(joy1x, joy1y)
		
		# Contrôle caméra avec joystick2
		var joy2x = ArduinoManager.joystick2x - JOYSTICK_CENTER
		var joy2y = ArduinoManager.joystick2y - JOYSTICK_CENTER
		
		# Application d'une zone morte
		if abs(joy2x) > JOYSTICK_DEADZONE:
			tête.rotate_y(-joy2x * JOYSTICK_SENSIBILITE * delta * 1000)
		if abs(joy2y) > JOYSTICK_DEADZONE:
			camera.rotate_x(-joy2y * JOYSTICK_SENSIBILITE * delta * 1000)
			camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-70), deg_to_rad(60))
		
		# Gestion du bouton1 pour la lampe (changement d'état)
		if ArduinoManager.bouton1 == 1:
			lumiere.visible = true
		else:
			lumiere.visible = false

		
		# Gestion du bouton2 pour interaction (touche E)
		if ArduinoManager.bouton2 == 1 and last_bouton2_state == 0:
			# Simulation appui touche E
			var event = InputEventAction.new()
			event.action = "Interagir"  # Assurez-vous que cette action existe
			event.pressed = true
			Input.parse_input_event(event)
		last_bouton2_state = ArduinoManager.bouton2
		

		# Gestion du levier pour la luminosité
		if lumiere.visible:
			# Normaliser la valeur du levier (0-1010) vers MIN_BRIGHTNESS-MAX_BRIGHTNESS
			var slider_value = ArduinoManager.levier  # disons que ça retourne entre 0 et 1010
			var lux = 0.0 + (slider_value / 1010.0) * (50.0 - 0.0)  # tu veux que la lumière varie de 0 à 5 par exemple

			lumiere.light_energy = lux
	
	# Utiliser le clavier si pas d'Arduino ou pour debug
	if input_dir.length() < 0.1:
		input_dir = Input.get_vector("Gauche", "Droite", "Avancer", "Reculer")
	
	# Déterminer si le joueur est en mouvement
	is_moving = input_dir.length() > 0.1
		
	var direction = (tête.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if is_on_floor():
		if direction:
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
			
			# Gestion des sons de pas (que ce soit avec le clavier ou l'Arduino)
			if is_moving:
				if speed_son == emetteur_course: # Course
					if not son_courir_actif:
						# Arrêter le son de marche si actif
						emetteur_marche.stop()
						walk_timer.stop()
						son_marcher_actif = false
					
						# Jouer le son de course
						emetteur_course.play()
						speed_timer.start()
						son_courir_actif = true
						
				elif speed_son == emetteur_marche: # Marche
					if not son_marcher_actif:
						# Arrêter le son de course si actif
						emetteur_course.stop()
						speed_timer.stop()
						son_courir_actif = false
					
						# Jouer le son de marche lente
						emetteur_marche.play()
						walk_timer.start()
						son_marcher_actif = true
			
		else:
			velocity.x = 0.0
			velocity.z = 0.0
			# Arrêter les sons si le personnage ne bouge pas
			if son_marcher_actif or son_courir_actif:
				emetteur_marche.stop()
				emetteur_course.stop()
				walk_timer.stop()
				speed_timer.stop()
				son_marcher_actif = false
				son_courir_actif = false
							
	else:
		velocity.x = lerp(velocity.x, direction.x * speed, delta * 3.0)
		velocity.z = lerp(velocity.z, direction.z * speed, delta * 3.0)
	
	# Head bob feature:
	time_bob += delta * velocity.length() * float(is_on_floor())
	camera.transform.origin = _headbob(time_bob)
	
	# FOV
	var velocity_clamped = clamp(velocity.length(), 0.5, SPRINT_SPEED * 2)
	var target_fov = BASE_FOV + FOV_CHANGE * velocity_clamped
	camera.fov = lerp(camera.fov, target_fov, delta * 8.0)
	
	move_and_slide()
	
	var joueur = g_vars.joueur
	if not joueur or not can_play_sound:
		return
	
	# Vérifier la proximité avec chaque cactus
	for cactus in cactus_list:
		var distance = joueur.global_position.distance_to(cactus.global_position)
		if distance < detection_distance and last_activated_cactus != cactus:
			print("ca grince")
			# Le joueur est à proximité d'un nouveau cactus
			last_activated_cactus = cactus
			
			# Déplacer le listener FMOD à la position du cactus
			fmod_listener.global_position = cactus.global_position
			
			# Jouer le son
			fmod_emitter.play()
			NoiseManager.add_noise(noise_amount_grince)
			
			# Activer le cooldown
			can_play_sound = false
			start_cooldown(delta)
			
			# Sortir de la boucle une fois qu'un cactus est activé
			break
			
func start_cooldown(delta):
	await get_tree().create_timer(cooldown_time).timeout
	can_play_sound = true
	# Réinitialiser le dernier cactus activé si le joueur n'est plus à proximité
	var joueur = g_vars.joueur
	if joueur and last_activated_cactus:
		var distance = joueur.global_position.distance_to(last_activated_cactus.global_position)
		if distance > detection_distance:
			last_activated_cactus = null

	# --- DEBUG ARDUINO ---
	arduino_debug_timer += delta
	if arduino_debug_timer >= 1.0:
		arduino_debug_timer = 0.0
		if ArduinoManager and ArduinoManager.connected:
			print("📡 ARDUINO VALUES → joy1: (", ArduinoManager.joystick1x, ", ", ArduinoManager.joystick1y, 
				  ") | joy2: (", ArduinoManager.joystick2x, ", ", ArduinoManager.joystick2y, ")")
			print("Boutons: ", ArduinoManager.bouton1, ", ", ArduinoManager.bouton2, ", ", ArduinoManager.bouton3)
			print("Bouton Joysticks: ", ArduinoManager.boutonJoystick1, ", ", ArduinoManager.boutonJoystick2)
			print("Levier: ", ArduinoManager.levier)

func _headbob(time) -> Vector3:
	var pos = Vector3.ZERO
	pos.y = sin(time * BOB_FREQ) * BOB_AMPLITUDE
	pos.x = cos(time * BOB_FREQ / 2) * BOB_AMPLITUDE
	return pos

func toggle_lampe():
	lampe_allumee = !lampe_allumee
	lumiere.visible = lampe_allumee
	print("Lampe: ", "ON" if lampe_allumee else "OFF")

func coup(dir):
	effets_dégâts()
	velocity += dir * RECUL_COUP

func effets_dégâts():
	rect_dégât.visible = true
	await get_tree().create_timer(0.2).timeout
	rect_dégât.visible = false
	
func _on_walk_timer_timeout():
	NoiseManager.add_noise(noise_amount_walk)
	
func _on_speed_timer_timeout():
	NoiseManager.add_noise(noise_amount_speed)
