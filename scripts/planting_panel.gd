extends RefCounted
## The planting path explains the action where it happens: seed, plot, sprout.
const Portrait = preload("res://scripts/plant_portrait.gd")
const Care = preload("res://scripts/plant_care.gd")
const INK := Color("284838")
const MUTED := Color("617957")
const WARM := Color("a4542b")
const PAGE_SIZE: int = 9

static func _action(g: Control,title: String,callback: Callable,action: String) -> Button:
	var button: Button = g._button(title,callback)
	button.set_meta("planting_action",action)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size.y = 42
	return button

static func _card(g: Control,parent: Node) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel",g._style(Color("fff6d2"),Color("a4bb7f"),0,12,11))
	parent.add_child(panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation",8)
	panel.add_child(body)
	return body

static func _preview(g: Control,seed_data: Dictionary) -> Dictionary:
	var p: Dictionary = seed_data.get("genome",{}).duplicate(true)
	if p.is_empty():
		# This is an explicitly illustrative founding form. A private deterministic
		# organism seed and ID keep inspection from consuming gameplay randomness.
		p = g.state._create_base(int(seed_data.get("species_index",0)),maxi(1,int(seed_data.get("seed",1))),"planting_preview")
		if seed_data.has("pattern"): p.genes.pattern.dominant = seed_data.pattern
	p["mature"] = true
	p["withered"] = false
	p["life_age"] = 0.0
	p["care"] = Care.default_care()
	return p

static func _resolve(g: Control,reference: Variant) -> Dictionary:
	return g.state._market_resolve("seed",reference)

static func _footer(g: Control) -> VBoxContainer:
	var footer := VBoxContainer.new()
	footer.add_theme_constant_override("separation",7)
	g.modal.get_node("Panel").get_child(0).add_child(footer)
	return footer

static func _plot_map(g: Control,parent: Node,cell: int,reference: Variant) -> void:
	parent.add_child(g._wrap("Your grow patch · plot %d selected" % [cell+1],14,INK))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation",6)
	grid.add_theme_constant_override("v_separation",6)
	parent.add_child(grid)
	for index in range(9):
		var occupied: bool = not str(g.state.bed[index]).is_empty()
		var label: String = "Occupied" if occupied else ("%d · HERE" % [index+1] if index==cell else "%d · empty" % [index+1])
		var button: Button = _action(g,label,func(): g._open_planting(index,reference),"choose_plot")
		button.set_meta("bed_index",index)
		button.clip_text = true
		button.custom_minimum_size.y = 34
		button.disabled = occupied
		if index==cell: button.add_theme_stylebox_override("normal",g._style(Color("ffcf92"),Color("c9884a"),0,5,5))
		grid.add_child(button)
	parent.add_child(g._wrap("Tap a different empty plot above if you want to change the spot.",11,MUTED))

static func show(g: Control,requested_cell: int = -1,reference: Variant = null,feedback: String = "") -> void:
	if g.exploring: g._return_from_wilderness()
	var cell: int = requested_cell
	if cell<0: cell = g.state.bed.find("")
	if cell>=0 and cell<9 and not str(g.state.bed[cell]).is_empty():
		cell = g.state.bed.find("")
		feedback = "That plot is now occupied. Choose another empty spot."
	if cell<0 or cell>=9:
		_show_full(g)
		return
	if reference!=null:
		_review(g,cell,reference,feedback)
		return
	g._open_modal("Plant a seed","planting")
	g.modal.set_meta("bed_index",cell)
	g.modal_content.add_child(g._wrap("1 · Choose a seed",22,INK))
	g.modal_content.add_child(g._wrap("Tap a seed below. Next, plant it in plot %d." % [cell+1],14,WARM))
	g.modal_content.add_child(g._wrap("10 light to plant · grows automatically in 12 seconds",13,MUTED))
	if not feedback.is_empty(): g.modal_content.add_child(g._wrap(feedback,14,WARM))
	if g.state.seed_bank.is_empty():
		g.modal_content.add_child(g._wrap("Your seed box is empty. Harvest a fruit and open it to get seeds, or buy a seed at the market.",16,INK))
		g.modal_content.add_child(_action(g,"Get seeds from fruit",func(): g.nursery_tab="fruits" if not g.state.fruit_inventory.is_empty() else "plants"; g._open_seeds(),"get_seeds"))
		g.modal_content.add_child(_action(g,"Buy seeds at the market",func(): g._open_market("shop"),"buy_seeds"))
	else:
		var pages: int = maxi(1,ceili(g.state.seed_bank.size()/float(PAGE_SIZE)))
		g.planting_page = clampi(g.planting_page,0,pages-1)
		if pages>1:
			var navigation := HBoxContainer.new()
			g.modal_content.add_child(navigation)
			var previous: Button = _action(g,"Previous",func(): g.planting_page-=1; g._open_planting(cell),"previous")
			previous.disabled = g.planting_page==0
			navigation.add_child(previous)
			navigation.add_child(g._wrap("Page %d / %d" % [g.planting_page+1,pages],12,MUTED))
			var next: Button = _action(g,"Next",func(): g.planting_page+=1; g._open_planting(cell),"next")
			next.disabled = g.planting_page>=pages-1
			navigation.add_child(next)
		var grid := GridContainer.new()
		grid.columns = 1 if g.small_layout else 3
		grid.add_theme_constant_override("h_separation",10)
		grid.add_theme_constant_override("v_separation",10)
		g.modal_content.add_child(grid)
		for offset in range(g.planting_page*PAGE_SIZE,mini(g.state.seed_bank.size(),(g.planting_page+1)*PAGE_SIZE)):
			var index: int = g.state.seed_bank.size()-1-offset
			var seed_data: Dictionary = g.state.seed_bank[index]
			var seed_ref: Variant = g.state.market_ref("seed",index)
			var card := _card(g,grid)
			var row: BoxContainer = HBoxContainer.new() if g.small_layout else VBoxContainer.new()
			card.add_child(row)
			var art := Portrait.new()
			art.plant = _preview(g,seed_data)
			art.custom_minimum_size = Vector2(72,100) if g.small_layout else Vector2(100,112)
			row.add_child(art)
			var notes := VBoxContainer.new()
			notes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(notes)
			notes.add_child(g._wrap(str(seed_data.get("name","Garden seed")),17,INK))
			notes.add_child(g._wrap("%s plant" % str(seed_data.get("type",art.plant.get("type","Leaf"))),12,WARM))
			notes.add_child(g._wrap("Inherited grown form" if seed_data.has("genome") else "Possible grown form",11,MUTED))
			var choose: Button = _action(g,"Choose this seed",func(): g._open_planting(cell,seed_ref),"choose_seed")
			choose.set_meta("seed_ref",seed_ref)
			choose.set_meta("seed_index",index)
			choose.set_meta("bed_index",cell)
			card.add_child(choose)
	var footer := _footer(g)
	footer.add_child(_action(g,"Move an existing plant here instead",func(): show_move_picker(g,"bed",cell),"move_existing"))
	footer.add_child(_action(g,"Cancel · back to garden",g._close_modal,"cancel"))

static func _review(g: Control,cell: int,reference: Variant,feedback: String) -> void:
	var resolved: Dictionary = _resolve(g,reference)
	if resolved.is_empty():
		show(g,cell,null,"That seed is no longer in your box. Choose another one.")
		return
	var seed_data: Dictionary = resolved.item
	g._open_modal("Plant it here?","planting_confirm")
	g.modal.set_meta("bed_index",cell)
	g.modal.set_meta("seed_ref",reference)
	g.modal_content.add_child(g._wrap("2 · Plant your seed",22,INK))
	if not feedback.is_empty(): g.modal_content.add_child(g._wrap(feedback,14,WARM))
	var hero := HBoxContainer.new()
	hero.add_theme_constant_override("separation",12)
	g.modal_content.add_child(hero)
	var art := Portrait.new()
	art.plant = _preview(g,seed_data)
	art.custom_minimum_size = Vector2(92,140) if g.small_layout else Vector2(155,180)
	hero.add_child(art)
	var notes := VBoxContainer.new()
	notes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero.add_child(notes)
	notes.add_child(g._wrap(str(seed_data.get("name","Garden seed")),21,INK))
	notes.add_child(g._wrap("Grows in 12 seconds. No watering needed to start!",14,WARM))
	notes.add_child(g._wrap("This is its inherited grown form. It starts as a little seedling." if seed_data.has("genome") else "This is one possible grown form. Your seed's own traits will appear as it grows.",12,MUTED))
	var cost := _card(g,g.modal_content)
	cost.add_child(g._wrap("Planting cost: 10 light · You have %d" % int(g.state.resources.sunlight),15,INK))
	if int(g.state.resources.sunlight)<10:
		cost.add_child(g._wrap("You need more light. Harvest ripe fruit or buy bottled sunlight at the market.",13,WARM))
		cost.add_child(_action(g,"Get sunlight at the market",func(): g._open_market("shop"),"get_light"))
	_plot_map(g,g.modal_content,cell,reference)
	var footer := _footer(g)
	var plant: Button = _action(g,"Plant here · 10 light",func(): g._sow_at(reference,cell),"plant_seed")
	plant.set_meta("seed_ref",reference)
	plant.set_meta("bed_index",cell)
	plant.disabled = int(g.state.resources.sunlight)<10
	plant.add_theme_stylebox_override("normal",g._style(Color("ffbc89"),Color("c9874e"),0,12,12))
	footer.add_child(plant)
	g.planting_buttons.append(plant)
	footer.add_child(_action(g,"Back · choose another seed",func(): g._open_planting(cell),"back"))

static func countdown(g: Control,id: String) -> String:
	var p: Dictionary = g.state.get_plant(id)
	if p.get("mature",false): return "All grown up! Ready to breed and grow fruit."
	return "Growing · %d seconds to go" % maxi(0,int(p.get("ready_at",0))-int(Time.get_unix_time_from_system()))

static func planted(g: Control,p: Dictionary,cell: int) -> void:
	var id: String = str(p.id)
	g._open_modal("It's planted!","planted")
	g.modal.set_meta("planted_id",id)
	g.modal.set_meta("bed_index",cell)
	g.modal_content.add_child(g._wrap("%s is growing in plot %d." % [p.name,cell+1],22,INK))
	var art := Portrait.new()
	art.plant = p
	art.activity = 1.0
	art.custom_minimum_size = Vector2(150,170)
	g.modal_content.add_child(art)
	var timer: Label = g._wrap(countdown(g,id),19,WARM)
	timer.set_meta("planting_countdown",true)
	timer.set_meta("plant_id",id)
	g.modal_content.add_child(timer)
	g.planting_labels.append(timer)
	g.modal_content.add_child(g._wrap("You're done planting. It grows automatically, right in the garden.",14,MUTED))
	var watch: Button = _action(g,"Watch it grow →",func(): g._close_modal(); g._refresh(); g._focus_planted(id),"watch_grow")
	watch.add_theme_stylebox_override("normal",g._style(Color("ffcf94"),Color("cb9258"),0,12,12))
	g.modal_content.add_child(watch)
	g.modal_content.add_child(_action(g,"Care for this plant",func(): g._open_care(id),"care"))

static func _show_full(g: Control) -> void:
	g._open_modal("Make room for a new sprout","planting_full")
	g.modal_content.add_child(g._wrap("Your grow patch is full. Move one plant to the tray below the garden to free a plot. You keep the plant.",17,INK))
	for index in range(9):
		var p: Dictionary = g.state.get_plant(str(g.state.bed[index]))
		if p.is_empty(): continue
		var id: String = str(p.id)
		var button: Button = _action(g,"Plot %d · move %s to tray" % [index+1,p.name],func(): g.state.bench(id); g._refresh(); g._open_planting(index),"bench")
		button.clip_text = true
		button.tooltip_text = str(p.name)
		button.set_meta("plant_id",id)
		button.set_meta("bed_index",index)
		g.modal_content.add_child(button)
	g.modal_content.add_child(_action(g,"Cancel · back to garden",g._close_modal,"cancel"))

static func show_move_picker(g: Control,zone: String,cell: int) -> void:
	g._open_modal("Choose a plant for this spot","place_plant")
	g.modal.set_meta("bed_index",cell)
	g.modal.set_meta("zone",zone)
	g.modal_content.add_child(g._wrap("The display shelf shows grown plants. Seeds start in the grow patch." if zone=="display" else "Pick a grown plant to move here. Moving is free.",14,INK))
	var found: bool = false
	for id: String in g.state.plant_order:
		var p: Dictionary = g.state.get_plant(id)
		if not p.get("mature",false) or p.get("withered",false): continue
		found = true
		var card := _card(g,g.modal_content)
		card.add_child(g._wrap(str(p.name),18,INK))
		var button: Button = _action(g,"Place here",func(): g._place_from_picker(id,zone,cell),"place_existing")
		button.set_meta("plant_id",id)
		button.set_meta("bed_index",cell)
		button.set_meta("zone",zone)
		card.add_child(button)
	if not found: g.modal_content.add_child(g._wrap("No grown plants yet. Plant a seed in the grow patch and wait 12 seconds.",15,WARM))
	if zone=="display": g.modal_content.add_child(_action(g,"Plant a seed in the grow patch",func(): g._open_planting(),"open"))
	g.modal_content.add_child(_action(g,"Cancel · back to garden",g._close_modal,"cancel"))
