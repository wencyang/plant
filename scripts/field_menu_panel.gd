extends RefCounted
## Field equipment, a discovered-family guide, and real routes through the wilds.
const Portrait=preload("res://scripts/plant_portrait.gd")
const Habitat=preload("res://scripts/habitat_catalog.gd")
const SceneArt=preload("res://scripts/habitat_scene.gd")
const Locale=preload("res://scripts/localization.gd")
const Icon=preload("res://scripts/care_tool_icon.gd")
const INK:=Color("284838")
const MUTED:=Color("617957")
const WARM:=Color("a4542b")
const FAMILIES: Array[String]=["Leaf","Bloom","Vine","Root","Spore","Toxin","Parasite","Carnivorous"]

static func action(g: Control,parent: Node,label: String,callback: Callable,key: String) -> Button:
	var result: Button=g._button(label,callback)
	result.set_meta("field_menu_action",key)
	result.custom_minimum_size=Vector2(0,38)
	result.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	result.clip_text=true
	parent.add_child(result)
	return result

static func card(g: Control,parent: Node) -> VBoxContainer:
	var panel:=PanelContainer.new()
	panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel",g._style(Color("f1efd6"),Color("a4b98b"),0,10,10))
	parent.add_child(panel)
	var body:=VBoxContainer.new()
	body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",7)
	panel.add_child(body)
	return body

static func art(parent: Node,p: Dictionary,height: float,silhouette: bool=false) -> Control:
	var portrait:=Portrait.new()
	portrait.plant=p
	portrait.silhouette=silhouette
	portrait.custom_minimum_size=Vector2(0,height)
	portrait.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	parent.add_child(portrait)
	return portrait

static func bag(g: Control,target: String="") -> void:
	var ids: Array[String]=[]
	for id: String in g.state.plant_order:
		if g.state.owns_plant(id) and not g.state.get_plant(id).get("withered",false): ids.append(id)
	var party: Array=g.state.travel_party()
	if not ids.has(target): target=g.field_bag_target
	if not ids.has(target): target=str(party[0].id) if not party.is_empty() else (ids[0] if not ids.is_empty() else "")
	g.field_bag_target=target
	g._open_modal("Field bag","field_bag")
	g.modal.set_meta("bag_target",target)
	var summary: Label=g._wrap("Light %d · Coins %d · Field kits %d" % [g.state.resources.sunlight,g.state.market_wallet(),g.state.field_kits],15,WARM)
	summary.set_meta("bag_role","summary")
	g.modal_content.add_child(summary)
	action(g,g.modal_content,"Day %d · Rest until morning" % g.state.garden_day,g._show_garden_day,"rest")
	var pockets:=HBoxContainer.new()
	g.modal_content.add_child(pockets)
	action(g,pockets,"Seeds %d" % g.state.seed_bank.size(),func(): g.nursery_tab="seeds"; g._open_seeds(),"seeds")
	action(g,pockets,"Fruit %d" % g.state.fruit_inventory.size(),func(): g.nursery_tab="fruits"; g._open_seeds(),"fruits")
	action(g,pockets,"Shop",func(): g._open_market("shop"),"shop")
	if not target.is_empty():
		g.modal_content.add_child(g._wrap("Use tools on",12,MUTED))
		var picker:=OptionButton.new()
		picker.fit_to_longest_item=false
		picker.clip_text=true
		picker.custom_minimum_size=Vector2(0,40)
		picker.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		picker.set_meta("field_menu_action","bag_target")
		for id: String in ids:
			picker.add_item(str(g.state.get_plant(id).name))
			picker.set_item_metadata(picker.item_count-1,id)
			if id==target: picker.select(picker.item_count-1)
		picker.item_selected.connect(func(index: int): g._open_field_bag(str(picker.get_item_metadata(index))))
		g.modal_content.add_child(picker)
		var tools:=GridContainer.new()
		tools.columns=2
		tools.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		tools.add_theme_constant_override("h_separation",8)
		tools.add_theme_constant_override("v_separation",8)
		g.modal_content.add_child(tools)
		for tool: Dictionary in g.state.Care.tools():
			var key: String=str(tool.key)
			var body:=card(g,tools)
			var icon:=Icon.new()
			icon.tool=key
			icon.custom_minimum_size=Vector2(0,40)
			body.add_child(icon)
			body.add_child(g._wrap(str(tool.name),15,INK))
			body.add_child(g._wrap(str(tool.effect),12,MUTED))
			var status: Dictionary=g.state.care_status(target,key)
			var use: Button=action(g,body,"Use · %d light" % int(tool.cost),func(): g._use_bag_tool(target,key),"use_tool")
			use.set_meta("tool_key",key)
			use.set_meta("plant_id",target)
			use.disabled=not bool(status.get("allowed",false))
			use.tooltip_text=str(status.get("reason",""))
			body.add_child(g._wrap("%d / %d uses left" % [int(status.get("remaining_uses",0)),int(status.get("max_uses",0))],11,MUTED))
	else: g.modal_content.add_child(g._wrap("Grow or collect a plant to use care tools.",16,INK))
	var supplies:=card(g,g.modal_content)
	supplies.add_child(g._wrap("Field kits hold cuttings from wild plants.",13,MUTED))
	action(g,supplies,"Pack 5 field kits · 20 light",g._pack_field_kits,"restock").disabled=int(g.state.resources.sunlight)<20
	Locale.apply_tree(g.modal)

static func specimens(g: Control,family: String) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	for id: String in g.state.plants:
		var p: Dictionary=g.state.get_plant(id)
		if str(p.type)==family: result.append(p)
	return result

static func dex(g: Control,family: String="") -> void:
	g._open_modal("Plant field guide","field_dex")
	var found: int=0
	for entry: String in FAMILIES:
		if not specimens(g,entry).is_empty(): found+=1
	g.modal_content.add_child(g._wrap("%d / 8 families recorded" % found,18,WARM))
	if not family.is_empty():
		var recorded: Array[Dictionary]=specimens(g,family)
		var body:=card(g,g.modal_content)
		body.add_child(g._wrap(family,22,INK))
		var display: Dictionary=recorded[0] if not recorded.is_empty() else {"type":family,"seed":719+FAMILIES.find(family)}
		art(body,display,150,recorded.is_empty())
		var habitats: Array[Dictionary]=Habitat.preferred_habitats(family)
		if not habitats.is_empty():
			var habitat: Dictionary=habitats[0]
			body.add_child(g._wrap(str(habitat.clue),14,MUTED))
			action(g,body,"Find in %s →" % str(habitat.biome),func(): g._follow_habitat_trail(str(habitat.biome),str(habitat.get("habitat_key",""))),"find_family")
		for p: Dictionary in recorded.slice(0,3):
			action(g,body,"%s · G%d · DNA" % [p.name,int(p.generation)],func(): g._open_dna(str(p.id)),"specimen_dna").set_meta("plant_id",str(p.id))
	var grid:=GridContainer.new()
	grid.columns=2 if g.small_layout else 4
	grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation",8)
	grid.add_theme_constant_override("v_separation",8)
	g.modal_content.add_child(grid)
	for entry: String in FAMILIES:
		var recorded: Array[Dictionary]=specimens(g,entry)
		var body:=card(g,grid)
		body.set_meta("field_dex_family",entry)
		var p: Dictionary=recorded[0] if not recorded.is_empty() else {"type":entry,"seed":719+FAMILIES.find(entry)}
		art(body,p,80 if g.small_layout else 100,recorded.is_empty())
		action(g,body,"%s · %d" % [entry,recorded.size()],func(): g._open_field_dex(entry),"family").set_meta("family",entry)
	Locale.apply_tree(g.modal)

static func routes(g: Control) -> void:
	g._open_modal("Routes & habitats","field_routes")
	g.modal_content.add_child(g._wrap("Follow a trail on foot. Discover camps to unlock fast travel.",14,MUTED))
	var row:=HBoxContainer.new()
	g.modal_content.add_child(row)
	action(g,row,"Living valley",g._open_adventure,"stream")
	action(g,row,"World map",func(): g._open_wilderness(); g.wilderness._open_atlas(),"world_map")
	var grid:=GridContainer.new()
	grid.columns=1 if g.small_layout else 2
	grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation",10)
	grid.add_theme_constant_override("v_separation",10)
	g.modal_content.add_child(grid)
	for biome: String in Habitat.REGIONS:
		var body:=card(g,grid)
		var vista:=TextureRect.new()
		vista.texture=SceneArt.texture_for(biome)
		vista.custom_minimum_size=Vector2(0,105)
		vista.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		vista.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
		body.add_child(vista)
		body.add_child(g._wrap(biome,20,INK))
		body.add_child(g._wrap(str(Habitat.REGIONS[biome].landscape),12,MUTED))
		action(g,body,"Follow this route →",func(): g._follow_habitat_trail(biome,""),"follow_route").set_meta("biome",biome)
	Locale.apply_tree(g.modal)
