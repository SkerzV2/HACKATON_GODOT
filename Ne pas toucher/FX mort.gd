extends Node3D

@export var Son_A_La_Mort:AudioStream
@export var VFX_A_La_Mort:GPUParticles3D

func _ready():
	if get_parent() is objet_base:
		get_parent().FX_mort = self

func jouer_son_et_fx():
	if Son_A_La_Mort != null && %General_Manager != null:
		%General_Manager.Joue_Un_Son(Son_A_La_Mort, get_parent().position)
	# TODO lancer particules
