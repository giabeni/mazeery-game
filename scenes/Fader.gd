extends ColorRect

onready var animation_player = $AnimationPlayer

signal fade_finished
signal fade_in_finished
signal fade_out_finished

func _ready():
	animation_player.connect("animation_finished", self, "on_animation_finished")

func fade_in():
	animation_player.play("fade_in")

func fade_out():
	animation_player.play("fade_out")
	
func on_animation_finished(name):
	emit_signal("fade_finished")
	
	if name == "fade_in":
		emit_signal("fade_in_finished")
	
	elif name == "fade_out":
		emit_signal("fade_out_finished")
		

func set_playback_speed(speed):
	animation_player.playback_speed = speed
