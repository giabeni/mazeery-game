extends Spatial

const light_env = preload("res://enviroments/LightEnv.tres")
const dark_env = preload("res://enviroments/DarkEnv.tres")

onready var sound_wind: AudioStreamPlayer = $WindFear
onready var sound_whisper: AudioStreamPlayer = $Whispers

onready var wind_timer: Timer = $WindTimer
onready var whisper_timer: Timer = $WhisperTimer

onready var env: WorldEnvironment = $WorldEnvironment

var rng = RandomNumberGenerator.new()

func _ready():
	rng.randomize()


func _on_WindTimer_timeout():
	wind_timer.wait_time = rng.randf_range(60, 100.0)
	sound_wind.play()


func _on_WhisperTimer_timeout():
	whisper_timer.wait_time = rng.randf_range(60, 200.0)
	sound_whisper.play()
	
func set_env(env_mode):
	if env_mode == "light":
		env.set_environment(light_env)
	elif env_mode == "dark":
		env.set_environment(dark_env)
