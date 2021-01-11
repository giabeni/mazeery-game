extends KinematicBody

class_name Spider

const Player = preload("res://scenes/Player.tscn")
const HealthBar3D = preload("res://scenes/HealthBar3D.tscn")

const BLACK_EYE_COLOR = "#160202"
const RED_EYE_COLOR = "#ea2525"

const SPEED = 9
const ACCEL = 2
const ANGULAR_ACCEL = 1.4
const GRAVITY = 5

const MAX_HP = 20

const ATTACK = {
	"duration": 0.4,
	"interval": 1,
	"damage": 10
}

onready var body: MeshInstance = $SpiderArmature/Skeleton/Cube
onready var eyes_light: OmniLight = $SpiderArmature/Skeleton/Cube/EyesLight
onready var anim_tree: AnimationTree = $AnimationTree
onready var anim_player: AnimationPlayer = $AnimationPlayer
onready var timer_exit_sight: Timer = $ExitTimer
onready var timer_attack_duration: Timer = $AttackDurationTimer
onready var timer_attack_interval: Timer = $AttackIntervalTimer
onready var timer_dead: Timer = $DeadIdleTimer
onready var timer_dizzy: Timer = $DizzyTimer
onready var blood_spill: Particles = $GreenBloodSpill/Particles
onready var audio_breath: AudioStreamPlayer3D = $BreathAudio
onready var audio_steps: AudioStreamPlayer3D = $StepsAudio
onready var audio_scream: AudioStreamPlayer3D = $ScreamAudio
onready var audio_bite: AudioStreamPlayer3D = $BiteAudio
onready var hurt_audio: AudioStreamPlayer3D = $HurtAudio
onready var death_audio: AudioStreamPlayer3D = $DeathAudio
onready var health_bar = $SpiderArmature/Skeleton/Cube/HealthBar3D
onready var sight_area: Area = $SightArea

var state = {
	"target": null,
	"dead": false,
	"sleeping": true,
	"hp": MAX_HP,
	"players_in_danger": []
}

var has_target_in_area = false

var velocity = Vector3.ZERO
var vertical_velocity = 0
var direction = Vector3.ZERO

# Called when the node enters the scene tree for the first time.
func _ready():
	print("Spider ready, HP is ", state.hp)
	_set_health_bar_max(health_bar, MAX_HP)
	
func _physics_process(delta):
	
	if state.dead:
		return
	
	_check_for_players_in_sight()
	
	if _can_attack():
		_attack()

	var cur_idle_walk_blend = anim_tree.get("parameters/IdleWalk/blend_amount")
	if (state.sleeping):
		_close_eyes(delta)
		health_bar.hide()
		(anim_tree as AnimationTree).set("parameters/IdleWalk/blend_amount", lerp(cur_idle_walk_blend, 0, delta * 10))
		if not audio_breath.playing:
			audio_breath.playing = true
		if audio_scream.playing:
			audio_scream.playing = false
	else:
		_open_eyes(delta)
		health_bar.show()		
		if audio_breath.playing:
			audio_breath.playing = false
		if not audio_scream.playing:
			audio_scream.playing = true
	
	
	vertical_velocity += GRAVITY * delta
	
	if is_instance_valid(state.target) and not state.sleeping:
		var target_position = (state.target as KinematicBody).global_transform.origin
		var self_origin = self.global_transform.origin
		
		direction = (target_position - self_origin).normalized()
		
		var angle = atan2(-direction.x, -direction.z) - self.global_transform.basis.get_euler().y
		self.global_rotate(Vector3.UP, angle)
	else:
		direction = Vector3.ZERO

#	if direction.length() > 0:
	velocity = lerp(velocity, direction * SPEED, delta * ACCEL)
	velocity.y = 0
	
	velocity = move_and_slide_with_snap(velocity + Vector3.DOWN * vertical_velocity, Vector3.ZERO * 100, Vector3.UP)
	
	cur_idle_walk_blend = 2 * velocity.length()/SPEED
	(anim_tree as AnimationTree).set("parameters/IdleWalk/blend_amount", cur_idle_walk_blend)
	
	if (velocity.length() > 0.2 * SPEED and not audio_steps.playing):
		audio_steps.playing = true
		audio_steps.pitch_scale = 0.8 * velocity.length()/SPEED
	else:
		audio_steps.playing = false
	
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

func _check_for_players_in_sight():
	if has_target_in_area:
		var players_in_sight_area = sight_area.get_overlapping_bodies()
#		print("Players in sight", players_in_sight_area)
		if players_in_sight_area.size() == 0:
			_forget_target()
			return

		for target in players_in_sight_area:
			if target.is_in_group("Player"):
				var space = get_world().direct_space_state
				var collision = space.intersect_ray(global_transform.origin, target.global_transform.origin)
				if collision.has("collider") and collision.collider.is_in_group("Player"):
					_set_target(collision.collider)
					_awake()

func _set_target(body):
	if body.is_alive():
		state.target = body
			
func _forget_target():
	if is_instance_valid(state.target) and timer_exit_sight.is_stopped():
#		print("Triggering exit timer...")
		timer_exit_sight.start(2)
		timer_exit_sight.connect("timeout", self, "_sleep")
		
func _can_attack():
	return not state.sleeping and not state.players_in_danger.empty() and state.players_in_danger[0].is_alive()
	
func _attack():
	if not _is_dizzy() and timer_attack_duration.is_stopped() and timer_attack_interval.is_stopped():
#		print("Attacking!")
		anim_tree.set("parameters/Attack/active", true)
		timer_attack_duration.start(ATTACK.duration)
		timer_attack_duration.connect("timeout", self, "_hit_players")
		audio_bite.play()
	
func _hit_players():
#	print("Hurting players!")
	timer_attack_interval.start(ATTACK.interval)
	for obj in state.players_in_danger:
		var player: Player = obj
		player.hurt(ATTACK.damage)

func _is_dizzy():
	return not timer_dizzy.is_stopped()

func _sleep():
	state.target = null
	state.sleeping = true
	
func _awake():
#	print("Awaking...", "time = ", OS.get_ticks_msec())
	state.sleeping = false
	
func hurt(damage):
	blood_spill.emitting = true
	hurt_audio.play()
	state.hp -= damage
	_set_health_bar(health_bar, state.hp)
	
	timer_dizzy.start()
#	print("Spider got damage of ", damage, ". => Cur HP = ", state.hp)
	if state.hp <= 0:
		_die()
		
func _set_health_bar_max(bar: HealthBar3D, max_hp):
	if bar and bar.has_method("set_max_hp"):
		bar.set_max_hp(max_hp)

func _set_health_bar(bar: HealthBar3D, current_hp):
	if bar and bar.has_method("set_current_hp"):	
		bar.set_current_hp(current_hp)
		
func _die():
	if state.dead:
		return
	_sleep()
	_close_eyes(1)
	state.dead = true
	death_audio.play()
	audio_breath.playing = false
	audio_scream.playing = false
	audio_bite.playing = false
	audio_steps.playing = false
	anim_tree.active = false
	health_bar.queue_free()
	anim_player.play("Spider_Death")
	yield(anim_player, "animation_finished")
	anim_player.play("Fade_Out")
	yield(anim_player, "animation_finished")
	queue_free()
	
func _on_AttackArea_body_entered(body):
	if body.is_in_group("Player") and not body in state.players_in_danger:
		print("Player able to atack ", body.name)
		state.players_in_danger.append(body)


func _on_AttackArea_body_exited(body):
	if body in state.players_in_danger:
		state.players_in_danger.erase(body)


func _on_SightArea_body_entered(body):
	print("Body entered sight area")
	if (body.is_in_group("Player")):
		print("Body entered is Player")
		has_target_in_area = true
