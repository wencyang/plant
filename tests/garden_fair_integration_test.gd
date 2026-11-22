extends SceneTree
## The fair gives real rewards for showing a plant, keeps that plant in the
## garden, and records permanent ribbons without introducing combat controls.
const Garden = preload("res://scripts/garden.gd")
const State = preload("res://scripts/garden_state.gd")
const DNA = preload("res://scripts/plant_dna.gd")
const Locale = preload("res://scripts/localization.gd")
var game: Control
var checks: int = 0
var failures: int = 0
var save_path: String
var hero_id: String
var request_key: String

func _initialize() -> void:
	call_deferred("run")

func check(value: bool,message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("GARDEN FAIR UI: "+message)

func settle() -> void:
	for i in range(6): await process_frame

func find_action(node: Node,action: String,filters: Dictionary = {}) -> Button:
	if node is Button and str(node.get_meta("fair_action",""))==action:
		var matches: bool = true
		for key: String in filters:
			if DNA.canonical(node.get_meta(key,""))!=DNA.canonical(filters[key]): matches=false
		if matches: return node
	for child in node.get_children():
		var found: Button = find_action(child,action,filters)
		if found!=null: return found
	return null

func press(action: String,filters: Dictionary,context: String) -> bool:
	var button: Button = find_action(game.modal,action,filters)
	check(button!=null,context+" offers its actual fair control")
	if button==null: return false
	check(not button.disabled,context+" action is available")
	if button.disabled: return false
	button.pressed.emit()
	await settle()
	return true

func texts(node: Node,result: Array[String]) -> void:
	if node is Control and not node.is_visible_in_tree(): return
	if node is Label or node is Button or node is RichTextLabel: result.append(str(node.text))
	if node is Control and not node.tooltip_text.is_empty(): result.append(str(node.tooltip_text))
	if node is OptionButton:
		for i in range(node.item_count): result.append(node.get_item_text(i))
	for child in node.get_children(): texts(child,result)

func text_in(node: Node) -> String:
	var result: Array[String] = []
	texts(node,result)
	return "\n".join(result)

func check_peaceful(node: Node,context: String) -> void:
	var removed := RegEx.new()
	removed.compile("(?i)\\b(?:battle|combat|rival|opponent|enemy|attack|damage)\\b|战斗|对手|敌人|攻击|伤害")
	var found: RegExMatch = removed.search(text_in(node))
	check(found==null,context+" uses peaceful gardening language"+(" (found "+found.get_string()+")" if found!=null else ""))

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
	check(is_instance_valid(game.modal),context+" opens a real fair view")
	if not is_instance_valid(game.modal): return
	var panel: Control = game.modal.get_node("Panel")
	check(within(panel.get_global_rect(),root.get_visible_rect()),context+" panel fits the viewport")
	var issues: Array[String] = []
	overflow(panel,panel.get_global_rect(),issues)
	check(issues.is_empty(),context+" content fits horizontally: "+"; ".join(issues.slice(0,6)))

func collection() -> String:
	var organisms: Dictionary = game.state.plants.duplicate(true)
	for id: String in organisms: organisms[id].erase("life_age")
	return DNA.canonical([organisms,game.state.plant_order,game.state.bed,game.state.display_bed])

func rewards_state() -> Dictionary:
	return {"coins":int(game.state.market_wallet()),"sunlight":int(game.state.resources.sunlight),"grafts":int(game.state.resources.grafts),"agents":int(game.state.resources.agents)}

func stable_state() -> String:
	return DNA.canonical([collection(),rewards_state(),game.state.seed_bank,game.state.fruit_inventory,game.state.pollinations,game.state.fruit_crops,game.state.fair,game.state.random.state,game.state.id_counter])

func check_rewards(before: Dictionary,rewards: Dictionary,context: String) -> void:
	var current: Dictionary = rewards_state()
	for key: String in ["coins","sunlight","grafts","agents"]:
		check(int(current[key])==int(before[key])+int(rewards.get(key,0)),context+" grants exactly the displayed "+key+" reward")

func request_row(key: String) -> Dictionary:
	for row: Dictionary in game.state.fair_requests():
		if str(row.key)==key: return row
	return {}

func ribbon_row(key: String) -> Dictionary:
	for row: Dictionary in game.state.fair_ribbons():
		if str(row.key)==key: return row
	return {}

func choose_plant(key: String,id: String,context: String) -> bool:
	var picker: OptionButton = find_action(game.modal,"choose_plant",{"request_key":key}) as OptionButton
	check(picker!=null,context+" offers its actual plant selector")
	if picker==null: return false
	var index: int = -1
	for i in range(picker.item_count):
		if str(picker.get_item_metadata(i))==id: index=i
	check(index>=0,context+" includes the chosen specimen's canonical ID")
	if index<0: return false
	picker.select(index)
	picker.item_selected.emit(index)
	await settle()
	return true

func run() -> void:
	Locale.set_language("en")
	root.size = Vector2i(1440,1000)
	save_path = "/tmp/conservatory_fair_ui_%d.json" % Time.get_ticks_usec()
	game = Garden.new()
	game.state = State.new(save_path)
	root.add_child(game)
	game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await settle()
	game.state.resources.sunlight = 500
	var a: String = str(game.state.plant_order[0])
	var b: String = str(game.state.plant_order[1])
	check(bool(game.state.pollinate(a,b).ok),"Fair fixture begins with a real cross between two founders")
	game.state.pollinations[a].ready_at = 0
	game.state.fruit_crops[a].natural_ready_at = int(Time.get_unix_time_from_system())+3600
	game.state.harvest_fruit(a)
	var fruit: Dictionary = game.state.fruit_inventory.back()
	game.state.extract_seeds(str(fruit.id))
	check(bool(game.state.plant_seed(game.state.seed_bank.size()-1).ok),"Fair fixture is an actual planted full-genome hybrid")
	hero_id = str(game.state.plant_order.back())
	check(bool(game.state.apply_care(hero_id,"sunlamp").ok),"The fair specimen has genuinely matured")
	game.state.get_plant(hero_id).favorite = true
	game.state.place_in_bed(hero_id,3)
	game.state.place_in_display(hero_id,4)
	game.state.save_game()
	var before: String = stable_state()
	var open: Button = find_action(game,"open")
	check(open!=null,"The main garden offers the fair as a direct peaceful activity")
	if open!=null:
		open.pressed.emit()
		await settle()
	else:
		game._open_fair()
		await settle()
	check(game.modal_kind=="fair","The former primary action opens the garden fair")
	check(stable_state()==before,"Opening the fair creates no hidden reward or plant change")
	check(not game.has_method("_start_battle") and not game.has_method("_prepare_battle"),"The garden runtime exposes no removed combat entry point")
	check_bounds("English desktop fair")
	check_peaceful(game,"English fair and garden")
	var requests: Array = game.state.fair_requests()
	check(requests.size()==3,"The fair presents three concrete visitors' requests")
	if requests.is_empty():
		quit(1)
		return
	request_key = str(requests[0].key)
	await check_daily_request()
	await check_ribbon()
	await check_rejected_plants()
	await check_reload()
	await check_localized_layouts()
	await audit_reachable_panels()
	game.queue_free()
	await settle()
	Locale.set_language("en")
	for path: String in [save_path,save_path.get_basename()+".backup.json",save_path.get_basename()+".audio.cfg",save_path.get_basename()+".language.cfg"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	print("GARDEN FAIR INTEGRATION TESTS: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)

func check_daily_request() -> void:
	var before: String = stable_state()
	if not await press("request",{"request_key":request_key},"Meet the seed librarian"): return
	check(game.modal_kind=="fair_request" and str(game.modal.get_meta("request_key",""))==request_key,"A visitor request has its own clear showing step")
	check(stable_state()==before,"Reading a visitor's request performs no trade or reward claim")
	if not await choose_plant(request_key,hero_id,"Choose the grown hybrid"): return
	check(str(game.modal.get_meta("plant_id",""))==hero_id,"The preview targets the plant actually chosen by the player")
	var preview: Dictionary = game.state.fair_preview(request_key,hero_id)
	check(bool(preview.get("eligible",false)),"The welcome visitor accepts an owned living mature hybrid, including a favorite")
	check(stable_state()==before,"Showing the selected plant's preview does not consume or change it")
	check_bounds("Chosen plant request preview")
	check_peaceful(game.modal,"Visitor plant preview")
	var rewards: Dictionary = preview.get("rewards",{})
	for key: String in rewards:
		if int(rewards[key])>0: check(text_in(game.modal).contains(str(rewards[key])),"The request previews its actual "+key+" reward")
	var original: String = collection()
	var amounts: Dictionary = rewards_state()
	var claim: Button = find_action(game.modal,"claim_request",{"request_key":request_key,"plant_id":hero_id})
	check(claim!=null and not claim.disabled,"The real request has an explicit claim action for the chosen plant")
	if claim==null or claim.disabled: return
	# Two queued presses must grant this daily visitor's reward only once.
	claim.pressed.emit()
	claim.pressed.emit()
	await settle()
	check_rewards(amounts,rewards,"A visitor shown the chosen plant once")
	check(collection()==original,"Showing a plant keeps its genome, favorite flag, placement, parents and ownership")
	check(bool(request_row(request_key).get("claimed",false)),"The completed visitor request is visibly marked claimed")
	check(game.state.fair.claims.has(request_key) and str(game.state.fair.claims[request_key].plant_id)==hero_id,"The daily claim ledger records the exact shown individual")
	before = stable_state()
	check(not bool(game.state.fair_claim(request_key,hero_id).ok) and stable_state()==before,"A repeated daily claim cannot grant a second reward")

func check_ribbon() -> void:
	var ribbon: Dictionary = ribbon_row("mixed_roots")
	check(bool(ribbon.get("eligible",false)) and not bool(ribbon.get("earned",true)),"A genuinely raised two-family hybrid qualifies for the mixed roots ribbon")
	game._open_fair()
	await settle()
	if not await press("tab",{"fair_tab":"ribbons"},"Visit permanent ribbons"): return
	check(game.modal_kind=="fair" and str(game.modal.get_meta("fair_tab",""))=="ribbons","The fair exposes permanent progress separately from today's visitors")
	check_bounds("Permanent ribbon board")
	var original: String = collection()
	var amounts: Dictionary = rewards_state()
	if await press("claim_ribbon",{"ribbon_key":"mixed_roots"},"Claim the mixed roots ribbon"):
		check_rewards(amounts,ribbon.reward,"The mixed roots ribbon")
		check(collection()==original,"Earning a ribbon preserves every plant and its inherited records")
		check(bool(ribbon_row("mixed_roots").get("earned",false)) and game.state.fair.ribbons.has("mixed_roots"),"The ribbon becomes a permanent earned record")
		var before: String = stable_state()
		check(not bool(game.state.fair_claim_ribbon("mixed_roots").ok) and stable_state()==before,"An earned ribbon cannot repeatedly pay its reward")

func check_rejected_plants() -> void:
	# A later market sale is deliberate fixture work: it proves the fair's earned
	# ribbon outlives its evidence without making the archived plant showable.
	game.state.get_plant(hero_id).favorite = false
	var offer: Dictionary = game.state.market_quote("plant",hero_id)
	check(bool(game.state.market_sell("plant",hero_id,str(offer.get("quote_id",""))).ok),"A previously shown plant can later be deliberately sold through the existing market")
	check(bool(ribbon_row("mixed_roots").get("earned",false)),"A permanent ribbon remains earned after its qualifying plant leaves the owned garden")
	var withered: Dictionary = game.state._create_base(0,608113)
	withered.withered = true
	withered.retired = true
	withered.life_age = State.WITHER_SECONDS
	game.state._add_plant(withered)
	check(bool(game.state.plant_seed(0).ok),"A growing seedling is available to test fair maturity guidance")
	var seedling_id: String = str(game.state.plant_order.back())
	game.state.get_plant(seedling_id).ready_at = int(Time.get_unix_time_from_system())+3600
	var key: String = str(game.state.fair_requests()[1].key)
	game._show_fair_request(key)
	await settle()
	for entry: Array in [[hero_id,"sold"],[str(withered.id),"withered"],[seedling_id,"seedling"]]:
		var id: String = str(entry[0])
		var preview: Dictionary = game.state.fair_preview(key,id)
		check(not bool(preview.get("eligible",true)) and not str(preview.get("reason","")).is_empty(),str(entry[1])+" plants have an explained showing restriction")
		var picker: OptionButton = find_action(game.modal,"choose_plant") as OptionButton
		var listed: bool = false
		if picker!=null:
			for i in range(picker.item_count):
				if str(picker.get_item_metadata(i))==id: listed=true
		if str(entry[1])=="seedling" and listed:
			await choose_plant(key,id,"Growing seedling guidance")
			var claim: Button = find_action(game.modal,"claim_request",{"plant_id":id})
			check(claim!=null and claim.disabled,"A selected seedling explains its growth requirement without offering gifts")
		else: check(not listed,str(entry[1])+" plants are excluded from the living fair selector")
		var before: String = stable_state()
		check(not bool(game.state.fair_claim(key,id).ok) and stable_state()==before,str(entry[1])+" plant claims cannot grant resources or change the garden")

func check_reload() -> void:
	game.state.save_game()
	var restored = State.new(save_path)
	check(restored.load_game(),"The fair garden reloads")
	check(DNA.canonical(restored.fair)==DNA.canonical(game.state.fair),"Daily shown plants and permanent ribbons persist exactly")
	check(restored.market_wallet()==game.state.market_wallet() and DNA.canonical(restored.resources)==DNA.canonical(game.state.resources),"Fair rewards survive reload in the real wallet and resource inventory")
	check(restored.plants.has(hero_id) and not restored.owns_plant(hero_id),"The shown and later sold plant retains its archived DNA after reload")
	var before: String = DNA.canonical([restored.fair,restored.resources,restored.market_wallet()])
	check(not bool(restored.fair_claim(request_key,hero_id).ok) and not bool(restored.fair_claim_ribbon("mixed_roots").ok),"Reload cannot reopen claimed daily or ribbon rewards")
	check(DNA.canonical([restored.fair,restored.resources,restored.market_wallet()])==before,"Rejected claims after reload change no persisted rewards")

func check_localized_layouts() -> void:
	for config: Array in [["en",Vector2i(1440,1000)],["zh_CN",Vector2i(390,780)],["en",Vector2i(390,780)],["zh_CN",Vector2i(1440,1000)]]:
		Locale.set_language(str(config[0]))
		root.size = config[1]
		game._close_modal()
		game._refresh()
		await settle()
		check(within(game.root_column.get_global_rect(),root.get_visible_rect()),str(config[0])+" fair garden fits "+str(config[1]))
		var open: Button = find_action(game,"open")
		check(open!=null and open.is_visible_in_tree() and within(open.get_global_rect(),root.get_visible_rect()),str(config[0])+" fair entry is reachable on "+str(config[1]))
		if open==null: continue
		var before: String = stable_state()
		open.pressed.emit()
		game._localize_ui()
		await settle()
		check_bounds(str(config[0])+" "+str(config[1])+" visitor board")
		check_peaceful(game,str(config[0])+" visitor board")
		if str(config[0])=="zh_CN": check(text_in(game.modal).contains("花园") and not text_in(game.modal).contains("Garden fair"),"The Chinese fair has a readable localized introduction")
		if await press("tab",{"fair_tab":"ribbons"},str(config[0])+" ribbon navigation"):
			game._localize_ui()
			await settle()
			check_bounds(str(config[0])+" "+str(config[1])+" ribbon board")
			check_peaceful(game.modal,str(config[0])+" ribbon board")
		if await press("tab",{"fair_tab":"requests"},str(config[0])+" visitor navigation"):
			var completed: Button = find_action(game.modal,"request",{"request_key":request_key})
			check(completed!=null and completed.disabled,str(config[0])+" completed daily visit is visibly unavailable until tomorrow")
			var another: String = str(game.state.fair_requests()[1].key)
			if await press("request",{"request_key":another},str(config[0])+" request details"):
				game._localize_ui()
				await settle()
				check_bounds(str(config[0])+" "+str(config[1])+" visitor details")
				check_peaceful(game.modal,str(config[0])+" visitor details")
		check(stable_state()==before,"Browsing "+str(config[0])+" visitors and ribbons performs no hidden claim")

func expand_folds(node: Node) -> void:
	if node is CheckButton or node is CheckBox: node.button_pressed = true
	for child in node.get_children(): expand_folds(child)

func audit_reachable_panels() -> void:
	for language: String in ["en","zh_CN"]:
		Locale.set_language(language)
		root.size = Vector2i(1440,1000)
		game._close_modal()
		game._refresh()
		await settle()
		check_peaceful(game,language+" home garden")
		var living: String = str(game.state.plant_order[0])
		var mate: String = str(game.state.plant_order[1])
		for panel: Array in [["_open_guide",[],"guide"],["_open_settings",[],"settings"],["_open_display_notes",[],"display notes"],["_open_codex",[],"collection book"],["_open_detail",[living],"plant detail"],["_open_dna",[living],"traits and records"],["_open_dna_compare",[living,mate],"offspring prediction"],["_open_care",[living],"care"],["_open_market",["prices"],"market prices"],["_open_planting",[],"planting"],["_open_seeds",[],"fruit and seeds"]]:
			game.callv(str(panel[0]),panel[1])
			game._localize_ui()
			await settle()
			if str(panel[0])=="_open_dna":
				expand_folds(game.modal)
				game._localize_ui()
				await settle()
			check_peaceful(game.modal,language+" reachable "+str(panel[2]))
		game._open_wilderness()
		await settle()
		check_peaceful(game,language+" wilderness")
		game._begin_wild_encounter("Mosswood","fair_copy_audit")
		game._localize_ui()
		await settle()
		check_peaceful(game.modal,language+" wild encounter")
		game._leave_wild()
		game._return_from_wilderness()
		await settle()
