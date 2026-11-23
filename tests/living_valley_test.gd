extends SceneTree
## End-to-end checks of real controls, independent embryos and revisited places.
const Garden=preload("res://scripts/garden.gd")
const State=preload("res://scripts/garden_state.gd")
const Rules=preload("res://scripts/plant_adventure.gd")
const Locale=preload("res://scripts/localization.gd")
const DNA=preload("res://scripts/plant_dna.gd")
var game: Control
var checks: int=0
var failures: int=0
var path: String
var native: bool=false

func _initialize() -> void: call_deferred("run")

func check(value: bool,message: String) -> void:
	checks+=1
	if not value:
		failures+=1
		push_error("LIVING VALLEY: "+message)

func settle() -> void:
	for i in range(8): await process_frame

func find_action(node: Node,key: String,filter: Dictionary={}) -> Button:
	if node is Button and str(node.get_meta("adventure_action",""))==key:
		var matches: bool=true
		for property: String in filter:
			if str(node.get_meta(property,""))!=str(filter[property]): matches=false
		if matches: return node
	for child: Node in node.get_children():
		var found: Button=find_action(child,key,filter)
		if found!=null: return found
	return null

func press(key: String,filter: Dictionary={}) -> bool:
	var button: Button=find_action(game.modal if is_instance_valid(game.modal) else game,key,filter)
	check(button!=null and not button.disabled,"Actual control is available: "+key+" "+str(filter))
	if button==null or button.disabled: return false
	button.pressed.emit()
	await settle()
	return true

func snapshot(label: String) -> void:
	if not native: return
	game._localize_ui()
	await settle()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/living-valley-"+label+".png")

func bounds(context: String) -> void:
	var panel: Control=game.modal.get_node("Panel")
	var visible: Rect2=root.get_visible_rect()
	var rect: Rect2=panel.get_global_rect()
	check(rect.position.x>=-1 and rect.position.y>=-1 and rect.end.x<=visible.end.x+1 and rect.end.y<=visible.end.y+1,context+" fits viewport")
	check(game.modal_content.get_combined_minimum_size().x<=panel.size.x,context+" has no horizontal overflow")

func run() -> void:
	native=DisplayServer.get_name()!="headless"
	Locale.set_language("en")
	path="/tmp/plant_living_valley_%d.json" % Time.get_ticks_usec()
	game=Garden.new()
	game.state=State.new(path)
	root.size=Vector2i(1440,1000)
	root.content_scale_factor=1
	root.add_child(game)
	game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game.display_settings.enabled=false
	game.state.random.seed=20261123
	await settle()
	var original_age: float=float(game.state.get_plant(str(game.state.plant_order[0])).life_age)
	game._process(120)
	check(float(game.state.get_plant(str(game.state.plant_order[0])).life_age)==original_age,"Exploring or reading never ages plants against a hidden wall clock")
	game._open_adventure()
	await settle()
	check(game.adventure_field.WORLD_SIZE.x>=1900,"Connected valley contains several authored places")
	game._show_adventure_parent("river_fan")
	await settle()
	await press("observe",{"observation":"rain"})
	check(game.state.adventure.observations.river_fan.choices.has("rain"),"An actual plant behavior observation is saved")
	await press("collect")
	var fan: String=str(game.state.adventure.cuttings.river_fan)
	check(bool(game.state.adventure_capabilities(game.state.get_plant(fan)).canopy),"A founder's expressed leaf properties work immediately")
	game._show_adventure_use("stream",fan)
	await settle()
	await press("apply")
	check(not str(game.state.adventure.route).is_empty(),"A suitable plant makes the stream physically crossable without species or generation locks")
	game._adventure_back_to_field()
	for key: String in ["gripvine","moonbell"]: game.state.adventure_collect(key)
	var coil: String=str(game.state.adventure.cuttings.gripvine)
	var moon: String=str(game.state.adventure.cuttings.moonbell)
	game.adventure_field.refresh()
	for site: Dictionary in game.state.adventure_sites():
		var id: String=str(site.id)
		game.adventure_field.walk_to(game.adventure_field.discovery_position(id))
		for step in range(1300):
			game.adventure_field._process(0.06)
			if game.adventure_field._waypoints.is_empty(): break
		check(game.adventure_field.player_position.distance_to(game.adventure_field.discovery_position(id))<45,"Tap navigation reaches "+id+" at "+str(game.adventure_field.player_position)+"; remaining="+str(game.adventure_field._waypoints.size()))
		check(game.adventure_field.is_walkable(game.adventure_field.player_position),"Reached place has legal collision: "+id)
		var chosen: String=moon if id=="moth_garden" else fan
		var approach: String="glow" if id=="moth_garden" else "canopy"
		var before: int=game.state.seed_bank.size()
		if id=="seed_catch":
			game.state.set_lead_plant(fan)
			game.adventure_field.interact()
			await settle()
			check(not is_instance_valid(game.modal),"A useful traveling plant acts directly in the landscape without another menu")
		else:
			game._show_adventure_discovery(id,chosen)
			await settle()
			bounds(id)
			await press("try_discovery",{"approach":approach})
		check(bool(game.state.adventure_site(id).solved) and game.state.seed_bank.size()==before+1,"A successful experiment changes "+id+" and gives one real seed")
		game.state.adventure_discover(id,chosen,approach)
		check(game.state.seed_bank.size()==before+1,"Repeating "+id+" never duplicates a reward")
		game._adventure_back_to_field()
	var before_seeds: int=game.state.seed_bank.size()
	var before_light: int=int(game.state.resources.sunlight)
	var failed: Dictionary=game.state.adventure_discover("cistern",moon,"coil")
	check(bool(failed.ok) and not bool(failed.success),"An incompatible real phenotype produces an honest failed experiment")
	check(game.state.seed_bank.size()==before_seeds and int(game.state.resources.sunlight)==before_light,"An unsuccessful experiment costs no supplies")
	# Search actual independent births for a combination. The RNG is fixed only
	# for repeatable QA; no allele or inherited embryo is rewritten by this test.
	var combined: String=""
	var siblings: Array=[]
	for attempt in range(6):
		game._show_adventure_cross(fan,moon)
		await settle()
		await press("pollinate")
		var embryos: String=DNA.canonical(game.state.pollinations[fan].seeds)
		game._show_garden_day()
		await settle()
		var wake: Button=game.modal.find_children("*","Button",true,false).filter(func(b: Node): return b.has_meta("garden_day_action"))[0]
		wake.pressed.emit()
		await settle()
		check(DNA.canonical(game.state.pollinations[fan].seeds)==embryos,"A morning cannot reroll the offspring")
		await press("siblings")
		siblings=game.state.adventure.siblings.duplicate()
		game._show_garden_day()
		await settle()
		wake=game.modal.find_children("*","Button",true,false).filter(func(b: Node): return b.has_meta("garden_day_action"))[0]
		wake.pressed.emit()
		await settle()
		for id: String in siblings:
			var p: Dictionary=game.state.get_plant(id)
			check(bool(p.mature) and p.parents==[fan,moon],"A real independent descendant grows through the controls")
			var cap: Dictionary=game.state.adventure_capabilities(p)
			if bool(cap.canopy) and bool(cap.glow): combined=id
		if not combined.is_empty(): break
	check(not combined.is_empty(),"Real crosses produce a useful combined phenotype without forced outcomes")
	if not combined.is_empty():
		game._show_adventure_reveal(siblings)
		await settle()
		bounds("sibling reveal")
		await snapshot("siblings-en")
		game._show_adventure_experiments(combined)
		await settle()
		bounds("playground")
		await snapshot("playground-en")
		await press("weather",{"mode":"night"})
		await snapshot("playground-night-en")
		game._show_adventure_discovery("rain_nursery",combined)
		await settle()
		await press("try_discovery",{"approach":"canopy"})
		check(bool(game.state.adventure_site("rain_nursery").enhanced),"Returning with a combined offspring opens a night discovery")
		check(game.state.seed_bank.size()==before_seeds+1,"The night variant is a second real full-genome seed")
		await snapshot("night-discovery-en")
		game.state.adventure_discover("rain_nursery",fan,"canopy")
		check(bool(game.state.adventure_site("rain_nursery").enhanced),"A later basic placement preserves the night discovery")
		check(bool(game.adventure_field._site_combined("rain_nursery")),"Enhanced scenery persists through returning")
	game.state.save_game()
	var loaded:=State.new(path)
	check(loaded.load_game(),"The full valley, trials, real seedlings and old pedigree reload")
	check(loaded.adventure.rewarded_sites.size()==5,"All basic discoveries persist")
	check(loaded.adventure.get("position",[]).size()==2,"The actual valley walking position persists with discoveries")
	check(Rules.valid_adventure(loaded.adventure,loaded.plants),"Every placement keeps valid real-phenotype evidence")
	game._adventure_back_to_field()
	game.adventure_field.player_position=Vector2(930,940)
	game.adventure_field._update_camera()
	await snapshot("valley-en")
	Locale.set_language("zh_CN")
	root.size=Vector2i(390,780)
	await settle()
	game._responsive()
	game._show_adventure_discovery("cistern",coil)
	await settle()
	bounds("Chinese phone discovery")
	await snapshot("discovery-mobile-zh")
	game._show_adventure_experiments(fan)
	await settle()
	bounds("Chinese phone playground")
	await snapshot("playground-mobile-zh")
	game._adventure_back_to_field()
	for step in range(60):
		game.adventure_field._move(Vector2.LEFT if step%2==0 else Vector2.RIGHT,2)
		game.adventure_field._update_hint()
		check(game.adventure_field._title.text==Locale.text(game.adventure_field._place_name()),"Movement keeps the chosen language synchronously")
	await snapshot("valley-mobile-zh")
	# Even when a mother's last morning arrives, the bench must still expose
	# the exact fruit she made rather than silently switching to another plant.
	var final_cross: Dictionary=game.state.adventure_begin_cross(coil,moon)
	check(bool(final_cross.ok),"A final-life parent can still make a real cross")
	if bool(final_cross.ok):
		game.state.get_plant(coil).life_age=float(game.state.life_profile(coil).life_limit)-State.GARDEN_DAY_AGE
		var embryos: String=DNA.canonical(game.state.pollinations[coil].seeds)
		game.state.advance_garden_day()
		game._show_adventure_cross(coil,moon)
		await settle()
		check(bool(game.state.get_plant(coil).withered) and str(game.modal.get_meta("mother_id",""))==coil,"A withered mother remains visible while her real fruit is pending")
		check(DNA.canonical(game.state.pollinations[coil].seeds)==embryos,"The final morning preserves the fertilized offspring")
		await press("siblings")
		check(game.state.adventure.siblings.size()==2,"A mother's final hybrid fruit can still grow both siblings")
	game.queue_free()
	await process_frame
	for suffix: String in ["",".tmp",".audio.cfg"]:
		if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(path+suffix)
	var backup: String=path.get_basename()+".backup.json"
	if FileAccess.file_exists(backup): DirAccess.remove_absolute(backup)
	print("LIVING VALLEY: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
