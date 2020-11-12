extends RigidBody

onready var timer_attack_interval: Timer = $AttackIntervalTimer
onready var slash_sound: AudioStreamPlayer3D = $SlashSound

var ATTRIBUTES = {
	"DAMAGE": 10,
	"ATTACK_INTERVAL": 0.6947
}

var state = {
	"attacking": true,
}

var parent: Node
var randomizer = RandomNumberGenerator.new()

func _ready():
	randomizer.randomize()

func start_attack():
	state.attacking = true
	if not slash_sound.playing:
		slash_sound.pitch_scale = randomizer.randf_range(0.8, 1.2)
		slash_sound.play()

func stop_attack():
	state.attacking = false

func set_parent(node):
	parent = node
		
func can_attack():
	return timer_attack_interval.is_stopped()

func _hit_enemies(body: Object):
	if body.has_method("hurt"):
		body.hurt(ATTRIBUTES.DAMAGE)
		state.attacking = false

func _on_Sword_body_entered(body: Object):

	# Only hurts if is attacking and timer is stopped
	if state.attacking and can_attack():
		# Avoid hurting the own parent
		if parent and parent.get_instance_id() == body.get_instance_id():
			return
		
		# If body is attackable, hurt them and start timer
		if body.is_in_group("Enemy") or body.is_in_group("Player"):
			timer_attack_interval.start(ATTRIBUTES.ATTACK_INTERVAL)
			_hit_enemies(body)
