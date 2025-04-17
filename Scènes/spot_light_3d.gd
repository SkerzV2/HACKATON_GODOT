extends SpotLight3D

@export var vitesse_changement_luminosite: float = 1.0
@export var luminosite_minimum: float = 0.0
@onready var lumiere = self

func _process(delta):
	if Input.is_action_pressed("Augmenter lux"):
		lumiere.light_energy += vitesse_changement_luminosite * delta
	elif Input.is_action_pressed("Baisser Lux"):
		lumiere.light_energy -= vitesse_changement_luminosite * delta
		if lumiere.light_energy < luminosite_minimum:
			lumiere.light_energy = luminosite_minimum

func _ready():
	# Assurez-vous que les actions d'entrée "augmenter_luminosite" et "diminuer_luminosite" sont définies
	# dans les paramètres du projet (Project Settings -> Input Map).
	# Par défaut, vous devrez les créer et leur assigner les touches W et X respectivement.
	pass
