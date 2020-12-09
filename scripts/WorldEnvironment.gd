extends WorldEnvironment


# Declare member variables here. Examples:
# var a = 2
# var b = "text"

const ROTATION_SPEED = 0.6

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	self.environment.background_sky_rotation_degrees.y += delta * ROTATION_SPEED
