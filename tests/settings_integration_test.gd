extends SceneTree
## Settings exercise the real controls while keeping both the garden archive and
## the player's actual mixer/language preferences untouched.
const Garden = preload("res://scripts/garden.gd")
const State = preload("res://scripts/garden_state.gd")
const Locale = preload("res://scripts/localization.gd")
const Sound = preload("res://scripts/soundscape.gd")
var game: Control
var checks: int = 0
var failures: int = 0
var save_path: String
var canonical_names: Dictionary = {}
var canonical_ids: Array = []
var canonical_genes: Dictionary = {}
var actual_sound_before: Dictionary
var actual_language_before: Dictionary

func _initialize() -> void:
	call_deferred("run")

func check(value: bool,message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("SETTINGS: "+message)

func settle() -> void:
	for i in range(6): await process_frame

func file_snapshot(path: String) -> Dictionary:
	return {"exists":FileAccess.file_exists(path),"contents":FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()}

func within(rect: Rect2,bounds: Rect2) -> bool:
	return rect.position.x>=bounds.position.x-2 and rect.position.y>=bounds.position.y-2 and rect.end.x<=bounds.end.x+2 and rect.end.y<=bounds.end.y+2

func find_sliders(node: Node,result: Dictionary) -> void:
	if node is HSlider and node.has_meta("sound_channel"): result[str(node.get_meta("sound_channel"))] = node
	for child in node.get_children(): find_sliders(child,result)

func find_mute(node: Node) -> CheckButton:
	if node is CheckButton: return node
	for child in node.get_children():
		var found: CheckButton = find_mute(child)
		if found != null: return found
	return null

func find_edit(node: Node) -> LineEdit:
	if node is LineEdit: return node
	for child in node.get_children():
		var found: LineEdit = find_edit(child)
		if found != null: return found
	return null

func horizontal_overflow(node: Node,bounds: Rect2,result: Array[String]) -> void:
	if node is Control and node.is_visible_in_tree():
		var rect: Rect2 = node.get_global_rect()
		if rect.position.x<bounds.position.x-2 or rect.end.x>bounds.end.x+2:
			var description: String = node.get_class()
			if node is Label or node is Button: description += " '%s'" % str(node.text).left(35)
			result.append(description+" "+str(rect))
		if node is ScrollContainer and node.horizontal_scroll_mode!=ScrollContainer.SCROLL_MODE_DISABLED: return
	for child in node.get_children(): horizontal_overflow(child,bounds,result)

func check_modal(context: String) -> void:
	var panel: Control = game.modal.get_node("Panel")
	check(within(panel.get_global_rect(),root.get_visible_rect()),context+" fits the visible canvas")
	var overflow: Array[String] = []
	horizontal_overflow(panel,panel.get_global_rect(),overflow)
	check(overflow.is_empty(),context+" has no horizontal overflow: "+"; ".join(overflow.slice(0,5)))

func check_canonical(context: String) -> void:
	check(game.state.plant_order==canonical_ids,context+" keeps exact plant IDs and tray order")
	var names_ok: bool = true
	var genes_ok: bool = true
	for id in canonical_ids:
		if game.state.plants[id].name!=canonical_names[id]: names_ok = false
		if game.state.plants[id].genes!=canonical_genes[id]: genes_ok = false
	check(names_ok,context+" keeps saved plant names canonical")
	check(genes_ok,context+" keeps gene enums canonical")

func run() -> void:
	actual_sound_before = file_snapshot("user://sound_v1.cfg")
	actual_language_before = file_snapshot("user://language_v1.cfg")
	Locale.set_language("en")
	root.size = Vector2i(1440,1000)
	game = Garden.new()
	save_path = "/tmp/conservatory_settings_integration_%d.json" % Time.get_ticks_usec()
	game.state = State.new(save_path)
	root.add_child(game)
	game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await settle()
	canonical_ids = game.state.plant_order.duplicate()
	for id in canonical_ids:
		canonical_names[id] = game.state.plants[id].name
		canonical_genes[id] = game.state.plants[id].genes.duplicate(true)
	check(game.soundscape.preview_muted,"A test garden uses silent preview audio")
	check(game.soundscape.settings_path!="user://sound_v1.cfg" and game.soundscape.settings_path.begins_with("/tmp/"),"Mixer preferences use the isolated temporary test path")
	check(game.soundscape.context=="garden" and not game.soundscape._any_music_playing(),"The home audio context is selected without playing during tests")
	game._open_settings()
	await settle()
	check_modal("Desktop sound/language settings")
	var sliders: Dictionary = {}
	find_sliders(game.modal,sliders)
	check(sliders.size()==4,"Settings expose four independent mixer sliders")
	var desired: Dictionary = {"master":12.0,"music":23.0,"ambience":34.0,"effects":45.0}
	for channel in desired:
		if sliders.has(channel): sliders[channel].value = desired[channel]
	for channel in desired:
		check(is_equal_approx(game.soundscape.get_volume(channel),desired[channel]/100.0),"The %s slider updates only its own mixer channel" % channel)
	var mute: CheckButton = find_mute(game.modal)
	check(mute!=null,"Settings expose a real mute toggle")
	if mute != null:
		mute.button_pressed = true
		check(game.soundscape.is_muted(),"The mute toggle mutes all sound")
		mute.button_pressed = false
		check(not game.soundscape.is_muted(),"The mute toggle restores the prior channel levels")
	game.soundscape.save_settings()
	var restored_sound = Sound.new()
	restored_sound.preview_muted = true
	restored_sound.settings_path = game.soundscape.settings_path
	root.add_child(restored_sound)
	await process_frame
	for channel in desired: check(is_equal_approx(restored_sound.get_volume(channel),desired[channel]/100.0),"%s volume persists independently of the garden archive" % channel)
	restored_sound.queue_free()
	check(game.language_picker.get_item_metadata(0)=="en" and game.language_picker.get_item_metadata(1)=="zh_CN","Language choices retain canonical option metadata")
	game.language_picker.select(1)
	game.language_picker.item_selected.emit(1)
	await settle()
	check(Locale.get_language()=="zh_CN","The real language picker enables Simplified Chinese")
	check(game.heading.text==Locale.text("Quiet Conservatory") and game.heading.text!="Quiet Conservatory","The existing garden heading updates to Chinese in place")
	check_modal("Chinese desktop settings")
	check_canonical("Chinese rendering")
	var language_path: String = save_path.get_basename()+".language.cfg"
	var prefs := ConfigFile.new()
	check(prefs.load(language_path)==OK and prefs.get_value("language","locale","")=="zh_CN","Chinese selection saves to temporary language preferences")
	game.language_picker.select(0)
	game.language_picker.item_selected.emit(0)
	await settle()
	check(Locale.get_language()=="en" and game.heading.text=="Quiet Conservatory","The real language picker restores English without rebuilding the garden")
	check_canonical("English round trip")
	game._close_modal()
	game._open_detail(str(canonical_ids[0]))
	await settle()
	var edit: LineEdit = find_edit(game.modal)
	check(edit!=null,"The specimen name remains an editable field")
	if edit != null:
		edit.text = "自定义 River Lily"
		game._change_language("zh_CN")
		await settle()
		check(edit.text=="自定义 River Lily","Chinese rendering never translates or replaces player-typed text")
		game._change_language("en")
		await settle()
		check(edit.text=="自定义 River Lily","English round trip preserves player-typed Chinese and Latin text")
	check_canonical("Name editing presentation")
	game._close_modal()
	for code in ["en","zh_CN"]:
		game._change_language(code)
		root.size = Vector2i(390,780)
		await settle()
		game._open_settings()
		await settle()
		check_modal("%s portrait settings" % code)
		game._close_modal()
	Locale.set_language("en")
	root.size = Vector2i(2880,2000)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i.ZERO
	root.content_scale_factor = 2.0
	await settle()
	game._open_settings()
	await settle()
	check_modal("High-density settings")
	game._close_modal()
	root.content_scale_factor = 1.0
	root.size = Vector2i(1440,1000)
	await settle()
	game._open_wilderness()
	await settle()
	check(game.soundscape.context=="wild","Entering the field selects the wilderness soundtrack")
	game._open_settings()
	await settle()
	check(game.wilderness.waiting and not game.wilderness._try_step(Vector2i.UP),"Sound/language settings freeze field movement")
	game._close_modal()
	await settle()
	check(not game.wilderness.waiting and game.state.expedition.active_encounter.is_empty(),"Closing settings resumes walking without leaving a blocked encounter")
	game._return_from_wilderness()
	await settle()
	check(game.soundscape.context=="garden","Returning home restores the garden soundtrack")
	game._prepare_battle()
	game._start_battle()
	await settle()
	check(game.sim!=null and game.soundscape.context=="battle","A real battle selects the battle soundtrack")
	game._open_settings()
	await settle()
	var frozen_at: float = game.sim.elapsed
	game._process(.6)
	check(game.paused and is_equal_approx(game.sim.elapsed,frozen_at),"Sound/language settings pause a running battle")
	game._close_modal()
	await settle()
	check(not game.paused,"Closing settings resumes a previously running battle")
	game._toggle_pause()
	check(game.paused,"Player can pause the battle before opening preferences")
	game._open_settings()
	await settle()
	game._close_modal()
	await settle()
	check(game.paused,"Closing settings preserves a battle that the player already paused")
	game.sim.update(160)
	game._finish_battle()
	await settle()
	check(game.soundscape.context=="garden","Battle results return to garden music")
	game._close_modal()
	check(not game.soundscape._any_music_playing() and not game.soundscape._ambience.playing,"Context changes never play audio in automated previews")
	check(file_snapshot("user://sound_v1.cfg")==actual_sound_before,"Settings tests never modify the player's actual mixer preferences")
	check(file_snapshot("user://language_v1.cfg")==actual_language_before,"Settings tests never modify the player's actual language preference")
	check_canonical("Completed settings and context flow")
	Locale.set_language("en")
	game.queue_free()
	await settle()
	for path in [save_path,save_path.get_basename()+".backup.json",save_path.get_basename()+".audio.cfg",language_path]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	print("SETTINGS INTEGRATION TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
