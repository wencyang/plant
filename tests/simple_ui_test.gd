extends SceneTree
## The garden balances a clear grow patch with useful collection and journey
## context. Extra systems stay reachable without changing DNA or supplies.
const Garden = preload("res://scripts/garden.gd")
const State = preload("res://scripts/garden_state.gd")
const DNA = preload("res://scripts/plant_dna.gd")
const Locale = preload("res://scripts/localization.gd")
const Cell = preload("res://scripts/plant_cell.gd")
var game: Control
var checks: int = 0
var failures: int = 0
var save_path: String

func _initialize() -> void:
	call_deferred("run")

func check(value: bool,message: String) -> void:
	checks+=1
	if not value:
		failures+=1
		push_error("SIMPLE UI: "+message)

func settle() -> void:
	for i in range(6): await process_frame

func stable_state() -> String:
	var organisms: Dictionary=game.state.plants.duplicate(true)
	for id: String in organisms: organisms[id].erase("life_age")
	return DNA.canonical([organisms,game.state.plant_order,game.state.bed,game.state.display_bed,game.state.seed_bank,game.state.fruit_inventory,game.state.pollinations,game.state.resources,game.state.market,game.state.adventure])

func find_action(node: Node,action: String) -> Button:
	if node is Button and str(node.get_meta("garden_action",""))==action: return node
	for child: Node in node.get_children():
		var found: Button=find_action(child,action)
		if found!=null: return found
	return null

func find_meta(node: Node,key: String,value: String) -> Node:
	if str(node.get_meta(key,""))==value: return node
	for child: Node in node.get_children():
		var found: Node=find_meta(child,key,value)
		if found!=null: return found
	return null

func visible_buttons(node: Node) -> Array[Button]:
	var result: Array[Button]=[]
	if node is Control and not node.is_visible_in_tree(): return result
	if node is Button: result.append(node)
	for child: Node in node.get_children(): result.append_array(visible_buttons(child))
	return result

func source_text(node: Node) -> String:
	if node is Control and not node.is_visible_in_tree(): return ""
	var result: String=str(node.get_meta("_locale_source_text",node.text)) if node is Label or node is Button else ""
	for child: Node in node.get_children(): result+="\n"+source_text(child)
	return result

func within(rect: Rect2,bounds: Rect2) -> bool:
	return rect.position.x>=bounds.position.x-2 and rect.position.y>=bounds.position.y-2 and rect.end.x<=bounds.end.x+2 and rect.end.y<=bounds.end.y+2

func overflow(node: Node,bounds: Rect2,result: Array[String]) -> void:
	if node is Control and node.is_visible_in_tree():
		var rect: Rect2=node.get_global_rect()
		if rect.position.x<bounds.position.x-2 or rect.end.x>bounds.end.x+2:
			result.append(node.get_class()+" "+str(rect))
		if node is ScrollContainer and node.horizontal_scroll_mode!=ScrollContainer.SCROLL_MODE_DISABLED: return
	for child: Node in node.get_children(): overflow(child,bounds,result)

func modal_bounds(context: String) -> void:
	check(is_instance_valid(game.modal),context+" opens a screen")
	if not is_instance_valid(game.modal): return
	var panel: Control=game.modal.get_node("Panel")
	check(within(panel.get_global_rect(),root.get_visible_rect()),context+" fits the viewport: "+str(panel.get_global_rect())+" inside "+str(root.get_visible_rect()))
	if not within(panel.get_global_rect(),root.get_visible_rect()):
		print("SIMPLE UI BOUNDS: ",context," panel minimum=",panel.get_combined_minimum_size()," scroll minimum=",game.modal_scroll.get_combined_minimum_size()," content minimum=",game.modal_content.get_combined_minimum_size()," scroll mode=",game.modal_scroll.vertical_scroll_mode)
	var issues: Array[String]=[]
	overflow(panel,panel.get_global_rect(),issues)
	check(issues.is_empty(),context+" fits horizontally: "+"; ".join(issues.slice(0,4)))

func press(action: String,context: String) -> bool:
	var button: Button=find_action(game.modal if is_instance_valid(game.modal) else game,action)
	check(button!=null,context+" exposes "+action)
	if button==null: return false
	check(button.is_visible_in_tree() and not button.disabled,context+" has an available "+action+" control")
	if not button.is_visible_in_tree() or button.disabled: return false
	button.pressed.emit()
	await settle()
	game._localize_ui()
	await settle()
	return true

func collection_cells(node: Node,zone: String,result: Array) -> void:
	if node.get_script()==Cell and str(node.zone)==zone: result.append(node)
	for child: Node in node.get_children(): collection_cells(child,zone,result)

func check_collection(context: String) -> void:
	var archive: Node=find_meta(game.modal,"collection_role","archive")
	var display: Node=find_meta(game.modal,"collection_role","display")
	check(archive!=null,context+" moves the archive into the collection screen")
	check(display!=null,context+" moves the shelf into the collection screen")
	if archive!=null:
		var cells: Array=[]
		collection_cells(archive,"tray",cells)
		var ids: Array=[]
		for cell: Control in cells:
			if not cell.plant.is_empty(): ids.append(str(cell.plant.id))
		check(ids.size()==game.state.plant_order.size(),context+" includes every archived plant")
		for id: String in game.state.plant_order: check(ids.has(id),context+" includes archive individual "+id)
	if display!=null:
		var slots: Array=[]
		collection_cells(display,"display",slots)
		check(slots.size()==6,context+" keeps all six interactive display slots")

func restore_home() -> void:
	game._close_modal()
	if game.exploring: game._return_from_wilderness()
	if game.adventuring: game._return_from_adventure()
	game.selected_id=""
	game.moving=false
	game._refresh()
	await settle()

func view(language: String,dimensions: Vector2i) -> void:
	Locale.set_language(language)
	root.size=dimensions
	root.content_scale_factor=1
	await settle()
	game._responsive()
	game._localize_ui()
	await settle()
	var context: String=language+" "+str(dimensions)
	check(visible_buttons(game.footer_row).size()==3,context+" offers exactly three main choices")
	check(game.plant_button.is_visible_in_tree() and game.breeding_button.is_visible_in_tree() and game.adventure_entry.is_visible_in_tree(),context+" main choices are planting, breeding and adventure")
	if dimensions.x>=900:
		check(game.display_grid.is_visible_in_tree() and game.display_heading.is_visible_in_tree(),context+" the desktop keeps a compact display shelf")
		check(game.sidebar.is_visible_in_tree(),context+" the desktop shows the current goal and journey context")
		check(find_meta(game.sidebar,"garden_role","party_preview")!=null,context+" the current travelling party has a home summary")
	else:
		check(not game.display_grid.is_visible_in_tree() and not game.display_heading.is_visible_in_tree(),context+" the phone keeps the full shelf in collection")
		check(not game.sidebar.is_visible_in_tree(),context+" the phone gives its width to the grow patch")
		var quick: Control=find_meta(game,"garden_role","quick_actions") as Control
		check(quick!=null and quick.is_visible_in_tree(),context+" the phone keeps useful shortcuts above the garden")
		if quick!=null:
			check(visible_buttons(quick).size()==3,context+" the phone shortcut strip stays concise")
			for action: String in ["harvest","party","bag"]:
				var button: Button=find_action(quick,action)
				check(button!=null and button.is_visible_in_tree(),context+" opens "+action+" without the More menu")
	check(not game.tray_panel.is_visible_in_tree(),context+" the full archive stays in its collection screen")
	check(within(game.root_column.get_global_rect(),root.get_visible_rect()),context+" home fits the viewport")
	check(within(game.footer_row.get_global_rect(),root.get_visible_rect()),context+" all three main actions fit the viewport")
	var original: String=stable_state()
	for key: String in ["harvest","tools","market","wilds","fair","collection","rewards","guide","settings"]:
		if not await press("more",context+" More menu"): break
		modal_bounds(context+" More menu")
		if not await press(key,context+" More menu"): break
		if key=="wilds":
			check(game.exploring and is_instance_valid(game.wilderness),context+" wild collecting remains reachable")
			if is_instance_valid(game.wilderness): check(within(game.wilderness.get_global_rect(),root.get_visible_rect()),context+" wilderness fits the viewport")
		else:
			modal_bounds(context+" "+key)
			if key=="collection": check_collection(context)
		check(stable_state()==original,context+" opening "+key+" preserves owned plants, DNA, seeds and supplies")
		await restore_home()
	var id: String=str(game.state.bed[6])
	check(not id.is_empty(),context+" fixture includes a planted specimen")
	game._choose_plant(id,"bed",6)
	await settle()
	game._localize_ui()
	modal_bounds(context+" tapped plant")
	var text: String=source_text(game.modal)
	check(not text.contains("THE EXPRESSED GENOME") and not text.contains("VITAL SIGNS") and not text.contains("Vitality"),context+" the first plant card hides raw genetics and combat-era stat text")
	var details: Button=find_action(game.modal,"plant_details")
	check(details!=null,context+" advanced traits remain available on demand")
	if details!=null:
		details.pressed.emit()
		await settle()
		modal_bounds(context+" requested plant details")
		check(game.modal_kind!="specimen",context+" requesting details opens the full trait view")
	check(stable_state()==original,context+" inspecting plants never changes their saved genome or inventory")
	await restore_home()
	game.breeding_button.pressed.emit()
	await settle()
	game._localize_ui()
	modal_bounds(context+" choose parents")
	check(is_instance_valid(game.lab_pick_a) and is_instance_valid(game.lab_pick_b),context+" crossing still offers two real parent selectors")
	if is_instance_valid(game.lab_pick_a) and is_instance_valid(game.lab_pick_b):
		var first: Rect2=game.lab_pick_a.get_global_rect()
		var second: Rect2=game.lab_pick_b.get_global_rect()
		check(absf(first.position.y-second.position.y)<2 and first.end.x<=second.position.x+2,context+" both parents stay visible side by side")
		var panel: Control=game.modal.get_node("Panel")
		check(within(first,panel.get_global_rect()) and within(second,panel.get_global_rect()),context+" both parent selectors fit without scrolling")
	var primary: Button=find_meta(game.modal,"reproduction_action","pollinate") as Button
	check(primary!=null and primary.is_visible_in_tree() and not primary.disabled,context+" one crossing action is immediately available")
	if primary!=null: check(within(primary.get_global_rect(),game.modal.get_node("Panel").get_global_rect()),context+" the crossing action stays visible")
	var preview: Button=find_meta(game.modal,"reproduction_action","dna_compare") as Button
	check(preview!=null and not preview.is_visible_in_tree(),context+" inherited-trait analysis waits behind More breeding options")
	check(not source_text(game.modal).contains("RECOMBINATION"),context+" crossing starts with parents instead of a genetics lecture")
	if await press("breeding_options",context+" optional breeding details"):
		preview=find_meta(game.modal,"reproduction_action","dna_compare") as Button
		check(preview!=null and preview.is_visible_in_tree(),context+" opening breeding options restores the DNA preview")
		modal_bounds(context+" expanded breeding options")
	check(stable_state()==original,context+" choosing and inspecting parents does not create or reroll offspring")
	await restore_home()

func run() -> void:
	root.size=Vector2i(1440,1000)
	Locale.set_language("en")
	save_path="/tmp/conservatory_simple_ui_%d.json" % Time.get_ticks_usec()
	game=Garden.new()
	game.state=State.new(save_path)
	root.add_child(game)
	game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await settle()
	game.display_settings.enabled=false
	game.set_process(false)
	check(game.soundscape.preview_muted,"Acceptance checks run with silent disposable gardens")
	for config: Array in [["en",Vector2i(1440,1000)],["zh_CN",Vector2i(1440,1000)],["en",Vector2i(390,780)],["zh_CN",Vector2i(390,780)]]:
		await view(str(config[0]),config[1])
	game.queue_free()
	await process_frame
	for suffix: String in [".json",".backup.json",".audio.cfg",".display.cfg"]: DirAccess.remove_absolute(save_path.get_basename()+suffix)
	Locale.set_language("en")
	print("SIMPLE UI TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
