extends SceneTree
## The journey keeps a real six-plant party and its companion on the field.
## Menus remain available without moving the player or changing the collection.
const Garden=preload("res://scripts/garden.gd")
const State=preload("res://scripts/garden_state.gd")
const DNA=preload("res://scripts/plant_dna.gd")
const Locale=preload("res://scripts/localization.gd")
const Habitat=preload("res://scripts/habitat_catalog.gd")
var game: Control
var checks: int=0
var failures: int=0
var save_path: String

func _initialize() -> void:
	call_deferred("run")

func check(value: bool,message: String) -> void:
	checks+=1
	if not value:
		failures+=1
		push_error("FIELD ADVENTURE UI: "+message)

func settle() -> void:
	for i in range(7): await process_frame

func find_meta(node: Node,key: String,value: Variant) -> Node:
	if node.has_meta(key) and node.get_meta(key)==value: return node
	for child: Node in node.get_children():
		var found: Node=find_meta(child,key,value)
		if found!=null: return found
	return null

func find_party_action(node: Node,action: String,id: String="") -> Button:
	if node is Button and str(node.get_meta("party_action",""))==action and (id.is_empty() or str(node.get_meta("plant_id",""))==id): return node
	for child: Node in node.get_children():
		var found: Button=find_party_action(child,action,id)
		if found!=null: return found
	return null

func stable_collection() -> String:
	var organisms: Dictionary=game.state.plants.duplicate(true)
	for id: String in organisms: organisms[id].erase("life_age")
	return DNA.canonical([organisms,game.state.plant_order,game.state.bed,game.state.display_bed,game.state.resources,game.state.seed_bank,game.state.fruit_inventory,game.state.pollinations,game.state.market,game.state.adventure])

func party_ids(state: RefCounted) -> Array[String]:
	var result: Array[String]=[]
	for p: Dictionary in state.travel_party(): result.append(str(p.id))
	return result

func within(rect: Rect2,bounds: Rect2) -> bool:
	return rect.position.x>=bounds.position.x-2 and rect.position.y>=bounds.position.y-2 and rect.end.x<=bounds.end.x+2 and rect.end.y<=bounds.end.y+2

func overflow(node: Node,bounds: Rect2,result: Array[String]) -> void:
	if node is Control and node.is_visible_in_tree():
		var rect: Rect2=node.get_global_rect()
		if rect.position.x<bounds.position.x-2 or rect.end.x>bounds.end.x+2: result.append(node.get_class()+" "+str(rect))
		if node is ScrollContainer and node.horizontal_scroll_mode!=ScrollContainer.SCROLL_MODE_DISABLED: return
	for child: Node in node.get_children(): overflow(child,bounds,result)

func check_modal(context: String) -> void:
	check(is_instance_valid(game.modal),context+" opens a real menu")
	if not is_instance_valid(game.modal): return
	var panel: Control=game.modal.get_node("Panel")
	check(within(panel.get_global_rect(),root.get_visible_rect()),context+" menu fits the viewport: "+str(panel.get_global_rect()))
	var issues: Array[String]=[]
	overflow(panel,panel.get_global_rect(),issues)
	check(issues.is_empty(),context+" menu has no horizontal overflow: "+"; ".join(issues.slice(0,4)))
	check(game.adventuring and game.adventure_field.waiting,context+" keeps the field open and pauses walking")
	var before: Vector2=game.adventure_field.player_position
	game.adventure_field.walk_to(before+Vector2(50,0))
	game.adventure_field._process(0.1)
	check(game.adventure_field.player_position==before,context+" prevents movement behind the menu")

func check_companion(context: String) -> void:
	var members: Array[String]=party_ids(game.state)
	check(not members.is_empty(),context+" has an actual travelling plant")
	var companion: Control=find_meta(game.adventure_field,"adventure_companion",true) as Control
	check(companion!=null and companion.is_visible_in_tree(),context+" shows a companion on the map")
	if members.is_empty() or companion==null: return
	check(str(companion.get_meta("plant_id",""))==members[0],context+" companion is the current party leader")
	var lead: Dictionary=game.state.get_plant(members[0])
	check(DNA.profile(companion.plant).code==DNA.profile(lead).code,context+" companion displays that individual's inherited DNA")
	check(companion.plant.stats==lead.stats and companion.plant.parents==lead.parents,context+" companion keeps real measurements and ancestry")

func check_party_layout(context: String) -> void:
	if not is_instance_valid(game.modal): return
	var actions: Control=find_meta(game.modal,"party_actions",true) as Control
	check(actions!=null and actions.is_visible_in_tree(),context+" keeps the selected companion's controls visible")
	if actions!=null:
		check(not game.modal_scroll.is_ancestor_of(actions),context+" companion actions stay outside the scrolling party list")
		check(within(actions.get_global_rect(),root.get_visible_rect()),context+" the full companion action area fits the viewport")
		for key: String in ["lead","change"]:
			var button: Button=find_party_action(actions,key)
			check(button!=null and button.is_visible_in_tree(),context+" keeps "+key+" available without scrolling")
			if button!=null: check(within(button.get_global_rect(),root.get_visible_rect()),context+" the "+key+" control is fully inside the viewport")
	if root.size.x<700:
		for slot: int in range(6):
			var body: Control=find_meta(game.modal,"party_slot",slot) as Control
			check(body!=null and body.is_visible_in_tree(),context+" shows party slot "+str(slot+1))
			if body==null: continue
			var portfolio: Control=body.get_parent() as Control
			check(portfolio!=null and within(portfolio.get_global_rect(),game.modal_scroll.get_global_rect()),context+" slot "+str(slot+1)+" fits inside the list without scrolling")

func view(language: String,dimensions: Vector2i) -> void:
	Locale.set_language(language)
	root.size=dimensions
	root.content_scale_factor=1
	await settle()
	game._responsive()
	game.adventure_field.refresh()
	game._localize_ui()
	await settle()
	var context: String=language+" "+str(dimensions)
	var field: Control=game.adventure_field
	check(within(field.get_global_rect(),root.get_visible_rect()),context+" field fits the screen")
	if dimensions.x<700: check(field._map_rect.size.y>=dimensions.y*0.50,context+" the map gets at least half the phone screen")
	check_companion(context)
	var original: String=stable_collection()
	var original_party: Array[String]=party_ids(game.state)
	for action: String in ["party","dex","bag","wilds"]:
		var button: Button=find_meta(field,"adventure_action",action) as Button
		check(button!=null and button.is_visible_in_tree(),context+" keeps "+action+" one tap away")
		if button==null: continue
		check(within(button.get_global_rect(),root.get_visible_rect()),context+" "+action+" control fits the screen")
		var source: String=str(button.get_meta("_locale_source_text",button.text))
		check(button.text==Locale.text(source),context+" "+action+" control follows the selected language")
		button.pressed.emit()
		await settle()
		game._localize_ui()
		check_modal(context+" "+action)
		if action=="party" and is_instance_valid(game.modal):
			check_party_layout(context)
			var slots: Control=find_meta(game.modal,"party_slots",true) as Control
			check(slots!=null and slots.get_child_count()==6,context+" the party screen keeps six explicit companion slots")
			for id: String in original_party:
				check(find_meta(game.modal,"party_plant",id)!=null,context+" the party screen depicts its actual member "+id)
		elif action=="bag" and is_instance_valid(game.modal):
			var summary: Label=find_meta(game.modal,"bag_role","summary") as Label
			check(summary!=null and summary.text==Locale.text("Light %d · Coins %d · Field kits %d" % [game.state.resources.sunlight,game.state.market_wallet(),game.state.field_kits]),context+" the bag reports the actual light, coins and field kits")
			var seeds: Button=find_meta(game.modal,"field_menu_action","seeds") as Button
			check(seeds!=null and seeds.text==Locale.text("Seeds %d" % game.state.seed_bank.size()),context+" the seed pocket reports the real seed bank")
		elif action=="dex" and is_instance_valid(game.modal):
			for family: String in ["Leaf","Bloom","Vine","Root","Spore","Toxin","Parasite","Carnivorous"]:
				var card: Control=find_meta(game.modal,"field_dex_family",family) as Control
				check(card!=null,context+" the guide includes the "+family+" family")
				if card==null: continue
				var count: int=0
				for p: Dictionary in game.state.plants.values():
					if str(p.type)==family: count+=1
				var entry: Button=find_meta(card,"field_menu_action","family") as Button
				check(entry!=null and entry.text==Locale.text("%s · %d" % [family,count]),context+" the guide derives "+family+" discoveries from the real archive")
		elif action=="wilds" and is_instance_valid(game.modal):
			for biome: String in Habitat.REGIONS:
				check(find_meta(game.modal,"biome",biome)!=null,context+" routes include a real "+biome+" trail")
		check(stable_collection()==original and party_ids(game.state)==original_party,context+" browsing "+action+" leaves plants, DNA, party and supplies unchanged")
		game._close_modal()
		await settle()
		check(not field.waiting and field.is_visible_in_tree(),context+" closing "+action+" returns to the field")
	var before: Vector2=field.player_position
	field.walk_to(Vector2(320,435))
	for i in range(8): field._process(0.05)
	check(not field.player_position.is_equal_approx(before),context+" walking works after closing menus")
	field.player_position=Vector2(255,435)
	field.refresh()

func lead_persistence() -> void:
	var before: String=stable_collection()
	var ids: Array[String]=party_ids(game.state)
	check(ids.size()==6,"The active party contains six owned plants")
	if ids.size()<4: return
	var chosen: String=ids[3]
	game._show_party(chosen)
	await settle()
	check_party_layout("Choosing a leader")
	var lead: Button=find_party_action(game.modal,"lead",chosen)
	check(lead!=null and not lead.disabled,"A party member can be chosen to walk beside the player")
	if lead==null or lead.disabled: return
	lead.pressed.emit()
	await settle()
	check(party_ids(game.state)[0]==chosen,"The real party control promotes the chosen individual")
	check(stable_collection()==before,"Changing the leader never changes DNA, beds or supplies")
	var restored=State.new(save_path)
	check(restored.load_game(),"The party choice saves through the ordinary archive")
	check(party_ids(restored)==party_ids(game.state),"The complete ordered travelling party survives reload")
	game._close_modal()
	game.adventure_field.refresh()
	await settle()
	check_companion("After choosing a leader")
	var replaced: String=party_ids(game.state)[2]
	var spare: String=str(game.state.plant_order[6])
	game._show_party(replaced)
	await settle()
	var change: Button=find_party_action(game.modal,"change",replaced)
	check(change!=null,"An existing party slot can choose a different companion")
	if change==null: return
	change.pressed.emit()
	await settle()
	var picker: OptionButton=find_party_action(game.modal,"member_picker") as OptionButton
	check(picker!=null,"Changing a member uses actual owned-plant choices")
	if picker==null: return
	var found: bool=false
	for index: int in range(picker.item_count):
		if str(picker.get_item_metadata(index))!=spare: continue
		picker.select(index)
		picker.item_selected.emit(index)
		found=true
		break
	check(found,"A plant outside the current six can join the party")
	var confirm: Button=find_party_action(game.modal,"confirm",spare)
	check(confirm!=null and not confirm.disabled,"The member selection can be confirmed")
	if confirm==null or confirm.disabled: return
	confirm.pressed.emit()
	await settle()
	var next: Array[String]=party_ids(game.state)
	check(next.size()==6 and next[2]==spare and not next.has(replaced),"Changing a member replaces only the chosen slot in the six-plant party")
	check(stable_collection()==before,"Replacing a party member keeps both plants, their DNA and garden positions")
	restored=State.new(save_path)
	check(restored.load_game() and party_ids(restored)==next,"The changed companion and exact party order survive reload")
	game._close_modal()
	await settle()

func use_bag_tool() -> void:
	var id: String=str(game.state.plant_order[1])
	game._open_field_bag()
	await settle()
	var picker: OptionButton=find_meta(game.modal,"field_menu_action","bag_target") as OptionButton
	check(picker!=null,"The bag allows tools to target a real individual")
	if picker==null: return
	var found: bool=false
	for index: int in range(picker.item_count):
		if str(picker.get_item_metadata(index))!=id: continue
		picker.select(index)
		picker.item_selected.emit(index)
		found=true
		break
	check(found,"The bag offers the intended owned plant through canonical selector metadata")
	await settle()
	var water: Button=find_meta(game.modal,"tool_key","water") as Button
	check(water!=null and not water.disabled and str(water.get_meta("plant_id",""))==id,"Watering applies to the selected plant")
	if water==null or water.disabled: return
	var p: Dictionary=game.state.get_plant(id)
	var bonus: int=int(p.care.get("life_bonus_seconds",0))
	var uses: int=int(p.care.get("uses",{}).get("water",0))
	var genome: String=DNA.profile(p).code
	var light: int=int(game.state.resources.sunlight)
	water.pressed.emit()
	await settle()
	p=game.state.get_plant(id)
	check(int(p.care.get("life_bonus_seconds",0))==bonus+60 and int(p.care.get("uses",{}).get("water",0))==uses+1,"The bag's actual watering control adds one minute and records its normal use")
	check(int(game.state.resources.sunlight)==light and DNA.profile(p).code==genome,"Free watering keeps the chosen plant's DNA and supplies")
	check(game.adventure_field.waiting,"Using a tool keeps field movement paused")
	game._close_modal()
	await settle()
	check(not game.adventure_field.waiting,"Closing the bag after care returns control to the player")

func follow_route() -> void:
	var before: String=stable_collection()
	game._open_field_routes()
	await settle()
	var trail: Button=find_meta(game.modal,"biome","Mosswood") as Button
	check(trail!=null and not trail.disabled,"The regional route card offers an actual forest trail")
	if trail==null or trail.disabled: return
	trail.pressed.emit()
	await settle()
	check(game.exploring and not game.adventuring and is_instance_valid(game.wilderness),"Following a region enters the large wild exploration map")
	if is_instance_valid(game.wilderness):
		check(game.wilderness.is_visible_in_tree(),"The chosen wild landscape is playable after following its route")
		game.wilderness.set_process(false)
	check(stable_collection()==before,"Choosing a trail leaves owned specimens, DNA, seeds and supplies intact")
	for config: Array in [["en",Vector2i(1440,1000)],["zh_CN",Vector2i(1440,1000)],["en",Vector2i(390,780)],["zh_CN",Vector2i(390,780)]]:
		await wild_view(str(config[0]),config[1])
	await captured_companion()
	var stream: Button=find_meta(game.wilderness,"field_action","stream") as Button
	check(stream!=null and stream.is_visible_in_tree(),"The wild field keeps the stream journey directly reachable")
	if stream!=null: stream.pressed.emit()
	await settle()
	check(game.adventuring and not game.exploring,"The stream journey remains reachable after a wild trip")

func wild_view(language: String,dimensions: Vector2i) -> void:
	Locale.set_language(language)
	root.size=dimensions
	await settle()
	game._responsive()
	game.wilderness.refresh()
	game._localize_ui()
	await settle()
	# The live wild field fits its HUD every frame. Run those layout frames with
	# walking paused because the acceptance fixture disables its automatic loop.
	var paused: bool=game.wilderness.waiting
	game.wilderness.waiting=true
	for i in range(3):
		game.wilderness._process(0.0)
		await process_frame
	game.wilderness.waiting=paused
	var context: String="Wild "+language+" "+str(dimensions)
	var wild: Control=game.wilderness
	check(within(wild.get_global_rect(),root.get_visible_rect()),context+" remains in the viewport")
	var companion: Control=find_meta(wild,"wild_companion",true) as Control
	var lead: String=party_ids(game.state)[0]
	check(companion!=null and companion.is_visible_in_tree(),context+" brings the lead companion into the wider wilds")
	if companion!=null:
		check(str(companion.get_meta("plant_id",""))==lead and DNA.profile(companion.plant).code==DNA.profile(game.state.get_plant(lead)).code,context+" the wild companion is the same inherited individual")
	var original: String=stable_collection()
	for action: String in ["party","dex","bag"]:
		var button: Button=find_meta(wild,"field_action",action) as Button
		check(button!=null and button.is_visible_in_tree(),context+" exposes "+action+" without returning home")
		if button==null: continue
		check(within(button.get_global_rect(),root.get_visible_rect()),context+" the "+action+" button fits")
		button.pressed.emit()
		await settle()
		check(is_instance_valid(game.modal) and game.exploring and wild.waiting,context+" "+action+" pauses the active wild map")
		if is_instance_valid(game.modal):
			var panel: Control=game.modal.get_node("Panel")
			check(within(panel.get_global_rect(),root.get_visible_rect()),context+" "+action+" menu stays in the viewport")
			var issues: Array[String]=[]
			overflow(panel,panel.get_global_rect(),issues)
			check(issues.is_empty(),context+" "+action+" menu fits horizontally")
		var tile: Vector2i=wild.player_tile
		check(not wild._try_step(Vector2i.RIGHT) and wild.player_tile==tile,context+" walking cannot continue behind "+action)
		check(stable_collection()==original,context+" browsing "+action+" leaves the real collection unchanged")
		game._close_modal()
		await settle()
		check(not wild.waiting and wild.is_visible_in_tree(),context+" closing "+action+" resumes the journey")
	var previous: Vector2i=wild.player_tile
	var moved: bool=false
	for direction: Vector2i in [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]:
		if not wild.is_walkable(previous+direction): continue
		moved=wild._try_step(direction)
		break
	check(moved and wild.player_tile!=previous,context+" a legal step works after the menus close")
	check(wild._companion_tile==previous and wild.is_walkable(wild._companion_tile),context+" the companion follows the player's previous legal tile")
	await bag_pockets(context)

func bag_pockets(context: String) -> void:
	var in_wilds: bool=game.exploring
	var field: Control=game.wilderness if in_wilds else game.adventure_field
	var position: Variant=field.player_tile if in_wilds else field.player_position
	var original: String=stable_collection()
	for pocket: String in ["seeds","fruits"]:
		game._open_field_bag()
		await settle()
		var open: Button=find_meta(game.modal,"field_menu_action",pocket) as Button
		check(open!=null,context+" the bag's "+pocket+" pocket can open")
		if open==null: continue
		open.pressed.emit()
		await settle()
		check(is_instance_valid(game.modal) and game.modal_kind=="seeds" and game.nursery_tab==pocket,context+" the "+pocket+" pocket opens the actual inventory tab")
		check(game.exploring==in_wilds and game.adventuring!=in_wilds and not game.ui_margin.visible,context+" opening "+pocket+" keeps the current field active")
		check(field.waiting and (field.player_tile if in_wilds else field.player_position)==position,context+" inventory browsing pauses at the same map position")
		var back: Button=find_meta(game.modal,"field_menu_action","back_to_bag") as Button
		check(back!=null and back.is_visible_in_tree(),context+" the inventory offers a direct Back to bag action")
		if back!=null:
			check(within(back.get_global_rect(),root.get_visible_rect()),context+" Back to bag stays visible")
			back.pressed.emit()
			await settle()
			check(game.modal_kind=="field_bag" and field.waiting,context+" Back to bag keeps the same paused journey")
		check(stable_collection()==original,context+" browsing "+pocket+" never plants, harvests or changes inventory")
		game._close_modal()
		await settle()
		check(not field.waiting and (field.player_tile if in_wilds else field.player_position)==position,context+" closing the nested bag returns control at the same position")

func captured_companion() -> void:
	var order: Array=game.state.plant_order.duplicate()
	var bed: Array=game.state.bed.duplicate()
	var captured: String=""
	var expected: Dictionary={}
	# Use normal observed collection attempts at real mapped patches. A failed
	# cutting keeps its outcome; a withdrawn specimen is left alone.
	for site: Dictionary in game.wilderness.SITES:
		if not captured.is_empty(): break
		game._leave_wild()
		game.wilderness.teleport_to_site(str(site.id))
		game.wilderness.interact()
		await settle()
		if game.modal_kind!="wild_encounter": continue
		game._wild_action("observe")
		await settle()
		for attempt: int in range(3):
			if game.state.expedition.active_encounter.is_empty(): break
			if game.state.field_kits==0: game.state.restock_field_kits()
			expected=game.state.expedition.active_encounter.plant.duplicate(true)
			game._wild_action("gather")
			await settle()
			if game.modal_kind=="wild_capture":
				captured=str(game.state.plant_order.back())
				break
	check(not captured.is_empty(),"A normal wild collection reaches the new companion reveal")
	if captured.is_empty(): return
	var p: Dictionary=game.state.get_plant(captured)
	check(p.genes==expected.genes and p.stats==expected.stats and p.seed==expected.seed,"The captured companion retains the exact observed wild individual")
	check(game.state.plant_order.size()==order.size()+1 and game.state.bed==bed,"Wild collection adds one plant without rearranging the garden")
	var lead: Button=find_party_action(game.modal,"lead",captured)
	check(lead!=null and lead.is_visible_in_tree() and not lead.disabled,"A collected plant can immediately travel with the player")
	if lead==null or lead.disabled: return
	check(within(lead.get_global_rect(),root.get_visible_rect()),"Travel with this plant stays visible on the phone capture reveal")
	lead.pressed.emit()
	await settle()
	check(party_ids(game.state)[0]==captured and game.exploring,"Travel with this plant promotes that exact capture without leaving the wilds")
	var restored=State.new(save_path)
	check(restored.load_game() and party_ids(restored)[0]==captured,"The captured lead companion persists in the ordinary saved party")
	game.wilderness._process(0.0)
	var companion: Control=find_meta(game.wilderness,"wild_companion",true) as Control
	check(companion!=null and str(companion.get_meta("plant_id",""))==captured and companion.plant.genes==expected.genes,"The new captured leader actually appears beside the wild explorer")
	game._close_modal()
	await settle()
	check(not game.wilderness.waiting,"Closing the captured plant's party restores field control")

func run() -> void:
	Locale.set_language("en")
	root.size=Vector2i(1440,1000)
	save_path="/tmp/conservatory_field_ui_%d.json" % Time.get_ticks_usec()
	game=Garden.new()
	game.state=State.new(save_path)
	root.add_child(game)
	game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await settle()
	game.display_settings.enabled=false
	game.set_process(false)
	check(game.soundscape.preview_muted,"Field checks use silent disposable gardens")
	check(not game.adventuring and game.ui_margin.visible,"A test instance does not trigger production exploration auto-start")
	for key: String in ["river_fan","stone_root"]: check(game.state.adventure_collect(key).get("ok",false),"The fixture collects a genuine "+key+" individual")
	var ids: Array=[]
	for id: String in game.state.plant_order.slice(0,6): ids.append(id)
	check(game.state.set_travel_party(ids).get("ok",false),"The party uses six actual owned living individuals")
	game._open_adventure()
	await settle()
	for config: Array in [["en",Vector2i(1440,1000)],["zh_CN",Vector2i(1440,1000)],["en",Vector2i(390,780)],["zh_CN",Vector2i(390,780)]]:
		await view(str(config[0]),config[1])
	await bag_pockets("Stream phone")
	await lead_persistence()
	await use_bag_tool()
	await follow_route()
	game._return_from_adventure()
	check(game.ui_margin.visible and not game.adventuring,"The garden remains reachable from the same journey")
	game.queue_free()
	await process_frame
	for suffix: String in [".json",".backup.json",".audio.cfg",".display.cfg"]: DirAccess.remove_absolute(save_path.get_basename()+suffix)
	Locale.set_language("en")
	print("FIELD ADVENTURE UI TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
