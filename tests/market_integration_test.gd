extends SceneTree
## Trading must follow a visible quote and sell the exact reviewed organism,
## fruit or seed. Garden archives and earned coins survive the transaction.
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
		push_error("MARKET UI: "+message)

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
	check(is_instance_valid(game.modal),context+" has an actual market view")
	if not is_instance_valid(game.modal): return
	var panel: Control = game.modal.get_node("Panel")
	check(within(panel.get_global_rect(),root.get_visible_rect()),context+" modal fits the viewport")
	var issues: Array[String] = []
	overflow(panel,panel.get_global_rect(),issues)
	check(issues.is_empty(),context+" controls fit horizontally: "+"; ".join(issues.slice(0,6)))
	if game.modal_kind=="market_review":
		var confirm: Button = find_action(game.modal,"confirm_sale")
		if confirm!=null: check(within(confirm.get_global_rect(),panel.get_global_rect()),context+" keeps the final sale decision visible outside the scrolling price breakdown")

func find_action(node: Node,action: String,filters: Dictionary = {}) -> Button:
	if node is Button and str(node.get_meta("market_action",""))==action:
		var matches: bool = true
		for key: String in filters:
			if DNA.canonical(node.get_meta(key,""))!=DNA.canonical(filters[key]): matches = false
		if matches: return node
	for child in node.get_children():
		var found: Button = find_action(child,action,filters)
		if found!=null: return found
	return null

func press(action: String,filters: Dictionary,context: String) -> bool:
	var button: Button = find_action(game.modal,action,filters)
	check(button!=null,context+" offers its actual market control")
	if button==null: return false
	check(not button.disabled,context+" control is available")
	if button.disabled: return false
	button.pressed.emit()
	await settle()
	return true

func genetics(id: String) -> String:
	var plant: Dictionary = game.state.get_plant(id)
	return DNA.canonical([plant.genes,plant.stats,plant.seed,plant.parents,plant.get("skill_genes",{}),plant.get("gene_sources",{}),plant.get("lineage_mix",{}),plant.get("skills",[])])

func inventory_row(kind: String,reference: Variant) -> Dictionary:
	for row: Dictionary in game.state.market_inventory(kind):
		if DNA.canonical(row.reference)==DNA.canonical(reference): return row
	return {}

func economy() -> String:
	var organisms: Dictionary = game.state.plants.duplicate(true)
	for id: String in organisms: organisms[id].erase("life_age")
	return DNA.canonical([game.state.market_wallet(),game.state.market_history(),game.state.market_stock(),organisms,game.state.plant_order,game.state.bed,game.state.display_bed,game.state.seed_bank,game.state.fruit_inventory,game.state.pollinations,game.state.fruit_crops,game.state.resources,game.state.random.state,game.state.id_counter])

func review(kind: String,reference: Variant,context: String) -> Dictionary:
	var tab: String = {"plant":"plants","fruit":"fruits","seed":"seeds"}.get(kind,kind)
	game._open_market(tab)
	await settle()
	var before: String = economy()
	if not await press("review_sale",{"item_kind":kind,"item_ref":reference},context+" review"): return {}
	check(game.modal_kind=="market_review",context+" opens an explicit sale review before exchanging anything")
	check(economy()==before,context+" review neither sells nor changes the wallet, inventory or RNG")
	check_bounds(context+" review")
	var quote: Dictionary = game.modal.get_meta("market_quote",{})
	check(bool(quote.get("ok",false)) and bool(quote.get("eligible",false)),context+" reviews an eligible, current quote")
	check(int(quote.get("price",0))>0,context+" has a real coin value")
	var sum: int = 0
	var shown: String = text_in(game.modal)
	for component: Dictionary in quote.get("breakdown",[]):
		sum += int(component.get("amount",0))
		check(shown.contains(Locale.text(str(component.get("label","")))),context+" explains the price component "+str(component.get("label","")))
	check(not quote.get("breakdown",[]).is_empty() and sum==int(quote.get("price",-1)),context+" disclosed price components add up to the exact offer")
	check(shown.contains(str(quote.get("price",-1))),context+" visibly states the total coin offer")
	var button: Button = find_action(game.modal,"confirm_sale",{"item_kind":kind,"item_ref":reference})
	check(button!=null and str(button.get_meta("quote_id",""))==str(quote.get("quote_id","")),context+" confirmation is tied to this exact reviewed quote")
	return quote

func run() -> void:
	Locale.set_language("en")
	root.size = Vector2i(1440,1000)
	save_path = "/tmp/conservatory_market_ui_%d.json" % Time.get_ticks_usec()
	game = Garden.new()
	game.state = State.new(save_path)
	root.add_child(game)
	game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await settle()
	game.state.resources.sunlight = 500
	var mother: String = str(game.state.plant_order[0])
	var father: String = str(game.state.plant_order[1])
	var seller: String = str(game.state.plant_order[2])
	var favorite_id: String = str(game.state.plant_order[3])
	var ripe_parent: String = str(game.state.plant_order[4])
	var sale_plant: Dictionary = game.state.get_plant(seller)
	sale_plant.name = "Market vine"
	sale_plant.rarity = "Legendary"
	sale_plant.genes.size.dominant = "Large"
	var descendant: Dictionary = game.state._make_offspring(sale_plant,game.state.get_plant(father),820139)
	descendant.ready_at = int(Time.get_unix_time_from_system())+3600
	game.state._add_plant(descendant)
	game.state.place_in_bed(seller,0)
	game.state.place_in_display(seller,4)
	game.state.get_plant(favorite_id).favorite = true
	# Two genuine hybrid crops: sell one fruit; extract the other for a seed sale.
	check(bool(game.state.pollinate(mother,father).ok),"The fruit-sale fixture grows from real pollination")
	game.state.pollinations[mother].ready_at = 0
	game.state.fruit_crops[mother].natural_ready_at = int(Time.get_unix_time_from_system())+3600
	game.state.harvest_fruit(mother)
	var sale_fruit: String = str(game.state.fruit_inventory.back().id)
	check(bool(game.state.pollinate(father,mother).ok),"The seed-sale fixture grows from a second real hybrid fruit")
	game.state.pollinations[father].ready_at = 0
	game.state.fruit_crops[father].natural_ready_at = int(Time.get_unix_time_from_system())+3600
	game.state.harvest_fruit(father)
	game.state.extract_seeds(str(game.state.fruit_inventory.back().id))
	for id: String in game.state.plant_order:
		if game.state.fruit_crops.has(id): game.state.fruit_crops[id].natural_ready_at = int(Time.get_unix_time_from_system())+3600
	game.state.fruit_crops[ripe_parent].natural_ready_at = 0
	game.state.save_game()
	var before: String = economy()
	var entry: Button = find_meta(game,"reproduction_action","open_market") as Button
	check(entry!=null,"The garden has a real market entry")
	if entry!=null:
		entry.pressed.emit()
		await settle()
	else:
		game._open_market()
		await settle()
	check(game.modal_kind=="market","The garden entry opens the trading market")
	check(economy()==before,"Opening the market never sells anything, grants coins, rolls genes or spends garden resources")
	check_bounds("English desktop market")
	await check_protected_sales(favorite_id,ripe_parent,mother,father)
	await check_fruit_sale(sale_fruit)
	await check_seed_sale()
	await check_plant_sale(seller,str(descendant.id))
	await check_purchases()
	await check_reload(seller,str(descendant.id))
	await check_localized_layouts()
	game.queue_free()
	await settle()
	Locale.set_language("en")
	for path: String in [save_path,save_path.get_basename()+".backup.json",save_path.get_basename()+".audio.cfg",save_path.get_basename()+".language.cfg"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	print("MARKET INTEGRATION TESTS: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)

func check_protected_sales(favorite_id: String,ripe_parent: String,mother: String,father: String) -> void:
	check(bool(game.state.pollinate(mother,father).ok),"A protected mother fixture has a real developing hybrid crop")
	for entry: Array in [[favorite_id,"favorite"],[ripe_parent,"ripe fruit"],[mother,"hybrid fruit"]]:
		var id: String = str(entry[0])
		game._open_market("plants")
		await settle()
		var before: String = economy()
		if not await press("review_sale",{"item_kind":"plant","item_ref":id},str(entry[1])+" protection review"): continue
		var quote: Dictionary = game.modal.get_meta("market_quote",{})
		check(not bool(quote.get("eligible",true)) and not str(quote.get("reason","")).is_empty(),str(entry[1])+" has an explained sale restriction")
		var confirm: Button = find_action(game.modal,"confirm_sale",{"item_kind":"plant","item_ref":id})
		check(confirm!=null and confirm.disabled,str(entry[1])+" cannot be sold through the actual confirm control")
		check(economy()==before,str(entry[1])+" review preserves the plant, fruit, wallet and RNG")
		if await press("cancel",{},str(entry[1])+" keep action"):
			check(game.modal_kind=="market" and economy()==before,"Keeping "+str(entry[1])+" returns without a trade")

func check_fruit_sale(id: String) -> void:
	var fruit_count: int = game.state.fruit_inventory.size()
	var seeds: String = DNA.canonical(game.state.seed_bank)
	var wallet: int = int(game.state.market_wallet())
	var quote: Dictionary = await review("fruit",id,"Whole hybrid fruit")
	if quote.is_empty(): return
	check(text_in(game.modal).contains("including its seeds"),"Fruit review explains that the buyer receives the embryos inside")
	var snapshot: String = economy()
	if await press("cancel",{},"Keep hybrid fruit"):
		check(economy()==snapshot,"Canceling a reviewed fruit offer leaves every seed and coin intact")
	quote = await review("fruit",id,"Accepted hybrid fruit")
	if quote.is_empty(): return
	if await press("confirm_sale",{"item_kind":"fruit","item_ref":id},"Hybrid fruit sale"):
		check(int(game.state.market_wallet())==wallet+int(quote.price),"Confirmed fruit sale credits exactly the reviewed coin amount")
		check(game.state.fruit_inventory.size()==fruit_count-1 and inventory_row("fruit",id).is_empty(),"Confirmed fruit sale removes exactly that stored fruit")
		check(DNA.canonical(game.state.seed_bank)==seeds,"Selling whole fruit does not extract or duplicate its seeds")
		check(game.modal_kind=="market","A completed sale returns to the market")
		var receipts: Array = game.state.market_history()
		check(not receipts.is_empty() and receipts[0].action=="sell" and receipts[0].kind=="fruit" and int(receipts[0].price)==int(quote.price),"The newest receipt records the exact fruit trade")

func check_seed_sale() -> void:
	var rows: Array = game.state.market_inventory("seed")
	var chosen: Dictionary = {}
	var sibling: Dictionary = {}
	for row: Dictionary in rows:
		if not row.get("seed",{}).has("genome"): continue
		if chosen.is_empty(): chosen=row
		else: sibling=row; break
	check(not chosen.is_empty() and not sibling.is_empty(),"Seed trading includes independently inherited full-genome hybrid seeds")
	if chosen.is_empty() or sibling.is_empty(): return
	var reference: Variant = chosen.reference
	check(reference is Dictionary and reference.has("fingerprint") and reference.has("occurrence"),"The reviewed seed uses a stable content reference rather than its list index")
	var quote: Dictionary = await review("seed",reference,"Hybrid seed")
	if quote.is_empty(): return
	var seed_count: int = game.state.seed_bank.size()
	var sibling_before: String = DNA.canonical(sibling.seed)
	# Sowing an earlier founding seed shifts the reviewed seed's list index.
	# This is a real inventory operation, not a synthetic mutation of the list.
	check(bool(game.state.plant_seed(0).ok),"An earlier seed can be sown while a previously captured seed reference remains valid")
	check(not inventory_row("seed",reference).is_empty(),"The reviewed hybrid seed still resolves after its old index shifts")
	var wallet: int = int(game.state.market_wallet())
	var confirm: Button = find_action(game.modal,"confirm_sale",{"item_kind":"seed","item_ref":reference})
	check(confirm!=null and not confirm.disabled,"The captured seed review retains its exact confirmation action")
	if confirm==null or confirm.disabled: return
	# A queued double tap must never sell the seed that shifts into the old slot.
	confirm.pressed.emit()
	confirm.pressed.emit()
	await settle()
	check(int(game.state.market_wallet())==wallet+int(quote.price),"A shifted-index seed and queued double tap earn exactly one reviewed payment")
	check(game.state.seed_bank.size()==seed_count-2,"Only the earlier sown seed and the reviewed sold seed leave inventory")
	check(inventory_row("seed",reference).is_empty(),"The sold seed's stable reference is no longer available")
	var survivor: Dictionary = inventory_row("seed",sibling.reference)
	check(not survivor.is_empty() and DNA.canonical(survivor.seed)==sibling_before,"The adjacent seed keeps its complete genome instead of being sold by a stale index")

func check_plant_sale(id: String,child_id: String) -> void:
	var before_genes: String = genetics(id)
	var child_genes: String = genetics(child_id)
	var before_count: int = game.state.plant_order.size()
	var wallet: int = int(game.state.market_wallet())
	var quote: Dictionary = await review("plant",id,"Living parent")
	if quote.is_empty(): return
	# A treatment changes the actual specimen and its offer while this earlier
	# review is still open. The UI must ask for a fresh review, never accept it.
	check(bool(game.state.apply_care(id,"growth").ok) and bool(game.state.apply_care(id,"compost").ok),"Real care can change a specimen after an offer was captured")
	game._refresh_market_counters()
	await settle()
	var old_confirm: Button = find_action(game.modal,"confirm_sale",{"item_kind":"plant","item_ref":id})
	check(old_confirm!=null and old_confirm.disabled,"A changed specimen disables the stale sale decision")
	check(int(game.state.market_wallet())==wallet and bool(game.state.owns_plant(id)),"An outdated review never trades the changed plant automatically")
	var old_quote: String = str(quote.quote_id)
	var old_price: int = int(quote.price)
	if not await press("refresh_offer",{},"Refresh changed plant offer"): return
	quote = game.modal.get_meta("market_quote",{})
	check(str(quote.get("quote_id",""))!=old_quote and int(quote.get("price",0))>old_price,"Refreshing shows the real new care-grown price and replaces the old quote")
	check(text_in(game.modal).contains("family tree") and text_in(game.modal).contains("archive"),"Plant review explains that its pedigree stays in the archive")
	var note: String = "\n".join(quote.get("notes",[]))
	check(note.to_lower().contains("fruit"),"The review discloses that its unripe natural fruit travels with the sold plant")
	if await press("confirm_sale",{"item_kind":"plant","item_ref":id},"Living parent sale"):
		check(int(game.state.market_wallet())==wallet+int(quote.price),"Confirmed parent sale credits exactly the accepted offer")
		check(game.state.plant_order.size()==before_count-1 and not bool(game.state.owns_plant(id)),"The sold parent leaves the owned collection")
		check(game.state.plants.has(id) and genetics(id)==before_genes,"The sold parent's full inherited genome stays in the permanent archive")
		check(genetics(child_id)==child_genes and game.state.get_plant(child_id).parents.has(id),"A living descendant retains the sold parent and every inherited gene")
		check(not game.state.bed.has(id) and not game.state.display_bed.has(id),"The sold parent vacates active soil and display cells")
		check(not game.state.fruit_crops.has(id),"Unripe natural fruit no longer produces rewards for a sold plant")
		var after: int = int(game.state.market_wallet())
		check(not bool(game.state.market_sell("plant",id,str(quote.quote_id)).ok) and int(game.state.market_wallet())==after,"An archived sold plant cannot be sold a second time")

func stock_row(key: String) -> Dictionary:
	for row: Dictionary in game.state.market_stock():
		if str(row.key)==key: return row
	return {}

func check_purchases() -> void:
	game._open_market("shop")
	await settle()
	check_bounds("Useful supply shop")
	var sunlight: int = int(game.state.resources.sunlight)
	var kits: int = int(game.state.field_kits)
	var wallet: int = int(game.state.market_wallet())
	var stock: Dictionary = stock_row("sunlight")
	if await press("buy",{"stock_key":"sunlight"},"Bottled sunlight purchase"):
		check(int(game.state.market_wallet())==wallet-int(stock.cost),"The sunlight purchase spends its disclosed coin price")
		check(int(game.state.resources.sunlight)==sunlight+int(stock.amount),"Purchased sunlight can actually fund sowing and care")
	wallet = int(game.state.market_wallet())
	stock = stock_row("field_kits")
	if await press("buy",{"stock_key":"field_kits"},"Field supplies purchase"):
		check(int(game.state.market_wallet())==wallet-int(stock.cost),"Field supplies spend their own disclosed coin price")
		check(int(game.state.field_kits)==kits+int(stock.amount),"Purchased field kits can actually collect wild plants")
	wallet = int(game.state.market_wallet())
	stock = stock_row("founding_seed")
	var seed_count: int = game.state.seed_bank.size()
	if await press("buy",{"stock_key":"founding_seed"},"Founder's seed purchase"):
		check(int(game.state.market_wallet())==wallet-int(stock.cost) and game.state.seed_bank.size()==seed_count+1,"Buying a founder's seed spends exactly its price and adds one usable seed")
		var seed: Dictionary = game.state.seed_bank.back()
		check(str(seed.rarity)=="Common","The shop delivers the advertised common founding seed")
		var count: int = game.state.plant_order.size()
		check(bool(game.state.plant_seed(game.state.seed_bank.size()-1).ok) and game.state.plant_order.size()==count+1,"The purchased seed can really be planted into a new individual")
	game._open_market("shop")
	await settle()
	var costly: Button = find_action(game.modal,"buy",{"stock_key":"founding_seed"})
	check(costly!=null and costly.disabled,"The shop visibly blocks a purchase the remaining wallet cannot afford")
	var balance: int = int(game.state.market_wallet())
	seed_count = game.state.seed_bank.size()
	check(not bool(game.state.market_buy("founding_seed").ok) and int(game.state.market_wallet())==balance and game.state.seed_bank.size()==seed_count,"An unaffordable purchase cannot spend coins or create a free item")

func check_reload(sold_id: String,child_id: String) -> void:
	game.state.save_game()
	var restored = State.new(save_path)
	check(restored.load_game(),"The traded garden reloads")
	check(int(restored.market_wallet())==int(game.state.market_wallet()),"The separate coin wallet survives reload exactly")
	check(DNA.canonical(restored.market_history())==DNA.canonical(game.state.market_history()),"Recent sale and purchase receipts survive reload")
	check(DNA.canonical(restored.market_stock())==DNA.canonical(game.state.market_stock()),"The same deterministic market offers survive reload")
	check(restored.plants.has(sold_id) and not bool(restored.owns_plant(sold_id)) and restored.get_plant(child_id).parents.has(sold_id),"Reload preserves sold-parent archives and the descendant's pedigree")

func check_localized_layouts() -> void:
	for config: Array in [["en",Vector2i(1440,1000)],["zh_CN",Vector2i(390,780)],["en",Vector2i(390,780)],["zh_CN",Vector2i(1440,1000)]]:
		Locale.set_language(str(config[0]))
		root.size = config[1]
		await settle()
		var before: String = economy()
		game._open_market("plants")
		await settle()
		for tab: String in ["plants","fruits","seeds","shop","history","prices"]:
			if not await press("tab",{"market_tab":tab},str(config[0])+" "+tab+" navigation"): continue
			game._localize_ui()
			await settle()
			check_bounds(str(config[0])+" "+str(config[1])+" "+tab)
			check(str(game.modal.get_meta("market_tab",""))==tab,"Market navigation retains canonical tab IDs in "+str(config[0]))
			if str(config[0])=="zh_CN":
				var shown: String = text_in(game.modal)
				check(shown.contains("金币") and not shown.contains("Today's wish list"),"Chinese market explains its wallet and daily demand in Chinese")
		check(economy()==before,"Browsing every "+str(config[0])+" market tab changes no coins, items, prices or RNG")
		var rows: Array = game.state.market_inventory("seed")
		if not rows.is_empty():
			game._review_market_sale("seed",rows[0].reference)
			game._localize_ui()
			await settle()
			check_bounds(str(config[0])+" "+str(config[1])+" sale review")
			if str(config[0])=="zh_CN":
				check(text_in(game.modal).contains("报价") and not text_in(game.modal).contains("How this offer adds up"),"Chinese sale reviews explain the exact price rather than exposing untranslated accounting")
		check(economy()==before,"Opening a translated sale review still performs no sale")
