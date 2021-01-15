extends KinematicBody

export(float) var MAX_SPEED = 8.0
export(float) var MAX_HP = 30.0
export(float) var ACCELERATION = 3.0
export(float) var ANGULAR_ACELLERATION = 3.0
export(float) var ATTACK_DURATION = 0.933
export(float) var WEIGHT = 0.8

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
onready var sight_area: Area = $SightArea
onready var attack_area: Area = $AttackArea
onready var forget_target_timer: Timer = $ForgetTargetTimer
onready var rotate_timer: Timer = $RotateTimer
onready var attack_delay_timer: Timer = $AttackDelayTimer
onready var reborn_timer: Timer = $RebornTimer
onready var hp_bar: HealthBar3D = $SkeletonArmature/HeadBone/HealthBar3D
onready var bone_spill: Particles = $BonesSpill
onready var hurt_sound: AudioStreamPlayer3D = $Sounds/HurtSound
onready var hunf_sound: AudioStreamPlayer3D = $Sounds/HunfSound

func _ready():
	# Set initial spawn point and rotations to retreat
	initial_origin = self.global_transform.origin
	next_rotation = self.rotation.y
	
	# Set parent of weapon to avoid self hurt
	(get_weapon() as Weapon).set_parent(self)
	
	# Set health bar parameters
	hp_bar.set_max_hp(MAX_HP)
	
func _debug():
	
	$Debug/Info.text = " Status = " + str(status)
	$Debug/Info.text += "\n HP = " + str(state.hp)
	$Debug/Info.text += "\n Sleeping = " + str(state.sleeping)
	$Debug/Info.text += "\n Anim Node = " + str(anim_tree["parameters/playback"].get_current_node())
	
	$Debug/Info.text += "\n --- PRESENCE ----"
	$Debug/Info.text += "\n Presence Monitoring = " + str(presence_area.monitoring)
	
	$Debug/Info.text += "\n --- SIGHT ----"
	$Debug/Info.text += "\n Has Target in Sight = " + str(has_target_in_sight)
	$Debug/Info.text += "\n Target = " + (str(target.get_instance_id()) if is_instance_valid(target) else "_")
	$Debug/Info.text += "\n Sight Monitoring = " + str(sight_area.monitoring)
	$Debug/Info.text += "\n Sight Count = " + str(sight_area.get_overlapping_bodies().size() if sight_area.monitorable else "???")
	$Debug/Info.text += "\n Sight Scale = " + str(sight_area.scale)
	$Debug/Info.text += "\n Sight Origin = " + str(sight_area.translation)
	$Debug/Info.text += "\n Sight Visible = " + str(sight_area.visible)
		
func _physics_process(delta):
	_update_status()
	_update_hp_bar()
	_debug()
	
	match status:
		Status.SLEEP:
			presence_area.set_deferred("monitoring", true)
			sight_area.set_deferred("monitoring", false)
			attack_area.set_deferred("monitoring", false)
			alive_collision.set_deferred("disabled", true)
			sleep_collision.set_deferred("disabled", false)

			hp_bar.hide()
			
		Status.IDLE:
			presence_area.set_deferred("monitoring", false)
			sight_area.set_deferred("monitoring", true)
			attack_area.set_deferred("monitoring", false)
			alive_collision.set_deferred("disabled", false)
			sleep_collision.set_deferred("disabled", true)
			hp_bar.hide()
			
			# Hack to restart monitoring of sight area
			if sight_area.scale != Vector3(1, 1, 1):
				yield(get_tree().create_timer(1), "timeout")
				print("Reseting sight scale")
				sight_area.scale = Vector3(1, 1, 1)
			
			_check_for_players_in_sight()
			_rotate_to_look(delta)
			
		Status.FOLLOWING:			
			presence_area.set_deferred("monitoring", false)
			sight_area.set_deferred("monitoring", true)
			attack_area.set_deferred("monitoring", true)
			alive_collision.set_deferred("disabled", false)
			sleep_collision.set_deferred("disabled", true)
			hp_bar.show()
			
			
			_follow_target(delta)
			_check_for_players_in_sight()
			
		Status.RETREATING:
			presence_area.set_deferred("monitoring", false)
			sight_area.set_deferred("monitoring", true)
			attack_area.set_deferred("monitoring", false)
			alive_collision.set_deferred("disabled", false)
			sleep_collision.set_deferred("disabled", true)
			hp_bar.show()
			
			_follow_target(delta)
			_check_for_players_in_sight()
			
		Status.DEAD:
			presence_area.set_deferred("monitoring", false)
			sight_area.set_deferred("monitoring", false)
			attack_area.set_deferred("monitoring", false)
			alive_collision.set_deferred("disabled", true)
			sleep_collision.set_deferred("disabled", false)
			hp_bar.hide()
			
# ==== SLEEP STATUS HANDLERS ===== #

# Detect presence to wake up
func _on_PresenceArea_body_entered(body):
	if (body.is_in_group("Player")):
		call_deferred("_wake_up", body)
		
func _on_PresenceArea_body_exited(body):
	if (body.is_in_group("Player")):
		print("Skeleton: Body exited presence area")
		targets_in_area = targets_in_area - 1
		
func _wake_up(body):
	print("Skeleton: Body entered presence area ", is_instance_valid(target), body.get_instance_id())
	if not is_instance_valid(target) or (is_instance_valid(target) and body.get_instance_id() != target.get_instance_id()):
		targets_in_area = targets_in_area + 1
	# Hack to restart monitoring of sight area
	sight_area.set_deferred("monitoring", true)

	state.sleeping = false
# ==== AWAKE STATUS HANDLERS ===== #

# Look for player to follow
func _on_SightArea_body_entered(body):
	print("_on_SightArea_body_entered")
	call_deferred("_set_target", body, true)

# Lost player of sight
func _on_SightArea_body_exited(body):
	call_deferred("_set_target", body, false)
		
func _set_target(body, entered = true):
	if (body.is_in_group("Player")):
		print("Skeleton: Body " +  ("ENTERED" if entered else "EXITED") + " sight area")
		has_target_in_sight = entered

# Scan area to find player
func _rotate_to_look(delta):
	if rotate_timer.is_stopped():
		rotate_timer.start()
	if self.rotation.y != next_rotation:
		print("Rotating to next_rotation = ", next_rotation, " from current = ", self.rotation.y)
		var angle = lerp_angle(self.rotation.y, next_rotation, delta * ANGULAR_ACELLERATION)
		self.rotation.y = angle
		
func _set_next_rotation():
	next_rotation += deg2rad(90)
	print("Setting new rotation = ", next_rotation)
	
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
		
func _is_away_from_spawn_point():
	return abs((self.global_transform.origin - initial_origin).length()) > 0.2

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
		if direction.length() <= 1.5:
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
		velocity = move_and_slide(velocity + impulse/WEIGHT, Vector3.UP)
		impulse = Vector3.ZERO

# If enemy return to spawn point
func _is_at_retreat_area():
	print ("distance to origin = ", self.global_transform.origin.distance_to(initial_origin))
	return self.global_transform.origin.distance_to(initial_origin) <= 1

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
func hurt(damage, attack_normal = self.global_transform.basis.z):
	hurt_sound.play()
	hunf_sound.play()
	# Seting rotation to opposite of the normal and emitting blood particles
	attack_normal.y = 0
	var particles_forward: Vector3 = -bone_spill.global_transform.basis.z
	particles_forward.y = 0
	bone_spill.global_rotate(Vector3.UP, particles_forward.angle_to(-attack_normal))
	bone_spill.emitting = true
	if not state.alive:
		return

	state.hp -= damage
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
	forget_target_timer.stop()
	rotate_timer.stop()
	attack_delay_timer.stop()
	reborn_timer.stop()
	impulse = Vector3.ZERO

	state.alive = false
	state.sleeping = true
	status = Status.DEAD
	
	reborn_timer.start()
	
	print("DIED")
	
# Calls reborn method after sleeping period
func _on_RebornTimer_timeout():
	call_deferred("_reborn")
	
# Reborn after timer
func _reborn():
	print("Skeleton reborning...")
	if status != Status.DEAD:
		return
	
	state.hp = MAX_HP
	state.alive = true
	status = Status.SLEEP
	
	print(">> Checking if there is body in presence area...")
	# Hack to restart monitoring of presence area
	presence_area.set_deferred("monitoring", true)
	presence_area.scale = Vector3(0.01, 0.01, 0.01)
	sight_area.scale = Vector3(0.01, 0.01, 0.01)
	yield(get_tree().create_timer(1), "timeout")
	presence_area.scale = Vector3(1, 1, 1)
	for body in presence_area.get_overlapping_bodies():
		print(">>>> Body already in presence area")
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
				
			# Go back to spawn point if is away from
			if not _is_at_retreat_area():
				status = Status.RETREATING
				
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
			if state.hp <= 0:
				status = Status.DEAD
				
	_update_animation()
	
	
func has_target():
	return is_instance_valid(target)
	
	
func _update_animation():
	match status:
		Status.SLEEP:
			anim_tree["parameters/Sleep/Seek/seek_position"] = 0
			anim_tree["parameters/conditions/can_spawn"] = not state.sleeping
			anim_tree["parameters/conditions/reborn"] = true			
			anim_tree["parameters/playback"].travel("Sleep")
		Status.IDLE:
			anim_tree["parameters/playback"].travel("Awake")
			anim_tree["parameters/Awake/Moving/blend_amount"] = 0
			anim_tree["parameters/conditions/can_spawn"] = false
			
		Status.FOLLOWING:
			anim_tree["parameters/playback"].travel("Awake")
			anim_tree["parameters/Awake/Moving/blend_amount"] = clamp(velocity.length() / MAX_SPEED, 0, 0.7)
			anim_tree["parameters/conditions/can_spawn"] = false
			
		Status.RETREATING:
			anim_tree["parameters/playback"].travel("Awake")
			anim_tree["parameters/Awake/Moving/blend_amount"] = clamp(velocity.length() / MAX_SPEED, 0, 0.4)
			anim_tree["parameters/conditions/can_spawn"] = false
			
		Status.DEAD:
			if anim_tree["parameters/playback"].get_current_node() != "Die":
				anim_tree["parameters/playback"].travel("Die")
				anim_tree["parameters/Sleep/Seek/seek_position"] = 0
				anim_tree["parameters/conditions/can_spawn"] = false
				anim_tree["parameters/conditions/reborn"] = false
