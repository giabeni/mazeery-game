extends KinematicBody

class_name Player

### CLASSESS ###
const Sword = preload("res://scenes/Sword.tscn")

## SCENES ###

var defeat_scene: PackedScene = preload("res://scenes/Defeat.tscn")
var victory_scene: PackedScene = preload("res://scenes/Victory.tscn")

### CONSTANTS ###
export(float) var GRAVITY = 5
export(float) var WALK_SPEED = 3
export(float) var RUN_SPEED = 8
export(float) var TURN_SENSITIVITY = 0.015

export(float) var ACCELERATION = 6
export(float) var ANGULAR_ACCELERATION = 7
export(float) var AIM_SENSITIVITY = 2

export(float) var ROLL_FORCE = 17
export(float) var JUMP_FORCE = 2

export(float) var MAX_HP = 100

export(float) var MAX_LIGHT_RANGE = 20

export(bool) var debug_vectors = true

### AUX VARIABLES ###
var direction = Vector3.FORWARD
var strafe_dir = Vector3.ZERO
var strafe = Vector3.ZERO
#var aim_turn = 0
var is_jumping = false
var velocity = Vector3.ZERO
var snap = Vector3.DOWN * 2.5
var is_walking = false
var vertical_velocity = 0
var movement_speed = 0
var target_light_range = 0
var h_rot
var slash_timer: SceneTreeTimer

var is_in_pickable_area = false
var pickable_item = null

var next_aim_blend = 0

enum TalismanColor {
	RED,
	ORANGE,
	YELLOW,
	GREEN,
	CYAN,
	BLUE,
	PURPLE
}

### STATE VARIABLES ###
var state = {
	"light_range": 0,
	"light_enabled": true,
	"sprint_fuel": 100,
	"hp": MAX_HP,
	"alive": true,
	"weapon": null,
	"backpack": [null, null, null],
	"active_slot": null,
	"talismans": []
}

var items = {
	"Sword": Sword
}



### NODE VARIABLES ###
onready var anim_tree: AnimationTree = $Mesh/PunkMan/AnimationTree
onready var anim_player: AnimationPlayer = $Mesh/PunkMan/AnimationPlayer
onready var light: OmniLight = $Mesh/Light
onready var skeleton: Skeleton = $Mesh/PunkMan/CharacterArmature/Skeleton
onready var body: MeshInstance = $Mesh/PunkMan/CharacterArmature/Skeleton/Body

onready var footsteps_sound: AudioStreamPlayer3D = $SoundFootsteps
onready var hurt_sound: AudioStreamPlayer3D = $SoundHurt
onready var pickup_sound: AudioStreamPlayer3D = $SoundPickup
onready var die_sound: AudioStreamPlayer = $SoundDeath
onready var win_sound: AudioStreamPlayer = $SoundVictory
onready var left_walk_step_sound: AudioStreamPlayer3D = $Mesh/PunkMan/StepsSounds/LeftWalkStepSound
onready var right_walk_step_sound: AudioStreamPlayer3D = $Mesh/PunkMan/StepsSounds/RightWalkStepSound
onready var left_run_step_sound: AudioStreamPlayer3D = $Mesh/PunkMan/StepsSounds/LeftRunStepSound
onready var right_run_step_sound: AudioStreamPlayer3D = $Mesh/PunkMan/StepsSounds/RightStepSound
onready var timer_dizzy: Timer = $DizzyTimer
onready var light_bar: ColorRect = $UI/VerticalContainer/TopContainer/RightContainer/LightBar
onready var current_light_bar: ColorRect = $UI/VerticalContainer/TopContainer/RightContainer/LightBar/CurrentLightBar
onready var health_bar: ColorRect = $UI/VerticalContainer/TopContainer/RightContainer/HealthBar
onready var current_health_bar: ColorRect = $UI/VerticalContainer/TopContainer/RightContainer/HealthBar/CurrentHealthBar
onready var backpack_slots: Control = $UI/VerticalContainer/BottomContainer/RightContainer/BackpackSlots
onready var talismans_icons: HBoxContainer = $UI/VerticalContainer/TopContainer/LeftContainer/TalismansIcons
onready var fist_attachment: BoneAttachment = $Mesh/PunkMan/CharacterArmature/Skeleton/FistAttachment
onready var blood_spill: Particles = $Mesh/BloodSpill/Particles
onready var pickable_msg: RichTextLabel = $MessagesControl/PickableMessage
onready var aim_slash: CSGPolygon = $Mesh/PunkMan/AimSlash
onready var dead_collision: CollisionShape = $DeadCollisionShape

onready var debug_axes: Spatial = $DebugAxes

func _ready():
	velocity = Vector3.ZERO
	aim_slash.hide()
	footsteps_sound.stop()
	direction = -transform.basis.z
	
#func _input(event):
#	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
#		aim_turn += -event.relative.x * TURN_SENSITIVITY

func _physics_process(delta):
	
	if not state.alive:
		return
		
	if transform.origin.y < -18:
		_die()
		
	
	# Horizontal Translation ----------------------
	if Input.is_action_pressed("move_forward") ||  Input.is_action_pressed("move_backward") ||  Input.is_action_pressed("move_left") ||  Input.is_action_pressed("move_right"):
		h_rot = $Camroot/h.global_transform.basis.get_euler().y
		direction = Vector3(
			Input.get_action_strength("move_left") - Input.get_action_strength("move_right"),
			0,
			Input.get_action_strength("move_forward") - Input.get_action_strength("move_backward"))
		
		strafe_dir = direction
		
		direction = direction.rotated(Vector3.UP, h_rot).normalized()
		debug_axes.rotation.y = h_rot
		
		if Input.is_action_pressed("run") and is_on_floor():
			movement_speed = RUN_SPEED
		else:
			movement_speed = WALK_SPEED
		
	else:
		movement_speed = 0
		strafe_dir = Vector3.ZERO
		
	velocity = lerp(velocity, direction * movement_speed, delta * ACCELERATION)
#	if !direction.dot(velocity) > 0:
#		if velocity.x < 2 && velocity.x > -2:
#			velocity.x = 0
#		if velocity.z < 2 && velocity.z > -2:
#			velocity.z = 0
	
	is_walking = abs(velocity.x) >= 0.01 or abs(velocity.z) >= 0.01
	
	# Equipment ------------------
	if Input.is_action_just_pressed("choose_item_1"):
		_equip_item(1)
	if Input.is_action_just_pressed("choose_item_2"):
		_equip_item(2)
	if Input.is_action_just_pressed("choose_item_3"):
		_equip_item(3)
	if Input.is_action_just_pressed("drop_item") and state.active_slot != null:
		_drop_item(state.active_slot)
		
	
	# Attacking ----------------------
	if Input.is_action_just_pressed("attack"):
		_attack()
			
		
	# Light Toggle ----------------------
	if Input.is_action_just_pressed("light_toggle"):
		state.light_enabled = !state.light_enabled

	# Movement ---------------------------
	
	# Gravity applied only when not on floor
	if not is_on_floor():
		vertical_velocity += GRAVITY * delta
		
	velocity = move_and_slide_with_snap(velocity + Vector3.DOWN * vertical_velocity, snap, Vector3.UP, true, 4, deg2rad(75))
	
	# Hack to stop on slope
	var slides = get_slide_count()
	if slides:
		for i in slides:
			var touched = get_slide_collision(i)
			print("normal: ", touched.normal)
			if is_on_floor() and touched.normal.y < cos(75) and velocity.y < 0 and (velocity.x != 0 or velocity.y != 0):
				vertical_velocity = 0
				
	if Input.is_action_just_pressed("force_die"):
		_die()
	
	strafe = lerp(strafe, strafe_dir, delta * ACCELERATION)
	
#	print('Strafe', strafe, strafe_dir, Vector2(strafe.z, -strafe.x) * velocity.length()/RUN_SPEED)
	anim_tree.set("parameters/Strafe/blend_position", Vector2(strafe.z, -strafe.x) * velocity.length()/RUN_SPEED)
	
	# Gravity and Jumping-------------------------

	if is_on_floor():
#		if velocity.y < 0:
#			velocity.y = 0
		if Input.is_action_just_pressed("jump") and not is_jumping:
			print ("is on floor? ", is_on_floor(), "  is jumping? ", is_jumping)
			anim_tree.set("parameters/toJump/active", true)
			yield(get_tree().create_timer(0.1), "timeout")
			snap = Vector3.ZERO
			vertical_velocity = -JUMP_FORCE
			is_jumping = true
#		print("Vel", velocity)
			
	else:
		is_jumping = false
		
	
	# Aiming
	if Input.is_action_just_pressed("aim"):
		$Camroot.set_mode('AIM')
		_aim()
	if Input.is_action_just_released("aim"):
		_quit_aim()
		$Camroot.set_mode('MOVE')
	
	var cur_aim_blend = anim_tree.get('parameters/AimSlashBlend/blend_amount')
	if cur_aim_blend != next_aim_blend:
		cur_aim_blend = lerp(cur_aim_blend, next_aim_blend, delta * 15)
		anim_tree.set('parameters/AimSlashBlend/blend_amount', cur_aim_blend)
	
	
	# Rotation --------------------------
	var angle_dir_rot = atan2(direction.x, direction.z) - self.rotation.y
	if (Input.is_action_pressed("aim")):
		if cur_aim_blend >= 0.95:
			aim_slash.show()
		h_rot = $Camroot/h.global_transform.basis.get_euler().y
		direction = $Camroot/h.global_transform.basis.z.normalized()
		$Mesh.rotation.y = lerp_angle($Mesh.rotation.y, angle_dir_rot, delta * ANGULAR_ACCELERATION * AIM_SENSITIVITY)
	else:
		$Mesh.rotation.y = lerp_angle($Mesh.rotation.y, angle_dir_rot, delta * ANGULAR_ACCELERATION)

	# Setiing UI feedback -------------------
	_set_lighting(delta)
	_set_hp_bar(delta)	
	
	# Sounds -----------------------
	if Vector2(velocity.x, velocity.z).length() < WALK_SPEED * 0.3:
		_stop_steps_sounds()
		
func _stop_steps_sounds():
	left_walk_step_sound.stop()
	right_walk_step_sound.stop()
	left_run_step_sound.stop()
	right_run_step_sound.stop()
	
func _can_attack():
	if not is_instance_valid(state.weapon):
		return not anim_tree.get("parameters/toSlash/active") and not is_dizzy()
	else:
		return state.weapon.can_attack() and not anim_tree.get("parameters/toSlash/active") and not is_dizzy()

func _aim():
	if is_instance_valid(state.weapon) and state.weapon.metadata.name == 'Sword':
		anim_tree.set('parameters/AimSlashState/current', 0)
		next_aim_blend = 0.99
		
func _quit_aim():
	if is_instance_valid(state.weapon) and state.weapon.metadata.name == 'Sword':
		state.weapon.start_attack()
		anim_tree.set('parameters/AimSlashState/current', 1)
		aim_slash.hide()
		slash_timer = get_tree().create_timer(0.78)
		yield(slash_timer, "timeout")
		state.weapon.stop_attack()
		next_aim_blend = 0
		anim_tree.set('parameters/AimSlashBlend/blend_amount', 0)

func _attack():
	if not _can_attack():
		return

	if not is_instance_valid(state.weapon):
		anim_tree.set("parameters/toPunch/active", true)
	else:
		state.weapon.start_attack()
		anim_tree.set("parameters/toSlash/active", true)
		aim_slash.hide()

func _on_pumpkin_collected(energy):
	target_light_range = light.omni_range + energy
	
func _set_hp_bar(delta):
	if health_bar and current_health_bar:
		var new_bar_width = lerp(current_health_bar.rect_size.x, state.hp * health_bar.rect_size.x / MAX_HP, delta * 10)
		current_health_bar.rect_size.x = clamp(new_bar_width, 0, health_bar.rect_size.x)
	
func _set_lighting(delta):
	light.visible = state.light_enabled
	if (state.light_enabled):
		target_light_range = clamp(target_light_range - 0.001, 0, MAX_LIGHT_RANGE)
	var attenuation =  2 if state.alive else 200
	if (abs(light.omni_range - target_light_range) > 0.00001):
		light.omni_range = lerp(light.omni_range, target_light_range, delta * attenuation)
	
	state.light_range = light.omni_range
	_set_skin_energy(state.light_range / MAX_LIGHT_RANGE if state.light_enabled else 0.1)
	if light_bar and current_light_bar:
		current_light_bar.rect_size.x = lerp(current_light_bar.rect_size.x, state.light_range * light_bar.rect_size.x / MAX_LIGHT_RANGE, delta * 10)

func _set_skin_energy(energy):
	if energy < 0.05:
		energy = 0.05
	var skin_material = (body as MeshInstance).mesh.surface_get_material(1)
	if body and skin_material:
		skin_material.emission_energy = energy
		(body as MeshInstance).mesh.surface_set_material(1, skin_material)

func _equip_item(slot):
	
	if is_in_pickable_area and is_instance_valid(pickable_item):
		if state.backpack[slot - 1] != null:
			_drop_item(slot)
		_pickup_item(slot, pickable_item)
	else:
		var item_metadata = state.backpack[slot - 1]
		if item_metadata == null:
			return
		anim_tree.set("parameters/toEquip/active", true)
		yield(get_tree().create_timer(0.4), "timeout")
		if is_instance_valid(state.weapon) and item_metadata != null:
			if item_metadata.name == state.weapon.metadata.name:
				_unequip_item()
		elif state.backpack[slot - 1] != null:
			_set_active_slot(slot)
			_instantiate_item(item_metadata)
			
func _unequip_item():
	if is_instance_valid(state.weapon):
		state.weapon = null
		_set_active_slot(null)
		fist_attachment.get_child(0).queue_free()
	
		
func _pickup_item(slot, item):
	
	if not "metadata" in item:
		return
		
	anim_tree.set("parameters/toPickUp/active", true)
	yield(get_tree().create_timer(0.4), "timeout")
	pickup_sound.play()
	yield(get_tree().create_timer(0.3), "timeout")
	
	if is_instance_valid(item):
		item.get_parent().remove_child(item)
		_instantiate_item(item.metadata)
		
		state.backpack[slot - 1] = item.metadata
		_set_active_slot(slot)
		_set_slot_icon(slot, item.metadata.icon)

		item.queue_free()
	
		
func _instantiate_item(item_metadata):
	var item_instance = items[item_metadata.type].instance()

	fist_attachment.add_child(item_instance, true)
	state.weapon = item_instance

	if state.weapon.has_method("set_parent"):
		state.weapon.set_parent(self)

func _drop_item(slot):
	if state.backpack[slot - 1] != null:
		var item_metadata = state.backpack[slot - 1]
		
		if is_instance_valid(state.weapon) and state.weapon.metadata.name == item_metadata.name:
			state.weapon = null
			fist_attachment.get_child(0).queue_free()
		
		var item_instance = items[item_metadata.type].instance()
		item_instance.global_transform = fist_attachment.get_child(0).global_transform
		item_instance.scale = item_metadata.level_scale
		get_parent().add_child(item_instance, true)
		state.backpack[slot - 1] = null
		_set_slot_icon(slot, null)
		_set_active_slot(null)
		
func _set_active_slot(slot):
	if slot != null:
		state.active_slot = slot
		var slot_button = backpack_slots.get_node("Slot" + String(slot))
		if is_instance_valid(slot_button):
			slot_button.grab_focus()
	else:
		var slot_button = backpack_slots.get_node("Slot" + String(state.active_slot))
		if is_instance_valid(slot_button):
			slot_button.release_focus()
		state.active_slot = null
	
func _set_slot_icon(slot, icon):
	var slot_button = backpack_slots.get_node("Slot" + String(slot))
	if is_instance_valid(slot_button):
		slot_button.icon = load("res://assets/icons/weapons/" + icon) if icon != null else null
	
func hurt(damage):
	anim_tree.set("parameters/toHurt/active", true)
	hurt_sound.play()
	timer_dizzy.start()
	blood_spill.emitting = true
	state.hp -= damage
	if (state.hp <= 0 and state.alive):
		state.hp = 0
		_die()
		
func _die():
	state.alive = false
	$Camroot.enable_movement = false
	dead_collision.disabled = true
	die_sound.play()
	anim_tree.set("parameters/gameState/current", 1)
	yield(get_tree().create_timer(3), "timeout")
	_go_to_defeat()
	
func _go_to_defeat():
	var defeat = defeat_scene.instance()
	get_tree().root.add_child(defeat)

func is_alive():
	return state.alive
	
func _win():
	win_sound.play()
	state.alive = false
	get_parent_spatial().set_env("light")
	$Camroot.enable_movement = false
	anim_tree.set("parameters/gameState/current", 2)
	yield(get_tree().create_timer(2), "timeout")
	_go_to_victory()
	
func _go_to_victory():
	var win = victory_scene.instance()
	get_tree().root.add_child(win)

func is_dizzy():
	return not timer_dizzy.is_stopped()
	
func on_PickableArea_entered(item):
	is_in_pickable_area = true
	pickable_item = item
	pickable_msg.show()
	
func on_PickableArea_exited(item):
	is_in_pickable_area = false
	pickable_item = null
	pickable_msg.hide()
	
func on_talisman_collected(talisman_color):
	print("Collected ", talisman_color, " ", get_color_name(talisman_color))
	
#	anim_tree.set("parameters/toWin/active", true)	
	var color_name = get_color_name(talisman_color)
	var icon_node_name = "Talisman" + color_name
	var icon_node = talismans_icons.get_node(icon_node_name) as TextureRect
	icon_node.texture = load("res://assets/icons/Gems/" + color_name + "Gem.png")
	
	state.talismans.append(talisman_color)
	if state.talismans.size() == 7:
		_win()

func get_color_name(talisman_color):
	match talisman_color:
		TalismanColor.RED:
			return "Red"
		TalismanColor.ORANGE:
			return "Orange"
		TalismanColor.YELLOW:
			return "Yellow"
		TalismanColor.GREEN:
			return "Green"
		TalismanColor.CYAN:
			return "Cyan"
		TalismanColor.BLUE:
			return "Blue"
		TalismanColor.PURPLE:
			return "Purple"
