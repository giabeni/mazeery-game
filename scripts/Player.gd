extends KinematicBody

class_name Player

### AUX VARIABLES ###
var direction = Vector3.FORWARD
var strafe_dir = Vector3.ZERO
var strafe = Vector3.ZERO
var aim_turn = 0
var is_jumping = false
var velocity = Vector3.ZERO
var is_walking = false
var vertical_velocity = 0
var movement_speed = 0
var target_light_range = 0

### STATE VARIABLES ###
var state = {
	"light_range": 0,
	"light_enabled": true,
	"sprint_fuel": 100,
	"hp": 100
}

### CONSTANTS ###
const GRAVITY = 20
const WALK_SPEED = 3
const RUN_SPEED = 8
const TURN_SENSITIVITY = 0.015

const ACCELERATION = 6
const ANGULAR_ACCELERATION = 7

const ROLL_FORCE = 17
const JUMP_FORCE = 200

const MAX_LIGHT_RANGE = 20

### NODE VARIABLES ###
onready var anim_tree: AnimationTree = $Mesh/PunkMan/AnimationTree
onready var light: OmniLight = $Mesh/Light
onready var body: MeshInstance = $Mesh/PunkMan/CharacterArmature/Skeleton/Body
onready var footsteps: AudioStreamPlayer = $SoundFootsteps
onready var timer_light: Timer = $TimerLightUsage
onready var light_bar: ColorRect = $UI/LightBar
onready var current_light_bar: ColorRect = $UI/LightBar/CurrentLightBar

func _ready():
	velocity = Vector3.ZERO

func _input(event):
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		aim_turn += -event.relative.x * TURN_SENSITIVITY

func _physics_process(delta):
	
	# Horizontal Translation ----------------------
	if Input.is_action_pressed("move_forward") ||  Input.is_action_pressed("move_backward") ||  Input.is_action_pressed("move_left") ||  Input.is_action_pressed("move_right"):
		var h_rot = $Camroot/h.global_transform.basis.get_euler().y
		direction = Vector3(
			Input.get_action_strength("move_left") - Input.get_action_strength("move_right"),
			0,
			Input.get_action_strength("move_forward") - Input.get_action_strength("move_backward"))
		
		strafe_dir = direction
		
		direction = direction.rotated(Vector3.UP, h_rot).normalized()
		
		if Input.is_action_pressed("run"):
			movement_speed = RUN_SPEED
		else:
			movement_speed = WALK_SPEED
		
	else:
		movement_speed = 0
		strafe_dir = Vector3.ZERO
	
	velocity = lerp(velocity, direction * movement_speed, delta * ACCELERATION)
	
	is_walking = abs(velocity.x) <= 0.001 and abs(velocity.z) <= 0.001
	
#	print("\nIS WALKING  ", is_walking)
	# Sounds -----------------------
	if is_walking and !footsteps.playing:
		footsteps.play()
	elif footsteps.playing:
		footsteps.stop()
		
	# Gravity and Jumping-------------------------
	if is_on_floor():
		if Input.is_action_just_pressed("jump"):
			vertical_velocity = JUMP_FORCE
			anim_tree.set("parameters/toJump/active", true)
			is_jumping = true
		else:
			vertical_velocity = 0
			
	else:
		vertical_velocity += GRAVITY * delta
		is_jumping = false
	
	
	# Attacking ----------------------
	if Input.is_action_just_pressed("attack"):
		anim_tree.set("parameters/toPunch/active", true)
		
	# Light Toggle ----------------------
	if Input.is_action_just_pressed("light_toggle"):
		state.light_enabled = !state.light_enabled

	velocity = move_and_slide(velocity + Vector3.DOWN * vertical_velocity, Vector3.UP)
	
	strafe = lerp(strafe, strafe_dir, delta * ACCELERATION)
	
#	print('Strafe', strafe, strafe_dir, Vector2(strafe.z, -strafe.x) * velocity.length()/RUN_SPEED)
	anim_tree.set("parameters/Strafe/blend_position", Vector2(strafe.z, -strafe.x) * velocity.length()/RUN_SPEED)
	
	
	# Rotation --------------------------
	$Mesh.rotation.y = lerp_angle($Mesh.rotation.y, atan2(direction.x, direction.z) - rotation.y, delta * ANGULAR_ACCELERATION)

	# Set lighthing -------------------
	_set_lighting(delta)

func _on_pumpkin_collected(energy):
	target_light_range = light.omni_range + energy
	
func _set_lighting(delta):
	light.visible = state.light_enabled
	if (state.light_enabled):
		target_light_range = clamp(target_light_range - 0.001, 0, MAX_LIGHT_RANGE)
	if (abs(light.omni_range - target_light_range) > 0.00001):
		light.omni_range = lerp(light.omni_range, target_light_range, delta * 3)
	
	state.light_range = light.omni_range
	_set_skin_energy(state.light_range / MAX_LIGHT_RANGE if state.light_enabled else 0)
	if light_bar and current_light_bar:
		current_light_bar.rect_size.x = lerp(current_light_bar.rect_size.x, state.light_range * light_bar.rect_size.x / MAX_LIGHT_RANGE, delta * 10)

func _set_skin_energy(energy):
	var skin_material = (body as MeshInstance).mesh.surface_get_material(1)
	if body and skin_material:
		skin_material.emission_energy = energy
		(body as MeshInstance).mesh.surface_set_material(1, skin_material)
		
func hurt(damage):
	anim_tree.set("parameters/toHurt/active", true)
	state.hp -= damage
	print("Player got damage of ", damage, ". => Cur HP = ", state.hp)
