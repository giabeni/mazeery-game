extends RichTextLabel

const Spider = preload("res://scenes/Spider.tscn") 

var spider: Spider

func _ready():
	spider = get_parent().get_parent()


func _process(delta):
	
	if (spider and spider.state):
		self.text = "Spider State \n\n"
		self.text += "sleeping: \t" + String(spider.state.sleeping) +  "\n"
		self.text += "target: \t" + spider.state.target.name if spider.state.target else "none" +  "\n"
		self.text += "HP: \t" + String(spider.state.hp) +  "\n"
		self.text += "Danger: \t" + String(spider.state.players_in_danger) +  "\n"
