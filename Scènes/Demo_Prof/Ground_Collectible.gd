extends Area3D

@export var activated: bool = true
@export var is_collected: bool = false

@onready var light_node: OmniLight3D = $OmniLight3D
@onready var visual_node = $VisualNode

# FMOD Event Emitter (add this node in the scene)
# var fmod_emitter_ground_collect

# Appelé lorsque le nœud entre dans l'arbre de scène
func _ready():
	# Ajout au groupe des collectibles au sol pour être trouvé par le joueur
	add_to_group("ground_collectibles")
	
	# Connexion du signal pour le corps entré
	connect("body_entered", Callable(self, "_on_body_entered"))
	
	# Définir la visibilité initiale
	set_visibility(activated)

# func initialize_fmod_sound():
# 	# Look for an existing FMOD emitter
# 	fmod_emitter_ground_collect = get_node_or_null("FmodEventEmitter3D_ground_collect")
	
# 	# If not found, create one
# 	if fmod_emitter_ground_collect == null:
# 		fmod_emitter_ground_collect = FmodEventEmitter3D.new()
# 		fmod_emitter_ground_collect.name = "FmodEventEmitter3D_ground_collect"
# 		# fmod_emitter_ground_collect.event_name = "event:/GroundCollect"
# 		add_child(fmod_emitter_ground_collect)
# 		print("Created FMOD emitter for ground collectible")

# Appelé à chaque frame. 'delta' est le temps écoulé depuis la frame précédente
func _process(delta):
	# Faire clignoter la lumière pour attirer l'attention
	if light_node != null and activated and !is_collected:
		var pulse = (sin(Time.get_ticks_msec() * 0.003) + 1.0) / 2.0  # Valeur entre 0 et 1
		light_node.light_energy = 1.0 + (pulse * 3.0)  # Varie entre 1 et 4
		
		# Optionnel: Mettre à l'échelle légèrement le nœud visuel
		if visual_node != null:
			var scale_factor = 1.0 + (pulse * 0.1)  # Varie entre 1.0 et 1.1
			visual_node.scale = Vector3(scale_factor, scale_factor, scale_factor)

func set_visibility(is_visible):
	if is_visible and !is_collected:
		self.show()
	else:
		self.hide()

func _on_body_entered(body):
	if body.name == "JoueurDemo" and !is_collected:
		collect(body)

func collect(body):
	# Marquer comme collecté
	is_collected = true
	
	# Appeler également la méthode du joueur pour la compatibilité
	if body.has_method("Play_Ground_Collectible_Sound"):
		body.Play_Ground_Collectible_Sound()
	
	# Effet visuel pour la collecte
	if light_node != null:
		var tween = create_tween()
		tween.tween_property(light_node, "light_energy", 10.0, 0.2)
		tween.tween_property(light_node, "light_energy", 0.0, 0.3)
	
	if visual_node != null:
		var tween = create_tween()
		tween.tween_property(visual_node, "scale", Vector3(2.0, 2.0, 2.0), 0.3)
	
	# Suppression de la scène après l'achèvement de l'effet
	await get_tree().create_timer(0.5).timeout
	set_visibility(false) 
