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

onready var anim_player: AnimationPlayer = $AnimationPlayer
onready var idle_sound: AudioStreamPlayer3D = $Sounds/IdleSound
onready var collected_sound: AudioStreamPlayer3D = $Sounds/CollectedSound

func _ready():
	self.connect("body_entered", self, "_on_Gem_body_entered")
	idle_sound.play()

func _disappear(anim_name):
	if (anim_name == "Collected"):
		queue_free()

func _on_Gem_body_entered(body):
	if not body.is_in_group("Player") or not body.has_method("on_talisman_collected"):
		return
	if state.collected:
		return
	
	state.collected = true
	self.monitoring = false
	var prev_origin = self.global_transform.origin
	self.get_parent().remove_child(self)
	body.add_child(self)
	self.owner = body
	self.global_transform.origin = prev_origin
	anim_player.play("Collected")
	anim_player.connect("animation_finished", self, "_disappear")
	collected_sound.play()
	idle_sound.stop()
	
	body.on_talisman_collected(talisman_color)
		
