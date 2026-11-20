extends RefCounted
## The village stall: transparent offers, a deliberate sale, useful supplies.
const Portrait = preload("res://scripts/plant_portrait.gd")
const Icon = preload("res://scripts/market_icon.gd")
const INK := Color("284838")
const MUTED := Color("617957")
const WARM := Color("a4542b")
const PAGE_SIZE: int = 12
const TABS := {"plants":"Plants","fruits":"Fruit","seeds":"Seeds","shop":"Shop","history":"Receipts","prices":"Prices"}
const KINDS := {"plants":"plant","fruits":"fruit","seeds":"seed"}

static func _card(g: Control,parent: Node,color: String = "fff8df") -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel",g._style(Color(color),Color("adc58d"),0,12,11))
	parent.add_child(panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation",8)
	panel.add_child(body)
	return body

static func _action(g: Control,text: String,action: Callable,kind: String) -> Button:
	var button: Button = g._button(text,action)
	button.set_meta("market_action",kind)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size.y = 42
	return button

static func _wallet(g: Control,parent: Node) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",8)
	parent.add_child(row)
	var coin := Icon.new()
	coin.kind = "coin"
	coin.custom_minimum_size = Vector2(28,28)
	row.add_child(coin)
	var label: Label = g._wrap("%d coins" % g.state.market_wallet(),22,INK)
	label.set_meta("market_wallet",true)
	row.add_child(label)
	g.market_labels.append(label)

static func _tabs(g: Control) -> void:
	var tabs := GridContainer.new()
	tabs.columns = 3 if g.small_layout else 6
	tabs.add_theme_constant_override("h_separation",6)
	tabs.add_theme_constant_override("v_separation",6)
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	g.modal_content.add_child(tabs)
	for tab: String in TABS:
		var button: Button = _action(g,str(TABS[tab]),func(): g.market_page=0; g._open_market(tab),"tab")
		button.set_meta("market_tab",tab)
		button.clip_text = true
		button.tooltip_text = str(TABS[tab])
		if tab==g.market_tab: button.add_theme_stylebox_override("normal",g._style(Color("ffcf94"),Color("cb9258"),0,10,9))
		tabs.add_child(button)

static func show(g: Control,tab: String = "plants",feedback: String = "") -> void:
	if g.exploring: g._return_from_wilderness()
	g.market_tab = tab if TABS.has(tab) else "plants"
	g._open_modal("The Sprout Market","market")
	g.modal.set_meta("market_tab",g.market_tab)
	var hero := HBoxContainer.new()
	hero.add_theme_constant_override("separation",12)
	g.modal_content.add_child(hero)
	var stall := Icon.new()
	stall.kind = "stall"
	stall.custom_minimum_size = Vector2(60,64) if g.small_layout else Vector2(88,76)
	hero.add_child(stall)
	var greeting := VBoxContainer.new()
	greeting.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero.add_child(greeting)
	greeting.add_child(g._wrap("Grow it. Love it. Trade it!",17 if g.small_layout else 20,WARM))
	_wallet(g,greeting)
	if not feedback.is_empty():
		var cheer: Label = g._wrap(feedback,16,WARM)
		cheer.set_meta("market_feedback",true)
		g.modal_content.add_child(cheer)
	var day: Dictionary = g.state.market_day()
	var demand := _card(g,g.modal_content,"e3f0d0")
	demand.add_child(g._wrap("Today's wish list · %s" % str(day.get("label","")),14,INK))
	demand.add_child(g._wrap("%s plants · %s patterns" % [str(day.get("type",day.get("wanted_type","Leaf"))),str(day.get("pattern",day.get("wanted_pattern","Striped")))],15,WARM))
	demand.add_child(g._wrap("Wanted type +%d coins · wanted pattern +%d coins" % [int(day.get("type_bonus",6)),int(day.get("pattern_bonus",4))],11,MUTED))
	_tabs(g)
	match g.market_tab:
		"shop": _shop(g)
		"history": _history(g)
		"prices": _prices(g)
		_: _inventory(g,str(KINDS[g.market_tab]))
	var book: Button = _action(g,"Open collection book",g._open_codex,"collection")
	g.modal_content.add_child(book)

static func _inventory(g: Control,kind: String) -> void:
	var rows: Array = g.state.market_inventory(kind)
	g.modal_content.add_child(g._wrap({"plant":"Find a new home for a plant. Its family history stays with you.","fruit":"Sell a harvested fruit, or keep it to collect the seeds inside.","seed":"Share a seed with another gardener. Its inherited traits shape the offer."}[kind],13,MUTED))
	if rows.is_empty():
		g.modal_content.add_child(g._wrap({"plant":"No plants at the stall yet. Sow a seed or bring a new friend home from the wild.","fruit":"Your basket is empty. Harvest ripe fruit before bringing it to market.","seed":"No seeds to sell yet. Open a harvested fruit to fill your seed box."}[kind],16,INK))
		g.modal_content.add_child(_action(g,"Visit fruit & seeds",g._open_seeds,"nursery"))
		return
	var pages: int = maxi(1,ceili(rows.size()/float(PAGE_SIZE)))
	g.market_page = clampi(g.market_page,0,pages-1)
	if pages>1:
		var navigation := HBoxContainer.new()
		g.modal_content.add_child(navigation)
		var previous: Button = _action(g,"Previous",func(): g.market_page-=1; g._open_market(g.market_tab),"previous")
		previous.disabled = g.market_page==0
		navigation.add_child(previous)
		var page: Label = g._wrap("Page %d / %d · %d items" % [g.market_page+1,pages,rows.size()],12,MUTED)
		page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		navigation.add_child(page)
		var next: Button = _action(g,"Next",func(): g.market_page+=1; g._open_market(g.market_tab),"next")
		next.disabled = g.market_page>=pages-1
		navigation.add_child(next)
	var grid := GridContainer.new()
	grid.columns = 1 if g.small_layout else 2
	grid.add_theme_constant_override("h_separation",12)
	grid.add_theme_constant_override("v_separation",12)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	g.modal_content.add_child(grid)
	for index in range(g.market_page*PAGE_SIZE,mini(rows.size(),(g.market_page+1)*PAGE_SIZE)):
		var row: Dictionary = rows[index]
		var reference: Variant = row.reference
		var quote: Dictionary = row.get("quote",{})
		var card := _card(g,grid,"fff1c8" if kind=="seed" else "fff8df")
		var heading := HBoxContainer.new()
		card.add_child(heading)
		var p: Dictionary = row.get("plant",{})
		if kind=="plant" and not p.is_empty():
			var art := Portrait.new()
			art.plant = p
			art.custom_minimum_size = Vector2(68,90)
			heading.add_child(art)
		else:
			var icon := Icon.new()
			icon.kind = kind
			icon.custom_minimum_size = Vector2(48,56)
			heading.add_child(icon)
		var words := VBoxContainer.new()
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		heading.add_child(words)
		words.add_child(g._wrap(str(row.get("name",quote.get("name","Garden treasure"))),18,INK))
		words.add_child(g._wrap("Offer · %d coins" % int(quote.get("price",0)),17,WARM))
		if kind=="plant":
			words.add_child(g._wrap(g.CareUI.measurement_text(g.state.plant_measurements(str(reference))),12,MUTED))
			words.add_child(g._wrap("%s · Generation %d" % [str(p.get("rarity","Common")),int(p.get("generation",1))],11,MUTED))
		elif kind=="fruit":
			var fruit: Dictionary = row.get("fruit",{})
			words.add_child(g._wrap("%d seeds inside · Generation %d" % [fruit.get("seeds",[]).size(),int(fruit.get("generation",1))],12,MUTED))
		else:
			var seed_data: Dictionary = row.get("seed",{})
			words.add_child(g._wrap("%s · %s" % [str(seed_data.get("rarity","Common")),str(seed_data.get("type","Leaf"))],12,MUTED))
		if not quote.get("eligible",false): card.add_child(g._wrap(str(quote.get("reason","")),12,WARM))
		var review: Button = _action(g,"See offer · %d coins" % int(quote.get("price",0)),func(): g._review_market_sale(kind,reference),"review_sale")
		review.set_meta("item_kind",kind)
		review.set_meta("item_ref",reference)
		review.disabled = g.sim!=null
		card.add_child(review)

static func _shop(g: Control) -> void:
	g.modal_content.add_child(g._wrap("Turn your garden treasures into your next adventure.",16,INK))
	var grid := GridContainer.new()
	grid.columns = 1 if g.small_layout else 2
	grid.add_theme_constant_override("h_separation",12)
	grid.add_theme_constant_override("v_separation",12)
	g.modal_content.add_child(grid)
	for stock: Dictionary in g.state.market_stock():
		var stock_key: String = str(stock.key)
		var card := _card(g,grid,"e8efc5")
		var heading := HBoxContainer.new()
		card.add_child(heading)
		var icon := Icon.new()
		icon.kind = {"sunlight":"sunlight","field_kits":"kit","founding_seed":"seed","graft_material":"graft","mutation_agent":"agent"}.get(stock_key,"coin")
		icon.custom_minimum_size = Vector2(48,48)
		heading.add_child(icon)
		heading.add_child(g._wrap(str(stock.name),18,INK))
		card.add_child(g._wrap(str(stock.get("description","")),13,MUTED))
		var buy: Button = _action(g,"Buy · %d coins" % int(stock.cost),func(): g._market_buy(stock_key),"buy")
		buy.set_meta("stock_key",stock_key)
		buy.set_meta("market_cost",int(stock.cost))
		buy.disabled = g.sim!=null or g.state.market_wallet()<int(stock.cost)
		card.add_child(buy)
		g.market_buttons.append(buy)
		if g.state.market_wallet()<int(stock.cost): card.add_child(g._wrap("Sell something from your garden to earn more coins.",11,MUTED))

static func _history(g: Control) -> void:
	var receipts: Array = g.state.market_history()
	g.modal_content.add_child(g._wrap("Your recent trades",19,INK))
	if receipts.is_empty():
		g.modal_content.add_child(g._wrap("Your first trade is waiting. Choose a plant, fruit, or seed to see its offer.",15,MUTED))
		return
	for index in range(mini(receipts.size(),20)):
		var receipt: Dictionary = receipts[index]
		var card := _card(g,g.modal_content)
		card.add_child(g._wrap(str(receipt.get("name","Garden trade")),16,INK))
		var bought: bool = str(receipt.get("action",receipt.get("kind","")))=="buy"
		card.add_child(g._wrap(("Bought · −%d coins" if bought else "Sold · +%d coins") % int(receipt.get("price",receipt.get("amount",0))),14,WARM))
		var date: String = Time.get_datetime_string_from_unix_time(int(receipt.get("at",0)),true)+" UTC"
		if not date.is_empty(): card.add_child(g._wrap(date,11,MUTED))
		if not bought and str(receipt.get("kind",""))=="plant" and not g.state.get_plant(str(receipt.get("key",""))).is_empty():
			var plant_id: String = str(receipt.key)
			var record: Button = _action(g,"Visit its family record",func(): g._open_detail(plant_id),"archive")
			record.set_meta("plant_id",plant_id)
			card.add_child(record)

static func _prices(g: Control) -> void:
	g.modal_content.add_child(g._wrap("Why is this one worth more?",22,INK))
	for pair: Array in [
		["Start with a fair offer","Plants start at 20 coins, fruit at 8, and seeds at 4. The offer adds quality bonuses to that base."],
		["Beautiful genes find eager collectors","Rarity, unusual patterns, glow, and mixed ancestry can add value. A high generation alone does not make an endless price ladder."],
		["Size and life matter","Natural height and weight add value; care-grown size adds at most 3 coins. Seedlings lose 30% of their quality subtotal, aging plants 15%, and the final 5% of life 35%. Withered plants offer 1–3 compost coins before supply adjustment."],
		["Fruit carries a whole future","Each seed inside adds 2 coins; hybrid fruit adds another 4. Extra quality comes from its best seed. Selling the fruit transfers all its seeds too."],
		["The wish list changes each day","The wanted plant type adds 6 coins and the wanted pattern adds 4. Withered plants receive no demand bonus. Offers stay steady when you reopen the stall."],
		["A full stall needs fewer of the same thing","Each sale lowers the next offer in that category by 4 percentage points, down to 60% after ten sales. Demand resets at 00:00 UTC."],
		["Read the offer before you trade","Every offer lists the exact coin amounts. If the item or its price changes, review the new offer before selling."]
	]:
		var card := _card(g,g.modal_content)
		card.add_child(g._wrap(str(pair[0]),17,WARM))
		card.add_child(g._wrap(str(pair[1]),13,MUTED))

static func review(g: Control,kind: String,reference: Variant,feedback: String = "") -> void:
	var quote: Dictionary = g.state.market_quote(kind,reference)
	g._open_modal("A new home, a fair offer","market_review")
	g.modal.set_meta("market_quote",quote.duplicate(true))
	g.modal.set_meta("item_kind",kind)
	g.modal.set_meta("item_ref",reference)
	_wallet(g,g.modal_content)
	var live_notice: Label = g._wrap("",12,WARM)
	live_notice.set_meta("market_review_notice",true)
	live_notice.visible = false
	g.modal_content.add_child(live_notice)
	if not feedback.is_empty(): g.modal_content.add_child(g._wrap(feedback,15,WARM))
	if not quote.get("ok",false):
		g.modal_content.add_child(g._wrap(str(quote.get("reason","This item is no longer at your stall.")),16,WARM))
		g.modal_content.add_child(_action(g,"Back to the market",func(): g._open_market(g.market_tab),"cancel"))
		return
	var hero := HBoxContainer.new()
	g.modal_content.add_child(hero)
	if kind=="plant":
		var art := Portrait.new()
		art.plant = g.state.get_plant(str(reference))
		art.custom_minimum_size = Vector2(86,125) if g.small_layout else Vector2(145,160)
		hero.add_child(art)
	else:
		var icon := Icon.new()
		icon.kind = kind
		icon.custom_minimum_size = Vector2(56,64)
		hero.add_child(icon)
	var notes := VBoxContainer.new()
	notes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero.add_child(notes)
	notes.add_child(g._wrap(str(quote.name),22,INK))
	var price: Label = g._wrap("Your offer · %d coins" % int(quote.price),23,WARM)
	price.set_meta("market_price",int(quote.price))
	notes.add_child(price)
	if kind=="plant": notes.add_child(g._measurement_label(str(reference)))
	var breakdown := _card(g,g.modal_content,"fff0b8")
	breakdown.add_child(g._wrap("How this offer adds up",18,INK))
	for component: Dictionary in quote.get("breakdown",[]):
		var row := HBoxContainer.new()
		breakdown.add_child(row)
		var text: Label = g._wrap(str(component.get("label","")),13,MUTED)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)
		var amount: int = int(component.get("amount",0))
		row.add_child(g._label(("+%d" if amount>=0 else "%d") % amount,15,INK))
	for note: Variant in quote.get("notes",[]): g.modal_content.add_child(g._wrap(str(note),12,MUTED))
	if kind=="plant":
		g.modal_content.add_child(_action(g,"Open plant details",func(): g._open_detail(str(reference)),"inspect"))
	elif kind=="fruit": g.modal_content.add_child(g._wrap("The buyer gets this whole fruit, including its seeds. Extract the seeds first if you want to keep them.",13,MUTED))
	else: g.modal_content.add_child(g._wrap("The buyer gets this seed. Your other seeds keep their own DNA.",13,MUTED))
	if not quote.get("eligible",false): g.modal_content.add_child(g._wrap(str(quote.get("reason","")),14,WARM))
	# Keep the final decision visible while a long breakdown scrolls above it.
	var footer := VBoxContainer.new()
	footer.add_theme_constant_override("separation",7)
	g.modal.get_node("Panel").get_child(0).add_child(footer)
	var quote_id: String = str(quote.get("quote_id",""))
	var sell: Button = _action(g,"Sell for %d coins" % int(quote.price),func(): g._confirm_market_sale(kind,reference,quote_id),"confirm_sale")
	sell.set_meta("item_kind",kind)
	sell.set_meta("item_ref",reference)
	sell.set_meta("quote_id",quote_id)
	sell.disabled = not quote.get("eligible",false) or g.sim!=null
	sell.add_theme_stylebox_override("normal",g._style(Color("ffcf94"),Color("cb9258"),0,12,11))
	footer.add_child(sell)
	g.market_buttons.append(sell)
	var refresh: Button = _action(g,"Refresh offer",func(): g._review_market_sale(kind,reference),"refresh_offer")
	refresh.set_meta("item_kind",kind)
	refresh.set_meta("item_ref",reference)
	refresh.set_meta("quote_id",quote_id)
	refresh.visible = false
	footer.add_child(refresh)
	g.market_buttons.append(refresh)
	footer.add_child(_action(g,"Keep it · back to market",func(): g._open_market(g.market_tab),"cancel"))
