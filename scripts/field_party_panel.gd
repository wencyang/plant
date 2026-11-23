extends RefCounted
## The six travelling specimens are the same individuals held in the archive.
const Portrait=preload("res://scripts/plant_portrait.gd")
const Locale=preload("res://scripts/localization.gd")
const INK:=Color("284838")
const MUTED:=Color("617957")
const WARM:=Color("a4542b")

static func button(g: Control,label: String,callback: Callable,action: String,parent_node: Node,meta: Dictionary={}) -> Button:
	var result: Button=g._button(label,callback)
	result.custom_minimum_size.y=38
	result.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	result.clip_text=true
	result.set_meta("party_action",action)
	for key: String in meta: result.set_meta(key,meta[key])
	parent_node.add_child(result)
	return result

static func _body(g: Control,parent_node: Node,highlight: bool=false) -> VBoxContainer:
	var panel:=PanelContainer.new()
	panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel",g._style(Color("fff0bc") if highlight else Color("edf0d4"),Color("c4964e") if highlight else Color("9aae7d"),0,6 if g.small_layout else 8,6 if g.small_layout else 8))
	parent_node.add_child(panel)
	var column:=VBoxContainer.new()
	column.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation",5)
	panel.add_child(column)
	return column

static func _portrait(parent_node: Node,p: Dictionary,height: float) -> Control:
	var portrait:=Portrait.new()
	portrait.plant=p
	portrait.custom_minimum_size=Vector2(0,height)
	portrait.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	parent_node.add_child(portrait)
	return portrait

static func _living(g: Control) -> Array[String]:
	var result: Array[String]=[]
	for id: String in g.state.plant_order:
		var p: Dictionary=g.state.get_plant(id)
		if g.state.owns_plant(id) and not bool(p.get("retired",false)) and not bool(g.state.life_profile(id).withered): result.append(id)
	return result

static func show(g: Control,selected: String="") -> void:
	var party: Array[Dictionary]=g.state.travel_party()
	var ids: Array[String]=[]
	for p: Dictionary in party: ids.append(str(p.id))
	var can_add: bool=_living(g).size()>party.size()
	if not ids.has(selected): selected=ids[0] if not ids.is_empty() else ""
	g._open_modal("Travel party","field_party")
	g.modal.set_meta("party_selected",selected)
	g.modal_content.add_theme_constant_override("separation",10)
	g.modal_content.add_child(g._wrap("Your lead plant travels beside you. Bring up to six companions.",12 if g.small_layout else 14,MUTED))
	var grid:=GridContainer.new()
	grid.columns=2 if g.small_layout else 3
	grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation",8)
	grid.add_theme_constant_override("v_separation",8)
	grid.set_meta("party_slots",true)
	g.modal_content.add_child(grid)
	for slot: int in range(6):
		var body:=_body(g,grid,slot<party.size() and str(party[slot].id)==selected)
		body.set_meta("party_slot",slot)
		if slot>=party.size():
			var spacer:=Control.new()
			spacer.custom_minimum_size=Vector2(0,44 if g.small_layout else 78)
			body.add_child(spacer)
			button(g,"+ Add plant",func(): choose(g,slot),"change",body,{"party_slot":slot}).disabled=slot>party.size() or not can_add
			continue
		var p: Dictionary=party[slot]
		var id: String=str(p.id)
		var portrait: Control=_portrait(body,p,44 if g.small_layout else 78)
		portrait.set_meta("party_plant",id)
		var pick:=button(g,str(p.name),func(): g._show_party(id),"select",body,{"plant_id":id,"party_slot":slot})
		pick.custom_minimum_size.y=28 if g.small_layout else 31
		if g.small_layout:
			pick.add_theme_font_size_override("font_size",12)
			for mode: String in ["normal","hover","pressed"]:
				pick.add_theme_stylebox_override(mode,g._style(Color("e8efb7"),Color("8ca96a"),0,5,3))
		var caption: Label=g._wrap("Lead companion" if slot==0 else "%s · G%d" % [p.type,int(p.generation)],11 if g.small_layout else 12,WARM if slot==0 else MUTED)
		caption.max_lines_visible=1
		caption.clip_text=true
		caption.custom_minimum_size.y=18 if g.small_layout else 20
		body.add_child(caption)
	if not selected.is_empty():
		var p: Dictionary=g.state.get_plant(selected)
		var measurements: Dictionary=g.state.plant_measurements(selected)
		var life: Dictionary=g.state.life_profile(selected)
		# Context controls stay visible while the six slots scroll independently.
		var detail:=_body(g,g.modal.get_node("Panel").get_child(0))
		detail.set_meta("party_actions",true)
		detail.add_child(g._wrap(str(p.name)+" · %s · G%d" % [p.type,int(p.generation)],16 if g.small_layout else 18,INK))
		detail.add_child(g._wrap("%.1f cm · %.1f g" % [float(measurements.height_cm),float(measurements.weight_g)],13,MUTED))
		var life_row:=HBoxContainer.new()
		detail.add_child(life_row)
		life_row.add_child(g._label("Life",12,MUTED))
		var meter:=ProgressBar.new()
		meter.value=(1.0-float(life.progress))*100.0
		var track:=StyleBoxFlat.new()
		track.bg_color=Color("dce4ce")
		track.border_color=Color("a7b890")
		track.set_border_width_all(1)
		track.set_corner_radius_all(3)
		var fill:=StyleBoxFlat.new()
		fill.bg_color=Color("78ae67")
		fill.border_color=Color("59844d")
		fill.set_border_width_all(1)
		fill.set_corner_radius_all(3)
		meter.add_theme_stylebox_override("background",track)
		meter.add_theme_stylebox_override("fill",fill)
		meter.show_percentage=false
		meter.custom_minimum_size=Vector2(70,12)
		meter.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		meter.tooltip_text="%d minutes of active life remain" % ceili(float(life.remaining)/60.0)
		life_row.add_child(meter)
		var actions:=HBoxContainer.new()
		actions.add_theme_constant_override("separation",6)
		detail.add_child(actions)
		button(g,"DNA",func(): g._open_dna(selected),"dna",actions,{"plant_id":selected})
		button(g,"Care",func(): g._open_field_bag(selected),"care",actions,{"plant_id":selected})
		button(g,"Cross",func(): g._breed_from(selected),"cross",actions,{"plant_id":selected}).disabled=not bool(p.mature)
		var controls:=HBoxContainer.new()
		controls.add_theme_constant_override("separation",6)
		detail.add_child(controls)
		button(g,"Leading the way" if ids[0]==selected else "Choose as lead",func(): g._set_party_lead(selected),"lead",controls,{"plant_id":selected}).disabled=ids[0]==selected
		button(g,"Change member",func(): choose(g,ids.find(selected)),"change",controls,{"plant_id":selected,"party_slot":ids.find(selected)})
	else:
		g.modal_content.add_child(g._wrap("Your garden plants can join you here.",16,INK))
	Locale.apply_tree(g.modal)

static func choose(g: Control,slot: int) -> void:
	var ids: Array[String]=_living(g)
	var party: Array[Dictionary]=g.state.travel_party()
	if slot>=party.size():
		var existing: Array[String]=[]
		for p: Dictionary in party: existing.append(str(p.id))
		var available: Array[String]=[]
		for id: String in ids:
			if not existing.has(id): available.append(id)
		ids=available
	g._open_modal("Choose a companion","field_party_choose")
	g.modal.set_meta("party_slot",slot)
	if ids.is_empty():
		g.modal_content.add_child(g._wrap("Every living plant is already in your party." if not party.is_empty() else "Grow or collect a living plant to bring it along.",18,INK))
		return
	var chosen: String=str(party[slot].id) if slot<party.size() else ids[0]
	var portrait:=_portrait(g.modal_content,g.state.get_plant(chosen),170 if g.small_layout else 220)
	var picker:=OptionButton.new()
	picker.set_meta("party_action","member_picker")
	picker.custom_minimum_size=Vector2(0,42)
	picker.fit_to_longest_item=false
	picker.clip_text=true
	picker.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	for id: String in ids:
		var p: Dictionary=g.state.get_plant(id)
		picker.add_item("%s · %s · G%d" % [p.name,p.type,int(p.generation)])
		picker.set_item_metadata(picker.item_count-1,id)
		if id==chosen: picker.select(picker.item_count-1)
	g.modal_content.add_child(picker)
	var confirm:=button(g,"Bring this plant",func(): g._swap_party_member(slot,str(picker.get_item_metadata(picker.selected))),"confirm",g.modal_content,{"plant_id":chosen,"party_slot":slot})
	picker.item_selected.connect(func(index: int):
		var id: String=str(picker.get_item_metadata(index))
		portrait.plant=g.state.get_plant(id)
		portrait.queue_redraw()
		confirm.set_meta("plant_id",id))
	Locale.apply_tree(g.modal)
