extends Area

onready var anim_player = $AnimationPlayer

func _ready():
	pass # Replace with function body.



func _on_Gem1_body_entered(body):
	if body.is_in_group("Player"):
		anim_player.play("Collected")
		anim_player.connect("animation_finished", self, "queue_free")
