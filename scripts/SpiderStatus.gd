extends RichTextLabel

const Spider = preload("res://scenes/Spider.tscn") 
const Player = preload("res://scenes/Player.tscn") 

var spider: Spider
var player: Player

func _ready():
	spider = get_parent().get_parent()
	player = get_parent().get_parent().get_parent().get_node("Player")


func _process(delta):
	
	if (spider and spider.state):
		self.text = "*** Spider State *** \n\n"
		self.text += "sleeping: \t" + String(spider.state.sleeping) +  "\n"
		self.text += "HP: \t" + String(spider.state.hp) +  "\n"
#		self.text += "target: \t" + spider.state.target.name if spider.state.target else "none" +  "\n"
#		self.text += "Danger: \t" + String(spider.state.players_in_danger) +  "\n"

	if (player and player.state):
		self.text = "\n*** Player State *** \n\n"
		self.text += "HP: \t" + String(player.state.hp) +  "\n"
		self.text += "Steps Playing: \t" + String(player.footsteps_sound.playing) +  "\n"
