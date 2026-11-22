extends SceneTree
## Real stream-adventure controls, real inherited siblings and physical routes.
## Each route uses an isolated silent garden; player saves stay untouched.
const Garden = preload("res://scripts/garden.gd")
const State = preload("res://scripts/garden_state.gd")
const DNA = preload("res://scripts/plant_dna.gd")
const Locale = preload("res://scripts/localization.gd")
const Display = preload("res://scripts/display_settings.gd")
var game: Control
var save_path: String
var checks: int=0
var failures: int=0
var home_genomes: String

func _initialize() -> void:
	call_deferred("run")

func check(value: bool,message: String) -> void:
	checks+=1
	if not value:
		failures+=1
		push_error("ADVENTURE UI: "+message)

func settle() -> void:
	for i in range(6): await process_frame

func within(rect: Rect2,bounds: Rect2) -> bool:
	return rect.position.x>=bounds.position.x-2 and rect.position.y>=bounds.position.y-2 and rect.end.x<=bounds.end.x+2 and rect.end.y<=bounds.end.y+2

func text_of(node: Node) -> String:
	return str(node.text) if node is Label or node is Button else node.get_class()

func overflow(node: Node,bounds: Rect2,result: Array[String]) -> void:
	if node is Control and node.is_visible_in_tree():
		var rect: Rect2=node.get_global_rect()
		if rect.position.x<bounds.position.x-2 or rect.end.x>bounds.end.x+2:
			result.append(text_of(node).left(42)+" "+str(rect))
		if node is ScrollContainer and node.horizontal_scroll_mode!=ScrollContainer.SCROLL_MODE_DISABLED: return
	for child: Node in node.get_children(): overflow(child,bounds,result)

func modal_bounds(context: String) -> void:
	check(is_instance_valid(game.modal),context+" opens a visible interaction")
	if not is_instance_valid(game.modal): return
	var panel: Control=game.modal.get_node("Panel")
	check(within(panel.get_global_rect(),root.get_visible_rect()),context+" panel fits the viewport: "+str(panel.get_global_rect())+" inside "+str(root.get_visible_rect()))
	var issues: Array[String]=[]
	overflow(panel,panel.get_global_rect(),issues)
	check(issues.is_empty(),context+" text and controls fit horizontally: "+"; ".join(issues.slice(0,5)))
	if game.adventuring:
		check(game.adventure_field.waiting,context+" pauses field walking while the interaction is open")
		var before: Vector2=game.adventure_field.player_position
		game.adventure_field._process(0.2)
		check(game.adventure_field.player_position==before,context+" a field update cannot move the player behind the panel")

func find_action(node: Node,action: String,filters: Dictionary={}) -> Button:
	if node is Button and str(node.get_meta("adventure_action",""))==action:
		var matches: bool=true
		for key: String in filters:
			if str(node.get_meta(key,""))!=str(filters[key]): matches=false
		if matches: return node
	for child: Node in node.get_children():
		var found: Button=find_action(child,action,filters)
		if found!=null: return found
	return null

func press(action: String,context: String,filters: Dictionary={}) -> bool:
	var button: Button=find_action(game.modal if is_instance_valid(game.modal) else game,action,filters)
	check(button!=null,context+" exposes the actual "+action+" control")
	if button==null:
		print("ADVENTURE ACTION MISSING: ",action," expected ",filters," in ",game.modal_kind," / ",game.modal.get_meta("cutting_key","") if is_instance_valid(game.modal) else "no modal")
		return false
	check(not button.disabled,context+" action is enabled")
	if button.disabled: return false
	button.pressed.emit()
	await settle()
	game._localize_ui()
	await settle()
	return true

func choose(action: String,id: String,context: String) -> bool:
	var picker: OptionButton=find_action(game.modal,action) as OptionButton
	check(picker!=null,context+" has a real plant selector")
	if picker==null: return false
	for index in range(picker.item_count):
		if str(picker.get_item_metadata(index))==id:
			picker.select(index)
			picker.item_selected.emit(index)
			await settle()
			return true
	check(false,context+" selector includes the intended canonical plant")
	return false

func genomes() -> String:
	var stable: Dictionary={}
	for id: String in game.state.plant_order:
		var p: Dictionary=game.state.get_plant(id)
		if int(str(id).trim_prefix("p"))>5: continue
		stable[id]=[p.genes,p.stats,p.parents,p.seed,p.get("lineage_mix",{}),p.get("skill_genes",{})]
	return DNA.canonical(stable)

func individual_record(id: String) -> String:
	var p: Dictionary=game.state.get_plant(id).duplicate(true)
	p.erase("life_age")
	return DNA.canonical(p)

func layout(language: String,dimensions: Vector2i) -> void:
	Locale.set_language(language)
	game.display_settings.enabled=false
	root.size=dimensions
	root.content_scale_factor=1
	await settle()
	game._responsive()
	game._localize_ui()
	await settle()

func new_garden(route: String) -> void:
	if is_instance_valid(game):
		game.queue_free()
		await process_frame
	Locale.set_language("en")
	save_path="/tmp/conservatory_adventure_ui_%s_%d.json" % [route,Time.get_ticks_usec()]
	game=Garden.new()
	game.state=State.new(save_path)
	root.add_child(game)
	game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game.display_settings=Display.new(save_path.get_basename()+".display.cfg")
	game.display_settings.configure(root,false)
	await layout("en",Vector2i(1440,1000))
	home_genomes=genomes()
	check(game.soundscape.preview_muted,"Adventure QA uses silent disposable gardens")
	check(await press("open","Adventure front door"),"The actual garden entry starts the stream adventure")
	check(game.adventuring and is_instance_valid(game.adventure_field),"Adventure opens a playable field")
	if is_instance_valid(game.modal): await press("return_field","Enter the shore")
	await settle()

func inspect(key: String) -> bool:
	if is_instance_valid(game.modal): await press("return_field","Return before exploring")
	game.adventure_field.walk_to(game.adventure_field.hotspot_position(key),"moonbell" if key=="moonbell" else "inspect_parent",key)
	for i in range(160):
		if is_instance_valid(game.modal): break
		game.adventure_field._process(0.15)
		await process_frame
	await settle()
	check(is_instance_valid(game.modal),"Walking to "+key+" reaches a real field interaction")
	return is_instance_valid(game.modal)

func collect(key: String) -> String:
	var before: int=game.state.plant_order.size()
	var supplies: String=DNA.canonical([game.state.resources,game.state.field_kits,game.state.seed_bank,game.state.market])
	if not await inspect(key): return ""
	modal_bounds("Meet "+key)
	if not await press("collect","Collect "+key,{"cutting_key":key}): return ""
	var info: Dictionary=game.state.adventure_info()
	var id: String=str(info.get("moonbell_id","")) if key=="moonbell" else str(info.cuttings.get(key,""))
	check(not id.is_empty() and game.state.owns_plant(id),"The cutting becomes one real owned "+key)
	check(game.state.plant_order.size()==before+1,"Collecting "+key+" adds exactly one individual")
	check(DNA.canonical([game.state.resources,game.state.field_kits,game.state.seed_bank,game.state.market])==supplies,"First adventure cutting costs no unrelated supplies")
	check(genomes()==home_genomes,"Collecting "+key+" preserves the existing garden DNA")
	return id

func grow_siblings(mother: String,father: String,context: String) -> Array[String]:
	game._show_adventure_cross(mother,father)
	await settle()
	check(await choose("mother",mother,context),context+" selects the intended mother")
	check(await choose("father",father,context),context+" selects the intended father")
	modal_bounds(context+" preview")
	var light: int=int(game.state.resources.sunlight)
	var plant_count: int=game.state.plant_order.size()
	if not await press("pollinate",context+" pollination"): return []
	check(int(game.state.resources.sunlight)==light-State.POLLINATION_COST,context+" spends the normal disclosed pollination cost")
	check(game.state.pollinations.has(mother),context+" fruit develops on the actual mother")
	if not game.state.pollinations.has(mother): return []
	var embryos: Array=game.state.pollinations[mother].seeds.duplicate(true)
	var spray: Dictionary=game.state.apply_care(mother,"ripening")
	check(spray.get("ok",false),context+" normal ripening spray makes its real fruit ready")
	game._show_adventure_cross(mother,father)
	await settle()
	light=int(game.state.resources.sunlight)
	if not await press("siblings",context+" harvest, extract and sow",{"mother_id":mother}): return []
	check(game.state.plant_order.size()==plant_count+2,context+" produces two actual sibling seedlings")
	check(int(game.state.resources.sunlight)==light+10,context+" applies30harvestlight and20plantinglight exactly")
	var children: Array[String]=[]
	for id: String in game.state.plant_order:
		var p: Dictionary=game.state.get_plant(id)
		if p.parents==[mother,father] and not bool(p.mature): children.append(id)
	check(children.size()==2,context+" both siblings retain the selected parent IDs")
	for i in range(children.size()):
		var p: Dictionary=game.state.get_plant(children[i])
		var matches: bool=false
		for seed: Dictionary in embryos:
			if DNA.profile(p).code==DNA.profile(seed.genome).code: matches=true
		check(matches,context+" sown sibling keeps an exact inherited embryo genome")
		check(game.state.apply_care(children[i],"sunlamp").get("ok",false),context+" normal sunshine lamp matures this exact seedling")
		check(game.state.get_plant(children[i]).mature,context+" same sibling becomes grown and usable")
	check(genomes()==home_genomes,context+" breeding leaves original home genomes unchanged")
	return children

func use_plant(id: String,goal: String,context: String) -> bool:
	game._show_adventure_use(goal,id)
	await settle()
	modal_bounds(context+" choose plant")
	if not await choose("choose_plant",id,context): return false
	var plant: String=individual_record(id)
	var inventory: String=DNA.canonical([game.state.plant_order,game.state.resources,game.state.seed_bank,game.state.field_kits,game.state.market])
	if not await press("apply",context,{"plant_id":id,"goal":goal}): return false
	check(individual_record(id)==plant,context+" keeps the actual plant and complete DNA")
	check(DNA.canonical([game.state.plant_order,game.state.resources,game.state.seed_bank,game.state.field_kits,game.state.market])==inventory,context+" uses a cutting without consuming owned plants or supplies")
	return true

func route_flow(route: String) -> void:
	await new_garden(route)
	check(not game.adventure_field.is_walkable(Vector2(650,420)),"The unbridged stream physically blocks crossing")
	check(not game.adventure_field.is_walkable(Vector2(1090,420)),"The unrevealed courtyard physically blocks entry")
	var cuttings: Dictionary={}
	for key: String in ["river_fan","floatcap","gripvine","stone_root"]:
		cuttings[key]=await collect(key)
	var mother: String=str(cuttings.get("river_fan" if route=="raft" else "gripvine",""))
	var father: String=str(cuttings.get("floatcap" if route=="raft" else "stone_root",""))
	if mother.is_empty() or father.is_empty(): return
	game.state.random.seed=5102026
	var children: Array[String]=await grow_siblings(mother,father,route+" G2")
	if children.is_empty(): return
	var child: String=children[0]
	check(game.state.adventure_preview(child,"stream").get("eligible",false),"Real "+route+" offspring has the required inherited exploration ability")
	if not await use_plant(child,"stream",route+" stream crossing"): return
	check(str(game.state.adventure_info().route)==route,"Using "+route+" permanently builds its physical crossing")
	if is_instance_valid(game.modal): await press("return_field","See the living crossing")
	game.adventure_field.refresh()
	await settle()
	check(game.adventure_field.is_walkable(Vector2(650,420)),"The new "+route+" opens the actual water corridor")
	var bell: String=await collect("moonbell")
	if bell.is_empty(): return
	check(str(game.state.adventure_info().stage)=="lantern","Island discovery offers a second-generation breeding goal")
	var glowing: String=""
	for attempt in range(2):
		game.state.random.seed=(4 if route=="raft" else 2) if attempt==0 else 1
		var a: String=bell if attempt==0 else children[1]
		var b: String=child if attempt==0 else bell
		var next: Array[String]=await grow_siblings(a,b,route+" G3 attempt%d" % attempt)
		for id: String in next:
			if game.state.adventure_preview(id,"lantern").get("eligible",false): glowing=id;break
		if not glowing.is_empty(): break
		if not next.is_empty():
			game._show_adventure_use("lantern",next[0])
			await settle()
			var blocked: Button=find_action(game.modal,"apply",{"plant_id":next[0],"goal":"lantern"})
			check(blocked!=null and blocked.disabled,"An unlit grown G3 cannot falsely light the courtyard")
			check(str(game.state.adventure_preview(next[0],"lantern").reason).contains("Soft Glow"),"Unlit offspring give the real inherited-glow goal for the next cross")
	check(not glowing.is_empty(),"Actual Moonbell descendants can inherit the courtyard-opening glow")
	if glowing.is_empty(): return
	check(int(game.state.get_plant(glowing).generation)>=3,"The second discovery uses a real G3 or later descendant")
	if not await use_plant(glowing,"lantern",route+" lantern discovery"): return
	check(str(game.state.adventure_info().stage)=="restored","A glowing descendant permanently reveals the courtyard")
	if is_instance_valid(game.modal): await press("return_field","Walk into the restored courtyard")
	game.adventure_field.refresh()
	await settle()
	check(game.adventure_field.is_walkable(Vector2(1090,420)),"The restored courtyard is physically accessible")
	for view: Array in [["en",Vector2i(1440,1000),"English desktop"],["zh_CN",Vector2i(1440,1000),"Chinese desktop"],["en",Vector2i(390,780),"English phone"],["zh_CN",Vector2i(390,780),"Chinese phone"]]:
		await layout(str(view[0]),view[1])
		game._show_adventure_cross(child,bell)
		await settle()
		modal_bounds(str(view[2])+" cross preview")
		game._show_adventure_use("lantern",glowing)
		await settle()
		modal_bounds(str(view[2])+" inherited ability")
		if is_instance_valid(game.modal): await press("return_field",str(view[2])+" field return")
		var field_bounds: Rect2=game.adventure_field.get_global_rect()
		check(within(field_bounds,root.get_visible_rect()),str(view[2])+" adventure field fits its viewport")
		game.adventure_field._process(0.05)
		for label: Control in [game.adventure_field._target_label,game.adventure_field._hint_label,game.adventure_field._interact_button,game.adventure_field._breed_button]:
			var source: String=str(label.get_meta("_locale_source_text",label.text))
			check(label.text==Locale.text(source),str(view[2])+" field updates retain the selected language without a later translation pass")
	game.state.save_game()
	var restored=State.new(save_path)
	check(restored.load_game(),route+" adventure reloads through the normal archive")
	check(DNA.canonical(restored.adventure)==DNA.canonical(game.state.adventure),route+" crossing, island discoveries and courtyard persist exactly")
	check(DNA.profile(restored.get_plant(glowing)).code==DNA.profile(game.state.get_plant(glowing)).code,route+" the usable G3 genome survives save and reload")
	check(genomes()==home_genomes,route+" complete adventure preserves the starting collection's inherited DNA")
	game._return_from_adventure()
	await settle()
	check(not game.adventuring and game.ui_margin.visible,route+" returns to the same living garden")
	game.queue_free()
	await process_frame
	for suffix: String in [".json",".backup.json",".audio.cfg",".display.cfg"]: DirAccess.remove_absolute(save_path.get_basename()+suffix)

func run() -> void:
	await route_flow("raft")
	await route_flow("vine")
	Locale.set_language("en")
	print("ADVENTURE INTEGRATION TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
