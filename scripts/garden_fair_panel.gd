extends RefCounted
## A friendly show-and-tell. Visitors admire plants; every plant stays at home.
const Portrait = preload("res://scripts/plant_portrait.gd")
const Avatar = preload("res://scripts/fair_avatar.gd")
const INK := Color("284838")
const MUTED := Color("617957")
const WARM := Color("a4542b")

static func reward_text(rewards: Dictionary) -> String:
	var parts: Array[String] = ["%d coins" % int(rewards.get("coins",0)),"%d light" % int(rewards.get("sunlight",0))]
	if int(rewards.get("grafts",0))>0: parts.append("%d grafting material" % int(rewards.grafts))
	if int(rewards.get("agents",0))>0: parts.append("%d mutation agent" % int(rewards.agents))
	return " + ".join(parts)

static func _npc_key(request: Dictionary) -> String:
	return str(request.get("npc","Mira")).get_slice(",",0).to_lower()

static func _card(g: Control,parent: Node,color: String = "fff4ce") -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel",g._style(Color(color),Color("a5bf83"),0,13,12))
	parent.add_child(panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation",9)
	panel.add_child(body)
	return body

static func _action(g: Control,title: String,callback: Callable,action: String) -> Button:
	var button: Button = g._button(title,callback)
	button.set_meta("fair_action",action)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size.y = 44
	button.clip_text = true
	return button

static func _avatar(parent: Node,kind: String,dimensions: Vector2) -> void:
	var face := Avatar.new()
	face.kind = kind
	face.ribbon = kind=="ribbon"
	face.custom_minimum_size = dimensions
	parent.add_child(face)

static func show(g: Control,tab: String = "requests",feedback: String = "") -> void:
	if g.exploring: g._return_from_wilderness()
	g.fair_tab = "ribbons" if tab=="ribbons" else "requests"
	g._open_modal("The Garden Fair","fair")
	g.modal.set_meta("fair_tab",g.fair_tab)
	var hero := HBoxContainer.new()
	hero.add_theme_constant_override("separation",12)
	g.modal_content.add_child(hero)
	_avatar(hero,"mira",Vector2(64,76) if g.small_layout else Vector2(86,90))
	var welcome := VBoxContainer.new()
	welcome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero.add_child(welcome)
	welcome.add_child(g._wrap("Every plant has a story. Come share yours!",18 if g.small_layout else 23,INK))
	welcome.add_child(g._wrap("Show a plant · keep your pal · collect a little joy",13,WARM))
	if not feedback.is_empty():
		var cheer: Label = g._wrap(feedback,16,WARM)
		cheer.set_meta("fair_feedback",true)
		g.modal_content.add_child(cheer)
	var tabs := HBoxContainer.new()
	g.modal_content.add_child(tabs)
	for entry: Array in [["requests","Today's visitors"],["ribbons","My ribbons"]]:
		var key: String = str(entry[0])
		var button: Button = _action(g,str(entry[1]),func(): g._open_fair(key),"tab")
		button.set_meta("fair_tab",key)
		if key==g.fair_tab: button.add_theme_stylebox_override("normal",g._style(Color("ffce98"),Color("ce9559"),0,12,10))
		tabs.add_child(button)
	if g.fair_tab=="ribbons": _ribbons(g)
	else: _requests(g)

static func _requests(g: Control) -> void:
	g.modal_content.add_child(g._wrap("Three friendly visits each day. Find a match, show your plant, and take your rewards home together.",13,MUTED))
	var grid := GridContainer.new()
	grid.columns = 1 if g.small_layout else 3
	grid.add_theme_constant_override("h_separation",12)
	grid.add_theme_constant_override("v_separation",12)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	g.modal_content.add_child(grid)
	for request: Dictionary in g.state.fair_requests():
		var key: String = str(request.key)
		var claimed: bool = bool(request.get("claimed",false))
		var card := _card(g,grid,"e8f0cd" if claimed else {"mira":"fff0bf","jun":"e0f1e6","pip":"ffe5d3"}.get(_npc_key(request),"fff0bf"))
		_avatar(card,_npc_key(request),Vector2(64,70))
		card.add_child(g._wrap(str(request.npc),13,WARM))
		card.add_child(g._wrap(str(request.title),19,INK))
		card.add_child(g._wrap(str(request.goal),13,MUTED))
		card.add_child(g._wrap("A thank-you gift: %s" % reward_text(request.reward),13,INK))
		var matches: int = request.get("eligible_ids",[]).size()
		card.add_child(g._wrap("A lovely visit. See you tomorrow!" if claimed else ("You have a plant ready to show!" if matches>0 else "A little growing adventure to try."),12,WARM))
		var visit: Button = _action(g,"Visit again tomorrow" if claimed else ("Show a plant →" if matches>0 else "Let's find a match →"),func(): g._show_fair_request(key),"request")
		visit.set_meta("request_key",key)
		visit.disabled = claimed
		card.add_child(visit)
	g.modal_content.add_child(g._wrap("Visitors change at 00:00 UTC. Ribbons are yours to keep forever.",11,MUTED))

static func request_view(g: Control,key: String,plant_id: String = "",feedback: String = "") -> void:
	var request: Dictionary = {}
	for candidate: Dictionary in g.state.fair_requests():
		if str(candidate.key)==key: request=candidate; break
	if request.is_empty():
		show(g,"requests","The fair has new visitors. Pick today's visit to continue.")
		return
	var chosen: String = plant_id
	var living: Array[String] = []
	for id: String in g.state.plant_order:
		if not g.state.get_plant(id).get("withered",false): living.append(id)
	if not living.has(chosen): chosen = str(request.eligible_ids[0]) if not request.eligible_ids.is_empty() else (living[0] if not living.is_empty() else "")
	g._open_modal("A little plant show-and-tell","fair_request")
	g.modal.set_meta("request_key",key)
	g.modal.set_meta("plant_id",chosen)
	var hero := HBoxContainer.new()
	g.modal_content.add_child(hero)
	_avatar(hero,_npc_key(request),Vector2(68,82))
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero.add_child(words)
	words.add_child(g._wrap(str(request.npc),17,WARM))
	words.add_child(g._wrap(str(request.title),22,INK))
	words.add_child(g._wrap(str(request.description),13,MUTED))
	if not feedback.is_empty(): g.modal_content.add_child(g._wrap(feedback,15,WARM))
	var wish := _card(g,g.modal_content,"fff0bd")
	wish.add_child(g._wrap(str(request.goal),16,INK))
	wish.add_child(g._wrap("A thank-you gift: %s" % reward_text(request.reward),13,WARM))
	if living.is_empty():
		g.modal_content.add_child(g._wrap("Your next plant friend starts with a seed. Plant one, let it grow, then come say hello!",16,INK))
		g.modal_content.add_child(_action(g,"Plant a seed →",func(): g._open_planting(),"plant_seed"))
	else:
		g.modal_content.add_child(g._wrap("Which plant is coming along?",15,INK))
		var picker := OptionButton.new()
		picker.set_meta("fair_plant_picker",true)
		picker.set_meta("fair_action","choose_plant")
		picker.set_meta("request_key",key)
		picker.clip_text = true
		picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		picker.custom_minimum_size.y = 42
		for id: String in living:
			picker.add_item(str(g.state.get_plant(id).name))
			picker.set_item_metadata(picker.item_count-1,id)
			if id==chosen: picker.select(picker.item_count-1)
		picker.item_selected.connect(func(index: int): g._show_fair_request(key,str(picker.get_item_metadata(index))))
		g.modal_content.add_child(picker)
		var p: Dictionary = g.state.get_plant(chosen)
		var plant_row := HBoxContainer.new()
		plant_row.add_theme_constant_override("separation",12)
		g.modal_content.add_child(plant_row)
		var art := Portrait.new()
		art.plant = p
		art.custom_minimum_size = Vector2(95,145) if g.small_layout else Vector2(160,185)
		plant_row.add_child(art)
		var notes := VBoxContainer.new()
		notes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		plant_row.add_child(notes)
		notes.add_child(g._wrap(str(p.name),23,INK))
		notes.add_child(g._measurement_label(chosen))
		var preview: Dictionary = g.state.fair_preview(key,chosen)
		var status: Label = g._wrap("A perfect match! Let's introduce you." if preview.get("eligible",false) else str(preview.reason),14,WARM)
		status.set_meta("fair_match_status",true)
		status.set_meta("request_key",key)
		status.set_meta("plant_id",chosen)
		notes.add_child(status)
		g.fair_labels.append(status)
		notes.add_child(g._wrap("You keep your plant, its fruit, and its whole family story.",12,MUTED))
		g.modal_content.add_child(_action(g,"See this plant's traits",func(): g._open_dna(chosen),"traits"))
		g.modal_content.add_child(_action(g,"Try a little plant care",func(): g._open_care(chosen),"care"))
	var footer := VBoxContainer.new()
	footer.add_theme_constant_override("separation",7)
	g.modal.get_node("Panel").get_child(0).add_child(footer)
	var show_plant: Button = _action(g,"Shown today!" if request.claimed else "Show this plant · collect gifts",func(): g._claim_fair_request(key,chosen),"claim_request")
	show_plant.set_meta("request_key",key)
	show_plant.set_meta("plant_id",chosen)
	show_plant.disabled = not g.state.fair_preview(key,chosen).get("eligible",false)
	show_plant.add_theme_stylebox_override("normal",g._style(Color("ffca91"),Color("c88a4e"),0,12,12))
	footer.add_child(show_plant)
	g.fair_buttons.append(show_plant)
	footer.add_child(_action(g,"Back to the fair",func(): g._open_fair(),"back"))

static func _ribbons(g: Control) -> void:
	g.modal_content.add_child(g._wrap("Little milestones, lovely memories",21,INK))
	g.modal_content.add_child(g._wrap("Grow, cross, and explore at your own pace. Each ribbon is a permanent keepsake, with a one-time gift.",13,MUTED))
	var grid := GridContainer.new()
	grid.columns = 1 if g.small_layout else 2
	grid.add_theme_constant_override("h_separation",12)
	grid.add_theme_constant_override("v_separation",12)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	g.modal_content.add_child(grid)
	for ribbon: Dictionary in g.state.fair_ribbons():
		var key: String = str(ribbon.key)
		var earned: bool = bool(ribbon.earned)
		var card := _card(g,grid,"fff0bd" if earned else "e7efd3")
		var heading := HBoxContainer.new()
		card.add_child(heading)
		_avatar(heading,"ribbon",Vector2(48,62))
		heading.add_child(g._wrap(str(ribbon.title),18,INK))
		card.add_child(g._wrap(str(ribbon.goal),13,MUTED))
		card.add_child(g._wrap("Yours forever!" if earned else "Progress · %d / %d" % [mini(int(ribbon.get("progress",0)),int(ribbon.get("target",1))),int(ribbon.get("target",1))],13,WARM))
		card.add_child(g._wrap("A little gift: %s" % reward_text(ribbon.reward),12,INK))
		var collect: Button = _action(g,"In your ribbon book" if earned else "Collect this ribbon",func(): g._claim_fair_ribbon(key),"claim_ribbon")
		collect.set_meta("ribbon_key",key)
		collect.disabled = earned or not ribbon.get("eligible",false)
		card.add_child(collect)
		g.fair_buttons.append(collect)

static func celebrate(g: Control,result: Dictionary,tab: String) -> void:
	g._open_modal("You made someone's day!","fair_reward")
	var id: String = str(result.get("plant_id",""))
	var p: Dictionary = g.state.get_plant(id)
	if not p.is_empty():
		var art := Portrait.new()
		art.plant = p
		art.activity = 1.0
		art.custom_minimum_size = Vector2(160,180)
		g.modal_content.add_child(art)
		g.modal_content.add_child(g._wrap("%s made the visitors smile!" % str(p.name),23,INK))
	else:
		_avatar(g.modal_content,"ribbon",Vector2(100,120))
		g.modal_content.add_child(g._wrap("A new ribbon for your growing story!",23,INK))
	g.modal_content.add_child(g._wrap(str(result.get("message","A lovely garden memory.")),14,MUTED))
	var gifts := _card(g,g.modal_content,"fff0bc")
	gifts.add_child(g._wrap("A gift for you",17,WARM))
	gifts.add_child(g._wrap(reward_text(result.get("rewards",{})),19,INK))
	var again: Button = _action(g,"Visit another friend →" if tab=="requests" else "See my ribbon book →",func(): g._open_fair(tab),"continue")
	g.modal_content.add_child(again)
	g.modal_content.add_child(_action(g,"Back to my garden",func(): g._close_modal(); g._refresh(),"garden"))
