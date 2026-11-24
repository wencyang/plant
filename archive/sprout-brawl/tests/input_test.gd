extends SceneTree
## Simulates real mouse input against the shop: tap-to-buy, drag-to-cross, drag-to-sell.
## godot --path . --quit-after 3000 --script res://tests/input_test.gd

const Game := preload("res://scripts/game.gd")
var game
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(c: bool, m: String) -> void:
	if not c:
		failures += 1
		print("FAIL: ", m)

func wait(s: float) -> void:
	await create_timer(s).timeout

func mouse(pos: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = pos
	e.global_position = pos
	Input.warp_mouse(pos)
	root.push_input(e)
	await process_frame

func move(pos: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = pos
	e.global_position = pos
	Input.warp_mouse(pos)
	root.push_input(e)
	await process_frame

func drag(a: Vector2, b: Vector2) -> void:
	await move(a)
	await mouse(a, true)
	for i in range(1, 9):
		await move(a.lerp(b, i / 8.0))
	await mouse(b, false)
	await wait(0.1)

func run() -> void:
	root.size = Vector2i(1280, 800)
	game = Game.new()
	root.add_child(game)
	game.save.path = "user://input_test_save.json"
	game.save.herbarium = {}
	game.sfx.muted = true
	await wait(0.5)
	game._start_run()
	await wait(1.2)
	# tap two packets
	await mouse(game.packet_pos(0), true)
	await mouse(game.packet_pos(0), false)
	await wait(0.3)
	check(game.run.plant_count() == 1, "tap buys a seed")
	await mouse(game.packet_pos(0), true)
	await mouse(game.packet_pos(0), false)
	await wait(0.3)
	check(game.run.plant_count() == 2, "second tap buys")
	# drag slot 3 plant onto slot 4 plant -> popup
	await drag(game.slot_pos(3) + Vector2(0, -50), game.slot_pos(4) + Vector2(0, -50))
	check(game.popup != null, "drag onto plant opens the cross popup")
	await wait(0.3)
	# press the Cross button
	var btn: Button = null
	for b in game.popup.find_children("*", "Button", true, false):
		if b.text.begins_with("Cross"): btn = b
	check(btn != null, "cross button exists")
	if btn: btn.pressed.emit()
	await wait(1.5)
	check(game.run.plant_count() == 1 and game.run.board[4] != null and game.run.board[4].gen == 2, "cross merged into slot 4")
	check(game.overlay != null, "reveal overlay shown")
	game._close_overlay()
	game.busy = false
	# drag the hybrid into the bin to sell
	var before: int = game.run.sun
	await drag(game.slot_pos(4) + Vector2(0, -50), game.bin_rect.get_center())
	await wait(0.3)
	check(game.run.plant_count() == 0 and game.run.sun > before, "drag to bin sells")
	# buy, then drag to an empty slot to move
	await mouse(game.packet_pos(0), true)
	await mouse(game.packet_pos(0), false)
	await wait(0.2)
	await drag(game.slot_pos(4) + Vector2(0, -50), game.slot_pos(1) + Vector2(0, -50))
	check(game.run.board[1] != null and game.run.board[4] == null, "drag to empty slot moves")
	# fight via keyboard
	var k := InputEventKey.new()
	k.keycode = KEY_SPACE
	k.pressed = true
	root.push_input(k)
	await wait(0.3)
	check(game.mode == "battle", "space starts the fight")
	game.skipping = true
	await wait(4.0)
	check(game.overlay != null, "result overlay shown")
	print("INPUT TEST: ", "OK" if failures == 0 else "%d FAILURES" % failures)
	quit(1 if failures else 0)
