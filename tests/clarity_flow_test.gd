extends SceneTree
## Real UI flow: understand a garden, plan, pollinate, choose and replant.
## Uses a silent temporary archive and never reads the player's seed vault.
const Main=preload("res://scripts/main.gd")
const Levels=preload("res://scripts/levels.gd")
const Genome=preload("res://scripts/genome.gd")
const Save=preload("res://scripts/save_data.gd")
var game
var path: String
var failures: int=0
var checks: int=0
var native: bool=false

func _initialize() -> void: call_deferred("run")

func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error("CLARITY FLOW: "+message)

func settle() -> void:
	for frame in range(8): await process_frame

func action(key: String) -> Button:
	for node: Node in game.ui_root.find_children("*","Button",true,false):
		if str(node.get_meta("game_action",""))==key and node.is_visible_in_tree(): return node
	return null

func press(key: String) -> void:
	var button: Button=action(key)
	check(button!=null and not button.disabled,"Actual action available: "+key)
	if button!=null and not button.disabled: button.pressed.emit()
	await settle()

func capture(name: String) -> void:
	if not native: return
	await create_timer(0.4).timeout
	await settle()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/clarity-"+name+".png")

func seed_grid_fits(context: String) -> void:
	var scrolls: Array=game.overlay.find_children("*","ScrollContainer",true,false)
	check(not scrolls.is_empty(),context+" has a scrollable seed collection")
	if scrolls.is_empty(): return
	var scroll: ScrollContainer=scrolls[0]
	var grid: GridContainer=scroll.get_child(0)
	check(grid.get_combined_minimum_size().x<=scroll.size.x,context+" never clips seed columns horizontally")
	check(grid.get_child_count()==game.save.seeds.size(),context+" keeps every saved seed selectable")
	for node: Node in game.overlay.find_children("*","Button",true,false):
		if str(node.get_meta("game_action","")) in ["plant_selected","replant_selected"]:
			check(root.get_visible_rect().encloses(node.get_global_rect()),context+" keeps its explicit planting action visible")

func run() -> void:
	native=DisplayServer.get_name()!="headless"
	path="/tmp/bloomward_clarity_%d.json" % Time.get_ticks_usec()
	root.size=Vector2i(1600,1000)
	game=Main.new()
	game.save_path=path
	game.quiet_preview=true
	root.add_child(game)
	await settle()
	game.breeding_random.seed=401
	check(game.save.path==path and game.sfx.muted,"QA owns an isolated, silent vault")
	game.show_level_intro(2)
	await settle()
	check(str(game.seed_selection_label.text).contains("Thorns"),"Seed preparation names the exact missing gift")
	check(str(game.seed_plan_label.text).contains("Spinebrush"),"Seed preparation says where the missing gift comes from")
	check(game.session.def.id=="demo","Selecting a seed does not silently start an attempt")
	seed_grid_fits("Seed preparation")
	await capture("01-seed-plan")
	await press("plant_selected")
	check(game.paused and game.mode=="play","Planting begins in a readable planning phase")
	var nodes: int=game.session.plant.pos.size()
	game._process(1.0)
	check(game.session.plant.pos.size()==nodes,"The plant waits while the player plans")
	check(game.hud_progress.text.contains("0 / 1"),"The actual win condition has a persistent count")
	check(game.hud_hint.text.contains("Spinebrush"),"Live guidance prioritizes obtaining a missing gift")
	game._toggle_hint()
	check(game.view.world_labels.focused_kind=="wild" and game.view.world_labels.focused_index==0,"Show me highlights the actual donor, without changing the puzzle")
	await capture("02-live-objective")
	game._place_lure(Vector2(330,520))
	check(game.session.world.lures.size()==1 and game.paused,"Lures can be arranged before growth starts")
	var tools: int=game.session.tools_used
	game._place_lure(Vector2(-40,500))
	check(game.session.tools_used==tools,"Invalid out-of-garden placement costs nothing")
	await press("growth")
	var attempts: int=0
	while game.pending_cross.is_empty() and attempts<1800 and not game.session.stuck():
		game._process(1.0/30)
		attempts+=1
	check(not game.pending_cross.is_empty(),"A real shoot reaches and pollinates Spinebrush")
	check(game.save.seeds.size()==4,"All three real offspring are saved at contact")
	var reloaded:=Save.new(path)
	check(reloaded.seeds.size()==4,"Leaving before the reveal cannot lose the earned seeds")
	var fruit: Dictionary=game.pending_cross[0] if not game.pending_cross.is_empty() else {}
	var parent: Dictionary=game.current_seed.duplicate(true)
	if not fruit.is_empty():
		game._show_cross()
		await settle()
		check(game.current_seed==parent and int(game.session.plant.genome.thorns)==0,"Pollination does not pretend to upgrade the growing parent")
		check(action("replant_child")!=null,"Each child has an explicit replant action")
		for node: Node in game.overlay.find_children("*","Button",true,false):
			if str(node.get_meta("game_action",""))=="replant_child":
				check(root.get_visible_rect().encloses(node.get_global_rect()) and node.get_global_rect().end.y<action("keep_current").get_global_rect().position.y,"A child's replant action fits above the keep-current footer")
		await capture("03-cross-replant")
		game._close_overlay()
	game.show_map()
	await create_timer(1.6).timeout
	check(game.mode=="map","A delayed reveal cannot steal focus from the map")
	game._start_level(2,Levels.starter(),true)
	game._update_guidance()
	check(game.guide_button.text=="Choose seed","A useful saved child is recommended instead of repeating the same cross")
	game._toggle_hint()
	await settle()
	seed_grid_fits("In-garden vault")
	check(int(game.selected_seed.thorns)>0,"Vault recommends an actual seed carrying the required gift")
	await capture("04-ready-seed")
	var selected: Dictionary=game.selected_seed.duplicate(true)
	await press("replant_selected")
	check(game.paused and game.current_seed==selected,"Replant starts a fresh planned attempt with the exact selected genome")
	check(int(game.session.plant.genome.thorns)>0 and game.session.lures_left==1,"The real new plant has Thorns and the attempt's tools reset")
	check(game.hud_progress.text.contains("0 / 1") and game.hud_hint.text.contains("sunwell"),"Guidance moves from breeding to reaching the goal")
	# Ensure a larger vault still fits, including six-gift seeds and variants.
	for species: String in Levels.SPECIES: game.save.add_seed(Levels.wild(species))
	game.show_level_intro(7)
	await settle()
	seed_grid_fits("Large vault")
	await capture("05-large-vault")
	# The vault preserves meaningful sibling differences despite matching names.
	var a: Dictionary=Levels.starter().duplicate(true)
	a.name="Sibling"
	var b: Dictionary=a.duplicate(true)
	b.hue=0.8
	var before: int=game.save.seeds.size()
	game.save.add_seed(a)
	game.save.add_seed(b)
	check(game.save.seeds.size()==before+2,"Equal names and gifts cannot erase a different pigment genome")
	game.save.add_seed(b.duplicate(true))
	check(game.save.seeds.size()==before+2,"The identical genome still deduplicates")
	# A won attempt earns its stars immediately; its delayed popup cannot
	# announce victory over a newly restarted attempt at the same garden.
	game._start_level(0,Levels.starter())
	attempts=0
	while not game.session.won() and attempts<2700:
		game._process(1.0/30)
		attempts+=1
	check(game.session.won(),"The original First Light puzzle remains solvable")
	check(game.save.star_count("first_light")>=1,"Stars are saved when earned, before the animation ends")
	game._start_level(0,Levels.starter(),true)
	await create_timer(2.4).timeout
	check(game.overlay==null and not game.session.won() and game.paused,"An old victory timer cannot overwrite a restarted garden")
	await capture("06-first-light-plan")
	game.queue_free()
	await process_frame
	if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	print("CLARITY FLOW: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
