extends KinematicBody

const GRAVITY = -24.8
const WALK_SPEED = 4
const RUN_SPEED = 8
const JUMP_SPEED = 8
const ACCEL = 4
const DEACCEL= 10
const MAX_SLOPE_ANGLE = 40

var dir = Vector3()
var vel = Vector3()
var is_running = false
var skeleton: Skeleton

var strafe = Vector2.ZERO
var look_rotation = 0


onready var camera = $CamiraPivot/Camera
onready var rotation_helper = $CamiraPivot

onready var char_model: Spatial = $PunkMan
onready var anim_tree: AnimationTree = $PunkMan/AnimationTree

var MOUSE_SENSITIVITY = 0.1

func _ready():
	skeleton = get_node("PunkMan/CharacterArmature/Skeleton")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta):
	process_input(delta)
	process_movement(delta)

func process_input(delta):

	# ----------------------------------
	# Walking
	var cam_xform = camera.get_global_transform()
	
	var input_movement_vector = Vector2()
	
	if Input.is_action_pressed("move_forward"):
		input_movement_vector.y += 1
	if Input.is_action_pressed("move_backward"):
		input_movement_vector.y -= 0.5
	if Input.is_action_pressed("move_left"):
		input_movement_vector.x -= 1
	if Input.is_action_pressed("move_right"):
		input_movement_vector.x += 1
	if !Input.is_action_pressed("move_forward") and !Input.is_action_pressed("move_backward") and !Input.is_action_pressed("move_left") and !Input.is_action_pressed("move_right"):
		input_movement_vector = Vector2.ZERO

	input_movement_vector = input_movement_vector.normalized()
	
	if input_movement_vector.length() > 0:
		# Basis vectors are already normalized.
		dir += -cam_xform.basis.z * input_movement_vector.y
		dir += cam_xform.basis.x * input_movement_vector.x
	else:
		dir = Vector3.ZERO
	# ----------------------------------

	# ----------------------------------
	# Running
	if Input.is_action_pressed("run"):
		is_running = true
	else:
		is_running = false
	# ----------------------------------

	# ----------------------------------
	# Jumping
	if is_on_floor():
		if Input.is_action_just_pressed("jump"):
			vel.y = JUMP_SPEED
			anim_tree.set("parameters/toJump/active", true)
	# ----------------------------------
	
	# ----------------------------------
	# Attacking
	if Input.is_action_just_pressed("attack"):
		anim_tree.set("parameters/toPunch/active", true)
	# ----------------------------------

	# ----------------------------------
	# Capturing/Freeing the cursor
	if Input.is_action_just_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	# ----------------------------------

func process_movement(delta):
	dir.y = 0
	dir = dir.normalized()

	vel.y += delta * GRAVITY

	var hvel: Vector3 = vel
	hvel.y = 0

	var max_speed = WALK_SPEED
	if (is_running):
		max_speed = RUN_SPEED

	var target = dir
	target *= max_speed
	
	var accel
	if dir.dot(hvel) > 0:
		accel = ACCEL
	else:
		accel = DEACCEL

	hvel = hvel.linear_interpolate(target, accel * delta)
	vel.x = hvel.x
	vel.z = hvel.z
	vel = move_and_slide(vel, Vector3(0, 1, 0), 0.05, 4, deg2rad(MAX_SLOPE_ANGLE))
	
	# Forward/Backward/Left/Right walk/run time scale
	# var dir_anim_speed = anim_tree['parameters/DirSpeed/blend_position']
#	var dir_anim_2d_speed = vel.rotated(Vector3.UP, vel.angle_to(Vector3.FORWARD))
	
	var speed_anim_blend = hvel.length() / RUN_SPEED
	if dir.dot(vel) < 0:
		speed_anim_blend *= -1
#	var new_strafe = Vector2(hvel.project(dir).length(), 0).normalized()
#	strafe = lerp(strafe, new_strafe, delta * accel)
	anim_tree['parameters/DirSpeed2D/blend_position'] = Vector2(speed_anim_blend, 0)
	
	print("Dir", dir)
	print("Vel", vel)
	print("Speed Dir", anim_tree['parameters/DirSpeed2D/blend_position'])
	print("\n")

func _input(event):
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotation_helper.rotate_x(deg2rad(event.relative.y * MOUSE_SENSITIVITY * -1))
		var cam_horizontal_turn = deg2rad(event.relative.x * MOUSE_SENSITIVITY * -1)
		self.rotate_y(cam_horizontal_turn*0.5)
		self.rotation.z = 0
#		self.rotation = Vector3(0, rotation_helper.rotation.y, 0)
#		char_model.rotation.linear_interpolate(rotation_helper.r, otation, 0.5)
#		char_model.look_at(rotation_helper.transform.origin + rotation_helper.transform.basis.z.normalized() * 4 , Vector3.UP)
		
#		look_rotation = lerp_angle(look_rotation, cam_horizontal_turn, 0.6)
#		char_model.rotate_y(cam_horizontal_turn)
#		char_model.rotation.z = 0
#		char_model.rotation.x = 0

		var camera_rot = rotation_helper.rotation_degrees
		camera_rot.x = clamp(camera_rot.x, -70, 70)
		rotation_helper.rotation_degrees = camera_rot
		

func get_facing_vector(obj):
	return Vector3(obj.transform.basis.z)
