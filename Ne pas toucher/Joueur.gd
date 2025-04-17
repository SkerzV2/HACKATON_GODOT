extends CharacterBody3D

# Based on this tutorial: https://www.youtube.com/watch?v=A3HLeyaBCq4

var speed
const WALK_SPEED = 5.0
const SPRINT_SPEED = 8.0
const JUMP_VELOCITY = 4.5
const SENSIBILITE = 0.003

# Head bob variable
const BOB_FREQ = 2.0
const BOB_AMPLITUDE = 0.08
var time_bob = 0.0

# FOV variables
const BASE_FOV = 75.0
const FOV_CHANGE = 1.5
const RECUL_COUP = 1.0


var gravity = 9.8

@onready var tête = $"Tête"
@onready var camera = $"Tête/Camera3D"
@onready var rect_dégât = $"Interface_Joueur/rect_dégât"

func _init():
	g_vars.joueur = self

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event):
	if event is InputEventMouseMotion:
		tête.rotate_y(-event.relative.x * SENSIBILITE)
		camera.rotate_x(-event.relative.y * SENSIBILITE)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-70), deg_to_rad(60))

func _physics_process(delta):
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle jump.
	if Input.is_action_just_pressed("Sauter") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	
	# Handle sprint.
	if Input.is_action_pressed("Courir"):
		speed = SPRINT_SPEED
	else:
		speed = WALK_SPEED

	# Get the input direction and handle the movement/deceleration.
	var input_dir = Input.get_vector("Gauche", "Droite", "Avancer", "Reculer")
	var direction = (tête.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	# if/else is_on_floor for jump inertia, avoid stopping abruptly in the middle of jump when releasing move keys
	if is_on_floor():
		if direction:
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
		else:
			velocity.x = 0.0
			velocity.z = 0.0
	else: # play with the last value to change inertia
		velocity.x = lerp(velocity.x, direction.x * speed, delta * 3.0)
		velocity.z = lerp(velocity.z, direction.z * speed, delta * 3.0)
	
	# Head bob feature:
	time_bob += delta * velocity.length() * float(is_on_floor())
	camera.transform.origin = _headbob(time_bob)
	
	# FOV
	var velocity_clamped = clamp(velocity.length(), 0.5, SPRINT_SPEED * 2)
	var target_fov = BASE_FOV + FOV_CHANGE * velocity_clamped
	camera.fov = lerp(camera.fov, target_fov, delta * 8.0)

	move_and_slide()

func _headbob(time) -> Vector3:
	var pos = Vector3.ZERO
	pos.y = sin(time * BOB_FREQ) * BOB_AMPLITUDE
	pos.x = cos(time * BOB_FREQ / 2) * BOB_AMPLITUDE
	return pos

func coup(dir):
	effets_dégâts()
	velocity += dir * RECUL_COUP

func effets_dégâts():
	rect_dégât.visible = true
	await get_tree().create_timer(0.2).timeout
	rect_dégât.visible = false
