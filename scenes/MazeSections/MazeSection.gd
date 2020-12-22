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

func _ready():
	
	section_area.connect("body_entered", self, "_on_Area_body_entered")
	section_area.connect("body_exited", self, "_on_Area_body_exited")
	
	if (gem_scene):
		var gem: Spatial = gem_scene.instance()
		gem.request_ready()
		gem_container.add_child(gem)
		gem.transform.origin = Vector3(0, 0, 0)
		
	if (item_scene):
		var item: Spatial = item_scene.instance()
		item.request_ready()
		item_container.add_child(item)
		item.transform.origin = Vector3(0, 0, 0)
	
		
func set_gem(scene):
	gem_scene = scene
	
func set_item(scene):
	item_scene = scene
	
func set_enemy(scene):
	enemy_scene = scene

func spawn_enemy():
	if (enemy == null and enemy_scene != null):
		enemy_container.transform.origin = Vector3(enemy_container.transform.origin.x, 0, enemy_container.transform.origin.z)
		enemy = enemy_scene.instance()
		enemy.request_ready()
		enemy_container.add_child(enemy)
		enemy.transform.origin = Vector3(0, 0, 0)
		enemy.scale = Vector3(0.4, 0.4, 0.4)
	elif enemy != null:
		enemy.request_ready()
		enemy_container.add_child(enemy)
		
func despawn_enemy():
	if (enemy):
		enemy_container.remove_child(enemy)
	

func _on_Area_body_entered(body: Object):
	if body.is_in_group("Player") and enemy_scene != null:
		print("Spawning spider")
		spawn_enemy()


func _on_Area_body_exited(body):
	if body.is_in_group("Player") and enemy != null and enemy.state.sleeping and not enemy.state.dead:
		print("Despawning spider")
		despawn_enemy()
