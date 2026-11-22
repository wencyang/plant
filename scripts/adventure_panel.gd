extends RefCounted
## A field potting bench: real crosses, two real siblings, and useful inherited traits.
const Portrait=preload("res://scripts/plant_portrait.gd")
const Guide=preload("res://scripts/genetics_guide.gd")
const Locale=preload("res://scripts/localization.gd")
const INK:=Color("284838")
const MUTED:=Color("617957")
const WARM:=Color("a4542b")

static func action(g: Control,text: String,callback: Callable,key: String,parent: Node,meta: Dictionary={}) -> Button:
	var b: Button=g._button(text,callback)
	b.custom_minimum_size.y=43
	b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	b.clip_text=true
	b.set_meta("adventure_action",key)
	for property: String in meta: b.set_meta(property,meta[property])
	parent.add_child(b)
	return b

static func card(g: Control,parent: Node) -> VBoxContainer:
	var panel:=PanelContainer.new()
	panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel",g._style(Color("f0edcf"),Color("97aa80"),0,12,10))
	parent.add_child(panel)
	var body:=VBoxContainer.new()
	body.add_theme_constant_override("separation",8)
	panel.add_child(body)
	return body

static func art(parent: Node,p: Dictionary,height: float) -> Control:
	var portrait:=Portrait.new()
	portrait.plant=p
	portrait.custom_minimum_size=Vector2(0,height)
	portrait.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	parent.add_child(portrait)
	return portrait

static func footer(g: Control) -> VBoxContainer:
	var body:=VBoxContainer.new()
	body.add_theme_constant_override("separation",7)
	g.modal.get_node("Panel").get_child(0).add_child(body)
	return body

static func gene(p: Dictionary,key: String) -> String:
	return str(p.get("genes",{}).get(key,{}).get("dominant",""))

static func _ready_time(p: Dictionary) -> int:
	return maxi(0,int(p.get("ready_at",0))-int(Time.get_unix_time_from_system()))

static func _goal(g: Control) -> String:
	return "lantern" if str(g.state.adventure_info().get("stage","shore")) in ["lantern","restored"] else "stream"

static func parent(g: Control,key: String) -> void:
	var row: Dictionary={}
	for candidate: Dictionary in g.state.adventure_plants():
		if str(candidate.key)==key: row=candidate; break
	if row.is_empty(): return
	g._open_modal(str(row.name),"adventure_parent")
	g.modal.set_meta("cutting_key",key)
	var p: Dictionary=row.get("plant",{})
	art(g.modal_content,p,210 if g.small_layout else 270)
	g.modal_content.add_child(g._wrap(str(row.get("description","")),18,INK))
	g.modal_content.add_child(g._wrap(str(row.get("tip","")),14,WARM))
	g.modal_content.add_child(g._wrap("Shown traits: %s · %s · %s" % [Guide.trait_value("shape",gene(p,"shape")),Guide.trait_value("texture",gene(p,"texture")),Guide.trait_value("form",gene(p,"form"))],13,MUTED))
	if key=="moonbell": g.modal_content.add_child(g._wrap("Moonbell carries two Soft Glow copies. Cross it with a second-generation plant to discover a glowing third generation.",14,INK))
	g.modal_content.add_child(g._wrap("Field cuttings stay with you. Their offspring can be traded.",12,MUTED))
	var buttons:=footer(g)
	if not bool(row.get("claimed",false)) or not g.state.owns_plant(str(p.get("id",""))) or bool(p.get("withered",false)):
		action(g,"Take a cutting · free",func(): g._adventure_collect(key),"collect",buttons,{"cutting_key":key})
	else:
		g.modal_content.add_child(g._wrap("This plant is already growing in your collection.",13,WARM))
		action(g,"Try a cross with this plant →",func():
			if key=="moonbell": g._show_adventure_cross(str(g.state.adventure_info().get("route_plant_id","")),str(p.id))
			else: g._show_adventure_cross(str(p.id)),"cross",buttons,{"plant_id":str(p.id)})
		action(g,"Read its inherited traits",func(): g._open_dna(str(p.id)),"traits",g.modal_content,{"plant_id":str(p.id)})
	action(g,"Back to the stream",func(): g._adventure_back_to_field(),"return_field",buttons)

static func journal(g: Control) -> void:
	var info: Dictionary=g.state.adventure_info()
	g._open_modal("Grow a way across","adventure_journal")
	g.modal_content.add_child(g._wrap(str(info.get("objective","A curious flower waits across the stream.")),23,INK))
	g.modal_content.add_child(g._wrap(str(info.get("description","")),14,MUTED))
	for entry: Array in [["A floating leaf raft","Broad, waxy leaves with inherited Leaf and Spore ancestry can carry you over the stream."],["A living vine bridge","Climbing, fibrous plants with inherited Vine and Root ancestry can grow a bridge."],["A light for the hidden garden","Meet Moonbell on the island. Cross it with a G2 plant, then raise a glowing G3 descendant to light the courtyard."]]:
		var body:=card(g,g.modal_content)
		body.add_child(g._wrap(str(entry[0]),18,WARM))
		body.add_child(g._wrap(str(entry[1]),13,INK))
	g.modal_content.add_child(g._wrap("Any two different grown plants can cross. These are two useful possibilities to investigate; your other offspring keep their own traits and family stories.",13,MUTED))
	var buttons:=footer(g)
	action(g,"Breed at the field bench →",func(): g._show_adventure_cross(),"cross",buttons)
	action(g,"Back to the stream",func(): g._adventure_back_to_field(),"return_field",buttons)

static func _owned(g: Control,include_young: bool=false) -> Array[String]:
	var ids: Array[String]=[]
	var info: Dictionary=g.state.adventure_info()
	for id: Variant in info.get("cuttings",{}).values():
		var p: Dictionary=g.state.get_plant(str(id))
		if g.state.owns_plant(str(id)) and not p.get("withered",false) and (include_young or p.get("mature",false)): ids.append(str(id))
	for id: String in g.state.plant_order:
		var p: Dictionary=g.state.get_plant(id)
		if not ids.has(id) and g.state.owns_plant(id) and not p.get("withered",false) and (include_young or p.get("mature",false)): ids.append(id)
	return ids

static func _picker(g: Control,parent_node: Node,ids: Array[String],chosen: String,key: String,callback: Callable) -> OptionButton:
	var picker:=OptionButton.new()
	picker.set_meta("adventure_action",key)
	picker.custom_minimum_size=Vector2(0,43)
	picker.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	picker.clip_text=true
	picker.fit_to_longest_item=false
	for id: String in ids:
		var p: Dictionary=g.state.get_plant(id)
		picker.add_item("%s · %s · G%d" % [p.name,p.type,int(p.generation)])
		picker.set_item_metadata(picker.item_count-1,id)
		if id==chosen: picker.select(picker.item_count-1)
	picker.item_selected.connect(func(index: int): callback.call(str(picker.get_item_metadata(index))))
	parent_node.add_child(picker)
	return picker

static func probability(preview: Dictionary,key: String,values: Array) -> float:
	for trait_info: Dictionary in preview.get("traits",[]):
		if str(trait_info.key)!=key: continue
		var chance: float=0.0
		for result: Dictionary in trait_info.outcomes:
			if values.has(result.raw): chance+=float(result.probability)
		return chance
	return 0.0

static func chances(a: Dictionary,b: Dictionary) -> Dictionary:
	var preview: Dictionary=Guide.cross_preview(a,b)
	var mix: Dictionary=preview.get("lineage_mix",{})
	var raft: float=0.0
	var vine: float=0.0
	if float(mix.get("Leaf",0))>=0.2 and float(mix.get("Spore",0))>=0.2:
		raft=probability(preview,"shape",["Round","Split"])*probability(preview,"texture",["Waxy"])
	if float(mix.get("Vine",0))>=0.2 and float(mix.get("Root",0))>=0.2:
		vine=probability(preview,"form",["Climbing"])*probability(preview,"texture",["Fibrous"])
	return {"raft":raft,"vine":vine,"glow":probability(preview,"glow",["Soft Glow"]) if int(preview.generation)>=3 else 0.0,"generation":int(preview.generation)}

static func cross(g: Control,mother_id: String="",father_id: String="") -> void:
	var ids: Array[String]=_owned(g)
	var info: Dictionary=g.state.adventure_info()
	var stored: Dictionary=info.get("last_cross",{})
	var a: String=mother_id
	var b: String=father_id
	if a.is_empty() and _goal(g)=="lantern" and not g.state.pollinations.has(str(stored.get("mother_id",""))): a=str(info.get("route_plant_id",""))
	if not ids.has(a): a=str(stored.get("mother_id",""))
	if not ids.has(a): a=str(info.get("route_plant_id","")) if _goal(g)=="lantern" else str(info.get("cuttings",{}).get("river_fan",""))
	if not ids.has(a): a=ids[0] if not ids.is_empty() else ""
	if not ids.has(b): b=str(info.get("moonbell_id","")) if _goal(g)=="lantern" else str(info.get("cuttings",{}).get("floatcap",""))
	if not ids.has(b) or b==a:
		b=""
		for id: String in ids:
			if id!=a: b=id; break
	var status: Dictionary=g.state.fruit_status(a)
	if not status.get("pollination",{}).is_empty(): b=str(status.pollination.father_id)
	var stored_siblings: bool=str(stored.get("mother_id",""))==a and str(info.get("cross_status","")) in ["stored_fruit","stored_seeds"]
	if stored_siblings: b=str(stored.get("father_id",b))
	g.adventure_mother=a
	g.adventure_father=b
	g._open_modal("The field breeding bench","adventure_cross")
	g.modal.set_meta("mother_id",a)
	g.modal.set_meta("father_id",b)
	g.modal_content.add_child(g._wrap("What could these two grow into?",22,INK))
	g.modal_content.add_child(g._wrap("Pollinate for 10 light. Their fruit ripens in 18 seconds; then grow both seeds for 20 light. Both parents and both children stay with you.",13,MUTED))
	var shortcuts:=HBoxContainer.new()
	g.modal_content.add_child(shortcuts)
	action(g,"Leaf raft pair",func(): g._adventure_suggest_pair("river_fan","floatcap"),"suggest_raft",shortcuts)
	action(g,"Vine bridge pair",func(): g._adventure_suggest_pair("gripvine","stone_root"),"suggest_vine",shortcuts)
	if ids.size()<2:
		g.modal_content.add_child(g._wrap("Meet the four plants on this bank and take two free cuttings. Your own grown garden plants can join the experiment too.",16,INK))
		var back:=footer(g)
		action(g,"Back to the stream",func(): g._adventure_back_to_field(),"return_field",back)
		return
	var parents:=GridContainer.new()
	parents.columns=1 if g.small_layout else 2
	parents.add_theme_constant_override("h_separation",10)
	parents.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	g.modal_content.add_child(parents)
	var left:=card(g,parents)
	left.add_child(g._wrap("Mother plant",13,WARM))
	art(left,g.state.get_plant(a),88 if g.small_layout else 160)
	_picker(g,left,ids,a,"mother",func(id: String): g._show_adventure_cross(id,b))
	var right:=card(g,parents)
	right.add_child(g._wrap("Father plant",13,WARM))
	art(right,g.state.get_plant(b),88 if g.small_layout else 160)
	_picker(g,right,ids,b,"father",func(id: String): g._show_adventure_cross(a,id))
	var odds: Dictionary=chances(g.state.get_plant(a),g.state.get_plant(b))
	var prediction:=card(g,g.modal_content)
	prediction.add_child(g._wrap("Their next generation: G%d" % int(odds.generation),18,INK))
	if _goal(g)=="lantern":
		prediction.add_child(g._wrap("Glowing G3 or later · %d%% per seed" % roundi(float(odds.glow)*100),16,WARM))
		prediction.add_child(g._wrap("Each child inherits independently. An unlit child can still carry Soft Glow and pass it on in another cross.",13,MUTED))
	else:
		prediction.add_child(g._wrap("Living raft · %d%% per seed" % roundi(float(odds.raft)*100),16,WARM))
		prediction.add_child(g._wrap("Vine bridge · %d%% per seed" % roundi(float(odds.vine)*100),16,WARM))
		prediction.add_child(g._wrap("A useful crossing plant needs the matching ancestry and the traits it actually shows. Read its DNA to plan a different combination.",13,MUTED))
	var buttons:=footer(g)
	var start:=action(g,"Cross these plants · 10 light",func(): g._adventure_pollinate(a,b),"pollinate",buttons,{"mother_id":a,"father_id":b})
	start.disabled=a==b or int(g.state.resources.sunlight)<10 or not status.get("pollination",{}).is_empty() or stored_siblings
	if not status.get("pollination",{}).is_empty() or stored_siblings:
		var timer: Label=g._wrap("",14,WARM)
		timer.set_meta("adventure_timer","fruit")
		timer.set_meta("mother_id",a)
		g.modal_content.add_child(timer)
		action(g,"Harvest & grow both siblings · 20 light",func(): g._adventure_sow(a),"siblings",buttons,{"mother_id":a})
	var previous: Array=info.get("siblings",stored.get("siblings",[]))
	if not previous.is_empty(): action(g,"Meet the latest siblings →",func(): g._show_adventure_reveal(previous),"reveal",g.modal_content)
	action(g,"Explore while the fruit grows →" if not status.get("pollination",{}).is_empty() and not status.get("cross_ready",false) else "Back to the stream",func(): g._adventure_back_to_field(),"return_field",buttons)
	tick(g)

static func reveal(g: Control,ids: Array) -> void:
	g._open_modal("Meet your two surprises","adventure_reveal")
	g.modal.set_meta("sibling_ids",ids.duplicate())
	g.modal_content.add_child(g._wrap("Two siblings. Two new possibilities.",22,INK))
	g.modal_content.add_child(g._wrap("Both belong to your garden. Watch their first leaves unfurl, then see what each one can do.",14,MUTED))
	var grid:=GridContainer.new()
	grid.columns=1 if g.small_layout else 2
	grid.add_theme_constant_override("h_separation",12)
	grid.add_theme_constant_override("v_separation",12)
	grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	g.modal_content.add_child(grid)
	var index: int=0
	for id: String in ids:
		var p: Dictionary=g.state.get_plant(id)
		if p.is_empty(): continue
		index+=1
		var body:=card(g,grid)
		body.add_child(g._wrap("Sibling %d · G%d" % [index,int(p.generation)],18,WARM))
		var portrait: Control=art(body,p,180 if g.small_layout else 235)
		portrait.reveal=0
		portrait.create_tween().tween_property(portrait,"reveal",1.0,0.8)
		body.add_child(g._wrap(str(p.name),20,INK))
		body.add_child(g._wrap("%s leaves · %s surface · %s habit" % [Guide.trait_value("shape",gene(p,"shape")),Guide.trait_value("texture",gene(p,"texture")),Guide.trait_value("form",gene(p,"form"))],13,MUTED))
		body.add_child(g._wrap("Glow: %s · Markings: %s" % [Guide.trait_value("glow",gene(p,"glow")),Guide.trait_value("pattern",gene(p,"pattern"))],13,WARM))
		var timer: Label=g._wrap("",13,INK)
		timer.set_meta("adventure_timer","seedling")
		timer.set_meta("plant_id",id)
		body.add_child(timer)
		action(g,"Try this plant →",func(): g._show_adventure_use(_goal(g),id),"use",body,{"plant_id":id,"goal":_goal(g),"wait_for_maturity":true})
		action(g,"See what it inherited",func(): g._open_dna(id),"traits",body,{"plant_id":id})
	var buttons:=footer(g)
	action(g,"Back to the stream",func(): g._adventure_back_to_field(),"return_field",buttons)
	action(g,"Try another cross",func(): g._show_adventure_cross(),"cross",buttons)
	tick(g)

static func use(g: Control,goal: String="stream",plant_id: String="") -> void:
	var ids: Array[String]=_owned(g,true)
	ids.sort_custom(func(a: String,b: String): return bool(g.state.adventure_preview(a,goal).get("eligible",false)) and not bool(g.state.adventure_preview(b,goal).get("eligible",false)))
	var chosen: String=plant_id if ids.has(plant_id) else (ids[0] if not ids.is_empty() else "")
	g._open_modal("A light for the hidden garden" if goal=="lantern" else "Grow a way across","adventure_use")
	g.modal.set_meta("goal",goal)
	g.modal.set_meta("plant_id",chosen)
	g.modal_content.add_child(g._wrap("A glowing third generation can wake the courtyard lights." if goal=="lantern" else "Bring a living raft or a vine bridge to the water's edge.",20,INK))
	if not chosen.is_empty():
		_picker(g,g.modal_content,ids,chosen,"choose_plant",func(id: String): g._show_adventure_use(goal,id))
		var p: Dictionary=g.state.get_plant(chosen)
		art(g.modal_content,p,200 if g.small_layout else 255)
		g.modal_content.add_child(g._wrap(str(p.name),22,INK))
		var reason: Label=g._wrap("",15,WARM)
		reason.set_meta("adventure_timer","eligibility")
		reason.set_meta("plant_id",chosen)
		reason.set_meta("goal",goal)
		g.modal_content.add_child(reason)
		g.modal_content.add_child(g._wrap("Your plant stays in your collection. Its living route will remain here as a lasting part of the landscape.",13,MUTED))
		var buttons:=footer(g)
		action(g,"Light the courtyard →" if goal=="lantern" else "Let this plant make a crossing →",func(): g._adventure_apply(chosen,goal),"apply",buttons,{"plant_id":chosen,"goal":goal})
		action(g,"Breed a new possibility",func(): g._show_adventure_cross(),"cross",buttons)
		action(g,"Back to the stream",func(): g._adventure_back_to_field(),"return_field",buttons)
	else:
		g.modal_content.add_child(g._wrap("Take two free cuttings on the shore, then grow their children at the field bench.",16,INK))
		action(g,"Back to the stream",func(): g._adventure_back_to_field(),"return_field",footer(g))
	tick(g)

static func success(g: Control,result: Dictionary,goal: String) -> void:
	var info: Dictionary=g.state.adventure_info()
	var id: String=str(info.get("lantern_id","")) if goal=="lantern" else str(info.get("route_plant_id",""))
	var p: Dictionary=g.state.get_plant(id)
	g._open_modal("Your garden changed the world!","adventure_success")
	art(g.modal_content,p,220 if g.small_layout else 285)
	g.modal_content.add_child(g._wrap(str(result.get("message","A new path has grown.")),21,INK))
	g.modal_content.add_child(g._wrap("A place to remember this plant family.",14,WARM))
	var name_edit:=LineEdit.new()
	name_edit.text=str(p.get("name",""))
	name_edit.max_length=30
	name_edit.placeholder_text="Name this plant"
	name_edit.set_meta("adventure_name",true)
	g.modal_content.add_child(name_edit)
	action(g,"Save its name",func(): g._adventure_name(id,name_edit.text),"name",g.modal_content,{"plant_id":id})
	var buttons:=footer(g)
	action(g,"Step into the restored garden →" if goal=="lantern" else "Test your new crossing →",func(): g._adventure_test_route(goal),"test_route",buttons,{"goal":goal})
	action(g,"Back to the stream",func(): g._adventure_back_to_field(),"return_field",buttons)
	g._care_sparkles()

static func tick(g: Control) -> void:
	if not is_instance_valid(g.modal) or not str(g.modal_kind).begins_with("adventure_"): return
	_tick_node(g,g.modal)
	Locale.apply_tree(g.modal)

static func _tick_node(g: Control,node: Node) -> void:
	if node is Label:
		match str(node.get_meta("adventure_timer","")):
			"fruit":
				var status: Dictionary=g.state.fruit_status(str(node.get_meta("mother_id","")))
				var info: Dictionary=g.state.adventure_info()
				var ready: bool=status.get("cross_ready",false) or (str(info.get("last_cross",{}).get("mother_id",""))==str(node.get_meta("mother_id","")) and bool(info.get("cross_ready",false)))
				node.text="The hybrid fruit is ripe. Let's meet its two children!" if ready else "Fruit ripening · %d seconds" % maxi(0,int(status.get("pollination",{}).get("ready_at",0))-int(Time.get_unix_time_from_system()))
			"seedling":
				var p: Dictionary=g.state.get_plant(str(node.get_meta("plant_id","")))
				node.text="Ready to meet the world!" if p.get("mature",false) else "Unfurling · %d seconds" % _ready_time(p)
			"eligibility":
				var preview: Dictionary=g.state.adventure_preview(str(node.get_meta("plant_id","")),str(node.get_meta("goal","stream")))
				node.text=str(preview.get("reason",""))
	if node is Button:
		match str(node.get_meta("adventure_action","")):
			"siblings":
				var info: Dictionary=g.state.adventure_info()
				node.disabled=not (g.state.fruit_status(str(node.get_meta("mother_id",""))).get("cross_ready",false) or (str(info.get("last_cross",{}).get("mother_id",""))==str(node.get_meta("mother_id","")) and bool(info.get("cross_ready",false))))
			"apply": node.disabled=not g.state.adventure_preview(str(node.get_meta("plant_id","")),str(node.get_meta("goal","stream"))).get("eligible",false)
			"use":
				if node.get_meta("wait_for_maturity",false): node.disabled=not g.state.get_plant(str(node.get_meta("plant_id",""))).get("mature",false)
	for child: Node in node.get_children(): _tick_node(g,child)
