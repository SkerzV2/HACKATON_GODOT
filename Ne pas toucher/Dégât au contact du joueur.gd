extends Node3D

@export var Nombre_Dégats = 0


func _ready():
	if get_parent() is objet_base:
		get_parent().Dégât_au_contact_du_joueur = self
