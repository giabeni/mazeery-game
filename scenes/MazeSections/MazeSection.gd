tool
extends Spatial

class_name MazeSection

export(PackedScene) var gem_scene = null
export(PackedScene) var item_scene = null
export(PackedScene) var enemy_scene = null

onready var gem_container: Spatial = $GemContainer
onready var item_container: Spatial = $PumpkinContainter
onready var enemy_container: Spatial = $EnemyContainer

func _ready():
	if (gem_scene):
		var gem: Spatial = gem_scene.instance()
		gem_container.add_child(gem)
		gem.transform.origin = Vector3(0, 0, 0)
		
	if (item_scene):
		var item: Spatial = item_scene.instance()
		item_container.add_child(item)
		item.transform.origin = Vector3(0, 0, 0)
		
	if (enemy_scene):
		enemy_container.transform.origin = Vector3(enemy_container.transform.origin.x, 0, enemy_container.transform.origin.z)
		var enemy: Spatial = enemy_scene.instance()
		enemy_container.add_child(enemy)
		enemy.transform.origin = Vector3(0, 0, 0)
		enemy.scale = Vector3(0.5, 0.5, 0.5)
		
func set_gem(scene, player):
	gem_scene = scene
#	if (_ready()):
#		var gem: Spatial = gem_scene.instance()
#		gem_container.add_child(gem)
#		gem.transform.origin = Vector3(0, 0, 0)
	
func set_item(scene, player):
	item_scene = scene
#	if (_ready()):
#		var item: Spatial = item_scene.instance()
#		item_container.add_child(item)
#		item.transform.origin = Vector3(0, 0, 0)
	
func set_enemy(scene, player):
	enemy_scene = scene
#	if (_ready()):
#		enemy_container.transform.origin = Vector3(enemy_container.transform.origin.x, 0, enemy_container.transform.origin.z)
#		var enemy: Spatial = enemy_scene.instance()
#		enemy_container.add_child(enemy)
#		enemy.transform.origin = Vector3(0, 0, 0)
#		enemy.scale = Vector3(0.5, 0.5, 0.5)
