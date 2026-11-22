extends SceneTree
const Sound = preload("res://scripts/soundscape.gd")
var checks: int = 0
var failures: int = 0
var mixer: Node
func _initialize() -> void:
	call_deferred("run")
func check(value: bool,message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func run() -> void:
	mixer = Sound.new()
	mixer.preview_muted = true
	mixer.settings_path = "/tmp/conservatory_audio_%d.cfg" % Time.get_ticks_usec()
	root.add_child(mixer)
	await process_frame
	check(mixer._music.size()==2,"Music transitions use exactly two player voices")
	check(mixer._effects.size()==8,"Effect voices are bounded and reusable")
	check(not mixer._any_music_playing(),"Headless/preview audio does not start music")
	check(not mixer._ambience.playing,"Headless/preview audio does not start ambience")
	for asset in ["music_garden","music_wild","ambience_forest"]:
		var stream: AudioStreamWAV = mixer._stream(asset,true)
		check(stream!=null,"Original loop %s is readable before editor import" % asset)
		if stream == null: continue
		check(stream.stereo and stream.format==AudioStreamWAV.FORMAT_16_BITS,"Loop %s is stereo16-bit PCM" % asset)
		check(stream.mix_rate==22050 and absf(stream.get_length()-64)<.01,"Loop %s retains its full64-second composition" % asset)
		check(stream.loop_mode==AudioStreamWAV.LOOP_FORWARD and stream.loop_end==22050*64,"Loop %s loops across the exact PCM frame range" % asset)
		var peak: int = 0
		var stereo_difference: int = 0
		var discontinuity: int = 0
		var frames: int = stream.data.size()/4
		for i in range(4000):
			var frame: int = (i*7919)%frames
			var left: int = stream.data.decode_s16(frame*4)
			var right: int = stream.data.decode_s16(frame*4+2)
			peak = maxi(peak,maxi(absi(left),absi(right)))
			stereo_difference += absi(left-right)
		for channel in range(2):
			discontinuity = maxi(discontinuity,absi(stream.data.decode_s16(channel*2)-stream.data.decode_s16((frames-1)*4+channel*2)))
		check(peak>100 and peak<16000,"Loop %s contains audible, unclipped signal" % asset)
		check(stereo_difference>10000,"Loop %s has a real stereo field" % asset)
		check(discontinuity<1000,"Loop %s crosses its boundary without an abrupt click (%d)" % [asset,discontinuity])
	for event in Sound.EFFECTS:
		var stream: AudioStreamWAV = mixer._stream("fx_"+event,false)
		check(stream!=null and stream.get_length()>.05 and stream.get_length()<2.1,"Effect %s is a real short PCM clip" % event)
	check(is_equal_approx(mixer.get_volume("master"),.65),"Default mix starts at a quiet master level")
	mixer.set_volume("master",.25)
	mixer.set_volume("music",.7)
	mixer.set_volume("effects",2)
	mixer.set_volume("ambience",-.5)
	mixer.set_muted(true)
	check(mixer.get_volume("effects")==1.0 and mixer.get_volume("ambience")==0.0,"Volume sliders are clamped to their supported range")
	check(mixer.is_muted(),"Mute state is reflected immediately")
	mixer.save_settings()
	var restored = Sound.new()
	restored.settings_path = mixer.settings_path
	restored.preview_muted = true
	root.add_child(restored)
	await process_frame
	check(restored.is_muted() and is_equal_approx(restored.get_volume("master"),.25) and is_equal_approx(restored.get_volume("music"),.7),"Mixer choices persist independently of game saves")
	mixer.set_context("wild","Sporefen")
	mixer.play("collect_success")
	check(mixer.context=="wild" and mixer.biome=="Sporefen" and not mixer._any_music_playing(),"Muted previews keep context while remaining silent")
	check(mixer.get_child_count()==11,"Context and effects do not leak AudioStreamPlayer nodes")
	# Dummy output exercises actual AudioStreamPlayer clocks and crossfades without
	# playing sound on the user's speakers during an automated test.
	if AudioServer.get_driver_name() == "Dummy":
		mixer._operational = true
		mixer.preview_muted = false
		mixer.set_muted(false)
		mixer.set_volume("master",.5)
		mixer.set_context("garden")
		await create_timer(.08).timeout
		check(mixer._any_music_playing(),"Dummy output starts a real looping music player")
		mixer.play("step")
		var first_step_voices: int = 0
		for voice in mixer._effects:
			if voice.playing: first_step_voices+=1
		mixer.play("step")
		var second_step_voices: int = 0
		for voice in mixer._effects:
			if voice.playing: second_step_voices+=1
		check(first_step_voices==1 and second_step_voices==1,"Repeated footstep events are rate limited")
		mixer.play("ui")
		mixer.set_muted(true)
		var silent: bool = true
		for voice in mixer._effects:
			if voice.volume_db > -79: silent = false
		check(silent,"Mute immediately silences effects already playing")
		mixer.set_muted(false)
		mixer.set_context("wild","Sporefen")
		await create_timer(2.0).timeout
		var music_voices: int = 0
		var wilderness_playing: bool = false
		for voice in mixer._music:
			if voice.playing:
				music_voices+=1
				wilderness_playing = voice.get_meta("context","")=="wild"
		check(music_voices==1 and wilderness_playing,"Garden-to-wilderness changes crossfade and stop the previous music voice")
		check(mixer.get_child_count()==11,"Playback transitions keep the voice pool bounded")
	var path: String = mixer.settings_path
	mixer.queue_free()
	restored.queue_free()
	await process_frame
	await create_timer(0.08).timeout
	DirAccess.remove_absolute(path)
	print("AUDIO TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
