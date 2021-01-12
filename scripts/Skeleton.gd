extends KinematicBody

export(float) var MAX_SPEED = 8.0
export(float) var MAX_HP = 30.0
export(float) var ACCELERATION = 3.0
export(float) var ANGULAR_ACELLERATION = 3.0
export(float) var ATTACK_DURATION = 0.933

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
	"alive": true,
	"sleeping": true
}

var direction = Vector3.ZERO
var velocity = Vector3.ZERO
var vertical_velocity: float = 0
var next_rotation: float
var impulse: Vector3 = Vector3.ZERO

var initial_origin: Vector3
var targets_in_area = 0
var has_target_in_sight = false
var forgetting_target = false
var attacking = false

onready var anim_tree: AnimationTree = $AnimationTree
onready var anim_player: AnimationPlayer = $AnimationPlayer
onready var weapon = $SkeletonArmature/WeaponBone/Weapon
onready var head = $SkeletonArmature/HeadBone
onready var alive_collision: CollisionShape = $AliveCollision
onready var sleep_collision: CollisionShape = $SleepCollision
onready var presence_area: Area = $PresenceArea
onready var sight_area: Area = $SkeletonArmature/HeadBone/Eyes/SightArea
onready var attack_area: Area = $AttackArea
onready var forget_target_timer: Timer = $ForgetTargetTimer
onready var rotate_timer: Timer = $RotateTimer
onready var attack_delay_timer: Timer = $AttackDelayTimer
onready var reborn_timer: Timer = $RebornTimer
onready var hp_bar: HealthBar3D = $SkeletonArmature/HeadBone/HealthBar3D

func _ready():
	# Set initial spawn point to retreat
	initial_origin = self.global_transform.origin
	
	# Set parent of weapon to avoid self hurt
	(get_weapon() as Weapon).set_parent(self)
	
	# Set health bar parameters
	hp_bar.set_max_hp(MAX_HP)

func _physics_process(delta):
	_update_status()
	_update_animation()
	_update_hp_bar()
	
	match status:
		Status.SLEEP:
			presence_area.monitoring = true
			sight_area.monitoring = false
			attack_area.monitoring = false
			alive_collision.disabled = true
			sleep_collision.disabled = false
			hp_bar.hide()
		Status.IDLE:
			presence_area.monitoring = false
			sight_area.monitoring = true
			attack_area.monitoring = false
			alive_collision.disabled = false
			sleep_collision.disabled = true
			hp_bar.hide()
			
			_check_for_players_in_sight()
			_rotate_to_look(delta)
		Status.FOLLOWING:
			presence_area.monitoring = false
			sight_area.monitoring = true
			attack_area.monitoring = true
			alive_collision.disabled = false
			sleep_collision.disabled = true
			hp_bar.show()
			_follow_target(delta)
			_check_for_players_in_sight()
		Status.RETREATING:
			presence_area.monitoring = false
			sight_area.monitoring = true
			attack_area.monitoring = false
			alive_collision.disabled = false
			sleep_collision.disabled = true
			hp_bar.show()
			
			_follow_target(delta)
			_check_for_players_in_sight()
		Status.DEAD:
			presence_area.monitoring = false
			sight_area.monitoring = false
			attack_area.monitoring = false
			alive_collision.disabled = true
			sleep_collision.disabled = false
			hp_bar.hide()
			
# ==== SLEEP STATUS HANDLERS ===== #

# Detect presence to wake up
func _on_PresenceArea_body_entered(body):
	if (body.is_in_group("Player")):
		print("Skeleton: Body entered presence area")
		if target == null or (target != null and body.get_instance_id() != target.get_instance_id()):
			targets_in_area = targets_in_area + 1
		state.sleeping = false
		
func _on_PresenceArea_body_exited(body):
	if (body.is_in_group("Player")):
		print("Skeleton: Body exited presence area")
		targets_in_area = targets_in_area - 1
		
# ==== AWAKE STATUS HANDLERS ===== #

# Look for player to follow
func _on_SightArea_body_entered(body):
	if (body.is_in_group("Player")):
		print("Skeleton: Body ENTERED sight area")
		has_target_in_sight = true

# Lost player of sight
func _on_SightArea_body_exited(body):
	if (body.is_in_group("Player")):
		print("Skeleton: Body EXITED sight area")
		has_target_in_sight = false

# Scan area to find player
func _rotate_to_look(delta):
	if rotate_timer.is_stopped():
		rotate_timer.start()
	if next_rotation != 0:
		var angle = lerp_angle(self.rotation.y, next_rotation, delta * ANGULAR_ACELLERATION)
		self.rotation.y = angle
		next_rotation = 0
		
func _set_next_rotation():
	next_rotation = deg2rad(90)
	
# Check if can see player	
func _check_for_players_in_sight():
	if has_target_in_sight:
		var players_in_sight_area = sight_area.get_overlapping_bodies()
		if players_in_sight_area.size() == 0:
			print("NO PLAYERS IN SIGHT")
			has_target_in_sight = false
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

# Removes player from target		
func _forget_target():
	print(" Target forgotten")
	if is_instance_valid(target):
		target = null
		forgetting_target = false

# Runs after player
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
		var angular_accel = ANGULAR_ACELLERATION if not attacking else ANGULAR_ACELLERATION * 3
		var angle = lerp_angle(0, angle_to_target, delta * angular_accel)
		self.global_rotate(Vector3.UP, angle)
	else:
		# Stopping if no target
		direction = Vector3.ZERO
	
	# Setting gravity
	if not is_on_floor():
		vertical_velocity += GRAVITY * delta
	else:
		vertical_velocity = 0
		
	# Setting new velocity
	velocity = lerp(velocity, direction * MAX_SPEED, delta * ACCELERATION)
	velocity = move_and_slide(velocity + Vector3.DOWN * vertical_velocity, Vector3.UP)
	
	# Adding impulses
	if impulse != Vector3.ZERO:
		velocity = move_and_slide(velocity + impulse, Vector3.UP)
		impulse = Vector3.ZERO

# If enemy return to spawn point
func _is_at_retreat_area():
	return self.global_transform.origin.distance_to(initial_origin) <= 0.01

# Checks for player in attack area
func _on_AttackArea_body_entered(body):
	print("Body entered attack area")
	if status != Status.FOLLOWING:
		return
	if not body.is_in_group("Player"):
		return
	if not body.state.alive:
		return
	if attack_delay_timer.time_left != 0:
		return
		
	_attack()

# Performs the attack
func _attack():
	print("Attacking!!!")
	var weapon_instance: Weapon = get_weapon()
	attacking = true
	if is_instance_valid(weapon_instance):
		weapon_instance.start_attack()
		var attack_duration_timer = get_tree().create_timer(ATTACK_DURATION)
		attack_duration_timer.connect("timeout", self, "_on_AttackFinished")
		anim_tree["parameters/Awake/Attacking/active"] = true

# Fires when attack finishes
func _on_AttackFinished():
	attacking = false
	(get_weapon() as Weapon).finish_attack()
	attack_delay_timer.start()
	print("Attack delay timer started")

# Try to attack again if delay timer had finished
func _on_AttackDelayTimer_timeout():
	print("Attack delay timer finished")
	for body in attack_area.get_overlapping_bodies():
		_on_AttackArea_body_entered(body)

# Returns the current weapon
func get_weapon():
	return weapon.get_child(0) if weapon.get_child_count() > 0 else null

# Take damage when attacked by player
func hurt(damage):
#	blood_spill.emitting = true
#	hurt_audio.play()
	if not state.alive:
		return

	state.hp -= damage
	# TODO retreat
	print("Skeleton got damage of ", damage, ". => Cur HP = ", state.hp)
	if state.hp <= 0:
		_die()

# Pushing body
func add_impulse(impulse_vector):
	impulse = impulse_vector

# Go to dead state
func _die():
	if not state.alive:
		return
	_forget_target()
	state.alive = false
	state.sleeping = true
	status = Status.DEAD
	if reborn_timer.is_stopped():
		reborn_timer.start()

# Reborn after timer
func _reborn():
	print("Skeleton reborning...")
	if status != Status.DEAD:
		return
	
	status = Status.SLEEP
	state.hp = MAX_HP
	state.alive = true
	
	presence_area.monitoring = true
	for body in presence_area.get_overlapping_bodies():
		_on_PresenceArea_body_entered(body)
	
# Updates health bar
func _update_hp_bar():
	hp_bar.set_current_hp(state.hp)
	
func _update_status():
	match status:
		Status.SLEEP:
			if not state.sleeping:
				status = Status.IDLE
			
		Status.IDLE:
			if has_target():
				print("Skeleton must follow player: IDLE => FOLLOWING")
				status = Status.FOLLOWING
				
			if state.hp <= 0:
				status = Status.DEAD

		Status.FOLLOWING:
			if not has_target():
				print("Skeleton must RETREAT: FOLLOWING => RETREATING")
				status = Status.RETREATING
				
			if state.hp <= 0:
				status = Status.DEAD
		
		Status.RETREATING:
			if has_target():
				print("Skeleton must follow player: REATREATING => FOLLOWING")
				status = Status.FOLLOWING

			elif _is_at_retreat_area():
				status = Status.IDLE
				
			if state.hp <= 0:
				status = Status.DEAD
				
		Status.DEAD:
			pass
	
func has_target():
	return is_instance_valid(target)
	
	
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
			


