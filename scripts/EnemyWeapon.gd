extends RigidBody

class_name Weapon

enum Status {
	HIDDEN,
	EQUIPPED,
	ATTACKING,
	DROPPED
}


var status = Status.EQUIPPED
var parent: Node = null

export var ATTRIBUTES = {
	"DAMAGE": 10
}

onready var pickable_area: Area = $PickableArea

func _physics_process(delta):
	_update_areas()
	
func _update_areas():
	match status:
		Status.DROPPED:
			pickable_area.monitoring = true
		_:
			pickable_area.monitoring = false
			
			
	

func set_parent(node):
	parent = node
		
func can_attack():
	return status == Status.ATTACKING and is_instance_valid(parent)

func start_attack():
	status = Status.ATTACKING
	
func finish_attack():
	status = Status.EQUIPPED
	

func _hit_enemies(body: Object):
	if body.has_method("hurt"):
		body.hurt(ATTRIBUTES.DAMAGE)
		status = Status.EQUIPPED
		

func _on_Axe_Double_body_entered(body: Spatial):
	# Only hurts if is attacking and timer is stopped
	if can_attack():
		# Avoid hurting the own parent
		if parent and parent.get_instance_id() == body.get_instance_id():
			return
		
		# If body is attackable, hurt them and start timer
		if body.is_in_group("Enemy") or body.is_in_group("Player"):
			_hit_enemies(body)
			
		# Push body
		if body.has_method("add_impulse"):
			var normal = self.global_transform.origin.direction_to(body.global_transform.origin) 
			body.add_impulse(normal.normalized() * 30)
