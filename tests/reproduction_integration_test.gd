extends SceneTree
## Exercise real controls through repeated pollination, fruit harvest, seed
## extraction and sowing. Time is advanced in the temporary model, not by sleeps.
const Garden = preload("res://scripts/garden.gd")
const State = preload("res://scripts/garden_state.gd")
const Locale = preload("res://scripts/localization.gd")
const DNA = preload("res://scripts/plant_dna.gd")
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
		push_error("REPRODUCTION UI: "+message)

func settle() -> void:
	for i in range(6): await process_frame

func within(rect: Rect2,bounds: Rect2) -> bool:
	return rect.position.x>=bounds.position.x-2 and rect.position.y>=bounds.position.y-2 and rect.end.x<=bounds.end.x+2 and rect.end.y<=bounds.end.y+2

func overflow(node: Node,bounds: Rect2,result: Array[String]) -> void:
	if node is Control and node.is_visible_in_tree():
		var rect: Rect2 = node.get_global_rect()
		if rect.position.x<bounds.position.x-2 or rect.end.x>bounds.end.x+2:
			var description: String = node.get_class()
			if node is Label or node is Button: description += " '%s'" % str(node.text).left(44)
			result.append(description+" "+str(rect))
		if node is ScrollContainer and node.horizontal_scroll_mode!=ScrollContainer.SCROLL_MODE_DISABLED: return
	for child in node.get_children(): overflow(child,bounds,result)

func modal_bounds(context: String) -> void:
	check(is_instance_valid(game.modal),context+" has a visible interaction")
	if not is_instance_valid(game.modal): return
	var panel: Control = game.modal.get_node("Panel")
	check(within(panel.get_global_rect(),root.get_visible_rect()),context+" panel fits its viewport")
	var problems: Array[String] = []
	overflow(panel,panel.get_global_rect(),problems)
	check(problems.is_empty(),context+" controls fit horizontally: "+"; ".join(problems.slice(0,6)))

func find_action(node: Node,action: String,filters: Dictionary = {}) -> Button:
	if node is Button and str(node.get_meta("reproduction_action",""))==action:
		var matching: bool = true
		for key: String in filters:
			if str(node.get_meta(key,""))!=str(filters[key]): matching = false
		if matching: return node
	for child in node.get_children():
		var found: Button = find_action(child,action,filters)
		if found!=null: return found
	return null

func press_action(action: String,filters: Dictionary,context: String) -> bool:
	var button: Button = find_action(game.modal,action,filters)
	check(button!=null,context+" exposes its actual action control")
	if button==null: return false
	check(not button.disabled,context+" action is enabled")
	if button.disabled: return false
	button.pressed.emit()
	await settle()
	return true

func choose_parent(which: int,id: String) -> void:
	var picker: OptionButton = game.lab_pick_a if which==0 else game.lab_pick_b
	var index: int = -1
	for i in range(picker.item_count):
		if str(picker.get_item_metadata(i))==id: index = i
	check(index>=0,"Every mature plant, including later hybrids, appears in parent selector %d" % which)
	if index<0: return
	picker.select(index)
	picker.item_selected.emit(index)
	await settle()
	check((game.parent_a if which==0 else game.parent_b)==id,"Parent selector preserves canonical ID "+id)

func restored_model() -> RefCounted:
	var restored = State.new(save_path)
	check(restored.load_game(),"Current reproduction archive reloads")
	return restored

func nursery_tab(tab: String,context: String) -> void:
	game._open_seeds()
	await settle()
	if game.nursery_tab!=tab:
		await press_action("nursery_tab",{"nursery_tab":tab},context+" tab")
	check(game.nursery_tab==tab,context+" opens the intended nursery section")

func make_generation(mother: String,father: String,generation: int,context: String) -> String:
	game._close_modal()
	game.lab_mode = "Crossbreed"
	game._open_lab()
	await settle()
	await choose_parent(0,mother)
	await choose_parent(1,father)
	modal_bounds(context+" parents")
	var before_count: int = game.state.plants.size()
	var light_before: int = int(game.state.resources.sunlight)
	if not await press_action("pollinate",{},context+" pollination"): return ""
	check(game.state.plants.size()==before_count,context+" fertilization keeps embryos out of the owned archive")
	check(game.state.pollinations.has(mother),context+" grows fruit on the exact maternal plant")
	check(int(game.state.resources.sunlight)==light_before-State.POLLINATION_COST,context+" spends the disclosed pollination cost once")
	if not game.state.pollinations.has(mother): return ""
	var batch: Dictionary = game.state.pollinations[mother]
	check(str(batch.father_id)==father and int(batch.generation)==generation,context+" fruit records both selected parents and generation")
	var stored_batch: RefCounted = restored_model()
	check(stored_batch.pollinations[mother].seeds==batch.seeds,context+" unripe fruit keeps exact embryos across reload")
	game.state.pollinations[mother].ready_at = 0
	await nursery_tab("plants",context+" ripe plants")
	modal_bounds(context+" ripe fruit")
	if not await press_action("harvest",{"plant_id":mother},context+" harvest"): return ""
	var fruit: Dictionary = {}
	for candidate: Dictionary in game.state.fruit_inventory:
		if candidate.kind=="hybrid" and str(candidate.mother_id)==mother: fruit = candidate
	check(not fruit.is_empty(),context+" harvest produces a stored cross fruit")
	if fruit.is_empty(): return ""
	var fruit_id: String = str(fruit.id)
	var stored_fruit: RefCounted = restored_model()
	check(stored_fruit.fruit_inventory.any(func(item): return str(item.id)==fruit_id),context+" harvested fruit persists before seed extraction")
	var first_seed: int = game.state.seed_bank.size()
	await nursery_tab("fruits",context+" stored fruit")
	if not await press_action("extract",{"fruit_id":fruit_id},context+" seed extraction"): return ""
	check(game.state.seed_bank.size()==first_seed+2,context+" cross fruit contains two seeds")
	check(not game.state.fruit_inventory.any(func(item): return str(item.id)==fruit_id),context+" extraction consumes the fruit exactly once")
	var seed: Dictionary = game.state.seed_bank[first_seed].duplicate(true)
	check(seed.has("genome") and seed.genome.parents==[mother,father],context+" seed holds its complete diploid genome and both parents")
	var stored_seed: RefCounted = restored_model()
	check(stored_seed.seed_bank[first_seed]==seed,context+" extracted seed genome survives reload unchanged")
	await nursery_tab("seeds",context+" stored seeds")
	if await press_action("view_seed_dna",{"seed_index":first_seed},context+" seed DNA inspection"):
		check(game.modal_kind=="dna" and str(game.modal.get_meta("dna_plant_id",""))==str(seed.genome.id),context+" seed DNA control targets the selected stored embryo")
		modal_bounds(context+" seed DNA")
		await nursery_tab("seeds",context+" return from seed DNA")
	if not await press_action("plant_seed",{"seed_index":first_seed},context+" sowing"): return ""
	var child_id: String = str(game.state.plant_order.back())
	var child: Dictionary = game.state.get_plant(child_id)
	check(game.modal_kind=="reveal",context+" sowing reveals the newly growing individual")
	check(game.state.plants.size()==before_count+1 and child_id!=mother and child_id!=father,context+" sowing creates one unique owned child")
	check(not bool(child.mature) and int(child.generation)==generation,context+" child must grow before breeding again")
	check(child.parents==[mother,father] and child.genes==seed.genome.genes and child.stats==seed.genome.stats,context+" sowing preserves full parents, alleles and stats instead of resetting to a base species")
	check(child.lineage_mix==seed.genome.lineage_mix,context+" all ancestral contributions survive the seed")
	check(DNA.profile(child).code==DNA.profile(seed.genome).code,context+" seed and growing child preserve the same encoded DNA")
	check(DNA.profile(child).code!=DNA.profile(game.state.get_plant(mother)).code and DNA.profile(child).code!=DNA.profile(game.state.get_plant(father)).code,context+" each new individual has its own DNA identity")
	check(child.get("gene_sources",{})==seed.genome.get("gene_sources",{}) and child.get("gene_sources",{}).size()==child.genes.size(),context+" seed keeps per-gene inheritance provenance")
	var origins_match: bool = true
	for slot: String in child.get("gene_sources",{}):
		var source: Dictionary = child.gene_sources[slot]
		if str(source.get("allele_a",{}).get("parent_id",""))!=mother or str(source.get("allele_b",{}).get("parent_id",""))!=father: origins_match = false
	check(origins_match,context+" every inherited allele traces to the actually selected mother or father")
	check(game.state.plants.has(mother) and game.state.plants.has(father),context+" both parents remain available")
	check(not game.state.pollinate(child_id,father).ok,context+" immature offspring cannot be used prematurely")
	child.ready_at = 0
	game.state.tick_growth()
	check(bool(child.mature),context+" elapsed growth makes the same child fertile")
	game._close_modal()
	game._refresh()
	await settle()
	return child_id

func run() -> void:
	Locale.set_language("en")
	root.size = Vector2i(1440,1000)
	save_path = "/tmp/conservatory_reproduction_ui_%d.json" % Time.get_ticks_usec()
	game = Garden.new()
	game.state = State.new(save_path)
	root.add_child(game)
	game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await settle()
	check(game.soundscape.preview_muted,"Reproduction tests keep player audio and preferences untouched")
	var leaf: String = str(game.state.plant_order[0])
	var bloom: String = str(game.state.plant_order[1])
	var vine: String = str(game.state.plant_order[2])
	var resources_before: Dictionary = game.state.resources.duplicate()
	check(not game.state.pollinate(leaf,leaf).ok and game.state.resources==resources_before,"Same-individual selection cannot spend resources or create a hidden fruit")
	var g2: String = await make_generation(leaf,bloom,2,"Desktop G2")
	if g2.is_empty():
		quit(1)
		return
	check(game.state.get_plant(g2).lineage_mix.size()==2,"First cross visibly represents both founding lineages")
	Locale.set_language("zh_CN")
	root.size = Vector2i(390,780)
	game._localize_ui()
	await settle()
	check(within(game.root_column.get_global_rect(),root.get_visible_rect()),"Chinese mobile garden keeps the core controls within the canvas")
	var g3: String = await make_generation(g2,vine,3,"Chinese mobile G3")
	if g3.is_empty():
		quit(1)
		return
	var g3_mix: Dictionary = game.state.get_plant(g3).lineage_mix
	check(g3_mix.has("Leaf") and g3_mix.has("Bloom") and g3_mix.has("Vine"),"Re-crossing a hybrid retains the two grandparents and the new parent")
	var root_plant: Dictionary = game.state._create_base(3,650319)
	game.state._add_plant(root_plant)
	var g4: String = await make_generation(g3,str(root_plant.id),4,"Chinese mobile G4")
	if g4.is_empty():
		quit(1)
		return
	var g4_mix: Dictionary = game.state.get_plant(g4).lineage_mix
	check(g4_mix.size()==4 and g4_mix.has("Leaf") and g4_mix.has("Bloom") and g4_mix.has("Vine") and g4_mix.has("Root"),"G4 keeps the complete four-type ancestry rather than only its dominant species")
	# Natural fruit is an independent seed source for the same continuous loop.
	game.state.fruit_crops[leaf].natural_ready_at = 0
	await nursery_tab("plants","Natural ripe plants")
	if await press_action("harvest",{"plant_id":leaf},"Natural fruit harvest"):
		var natural: Dictionary = {}
		for candidate: Dictionary in game.state.fruit_inventory:
			if candidate.kind=="natural" and str(candidate.mother_id)==leaf: natural = candidate
		check(not natural.is_empty(),"A mature parent produces a collectible natural fruit")
		if not natural.is_empty():
			var seed_count: int = game.state.seed_bank.size()
			await nursery_tab("fruits","Natural stored fruit")
			await press_action("extract",{"fruit_id":str(natural.id)},"Natural seed extraction")
			check(game.state.seed_bank.size()==seed_count+1,"Natural fruit gives one full-lineage seed")
	# Grafting accepts a different species and records the actual donor tissue,
	# so the host can keep its identity and later descendants can inherit it.
	var donor: Dictionary = game.state._create_base(5,730593)
	game.state._add_plant(donor)
	game.lab_mode = "Graft"
	game._open_lab()
	await settle()
	await choose_parent(0,g4)
	await choose_parent(1,str(donor.id))
	modal_bounds("Chinese mobile cross-species graft")
	var graft_odds: float = game.state.graft_odds(g4,str(donor.id))
	var trial := RandomNumberGenerator.new()
	for candidate_seed in range(1,100):
		trial.seed = candidate_seed
		if trial.randf()<graft_odds:
			game.state.random.seed = candidate_seed
			break
	var graft_count: int = game.state.get_plant(g4).graft_history.size()
	if await press_action("graft",{},"Cross-species graft"):
		var grafts: Array = game.state.get_plant(g4).graft_history
		check(grafts.size()==graft_count+1,"Successful cross-species graft attaches a permanent donor record")
		if grafts.size()>graft_count:
			var record: Dictionary = grafts.back()
			check(str(record.get("donor_type",""))=="Toxin" and record.get("donor_genes",{})==donor.genes,"Graft preserves the different donor's anatomy and complete tissue genes")
		check(game.state.plants.has(str(donor.id)) and int(donor.donor_ready_at)>int(Time.get_unix_time_from_system()),"Donor remains alive on its disclosed recovery cooldown")
	game._open_detail(g4)
	await settle()
	modal_bounds("Chinese G4 genome and lineage detail")
	if await press_action("view_dna",{"plant_id":g4},"Chinese DNA inspector"):
		check(game.modal_kind=="dna","Actual DNA control opens the dedicated genome inspector")
		modal_bounds("Chinese mobile DNA inspector")
	var identity: String = DNA.profile(game.state.get_plant(g4)).code
	game.state.rename_plant(g4,"A remembered hybrid")
	check(DNA.profile(game.state.get_plant(g4)).code==identity,"Renaming never rewrites the genome")
	game._close_modal()
	var living_genes: Dictionary = game.state.get_plant(g4).genes.duplicate(true)
	var living_seed: int = int(game.state.get_plant(g4).seed)
	game.state.get_plant(g4).life_age = 1199.0
	game.state.advance_lifecycle(1.0)
	check(game.state.life_profile(g4).stage=="aging","A mature plant enters its visible aging stage at 20 minutes of active play")
	game._open_detail(g4)
	await settle()
	modal_bounds("Chinese aging plant detail")
	game._close_modal()
	game.state.fruit_crops[g4].natural_ready_at = int(Time.get_unix_time_from_system())+3600
	game.state.get_plant(g4).life_age = 1499.0
	game.state.advance_lifecycle(1.0)
	check(game.state.life_profile(g4).stage=="withered" and game.state.plants.has(g4),"Natural withering retains the individual in the permanent archive")
	check(not game.state.bed.has(g4) and not game.state.display_bed.has(g4),"Withered plants leave their active soil and display slots")
	check(game.state.get_plant(g4).genes==living_genes and int(game.state.get_plant(g4).seed)==living_seed,"Aging and withering preserve the plant's genetic identity")
	check(DNA.profile(game.state.get_plant(g4)).code==identity,"Natural withering never rewrites the encoded DNA")
	check(not game.state.pollinate(g4,leaf).ok and not game.state.graft(g4,leaf).ok,"Withered individuals cannot be used as living parents or graft hosts")
	game.lab_mode = "Crossbreed"
	game._open_lab()
	await settle()
	var living_selector: bool = true
	for picker: OptionButton in [game.lab_pick_a,game.lab_pick_b]:
		for i in range(picker.item_count):
			if str(picker.get_item_metadata(i))==g4: living_selector = false
	check(living_selector,"Parent selectors exclude naturally withered archive specimens")
	check(game.state.fruit_status(g4).natural_ready,"Withering leaves one final natural fruit for a successor")
	await nursery_tab("plants","Final ripe fruit")
	if await press_action("harvest",{"plant_id":g4},"Final fruit harvest"):
		var final_fruit: Dictionary = {}
		for candidate: Dictionary in game.state.fruit_inventory:
			if candidate.kind=="natural" and str(candidate.mother_id)==g4: final_fruit = candidate
		check(not final_fruit.is_empty(),"The final fruit can be collected from the withered parent")
		check(not game.state.harvest_fruit(g4).ok,"A withered parent's final fruit cannot be harvested twice")
		game.state.tick_reproduction()
		check(not game.state.fruit_crops.has(g4),"Withered plants do not restart a new fruit timer")
		if not final_fruit.is_empty():
			await nursery_tab("fruits","Final stored fruit")
			var successor_seed_index: int = game.state.seed_bank.size()
			await press_action("extract",{"fruit_id":str(final_fruit.id)},"Final seed extraction")
			await nursery_tab("seeds","Successor seed")
			if await press_action("plant_seed",{"seed_index":successor_seed_index},"Successor sowing"):
				var successor: Dictionary = game.state.get_plant(str(game.state.plant_order.back()))
				check(successor.parents==[g4] and int(successor.generation)==5,"Final seed continues the naturally withered G4 lineage into G5")
				check(game.state.life_profile(str(successor.id)).stage=="seedling" and float(successor.life_age)<1.0,"A new seed starts a fresh lifespan rather than inheriting its parent's age")
	game._close_modal()
	game.state.save_game()
	var restored: RefCounted = restored_model()
	check(restored.plants[g4].parents==[g3,root_plant.id] and restored.plants[g4].lineage_mix==g4_mix,"Multigeneration ancestry and exact parent IDs persist")
	check(DNA.canonical(restored.seed_bank)==DNA.canonical(game.state.seed_bank) and DNA.canonical(restored.fruit_inventory)==DNA.canonical(game.state.fruit_inventory),"Stored fruits and complete seed genomes persist together")
	check(DNA.profile(restored.plants[g4]).code==identity,"DNA encoding remains stable across JSON save/reload")
	Locale.set_language("en")
	game.queue_free()
	await settle()
	for path in [save_path,save_path.get_basename()+".backup.json",save_path.get_basename()+".audio.cfg",save_path.get_basename()+".language.cfg"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	print("REPRODUCTION INTEGRATION TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
