extends Node3D

# Références aux frigidaires
@onready var frigo_plein = get_node("fridge_A_decorated")
@onready var frigo_vide = get_node("fridge_A")

# Références aux AnimationPlayers
@onready var anim_player_plein = frigo_plein.get_node("AnimationPlayer")
@onready var anim_player_vide = frigo_vide.get_node("AnimationPlayer")

# Référence au label d'interaction
@onready var interaction_prompt = get_node("../../../UI/InstructionLabel_fridge")

@onready var porte_vestibule = get_node("../../Portes/Porte vestibule")
@onready var porte_vestibule_anim_player = porte_vestibule.get_node("AnimationPlayer")
# Distance à laquelle le joueur peut interagir avec le frigo
@export var distance_interaction: float = 3.0

# Zone de détection pour l'ouverture automatique
@export var distance_ouverture: float = 5.0

# Variable pour suivre si le joueur est dans la zone d'ouverture
var joueur_dans_zone = false

# Variable pour suivre si le joueur a mangé dans le frigo
var nourriture_mangee = false

func _ready():
	porte_vestibule_anim_player.play("close")
	# Au démarrage, le frigo plein est visible, le vide est caché
	frigo_plein.visible = true
	frigo_vide.visible = true
	
	# Cacher le label d'instruction au démarrage
	if interaction_prompt:
		interaction_prompt.visible = false
	else:
		push_warning("Frigo_Manager: Label d'instruction non trouvé")

func _process(_delta):
	var joueur = g_vars.joueur
	if not joueur:
		return
	
	# Calculer la distance entre le joueur et le frigo
	var distance = joueur.global_position.distance_to(frigo_vide.global_position)
	
	# Gestion de l'ouverture/fermeture automatique des portes
	var precedent_dans_zone = joueur_dans_zone
	joueur_dans_zone = distance < distance_ouverture
	
	# Si le joueur vient d'entrer dans la zone
	if joueur_dans_zone and not precedent_dans_zone:
		ouvrir_portes()
	
	# Si le joueur vient de sortir de la zone
	elif (not joueur_dans_zone and precedent_dans_zone):
		fermer_portes()
	
	# Gestion de l'interaction (manger)
	if distance < distance_interaction and frigo_plein.visible:
		interaction_prompt.visible = true
		interaction_prompt.text = "'E' pour manger"
		
		# Si le joueur appuie sur E
		print(Input.is_action_just_pressed("interagir"))
		if Input.is_action_just_pressed("interagir"):
			manger_dans_frigo()
	else:
		interaction_prompt.visible = false

func ouvrir_portes():
	if frigo_plein.visible:
		anim_player_plein.play("open")
		anim_player_vide.play("open")
		frigo_vide.get_node("FmodListener3D/FmodEventEmitter3D_porte_open").play()

func fermer_portes():
	anim_player_plein.play("close")
	anim_player_vide.play("close")
	await get_tree().create_timer(0.5).timeout
	frigo_vide.get_node("FmodListener3D/FmodEventEmitter3D_porte_close").play()

func manger_dans_frigo():
	# Le joueur mange dans le frigo
	nourriture_mangee = true
	frigo_plein.visible = false
	porte_vestibule_anim_player.play("open")

	
	# Jouer un son via le General_Manager s'il existe
	if get_node_or_null("%General_Manager") != null:
		var son_manger = load("res://sons/manger.ogg") if ResourceLoader.exists("res://sons/manger.ogg") else null
		if son_manger:
			%General_Manager.J
