extends SceneTree
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
	print("READABLE GENETICS VISUAL: ",name," · ",root.size)
func run() -> void:
	Locale.set_language("en")
	game = Garden.new()
	game.state = State.new("/tmp/conservatory_readable_genetics_%d.json" % Time.get_ticks_usec())
	root.add_child(game)
	game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game.display_settings = Display.new("/tmp/conservatory_readable_genetics_display.cfg")
	game.display_settings.configure(root,false)
	var carrier: String = str(game.state.plant_order[0])
	var solid: String = str(game.state.plant_order[1])
	var striped: String = str(game.state.plant_order[2])
	game.state.get_plant(carrier).genes.pattern = {"dominant":"Solid","recessive":"Striped"}
	game.state.get_plant(solid).genes.pattern = {"dominant":"Solid","recessive":"Solid"}
	game.state.get_plant(striped).genes.pattern = {"dominant":"Striped","recessive":"Striped"}
	game._open_dna(carrier)
	await snap("traits-readable-desktop-en")
	game._open_dna_compare(carrier,solid,"pattern","Striped")
	await snap("traits-cross-25-desktop-en")
	game._open_dna_compare(carrier,striped,"pattern","Striped")
	await snap("traits-cross-75-desktop-en")
	game.modal_scroll.scroll_vertical = 380
	await snap("traits-offspring-examples-en")
	Locale.set_language("zh_CN")
	game._open_dna(carrier)
	await snap("traits-readable-desktop-zh")
	game._open_dna_compare(carrier,striped,"pattern","Striped")
	await snap("traits-cross-desktop-zh")
	game.display_settings.enabled = false
	root.size = Vector2i(780,1560)
	root.content_scale_factor = 2
	game._open_dna(carrier)
	await snap("traits-readable-mobile-zh")
	game.modal_scroll.scroll_vertical = 350
	await snap("traits-hidden-mobile-zh")
	game._open_dna_compare(carrier,solid,"pattern","Striped")
	await snap("traits-cross-25-mobile-zh")
	game._open_dna_compare(carrier,striped,"pattern","Striped")
	await snap("traits-cross-75-mobile-zh")
	game._open_dna_compare(carrier,solid,"petals",6)
	await snap("traits-stored-flower-gene-mobile-zh")
	print("READABLE GENETICS PREVIEW COMPLETE: shown / hidden / named colors / 25 to 75 percent / actual offspring examples")
	quit()
