extends Area3D

@onready var fmod_emitter_objectloop = $FmodEventEmitter3D_objectloop
@onready var AudioPlayer3D: AudioStreamPlayer3D = $AudioStreamPlayer3D # Pour compatibilité avec versions antérieures

# Définition des numéros de séquence d'objets - utilisés pour sélectionner quel son FMOD joue
const OBJECT_LOOP_PARAMETER_NAME = "ObjectLoopNum"
# Utilisation de chaînes au lieu d'entiers pour les valeurs d'objet pour correspondre aux paramètres FMOD
const OBJECT_STATE_VALUES = ["Objet1", "Objet2", "Objet3", "Objet4", "Vide"]
var object_state = "Objet1" # Par défaut au premier objet, remplacé dans _ready en fonction de la position dans la scène

@export var activated: bool = false
@export var Prochain_Objet_A_Activer: Node
@export var final_object: bool = false

@onready var final_camera = %Final_Camera
@onready var fade_rect: ColorRect = $CanvasLayer/FadeRect

func _ready():
	# Déterminer l'état de l'objet en fonction de sa position dans la scène
	determine_object_state()
	
	# Initialiser l'événement FMOD
	initialize_fmod_sound()
	
	set_visibility(activated)
	if activated:
		play_object_sound()
	
	connect("body_entered", Callable(self, "_on_body_entered"))

func determine_object_state():
	# Tente d'extraire le numéro d'objet du nom du nœud
	var node_name = name
	
	# Vérifie si le nom suit le modèle "Object_To_Catch_X"
	if node_name.begins_with("Object_To_Catch_"):
		var num_string = node_name.substr("Object_To_Catch_".length())
		if num_string.is_valid_int():
			var num = num_string.to_int()
			if num >= 1 and num <= 4:
				object_state = "Objet" + str(num)
			elif num == 5 and final_object:
				object_state = "Vide" # L'objet final obtient l'état "Vide"
	
	# Ou nous pouvons le déterminer en fonction de l'ordre de l'arborescence de la scène
	var parent = get_parent()
	if parent:
		var siblings = parent.get_children()
		var object_count = 0
		for i in range(siblings.size()):
			if siblings[i].name.begins_with("Object_To_Catch_"):
				object_count += 1
				if siblings[i] == self:
					if object_count <= 4:
						object_state = "Objet" + str(object_count)
					else:
						object_state = "Vide"
	
	# Si c'est l'objet final, assurez-vous qu'il utilise "Vide"
	if final_object:
		object_state = "Vide"
		
	print("Object_To_Catch state set to: ", object_state)

func initialize_fmod_sound():
	# Définir le paramètre pour quel son d'objet jouer en utilisant la valeur de chaîne
	fmod_emitter_objectloop.set_parameter(OBJECT_LOOP_PARAMETER_NAME, object_state)
	
	print("FMOD ObjectLoop sound initialized with parameter ", OBJECT_LOOP_PARAMETER_NAME, " = ", object_state)

func _process(delta):
	pass

func set_visibility(is_visible):
	if is_visible:
		self.show()
	else:
		self.hide()

func play_object_sound():
	# Démarrer le son de boucle FMOD pour cet objet
	fmod_emitter_objectloop.play()
	print("Playing FMOD object loop sound for object: ", object_state)

func stop_object_sound():
	# Arrêter le son de boucle FMOD
	fmod_emitter_objectloop.stop()

func _on_body_entered(body):
	if body.name == "JoueurDemo":
		if final_object:
			body.Play_Feedback_Sound()
			body.hide()
			final_camera.make_current()
			stop_object_sound() # Arrêter le son FMOD
			body.BackgroundSoundPlayer.stream_paused = true
			fade_to_black()
		else:
			if Prochain_Objet_A_Activer:
				Prochain_Objet_A_Activer.activated = true
				Prochain_Objet_A_Activer.set_visibility(true)
				Prochain_Objet_A_Activer.play_object_sound()
				body.Play_Feedback_Sound()
			queue_free()

func fade_to_black():
	var tween = get_tree().create_tween()
	tween.tween_property(fade_rect, "modulate:a", 1.0, 6.0).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
