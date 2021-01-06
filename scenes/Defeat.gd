extends Spatial

var menu_scene: PackedScene = null
var level_scene: PackedScene = null

onready var fader = $Fader

func _ready():
	fader.connect("fade_in_finished", self, "on_fade_in_finished")
	fader.connect("fade_out_finished", self, "on_fade_out_finished")
	menu_scene = load("res://scenes/Menu Components/MainMenu.tscn")
	level_scene = load("res://scenes/RootRuins.tscn")

func on_fade_in_finished():
	get_tree().change_scene_to(level_scene)
#	get_tree().reload_current_scene()
	fader.fade_out()

func on_fade_out_finished():
	queue_free()

func _on_RestartButton_pressed():
#	fader.fade_in()
#	get_tree().reload_current_scene()
	get_node("/root/Root").free()
	get_tree().change_scene_to(level_scene)
	queue_free()
	
func _on_QuitGameButton_pressed():
	get_tree().quit()

func _on_MenuButton_pressed():
	get_tree().change_scene_to(menu_scene)
	queue_free()
