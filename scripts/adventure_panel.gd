extends RefCounted
## A compact breeding flow: choose parents, grow siblings, use a useful child.
const Portrait=preload("res://scripts/plant_portrait.gd")
const Guide=preload("res://scripts/genetics_guide.gd")
const Behavior=preload("res://scripts/plant_behavior_stage.gd")
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

static func open(g: Control,title: String,kind: String) -> void:
	g._open_modal(title,kind)
	# The header close is the single way back, instead of another full-width row.
	var header: Node=g.modal.get_node("Panel").get_child(0).get_child(0)
	for child: Node in header.get_children():
		if child is Button: child.set_meta("adventure_action","return_field")
	g.modal_content.add_theme_constant_override("separation",10)

static func details(g: Control,parent_node: Node,title: String="Details") -> VBoxContainer:
	var toggle:=Button.new()
	toggle.text=title+" ▸"
	toggle.flat=true
	toggle.alignment=HORIZONTAL_ALIGNMENT_LEFT
	toggle.custom_minimum_size.y=32
	toggle.set_meta("adventure_details",true)
	parent_node.add_child(toggle)
	var body:=VBoxContainer.new()
	body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	body.visible=false
	parent_node.add_child(body)
	toggle.pressed.connect(func():
		body.visible=not body.visible
		toggle.text=title+(" ▾" if body.visible else " ▸")
		Locale.apply_tree(g.modal))
	return body

static func card(g: Control,parent_node: Node) -> VBoxContainer:
	var panel:=PanelContainer.new()
	panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel",g._style(Color("f0edcf"),Color("97aa80"),0,7 if g.small_layout else 12,8))
	parent_node.add_child(panel)
	var body:=VBoxContainer.new()
	body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",6)
	panel.add_child(body)
	return body

static func art(parent_node: Node,p: Dictionary,height: float) -> Control:
	var portrait:=Portrait.new()
	portrait.plant=p
	portrait.custom_minimum_size=Vector2(0,height)
	portrait.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	parent_node.add_child(portrait)
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
	open(g,str(row.name),"adventure_parent")
	g.modal.set_meta("cutting_key",key)
	var p: Dictionary=row.get("plant",{})
	art(g.modal_content,p,170 if g.small_layout else 245)
	g.modal_content.add_child(g._wrap(str(row.get("tip","")),17,INK))
	var extra:=details(g,g.modal_content,"About this plant")
	extra.add_child(g._wrap(str(row.get("description","")),14,MUTED))
	extra.add_child(g._wrap("Shown traits: %s · %s · %s" % [Guide.trait_value("shape",gene(p,"shape")),Guide.trait_value("texture",gene(p,"texture")),Guide.trait_value("form",gene(p,"form"))],13,MUTED))
	extra.add_child(g._wrap("Field cuttings stay with you. Their offspring can be traded.",12,MUTED))
	for option: Dictionary in row.get("observation_choices",[]):
		action(g,str(option.label),func(): g._adventure_observe(key,str(option.key)),"observe",g.modal_content,{"observation":str(option.key)})
	var buttons:=footer(g)
	if not bool(row.get("claimed",false)) or not g.state.owns_plant(str(p.get("id",""))) or bool(p.get("withered",false)) or bool(row.get("replacement",false)):
		action(g,"Take a cutting · free",func(): g._adventure_collect(key),"collect",buttons,{"cutting_key":key})
	else:
		g.modal_content.add_child(g._wrap("Already in your garden",13,WARM))
		action(g,"Cross with this plant",func():
			if key=="moonbell": g._show_adventure_cross(str(g.state.adventure_info().get("route_plant_id","")),str(p.id))
			else: g._show_adventure_cross(str(p.id)),"cross",buttons,{"plant_id":str(p.id)})
		action(g,"See DNA",func(): g._open_dna(str(p.id)),"traits",extra,{"plant_id":str(p.id)})

static func journal(g: Control) -> void:
	open(g,"Valley notebook","adventure_journal")
	var info: Dictionary=g.state.adventure_info()
	g.modal_content.add_child(g._wrap("%d places changed · %d night discoveries" % [int(info.get("discovery_count",0)),int(info.get("enhanced_count",0))],20,WARM))
	g.modal_content.add_child(g._wrap("Follow a question. Try a plant. Return with a new idea.",15,INK))
	for site: Dictionary in g.state.adventure_sites():
		var body:=card(g,g.modal_content)
		body.add_child(g._wrap(str(site.name),18,INK))
		body.add_child(g._wrap(str(site.question),14,MUTED))
		if bool(site.get("enhanced",false)): body.add_child(g._wrap("Night variant discovered",13,WARM))
		elif bool(site.solved): body.add_child(g._wrap("What if this plant could glow, too?",13,WARM))
		action(g,"Visit this place →",func(): g._adventure_visit(str(site.id)),"visit_site",body,{"site_id":str(site.id)})
	var extra:=details(g,g.modal_content,"Your latest experiments")
	var trials: Array=info.get("experiments",[]).duplicate()
	trials.reverse()
	for trial: Dictionary in trials.slice(0,5):
		var plant: Dictionary=g.state.get_plant(str(trial.plant_id))
		var site: Dictionary=g.state.adventure_site(str(trial.site_id))
		extra.add_child(g._wrap("%s · %s" % [plant.get("name",""),site.get("name","")],14,INK))
		extra.add_child(g._wrap(str(trial.get("reason","")),12,MUTED))
	var buttons:=footer(g)
	action(g,"Plant playground",func(): g._show_adventure_experiments(),"experiments",buttons)
	action(g,"Day %d · Rest until morning" % g.state.garden_day,g._show_garden_day,"rest",buttons)

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
	picker.custom_minimum_size=Vector2(0,40)
	picker.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	picker.clip_text=true
	picker.fit_to_longest_item=false
	for id: String in ids:
		var p: Dictionary=g.state.get_plant(id)
		picker.add_item(str(p.name))
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
	var canopy: float=probability(preview,"shape",["Round","Split"])*probability(preview,"texture",["Waxy"])
	var coil: float=probability(preview,"form",["Climbing"])*probability(preview,"texture",["Fibrous"])
	var glow: float=probability(preview,"glow",["Soft Glow"])
	return {"raft":canopy,"vine":coil,"canopy":canopy,"coil":coil,"glow":glow,"canopy_glow":canopy*glow,"coil_glow":coil*glow,"generation":int(preview.generation)}

static func cross(g: Control,mother_id: String="",father_id: String="") -> void:
	var ids: Array[String]=_owned(g)
	var info: Dictionary=g.state.adventure_info()
	var stored: Dictionary=info.get("last_cross",{})
	# A mother's final morning must never hide the real embryos she carries.
	var pending: String=str(stored.get("mother_id",""))
	if g.state.pollinations.has(pending) or str(info.get("cross_status","")) in ["stored_fruit","stored_seeds"]:
		for id: String in [pending,str(stored.get("father_id",""))]:
			if not ids.has(id) and not g.state.get_plant(id).is_empty(): ids.append(id)
	var a: String=mother_id
	var b: String=father_id
	if not ids.has(a): a=str(stored.get("mother_id",""))
	if not ids.has(a): a=str(info.get("cuttings",{}).get("river_fan",""))
	if not ids.has(a): a=ids[0] if not ids.is_empty() else ""
	if not ids.has(b): b=str(info.get("moonbell_id","")) if not str(info.get("moonbell_id","")).is_empty() else str(info.get("cuttings",{}).get("floatcap",""))
	if not ids.has(b) or b==a:
		b=""
		for id: String in ids:
			if id!=a: b=id; break
	var status: Dictionary=g.state.fruit_status(a)
	if not status.get("pollination",{}).is_empty(): b=str(status.pollination.father_id)
	var stored_siblings: bool=str(stored.get("mother_id",""))==a and str(info.get("cross_status","")) in ["stored_fruit","stored_seeds"]
	if stored_siblings: b=str(stored.get("father_id",b))
	var busy: bool=not status.get("pollination",{}).is_empty() or stored_siblings
	g.adventure_mother=a
	g.adventure_father=b
	open(g,"Cross two plants","adventure_cross")
	g.modal.set_meta("mother_id",a)
	g.modal.set_meta("father_id",b)
	if ids.size()<2:
		g.modal_content.add_child(g._wrap("Take two free cuttings from plants beside the stream.",20,INK))
		action(g,"Find plants",func(): g._adventure_back_to_field(),"find_plants",footer(g))
		return
	var parents:=GridContainer.new()
	parents.columns=2
	parents.add_theme_constant_override("h_separation",8)
	parents.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	g.modal_content.add_child(parents)
	var left:=card(g,parents)
	left.add_child(g._wrap("Parent 1",13,MUTED))
	art(left,g.state.get_plant(a),90 if g.small_layout else 175)
	var pick_a:=_picker(g,left,ids,a,"mother",func(id: String): g._show_adventure_cross(id,b))
	var right:=card(g,parents)
	right.add_child(g._wrap("Parent 2",13,MUTED))
	art(right,g.state.get_plant(b),90 if g.small_layout else 175)
	var pick_b:=_picker(g,right,ids,b,"father",func(id: String): g._show_adventure_cross(a,id))
	pick_a.disabled=busy
	pick_b.disabled=busy
	var odds: Dictionary=chances(g.state.get_plant(a),g.state.get_plant(b))
	g.modal_content.add_child(g._wrap("Shelter + glow · %d%%  /  Climb + glow · %d%%" % [roundi(float(odds.canopy_glow)*100),roundi(float(odds.coil_glow)*100)],18,WARM))
	g.modal_content.add_child(g._wrap("Each seed is its own experiment. Combined traits can reveal night variants in familiar places.",13,MUTED))
	if not busy: g.modal_content.add_child(g._wrap("Two seeds · fruit ready in 18 seconds",13,MUTED))
	var extra:=details(g,g.modal_content,"Traits & possibilities")
	extra.add_child(g._wrap("Their next generation: G%d" % int(odds.generation),15,INK))
	extra.add_child(g._wrap("Sheltering canopy · %d%% per seed" % roundi(float(odds.canopy)*100),13,MUTED))
	extra.add_child(g._wrap("Coiling growth · %d%% per seed" % roundi(float(odds.coil)*100),13,MUTED))
	extra.add_child(g._wrap("Soft Glow · %d%% per seed" % roundi(float(odds.glow)*100),13,MUTED))
	extra.add_child(g._wrap("Each child inherits independently. An unlit child can still carry Soft Glow and pass it on in another cross.",13,MUTED))
	action(g,"Parent 1 DNA",func(): g._open_dna(a),"traits",extra,{"plant_id":a})
	action(g,"Parent 2 DNA",func(): g._open_dna(b),"traits",extra,{"plant_id":b})
	var previous: Array=info.get("siblings",stored.get("siblings",[]))
	if not previous.is_empty(): action(g,"Meet the latest siblings →",func(): g._show_adventure_reveal(previous),"reveal",extra)
	var buttons:=footer(g)
	if busy:
		action(g,"Grow both seeds · 20 light",func(): g._adventure_sow(a),"siblings",buttons,{"mother_id":a})
		if not bool(status.get("cross_ready",false)): action(g,"Rest until morning",g._show_garden_day,"rest",buttons)
	else:
		var start:=action(g,"Cross these plants · 10 light",func(): g._adventure_pollinate(a,b),"pollinate",buttons,{"mother_id":a,"father_id":b})
		start.disabled=a==b or int(g.state.resources.sunlight)<10
	tick(g)

static func _useful(g: Control,p: Dictionary,goal: String) -> bool:
	var abilities: Dictionary=g.state.adventure_capabilities(p)
	return bool(abilities.lantern) if goal=="lantern" else bool(abilities.raft) or bool(abilities.vine)

static func _ability(g: Control,p: Dictionary,goal: String) -> String:
	var abilities: Dictionary=g.state.adventure_capabilities(p)
	if goal=="lantern": return "Can light the hidden garden" if bool(abilities.lantern) else "No glow this time"
	if bool(abilities.raft): return "Can float across the stream"
	if bool(abilities.vine): return "Can grow a vine bridge"
	return "A new family to keep growing"

static func reveal(g: Control,ids: Array) -> void:
	open(g,"Meet your new plants","adventure_reveal")
	g.modal.set_meta("sibling_ids",ids.duplicate())
	g.modal_content.add_child(g._wrap("Two siblings. Two different possibilities.",18,INK))
	var grid:=GridContainer.new()
	grid.columns=2
	grid.add_theme_constant_override("h_separation",8)
	grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	g.modal_content.add_child(grid)
	var growing: bool=false
	for id: String in ids:
		var p: Dictionary=g.state.get_plant(id)
		if p.is_empty(): continue
		var body:=card(g,grid)
		var portrait: Control=art(body,p,125 if g.small_layout else 195)
		portrait.reveal=0
		portrait.create_tween().tween_property(portrait,"reveal",1.0,0.9)
		body.add_child(g._wrap(str(p.name),16,INK))
		var caps: Dictionary=g.state.adventure_capabilities(p)
		body.add_child(g._wrap(" · ".join(PackedStringArray(caps.labels)) if not caps.labels.is_empty() else "A new combination to keep growing",14,WARM))
		body.add_child(g._wrap("%s leaves · %s surface" % [Guide.trait_value("shape",gene(p,"shape")),Guide.trait_value("texture",gene(p,"texture"))],12,MUTED))
		body.add_child(g._wrap("%s habit · %s" % [Guide.trait_value("form",gene(p,"form")),Guide.trait_value("glow",gene(p,"glow"))],12,MUTED))
		var timer: Label=g._wrap("",12,MUTED)
		timer.set_meta("adventure_timer","seedling")
		timer.set_meta("plant_id",id)
		body.add_child(timer)
		action(g,"Try in playground",func(): g._show_adventure_experiments(id),"experiments",body,{"plant_id":id})
		var take:=action(g,"Take outside →",func(): g._adventure_try_outside(id),"outside",body,{"plant_id":id,"wait_for_maturity":true})
		take.disabled=not bool(p.mature)
		growing=growing or not bool(p.mature)
	var extra:=details(g,g.modal_content,"Names & family records")
	for id: String in ids:
		var p: Dictionary=g.state.get_plant(id)
		if p.is_empty(): continue
		var edit:=LineEdit.new()
		edit.text=str(p.name)
		edit.max_length=30
		edit.placeholder_text="Name this plant"
		extra.add_child(edit)
		action(g,"Save its name",func(): g._adventure_name(id,edit.text),"name",extra,{"plant_id":id})
		action(g,"See DNA",func(): g._open_dna(id),"traits",extra,{"plant_id":id})
	var buttons:=footer(g)
	if growing: action(g,"Rest until morning",g._show_garden_day,"rest",buttons)
	action(g,"Cross again",func(): g._show_adventure_cross(),"cross",buttons)
	tick(g)

static func use(g: Control,goal: String="stream",plant_id: String="") -> void:
	var ids: Array[String]=_owned(g,true)
	ids.sort_custom(func(a: String,b: String): return bool(g.state.adventure_preview(a,goal).get("eligible",false)) and not bool(g.state.adventure_preview(b,goal).get("eligible",false)))
	var chosen: String=plant_id if ids.has(plant_id) else (ids[0] if not ids.is_empty() else "")
	open(g,"Light the garden" if goal=="lantern" else "Cross the stream","adventure_use")
	g.modal.set_meta("goal",goal)
	g.modal.set_meta("plant_id",chosen)
	if not chosen.is_empty():
		var p: Dictionary=g.state.get_plant(chosen)
		art(g.modal_content,p,165 if g.small_layout else 245)
		g.modal_content.add_child(g._wrap(str(p.name),22,INK))
		var reason: Label=g._wrap("",15,WARM)
		reason.set_meta("adventure_timer","eligibility")
		reason.set_meta("plant_id",chosen)
		reason.set_meta("goal",goal)
		g.modal_content.add_child(reason)
		g.modal_content.add_child(g._wrap("Your plant stays with you.",13,MUTED))
		var extra:=details(g,g.modal_content,"Choose another plant")
		_picker(g,extra,ids,chosen,"choose_plant",func(id: String): g._show_adventure_use(goal,id))
		action(g,"See DNA",func(): g._open_dna(chosen),"traits",extra,{"plant_id":chosen})
		if not _useful(g,p,goal): action(g,"Try another cross",func(): g._show_adventure_cross(),"cross",g.modal_content)
		action(g,"Light the courtyard →" if goal=="lantern" else "Grow the crossing →",func(): g._adventure_apply(chosen,goal),"apply",footer(g),{"plant_id":chosen,"goal":goal})
	else:
		g.modal_content.add_child(g._wrap("Take two free cuttings from plants beside the stream.",18,INK))
		action(g,"Find plants",func(): g._adventure_back_to_field(),"find_plants",footer(g))
	tick(g)

static func success(g: Control,result: Dictionary,goal: String) -> void:
	var info: Dictionary=g.state.adventure_info()
	var id: String=str(info.get("lantern_id","")) if goal=="lantern" else str(info.get("route_plant_id",""))
	var p: Dictionary=g.state.get_plant(id)
	open(g,"Your plant made a new path!" if goal=="stream" else "The garden is awake!","adventure_success")
	art(g.modal_content,p,175 if g.small_layout else 265)
	g.modal_content.add_child(g._wrap(str(result.get("message","A new path has grown.")),20,INK))
	var extra:=details(g,g.modal_content,"Name this plant")
	var name_edit:=LineEdit.new()
	name_edit.text=str(p.get("name",""))
	name_edit.max_length=30
	name_edit.placeholder_text="Name this plant"
	name_edit.set_meta("adventure_name",true)
	extra.add_child(name_edit)
	action(g,"Save its name",func(): g._adventure_name(id,name_edit.text),"name",extra,{"plant_id":id})
	action(g,"Step into the restored garden →" if goal=="lantern" else "Walk across →",func(): g._adventure_test_route(goal),"test_route",footer(g),{"goal":goal})
	g._care_sparkles()

static func stage(parent_node: Node,p: Dictionary,mode: String,height: float) -> Control:
	var tray:=Behavior.new()
	tray.plant=p
	tray.mode=mode
	tray.custom_minimum_size=Vector2(0,height)
	tray.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	parent_node.add_child(tray)
	return tray

static func _site_score(g: Control,site_id: String,id: String) -> int:
	var preview: Dictionary=g.state.adventure_discovery_preview(site_id,id)
	return (4 if bool(preview.get("combined",false)) else 0)+(2 if bool(preview.get("eligible",false)) else 0)+(1 if bool(preview.get("usable",false)) else 0)

static func discovery(g: Control,site_id: String,plant_id: String="",approach: String="") -> void:
	var site: Dictionary=g.state.adventure_site(site_id)
	if site.is_empty(): return
	var ids: Array[String]=_owned(g,true)
	ids.sort_custom(func(a: String,b: String): return _site_score(g,site_id,a)>_site_score(g,site_id,b))
	var chosen: String=plant_id if ids.has(plant_id) else (ids[0] if not ids.is_empty() else "")
	open(g,str(site.name),"adventure_discovery")
	g.modal.set_meta("site_id",site_id)
	g.modal.set_meta("plant_id",chosen)
	g.modal_content.add_child(g._wrap(str(site.question),22,INK))
	g.modal_content.add_child(g._wrap(str(site.description),14,MUTED))
	if bool(site.get("enhanced",false)):
		g.modal_content.add_child(g._wrap("Night variant discovered · your living creation is part of this place.",14,WARM))
	elif bool(site.solved):
		g.modal_content.add_child(g._wrap("What if this plant could glow, too?",16,WARM))
		g.modal_content.add_child(g._wrap("Combine shelter or climbing growth with Soft Glow to discover a night variant.",13,MUTED))
	if chosen.is_empty():
		g.modal_content.add_child(g._wrap("Meet a plant in the valley and take a free cutting.",16,INK))
		action(g,"Back to the valley",g._adventure_back_to_field,"return_field",footer(g))
		return
	_picker(g,g.modal_content,ids,chosen,"discovery_plant",func(id: String): g._show_adventure_discovery(site_id,id,approach))
	var p: Dictionary=g.state.get_plant(chosen)
	var preview: Dictionary=g.state.adventure_discovery_preview(site_id,chosen,approach)
	var mode: String="night" if str(preview.get("approach",""))=="glow" else ("rain" if site_id in ["rain_nursery","cistern"] else "wind")
	stage(g.modal_content,p,mode,150 if g.small_layout else 195)
	g.modal_content.add_child(g._wrap("Your plant stays with you. Trying an idea is free.",13,MUTED))
	var buttons:=footer(g)
	for option: Dictionary in site.approaches:
		var trial: Dictionary=g.state.adventure_discovery_preview(site_id,chosen,str(option.key))
		var button:=action(g,str(option.label)+" →",func(): g._adventure_try_discovery(site_id,chosen,str(option.key)),"try_discovery",buttons,{"site_id":site_id,"plant_id":chosen,"approach":str(option.key)})
		button.disabled=not bool(trial.get("usable",false))
		button.tooltip_text=str(trial.get("reason",""))
	if not bool(p.get("mature",false)): action(g,"Rest until morning",g._show_garden_day,"rest",buttons)
	var extra:=details(g,g.modal_content,"Clues & inherited traits")
	extra.add_child(g._wrap(str(site.clue),14,INK))
	var caps: Dictionary=g.state.adventure_capabilities(p)
	for behavior: Dictionary in caps.behaviors:
		if not bool(behavior.ready): continue
		extra.add_child(g._wrap(str(behavior.description),13,INK))
		extra.add_child(g._wrap(str(behavior.tradeoff),12,MUTED))
	action(g,"Cross a new idea",func(): g._show_adventure_cross(chosen),"cross",extra)
	Locale.apply_tree(g.modal)

static func discovery_success(g: Control,result: Dictionary) -> void:
	var site_id: String=str(result.site_id)
	var site: Dictionary=g.state.adventure_site(site_id)
	var id: String=str(result.plant_id)
	var p: Dictionary=g.state.get_plant(id)
	var worked: bool=bool(result.get("success",false))
	open(g,"A night discovery!" if bool(result.get("enhancement_unlocked",false)) else ("Your plant changed this place!" if worked else "An idea to grow from"),"adventure_discovery_result")
	stage(g.modal_content,p,"night" if bool(result.get("combined",false)) or str(result.approach)=="glow" else ("rain" if site_id in ["rain_nursery","cistern"] else "wind"),175 if g.small_layout else 230)
	g.modal_content.add_child(g._wrap(str(result.message),18,INK))
	if not worked:
		g.modal_content.add_child(g._wrap("No supplies lost. Your plant is ready for another experiment.",14,MUTED))
	else:
		if not bool(site.get("enhanced",false)): g.modal_content.add_child(g._wrap("What if this plant could glow, too?",15,WARM))
		var reward: Dictionary=result.get("enhancement_reward_seed",{})
		var reward_index: int=int(result.get("enhancement_seed_index",-1))
		if reward.is_empty(): reward=result.get("reward_seed",{}); reward_index=int(result.get("seed_index",-1))
		if not reward.is_empty() and reward_index>=0:
			g.modal_content.add_child(g._wrap("Discovered: %s" % str(reward.name),17,WARM))
			var reference: Variant=g.state.market_ref("seed",reward_index)
			action(g,"Plant the discovered seed →",func(): g._open_planting(-1,reference),"plant_reward",g.modal_content,{"site_id":site_id})
	var buttons:=footer(g)
	action(g,"See it in the valley →",func(): g._adventure_visit(site_id),"visit_site",buttons,{"site_id":site_id})
	if not worked: action(g,"Try another plant",func(): g._show_adventure_discovery(site_id),"choose_plant",buttons)
	else: action(g,"Cross a new idea",func(): g._show_adventure_cross(id),"cross",buttons)
	if worked: g._care_sparkles()
	Locale.apply_tree(g.modal)

static func experiments(g: Control,plant_id: String="",mode: String="rain") -> void:
	var ids: Array[String]=_owned(g,true)
	var party: Array=g.state.travel_party()
	var chosen: String=plant_id if ids.has(plant_id) else (str(party[0].id) if not party.is_empty() else (ids[0] if not ids.is_empty() else ""))
	open(g,"Plant playground","adventure_experiments")
	if chosen.is_empty():
		g.modal_content.add_child(g._wrap("Meet a plant in the valley and take a free cutting.",18,INK))
		return
	g.modal.set_meta("plant_id",chosen)
	g.modal.set_meta("weather_mode",mode)
	_picker(g,g.modal_content,ids,chosen,"experiment_plant",func(id: String): experiments(g,id,mode))
	var modes:=HBoxContainer.new()
	g.modal_content.add_child(modes)
	for row: Array in [["Rain","rain"],["Wind","wind"],["Night","night"]]:
		var button:=action(g,str(row[0]),func(): experiments(g,chosen,str(row[1])),"weather",modes,{"mode":str(row[1])})
		button.disabled=str(row[1])==mode
	var p: Dictionary=g.state.get_plant(chosen)
	stage(g.modal_content,p,mode,195 if g.small_layout else 280)
	var caps: Dictionary=g.state.adventure_capabilities(p)
	var property: String="glow" if mode=="night" else ("coil" if mode=="wind" else "canopy")
	var active: bool=bool(caps.get(property,false)) and bool(p.get("mature",false))
	if mode=="wind" and bool(caps.canopy) and bool(p.get("mature",false)): active=true
	var reactions: Dictionary={"rain":["Rain slides off the waxy canopy. The little seedling stays dry.","Rain falls through. Broad waxy leaves could make a shelter."],"wind":["Tendrils grip the support and catch seeds on the wind.","Seeds drift past. Fibrous climbing growth could catch them."],"night":["Moths gather around the flower's inherited glow.","The moths stay at the edge. A glowing flower could draw them closer."]}
	if mode=="wind" and bool(caps.canopy): reactions.wind[0]="Broad leaves cup the seeds drifting on the breeze."
	g.modal_content.add_child(g._wrap(str(reactions[mode][0 if active else 1]),17,INK))
	if not bool(p.get("mature",false)): g.modal_content.add_child(g._wrap("This seedling is still growing. Try again after its leaves unfurl.",14,WARM))
	g.modal_content.add_child(g._wrap("Free experiments · DNA stays unchanged",12,MUTED))
	var buttons:=footer(g)
	action(g,"Take outside →",func(): g._adventure_try_outside(chosen),"outside",buttons,{"plant_id":chosen,"wait_for_maturity":true}).disabled=not bool(p.get("mature",false))
	if not bool(p.get("mature",false)): action(g,"Rest until morning",g._show_garden_day,"rest",buttons)
	action(g,"Cross with another plant",func(): g._show_adventure_cross(chosen),"cross",buttons)
	Locale.apply_tree(g.modal)

static func tick(g: Control) -> void:
	if not is_instance_valid(g.modal) or not str(g.modal_kind).begins_with("adventure_"): return
	_tick_node(g,g.modal)
	Locale.apply_tree(g.modal)

static func _tick_node(g: Control,node: Node) -> void:
	if node is Label:
		match str(node.get_meta("adventure_timer","")):
			"seedling":
				var p: Dictionary=g.state.get_plant(str(node.get_meta("plant_id","")))
				node.text="Ready!" if p.get("mature",false) else "Growing · %d seconds" % _ready_time(p)
			"eligibility":
				var preview: Dictionary=g.state.adventure_preview(str(node.get_meta("plant_id","")),str(node.get_meta("goal","stream")))
				node.text=str(preview.get("reason",""))
	if node is Button:
		match str(node.get_meta("adventure_action","")):
			"siblings":
				var mother: String=str(node.get_meta("mother_id",""))
				var status: Dictionary=g.state.fruit_status(mother)
				var info: Dictionary=g.state.adventure_info()
				var ready: bool=status.get("cross_ready",false) or (str(info.get("last_cross",{}).get("mother_id",""))==mother and bool(info.get("cross_ready",false)))
				node.disabled=not ready
				node.text="Grow both seeds · 20 light" if ready else "Fruit growing · %d seconds" % maxi(0,int(status.get("pollination",{}).get("ready_at",0))-int(Time.get_unix_time_from_system()))
			"apply": node.disabled=not g.state.adventure_preview(str(node.get_meta("plant_id","")),str(node.get_meta("goal","stream"))).get("eligible",false)
			"use":
				if node.get_meta("wait_for_maturity",false):
					var p: Dictionary=g.state.get_plant(str(node.get_meta("plant_id","")))
					node.disabled=not p.get("mature",false)
					node.text="Try this plant →" if not node.disabled else "Growing · %d seconds" % _ready_time(p)
			"outside":
				node.disabled=not bool(g.state.get_plant(str(node.get_meta("plant_id",""))).get("mature",false))
			"select_sibling":
				node.text="Selected ✓" if str(node.get_meta("plant_id",""))==str(g.modal.get_meta("selected_sibling","")) else "Select"
	for child: Node in node.get_children(): _tick_node(g,child)
