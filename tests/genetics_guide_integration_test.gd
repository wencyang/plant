extends SceneTree
## Player-facing genetics: traits must explain visible expression, hidden
## inheritance, and the effect of choosing another mate without editing a genome.
const Garden = preload("res://scripts/garden.gd")
const State = preload("res://scripts/garden_state.gd")
const DNA = preload("res://scripts/plant_dna.gd")
const Locale = preload("res://scripts/localization.gd")
const Guide = preload("res://scripts/genetics_guide.gd")
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
		push_error("GENETICS GUIDE UI: "+message)

func settle() -> void:
	for i in range(6): await process_frame

func find_meta(node: Node,key: String,value: Variant) -> Node:
	if node.has_meta(key) and str(node.get_meta(key))==str(value): return node
	for child in node.get_children():
		var found: Node = find_meta(child,key,value)
		if found!=null: return found
	return null

func action(name: String) -> Button:
	return find_meta(game.modal,"reproduction_action",name) as Button

func texts(node: Node,result: Array[String]) -> void:
	if node is Control and not node.is_visible_in_tree(): return
	if node is Label or node is Button: result.append(str(node.text))
	for child in node.get_children(): texts(child,result)

func text_in(node: Node) -> String:
	var values: Array[String] = []
	texts(node,values)
	return "\n".join(values)

func has_codes(node: Node) -> bool:
	var sequence := RegEx.new()
	sequence.compile("[ACGT]{16,}|(?:#)?\\b[0-9a-fA-F]{6,12}\\b")
	return sequence.search(text_in(node))!=null

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
	var panel: Control = game.modal.get_node("Panel")
	check(within(panel.get_global_rect(),root.get_visible_rect()),context+" modal fits viewport")
	var issues: Array[String] = []
	overflow(panel,panel.get_global_rect(),issues)
	check(issues.is_empty(),context+" content fits horizontally: "+"; ".join(issues.slice(0,6)))

func stable_genetics() -> String:
	var records: Dictionary = {}
	for id: String in game.state.plants:
		var p: Dictionary = game.state.get_plant(id)
		records[id] = [p.genes,p.stats,p.get("skill_genes",{}),p.seed,p.parents,p.get("lineage_mix",{})]
	return DNA.canonical([records,game.state.random.state,game.state.id_counter,game.state.resources,game.state.seed_bank])

func press(name: String,context: String) -> bool:
	var button: Button = action(name)
	check(button!=null,context+" has an actual action control")
	if button==null: return false
	check(not button.disabled,context+" action is usable")
	if button.disabled: return false
	if button is CheckButton or button is CheckBox: button.button_pressed = not button.button_pressed
	else: button.pressed.emit()
	await settle()
	return true

func run() -> void:
	# The fixtures deliberately separate transmission from visible expression:
	# Solid/Striped × Solid/Solid transmits Striped from the first plant 50% of
	# the time, but expresses it in only 25% of their G2 offspring.
	Locale.set_language("en")
	root.size = Vector2i(1440,1000)
	save_path = "/tmp/conservatory_readable_dna_%d.json" % Time.get_ticks_usec()
	game = Garden.new()
	game.state = State.new(save_path)
	root.add_child(game)
	game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await settle()
	var carrier_id: String = str(game.state.plant_order[0])
	var solid_id: String = str(game.state.plant_order[1])
	var striped_id: String = str(game.state.plant_order[2])
	var carrier: Dictionary = game.state.get_plant(carrier_id)
	var solid: Dictionary = game.state.get_plant(solid_id)
	var striped: Dictionary = game.state.get_plant(striped_id)
	carrier.name = "Carrier fern"
	carrier.genes.pattern = {"dominant":"Solid","recessive":"Striped"}
	solid.name = "Solid flower"
	solid.genes.pattern = {"dominant":"Solid","recessive":"Solid"}
	striped.name = "Striped vine"
	striped.genes.pattern = {"dominant":"Striped","recessive":"Striped"}
	carrier.stats.vitality = 120
	solid.stats.vitality = 200
	game.state.save_game()
	var before: String = stable_genetics()
	game._open_dna(carrier_id)
	await settle()
	check(game.modal_kind=="dna","Trait guide remains reachable through the established DNA action")
	check(not has_codes(game.modal),"Default trait sheet contains no opaque sequence, hex pigment, or hash identity")
	check_bounds("English desktop trait guide")
	var pattern_card: Node = find_meta(game.modal,"trait_key","pattern")
	check(pattern_card!=null,"Pattern trait has a clear player-facing card")
	if pattern_card!=null:
		var text: String = text_in(pattern_card).to_lower()
		check(text.contains(Guide.trait_value("pattern","Solid").to_lower()) and text.contains("striped"),"Player can distinguish current Solid appearance from carried Striped")
		check(text.contains("50%"),"Carrier explains its actual chance to transmit either allele")
		var shown: Node = find_meta(pattern_card,"role","visible")
		var carried: Node = find_meta(pattern_card,"role","hidden")
		check(shown!=null and carried!=null,"Current appearance and hidden inheritance have separate labeled values")
		if shown!=null and carried!=null:
			check(text_in(shown).contains(Guide.trait_value("pattern","Solid")) and text_in(carried).contains("Striped"),"Visible and carried labels show the actual corresponding allele rather than swapping them")
	var advanced: Button = action("dna_advanced")
	check(advanced!=null,"Raw encoding is available only through an explicit advanced action")
	if advanced!=null:
		await press("dna_advanced","Advanced genome details")
		check(has_codes(game.modal),"Opening advanced details reveals the underlying encoded record")
		check_bounds("Expanded advanced record")
		game._open_dna(carrier_id)
		await settle()
		check(not has_codes(game.modal),"Opening the normal trait sheet returns to readable information")
	check(stable_genetics()==before,"Reading traits and advanced records never changes genes, resources, RNG, IDs or seeds")
	# Comparison and localization assertions follow the production comparison
	# controls. Root supplies these metadata while implementing the new view.
	await check_comparison(carrier_id,solid_id,striped_id,before)
	Locale.set_language("zh_CN")
	root.size = Vector2i(390,780)
	game._open_dna(carrier_id)
	game._localize_ui()
	await settle()
	check(not has_codes(game.modal),"Chinese mobile guide also leads with readable traits")
	check_bounds("Chinese mobile trait guide")
	var chinese: String = text_in(game.modal)
	check(chinese.contains("纯色") and chinese.contains("条纹"),"Chinese guide names both visible and hidden pattern values")
	check(stable_genetics()==before,"Changing language and viewport never changes the inherited genome")
	for config: Array in [["en",Vector2i(390,780)],["zh_CN",Vector2i(1440,1000)]]:
		Locale.set_language(str(config[0]))
		root.size = config[1]
		await settle()
		game._open_dna(carrier_id)
		game._localize_ui()
		await settle()
		check(not has_codes(game.modal),str(config[0])+" alternateviewport defaults to readabletraits")
		check_bounds(str(config[0])+" alternateviewport traitguide")
	game.queue_free()
	await settle()
	Locale.set_language("en")
	for path in [save_path,save_path.get_basename()+".backup.json",save_path.get_basename()+".audio.cfg",save_path.get_basename()+".language.cfg"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	print("GENETICS GUIDE INTEGRATION TESTS: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)

func choose_mate(id: String,context: String) -> bool:
	var picker: OptionButton = find_meta(game.modal,"dna_mate_picker",true) as OptionButton
	check(picker!=null,context+" exposes the actual mate selector")
	if picker==null: return false
	var index: int = -1
	for i in range(picker.item_count):
		if str(picker.get_item_metadata(i))==id: index = i
	check(index>=0,context+" includes the selected mature plant with its canonical ID")
	if index<0: return false
	picker.select(index)
	picker.item_selected.emit(index)
	await settle()
	return true

func outcome_probability(preview: Dictionary,key: String,raw: Variant) -> float:
	for trait_info: Dictionary in preview.get("traits",[]):
		if str(trait_info.get("key",""))!=key: continue
		for result: Dictionary in trait_info.get("outcomes",[]):
			if str(result.get("raw",result.get("value","")))==str(raw): return float(result.get("probability",-1))
	return -1.0

func choose_goal(key: String,value: Variant) -> bool:
	var picker: OptionButton = find_meta(game.modal,"dna_goal_trait",true) as OptionButton
	check(picker!=null,"Breeding preview offers a trait goal selector")
	if picker==null: return false
	var index: int = -1
	for i in range(picker.item_count):
		if str(picker.get_item_metadata(i))==key: index=i
	check(index>=0,"Trait goal selector stores the canonical gene key "+key)
	if index<0: return false
	picker.select(index)
	picker.item_selected.emit(index)
	await settle()
	var choice: OptionButton = find_meta(game.modal,"dna_goal_value",true) as OptionButton
	check(choice!=null,"Selected gene offers readable target values")
	if choice==null: return false
	index = -1
	for i in range(choice.item_count):
		if DNA.canonical(choice.get_item_metadata(i))==DNA.canonical(value): index=i
	check(index>=0,"Target selector preserves the actual allele rather than a translated label")
	if index<0: return false
	choice.select(index)
	choice.item_selected.emit(index)
	await settle()
	return true

func check_comparison(carrier: String,solid: String,striped: String,before: String) -> void:
	if not await press("dna_compare","Breeding comparison"): return
	check(game.modal_kind=="dna_compare","Trait guide opens a focused mate comparison")
	check_bounds("English desktop mate comparison")
	if not await choose_mate(solid,"Solid mate"): return
	var first: Dictionary = game.modal.get_meta("dna_preview",{})
	check(is_equal_approx(outcome_probability(first,"pattern","Striped"),0.25),"Carrier×Solid mate predicts25%visibleStriped from the actual inheritance rules")
	check(text_in(game.modal).contains("25%"),"Player sees the25%visible chance rather than only a50%transmission claim")
	if not await choose_mate(striped,"Striped mate"): return
	var improved: Dictionary = game.modal.get_meta("dna_preview",{})
	check(is_equal_approx(outcome_probability(improved,"pattern","Striped"),0.75),"Choosing aStriped/Striped mate actually raises visible offspring chance to75%")
	check(text_in(game.modal).contains("75%"),"Improved75%chance is displayed after the real selector changes")
	check(not has_codes(game.modal),"Breeding decisions use names, swatches and chances without rawcodes")
	check(stable_genetics()==before,"Comparing mates never creates embryos or advances gameplayRNG")
	if await choose_goal("petals",12):
		check(str(game.modal.get_meta("dna_goal_key",""))=="petals" and int(game.modal.get_meta("dna_goal_value",0))==12,"A new goal updates the actual prediction context")
		check(text_in(game.modal).contains("0%"),"Unavailable twelve-petal allele is disclosed as zero chance with these parents")
		check(text_in(game.modal).contains("inherited petal count") and text_in(game.modal).contains("flowering descendants"),"Flower genes are explained as potential for flowering offspring without promising flowers on a leaf-vine cross")
		check_bounds("Petal inheritance goal")
	await choose_goal("pattern","Striped")
	check(is_equal_approx(float(game.modal.get_meta("dna_target_probability",-1)),0.75) or text_in(game.modal).contains("75%"),"Returning to the striped goal retains the selected striped mate and its improved chance")
	await create_timer(1.1).timeout
	await settle()
	check(action("dna_use_pair")!=null and not action("dna_use_pair").disabled,"Selected fertilepair stays usable after the normal lifecycleUIrefresh")
	if await press("dna_use_pair","Use selected pair"):
		check(game.modal_kind=="lab" and game.parent_a==carrier and game.parent_b==striped,"Recommendedpair action prefills the actual breeding laboratory")
		check(stable_genetics()==before,"Prefilling a pair does not spend resources or perform a cross")
	Locale.set_language("zh_CN")
	root.size = Vector2i(390,780)
	await settle()
	game._open_dna_compare(carrier,solid,"pattern","Striped")
	game._localize_ui()
	await settle()
	check_bounds("Chinese mobile mate comparison")
	check(text_in(game.modal).contains("25%") and text_in(game.modal).contains("条纹"),"Chinese comparison preserves the actual target trait and its25%chance")
