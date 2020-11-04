extends KinematicBody

const BLACK_EYE_COLOR = "#160202"
const RED_EYE_COLOR = "#ea2525"

const SPEED = 10
const ACCEL = 2
const ANGULAR_ACCEL = 3
const GRAVITY = 20

onready var body: MeshInstance = $SpiderArmature/Skeleton/Cube
onready var eyes_light: OmniLight = $SpiderArmature/Skeleton/Cube/EyesLight
onready var anim_tree: AnimationTree = $AnimationTree
onready var timer_exit_sight: Timer = $ExitTimer

var state = {
	"target": null,
	"sleeping": true,
	"hp": 20
}

var velocity = Vector3.ZERO
var vertical_velocity = 0
var direction = Vector3.ZERO

# Called when the node enters the scene tree for the first time.
func _ready():
	pass
	
func _physics_process(delta):
	
	var cur_idle_walk_blend = anim_tree.get("parameters/IdleWalk/blend_amount")
	if (state.sleeping):
		_close_eyes(delta)
		(anim_tree as AnimationTree).set("paramters/IdleWalk/blend_amount", lerp(cur_idle_walk_blend, 0, delta * 10))
	else:
#		print("Before open eyes", "time = ", OS.get_ticks_msec())
		_open_eyes(delta)
	
	# Gravity and Jumping-------------------------
	if is_on_floor():
		vertical_velocity = 0
	else:
		vertical_velocity += GRAVITY * delta
	
	if state.target:
		var target_position = (state.target as KinematicBody).global_transform.origin
		var self_origin = self.global_transform.origin
		
		direction = (target_position - self_origin).normalized()
		
		var angle = atan2(-direction.x, -direction.z) - self.global_transform.basis.get_euler().y
		self.global_rotate(Vector3.UP, angle)
#		print("\nTargetPosition = ", target_position, "  SelfOrigin = ", self.global_transform.origin)

	if direction.length() > 0:
		velocity = lerp(velocity, direction * SPEED, delta * ACCEL)
		velocity.y = 0
		print("Vertical Vel =   ", vertical_velocity, " Vector =  ", Vector3(0,0,0) + Vector3.DOWN * vertical_velocity)
	
	velocity = move_and_slide(Vector3.DOWN * vertical_velocity, Vector3.UP)
#	translate(velocity)
	print("\nOrigin = ", self.global_transform.origin, "\nVelocity = ", velocity, "\nDirection = ", direction)
	cur_idle_walk_blend =  lerp(cur_idle_walk_blend, velocity.length()/SPEED, delta * 10)
	(anim_tree as AnimationTree).set("paramters/IdleWalk/blend_amount", cur_idle_walk_blend)
		
	
func _close_eyes(delta):
	var eye_material = (body as MeshInstance).get_surface_material(1) as SpatialMaterial
	if body and eye_material:
		eye_material.emission_enabled = false
		eye_material.albedo_color = BLACK_EYE_COLOR
		(body as MeshInstance).mesh.surface_set_material(1, eye_material);
	eyes_light.omni_range = lerp(eyes_light.omni_range, 0, delta * 10)
	eyes_light.light_energy = lerp(eyes_light.light_energy, 0, delta * 10)

func _open_eyes(delta):
#	print("Start open eyes", "time = ", OS.get_ticks_msec())
	var eye_material = (body as MeshInstance).get_surface_material(1) as SpatialMaterial
	if body and eye_material:
		eye_material.emission_enabled = true
		eye_material.albedo_color = RED_EYE_COLOR
		(body as MeshInstance).mesh.surface_set_material(1, eye_material);
#	print("After enable emission open eyes", "time = ", OS.get_ticks_msec())
	
	eyes_light.omni_range = lerp(eyes_light.omni_range, 0.8, delta * 10)
	eyes_light.light_energy = lerp(eyes_light.light_energy, 2, delta * 10)
#	print("After enable light open eyes", "time = ", OS.get_ticks_msec())

func _on_player_sighted(body):
#	print("Body saw by spider, groups: ", body.get_groups(), "time = ", OS.get_ticks_msec())
	if body.is_in_group("Player"):
		state.target = body
		_awake()


func _on_body_exited_sight(body):
	print("Body exited sight of spider, groups: ", body.name)
#	print("Current target ", state.target.get_instance_id() if state.target else "NULL")
	if state.target and state.target.get_instance_id() == body.get_instance_id():
		print("Trigging exit timer...")
		state.target = null
		timer_exit_sight.start(2)
		timer_exit_sight.connect("timeout", self, "_sleep")

func _sleep():
#	print("Sleeping...", "time = ", OS.get_ticks_msec())
	state.sleeping = true
	
func _awake():
#	print("Awaking...", "time = ", OS.get_ticks_msec())
	state.sleeping = false
