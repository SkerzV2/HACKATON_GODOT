extends Control

# Chemin vers la scène principale du jeu
@export var scene_jeu_path: String = "res://Scènes/Votre_Scene_Dupliquer.tscn"

func _ready():
	# Centrer la fenêtre si nécessaire
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN:
		var screen_size = DisplayServer.screen_get_size()
		var window_size = DisplayServer.window_get_size()
		DisplayServer.window_set_position(screen_size/2 - window_size/2)

func _on_bouton_jouer_pressed():
	# Charger la scène principale du jeu
	get_tree().change_scene_to_file(scene_jeu_path)

func _on_bouton_quitter_pressed():
	# Fermer le jeu
	get_tree().quit() 
