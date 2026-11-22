extends SceneTree
## Actual stream exploration, normal breeding/care rules, permanent discoveries.
## All captures use silent, disposable gardens and never the player's archive.
const Garden = preload("res://scripts/garden.gd")
const State = preload("res://scripts/garden_state.gd")
const Locale = preload("res://scripts/localization.gd")
const Display = preload("res://scripts/display_settings.gd")
var game: Control
var save_paths: Array[String]=[]

func _initialize() -> void:
	call_deferred("run")

func settle() -> void:
	for i in range(5): await process_frame

func layout(language: String,dimensions: Vector2i) -> void:
	Locale.set_language(language)
	game.display_settings.enabled=false
	root.size=dimensions
	root.content_scale_factor=2
	await settle()
	game._responsive()
	game._localize_ui()
	await settle()

func snap(name: String) -> void:
	game._localize_ui()
	await create_timer(0.4).timeout
	await settle()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/"+name+".png")
	print("ADVENTURE VISUAL: ",name," · ",root.size)

func find_action(node: Node,action: String,filters: Dictionary={}) -> Button:
	if node is Button and str(node.get_meta("adventure_action",""))==action:
		var matches: bool=true
		for key: String in filters:
			if str(node.get_meta(key,""))!=str(filters[key]): matches=false
		if matches: return node
	for child: Node in node.get_children():
		var found: Button=find_action(child,action,filters)
		if found!=null: return found
	return null

func press(action: String,filters: Dictionary={}) -> bool:
	var button: Button=find_action(game.modal if is_instance_valid(game.modal) else game,action,filters)
	if button==null or button.disabled:
		push_error("ADVENTURE PREVIEW: missing or disabled "+action+" "+str(filters))
		quit(1)
		return false
	button.pressed.emit()
	await settle()
	return true

func choose(action: String,id: String) -> void:
	var picker: OptionButton=find_action(game.modal,action) as OptionButton
	if picker==null:
		push_error("ADVENTURE PREVIEW: no actual "+action+" picker")
		quit(1)
		return
	for index in range(picker.item_count):
		if str(picker.get_item_metadata(index))==id:
			picker.select(index)
			picker.item_selected.emit(index)
			await settle()
			return
	push_error("ADVENTURE PREVIEW: selected plant is not offered")
	quit(1)

func new_garden(route: String) -> void:
	if is_instance_valid(game):
		game.queue_free()
		await process_frame
	Locale.set_language("en")
	var path: String="/tmp/conservatory_adventure_visual_%s_%d.json" % [route,Time.get_ticks_usec()]
	save_paths.append(path)
	game=Garden.new()
	game.state=State.new(path)
	root.add_child(game)
	game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game.display_settings=Display.new(path.get_basename()+".display.cfg")
	game.display_settings.configure(root,false)
	await layout("en",Vector2i(2880,2000))
	game._open_adventure()
	await settle()
	if is_instance_valid(game.modal): await press("return_field")
	await settle()

func meet(key: String) -> void:
	if is_instance_valid(game.modal): await press("return_field")
	game.adventure_field.walk_to(game.adventure_field.hotspot_position(key),"moonbell" if key=="moonbell" else "inspect_parent",key)
	for i in range(160):
		if is_instance_valid(game.modal): break
		game.adventure_field._process(0.15)
		await process_frame
	await settle()
	if not is_instance_valid(game.modal):
		push_error("ADVENTURE PREVIEW: walking did not reach "+key)
		quit(1)

func collect(key: String,capture: String="") -> String:
	await meet(key)
	if not capture.is_empty(): await snap(capture)
	await press("collect",{"cutting_key":key})
	var info: Dictionary=game.state.adventure_info()
	return str(info.get("moonbell_id","")) if key=="moonbell" else str(info.cuttings.get(key,""))

func siblings(mother: String,father: String,prefix: String="") -> Array[String]:
	game._show_adventure_cross(mother,father)
	await settle()
	await choose("mother",mother)
	await choose("father",father)
	if not prefix.is_empty(): await snap(prefix+"-cross-preview")
	await press("pollinate")
	if not prefix.is_empty(): await snap(prefix+"-fruit-growing")
	var result: Dictionary=game.state.apply_care(mother,"ripening")
	if not result.get("ok",false):
		push_error("ADVENTURE PREVIEW: normal ripening spray unavailable "+str(result))
		quit(1)
		return []
	game._show_adventure_cross(mother,father)
	await settle()
	await press("siblings",{"mother_id":mother})
	var children: Array[String]=[]
	for id: String in game.state.plant_order:
		var p: Dictionary=game.state.get_plant(id)
		if p.parents==[mother,father] and not bool(p.mature): children.append(id)
	if not prefix.is_empty(): await snap(prefix+"-sibling-seedlings")
	for id: String in children: game.state.apply_care(id,"sunlamp")
	game._show_adventure_reveal(children)
	await settle()
	if not prefix.is_empty(): await snap(prefix+"-grown-siblings")
	return children

func apply_plant(id: String,goal: String,capture: String="") -> void:
	game._show_adventure_use(goal,id)
	await settle()
	await choose("choose_plant",id)
	if not capture.is_empty(): await snap(capture)
	await press("apply",{"plant_id":id,"goal":goal})
	if is_instance_valid(game.modal): await press("return_field")
	await settle()

func run() -> void:
	await new_garden("raft")
	await snap("adventure-shore-desktop-en")
	var leaf: String=await collect("river_fan","adventure-river-fan-desktop-en")
	var spore: String=await collect("floatcap","adventure-floatcap-desktop-en")
	game.state.random.seed=5102026
	var g2: Array[String]=await siblings(leaf,spore,"adventure-raft")
	if g2.is_empty(): return
	await apply_plant(g2[0],"stream","adventure-raft-ability-desktop-en")
	await snap("adventure-living-raft-desktop-en")
	var bell: String=await collect("moonbell","adventure-island-moonbell-desktop-en")
	var glowing: String=""
	for attempt in range(2):
		game.state.random.seed=1
		var next: Array[String]=await siblings(bell if attempt==0 else g2[1],g2[0] if attempt==0 else bell,"adventure-lantern" if attempt==0 else "")
		for id: String in next:
			if game.state.adventure_preview(id,"lantern").get("eligible",false): glowing=id;break
		if not glowing.is_empty(): break
	if glowing.is_empty():
		push_error("ADVENTURE PREVIEW: two actual Moonbell fruit batches did not produce a glowing child")
		quit(1)
		return
	await apply_plant(glowing,"lantern","adventure-lantern-ability-desktop-en")
	game.adventure_field.walk_to(Vector2(1180,420))
	for i in range(50):
		game.adventure_field._process(0.15)
		await process_frame
	await snap("adventure-restored-courtyard-desktop-en")
	await layout("zh_CN",Vector2i(780,1560))
	await snap("adventure-restored-courtyard-mobile-zh")
	game._show_adventure_cross(g2[0],bell)
	await snap("adventure-cross-preview-mobile-zh")
	game._show_adventure_use("lantern",glowing)
	await snap("adventure-plant-ability-mobile-zh")
	await new_garden("vine")
	var vine: String=await collect("gripvine","adventure-gripvine-desktop-en")
	var root_id: String=await collect("stone_root","adventure-stone-root-desktop-en")
	game.state.random.seed=5102026
	var bridge: Array[String]=await siblings(vine,root_id,"adventure-vine")
	if bridge.is_empty(): return
	await apply_plant(bridge[0],"stream","adventure-vine-ability-desktop-en")
	await snap("adventure-vine-bridge-desktop-en")
	await layout("zh_CN",Vector2i(780,1560))
	await snap("adventure-vine-bridge-mobile-zh")
	game._show_adventure_use("stream",bridge[0])
	await snap("adventure-vine-ability-mobile-zh")
	game.queue_free()
	await process_frame
	for path: String in save_paths:
		for suffix: String in [".json",".backup.json",".audio.cfg",".display.cfg"]: DirAccess.remove_absolute(path.get_basename()+suffix)
	Locale.set_language("en")
	print("ADVENTURE PREVIEW COMPLETE: real cutting collection, two genetic crossing solutions, fruit and sibling growth, island Moonbell, glowing G3 courtyard; English and Chinese desktop and phone; disposable gardens only")
	quit()
