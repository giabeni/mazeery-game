tool
extends Spatial

class_name MazeSection

export(PackedScene) var gem_scene = null
export(PackedScene) var item_scene = null
export(PackedScene) var enemy_scene = null

onready var gem_container: Spatial = $GemContainer
onready var item_container: Spatial = $PumpkinContainter
onready var enemy_container: Spatial = $EnemyContainer
onready var section_area: Area = $Area

var gem: Talisman
var enemy: Spatial
var item: Object
export(Vector2) var position: Vector2 = Vector2(0, 0)

signal area_reached

func _enter_tree ():
#	yield(get_tree().create_timer(4), "timeout")
	pass

func _ready():
#	yield(get_tree().create_timer(3), "timeout")
	
	section_area.connect("body_entered", self, "_on_Area_body_entered")
	section_area.connect("body_exited", self, "_on_Area_body_exited")
	
	if (gem_scene):
		call_deferred("_instance_gem", gem_scene)
	if (item_scene):
		call_deferred("_instance_item", item_scene)
		
func set_gem(scene: PackedScene):
	gem_scene = scene
	
func set_item(scene: PackedScene):
	item_scene = scene
	
func set_enemy(scene: PackedScene):
	print(">>> Enemy scene = ", scene.resource_name)
	enemy_scene = scene
	
func set_position(x, z):
	position = Vector2(x, z)
	
func get_position():
	return position
	
func _instance_gem(gem_scene: PackedScene):
	var gem: Spatial = gem_scene.instance()
	gem.request_ready()
	gem_container.add_child(gem)
	gem.transform.origin = Vector3(0, 0, 0)
	gem.scale = Vector3(1.5, 1.5, 1.5)
	
func _instance_item(item_scene: PackedScene):
	var item: Spatial = item_scene.instance()
	item.request_ready()
	item_container.add_child(item)
	item.transform.origin = Vector3(0, 0, 0)
	
func get_neighbor_sections():
	return [
		position + Vector2(1, 0),
		position + Vector2(-1, 0),
		position + Vector2(0, 1),
		position + Vector2(0, -1),
		position + Vector2(1, 1),
		position + Vector2(-1, -1),
		position + Vector2(1, -1),
		position + Vector2(-1, 1),
	]
	

func spawn_enemy():
	if (enemy == null and enemy_scene != null):
		enemy_container.transform.origin = Vector3(enemy_container.transform.origin.x, 0, enemy_container.transform.origin.z)
		enemy = enemy_scene.instance()
		enemy.request_ready()
		enemy_container.add_child(enemy)
		enemy.transform.origin = Vector3(0, 0, 0)
#		enemy.scale = Vector3(0.5, 0.5, 0.5)
	elif enemy != null:
		enemy.request_ready()
		enemy_container.add_child(enemy)
		
func despawn_enemy():
	if (enemy):
		enemy_container.remove_child(enemy)
		
func set_visible(visible):
	self.visible = visible
	$GridMap.visible = visible
	
func _should_despawn_enemy():
	return is_instance_valid(enemy) and "state" in enemy and enemy.state.sleeping and enemy.state.alive
	

func _on_Area_body_entered(body: Object):
	if body.is_in_group("Player"):
		emit_signal("area_reached", position.x, position.y)
		if (enemy_scene != null):
			print("Spawning spider")
			call_deferred("spawn_enemy")

func _on_Area_body_exited(body):
	if body.is_in_group("Player") and _should_despawn_enemy():
		print("Despawning spider")
		call_deferred("despawn_enemy")
