extends SceneTree
## Native captures of the illustrated wilderness using a disposable, silent save.
## The player's garden, preferences, field progress and stored organisms stay untouched.
const Garden = preload("res://scripts/garden.gd")
const State = preload("res://scripts/garden_state.gd")
const Display = preload("res://scripts/display_settings.gd")
const Locale = preload("res://scripts/localization.gd")
const Habitat = preload("res://scripts/habitat_catalog.gd")
var game: Control
var save_path: String

func _initialize() -> void:
	call_deferred("run")

func settle() -> void:
	for i in range(5): await process_frame

func snap(filename: String) -> void:
	game._localize_ui()
	await create_timer(0.35).timeout
	await settle()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/"+filename+".png")
	print("LANDSCAPE VISUAL: ",filename," · ",root.size)

func layout(dimensions: Vector2i) -> void:
	game.display_settings.enabled=false
	root.size=dimensions
	root.content_scale_factor=2
	await settle()
	game._responsive()
	await settle()

func biome_site(biome: String) -> String:
	for site: Dictionary in game.wilderness.SITES:
		if str(site.biome)==biome:
			return str(site.id)
	return ""

func run() -> void:
	Locale.set_language("en")
	save_path="/tmp/conservatory_landscape_visual_%d.json" % Time.get_ticks_usec()
	game=Garden.new()
	game.state=State.new(save_path)
	root.add_child(game)
	game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game.display_settings=Display.new(save_path.get_basename()+".display.cfg")
	game.display_settings.configure(root,false)
	await layout(Vector2i(2880,2000))
	await snap("illustrated-garden-desktop-en")
	game._open_plant_habitats(str(game.state.plant_order[0]))
	await snap("landscape-family-guide-desktop-en")
	game._close_modal()
	game._open_wilderness()
	await settle()
	for biome: String in State.WILD_BIOMES:
		game.wilderness.teleport_to_site(biome_site(biome))
		await snap("landscape-"+str(Habitat.region(biome).art_key)+"-desktop-en")
	game.wilderness._open_atlas()
	await snap("landscape-atlas-desktop-en")
	game.wilderness._close_atlas()
	game.wilderness.teleport_to_site(biome_site("Mosswood"))
	game.wilderness.interact()
	await snap("landscape-encounter-forest-desktop-en")
	game._wild_action("observe")
	await snap("landscape-encounter-studied-desktop-en")
	game._leave_wild()
	game.wilderness.teleport_to_site(biome_site("Glassfall Coast"))
	game.wilderness.interact()
	await snap("landscape-encounter-coast-desktop-en")
	game._leave_wild()
	Locale.set_language("zh_CN")
	game.wilderness.teleport_to_site(biome_site("Ember Ridge"))
	await snap("landscape-canyon-desktop-zh")
	game.wilderness.interact()
	await snap("landscape-encounter-canyon-desktop-zh")
	game._leave_wild()
	game.wilderness._open_atlas()
	await snap("landscape-atlas-desktop-zh")
	game.wilderness._close_atlas()
	await layout(Vector2i(780,1560))
	game.wilderness.teleport_to_site(biome_site("Moonfen"))
	await snap("landscape-moonfen-mobile-zh")
	game.wilderness.interact()
	await snap("landscape-encounter-mobile-zh")
	game._leave_wild()
	game.wilderness._open_atlas()
	await snap("landscape-atlas-mobile-zh")
	game.wilderness._close_atlas()
	Locale.set_language("en")
	game.wilderness.teleport_to_site(biome_site("Ancient Grove"))
	await snap("landscape-ancient-grove-mobile-en")
	game.wilderness.interact()
	await snap("landscape-encounter-mobile-en")
	game._leave_wild()
	game.wilderness._open_atlas()
	await snap("landscape-atlas-mobile-en")
	game.wilderness._close_atlas()
	game._return_from_wilderness()
	await snap("illustrated-garden-mobile-en")
	game.queue_free()
	await process_frame
	for suffix: String in [".json",".backup.json",".audio.cfg",".display.cfg"]:
		DirAccess.remove_absolute(save_path.get_basename()+suffix)
	Locale.set_language("en")
	print("LANDSCAPE PREVIEW COMPLETE: eight landscapes, actual specimen encounters, English and Chinese desktop and mobile; disposable save only")
	quit()
