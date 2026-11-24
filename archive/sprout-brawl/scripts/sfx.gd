extends Node
## Tiny audio manager: pooled effects with pitch variation + looping music.

const FX := {
	"ui": "res://assets/audio/fx_ui.wav",
	"buy": "res://assets/audio/fx_seed.wav",
	"cross": "res://assets/audio/fx_breed.wav",
	"mutant": "res://assets/audio/fx_mutate.wav",
	"bloom": "res://assets/audio/fx_bloom.wav",
	"win": "res://assets/audio/fx_collect_success.wav",
	"lose": "res://assets/audio/fx_collect_fail.wav",
	"start": "res://assets/audio/fx_encounter.wav",
	"hit": "res://assets/audio/fx_step.wav",
	"swish": "res://assets/audio/fx_grass.wav",
	"pop": "res://assets/audio/fx_observe.wav",
	"back": "res://assets/audio/fx_back.wav",
	"zap": "res://assets/audio/fx_graft.wav",
}
const MUSIC := {"shop": "res://assets/audio/music_garden.wav", "battle": "res://assets/audio/music_wild.wav"}

var players: Array = []
var streams: Dictionary = {}
var music_a: AudioStreamPlayer
var music_b: AudioStreamPlayer
var current_music := ""
var muted := false

func _ready() -> void:
	for k in FX:
		if ResourceLoader.exists(FX[k]): streams[k] = load(FX[k])
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	music_a = AudioStreamPlayer.new()
	music_b = AudioStreamPlayer.new()
	for m in [music_a, music_b]:
		add_child(m)
		m.volume_db = -80
		m.finished.connect(m.play)

func play(name: String, pitch := 1.0, volume := 0.0) -> void:
	if muted or not streams.has(name): return
	for p in players:
		if not p.playing:
			p.stream = streams[name]
			p.pitch_scale = pitch * randf_range(0.94, 1.06)
			p.volume_db = volume - 4.0
			p.play()
			return

func music(name: String) -> void:
	if name == current_music or not ResourceLoader.exists(MUSIC.get(name, "")): return
	current_music = name
	var incoming := music_b if music_a.playing and music_a.volume_db > -40 else music_a
	var outgoing := music_a if incoming == music_b else music_b
	incoming.stream = load(MUSIC[name])
	incoming.volume_db = -40
	incoming.play()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(incoming, "volume_db", -12.0 if not muted else -80.0, 1.2)
	tw.tween_property(outgoing, "volume_db", -80.0, 1.2)

func set_muted(value: bool) -> void:
	muted = value
	for m in [music_a, music_b]:
		if m.stream != null and m.playing and str(m.stream.resource_path) == str(MUSIC.get(current_music, "")):
			m.volume_db = -80.0 if muted else -12.0
