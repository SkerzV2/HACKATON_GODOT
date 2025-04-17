extends Control

@export var Scène_A_Lancer:String = ""


func _on_button_pressed():
	if Scène_A_Lancer != "":
		get_tree().paused = false
		get_tree().change_scene_to_file(Scène_A_Lancer)
