extends Area

onready var anim_player: AnimationPlayer = $AnimationPlayer
onready var sound_ping: AudioStreamPlayer = $SoundPing

signal pumpkin_collected

func _on_body_entered(body):
	if body.is_in_group("Player"):
		print("just hit pumpkin")
		anim_player.play("Collect")
		sound_ping.play()
		(body as Player)._on_pumpkin_collected(3)
#		emit_signal("pumpkin_collected", 3)
		yield(anim_player, "animation_finished")
		self.hide()
		yield(sound_ping, "finished")
		sound_ping.stop()
		self.queue_free()
