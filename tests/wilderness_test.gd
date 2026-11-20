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
	return rect.position.x>=viewport.position.x-1 and rect.position.y>=viewport.position.y-1 and rect.end.x<=viewport.end.x+1 and rect.end.y<=viewport.end.y+1
func run() -> void:
	root.size = Vector2i(1440,1000)
	test_path = "/tmp/conservatory_expanded_%d.json" % Time.get_ticks_usec()
	state = State.new(test_path)
	state.new_game()
	state.begin_expedition()
	world = World.new()
	world.state = state
	root.add_child(world)
	world.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await settle()
	check(world.MAP_WIDTH==160 and world.MAP_HEIGHT==128,"The wilderness has sixteen times the original area")
	check(world.SITES.size()>=150,"The wider world contains at least 150 collection patches")
	check(world.player_tile==Vector2i(15,18),"Existing saves still begin at the old home coordinates")
	check(world.nearest_site().id=="moss_01","The first old collection patch is preserved")
	var biomes: Dictionary = {}
	for site: Dictionary in world.SITES:
		check(world._find_path(Vector2i(15,18),Vector2i(site.x,site.y)).size()>0,"Every collection patch is reachable: %s" % site.id)
		biomes[str(site.biome)] = true
	check(biomes.size()==8,"All eight habitats contain reachable wild plants")
	for camp: Dictionary in world.LANDMARKS:
		check(world._find_path(Vector2i(15,18),Vector2i(camp.x,camp.y)).size()>0,"Every field camp is reachable: %s" % camp.id)
	check(not world.is_walkable(Vector2i(0,0)),"The world edge remains impassable")
	check(not world.is_walkable(Vector2i(6,27)),"The original pond still blocks movement")
	check(within(world._header.get_global_rect(),root.get_visible_rect()),"Desktop field header fits")
	check(within(world._footer.get_global_rect(),root.get_visible_rect()),"Desktop field controls fit")
	check(world._map_image==null,"There is no enormous whole-world HD image retained in memory")
	check(world._chunk_cache.size()>0 and world._chunk_cache.size()<=world.CHUNK_LIMIT,"Only a bounded visible HD chunk cache is retained")
	var chunk: Texture2D = world._chunk_cache.values()[0]
	check(chunk.get_width()<=1548 and chunk.get_height()<=1164,"HD chunks stay bounded to sixteen-by-twelve tiles plus seam gutters")
	check(chunk.get_image().has_mipmaps(),"Terrain chunks use true quality mipmaps")
	var received: Array = []
	world.sfx_requested.connect(func(sound): received.append(str(sound)))
	key(KEY_W,true)
	await settle()
	key(KEY_W,false)
	await process_frame
	check(world.player_tile==Vector2i(15,17),"Actual W input walks north one tile")
	check(state.expedition.position==[15,17],"Walking remains persistent")
	check(received.has("step") or received.has("grass"),"Walking requests a contextual footstep sound")
	var encounter: Array = []
	world.encounter_requested.connect(func(biome,id): encounter.append([biome,id]))
	key(KEY_E,true)
	await process_frame
	key(KEY_E,false)
	check(encounter.size()==1 and encounter[0]==["Mosswood","moss_01"],"E still opens the first legacy wild encounter")
	check(world.waiting,"Encounter input freezes movement")
	var old_tile: Vector2i = world.player_tile
	world._try_step(Vector2i.RIGHT)
	check(world.player_tile==old_tile,"No walking during encounter")
	world.encounter_closed()
	check(not world.waiting,"Closing the encounter releases movement")
	# Sweep the map without ever keeping a full-resolution whole-world bitmap.
	for camp_index in [2,4,5,6]:
		var camp: Dictionary = world.LANDMARKS[camp_index]
		state.visit_landmark(str(camp.id),str(camp.biome))
		world._travel_to(camp)
		check(world._chunk_cache.size()<=world.CHUNK_LIMIT,"Chunk LRU remains bounded after traveling: %s" % camp.id)
	check(world.chunks_built>world.CHUNK_LIMIT,"Distant travel exercises real chunk eviction, rather than only filling the cache")
	world.teleport_to_site(str(world.SITES.back().id))
	world._warm_visible_chunks()
	check(state.expedition.position[0]>100 or state.expedition.position[1]>100,"Expanded coordinates persist beyond the former 40x32 boundary")
	check(world._map_image==null,"Chunk painting releases CPU pixel buffers after upload")
	# Route atlas is useful, responsive, and never grants unvisited fast travel.
	world._open_atlas()
	await settle()
	check(world._atlas.visible and world.waiting,"The atlas pauses walking")
	world.encounter_closed()
	check(world.waiting,"Closing another overlay keeps an open route atlas paused")
	check(within(world._atlas.get_global_rect(),root.get_visible_rect()),"Desktop route map fits")
	var before: Vector2i = world.player_tile
	var unvisited: Dictionary = world.LANDMARKS.back()
	world._travel_to(unvisited)
	check(world.player_tile==before,"Unvisited camps cannot be used for fast travel")
	world._close_atlas()
	state.visit_landmark(str(unvisited.id),str(unvisited.biome))
	world._open_atlas()
	world._travel_to(unvisited)
	check(world.player_tile==Vector2i(unvisited.x,unvisited.y),"Visited camps allow a return journey")
	check(not world.waiting,"Camp travel returns control to the trail")
	world._open_atlas()
	world._route_to(Vector2i(15,18))
	check(not world._route.is_empty() and world._touch_goal==Vector2i(15,18),"Atlas click plans an efficient route to a distant destination")
	world._touch_goal = Vector2i(-1,-1)
	world._route.clear()
	root.size = Vector2i(390,780)
	await settle()
	check(within(world._header.get_global_rect(),root.get_visible_rect()),"Mobile field header fits")
	check(within(world._footer.get_global_rect(),root.get_visible_rect()),"Mobile field controls fit")
	world._open_atlas()
	await settle()
	check(within(world._atlas.get_global_rect(),root.get_visible_rect()),"Mobile route map fits")
	world._close_atlas()
	world.queue_free()
	await process_frame
	if FileAccess.file_exists(test_path):DirAccess.remove_absolute(test_path)
	print("WILDERNESS TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures>0 else 0)
