extends SceneTree
## A new gardener should be able to tap soil, choose a real seed, review where
## it will grow, and see that exact individual appear in the chosen plot.
const Garden = preload("res://scripts/garden.gd")
const State = preload("res://scripts/garden_state.gd")
const DNA = preload("res://scripts/plant_dna.gd")
const Locale = preload("res://scripts/localization.gd")
var game: Control
var checks: int = 0
var failures: int = 0
var save_path: String

func _initialize() -> void:
	call_deferred("run")

func check(value: bool,message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("PLANTING UI: "+message)

func settle() -> void:
	for i in range(6): await process_frame

func find_action(node: Node,action: String,filters: Dictionary = {}) -> Button:
	if node is Button and str(node.get_meta("planting_action",""))==action:
		var matches: bool = true
		for key: String in filters:
			if DNA.canonical(node.get_meta(key,""))!=DNA.canonical(filters[key]): matches = false
		if matches: return node
	for child in node.get_children():
		var found: Button = find_action(child,action,filters)
		if found!=null: return found
	return null

func find_meta(node: Node,key: String,value: Variant) -> Node:
	if node.has_meta(key) and DNA.canonical(node.get_meta(key))==DNA.canonical(value): return node
	for child in node.get_children():
		var found: Node = find_meta(child,key,value)
		if found!=null: return found
	return null

func text_in(node: Node) -> String:
	if node is Control and not node.is_visible_in_tree(): return ""
	var result: String = str(node.text) if node is Label or node is Button else ""
	for child in node.get_children(): result += "\n"+text_in(child)
	return result

func within(rect: Rect2,bounds: Rect2) -> bool:
	return rect.position.x>=bounds.position.x-2 and rect.position.y>=bounds.position.y-2 and rect.end.x<=bounds.end.x+2 and rect.end.y<=bounds.end.y+2

func overflow(node: Node,bounds: Rect2,result: Array[String]) -> void:
	if node is Control and node.is_visible_in_tree():
		var rect: Rect2 = node.get_global_rect()
		if rect.position.x<bounds.position.x-2 or rect.end.x>bounds.end.x+2:
			var detail: String = node.get_class()
			if node is Label or node is Button: detail += " "+str(node.text).left(45)
			result.append(detail+" "+str(rect))
		if node is ScrollContainer and node.horizontal_scroll_mode!=ScrollContainer.SCROLL_MODE_DISABLED: return
	for child in node.get_children(): overflow(child,bounds,result)

func check_bounds(context: String) -> void:
	check(is_instance_valid(game.modal),context+" has a visible planting step")
	if not is_instance_valid(game.modal): return
	var panel: Control = game.modal.get_node("Panel")
	check(within(panel.get_global_rect(),root.get_visible_rect()),context+" modal fits the viewport")
	var issues: Array[String] = []
	overflow(panel,panel.get_global_rect(),issues)
	check(issues.is_empty(),context+" content fits horizontally: "+"; ".join(issues.slice(0,6)))
	var confirm: Button = find_action(game.modal,"plant_seed")
	if confirm!=null: check(within(confirm.get_global_rect(),panel.get_global_rect()),context+" keeps the final planting action visible")

func stable_state() -> String:
	var organisms: Dictionary = game.state.plants.duplicate(true)
	for id: String in organisms: organisms[id].erase("life_age")
	return DNA.canonical([organisms,game.state.plant_order,game.state.bed,game.state.display_bed,game.state.seed_bank,game.state.fruit_inventory,game.state.pollinations,game.state.fruit_crops,game.state.resources,game.state.random.state,game.state.id_counter,game.state.market_wallet()])

func press(action: String,filters: Dictionary,context: String) -> bool:
	var button: Button = find_action(game.modal,action,filters)
	check(button!=null,context+" offers its real action control")
	if button==null: return false
	check(not button.disabled,context+" action is available")
	if button.disabled: return false
	button.pressed.emit()
	await settle()
	return true

func tap_plot(index: int,context: String) -> void:
	game._close_modal()
	game.selected_id = ""
	game.moving = false
	game._refresh()
	await settle()
	var cell: Control = game.bed_grid.get_child(index)
	check(cell.plant.is_empty(),context+" starts at visibly empty soil")
	check(not cell.title_label.text.is_empty() and not cell.meta_label.text.is_empty(),context+" empty soil gives a visible planting invitation")
	var before: String = stable_state()
	cell.chosen.emit("","bed",index)
	await settle()
	check(game.modal_kind=="planting",context+" tapping the real empty soil opens the seed selector")
	check(stable_state()==before,context+" opening the selector changes no seeds, genes, IDs or resources")
	check_bounds(context+" seed selector")

func select_seed(reference: Variant,index: int,context: String) -> bool:
	var before: String = stable_state()
	if not await press("choose_seed",{"seed_ref":reference,"bed_index":index},context+" seed choice"): return false
	check(game.modal_kind=="planting_confirm",context+" choosing a seed opens a clear final review")
	check(stable_state()==before,context+" reviewing the chosen seed never plants or rerolls it")
	var confirm: Button = find_action(game.modal,"plant_seed",{"seed_ref":reference,"bed_index":index})
	check(confirm!=null,context+" review preserves the exact seed and chosen soil location")
	var shown: String = text_in(game.modal)
	check(shown.contains("10") and shown.contains("12"),context+" shows the actual ten-light cost and twelve-second growth time")
	check_bounds(context+" final review")
	return confirm!=null

func run() -> void:
	Locale.set_language("en")
	root.size = Vector2i(1440,1000)
	save_path = "/tmp/conservatory_planting_ui_%d.json" % Time.get_ticks_usec()
	game = Garden.new()
	game.state = State.new(save_path)
	root.add_child(game)
	game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await settle()
	game.state.resources.sunlight = 500
	var a: String = str(game.state.plant_order[0])
	var b: String = str(game.state.plant_order[1])
	check(bool(game.state.pollinate(a,b).ok),"Planting fixture begins with a real cross")
	game.state.pollinations[a].ready_at = 0
	game.state.fruit_crops[a].natural_ready_at = int(Time.get_unix_time_from_system())+3600
	game.state.harvest_fruit(a)
	game.state.extract_seeds(str(game.state.fruit_inventory.back().id))
	var seed_index: int = game.state.seed_bank.size()-2
	var seed: Dictionary = game.state.seed_bank[seed_index].duplicate(true)
	var reference: Variant = game.state.market_ref("seed",seed_index)
	game.state.save_game()
	var target: int = 4
	check(game.state.bed.find("")==0 and str(game.state.bed[target]).is_empty(),"The chosen plot differs from the first available plot")
	await tap_plot(target,"Desktop empty soil")
	if await select_seed(reference,target,"Hybrid seed"):
		var before: String = stable_state()
		if await press("back",{},"Return from planting review") and await press("cancel",{},"Cancel seed choice"):
			check(stable_state()==before,"Canceling keeps the seed, selected plot, light, IDs and RNG intact")
		await tap_plot(target,"Return to chosen soil")
		if await select_seed(reference,target,"Reviewed hybrid seed"):
			await check_actual_sowing(reference,target,seed)
	await check_failures()
	await check_localized_layouts()
	game.queue_free()
	await settle()
	Locale.set_language("en")
	for path: String in [save_path,save_path.get_basename()+".backup.json",save_path.get_basename()+".audio.cfg",save_path.get_basename()+".language.cfg"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	print("PLANTING INTEGRATION TESTS: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)

func find_care_entry(node: Node,id: String) -> Button:
	if node is Button and node.get_meta("reproduction_action","")=="open_care" and str(node.get_meta("plant_id",""))==id: return node
	for child in node.get_children():
		var found: Button = find_care_entry(child,id)
		if found!=null: return found
	return null

func check_actual_sowing(reference: Variant,target: int,seed: Dictionary) -> void:
	var seed_count: int = game.state.seed_bank.size()
	var earlier: Dictionary = game.state.plant_seed_at(game.state.market_ref("seed",0),0)
	check(bool(earlier.ok),"Sowing an earlier seed elsewhere genuinely shifts this reviewed seed's former index")
	var before_count: int = game.state.plant_order.size()
	var light: int = int(game.state.resources.sunlight)
	if not await press("plant_seed",{"seed_ref":reference,"bed_index":target},"Plant reviewed seed in chosen soil"): return
	check(game.modal_kind=="planted","Successful sowing explains what just appeared instead of leaving the player in the seed bank")
	var id: String = str(game.modal.get_meta("planted_id",""))
	check(not id.is_empty() and str(game.state.bed[target])==id,"The newly revealed individual occupies the exact tapped soil cell")
	check(int(game.modal.get_meta("bed_index",-1))==target and str(game.state.bed[0])==str(earlier.get("plant_id","")),"Planting never falls back to the first available plot or replaces the earlier seedling")
	check(game.state.plant_order.size()==before_count+1 and game.state.seed_bank.size()==seed_count-2,"Only the earlier sown seed and the reviewed seed are consumed, creating one individual each")
	check(int(game.state.resources.sunlight)==light-10,"The final planting action spends exactly the reviewed ten light")
	var plant: Dictionary = game.state.get_plant(id)
	if plant.is_empty(): return
	check(not bool(plant.mature) and int(plant.ready_at)-int(Time.get_unix_time_from_system())<=12 and int(plant.ready_at)>int(Time.get_unix_time_from_system()),"The selected plant starts as a real twelve-second seedling")
	check(DNA.canonical(plant.genes)==DNA.canonical(seed.genome.genes) and DNA.canonical(plant.stats)==DNA.canonical(seed.genome.stats),"A full-genome seed produces its exact inherited traits and stats")
	check(plant.parents==seed.genome.parents and DNA.canonical(plant.get("gene_sources",{}))==DNA.canonical(seed.genome.get("gene_sources",{})),"The new seedling keeps the exact parents and per-gene origins")
	check(str(game.selected_id)==id,"The newly planted individual becomes the selected plant")
	check(find_meta(game.modal,"planting_countdown",true)!=null,"The success view gives a live growth countdown")
	check(find_action(game.modal,"care")!=null,"The success view points to useful care for the new plant")
	check_bounds("Newly planted seedling")
	game.state.save_game()
	var restored = State.new(save_path)
	check(restored.load_game() and str(restored.bed[target])==id,"Reload keeps the exact new plant in its chosen plot")
	check(DNA.canonical(restored.get_plant(id).genes)==DNA.canonical(seed.genome.genes),"Reload keeps the planted seed's inherited genome")
	if await press("watch_grow",{},"Watch the new seedling grow"):
		check(not is_instance_valid(game.modal),"Watching growth returns to the actual garden")
		var cell: Control = game.bed_grid.get_child(target)
		check(str(cell.plant.get("id",""))==id and bool(cell.selected),"The actual chosen soil cell highlights the new seedling")
		check(cell.meta_label.text.contains("Growing") and bool(cell.meta_label.get_meta("plant_growth_label",false)),"The garden cell shows its own growing countdown")
		var care: Button = find_care_entry(game,id)
		check(care!=null,"The selected seedling exposes its own actual care entry")
		if care!=null:
			care.pressed.emit()
			await settle()
			check(game.modal_kind=="care" and str(game.modal.get_meta("care_plant_id",""))==id,"The care entry targets the seedling that was just planted")
			var lamp: Button = find_meta(game.modal,"care_tool","sunlamp") as Button
			check(lamp!=null and not lamp.disabled,"The new seedling can use its actual sunshine lamp")
			if lamp!=null and not lamp.disabled:
				light = int(game.state.resources.sunlight)
				lamp.pressed.emit()
				await settle()
				check(bool(plant.mature) and int(game.state.resources.sunlight)==light-5,"The lamp matures that exact planted seedling for five light")
				check(str(game.state.bed[target])==id and DNA.canonical(plant.genes)==DNA.canonical(seed.genome.genes),"Fast maturation preserves the chosen plot and inherited genome")
	game._close_modal()
	game._refresh()
	await settle()

func check_failures() -> void:
	var reference: Variant = game.state.market_ref("seed",0)
	var light: int = int(game.state.resources.sunlight)
	game.state.resources.sunlight = 9
	await tap_plot(2,"Low-light soil")
	if await select_seed(reference,2,"Low-light seed review"):
		var confirm: Button = find_action(game.modal,"plant_seed")
		check(confirm!=null and confirm.disabled,"Insufficient light visibly disables sowing")
		var before: String = stable_state()
		if confirm!=null: confirm.pressed.emit()
		await settle()
		check(stable_state()==before,"A low-light race cannot consume a seed, allocate an ID, or charge light")
	game.state.resources.sunlight = light
	await tap_plot(3,"Soil that becomes occupied")
	if await select_seed(reference,3,"Occupied-target seed review"):
		var mature: String = str(game.state.plant_order[0])
		check(bool(game.state.place_in_bed(mature,3)),"Another mature specimen can occupy the previously chosen plot")
		var before: String = stable_state()
		var confirm: Button = find_action(game.modal,"plant_seed")
		if confirm!=null: confirm.pressed.emit()
		await settle()
		check(stable_state()==before and str(game.state.bed[3])==mature,"An occupied target never redirects planting to another plot or replaces its plant")
	await tap_plot(5,"Soil for a seed that leaves inventory")
	if await select_seed(reference,5,"Stale-seed review"):
		var other: int = game.state.bed.find("")
		check(other>=0 and other!=5 and bool(game.state.plant_seed_at(reference,other).ok),"The reviewed seed can be legitimately consumed at a different plot")
		var before: String = stable_state()
		var confirm: Button = find_action(game.modal,"plant_seed")
		if confirm!=null: confirm.pressed.emit()
		await settle()
		check(stable_state()==before and str(game.state.bed[5]).is_empty(),"A stale seed reference cannot plant an adjacent seed that shifts into its old slot")
	for index in range(game.state.bed.size()):
		if not str(game.state.bed[index]).is_empty(): continue
		var p: Dictionary = game.state._create_base(0,91760+index)
		game.state._add_plant(p)
		game.state.place_in_bed(str(p.id),index)
	game._close_modal()
	game._refresh()
	await settle()
	var before: String = stable_state()
	var open: Button = find_action(game,"open")
	check(open!=null,"A full garden still exposes the planting help entry")
	if open!=null:
		open.pressed.emit()
		await settle()
		check(stable_state()==before,"Opening planting help with a full garden changes no inventory or resource")
		var confirm: Button = find_action(game.modal,"plant_seed")
		check(confirm==null or confirm.disabled,"A full garden cannot silently sow into an occupied plot")
		var shown: String = text_in(game.modal).to_lower()
		check(shown.contains("full") or shown.contains("space") or shown.contains("empty"),"A full garden plainly explains why no seed can be planted")
		check_bounds("Full garden planting guidance")

func check_localized_layouts() -> void:
	game.state.bench(str(game.state.bed[2]))
	for config: Array in [["en",Vector2i(1440,1000)],["zh_CN",Vector2i(390,780)],["en",Vector2i(390,780)],["zh_CN",Vector2i(1440,1000)]]:
		Locale.set_language(str(config[0]))
		root.size = config[1]
		game._close_modal()
		game._refresh()
		await settle()
		var before: String = stable_state()
		check(within(game.root_column.get_global_rect(),root.get_visible_rect()),str(config[0])+" garden keeps the planting controls and soil inside the viewport")
		var entry: Button = find_action(game,"open")
		check(entry!=null and entry.is_visible_in_tree() and within(entry.get_global_rect(),root.get_visible_rect()),str(config[0])+" planting button is directly reachable in "+str(config[1]))
		if entry==null: continue
		entry.pressed.emit()
		game._localize_ui()
		await settle()
		check(game.modal_kind=="planting",str(config[0])+" main Plant button opens the visual seed selector")
		check_bounds(str(config[0])+" "+str(config[1])+" planting selector")
		var reference: Variant = game.state.market_ref("seed",0)
		var target: int = int(game.modal.get_meta("bed_index",-1))
		check(target==2,"The Plant button proposes the actual empty plot after earlier cells are filled")
		if await select_seed(reference,target,str(config[0])+" planting review"):
			game._localize_ui()
			await settle()
			check_bounds(str(config[0])+" "+str(config[1])+" planting review")
			if str(config[0])=="zh_CN":
				var shown: String = text_in(game.modal)
				check(shown.contains("种子") and shown.contains("光照") and not shown.contains("Plant here"),"Chinese planting explains the seed, cost and final action in Chinese")
			await press("back",{},str(config[0])+" choose a different seed")
			check(game.modal_kind=="planting",str(config[0])+" Back returns to seed choice")
			await press("cancel",{},str(config[0])+" close planting")
		check(stable_state()==before,"Browsing and canceling "+str(config[0])+" planting never consumes seeds, light or RNG")
