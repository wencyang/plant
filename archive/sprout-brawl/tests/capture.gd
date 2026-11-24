extends SceneTree
## Drives the real game and saves screenshots to screenshots/.
## godot --path . --quit-after 3000 --script res://tests/capture.gd

const Game := preload("res://scripts/game.gd")
const SaveData := preload("res://scripts/save_data.gd")
var game

func _initialize() -> void:
	call_deferred("run")

func wait(s: float) -> void:
	await create_timer(s).timeout

func snap(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/%s.png" % name)
	print("CAPTURED ", name)

func run() -> void:
	root.size = Vector2i(1280, 800)
	root.content_scale_size = Vector2i(1280, 800)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	game = Game.new()
	root.add_child(game)
	game.save.path = "user://capture_save.json"
	game.save.herbarium = {"leaf+snap": {"count": 1, "mutant": false}, "bloom+bloom": {"count": 2, "mutant": true}, "root+toxin": {"count": 1, "mutant": false}}
	game.sfx.muted = true
	await wait(1.2)
	await snap("01-title")
	game._start_run()
	await wait(1.6)
	await snap("02-shop")
	game._buy_to(0, game.run.first_empty())
	await wait(0.2)
	game._buy_to(0, game.run.first_empty())
	await wait(0.2)
	game._buy_to(0, game.run.first_empty())
	await wait(0.8)
	game._show_info_for_plant(game.run.board[4], game.board_views[4].global_position + Vector2(0, -140))
	await snap("03-planted")
	game.info_card.visible = false
	game._ask_cross(3, 4)
	await wait(0.4)
	await snap("04-cross-preview")
	game._close_popup()
	game._do_cross(3, 4)
	await wait(1.3)
	await snap("05-reveal")
	game._close_overlay()
	game.busy = false
	# fast-forward a few rounds with bot purchases so the battle is interesting
	for r in 4:
		game.run.next_round()
		while game.run.sun >= 3 and game.run.first_empty() >= 0:
			var idx := -1
			for i in game.run.shop.size():
				if game.run.shop[i].kind == "seed": idx = i
			if idx < 0: break
			game.run.buy_seed(idx, game.run.first_empty())
		if game.run.first_empty() < 0:
			game.run.cross(0, 1)
	game.run.roll_shop()
	game._enter_shop()
	await wait(1.4)
	await snap("06-shop-later")
	game._on_fight()
	await wait(2.6)
	await snap("07-battle-intro")
	await wait(2.5)
	await snap("08-battle-mid")
	game.skipping = true
	await wait(3.0)
	await snap("09-battle-result")
	game._close_overlay()
	game.show_herbarium()
	await wait(0.6)
	await snap("10-herbarium")
	quit()
