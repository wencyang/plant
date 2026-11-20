extends SceneTree
## Native visual review with a temporary garden. The player's archive/preferences
## remain untouched while all eight types and the actual responsive UI are shown.
const Garden = preload("res://scripts/garden.gd")
const State = preload("res://scripts/garden_state.gd")
const Display = preload("res://scripts/display_settings.gd")
const Locale = preload("res://scripts/localization.gd")
var game: Control

func _initialize() -> void:
	call_deferred("run")

func snap(filename: String) -> void:
	game._localize_ui()
	await create_timer(0.35).timeout
	for i in range(4): await process_frame
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	picture.save_png("res://screenshots/"+filename+".png")
	print("BOTANICAL GAME CAPTURE: ",filename," · ",picture.get_size())

func run() -> void:
	Locale.set_language("en")
	game = Garden.new()
	game.state = State.new("/tmp/conservatory_botanical_%d.json" % Time.get_ticks_usec())
	root.add_child(game)
	game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game.display_settings = Display.new("/tmp/conservatory_botanical_display.cfg")
	game.display_settings.configure(root,false)
	# Put every authored anatomy into real soil cells, without the starter-only
	# repetition concealing whether rarer species work in the actual game.
	for index in range(3,8):
		var specimen: Dictionary = game.state._create_base(mini(index,6),732831+index*1009)
		if index==7:
			specimen.type = "Carnivorous"
			specimen.species = "Hollow Pitcher"
			specimen.name = "Hollow Pitcher"
		game.state._add_plant(specimen)
		game.state.bed[index-3] = specimen.id
	game._refresh()
	await snap("botanical-garden-desktop")
	game.selected_id = str(game.state.bed[0])
	game._refresh()
	await snap("botanical-specimen-desktop")
	game._open_detail(str(game.state.bed[1]))
	await snap("botanical-detail-desktop")
	game._close_modal()
	game._open_wilderness()
	await snap("botanical-wilderness-desktop")
	game.wilderness.teleport_to_site("moss_01")
	game.wilderness.interact()
	await snap("botanical-encounter-desktop")
	game._leave_wild()
	game._return_from_wilderness()
	game._prepare_battle()
	game._start_battle()
	game.sim.update(26)
	game.effects.add_events(game.sim.events)
	await snap("botanical-battle-desktop")
	game._finish_battle()
	game._close_modal()
	game.display_settings.enabled = false
	root.size = Vector2i(780,1560)
	root.content_scale_factor = 2
	Locale.set_language("zh_CN")
	game._localize_ui()
	await snap("botanical-garden-mobile-zh")
	game._open_detail(str(game.state.bed[1]))
	await snap("botanical-detail-mobile-zh")
	game._close_modal()
	game._open_wilderness()
	game.wilderness.teleport_to_site("amber_01")
	game.wilderness.interact()
	await snap("botanical-encounter-mobile-zh")
	print("BOTANICAL GAME PREVIEW COMPLETE")
	quit()
