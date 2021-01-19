extends Spatial

class_name HealthBar3D

onready var bg_bar: MeshInstance = $BackgroundBar
onready var bar: MeshInstance = $Bar
onready var progress_bar: ProgressBar = $Viewport/ProgressBar

var initial_bar_size
var max_hp = 100
var cur_hp = 100

var target_hp = 100

const BAR_ACCELERATION = 20

func _ready():
	initial_bar_size = bg_bar.mesh.size.x
	
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
	bar.mesh.size.x = initial_bar_size * cur_hp/max_hp
	
	bar.translation = Vector3(-(initial_bar_size - bar.mesh.size.x)/2, 0, 0)
	bg_bar.translation = Vector3(0, 0, 0)
