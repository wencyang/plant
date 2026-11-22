extends SceneTree
## Real field controls expose the ecology that chooses the actual organism.
## Landscape browsing must keep owned plants, inherited DNA and supplies intact.
const Garden = preload("res://scripts/garden.gd")
const State = preload("res://scripts/garden_state.gd")
const Habitat = preload("res://scripts/habitat_catalog.gd")
const DNA = preload("res://scripts/plant_dna.gd")
const Locale = preload("res://scripts/localization.gd")
const Display = preload("res://scripts/display_settings.gd")
var game: Control
var checks: int=0
var failures: int=0
var save_path: String
var original_collection: String
var original_supplies: String

func _initialize() -> void:
	call_deferred("run")

func check(value: bool,message: String) -> void:
	checks+=1
	if not value:
		failures+=1
		push_error("HABITAT UI: "+message)

func settle() -> void:
	for i in range(5): await process_frame

func collection() -> String:
	var organisms: Dictionary=game.state.plants.duplicate(true)
	for id: String in organisms: organisms[id].erase("life_age")
	return DNA.canonical([organisms,game.state.plant_order,game.state.bed,game.state.display_bed])

func supplies() -> String:
	return DNA.canonical([game.state.resources,game.state.market,game.state.seed_bank,game.state.fruit_inventory,game.state.field_kits])

func find_meta(node: Node,key: String) -> Node:
	if node.has_meta(key) and bool(node.get_meta(key)): return node
	for child: Node in node.get_children():
		var found: Node=find_meta(child,key)
		if found!=null: return found
	return null

func find_button(node: Node,title: String="",action: String="") -> Button:
	if node is Button and ((not title.is_empty() and str(node.text)==title) or (not action.is_empty() and str(node.get_meta("habitat_action",""))==action)):
		return node
	for child: Node in node.get_children():
		var found: Button=find_button(child,title,action)
		if found!=null: return found
	return null

func text_of(node: Node) -> String:
	if node==null: return ""
	if node is Label or node is RichTextLabel or node is Button: return str(node.text)
	return ""

func within(rect: Rect2,bounds: Rect2) -> bool:
	return rect.position.x>=bounds.position.x-2 and rect.position.y>=bounds.position.y-2 and rect.end.x<=bounds.end.x+2 and rect.end.y<=bounds.end.y+2

func overflow(node: Node,bounds: Rect2,issues: Array[String]) -> void:
	if node is Control and node.is_visible_in_tree():
		var rect: Rect2=node.get_global_rect()
		if rect.position.x<bounds.position.x-2 or rect.end.x>bounds.end.x+2:
			issues.append(node.get_class()+" "+text_of(node).left(45)+" "+str(rect))
		if node is ScrollContainer and node.horizontal_scroll_mode!=ScrollContainer.SCROLL_MODE_DISABLED: return
	for child: Node in node.get_children(): overflow(child,bounds,issues)

func check_modal(context: String) -> void:
	check(is_instance_valid(game.modal),context+" opens an actual encounter panel")
	if not is_instance_valid(game.modal): return
	var panel: Control=game.modal.get_node("Panel")
	check(within(panel.get_global_rect(),root.get_visible_rect()),context+" fits the viewport")
	var issues: Array[String]=[]
	overflow(panel,panel.get_global_rect(),issues)
	check(issues.is_empty(),context+" text and actions fit horizontally: "+"; ".join(issues.slice(0,5)))

func layout(language: String,dimensions: Vector2i) -> void:
	Locale.set_language(language)
	game.display_settings.enabled=false
	root.size=dimensions
	root.content_scale_factor=1
	await settle()
	game._responsive()
	game._localize_ui()
	await settle()

func biome_site(biome: String) -> Dictionary:
	for site: Dictionary in game.wilderness.SITES:
		if str(site.biome)==biome: return site
	return {}

func inspect_habitat(biome: String,context: String) -> void:
	var site: Dictionary=biome_site(biome)
	check(not site.is_empty(),context+" has a reachable mapped plant patch")
	if site.is_empty(): return
	game.wilderness.teleport_to_site(str(site.id))
	await settle()
	check(within(game.wilderness._header.get_global_rect(),root.get_visible_rect()) and within(game.wilderness._footer.get_global_rect(),root.get_visible_rect()),context+" field HUD fits")
	var patch: Dictionary=Habitat.patch(biome,str(site.id))
	game._localize_ui()
	await settle()
	check(game.wilderness._target_label.text==Locale.text("%s / %s" % [patch.name,patch.primary_species]),context+" trail marker names the real patch and its usual plant family")
	check(game.wilderness._hint_label.text==Locale.text(str(patch.clue)),context+" trail hint explains where that family prefers to grow")
	if Locale.get_language()=="zh_CN":
		check(Locale.text(str(patch.name))!=str(patch.name) and Locale.text(str(patch.clue))!=str(patch.clue),context+" ecological names and clues have Chinese translations")
	var expected: Dictionary=game.state.preview_wild_plant(biome,str(site.id))
	var field_art: Control=game.wilderness._wild_portraits.get(str(site.id))
	check(is_instance_valid(field_art),context+" renders the nearby wild specimen through the real plant portrait")
	if is_instance_valid(field_art):
		check(DNA.canonical(field_art.plant.get("genes",{}))==DNA.canonical(expected.genes) and int(field_art.plant.seed)==int(expected.seed),context+" field art uses the exact inherited colors, patterns and anatomy seen in the encounter")
		check(game.wilderness._wild_layer.clip_contents and within(field_art.get_global_rect(),game.wilderness._wild_layer.get_global_rect()),context+" live plant artwork stays inside the walkable field")
	game.wilderness.interact()
	await settle()
	game._localize_ui()
	await settle()
	check(game.modal_kind=="wild_encounter",context+" investigates through the real field signal")
	check_modal(context)
	if game.state.expedition.active_encounter.is_empty(): return
	var actual: Dictionary=game.state.expedition.active_encounter.plant
	check(DNA.canonical([expected.genes,expected.seed,expected.species])==DNA.canonical([actual.genes,actual.seed,actual.species]),context+" landscape specimen matches the real previewed DNA")
	var scene: Node=find_meta(game.modal,"habitat_scene")
	var name_label: Node=find_meta(game.modal,"habitat_name")
	var clue_label: Node=find_meta(game.modal,"habitat_clue")
	check(scene!=null,context+" displays an illustrated habitat scene with the plant")
	if scene!=null:
		check(str(scene.get_meta("art_key",""))==str(patch.art_key),context+" uses its own landscape artwork")
	check(text_of(name_label)==Locale.text(str(patch.name)),context+" names the actual microhabitat")
	check(text_of(clue_label)==Locale.text(str(patch.clue)),context+" explains the habitat's botanical clue")
	check(str(actual.origin.get("habitat",""))==str(patch.name),context+" organism remembers the shown microhabitat")
	check(collection()==original_collection and supplies()==original_supplies,context+" browsing keeps owned genomes, arrangement and supplies")
	var organism: String=DNA.canonical(actual)
	game._wild_action("observe")
	await settle()
	check(game.state.expedition.active_encounter.observed and DNA.canonical(game.state.expedition.active_encounter.plant)==organism,context+" studying keeps the exact specimen and provenance")
	check(supplies()==original_supplies,context+" studying consumes no supplies")
	game._leave_wild()
	await settle()
	check(not game.wilderness.waiting and game.state.expedition.active_encounter.is_empty(),context+" leaving returns control to the same landscape")

func follow_guide_trail() -> void:
	await layout("en",Vector2i(1440,1000))
	game._return_from_wilderness()
	await settle()
	var owned: String=str(game.state.plant_order[0])
	game._open_detail(owned)
	await settle()
	var entry: Button=find_button(game.modal,"Where this family grows →")
	check(entry!=null,"Owned plant detail offers the actual habitat guide control")
	if entry==null: return
	entry.pressed.emit()
	await settle()
	check(game.modal_kind=="habitat_guide" and str(game.modal.get_meta("plant_id",""))==owned,"The actual detail button opens this plant's family guide")
	check_modal("Owned family guide")
	var route: Button=find_button(game.modal,"","route")
	check(route!=null and not route.disabled,"The family guide offers a real Follow this trail action")
	if route==null: return
	var biome: String=str(route.get_meta("biome",""))
	var habitat_key: String=str(route.get_meta("habitat_key",""))
	var matches: bool=false
	for info: Dictionary in Habitat.preferred_habitats(str(game.state.get_plant(owned).type)):
		if str(info.biome)==biome and str(info.get("habitat_key",""))==habitat_key and bool(info.get("primary",false)): matches=true
	check(matches,"The chosen guide trail is a primary habitat for the owned plant's actual family")
	# Freeze automatic strolling only while examining the resulting route. The
	# actual button still opens the field and computes its normal walkable path.
	game.wilderness.set_process(false)
	var start: Vector2i=game.wilderness.player_tile
	route.pressed.emit()
	await settle()
	check(game.exploring and not game.wilderness.waiting,"Following a guide trail returns walking control to the wilderness")
	check(game.wilderness.player_tile==start,"Following a guide trail does not teleport the player")
	var goal: Vector2i=game.wilderness._touch_goal
	var route_path: Array[Vector2i]=game.wilderness._find_path(start,goal)
	check(goal.x>=0 and route_path.size()>1,"The guide computes a real path from the present explorer position")
	var suitable: bool=false
	for site: Dictionary in game.wilderness.SITES:
		if str(site.biome)!=biome or game.wilderness._site_unavailable(str(site.id)): continue
		var info: Dictionary=Habitat.patch(biome,str(site.id))
		if str(info.id)==habitat_key and game.wilderness._distance(goal,Vector2i(site.x,site.y))<=1: suitable=true
	check(suitable,"The trail ends beside an available patch of the promised microhabitat")
	var walkable: bool=true
	for step: Vector2i in route_path:
		if not game.wilderness.is_walkable(step): walkable=false
	check(walkable,"The guide route follows walkable terrain around actual landscape obstacles")
	if route_path.size()>1:
		check(game.wilderness._try_step(route_path[1]-start) and game.wilderness.player_tile==route_path[1],"A real walking step advances along the guide's route")
	game.wilderness.set_process(true)
	check(collection()==original_collection and supplies()==original_supplies,"Family-guide navigation keeps owned DNA, beds, inventory and supplies")

func run() -> void:
	Locale.set_language("en")
	save_path="/tmp/conservatory_habitat_ui_%d.json" % Time.get_ticks_usec()
	game=Garden.new()
	game.state=State.new(save_path)
	root.add_child(game)
	game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game.display_settings=Display.new(save_path.get_basename()+".display.cfg")
	game.display_settings.configure(root,false)
	await layout("en",Vector2i(1440,1000))
	original_collection=collection()
	original_supplies=supplies()
	game._open_wilderness()
	await settle()
	check(game.soundscape.preview_muted,"Disposable ecology QA does not play audio or change sound preferences")
	var art_keys: Dictionary={}
	for biome: String in State.WILD_BIOMES:
		art_keys[str(Habitat.region(biome).art_key)]=true
		await inspect_habitat(biome,"English desktop "+biome)
	check(art_keys.size()==8,"All eight habitats have distinct scene identities")
	for view: Array in [["zh_CN",Vector2i(1440,1000),"Chinese desktop"],["en",Vector2i(390,780),"English phone"],["zh_CN",Vector2i(390,780),"Chinese phone"]]:
		await layout(str(view[0]),view[1])
		for biome: String in ["Mosswood","Glassfall Coast","Moonfen"]:
			await inspect_habitat(biome,str(view[2])+" "+biome)
		game.wilderness._open_atlas()
		await settle()
		game._localize_ui()
		await settle()
		check(within(game.wilderness._atlas.get_global_rect(),root.get_visible_rect()),str(view[2])+" atlas fits the viewport")
		var issues: Array[String]=[]
		overflow(game.wilderness._atlas,game.wilderness._atlas.get_global_rect(),issues)
		check(issues.is_empty(),str(view[2])+" atlas content fits horizontally: "+"; ".join(issues.slice(0,5)))
		game.wilderness._close_atlas()
		await settle()
	await follow_guide_trail()
	check(collection()==original_collection and supplies()==original_supplies,"The complete landscape tour keeps home plants, DNA, beds, wallet, fruit, seeds and field kits intact")
	game.state.save_game()
	var restored: RefCounted=State.new(save_path)
	check(restored.load_game(),"Habitat tour reloads through the normal save format")
	check(DNA.canonical([restored.expedition.position,restored.expedition.site_records])==DNA.canonical([game.state.expedition.position,game.state.expedition.site_records]),"Patch observations and explorer location survive reload")
	game._return_from_wilderness()
	game.queue_free()
	await process_frame
	for suffix: String in [".json",".backup.json",".audio.cfg",".display.cfg"]:
		DirAccess.remove_absolute(save_path.get_basename()+suffix)
	Locale.set_language("en")
	print("HABITAT INTEGRATION TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
