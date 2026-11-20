extends RefCounted
## A tool shed built around the selected plant: see the benefit, then try it.
const Portrait = preload("res://scripts/plant_portrait.gd")
const Icon = preload("res://scripts/care_tool_icon.gd")
const INK := Color("284838")
const MUTED := Color("617957")
const WARM := Color("a4542b")
const TOOLS := [
	{"key":"water","name":"Watering can","tag":"A little drink, a little extra time.","description":"Adds 1 minute of life. Free, with a 60-second refill. Up to 5 drinks per plant.","color":"dcf1ea"},
	{"key":"longevity","name":"Life tonic","tag":"More time with your favorite plant.","description":"Adds 10 minutes before aging and withering. Up to 3 doses per plant.","color":"ffe2d4"},
	{"key":"growth","name":"Stretch feed","tag":"Go on. Grow a little taller!","description":"Adds 15% of its natural height each time. Up to 4 feeds per plant.","color":"fff0b8"},
	{"key":"compost","name":"Chunky compost","tag":"Big leaves. Happy roots.","description":"Adds 20% of its natural weight each time. Up to 4 scoops per plant.","color":"e6edbc"},
	{"key":"sunlamp","name":"Sunshine lamp","tag":"Hello, grown-up leaves!","description":"Instantly grows a seedling into a mature plant, ready to breed.","color":"fff0b8"},
	{"key":"ripening","name":"Ripening spray","tag":"Fresh fruit, right this moment.","description":"Ripens natural and hybrid fruit. Up to 5 sprays, with a 30-second refill. Harvest in Fruit & seeds.","color":"e2f0d2"}
]

static func _number(value: float) -> String:
	return str(roundi(value)) if value>=100 else "%.1f" % value

static func measurement_text(data: Dictionary) -> String:
	return "%s cm tall · %s g" % [_number(float(data.get("height_cm",0))),_number(float(data.get("weight_g",0)))]

static func garden_records(g: Control) -> Dictionary:
	var records := {"tallest":"","heaviest":"","height":0.0,"weight":0.0}
	for id in g.state.plant_order:
		var p: Dictionary = g.state.get_plant(str(id))
		if p.get("withered",false) or not p.get("mature",false): continue
		var data: Dictionary = g.state.plant_measurements(str(id))
		if float(data.height_cm)>float(records.height): records.tallest=str(id); records.height=float(data.height_cm)
		if float(data.weight_g)>float(records.weight): records.heaviest=str(id); records.weight=float(data.weight_g)
	return records

static func _measurement(g: Control,parent: Node,title: String,value: String,role: String) -> void:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel",g._style(Color("fff8df"),Color("adc58d"),0,10,9))
	parent.add_child(card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",2)
	card.add_child(column)
	column.add_child(g._wrap(title,11,MUTED))
	var label: Label = g._wrap(value,22,INK)
	label.set_meta("care_measurement",role)
	label.set_meta("care_plant_id",str(g.modal.get_meta("care_plant_id","")))
	column.add_child(label)
	g.care_labels.append(label)

static func _benefit(key: String,m: Dictionary,life: Dictionary) -> String:
	match key:
		"growth":
			if float(m.get("height_bonus",0))>=0.599: return "Maximum height reached. What a giant!"
			return "Full-grown height: %s → %s cm" % [_number(float(m.get("mature_height_cm",0))),_number(float(m.get("mature_height_cm",0))+float(m.get("natural_height_cm",0))*0.15)]
		"compost":
			if float(m.get("weight_bonus",0))>=0.799: return "Maximum weight reached. Looking lush!"
			return "Full-grown weight: %s → %s g" % [_number(float(m.get("mature_weight_g",0))),_number(float(m.get("mature_weight_g",0))+float(m.get("natural_weight_g",0))*0.20)]
		"water": return "+1 minute of life"
		"longevity": return "+10 minutes of life"
		"sunlamp": return "Seedling → ready to breed"
		_: return "Growing fruit → ripe fruit"

static func life_text(g: Control,id: String) -> String:
	var life: Dictionary = g.state.life_profile(id)
	if str(life.get("stage",""))=="withered": return "Resting in the archive"
	var seconds: int = maxi(0,ceili(float(life.get("remaining",0))))
	return "%d min %02d sec" % [seconds/60,seconds%60]

static func status_text(status: Dictionary) -> String:
	return "Ready! %d / %d uses left" % [int(status.get("remaining_uses",0)),int(status.get("max_uses",0))] if status.get("allowed",false) else str(status.get("reason",""))

static func show(g: Control,id: String = "",feedback: String = "") -> void:
	if g.exploring: g._return_from_wilderness()
	var chosen: String = id if g.state.plants.has(id) else str(g.selected_id)
	if not g.state.plants.has(chosen):
		for candidate in g.state.plant_order:
			if not g.state.get_plant(str(candidate)).get("withered",false): chosen=str(candidate); break
	if not g.state.plants.has(chosen) and not g.state.plant_order.is_empty(): chosen=str(g.state.plant_order[0])
	g._open_modal("The happy little tool shed","care")
	g.modal.set_meta("care_plant_id",chosen)
	if chosen.is_empty():
		g.modal_content.add_child(g._wrap("Plant a seed or bring home a wild plant, then give it a little love.",16,INK))
		g.modal_content.add_child(g._button("Find a plant in the wild",g._open_wilderness))
		return
	var p: Dictionary = g.state.get_plant(chosen)
	var picker := OptionButton.new()
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker.clip_text = true
	picker.custom_minimum_size.y = 40
	picker.set_meta("care_plant_picker",true)
	for candidate in g.state.plant_order:
		var specimen: Dictionary = g.state.get_plant(str(candidate))
		if specimen.is_empty(): continue
		picker.add_item(str(specimen.name))
		picker.set_item_metadata(picker.item_count-1,str(candidate))
		if str(candidate)==chosen: picker.select(picker.item_count-1)
	picker.item_selected.connect(func(index: int): g._open_care(str(picker.get_item_metadata(index))))
	g.modal_content.add_child(picker)
	if not feedback.is_empty():
		var cheer: Label = g._wrap(feedback,17,WARM)
		cheer.set_meta("care_feedback",true)
		g.modal_content.add_child(cheer)
	var hero := HBoxContainer.new()
	hero.add_theme_constant_override("separation",14)
	g.modal_content.add_child(hero)
	var art := Portrait.new()
	art.plant = p
	art.activity = 1.0 if not feedback.is_empty() else 0.0
	art.custom_minimum_size = Vector2(98,136) if g.small_layout else Vector2(180,185)
	hero.add_child(art)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero.add_child(info)
	info.add_child(g._wrap(str(p.name),24,INK))
	info.add_child(g._wrap("Tiny seedling, big dreams." if not p.get("mature",true) else "A one-of-a-kind plant pal.",13,MUTED))
	var records: Dictionary = garden_records(g)
	if str(records.tallest)==chosen: info.add_child(g._wrap("Garden champion · tallest plant!",12,WARM))
	if str(records.heaviest)==chosen: info.add_child(g._wrap("Garden champion · heaviest plant!",12,WARM))
	var data: Dictionary = g.state.plant_measurements(chosen)
	var measures := GridContainer.new()
	measures.columns = 1 if g.small_layout else 2
	measures.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(measures)
	_measurement(g,measures,"HEIGHT","%s cm" % _number(float(data.get("height_cm",0))),"height")
	_measurement(g,measures,"WEIGHT","%s g" % _number(float(data.get("weight_g",0))),"weight")
	var life_row := HBoxContainer.new()
	g.modal_content.add_child(life_row)
	_measurement(g,life_row,"LIFE LEFT · WHILE YOU PLAY",life_text(g,chosen),"life")
	var bonus_minutes: int = roundi(float(p.get("care",{}).get("life_bonus_seconds",0))/60.0)
	if bonus_minutes>0: g.modal_content.add_child(g._wrap("Care has added %d extra minutes to this plant's life." % bonus_minutes,13,WARM))
	g.modal_content.add_child(g._wrap("Pick a tool. Watch your plant change!",19,INK))
	g.modal_content.add_child(g._wrap("Every plant has its own natural size. Care makes this individual bigger or longer-lived; its seeds still inherit its DNA.",12,MUTED))
	if p.get("withered",false):
		g.modal_content.add_child(g._wrap("This plant has finished its life. Sow one of its seeds to keep the family growing.",14,WARM))
		g.modal_content.add_child(g._button("Plant its next generation",g._open_seeds))
	var grid := GridContainer.new()
	grid.columns = 1 if g.small_layout else 2
	grid.add_theme_constant_override("h_separation",12)
	grid.add_theme_constant_override("v_separation",12)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	g.modal_content.add_child(grid)
	for definition: Dictionary in TOOLS:
		var tool_key: String = str(definition.key)
		var status: Dictionary = g.state.care_status(chosen,tool_key)
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.set_meta("care_card",tool_key)
		panel.add_theme_stylebox_override("panel",g._style(Color(str(definition.color)),Color("a7bd83"),0,13,12))
		grid.add_child(panel)
		var body := VBoxContainer.new()
		body.add_theme_constant_override("separation",8)
		panel.add_child(body)
		var heading := HBoxContainer.new()
		body.add_child(heading)
		var icon := Icon.new()
		icon.tool = tool_key
		icon.custom_minimum_size = Vector2(48,48)
		heading.add_child(icon)
		var words := VBoxContainer.new()
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		heading.add_child(words)
		words.add_child(g._wrap(str(definition.name),18,INK))
		words.add_child(g._wrap(str(definition.tag),12,WARM))
		body.add_child(g._wrap(str(definition.description),12,MUTED))
		body.add_child(g._wrap(_benefit(tool_key,data,g.state.life_profile(chosen)),14,INK))
		var cost: int = int(status.get("cost",0))
		var use_button: Button = g._action_button("Use · free" if cost==0 else "Use · %d light" % cost,func(): g._apply_care(chosen,tool_key),"care_apply",chosen)
		use_button.set_meta("care_tool",tool_key)
		use_button.disabled = not status.get("allowed",false) or g.sim!=null
		use_button.tooltip_text = str(status.get("reason",""))
		use_button.custom_minimum_size.y = 44
		body.add_child(use_button)
		g.care_buttons.append(use_button)
		var note: Label = g._wrap(status_text(status),11,MUTED)
		note.set_meta("care_tool_note",tool_key)
		note.set_meta("care_plant_id",chosen)
		body.add_child(note)
		g.care_labels.append(note)
	g.modal_content.add_child(g._button("See its traits & plan a cross",func(): g._open_dna(chosen)))
