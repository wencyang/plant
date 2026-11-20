extends SceneTree
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
	for i in range(5): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/"+filename+".png")
func english_left(node: Node,result: Array[String]) -> void:
	if node is Label or node is Button:
		if node.is_visible_in_tree():
			var value: String = node.text
			var expression := RegEx.new()
			expression.compile("[A-Za-z]{3,}")
			if expression.search(value) and not value.is_valid_hex_number(false) and value!="English": result.append(value)
	for child in node.get_children(): english_left(child,result)
func audit(context: String) -> void:
	var remaining: Array[String] = []
	english_left(game,remaining)
	print("CHINESE UI ",context," / remaining ",JSON.stringify(remaining))
func run() -> void:
	Locale.set_language("en")
	game = Garden.new()
	game.state = State.new("/tmp/conservatory_new_features_%d.json" % Time.get_ticks_usec())
	root.add_child(game)
	game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game.display_settings = Display.new("/tmp/conservatory_new_features_display.cfg")
	game.display_settings.configure(root,false)
	game._open_settings()
	await snap("settings-en")
	game._close_modal()
	game._open_wilderness()
	await snap("expanded-wilderness")
	game.wilderness._open_atlas()
	await snap("expanded-atlas")
	game.wilderness._close_atlas()
	Locale.set_language("zh_CN")
	game._localize_ui()
	game.wilderness._open_atlas()
	await snap("expanded-atlas-zh")
	audit("atlas")
	game.wilderness._close_atlas()
	var distant: Dictionary = game.wilderness.SITES.back()
	game.wilderness.teleport_to_site(str(distant.id))
	await snap("distant-wilderness-zh")
	game.wilderness.interact()
	await snap("wild-encounter-zh")
	audit("encounter")
	game._leave_wild()
	game._open_settings()
	await snap("settings-zh")
	audit("settings")
	game._close_modal()
	game.display_settings.enabled = false
	root.size = Vector2i(780,1560)
	root.content_scale_factor = 2
	await create_timer(0.2).timeout
	game.wilderness._open_atlas()
	await snap("expanded-atlas-mobile-zh")
	game.wilderness._close_atlas()
	game._open_settings()
	await snap("settings-mobile-zh")
	game._close_modal()
	game._return_from_wilderness()
	await snap("garden-mobile-zh")
	audit("mobile garden")
	print("FEATURE PREVIEW: ",game.wilderness.SITES.size()," patches / ",game.wilderness.LANDMARKS.size()," camps / ",game.state.WILD_BIOMES.size()," biomes / audio preview muted ",game.soundscape.preview_muted)
	quit()
