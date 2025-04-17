# From this tutorial
extends CharacterBody3D

var machine_à_états 

const VITESSE = 4.0
const PORTÉE_ATTAQUE = 2.5

@onready var nav_agent:NavigationAgent3D = $NavigationAgent3D
@onready var anim_tree:AnimationTree = $AnimationTree

func _ready():
	machine_à_états = anim_tree.get("parameters/playback")
	anim_tree.set("parameters/conditions/courrir", true)

func _process(delta):
	velocity = Vector3.ZERO
	
	match machine_à_états.get_current_node():
		"Running_A": 
			# Navigation
			nav_agent.set_target_position(g_vars.joueur.global_transform.origin)
			var next_nav_point = nav_agent.get_next_path_position()
			velocity = (next_nav_point - global_transform.origin).normalized() * VITESSE
			rotation.y = lerp_angle(rotation.y, atan2(-velocity.x, -velocity.z), delta * 10.0)
			#look_at(Vector3(global_position.x + velocity.x, global_position.y, global_position.z + velocity.z), Vector3.UP)
		"1H_Melee_Attack_Slice_Horizontal": 
			look_at(Vector3(g_vars.joueur.global_position.x, global_position.y, g_vars.joueur.global_position.z), Vector3.UP)
	
	
	look_at(Vector3(g_vars.joueur.global_position.x, global_position.y, g_vars.joueur.global_position.z), Vector3.UP)
	
	# Conditions
	anim_tree.set("parameters/conditions/cac_attaque_desarmée", _cible_a_portée())
	#anim_tree.set("parameters/conditions/courrir", !_cible_a_portée())
	
	
	anim_tree.get("parameters/playback")
	
	move_and_slide()

func _cible_a_portée():
	return global_position.distance_to(g_vars.joueur.global_position) < PORTÉE_ATTAQUE

func _coup_terminé():
	if global_position.distance_to(g_vars.joueur.global_position) < PORTÉE_ATTAQUE + 1.0:
		var dir = global_position.direction_to(g_vars.joueur.global_position).inverse()
		g_vars.joueur.coup(dir)
