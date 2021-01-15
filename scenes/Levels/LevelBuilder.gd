
extends Spatial

export(Array, PackedScene) var SECTIONS = []
export(Array, PackedScene) var GEMS = []
export(Array, PackedScene) var ENEMIES = []
export(Array, PackedScene) var ITEMS = []

export(PackedScene) var MAZE_SIDE = null
export(PackedScene) var PLAYER_SCENE = null

export(NodePath) var baked_lightmap
export(NodePath) var dir_light

export(int) var X_SECTIONS = 5
export(int) var Z_SECTIONS = 5
export(float) var SECTION_SIZE = 20

export var ENEMY_PROB = 0.4
export var ITEM_PROB = 0.7

var enemies_count = 0
var gems_count = 0


var sections_with_gem = []
var rng = RandomNumberGenerator.new()

var spawn_containers = []

var all_sections = []
var cur_section = null

onready var maze: Spatial = $Maze

func _ready():
	rng.randomize()
	
	_clear_current_maze()
	
	_clamp_maze_size()
	
	_rand_sections_with_gems()
	_build_maze()
	_bake_lights()
	_spawn_player()
	
# Assures that there are at list 7 sections
# Changing the Z_SECTIONS if necessary	
func _clamp_maze_size():
	if (X_SECTIONS * Z_SECTIONS < 7):
		Z_SECTIONS = ceil(7 / X_SECTIONS)
		
func _build_maze():	
	for x in range(0, X_SECTIONS * SECTION_SIZE, SECTION_SIZE):
		print(">>>> x ", x)
		for z in range(0, Z_SECTIONS * SECTION_SIZE, SECTION_SIZE):
			print("z ", z)
			var section_index = rng.randi_range(0, SECTIONS.size() - 1)
			var section: MazeSection = SECTIONS[section_index].instance()
			
			var rotation_index = rng.randi_range(0, 3)
			var rotations = [0, 90, 180, 270]
			var section_rotation = rotations[rotation_index]
			
			if (sections_with_gem.find(Vector2(x/SECTION_SIZE, z/SECTION_SIZE)) != -1):
				print ("ADDING GEM ", x, " ", z)
				section.set_gem(GEMS.pop_front())
				gems_count = gems_count + 1
				
			if (randf() <= ITEM_PROB):
				var item_index = rng.randi_range(0, ITEMS.size() - 1)
				section.set_item(ITEMS[item_index])
				
			if (randf() <= ENEMY_PROB):
				var enemy_index = rng.randi_range(0, ENEMIES.size() - 1)
				section.set_enemy(ENEMIES[enemy_index])
				enemies_count = enemies_count + 1
			
			section.request_ready()
			maze.add_child(section)
			section.name = "Section-" + str(x) + "-" + str(z)
			section.connect("area_reached", self, "on_Area_Reached")
			section.set_position(x, z)
			section.global_transform.origin = Vector3(x, 0, z)
			section.rotation_degrees = Vector3(0, section_rotation, 0)
			all_sections.append(section)
			
			if (z == 0):
				var side: Spatial = MAZE_SIDE.instance()
				side.request_ready()
				maze.add_child(side)
				side.rotation_degrees = Vector3(0, 180, 0)
				side.global_transform.origin = Vector3(x, 0, -SECTION_SIZE/2)
				if side.has_node("SpawnContainer"):
					spawn_containers.push_back(side.get_node("SpawnContainer"))
			elif (z == (Z_SECTIONS - 1) * SECTION_SIZE):
				var side: Spatial = MAZE_SIDE.instance()
				side.request_ready()
				maze.add_child(side)
				side.rotation_degrees = Vector3(0, 0, 0)
				side.global_transform.origin = Vector3(x, 0, Z_SECTIONS * SECTION_SIZE - SECTION_SIZE/2)
				if side.has_node("SpawnContainer"):
					spawn_containers.push_back(side.get_node("SpawnContainer"))
			if (x == 0):
				var side: Spatial = MAZE_SIDE.instance()
				side.request_ready()
				maze.add_child(side)
				side.rotation_degrees = Vector3(0, -90, 0)
				side.global_transform.origin = Vector3(-SECTION_SIZE/2, 0, z)
				if side.has_node("SpawnContainer"):
					spawn_containers.push_back(side.get_node("SpawnContainer"))
			elif (x == (Z_SECTIONS - 1) * SECTION_SIZE):
				var side: Spatial = MAZE_SIDE.instance()
				side.request_ready()
				maze.add_child(side)
				side.rotation_degrees = Vector3(0, 90, 0)
				side.global_transform.origin = Vector3(Z_SECTIONS * SECTION_SIZE - SECTION_SIZE/2, 0, z)
				if side.has_node("SpawnContainer"):
					spawn_containers.push_back(side.get_node("SpawnContainer"))
					
		print ("NUMBER OF ENEMIES = ", enemies_count)	
		print ("NUMBER OF GEMS = ", gems_count)	
		print ("SPAWN_CONTAINERS = ", spawn_containers)	
		
func _spawn_player():
	if (PLAYER_SCENE):
		var spawn_container: Spatial = _get_random_spawn_container()
		spawn_container.rotation.y = -spawn_container.get_parent_spatial().global_transform.basis.get_euler().y
		var player: Spatial = PLAYER_SCENE.instance()
		player.request_ready()
		player.name = "Player"
		player.set_root_node(self.get_parent_spatial())
		spawn_container.add_child(player)
		player.transform.origin = Vector3(0, 0, 0)
#		player.global_scale(Vector3(0.5, 0.5, 0.5))
	else:
		print("WARNING! No Player Scene provided to LevelBuilder")
	
func _rand_sections_with_gems():
	for x in range(0, X_SECTIONS):
		for z in range(0, Z_SECTIONS):
			sections_with_gem.push_back(Vector2(x, z))

	sections_with_gem.shuffle()
	sections_with_gem = sections_with_gem.slice(0, 6)
	
func _get_random_spawn_container():
	spawn_containers.shuffle()
	return spawn_containers[0]
	
func _clear_current_maze():
	for child in get_children():
		if child.name != "Maze":
			remove_child(child)
			child.queue_free()
	for child in maze.get_children():
		if child.name != "Camera":
			maze.remove_child(child)
			child.queue_free()

func _bake_lights():
	if baked_lightmap:
		print("Baking lights")
		var lightmap: BakedLightmap = get_node(baked_lightmap)
		lightmap.bake_extents = Vector3(1, 1, 1) * SECTION_SIZE
		lightmap.bake()
		if dir_light:
			var light: DirectionalLight = get_node(dir_light)
			light.shadow_enabled = false

func on_Area_Reached(x, z):
	
	if (Vector2(x, z) == cur_section):
		return
	cur_section = Vector2(x, z)
	
	print("Area reached = ", str(cur_section))

	var section_node: MazeSection = maze.get_node("Section-" + str(x) + "-" + str(z))
		
	for section in all_sections:
		if (section as MazeSection).position.x in [x - SECTION_SIZE, x, x + SECTION_SIZE] and (section as MazeSection).position.y in [z - SECTION_SIZE, z, z + SECTION_SIZE]:
			section.set_visible(true)
		else:
			section.set_visible(false)
	
	
