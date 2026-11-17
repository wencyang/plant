extends SceneTree
const State = preload("res://scripts/garden_state.gd")
const World = preload("res://scripts/wilderness.gd")
var checks: int = 0
var failures: int = 0
var world: Control
var state
var test_path: String

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func settle() -> void:
	for i in range(5): await process_frame

func key(physical: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = physical
	event.keycode = physical
	event.pressed = pressed
	Input.parse_input_event(event)

func within(rect: Rect2, viewport: Rect2) -> bool:
	return rect.position.x >= viewport.position.x and rect.position.y >= viewport.position.y and rect.end.x <= viewport.end.x and rect.end.y <= viewport.end.y

func run() -> void:
	root.size = Vector2i(1440,1000)
	test_path = "/tmp/conservatory_wilderness_%d.json" % Time.get_ticks_usec()
	state = State.new(test_path)
	state.new_game()
	state.begin_expedition()
	world = World.new()
	world.state = state
	root.add_child(world)
	world.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await settle()
	check(world.player_tile == Vector2i(15,18),"Expedition begins outside the home conservatory")
	check(world.nearest_site().id == "moss_01","The first wild specimen is on the north path")
	check(world.SITES.size() == 18,"Eighteen field collection sites")
	for site: Dictionary in world.SITES:
		check(world._find_path(Vector2i(15,18),Vector2i(site.x,site.y)).size() > 0,"Collection site %s must be reachable from home" % site.id)
	check(not world.is_walkable(Vector2i(0,0)),"The outer hedge blocks movement")
	check(not world.is_walkable(Vector2i(6,27)),"Deep pond tiles block movement")
	check(within(world._header.get_global_rect(),root.get_visible_rect()),"Desktop expedition header fits the viewport")
	check(within(world._footer.get_global_rect(),root.get_visible_rect()),"Desktop expedition controls fit the viewport")
	check(world._font is SystemFont,"Exploration HUD uses a full-resolution system font")
	check(world._map_texture.get_width()==1280 and world._map_texture.get_height()==1024,"The world texture contains the doubled detail resolution")
	check(world._pixel_scale==2,"World tiles remain32screenpixels ondesktop")
	var fine_blocks: int = 0
	for y in range(40,100,2):
		for x in range(40,100,2):
			var c: Color = world._map_image.get_pixel(x,y)
			if c!=world._map_image.get_pixel(x+1,y) or c!=world._map_image.get_pixel(x,y+1): fine_blocks+=1
	check(fine_blocks>10,"New source pixels contain finer detail rather than only an enlarged old texture")
	# Exercise the input event path, then verify that movement reaches saved data.
	key(KEY_W,true)
	await settle()
	key(KEY_W,false)
	await process_frame
	check(world.player_tile == Vector2i(15,17),"W keyboard input walks north one tile")
	check(state.expedition.position == [15,17],"Keyboard movement persists the explorer position")
	var events: Array = []
	world.encounter_requested.connect(func(biome: String,id: String): events.append([biome,id]))
	key(KEY_E,true)
	key(KEY_E,false)
	await process_frame
	check(events.size() == 1 and events[0] == ["Mosswood","moss_01"],"E keyboard input investigates the nearby plant")
	check(world.waiting,"An encounter suspends field movement")
	check(not world._try_step(Vector2i.UP) and world.player_tile == Vector2i(15,17),"Exploration cannot walk behind a plant encounter")
	world.encounter_closed()
	check(not world.waiting,"Closing the encounter restores exploration")
	state.expedition.collected_sites.append("moss_01")
	world.refresh()
	check(world.nearest_site().id != "moss_01","Collected plants no longer appear as available sites")
	world.teleport_to_site("fen_02")
	check(world.nearest_site().id == "fen_02","The test/travel helper reaches distant biomes")
	root.size = Vector2i(390,780)
	await settle()
	check(within(world._header.get_global_rect(),root.get_visible_rect()),"Portrait expedition header fits a390x780 viewport")
	check(within(world._footer.get_global_rect(),root.get_visible_rect()),"Portrait expedition controls fit a390x780 viewport")
	check(world._map_rect.size.x > 0 and world._map_rect.size.y > 0,"Portrait exploration leaves a usable map viewport")
	world.queue_free()
	await process_frame
	for path: String in [test_path,test_path.get_basename()+".backup.json"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	print("WILDERNESS TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures>0 else 0)
