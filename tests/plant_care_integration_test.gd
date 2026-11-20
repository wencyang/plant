extends SceneTree
## Drive the same care controls players use. Physical growth and extra lifetime
## must survive a save while inherited genes and the breeding lineage stay intact.
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
		push_error("PLANT CARE UI: "+message)

func settle() -> void:
	for i in range(6): await process_frame

func find_meta(node: Node,key: String,value: Variant) -> Node:
	if node.has_meta(key) and str(node.get_meta(key))==str(value): return node
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
	check(is_instance_valid(game.modal),context+" has an actual care view")
	if not is_instance_valid(game.modal): return
	var panel: Control = game.modal.get_node("Panel")
	check(within(panel.get_global_rect(),root.get_visible_rect()),context+" modal fits the viewport")
	var issues: Array[String] = []
	overflow(panel,panel.get_global_rect(),issues)
	check(issues.is_empty(),context+" controls fit horizontally: "+"; ".join(issues.slice(0,6)))

func genetics(id: String) -> String:
	var p: Dictionary = game.state.get_plant(id)
	return DNA.canonical([p.genes,p.stats,p.get("skill_genes",{}),p.seed,p.parents,p.get("lineage_mix",{}),p.get("gene_sources",{}),p.get("skills",[])])

func tool(key: String) -> Button:
	return find_meta(game.modal,"care_tool",key) as Button

func press_tool(key: String,context: String) -> bool:
	var button: Button = tool(key)
	check(button!=null,context+" has an actual tool button")
	if button==null: return false
	check(str(button.get_meta("reproduction_action",""))=="care_apply",context+" uses the production care action")
	check(not button.disabled,context+" is available")
	if button.disabled: return false
	button.pressed.emit()
	await settle()
	return true

func choose_plant(id: String,context: String) -> bool:
	var picker: OptionButton = find_meta(game.modal,"care_plant_picker",true) as OptionButton
	check(picker!=null,context+" offers a real plant selector")
	if picker==null: return false
	var index: int = -1
	for i in range(picker.item_count):
		if str(picker.get_item_metadata(i))==id: index = i
	check(index>=0,context+" keeps the canonical specimen ID")
	if index<0: return false
	picker.select(index)
	picker.item_selected.emit(index)
	await settle()
	check(str(game.modal.get_meta("care_plant_id",""))==id,context+" targets the selected plant")
	return true

func check_measurements(context: String) -> void:
	for key: String in ["height","weight","life"]:
		var label: Node = find_meta(game.modal,"care_measurement",key)
		check(label!=null and not text_in(label).strip_edges().is_empty(),context+" shows "+key+" as a labeled readable measurement")
	var number := RegEx.new()
	number.compile("[0-9]+(?:\\.[0-9]+)?")
	var data: Dictionary = game.state.plant_measurements(str(game.modal.get_meta("care_plant_id","")))
	for entry: Array in [["height","height_cm"],["weight","weight_g"]]:
		var label: Node = find_meta(game.modal,"care_measurement",entry[0])
		var displayed: RegExMatch = number.search(text_in(label)) if label!=null else null
		check(displayed!=null and absf(float(displayed.get_string())-float(data[entry[1]]))<0.6,context+" displays the selected individual's actual "+str(entry[0])+" rather than a decorative number")

func run() -> void:
	Locale.set_language("en")
	root.size = Vector2i(1440,1000)
	save_path = "/tmp/conservatory_care_ui_%d.json" % Time.get_ticks_usec()
	game = Garden.new()
	game.state = State.new(save_path)
	root.add_child(game)
	game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await settle()
	game.state.resources.sunlight = 500
	var id: String = str(game.state.plant_order[0])
	var mate: String = str(game.state.plant_order[1])
	var plant: Dictionary = game.state.get_plant(id)
	plant.life_age = 1490.0
	game.state.save_game()
	var before_genes: String = genetics(id)
	var before_age: float = float(plant.life_age)
	var before_life: Dictionary = game.state.life_profile(id)
	var before_size: Dictionary = game.state.plant_measurements(id)
	# The garden entry point must work, rather than only a test-only modal call.
	var entry: Button = find_meta(game,"reproduction_action","open_care") as Button
	check(entry!=null,"The garden exposes a reachable plant care entry")
	if entry!=null:
		entry.pressed.emit()
		await settle()
	else:
		game._open_care(id)
		await settle()
	check(game.modal_kind=="care","The care entry opens the care view")
	await choose_plant(id,"Mature specimen selection")
	check_measurements("English care view")
	check_bounds("English desktop care")
	await create_timer(1.1).timeout
	await settle()
	check(tool("water")!=null and not tool("water").disabled,"Care actions remain enabled after the ordinary lifecycle UI refresh")
	var light: int = int(game.state.resources.sunlight)
	if await press_tool("water","Free watering"):
		check(int(game.state.resources.sunlight)==light,"Watering is free")
		check(int(game.state.life_profile(id).life_limit)==int(before_life.life_limit)+60,"Watering adds a real minute before withering")
		check(absf(float(plant.life_age)-before_age)<3,"Watering extends the limit rather than erasing a plant's age")
		var status: Dictionary = game.state.care_status(id,"water")
		check(not bool(status.allowed) and int(status.cooldown_remaining)>0,"Watering has a real cooldown")
		check(tool("water")!=null and tool("water").disabled,"The watered button reflects the cooldown")
		var saved_bonus: float = float(plant.care.life_bonus_seconds)
		check(not bool(game.state.apply_care(id,"water").ok) and float(plant.care.life_bonus_seconds)==saved_bonus,"Repeated watering during cooldown cannot add life")
	light = int(game.state.resources.sunlight)
	if await press_tool("longevity","Life tonic"):
		check(int(game.state.resources.sunlight)==light-10,"Life tonic spends exactly the disclosed ten light")
		check(int(game.state.life_profile(id).life_limit)==int(before_life.life_limit)+660,"Life tonic adds ten minutes on top of watering")
		game.state.advance_lifecycle(20)
		check(not bool(plant.withered) and float(plant.life_age)>State.WITHER_SECONDS,"Care keeps the same individual alive beyond its original lifetime")
	light = int(game.state.resources.sunlight)
	if await press_tool("growth","Growth feed"):
		var grown: Dictionary = game.state.plant_measurements(id)
		check(float(grown.height_cm)>float(before_size.height_cm)*1.14,"Growth feed makes the actual measured plant taller")
		check(int(game.state.resources.sunlight)==light-12,"Growth feed spends exactly twelve light")
		check_measurements("Taller plant")
	light = int(game.state.resources.sunlight)
	var before_weight: float = float(game.state.plant_measurements(id).weight_g)
	if await press_tool("compost","Rich compost"):
		check(float(game.state.plant_measurements(id).weight_g)>before_weight*1.19,"Compost makes the actual measured plant heavier")
		check(int(game.state.resources.sunlight)==light-12,"Compost spends exactly twelve light")
	check(genetics(id)==before_genes,"Water, tonic, feed and compost preserve every inherited gene, stat and parent")
	await check_fruit_and_seedling(id,mate)
	await check_caps_and_archive(id,before_genes)
	await check_localized_layouts(id)
	game.queue_free()
	await settle()
	Locale.set_language("en")
	for path: String in [save_path,save_path.get_basename()+".backup.json",save_path.get_basename()+".audio.cfg",save_path.get_basename()+".language.cfg"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	print("PLANT CARE INTEGRATION TESTS: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)

func check_fruit_and_seedling(id: String,mate: String) -> void:
	game.state.fruit_crops[id].natural_ready_at = int(Time.get_unix_time_from_system())+3600
	check(bool(game.state.pollinate(id,mate).ok),"Fruit-care fixture is a real pollinated hybrid fruit")
	game.state.pollinations[id].ready_at = int(Time.get_unix_time_from_system())+3600
	var embryos: String = DNA.canonical(game.state.pollinations[id].seeds)
	game._open_care(id)
	await settle()
	var light: int = int(game.state.resources.sunlight)
	if await press_tool("ripening","Fruit ripening"):
		var fruit: Dictionary = game.state.fruit_status(id)
		check(bool(fruit.natural_ready) and bool(fruit.cross_ready),"Ripening makes both natural and pollinated fruit harvestable")
		check(int(game.state.resources.sunlight)==light-8,"Ripening spends exactly eight light")
		check(DNA.canonical(game.state.pollinations[id].seeds)==embryos,"Ripening never rerolls the stored hybrid embryos")
	var planted: Dictionary = game.state.plant_seed(0)
	check(bool(planted.ok),"Seedling-care fixture starts from a real sown seed")
	if not bool(planted.ok): return
	var child: Dictionary = game.state.get_plant(str(game.state.plant_order.back()))
	child.ready_at = int(Time.get_unix_time_from_system())+3600
	var child_id: String = str(child.id)
	var child_genes: String = genetics(child_id)
	game._open_care(id)
	await settle()
	if not await choose_plant(child_id,"Growing seedling selection"): return
	light = int(game.state.resources.sunlight)
	if await press_tool("sunlamp","Seedling sunlamp"):
		check(bool(child.mature),"The sunlamp matures the same sown individual")
		check(int(game.state.resources.sunlight)==light-5,"The sunlamp spends exactly five light")
		check(genetics(child_id)==child_genes,"Fast maturation preserves the seed's complete inherited genome")
		check(tool("sunlamp")==null or tool("sunlamp").disabled,"A mature plant cannot repeatedly spend light on seedling growth")

func check_caps_and_archive(id: String,before_genes: String) -> void:
	var plant: Dictionary = game.state.get_plant(id)
	for i in range(4):
		plant.care.cooldowns.water = 0
		check(bool(game.state.apply_care(id,"water").ok),"Water remains available within its lifetime allowance")
	plant.care.cooldowns.water = 0
	check(not bool(game.state.care_status(id,"water").allowed),"Five waterings exhaust the free lifetime allowance")
	for i in range(2): check(bool(game.state.apply_care(id,"longevity").ok),"Remaining tonic doses extend real lifetime")
	check(int(game.state.life_profile(id).life_limit)==3600 and int(game.state.life_profile(id).aging_at)==3300,"Water and tonic caps retain the five-minute final aging phase")
	check(not bool(game.state.care_status(id,"longevity").allowed),"Three tonics exhaust the individual lifetime allowance")
	game.state.save_game()
	var restored = State.new(save_path)
	check(restored.load_game(),"The cared-for garden reloads")
	var stored: Dictionary = restored.get_plant(id)
	check(DNA.canonical(stored.care)==DNA.canonical(plant.care),"Treatment doses, cooldowns and bonuses survive reload")
	check(DNA.canonical(restored.plant_measurements(id))==DNA.canonical(game.state.plant_measurements(id)),"Individual height and weight survive reload exactly")
	check(int(restored.life_profile(id).life_limit)==3600,"Extra lifetime survives reload")
	check(genetics(id)==before_genes,"All care allowances leave the genome and parentage unchanged")
	var light: int = int(game.state.resources.sunlight)
	game.state.resources.sunlight = 0
	game._open_care(id)
	await settle()
	check(tool("growth")!=null and tool("growth").disabled,"A paid tool is visibly unavailable when gathered light is insufficient")
	var size: String = DNA.canonical(game.state.plant_measurements(id))
	check(not bool(game.state.apply_care(id,"growth").ok) and DNA.canonical(game.state.plant_measurements(id))==size,"An unaffordable treatment cannot silently change the plant")
	game.state.resources.sunlight = light
	var archive: Dictionary = game.state._create_base(2,704928)
	archive.withered = true
	archive.retired = true
	archive.life_age = 1500
	game.state._add_plant(archive)
	var resources: Dictionary = game.state.resources.duplicate()
	check(not bool(game.state.apply_care(str(archive.id),"longevity").ok) and game.state.resources==resources,"Care cannot revive a naturally withered plant or charge for trying")

func check_localized_layouts(id: String) -> void:
	for config: Array in [["en",Vector2i(1440,1000)],["zh_CN",Vector2i(390,780)],["en",Vector2i(390,780)],["zh_CN",Vector2i(1440,1000)]]:
		Locale.set_language(str(config[0]))
		root.size = config[1]
		await settle()
		game._open_care(id)
		game._localize_ui()
		await settle()
		check_measurements(str(config[0])+" care view")
		check_bounds(str(config[0])+" "+str(config[1])+" care")
		check(str(game.modal.get_meta("care_plant_id",""))==id,"Changing language and size keeps the selected individual")
		if str(config[0])=="zh_CN":
			var text: String = text_in(game.modal)
			check(text.contains("身高") and text.contains("重量"),"Chinese care names both physical measurements plainly")
			check(text.contains("浇水") and not text.contains("Growth feed") and not text.contains("Life tonic"),"Chinese care tools are translated rather than showing English actions")
			check(not text.contains("This plant has received") and not text.contains("The sun lamp is"),"Chinese care explains exhausted doses and unavailable tools in Chinese")
			check(Locale.text("This tool will be ready for this plant in 37 seconds.").contains("37秒"),"The Chinese watering countdown preserves the real wait time")
			check(Locale.text("This tool needs 12 gathered light.").contains("12采集光照"),"Chinese tool affordability preserves the exact cost")
