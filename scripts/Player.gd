extends KinematicBody

class_name Player

### CLASSESS ###
const Sword = preload("res://scenes/Sword.tscn")

### CONSTANTS ###
const GRAVITY = 20
const WALK_SPEED = 3
const RUN_SPEED = 8
const TURN_SENSITIVITY = 0.015

const ACCELERATION = 6
const ANGULAR_ACCELERATION = 7

const ROLL_FORCE = 17
const JUMP_FORCE = 200

const MAX_HP = 100

const MAX_LIGHT_RANGE = 20

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

var is_in_pickable_area = false
var pickable_item = null

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
onready var light: OmniLight = $Mesh/Light
onready var skeleton: Skeleton = $Mesh/PunkMan/CharacterArmature/Skeleton
onready var body: MeshInstance = $Mesh/PunkMan/CharacterArmature/Skeleton/Body
onready var footsteps_sound: AudioStreamPlayer3D = $SoundFootsteps
onready var hurt_sound: AudioStreamPlayer3D = $SoundHurt
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
	
	is_walking = abs(velocity.x) >= 0.001 or abs(velocity.z) >= 0.001
	
		
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

	velocity = move_and_slide(velocity + Vector3.DOWN * vertical_velocity, Vector3.UP)
	
	strafe = lerp(strafe, strafe_dir, delta * ACCELERATION)
	
#	print('Strafe', strafe, strafe_dir, Vector2(strafe.z, -strafe.x) * velocity.length()/RUN_SPEED)
	anim_tree.set("parameters/Strafe/blend_position", Vector2(strafe.z, -strafe.x) * velocity.length()/RUN_SPEED)
	
	
	# Rotation --------------------------
	$Mesh.rotation.y = lerp_angle($Mesh.rotation.y, atan2(direction.x, direction.z) - rotation.y, delta * ANGULAR_ACCELERATION)

	# Setiing UI feedback -------------------
	_set_lighting(delta)
	_set_hp_bar(delta)	
	
	# Sounds -----------------------
	if velocity.length() > WALK_SPEED:
		if not footsteps_sound.playing:
			footsteps_sound.playing = true
	else:
		footsteps_sound.playing = false
	
func _can_attack():
	if not is_instance_valid(state.weapon):
		return not anim_tree.get("parameters/toSlash/active") and not is_dizzy()
	else:
		return state.weapon.can_attack() and not anim_tree.get("parameters/toSlash/active") and not is_dizzy()

func _attack():
	if not _can_attack():
		return

	if not is_instance_valid(state.weapon):
		anim_tree.set("parameters/toPunch/active", true)
	else:
		state.weapon.start_attack()
		anim_tree.set("parameters/toSlash/active", true)

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
	yield(get_tree().create_timer(0.7), "timeout")
	
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
#	print("Player got damage of ", damage, ". => Cur HP = ", state.hp)

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
	
	anim_tree.set("parameters/toWin/active", true)
	
	var color_name = get_color_name(talisman_color)
	var icon_node_name = "Talisman" + color_name
	var icon_node = talismans_icons.get_node(icon_node_name) as TextureRect
	icon_node.texture = load("res://assets/icons/Gems/" + color_name + "Gem.png")
	
	state.talismans.append(talisman_color)
	if state.talismans.size() == 7:
		# @TODO trigger vicotry
		print("VICTORY!!!!!")

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
