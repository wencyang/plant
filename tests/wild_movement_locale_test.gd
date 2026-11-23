extends SceneTree
## A standalone wilderness has no delayed garden locale sweep to repair a frame.
## Every movement/route/camp callback must return already-localized visible text.
const World=preload("res://scripts/wilderness.gd")
const State=preload("res://scripts/garden_state.gd")
const Locale=preload("res://scripts/localization.gd")
const DNA=preload("res://scripts/plant_dna.gd")
var world: Control
var state
var save_path: String
var checks: int=0
var failures: int=0
var moved: int=0

func _initialize() -> void: call_deferred("run")

func check(value: bool,message: String) -> void:
	checks+=1
	if not value:
		failures+=1
		push_error("WILD MOVEMENT LOCALE: "+message)

func localized(node: Node,context: String) -> void:
	if node is Label or node is Button:
		check(node.has_meta("_locale_source_text"),context+" owns a canonical source: "+node.name)
		var source: String=str(node.get_meta("_locale_source_text",""))
		check(str(node.text)==Locale.text(source),context+" is already localized: "+source.left(60))
		check(str(node.get_meta("_locale_rendered_text",""))==str(node.text),context+" keeps rendered/source metadata in sync")
		if Locale.get_language()=="zh_CN":
			check(node.get_theme_font("font")==Locale.get_ui_font(),context+" uses the Chinese font immediately")
	if node is Control and node.has_meta("_locale_source_tooltip_text"):
		check(node.tooltip_text==Locale.text(str(node.get_meta("_locale_source_tooltip_text"))),context+" tooltip is translated immediately")
	for child: Node in node.get_children(): localized(child,context)

func hud(context: String) -> void:
	for node: Control in [world._header,world._footer,world._vista_caption]: localized(node,context)
	var biome: String=world.biome_at(world.player_tile)
	check(world._vista_title.text==Locale.text(biome),context+" vista names the current biome")
	var heading: String="PLANT SAFARI" if world.size.x<700 else "PLANT SAFARI / THE OUTER GARDENS"
	check(world._header_title.text==Locale.text(heading),context+" keeps the layout-dependent heading localized")

func step(direction: Vector2i,context: String) -> void:
	var before: Vector2i=world.player_tile
	check(world._try_step(direction),context+" actually walks")
	check(world.player_tile==before+direction,context+" moves one stable world tile")
	moved+=1
	hud(context+" before another frame")
	world._process(1.0/60.0)
	hud(context+" after _process")
	await process_frame
	hud(context+" rendered frame")

func first_site(biome: String) -> Dictionary:
	for site: Dictionary in world.SITES:
		if str(site.biome)==biome: return site
	return {}

func adjacent_walk(context: String) -> void:
	var start: Vector2i=world.player_tile
	for direction: Vector2i in [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]:
		if world.is_walkable(start+direction):
			await step(direction,context)
			await step(-direction,context+" return")
			return
	check(false,context+" has at least one reachable adjacent tile")

func language(code: String,context: String) -> void:
	Locale.set_language(code)
	# The field must catch a locale change in its own frame, without the garden.
	world._process(1.0/60.0)
	hud(context+" language frame")
	if is_instance_valid(world._atlas): localized(world._atlas,context+" atlas language frame")
	await process_frame
	hud(context+" next frame")

func run() -> void:
	save_path="/tmp/conservatory_movement_locale_%d.json" % Time.get_ticks_usec()
	state=State.new(save_path)
	state.new_game()
	state.begin_expedition()
	var collection: String=DNA.canonical([state.plants,state.plant_order,state.bed,state.display_bed,state.seed_bank,state.resources])
	Locale.set_language("zh_CN")
	root.size=Vector2i(1440,1000)
	world=World.new()
	world.state=state
	root.add_child(world)
	world.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	world.set_process(false)
	for i in range(5): await process_frame
	hud("Initial standalone Chinese field")
	check(world._location_label.text!=str(world._location_label.get_meta("_locale_source_text")),"Chinese location is a real translation")
	for dimensions: Vector2i in [Vector2i(1440,1000),Vector2i(390,780)]:
		root.size=dimensions
		await process_frame
		world._layout()
		hud("Layout write "+str(dimensions))
		for code: String in ["zh_CN","en","zh_CN"]:
			await language(code,str(dimensions))
			# The first patch has a real plant, family name, ecological clue and E action.
			world.teleport_to_site("moss_01")
			hud(code+" nearby patch teleport")
			await adjacent_walk(code+" near a specimen")
			# Exercise the exact movement callback across a region boundary.
			var boundary: Array[Vector2i]=world._find_path(Vector2i(24,17),Vector2i(26,17))
			check(boundary.size()>1,code+" region-boundary path exists")
			if boundary.size()>1:
				world.player_tile=boundary[0]
				state.move_explorer(world.player_tile.x,world.player_tile.y)
				world.refresh()
				for index in range(1,boundary.size()): await step(boundary[index]-world.player_tile,code+" region boundary")
			# Atlas controls are created dynamically, including unvisited camp tooltips.
			world._open_atlas()
			check(world._atlas.visible and world.waiting,code+" opens and pauses at the real atlas")
			localized(world._atlas,code+" freshly built atlas")
			var source_before: String=str(world._atlas_title.get_meta("_locale_source_text"))
			await language("en" if code=="zh_CN" else "zh_CN",code+" live atlas switch")
			check(str(world._atlas_title.get_meta("_locale_source_text"))==source_before,"Switching locale preserves atlas canonical source")
			await language(code,code+" restored atlas language")
			var camp: Dictionary=world.LANDMARKS[2]
			state.visit_landmark(str(camp.id),str(camp.biome))
			world._rebuild_camp_list()
			localized(world._atlas,code+" rebuilt visited camps")
			world._travel_to(camp)
			check(not world.waiting and not world._atlas.visible,code+" camp travel returns walking control")
			hud(code+" immediate camp arrival")
			await adjacent_walk(code+" camp footstep")
			# Route-map clicks use the actual pathfinder and _process walking loop.
			var destination: Vector2i=world.player_tile+Vector2i(2,0)
			if world.is_walkable(destination):
				world._open_atlas()
				world._route_to(destination)
				check(not world.waiting and world._touch_goal==destination,code+" atlas click resumes a real route")
				for frame in range(4):
					world._process(0.16)
					hud(code+" routed frame "+str(frame))
					await process_frame
			# The scenic caption changes independently of the garden's UI refresh.
			for biome: String in ["Glassfall Coast","Sporefen","Ember Ridge","Moonfen","Ancient Grove"]:
				var site: Dictionary=first_site(biome)
				world.teleport_to_site(str(site.id))
				world._update_vista()
				hud(code+" scenic biome "+biome)
			world._touch_goal=Vector2i(-1,-1)
			world._route.clear()
	check(moved>=24,"Regression observes real walking rather than only static translated screenshots")
	check(DNA.canonical([state.plants,state.plant_order,state.bed,state.display_bed,state.seed_bank,state.resources])==collection,"Locale and exploration checks preserve the isolated collection and supplies")
	world.queue_free()
	await process_frame
	for suffix: String in [".json",".backup.json"]: DirAccess.remove_absolute(save_path.get_basename()+suffix)
	Locale.set_language("en")
	print("WILD MOVEMENT LOCALE TESTS: %d checks, %d failures; %d actual walking steps" % [checks,failures,moved])
	quit(1 if failures else 0)
