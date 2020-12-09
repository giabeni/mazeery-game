extends Spatial

onready var fader = $Fader

var menu_scene: PackedScene = null

func _ready():
	fader.connect("fade_in_finished", self, "on_fade_in_finished")
	fader.connect("fade_out_finished", self, "on_fade_out_finished")
	menu_scene = load("res://scenes/Menu Components/MainMenu.tscn")

func on_start_pressed():
	fader.fade_in()

func on_fade_in_finished():
	get_tree().reload_current_scene()
#	fader.fade_out()

func on_fade_out_finished():
	queue_free()

func _on_RestartButton_pressed():
	get_tree().reload_current_scene()
	queue_free()
#	fader.fade	queue_free()_in()	

func _on_MenuButton_pressed():
	get_tree().change_scene_to(menu_scene)
	queue_free()


func _on_QuitButton_pressed():
	get_tree().quit()
