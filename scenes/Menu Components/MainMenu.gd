  
extends Spatial

onready var start_button = $CanvasLayer/Fader/Control/VBoxContainer/CenterContainer/VBoxContainer/StartButton
onready var quit_button = $CanvasLayer/Fader/Control/VBoxContainer/CenterContainer/VBoxContainer/QuitButton
onready var fader = $CanvasLayer/Fader

export (PackedScene) var game_scene

func _enter_tree ():
	yield(get_tree().create_timer(1), "timeout")
#	pass

func _ready():
	yield(get_tree().create_timer(4), "timeout")
	start_button.connect("pressed", self, "on_start_pressed")
	quit_button.connect("pressed", self, "on_quit_pressed")
	fader.connect("fade_finished", self, "on_fade_finished")
	

func on_start_pressed():
	fader.fade_in()

func on_quit_pressed():
	get_tree().quit()

func on_fade_finished():
	get_tree().call_deferred("change_scene_to", game_scene)
