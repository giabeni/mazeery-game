extends Spatial

onready var sound_wind: AudioStreamPlayer = $WindFear
onready var sound_whisper: AudioStreamPlayer = $Whispers

onready var wind_timer: Timer = $WindTimer
onready var whisper_timer: Timer = $WhisperTimer

var rng = RandomNumberGenerator.new()

func _ready():
	rng.randomize()


func _on_WindTimer_timeout():
	wind_timer.wait_time = rng.randf_range(20, 100.0)
	sound_wind.play()


func _on_WhisperTimer_timeout():
	whisper_timer.wait_time = rng.randf_range(30, 200.0)
	sound_whisper.play()
