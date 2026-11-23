extends SceneTree
## Native captures with an isolated, silent party. Never loads the player's save.
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
	await create_timer(0.35).timeout
	await settle()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/field-adventure-"+label+".png")
	print("FIELD ADVENTURE VISUAL: ",label)

func run() -> void:
	path="/tmp/conservatory_field_adventure_visual_%d.json" % Time.get_ticks_usec()
	game=Garden.new()
	game.state=State.new(path)
	root.add_child(game)
	game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game.display_settings.enabled=false
	game.state.adventure_collect("river_fan")
	game.state.adventure_collect("floatcap")
	game._refresh()
	await layout("en",Vector2i(2880,2000))
	game._open_adventure()
	await snap("overworld-desktop-en")
	game._show_party()
	await snap("party-desktop-en")
	game._close_modal()
	game._return_from_adventure()
	await snap("garden-desktop-en")
	game._open_adventure()
	await layout("zh_CN",Vector2i(780,1560))
	await snap("overworld-mobile-zh")
	game._show_party()
	await snap("party-mobile-zh")
	game._open_field_bag()
	await snap("bag-mobile-zh")
	game._open_field_dex()
	await snap("guide-mobile-zh")
	game._open_field_routes()
	await snap("routes-mobile-zh")
	game._close_modal()
	game._return_from_adventure()
	await snap("garden-mobile-zh")
	game._open_wilderness()
	await snap("wilds-mobile-zh")
	game._return_from_wilderness()
	game.queue_free()
	await process_frame
	for suffix: String in ["",".bak",".audio.cfg"]:
		if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(path+suffix)
	print("FIELD ADVENTURE PREVIEW COMPLETE: temporary garden only")
	quit()
