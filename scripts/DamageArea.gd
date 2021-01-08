extends Area

class_name DamageArea

export(float) var damage = 5
export(float) var delay = 1

var timer_delay: SceneTreeTimer

func _ready():
	timer_delay = get_tree().create_timer(delay)

func _on_DamageArea_body_entered(body):
	if body.has_method("hurt") and timer_delay.time_left <= 0:
		body.hurt(damage)
		timer_delay = get_tree().create_timer(delay)
