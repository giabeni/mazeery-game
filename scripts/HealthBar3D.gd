extends Spatial

class_name HealthBar3D

onready var progress_bar: ProgressBar = $Viewport/ProgressBar

var max_hp = 100
var cur_hp = 100

var target_hp = 100

const BAR_ACCELERATION = 20

func _ready():
	pass
	
func hide():
	if visible:
		visible = false

func show():
	if not visible:
		visible = true
	
func set_max_hp(hp):
	max_hp = hp
	progress_bar.set_max(hp)

func set_current_hp(hp):
	target_hp = hp
	
func _process(delta):
	if cur_hp != target_hp:
		cur_hp = lerp(cur_hp, target_hp, delta * BAR_ACCELERATION)
		
	progress_bar.set_value(cur_hp)
