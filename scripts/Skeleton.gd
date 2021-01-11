extends KinematicBody

export(float) var MAX_SPEED = 8.0
export(float) var MAX_HP = 20.0
export(float) var FOV = 90.0
export(float) var ACCELERATION = 4.0
export(float) var ANGULAR_ACELLERATION = 2.0

const GRAVITY: float = 5.0

enum Status {
	SLEEP,
	IDLE,
	FOLLOWING,
	RETREATING,
	DEAD
}

var status = Status.SLEEP
var target: Spatial = null
var state = {
	"hp": MAX_HP,
	"sleeping": true
}

var direction = Vector3.ZERO
var velocity = Vector3.ZERO
var vertical_velocity: float = 0
var next_rotation: float

var initial_origin: Vector3
var has_target_in_area = false
var forgetting_target = false
var time_left
var stopped

onready var anim_tree: AnimationTree = $AnimationTree
onready var weapon = $SkeletonArmature/WeaponBone/Weapon
onready var head = $SkeletonArmature/HeadBone
onready var presence_area: Area = $PresenceArea
onready var sight_area: Area = $SkeletonArmature/HeadBone/Eyes/SightArea
onready var forget_target_timer: Timer = $ForgetTargetTimer
onready var rotate_timer: Timer = $RotateTimer

func _ready():
	initial_origin = self.global_transform.origin

func _physics_process(delta):
	_update_status()
	_update_animation()
	
	match status:
		Status.SLEEP:
			presence_area.monitoring = true
			sight_area.monitoring = false
		Status.IDLE:
			presence_area.monitoring = false
			sight_area.monitoring = true
			_check_for_players_in_sight()
			_rotate_to_look(delta)
		Status.FOLLOWING:
			presence_area.monitoring = false
			sight_area.monitoring = true
			_follow_target(delta)
			_check_for_players_in_sight()
		Status.RETREATING:
			presence_area.monitoring = false
			sight_area.monitoring = true
			_follow_target(delta)
			_check_for_players_in_sight()
		Status.DEAD:
			presence_area.monitoring = false
			sight_area.monitoring = false
			pass
			
# ==== SLEEP STATUS HANDLERS ===== #
func _on_PresenceArea_body_entered(body):
	if (body.is_in_group("Player")):
		print("Skeleton: Body entered presence area")
		state.sleeping = false
		
# ==== AWAKE STATUS HANDLERS ===== #
func _on_SightArea_body_entered(body):
	if (body.is_in_group("Player")):
		print("Skeleton: Body ENTERED sight area")
		has_target_in_area = true

func _on_SightArea_body_exited(body):
	if (body.is_in_group("Player")):
		print("Skeleton: Body EXITED sight area")
		has_target_in_area = false
	
func _rotate_to_look(delta):
	if rotate_timer.is_stopped():
		rotate_timer.start()
	if next_rotation != 0:
		var angle = lerp_angle(self.rotation.y, next_rotation, delta * ANGULAR_ACELLERATION)
		self.rotation.y = angle
		next_rotation = 0
		
func _set_next_rotation():
	next_rotation = deg2rad(90)
		
func _check_for_players_in_sight():
	if has_target_in_area:
		var players_in_sight_area = sight_area.get_overlapping_bodies()
		if players_in_sight_area.size() == 0:
			print("NO PLAYERS IN SIGHT")
			has_target_in_area = false
			_start_forget_timer()
			return false

		for body in players_in_sight_area:
			if body.is_in_group("Player"):
				var space = get_world().direct_space_state
				var collision = space.intersect_ray(head.global_transform.origin, body.global_transform.origin)
				if collision.has("collider") and collision.collider.is_in_group("Player"):
					var prev_target = target
					
					# Stops forgeting timer
					if forgetting_target:
						print(" Cancelling timer ...")
						forget_target_timer.stop()
						forgetting_target = false
						
					target = collision.collider
					
					if target != prev_target:
						print("Status = ", status, "  Forgetting target? ", forgetting_target, "     Target = ", target)
					
					
				else:
					_start_forget_timer()
		return false
	
# Start timer that skeleton will follow player without seeing him
func _start_forget_timer():
	if not forgetting_target:
		forget_target_timer.start(3)
		forgetting_target = true
		print(" Forgetting target in... ", forget_target_timer.time_left, forget_target_timer.is_stopped())
		
func _forget_target():
	print(" Target forgotten")
	if is_instance_valid(target):
		target = null
		forgetting_target = false

func _follow_target(delta):
	if anim_tree["parameters/playback"].get_current_node() != "Awake":
		return
	
	var self_origin = self.global_transform.origin
	var target_position
	
	if (status == Status.FOLLOWING and is_instance_valid(target)):
		target_position = target.global_transform.origin 
	else:
		target_position = initial_origin

	if not state.sleeping:
		# Setting direction to look
		direction = (target_position - self_origin)
		if direction.length() <= 2:
			direction = Vector3.ZERO
		else:
			direction = direction.normalized()
		
		var angle_to_target = atan2(direction.x, direction.z) - self.global_transform.basis.get_euler().y
		var angle = lerp_angle(0, angle_to_target, delta * ANGULAR_ACELLERATION)
		self.global_rotate(Vector3.UP, angle)
	else:
		# Stoping if no target
		direction = Vector3.ZERO
	
	# Setting gravity
	if not is_on_floor():
		vertical_velocity += GRAVITY * delta
	else:
		vertical_velocity = 0
		
	# Setting new velocity
	velocity = lerp(velocity, direction * MAX_SPEED, delta * ACCELERATION)
#	velocity.y = 0
	velocity = move_and_slide(velocity + Vector3.DOWN * vertical_velocity, Vector3.UP)
	
func set_status(status):
	status = status
	
func _update_status():
	if status == Status.SLEEP:
		if not state.sleeping:
			status = Status.IDLE
			
	elif status == Status.IDLE:
		if has_target():
			print("Skeleton must follow player: IDLE => FOLLOWING")
			status = Status.FOLLOWING
			
		if state.hp <= 0:
			status = Status.DEAD

	elif status == Status.FOLLOWING:
		if not has_target():
			print("Skeleton must RETREAT: FOLLOWING => RETREATING")
			status = Status.RETREATING
			
		if state.hp <= 0:
			status = Status.DEAD
		
	elif status == Status.RETREATING:
		if has_target():
			print("Skeleton must follow player: REATREATING => FOLLOWING")
			status = Status.FOLLOWING

		elif _is_at_retreat_area():
			status = Status.IDLE
			
		if state.hp <= 0:
			status = Status.DEAD
	
func has_target():
	return is_instance_valid(target)
	
func _is_at_retreat_area():
	return self.global_transform.origin.distance_to(initial_origin) <= 0.01
	
func _update_animation():
	match status:
		Status.SLEEP:
			anim_tree["parameters/playback"].travel("Sleep")
			anim_tree["parameters/Sleep/Seek/seek_position"] = 0
		Status.IDLE:
			anim_tree["parameters/playback"].travel("Awake")
			anim_tree["parameters/Awake/Moving/blend_amount"] = 0
			
		Status.FOLLOWING:
			anim_tree["parameters/playback"].travel("Awake")
			anim_tree["parameters/Awake/Moving/blend_amount"] = clamp(velocity.length() / MAX_SPEED, 0, 0.7)
			
		Status.RETREATING:
			anim_tree["parameters/playback"].travel("Awake")
			anim_tree["parameters/Awake/Moving/blend_amount"] = clamp(velocity.length() / MAX_SPEED, 0, 0.4)
						
		Status.DEAD:
			anim_tree["parameters/playback"].travel("Die")
			
