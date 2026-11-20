extends Node
class_name Soundscape
## Original, quiet botanical music with pooled effects. Mixer preferences are
## independent of the garden save; disabling audio never changes game state.
signal settings_changed()
const DEFAULT_VOLUMES := {"master":0.65,"music":0.45,"ambience":0.40,"effects":0.65}
const CHANNELS := ["master","music","ambience","effects"]
const EFFECTS := ["ui","back","step","grass","encounter","observe","collect_success","collect_fail","seed","breed","graft","mutate","bloom","battle_start","battle_win","battle_lose"]
const EFFECT_GAINS := {"ui":0.68,"back":0.72,"step":0.42,"grass":0.44,"encounter":0.83,"observe":0.75,"collect_success":0.9,"collect_fail":0.75,"seed":0.76,"breed":0.85,"graft":0.78,"mutate":0.8,"bloom":0.9,"battle_start":0.85,"battle_win":0.9,"battle_lose":0.8}
const FX_VOICES: int = 8
var settings_path: String = "user://sound_v1.cfg"
var preview_muted: bool = false
var context: String = "garden"
var biome: String = ""
var _volumes: Dictionary = DEFAULT_VOLUMES.duplicate()
var _muted: bool = false
var _operational: bool = false
var _music: Array[AudioStreamPlayer] = []
var _music_levels: Array[float] = [0.0,0.0]
var _ambience: AudioStreamPlayer
var _effects: Array[AudioStreamPlayer] = []
var _streams: Dictionary = {}
var _last_events: Dictionary = {}
var _transition: Tween
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	_operational = DisplayServer.get_name() != "headless"
	_load_settings()
	_create_players()
	if _can_run():
		_ambience.stream = _stream("ambience_forest",true)
		if _ambience.stream != null: _ambience.play()
		_start_music(context,0.0)
	_apply_volumes()

func _create_players() -> void:
	for i in range(2):
		var player := AudioStreamPlayer.new()
		player.name = "Music%d" % i
		player.volume_db = -80
		player.bus = "Master"
		add_child(player)
		_music.append(player)
	_ambience = AudioStreamPlayer.new()
	_ambience.name = "ForestAmbience"
	_ambience.volume_db = -80
	add_child(_ambience)
	for i in range(FX_VOICES):
		var player := AudioStreamPlayer.new()
		player.name = "Effect%d" % i
		player.volume_db = -80
		player.set_meta("event","")
		player.set_meta("started",0)
		add_child(player)
		_effects.append(player)

func _can_run() -> bool:
	return _operational and not preview_muted and is_inside_tree()

func set_context(next_context: String, next_biome: String = "") -> void:
	if next_context not in ["garden","wild","battle"]: next_context = "garden"
	var different: bool = next_context != context
	context = next_context
	biome = next_biome
	if not _can_run(): return
	if different or not _any_music_playing(): _start_music(context,1.8)
	# These very small changes make wet habitats quieter without repitching music.
	if is_instance_valid(_ambience):
		_ambience.pitch_scale = 0.97 if biome in ["Sporefen","Sunken Glade","Moonfen"] else 1.0
	_apply_volumes()

func _any_music_playing() -> bool:
	for player in _music:
		if player.playing: return true
	return false

func _start_music(next_context: String, seconds: float) -> void:
	if not _can_run() or _music.size() != 2: return
	if is_instance_valid(_transition): _transition.kill()
	var destination: int = -1
	for i in range(_music.size()):
		if _music[i].get_meta("context","") == next_context:
			destination = i
			break
	if destination < 0: destination = 0 if _music_levels[0] <= _music_levels[1] else 1
	var next_player: AudioStreamPlayer = _music[destination]
	if next_player.get_meta("context","") != next_context:
		next_player.stop()
		next_player.stream = _stream("music_"+next_context,true)
		next_player.set_meta("context",next_context)
		_music_levels[destination] = 0.0
	if next_player.stream == null: return
	if not next_player.playing: next_player.play()
	if seconds <= 0:
		for i in range(2):
			_music_levels[i] = 1.0 if i == destination else 0.0
			if i != destination: _music[i].stop()
		_apply_volumes()
		return
	_transition = create_tween().set_parallel(true)
	for i in range(2):
		_transition.tween_method(_set_music_level.bind(i),_music_levels[i],1.0 if i==destination else 0.0,seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_transition.chain().tween_callback(_finish_transition.bind(destination))

func _set_music_level(value: float,index: int) -> void:
	_music_levels[index] = value
	_apply_volumes()

func _finish_transition(destination: int) -> void:
	for i in range(_music.size()):
		if i != destination and _music_levels[i] < 0.001: _music[i].stop()

func play(event: String) -> void:
	if not _can_run() or _muted or event not in EFFECTS: return
	var now: int = Time.get_ticks_msec()
	var limit: int = 120 if event in ["step","grass"] else (40 if event == "ui" else 70)
	if now-int(_last_events.get(event,-10000)) < limit: return
	_last_events[event] = now
	var player: AudioStreamPlayer = _effects[0]
	var found: bool = false
	for voice in _effects:
		if not voice.playing:
			player = voice
			found = true
			break
	if not found:
		for voice in _effects:
			if int(voice.get_meta("started",0)) < int(player.get_meta("started",0)): player = voice
	player.stop()
	player.stream = _stream("fx_"+event,false)
	if player.stream == null: return
	player.set_meta("event",event)
	player.set_meta("started",now)
	player.pitch_scale = _rng.randf_range(0.94,1.06) if event in ["step","grass"] else 1.0
	player.volume_db = _db(_channel_gain("effects")*float(EFFECT_GAINS.get(event,1.0)))
	player.play()

func set_volume(channel: String,value: float) -> void:
	if channel not in CHANNELS or not is_finite(value): return
	_volumes[channel] = clampf(value,0.0,1.0)
	_apply_volumes()
	save_settings()
	settings_changed.emit()

func get_volume(channel: String) -> float:
	return float(_volumes.get(channel,0.0))

func set_muted(value: bool) -> void:
	_muted = value
	_apply_volumes()
	save_settings()
	settings_changed.emit()

func is_muted() -> bool:
	return _muted

func _channel_gain(channel: String) -> float:
	if not _can_run() or _muted: return 0.0
	return float(_volumes.master)*float(_volumes.get(channel,1.0))

func _db(gain: float) -> float:
	return -80.0 if gain <= 0.0001 else maxf(-80.0,linear_to_db(gain))

func _apply_volumes() -> void:
	for i in range(_music.size()): _music[i].volume_db = _db(_channel_gain("music")*_music_levels[i])
	if is_instance_valid(_ambience):
		var habitat_gain: float = 0.75 if context == "garden" else (0.45 if context == "battle" else 1.0)
		_ambience.volume_db = _db(_channel_gain("ambience")*habitat_gain)
	for player in _effects:
		var event: String = str(player.get_meta("event",""))
		player.volume_db = _db(_channel_gain("effects")*float(EFFECT_GAINS.get(event,1.0)))

func _load_settings() -> void:
	var prefs := ConfigFile.new()
	if prefs.load(settings_path) != OK: return
	for channel in CHANNELS:
		var value: Variant = prefs.get_value("audio",channel,DEFAULT_VOLUMES[channel])
		if (value is int or value is float) and is_finite(float(value)): _volumes[channel] = clampf(float(value),0.0,1.0)
	var value: Variant = prefs.get_value("audio","muted",false)
	_muted = value if value is bool else false

func save_settings() -> void:
	# Automated previews remain silent and never write the player's preferences.
	if (not _operational or preview_muted) and settings_path.begins_with("user://"): return
	var prefs := ConfigFile.new()
	for channel in CHANNELS: prefs.set_value("audio",channel,_volumes[channel])
	prefs.set_value("audio","muted",_muted)
	var result: Error = prefs.save(settings_path)
	if result != OK: push_warning("Could not save sound preferences: %s" % error_string(result))

func _stream(asset: String,looped: bool) -> AudioStreamWAV:
	if _streams.has(asset): return _streams[asset]
	var path: String = "res://assets/audio/%s.wav" % asset
	var result: AudioStreamWAV
	# Loading raw PCM also works before the editor's first import. Exported builds
	# fall back to Godot's imported resource remap when the original is omitted.
	if FileAccess.file_exists(path): result = _read_pcm_wav(path)
	if result == null and ResourceLoader.exists(path): result = load(path) as AudioStreamWAV
	if result == null:
		push_warning("Missing sound asset: "+path)
		return null
	if looped:
		result.loop_mode = AudioStreamWAV.LOOP_FORWARD
		result.loop_begin = 0
		result.loop_end = int(result.get_length()*result.mix_rate)
	_streams[asset] = result
	return result

static func _read_pcm_wav(path: String) -> AudioStreamWAV:
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null or file.get_length() < 44: return null
	if file.get_buffer(4).get_string_from_ascii() != "RIFF": return null
	file.get_32()
	if file.get_buffer(4).get_string_from_ascii() != "WAVE": return null
	var channels: int = 0
	var rate: int = 0
	var bits: int = 0
	var encoding: int = 0
	var pcm := PackedByteArray()
	while file.get_position()+8 <= file.get_length():
		var chunk: String = file.get_buffer(4).get_string_from_ascii()
		var length: int = file.get_32()
		var end: int = file.get_position()+length
		if end > file.get_length(): return null
		if chunk == "fmt " and length >= 16:
			encoding = file.get_16()
			channels = file.get_16()
			rate = file.get_32()
			file.get_32()
			file.get_16()
			bits = file.get_16()
		elif chunk == "data": pcm = file.get_buffer(length)
		file.seek(end+(length%2))
	if encoding != 1 or channels not in [1,2] or bits != 16 or rate < 8000 or pcm.is_empty(): return null
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = channels == 2
	stream.data = pcm
	return stream


func _exit_tree() -> void:
	if is_instance_valid(_transition): _transition.kill()
	for player in _music:
		if is_instance_valid(player): player.stop(); player.stream = null
	if is_instance_valid(_ambience): _ambience.stop(); _ambience.stream = null
	for player in _effects:
		if is_instance_valid(player): player.stop(); player.stream = null
	_streams.clear()
