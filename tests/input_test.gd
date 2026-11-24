extends SceneTree
## Simulated mouse/keyboard play: place lure, drag it, recall it, swipe-prune.
## godot --path . --quit-after 6000 --script res://tests/input_test.gd

const Main := preload("res://scripts/main.gd")
const Levels := preload("res://scripts/levels.gd")
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

func mouse(pos: Vector2, pressed: bool, button := MOUSE_BUTTON_LEFT) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = button
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
	for i in range(1, 11):
		await move(a.lerp(b, i / 10.0))
	await mouse(b, false)
	await wait(0.1)

func run() -> void:
	root.size = Vector2i(1600, 1000)
	game = Main.new()
	root.add_child(game)
	game.save.path = "user://input_test.json"
	game.save.seeds = [Levels.starter()]
	game.save.completed = {}
	game.sfx.muted = true
	await wait(0.5)
	game.show_level_intro(1)
	await wait(0.5)
	game._start_level(1, Levels.starter())
	await wait(0.3)
	await mouse(Vector2(400, 400), true)
	await mouse(Vector2(400, 400), false)
	check(game.session.world.lures.size() == 1, "click places a lure")
	await drag(Vector2(400, 400), Vector2(500, 450))
	check(game.session.world.lures[0].distance_to(Vector2(500, 450)) < 2.0, "drag moves the lure")
	await mouse(Vector2(500, 450), true, MOUSE_BUTTON_RIGHT)
	check(game.session.world.lures.is_empty() and game.session.lures_left == 2, "right-click recalls the lure")
	await wait(3.0)
	var before: int = game.session.prunes_left
	var tips_before: int = game.session.plant.tips.size()
	await drag(Vector2(700, 760), Vector2(900, 760))
	check(game.session.prunes_left == before - 1, "swipe across stem uses a prune")
	check(game.session.plant.tips.size() >= 2, "pruning spawns new shoots")
	await drag(Vector2(100, 200), Vector2(200, 200))
	check(game.session.prunes_left == before - 1, "swipe through empty air costs nothing")
	var k := InputEventKey.new()
	k.keycode = KEY_SPACE
	k.pressed = true
	root.push_input(k)
	await wait(0.1)
	check(game.paused, "space pauses")
	print("INPUT TEST: ", "OK" if failures == 0 else "%d FAILURES" % failures)
	quit(1 if failures else 0)
