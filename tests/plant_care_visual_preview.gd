extends SceneTree
## Native screenshots use a disposable garden; the player's save and preferences
## are never loaded, and every applied tool belongs only to the temporary garden.
const Garden = preload("res://scripts/garden.gd")
const State = preload("res://scripts/garden_state.gd")
const Display = preload("res://scripts/display_settings.gd")
const Locale = preload("res://scripts/localization.gd")
var game: Control

func _initialize() -> void:
	call_deferred("run")

func snap(name: String) -> void:
	game._localize_ui()
	await create_timer(0.35).timeout
	for i in range(4): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/"+name+".png")
	print("PLANT CARE VISUAL: ",name," · ",root.size)

func layout(dimensions: Vector2i) -> void:
	game.display_settings.enabled = false
	root.size = dimensions
	root.content_scale_factor = 2
	for i in range(5): await process_frame
	game._responsive()
	for i in range(4): await process_frame

func run() -> void:
	Locale.set_language("en")
	game = Garden.new()
	game.state = State.new("/tmp/conservatory_care_visual_%d.json" % Time.get_ticks_usec())
	root.add_child(game)
	game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game.display_settings = Display.new("/tmp/conservatory_care_visual_display_%d.cfg" % Time.get_ticks_usec())
	game.display_settings.configure(root,false)
	await layout(Vector2i(2880,2000))
	game.state.resources.sunlight = 600
	var leaf: String = str(game.state.plant_order[0])
	var flower: String = str(game.state.plant_order[1])
	game.state.get_plant(leaf).life_age = 0
	game._refresh()
	await snap("care-sunny-garden-desktop-en")
	game._open_wilderness()
	await snap("care-sunny-wilds-desktop-en")
	game.wilderness._open_atlas()
	await snap("care-sunny-atlas-desktop-en")
	game.wilderness._close_atlas()
	game._return_from_wilderness()
	game._open_care(leaf)
	await snap("care-tools-before-desktop-en")
	game.modal_scroll.scroll_vertical = 430
	await snap("care-tools-grid-desktop-en")
	game.modal_scroll.scroll_vertical = 0
	game._apply_care(leaf,"growth")
	await snap("care-growth-after-desktop-en")
	for i in range(3): game.state.apply_care(leaf,"growth")
	for i in range(4): game.state.apply_care(leaf,"compost")
	game._open_care(leaf,"A little love goes a long way!")
	await snap("care-big-plant-desktop-en")
	game._apply_care(leaf,"longevity")
	await snap("care-life-extended-desktop-en")
	game._close_modal()
	game._refresh()
	await snap("care-grown-garden-desktop-en")
	Locale.set_language("zh_CN")
	game._refresh()
	await snap("care-sunny-garden-desktop-zh")
	game._open_wilderness()
	await snap("care-sunny-wilds-desktop-zh")
	game._return_from_wilderness()
	game._open_care(leaf)
	await snap("care-tools-desktop-zh")
	game.modal_scroll.scroll_vertical = 450
	await snap("care-tools-grid-desktop-zh")
	Locale.set_language("en")
	await layout(Vector2i(780,1560))
	game._close_modal()
	game._refresh()
	await snap("care-sunny-garden-mobile-en")
	game._open_wilderness()
	await snap("care-sunny-wilds-mobile-en")
	game._return_from_wilderness()
	game._open_care(flower)
	await snap("care-tools-mobile-en")
	game.modal_scroll.scroll_vertical = 470
	await snap("care-tools-scrolled-mobile-en")
	game.modal_scroll.scroll_vertical = 100000
	await snap("care-tools-bottom-mobile-en")
	Locale.set_language("zh_CN")
	game._open_care(flower)
	await snap("care-tools-mobile-zh")
	game.modal_scroll.scroll_vertical = 470
	await snap("care-tools-scrolled-mobile-zh")
	game.modal_scroll.scroll_vertical = 100000
	await snap("care-tools-bottom-mobile-zh")
	print("PLANT CARE PREVIEW COMPLETE: sunny garden / individual measurements / visible growth / extended life / six tools / English and Chinese desktop and mobile")
	quit()
