extends RefCounted
## Human-readable genetics and decisions, backed by the same inheritance rules
## that create real seeds. Encoded identifiers are opt-in reference material.
const Guide = preload("res://scripts/genetics_guide.gd")
const DNA = preload("res://scripts/plant_dna.gd")
const Portrait = preload("res://scripts/plant_portrait.gd")
const State = preload("res://scripts/garden_state.gd")
const INK := Color("dce0ce")
const MUTED := Color("8d9f91")
const AMBER := Color("d5b67b")
const GREEN := Color("b8c9a3")
const GOAL_KEYS := ["pattern","petals","size","shape","form"]

static func _number(value: float) -> String:
	var rounded: float = snappedf(value,0.1)
	return str(roundi(rounded)) if is_equal_approx(rounded,roundf(rounded)) else "%.1f" % rounded

static func _card(g: Control,parent: Node) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel",g._style(Color("1b3025"),Color("405b46"),0,12,10))
	parent.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",7)
	panel.add_child(column)
	return column

static func _value(g: Control,parent: Node,prefix: String,value: String,color: Variant,role: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",8)
	parent.add_child(row)
	if color is Color:
		var swatch := ColorRect.new()
		swatch.color = color
		swatch.custom_minimum_size = Vector2(22,22)
		swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(swatch)
	var label: Label = g._wrap(prefix % value,13,INK if role=="visible" else GREEN)
	label.set_meta("role",role)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

static func _transmission(trait_info: Dictionary) -> String:
	var options: Array = trait_info.get("transmission",[])
	if options.size()==1: return "Always passes on %s." % str(options[0].value)
	if options.size()>1 and str(options[0].value)==str(options[1].value): return "Two shades of %s; each has a 50%% chance of being passed on." % str(options[0].value)
	if options.size()>1: return "Can pass on %s or %s: 50%% each." % [options[0].value,options[1].value]
	return "Always passes on %s." % str(trait_info.visible)

static func _fold(g: Control,parent: Node,title: String,action: String) -> VBoxContainer:
	var toggle := CheckButton.new()
	toggle.text = title
	toggle.set_meta("reproduction_action",action)
	toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toggle.clip_text = true
	parent.add_child(toggle)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation",9)
	body.visible = false
	parent.add_child(body)
	toggle.toggled.connect(func(open: bool): body.visible=open)
	return body

static func _trait_card(g: Control,parent: Node,p: Dictionary,trait_info: Dictionary) -> void:
	var card: VBoxContainer = _card(g,parent)
	card.set_meta("trait_key",trait_info.key)
	card.get_parent().set_meta("trait_key",trait_info.key)
	card.add_child(g._wrap(str(trait_info.label),17,AMBER))
	_value(g,card,"Inherited color: %s" if str(trait_info.key)=="color" and float(p.get("life_age",0))>=1200+float(p.get("care",{}).get("life_bonus_seconds",0)) else "Shows: %s",str(trait_info.visible),trait_info.get("visible_color"),"visible")
	if bool(trait_info.get("has_hidden",false)):
		var alternative: String = str(trait_info.hidden)
		if trait_info.key in ["color","accent"] and str(trait_info.visible)==alternative: alternative = "Another shade of %s" % alternative
		_value(g,card,"Also active: %s" if trait_info.get("carried_active",false) else "Hidden alternative: %s",alternative,trait_info.get("hidden_color"),"hidden")
	else:
		var same: Label = g._wrap("Both copies are the same; no hidden alternative.",12,MUTED)
		same.set_meta("role","hidden")
		card.add_child(same)
	card.add_child(g._wrap(str(trait_info.explanation),12,MUTED))
	card.add_child(g._wrap(_transmission(trait_info),12,GREEN))
	var source: Dictionary = p.get("gene_sources",{}).get(str(trait_info.key),{})
	if not source.is_empty() and str(source.get("expressed_origin","founder"))!="founder":
		card.add_child(g._wrap(Guide.origin_note(p,str(trait_info.key)),11,MUTED))
	if bool(trait_info.get("has_hidden",false)) and str(trait_info.key) in GOAL_KEYS:
		var find: Button = g._action_button("Find mates for %s" % str(trait_info.hidden),func(): g._open_dna_compare(str(p.id),"",str(trait_info.key),trait_info.carried_raw),"dna_compare",str(p.id))
		find.set_meta("goal_key",trait_info.key)
		find.set_meta("goal_value",trait_info.carried_raw)
		card.add_child(find)

static func show_traits(g: Control,id: String) -> void:
	var p: Dictionary = g._inspection_plant(id)
	if p.is_empty(): return
	var owned: bool = g._owns_plant(id)
	g._open_modal(("Traits · %s" if g.small_layout else "Traits & breeding · %s") % str(p.name),"dna")
	g.modal.set_meta("dna_plant_id",id)
	g.modal_content.add_child(g._wrap("Traits you can breed for" if g.small_layout else "Read the plant. Plan its next generation.",17 if g.small_layout else 19,AMBER))
	g.modal_content.add_child(g._wrap("See its visible traits and hidden alternatives, then plan a cross." if g.small_layout else "Shown traits shape this plant. Hidden alternatives can return in its descendants. Choose a mate to see the actual chances for each offspring trait.",13))
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation",12)
	g.modal_content.add_child(top)
	var art := Portrait.new()
	art.plant = p
	art.custom_minimum_size = Vector2(84,124) if g.small_layout else Vector2(160,185)
	art.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_child(art)
	var overview := VBoxContainer.new()
	overview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	overview.add_theme_constant_override("separation",8)
	top.add_child(overview)
	overview.add_child(g._wrap(str(p.name),25,INK))
	if owned: overview.add_child(g._measurement_label(id))
	overview.add_child(g._wrap("Generation %d · %s" % [p.generation,g._lineage_text(p)],12,GREEN))
	var visible_traits: Array = Guide.trait_summary(p)
	for key: String in (["color","pattern"] if g.small_layout else ["color","pattern","form"]):
		for trait_info: Dictionary in visible_traits:
			if trait_info.key==key: _value(g,overview,"%s",str(trait_info.visible),trait_info.get("visible_color"),"overview")
	for trait_info: Dictionary in visible_traits:
		if trait_info.key=="pattern" and trait_info.get("has_hidden",false): overview.add_child(g._wrap("Hidden pattern: %s" % str(trait_info.hidden),12,GREEN))
	var actions: Node = g.modal_content if g.small_layout else overview
	if owned: actions.add_child(g._live_life_label(id))
	if owned: actions.add_child(g._care_entry(id))
	var compare: Button = g._action_button("Choose a mate & predict offspring",func(): g._open_dna_compare(id),"dna_compare",id)
	compare.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(compare)
	actions.add_child(g._wrap("The preview is free. It does not pollinate or spend resources.",11,MUTED))
	var parents: Array = p.get("parents",[])
	if not parents.is_empty():
		var links := HBoxContainer.new()
		links.add_theme_constant_override("separation",6)
		overview.add_child(links)
		for index in range(mini(2,parents.size())):
			var parent_id: String = str(parents[index])
			if g._inspection_plant(parent_id).is_empty(): continue
			links.add_child(g._action_button("Mother's traits" if index==0 else "Father's traits",func(): g._open_dna(parent_id),"view_dna",parent_id))
	g.modal_content.add_child(g._wrap("What this plant shows and can pass on",17,AMBER))
	g.modal_content.add_child(g._wrap("A parent passes one copy of each trait. The other parent contributes too: a 50% chance of passing a trait is different from the offspring's chance of showing it.",12,MUTED))
	var grid := GridContainer.new()
	grid.columns = 1 if g.small_layout else 2
	grid.add_theme_constant_override("h_separation",10)
	grid.add_theme_constant_override("v_separation",10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	g.modal_content.add_child(grid)
	var inactive: Array[Dictionary] = []
	var ordered: Array = visible_traits.duplicate()
	ordered.sort_custom(func(a,b): return str(a.key)=="pattern" and str(b.key)!="pattern")
	for trait_info: Dictionary in ordered:
		if not bool(trait_info.get("appearance_applies",true)): inactive.append(trait_info); continue
		_trait_card(g,grid,p,trait_info)
	if not inactive.is_empty():
		var stored: VBoxContainer = _fold(g,g.modal_content,"Stored traits · not currently visible","dna_stored_traits")
		stored.add_child(g._wrap("These genes are still inherited. They become visible when a descendant has the matching plant organs.",12,MUTED))
		for trait_info: Dictionary in inactive: _trait_card(g,stored,p,trait_info)
	var stats: VBoxContainer = _fold(g,g.modal_content,"Battle traits · what the numbers do","dna_battle_traits")
	for stat: Dictionary in Guide.cross_preview(p,p).get("stats",[]):
		var card: VBoxContainer = _card(g,stats)
		card.add_child(g._wrap("%s: %d" % [stat.label,int(p.get("stats",{}).get(stat.key,0))],15,INK))
		card.add_child(g._wrap(str(stat.get("explanation",stat.get("effect",""))),12,MUTED))
	var tissues: Array = p.get("graft_history",[]).duplicate()
	tissues.append_array(p.get("inherited_graft_records",[]))
	for tissue: Dictionary in tissues:
		var donor: Dictionary = tissue.get("donor_genes",{})
		var card: VBoxContainer = _card(g,g.modal_content)
		card.add_child(g._wrap("Grafted branch from %s" % tissue.get("donor_name",tissue.get("donor_type","Donor")),16,AMBER))
		card.add_child(g._wrap("This branch has the donor's traits. A child has a 20% chance to inherit this graft.",12))
		if not donor.is_empty(): card.add_child(g._wrap("%s · %s" % [Guide.trait_value("color",donor.get("color",{}).get("dominant","829d80")),Guide.trait_value("pattern",donor.get("pattern",{}).get("dominant","Solid"))],12,GREEN))
	var advanced: VBoxContainer = _fold(g,g.modal_content,"Advanced · encoded records","dna_advanced")
	advanced.add_child(g._wrap("These codes identify the stored genome. Trait cards and the cross preview explain the inherited effects.",12,MUTED))
	var genome: Dictionary = DNA.profile(p)
	advanced.add_child(g._wrap("Genome ID: %s" % genome.code,12,MUTED))
	for locus: Dictionary in genome.loci:
		advanced.add_child(g._wrap("%s · %s" % [locus.label,locus.sequence],10,MUTED))
		advanced.add_child(g._wrap(DNA.origin_text(locus),11,MUTED))
	advanced.add_child(g._wrap(str(genome.sequence),10,MUTED))
	if owned:
		var use: Button = g._action_button("Use as a parent",func(): g._breed_from(id),"next_cross",id)
		use.disabled = not p.get("mature",false) or p.get("withered",false) or g.sim!=null
		g.reproduction_buttons.append(use)
		g.modal_content.add_child(use)
	elif str(g.state.expedition.get("active_encounter",{}).get("plant",{}).get("id",""))==id:
		g.modal_content.add_child(g._wrap("Collect this wild plant before using it as a parent.",13,AMBER))
		g.modal_content.add_child(g._button("Back to the wild plant",func(): g._show_wild_encounter()))
	else:
		g.modal_content.add_child(g._button("Return to fruit & seeds",func(): g.nursery_tab="seeds"; g._open_seeds()))

static func _goal_options(g: Control,p: Dictionary,key: String) -> Array:
	var values: Array = []
	match key:
		"pattern": values = State.PATTERNS.duplicate()
		"petals": values = [3,4,5,6,7,8,9,10,11,12]
		"size": values = ["Small","Standard","Large"]
		"shape": values = State.SHAPES.duplicate()
		"form": values = State.FORMS.duplicate()
	var gene: Dictionary = p.get("genes",{}).get(key,{})
	for copy: Variant in gene.values():
		if not values.any(func(value): return DNA.canonical(value)==DNA.canonical(copy)): values.append(copy)
	return values

static func _chance(preview: Dictionary,key: String,value: Variant) -> float:
	for trait_info: Dictionary in preview.get("traits",[]):
		if str(trait_info.key)!=key: continue
		for outcome: Dictionary in trait_info.outcomes:
			if DNA.canonical(outcome.raw)==DNA.canonical(value): return float(outcome.probability)
	return 0.0

static func _odds_bar(g: Control,parent: Node,outcome: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",8)
	parent.add_child(row)
	if outcome.get("color") is Color:
		var swatch := ColorRect.new()
		swatch.color = outcome.color
		swatch.custom_minimum_size = Vector2(16,16)
		row.add_child(swatch)
	var label: Label = g._wrap(str(outcome.value),12,INK)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	row.add_child(g._label("%s%%" % _number(float(outcome.probability)*100),12,AMBER))
	var meter: ProgressBar = g._meter(float(outcome.probability),Color("91aa78"))
	parent.add_child(meter)

static func _display_outcomes(trait_info: Dictionary) -> Array:
	if not str(trait_info.key) in ["color","accent"]: return trait_info.outcomes
	# Color words describe families. Merge nearby shades instead of showing the
	# same name in several competing rows; analytical raw outcomes stay intact.
	var groups: Dictionary = {}
	for outcome: Dictionary in trait_info.outcomes:
		var name: String = str(outcome.value)
		if not groups.has(name): groups[name] = {"value":name,"probability":0.0,"weighted":Color(0,0,0,0),"count":0}
		groups[name].probability += float(outcome.probability)
		groups[name].weighted += outcome.color*float(outcome.probability)
		groups[name].count += 1
	var result: Array = []
	for group: Dictionary in groups.values():
		result.append({"value":"%s shades" % group.value if int(group.count)>1 else group.value,"probability":group.probability,"color":group.weighted/maxf(0.00001,float(group.probability))})
	result.sort_custom(func(a,b): return float(a.probability)>float(b.probability))
	return result

static func show_cross(g: Control,id: String,mate_id: String = "",goal_key: String = "pattern",goal_value: Variant = null) -> void:
	var p: Dictionary = g._inspection_plant(id)
	if p.is_empty(): return
	if not goal_key in GOAL_KEYS: goal_key = "pattern"
	if goal_value==null: goal_value = p.get("genes",{}).get(goal_key,{}).get("recessive",p.get("genes",{}).get(goal_key,{}).get("dominant","Solid"))
	var candidates: Array[String] = []
	for other: String in g.state.plant_order:
		var plant: Dictionary = g.state.get_plant(other)
		if other!=id and plant.get("mature",false) and not plant.get("withered",false): candidates.append(other)
	g._open_modal("Breeding preview","dna_compare")
	g.modal.set_meta("dna_plant_id",id)
	if candidates.is_empty():
		g.modal_content.add_child(g._wrap("Raise or collect another mature plant to compare a cross.",15))
		g.modal_content.add_child(g._button("Back to traits",func(): g._open_dna(id)))
		return
	if not candidates.has(mate_id): mate_id = candidates[0]
	var mate: Dictionary = g.state.get_plant(mate_id)
	var preview: Dictionary = Guide.cross_preview(p,mate)
	g.modal.set_meta("dna_preview",preview)
	g.modal.set_meta("dna_goal_key",goal_key)
	g.modal.set_meta("dna_goal_value",goal_value)
	g.modal_content.add_child(g._wrap("%s × %s" % [p.name,mate.name],22,INK))
	g.modal_content.add_child(g._wrap("Each seed is an independent roll. These chances describe inherited traits, not a guaranteed child.",12,MUTED))
	g.modal_content.add_child(g._label("Choose a mate",12,AMBER))
	var picker := OptionButton.new()
	picker.clip_text = true
	picker.set_meta("dna_mate_picker",true)
	for other: String in candidates:
		picker.add_item(str(g.state.get_plant(other).name))
		picker.set_item_metadata(picker.item_count-1,other)
		if other==mate_id: picker.select(picker.item_count-1)
	picker.item_selected.connect(func(index: int): g._open_dna_compare(id,str(picker.get_item_metadata(index)),goal_key,goal_value))
	g.modal_content.add_child(picker)
	g.modal_content.add_child(g._label("What would you like to breed?",12,AMBER))
	var goals := HBoxContainer.new()
	goals.add_theme_constant_override("separation",6)
	g.modal_content.add_child(goals)
	var goal_trait := OptionButton.new()
	goal_trait.clip_text = true
	goal_trait.set_meta("dna_goal_trait",true)
	goal_trait.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for key: String in GOAL_KEYS:
		goal_trait.add_item(str(DNA.LABELS[key]))
		goal_trait.set_item_metadata(goal_trait.item_count-1,key)
		if key==goal_key: goal_trait.select(goal_trait.item_count-1)
	goals.add_child(goal_trait)
	goal_trait.item_selected.connect(func(index: int): g._open_dna_compare(id,mate_id,str(goal_trait.get_item_metadata(index)),null))
	var goal_choice := OptionButton.new()
	goal_choice.clip_text = true
	goal_choice.set_meta("dna_goal_value",true)
	goal_choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for raw: Variant in _goal_options(g,p,goal_key):
		goal_choice.add_item(Guide.trait_value(goal_key,raw))
		goal_choice.set_item_metadata(goal_choice.item_count-1,raw)
		if DNA.canonical(raw)==DNA.canonical(goal_value): goal_choice.select(goal_choice.item_count-1)
	goals.add_child(goal_choice)
	goal_choice.item_selected.connect(func(index: int): g._open_dna_compare(id,mate_id,goal_key,goal_choice.get_item_metadata(index)))
	var target: VBoxContainer = _card(g,g.modal_content)
	var chance: float = _chance(preview,goal_key,goal_value)
	target.set_meta("dna_target_probability",chance)
	target.add_child(g._wrap("Goal: %s" % Guide.trait_value(goal_key,goal_value),16,AMBER))
	target.add_child(g._wrap(("%s%% chance of this inherited petal count" if goal_key=="petals" else "%s%% chance the child shows this trait") % _number(chance*100),19,INK))
	if goal_key=="petals": target.add_child(g._wrap("Petal counts show on flowering descendants. Other descendants can carry this potential; starburst markings also use this count.",12,GREEN))
	target.add_child(g._wrap("Passing a copy and showing its trait are different. This prediction includes both parents' stored copies.",12,MUTED))
	var ranked: Array[Dictionary] = []
	for other: String in candidates:
		ranked.append({"id":other,"chance":_chance(Guide.cross_preview(p,g.state.get_plant(other)),goal_key,goal_value)})
	ranked.sort_custom(func(a,b): return float(a.chance)>float(b.chance))
	if ranked.size()>1:
		target.add_child(g._wrap("Best available mates for this goal",12,GREEN))
		for index in range(mini(3,ranked.size())):
			var candidate_id: String = str(ranked[index].id)
			var score: float = float(ranked[index].chance)
			var select: Button = g._action_button("%s · %s%%" % [g.state.get_plant(candidate_id).name,_number(score*100)],func(): g._open_dna_compare(id,candidate_id,goal_key,goal_value),"dna_choose_mate",candidate_id)
			select.set_meta("dna_probability",score)
			target.add_child(select)
	g.modal_content.add_child(g._wrap("Examples of possible offspring",15,AMBER))
	g.modal_content.add_child(g._wrap("These illustrate possibilities, not your next two seeds. Use the percentages to judge how likely each trait is.",11,MUTED))
	var examples := HBoxContainer.new()
	examples.add_theme_constant_override("separation",8)
	g.modal_content.add_child(examples)
	var possibilities: Array[Dictionary] = []
	var goal_example: Dictionary = {}
	var other_example: Dictionary = {}
	for trial in range(64):
		var sample: Dictionary = g.state._make_offspring(p,mate,absi(hash([p.get("seed",1),mate.get("seed",1),trial]))+1,"trait_preview_%d" % trial)
		if possibilities.size()<2: possibilities.append(sample)
		var matches: bool = DNA.canonical(sample.genes[goal_key].dominant)==DNA.canonical(goal_value)
		if matches and goal_example.is_empty(): goal_example=sample
		if not matches and other_example.is_empty(): other_example=sample
		if trial>=1 and (not goal_example.is_empty() or chance<=0) and (not other_example.is_empty() or chance>=1): break
	if not goal_example.is_empty(): possibilities[0]=goal_example
	if not goal_example.is_empty() and not other_example.is_empty() and possibilities.size()>1: possibilities[1]=other_example
	for index in range(2):
		var example: Dictionary = possibilities[mini(index,possibilities.size()-1)]
		example.mature = true
		var card: VBoxContainer = _card(g,examples)
		var art := Portrait.new()
		art.plant = example
		art.custom_minimum_size = Vector2(70,135)
		card.add_child(art)
		card.add_child(g._wrap("%s · %s" % [Guide.trait_value("color",example.genes.color.dominant),Guide.trait_value("pattern",example.genes.pattern.dominant)],11,MUTED))
		var example_chance: float = _chance(preview,goal_key,example.genes[goal_key].dominant)
		card.add_child(g._wrap(("Petal gene: %s · %s%% chance" if goal_key=="petals" else "%s · %s%% chance") % [Guide.trait_value(goal_key,example.genes[goal_key].dominant),_number(example_chance*100)],11,AMBER))
	g.modal_content.add_child(g._wrap("Offspring trait chances",16,AMBER))
	for trait_info: Dictionary in preview.get("traits",[]):
		var card: VBoxContainer = _card(g,g.modal_content)
		card.set_meta("trait_key",trait_info.key)
		card.add_child(g._wrap(str(trait_info.label),15,INK))
		if str(trait_info.key)=="petals": card.add_child(g._wrap("These are flower-gene chances. Flowers must be expressed for petals to appear.",11,MUTED))
		if str(trait_info.key) in ["color","accent"]: card.add_child(g._wrap("Similar shades are grouped into readable color families.",11,MUTED))
		for outcome: Dictionary in _display_outcomes(trait_info): _odds_bar(g,card,outcome)
	g.modal_content.add_child(g._wrap("Possible inherited abilities",16,AMBER))
	for outcome: Dictionary in preview.get("skill_outcomes",[]): _odds_bar(g,g.modal_content,outcome)
	g.modal_content.add_child(g._wrap("Expected inherited strengths",16,AMBER))
	for stat: Dictionary in preview.get("stats",[]):
		g.modal_content.add_child(g._wrap("%s: about %s · range %d–%d" % [stat.label,_number(float(stat.expected)),stat.min,stat.max],12,GREEN))
		g.modal_content.add_child(g._wrap(str(stat.get("explanation",stat.get("effect",""))),11,MUTED))
	for note: String in preview.get("notes",[]): g.modal_content.add_child(g._wrap(note,11,MUTED))
	var footer := VBoxContainer.new()
	footer.add_theme_constant_override("separation",6)
	g.modal.get_node("Panel").get_child(0).add_child(footer)
	var use: Button = g._action_button("Use this pair in the laboratory",func(): g._use_dna_pair(id,mate_id),"dna_use_pair",id)
	use.set_meta("parent_a",id)
	use.set_meta("parent_b",mate_id)
	use.disabled = not g._owns_plant(id) or not p.get("mature",false) or p.get("withered",false) or g.sim!=null
	g.reproduction_buttons.append(use)
	footer.add_child(use)
	if p.get("withered",false): footer.add_child(g._wrap("This is an archived plant. Grow its stored seeds to continue these traits in a living parent.",11,MUTED))
	elif p.get("sold",false): footer.add_child(g._wrap("This plant has a new home. Its family history stays in your archive.",11,MUTED))
	elif not g._owns_plant(id): footer.add_child(g._wrap("Collect this plant, or sow and raise this seed, before using the pair.",11,MUTED))
	elif not p.get("mature",false): footer.add_child(g._wrap("This seedling must mature before it can become a parent.",11,MUTED))
	footer.add_child(g._button("Back to traits",func(): g._open_dna(id)))
