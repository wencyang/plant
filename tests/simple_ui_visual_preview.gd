extends SceneTree
## Silent, disposable captures of the smaller everyday interface.
const Garden=preload("res://scripts/garden.gd")
const State=preload("res://scripts/garden_state.gd")
const Locale=preload("res://scripts/localization.gd")
var game: Control
var path: String

func _initialize() -> void:
	call_deferred("run")

func settle() -> void:
	for frame in range(8): await process_frame

func layout(language: String,dimensions: Vector2i) -> void:
	Locale.set_language(language)
	root.size=dimensions
	root.content_scale_factor=2
	await settle()
	game._responsive()
	game._localize_ui()
	await settle()

func snap(label: String) -> void:
	game._localize_ui()
	await create_timer(0.3).timeout
	await settle()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/simple-"+label+".png")
	print("SIMPLE UI VISUAL: ",label)

func run() -> void:
	path="/tmp/conservatory_simple_ui_visual_%d.json" % Time.get_ticks_usec()
	game=Garden.new()
	game.state=State.new(path)
	root.add_child(game)
	game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game.display_settings.enabled=false
	await layout("en",Vector2i(2880,2000))
	await snap("garden-desktop-en")
	game._open_lab()
	await snap("cross-desktop-en")
	game._close_modal()
	game._open_garden_menu()
	await snap("menu-desktop-en")
	game._close_modal()
	await layout("zh_CN",Vector2i(780,1560))
	await snap("garden-mobile-zh")
	game._open_lab()
	await snap("cross-mobile-zh")
	game._close_modal()
	game._choose_plant(str(game.state.plant_order[0]),"bed",0)
	await snap("plant-mobile-zh")
	game._close_modal()
	game._open_adventure()
	await snap("field-mobile-zh")
	var first: Dictionary=game.state.adventure_collect("river_fan")
	var second: Dictionary=game.state.adventure_collect("floatcap")
	var a: String=str(first.get("plant",{}).get("id",game.state.adventure_info().cuttings.river_fan))
	var b: String=str(second.get("plant",{}).get("id",game.state.adventure_info().cuttings.floatcap))
	game._show_adventure_cross(a,b)
	await snap("field-cross-mobile-zh")
	game._adventure_pollinate(a,b)
	await snap("fruit-mobile-zh")
	game.state.apply_care(a,"ripening")
	game._adventure_sow(a)
	await snap("siblings-mobile-zh")
	game._adventure_back_to_field()
	await layout("en",Vector2i(2880,2000))
	game.adventure_field.refresh()
	await snap("field-desktop-en")
	game.queue_free()
	await process_frame
	for suffix: String in ["",".bak",".audio.cfg"]:
		if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(path+suffix)
	print("SIMPLE UI PREVIEW COMPLETE: disposable garden only")
	quit()
