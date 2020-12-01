extends Spatial

var camrot_h = 0
var camrot_v = 0

var mode = 'MOVE'
var new_translation
var new_rotation_degrees

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

const MODE_CHANGE_VEL = 8

const MODES = {
	'MOVE': {
		'translation': Vector3(0, 0, 0),
		'rotation': Vector3(0, 0, 0),
	},
	'AIM': {
#		'translation': Vector3(-1.2, 2, 1.6),
#		'rotation': Vector3(0, 15, 0),
		'translation': Vector3(0, 0, 0),
		'rotation': Vector3(0, 0, 0),
	}
}

func set_mode(new_mode):
	mode = new_mode
	new_translation = MODES[new_mode].translation
	new_rotation_degrees = MODES[new_mode].rotation

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	$h/v/Camera.add_exception(get_parent())
	new_translation = MODES[mode].translation
	new_rotation_degrees = MODES[mode].rotation
	
	
func _input(event):
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
#		$mouse_control_stay_delay.start()
		camrot_h += -event.relative.x * H_SENSITIVITY
		camrot_v += event.relative.y * V_SENSITIVITY
		
func _physics_process(delta):
	
	if self.translation != new_translation:
		self.translation = self.translation.linear_interpolate(new_translation, delta * MODE_CHANGE_VEL)
	if self.rotation_degrees != new_rotation_degrees:
		self.rotation_degrees = self.rotation_degrees.linear_interpolate(new_rotation_degrees, delta * MODE_CHANGE_VEL)
	
	camrot_v = clamp(camrot_v, CAM_V_MIN, CAM_V_MAX)
	if mode == 'AIM':
		camrot_v = 0
	
	$h.rotation_degrees.y = lerp($h.rotation_degrees.y, camrot_h, delta * H_ACCELERATION)
	$h/v.rotation_degrees.x = lerp($h/v.rotation_degrees.x, camrot_v, delta * V_ACCELERATION)
	
	
	# Capturing/Freeing the cursor --------------------------
	if Input.is_action_just_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	# -------------------------------------------------------
