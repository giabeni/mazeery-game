extends Area

class_name Talisman

enum TalismanColor {
	RED,
	ORANGE,
	YELLOW,
	GREEN,
	CYAN,
	BLUE,
	PURPLE
}

export(TalismanColor) var talisman_color

var state = {
	"collected": false
}

export var sound_playing = true

onready var anim_player: AnimationPlayer = $AnimationPlayer
onready var idle_sound: AudioStreamPlayer3D = $Sounds/IdleSound
onready var collider: CollisionShape = $CollisionShape
onready var collected_sound: AudioStreamPlayer3D = $Sounds/CollectedSound

func _ready():
	self.connect("body_entered", self, "_on_Gem_body_entered")
	idle_sound.playing = sound_playing

func _disappear(anim_name):
	if (anim_name == "Collected"):
		queue_free()

func _on_Gem_body_entered(body):
	if not body.is_in_group("Player") or not body.has_method("on_talisman_collected"):
		return
	if state.collected:
		return
	
	print("Talisman collected", body.get_instance_id())
	state.collected = true
	collider.disabled = true
	set_deferred("monitoring", false)
	var prev_origin = self.global_transform.origin
	call_deferred("reparent", body, prev_origin)
	anim_player.connect("animation_finished", self, "_disappear")
	anim_player.play("Collected")
	collected_sound.play()
	idle_sound.stop()
	
	(body as Player).on_talisman_collected(talisman_color)

func reparent(body, prev_origin):
	self.get_parent().remove_child(self)
	body.add_child(self)
	self.owner = body
	self.global_transform.origin = prev_origin
