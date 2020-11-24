extends Spatial

var camrot_h = 0
var camrot_v = 0

const CAM_V_MIN = -55
const CAM_V_MAX = 60
#
#const CAM_H_MIN = -45
#const CAM_H_MAX = 225

const H_SENSITIVITY = 0.1
const V_SENSITIVITY = 0.1
const H_ACCELERATION = 10
const V_ACCELERATION = 10

const ROT_SPEED = 0.15 #reduce this to make the rotation radius larger

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	$h/v/Camera.add_exception(get_parent())
	
	
func _input(event):
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
#		$mouse_control_stay_delay.start()
		camrot_h += -event.relative.x * H_SENSITIVITY
		camrot_v += event.relative.y * V_SENSITIVITY
		
func _physics_process(delta):
	
	camrot_v = clamp(camrot_v, CAM_V_MIN, CAM_V_MAX)
	$h.rotation_degrees.y = lerp($h.rotation_degrees.y, camrot_h, delta * H_ACCELERATION)
	
	$h/v.rotation_degrees.x = lerp($h/v.rotation_degrees.x, camrot_v, delta * V_ACCELERATION)
	
	
	# Capturing/Freeing the cursor --------------------------
	if Input.is_action_just_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	# -------------------------------------------------------
