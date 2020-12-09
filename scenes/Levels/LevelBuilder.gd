
extends Spatial

export(Array, PackedScene) var SECTIONS = []
export(Array, PackedScene) var GEMS = []
export(Array, PackedScene) var ENEMIES = []
export(Array, PackedScene) var ITEMS = []

export(PackedScene) var MAZE_SIDE = null

export(int) var X_SECTIONS = 10
export(int) var Z_SECTIONS = 10
const SECTION_SIZE = 20

export var ENEMY_PROB = 0
export var ITEM_PROB = 0.7

export(NodePath) var player_node
var player: Player


var enemies_count = 0
var gems_count = 0


var sections_with_gem = []
var rng = RandomNumberGenerator.new()

onready var maze: Spatial = $Maze

func _ready():
	rng.randomize()
	
	if (player_node):
		player = get_node(player_node)
	
	# Assures that there are at list 7 sections
	# Changing the Z_SECTIONS if necessary	
	if (X_SECTIONS * Z_SECTIONS < 7):
		Z_SECTIONS = ceil(7 / X_SECTIONS)
		
	_rand_sections_with_gems()
	print ('--- With GEMAS', sections_with_gem)
	
	for x in range(0, X_SECTIONS * SECTION_SIZE, SECTION_SIZE):
		print(">>>> x ", x)
		for z in range(0, Z_SECTIONS * SECTION_SIZE, SECTION_SIZE):
			print("z ", z)
			var section_index = rng.randi_range(0, SECTIONS.size() - 1)
			var section: MazeSection = SECTIONS[section_index].instance()
			
			if (sections_with_gem.find(Vector2(x/SECTION_SIZE, z/SECTION_SIZE)) != -1):
				print ("ADDING GEM ", x, " ", z)
				section.set_gem(GEMS.pop_front(), player)
				gems_count = gems_count + 1
				
			if (randf() <= ITEM_PROB):
				var item_index = rng.randi_range(0, ITEMS.size() - 1)
				section.set_item(ITEMS[item_index], player)
				
			if (randf() <= ENEMY_PROB):
				var enemy_index = rng.randi_range(0, ENEMIES.size() - 1)
				section.set_enemy(ENEMIES[enemy_index], player)
				enemies_count = enemies_count + 1
			
			maze.add_child(section)
			section.global_transform.origin = Vector3(x, 0, z)
			
			if (z == 0):
				var side: Spatial = MAZE_SIDE.instance()
				maze.add_child(side)
				side.rotation_degrees = Vector3(0, 180, 0)
				side.global_transform.origin = Vector3(x, 0, -SECTION_SIZE/2)
			elif (z == (Z_SECTIONS - 1) * SECTION_SIZE):
				var side: Spatial = MAZE_SIDE.instance()
				maze.add_child(side)
				side.rotation_degrees = Vector3(0, 0, 0)
				side.global_transform.origin = Vector3(x, 0, Z_SECTIONS * SECTION_SIZE - SECTION_SIZE/2)
						
			if (x == 0):
				var side: Spatial = MAZE_SIDE.instance()
				maze.add_child(side)
				side.rotation_degrees = Vector3(0, -90, 0)
				side.global_transform.origin = Vector3(-SECTION_SIZE/2, 0, z)
			elif (x == (Z_SECTIONS - 1) * SECTION_SIZE):
				var side: Spatial = MAZE_SIDE.instance()
				maze.add_child(side)
				side.rotation_degrees = Vector3(0, 90, 0)
				side.global_transform.origin = Vector3(Z_SECTIONS * SECTION_SIZE - SECTION_SIZE/2, 0, z)
		
		print ("NUMBER OF ENEMIES", enemies_count)	
		print ("NUMBER OF GEMS", gems_count)	
func _rand_sections_with_gems():
	for x in range(0, X_SECTIONS):
		for z in range(0, Z_SECTIONS):
			sections_with_gem.push_back(Vector2(x, z))

	sections_with_gem.shuffle()
	sections_with_gem = sections_with_gem.slice(0, 6)
