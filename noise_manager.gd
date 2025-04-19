# NoiseManager.gd
extends Node

var noise_level = 0.0  # Niveau de bruit actuel (peut-être une valeur entre 0 et 1)
var noise_decrease_rate = 0.4  # Vitesse à laquelle le bruit diminue par seconde
var max_noise_level = 100.0 # Bruit maximum

func _ready():
	print("NoiseManager initialisé!")
	# Utilisez un Timer pour la diminution automatique
	var timer = Timer.new()
	add_child(timer)
	timer.connect("timeout", _on_NoiseDecreaseTimer_timeout) # Correction ici
	timer.start(0.3)  # Diminue le bruit toutes les secondes (ajustez selon vos besoins)

func add_noise(amount):
	noise_level += amount
	noise_level = min(noise_level, max_noise_level)  # S'assurer que le niveau ne dépasse pas le maximum
	print("Niveau de bruit actuel : ", noise_level)
	# Vous pouvez ajouter ici des signaux ou d'autres actions si nécessaire (par exemple, alerter les ennemis)

func _on_NoiseDecreaseTimer_timeout():
	if noise_level > 0:
		noise_level -= noise_decrease_rate
		noise_level = max(noise_level, 0.0)  # S'assurer que le niveau ne devient pas négatif
		print("Niveau de bruit diminué : ", noise_level)
		# Vous pouvez mettre à jour l'interface utilisateur ou déclencher d'autres événements ici

func isMaxNoise ():
	return noise_level == max_noise_level
