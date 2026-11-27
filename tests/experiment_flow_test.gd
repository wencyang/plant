extends SceneTree
## Actual input integration for previews, deliberate aiming and forgiving undo.
const Main=preload("res://scripts/main.gd")
const Levels=preload("res://scripts/levels.gd")
var game
var path: String
var checks: int=0
var failures: int=0
var native: bool=false

func _initialize() -> void: call_deferred("run")
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:
		failures+=1
		push_error("EXPERIMENT FLOW: "+message)
func settle() -> void:
	for frame in range(6): await process_frame
func mouse(pos: Vector2,pressed: bool,button: int=MOUSE_BUTTON_LEFT) -> void:
	var event:=InputEventMouseButton.new()
	event.position=pos
	event.global_position=pos
	event.button_index=button
	event.pressed=pressed
	root.push_input(event)
func move(pos: Vector2) -> void:
	var event:=InputEventMouseMotion.new()
	event.position=pos
	event.global_position=pos
	root.push_input(event)
func key(code: int) -> void:
	var event:=InputEventKey.new()
	event.keycode=code
	event.pressed=true
	root.push_input(event)
func geometry() -> String:
	var plant=game.session.plant
	return str([plant.pos,plant.parent,plant.alive,plant.children,plant.tips,plant.energy,plant.rng.state])
func capture(name: String) -> void:
	if not native: return
	await settle()
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/experiment-"+name+".png")

func run() -> void:
	path="/tmp/bloomward_experiment_%d.json" % Time.get_ticks_usec()
	native=DisplayServer.get_name()!="headless"
	root.size=Vector2i(1600,1000)
	game=Main.new()
	game.save_path=path
	game.quiet_preview=true
	root.add_child(game)
	await settle()
	game.set_process(false)
	game._start_level(1,Levels.starter())
	game._place_lure(Vector2(800,400))
	for i in range(90): game._process(1.0/30)
	game.paused=true
	var original: String=geometry()
	var energy: float=game.session.plant.energy
	var cuts: int=game.session.prunes_left
	var history: int=game.session._undo_history.size()
	# Aiming must freeze mechanics even if growth had been running.
	game.paused=false
	mouse(Vector2(700,760),true)
	move(Vector2(900,760))
	await settle()
	check(game.pressing and game.swiping,"Dragging across the garden starts a pruning gesture")
	check(game.view.prune_overlay.visible and bool(game.view.prune_overlay.preview.get("has_hits",false)),"The actual gesture exposes an exact live pruning preview")
	var forecast: Dictionary=game.view.prune_overlay.preview.duplicate(true)
	game._process(0.8)
	check(geometry()==original,"Growth and RNG wait while the player aims")
	check(game.session.prunes_left==cuts and game.session._undo_history.size()==history,"A preview spends no prune and creates no undo action")
	await capture("01-prune-preview")
	key(KEY_ESCAPE)
	check(not game.pressing and not game.view.prune_overlay.visible and geometry()==original,"Esc cancels the preview without changing the plant")
	check(not game.paused,"Temporary aiming never changes the player's explicit pause choice")
	game.paused=true
	# Commit the same path, then undo it through the real HUD button.
	mouse(Vector2(700,760),true)
	move(Vector2(900,760))
	mouse(Vector2(900,760),false)
	await settle()
	check(game.session.prunes_left==cuts-1 and not game.pressing,"Releasing makes exactly one pruning action")
	check(absf(game.session.plant.energy-energy-float(forecast.sap_refund))<0.001,"The preview's sap refund is the actual refund")
	check(game.session.undo_label()=="Prune stem" and not game.undo_button.disabled,"The completed cut has a clear usable undo control")
	await capture("02-after-cut")
	game.undo_button.pressed.emit()
	await settle()
	check(geometry()==original and game.session.prunes_left==cuts,"Undo restores the exact pre-cut tree, sap and RNG")
	check(game.paused and game.overlay==null,"Undo returns to planning rather than forcing another attempt")
	await capture("03-undo-cut")
	# All motions of one drag are one action; cancel preserves earlier history.
	history=game.session._undo_history.size()
	mouse(Vector2(800,400),true)
	move(Vector2(850,430))
	move(Vector2(900,470))
	check(game.session._undo_history.size()==history+1,"A lure drag has one checkpoint, not one per pointer motion")
	mouse(Vector2(900,470),true,MOUSE_BUTTON_RIGHT)
	check(game.session.world.lures[0]==Vector2(800,400) and game.session._undo_history.size()==history,"Right-click cancels a moved lure and keeps earlier undo history")
	mouse(Vector2(800,400),true)
	move(Vector2(900,470))
	mouse(Vector2(900,470),false)
	check(game.session.world.lures[0]==Vector2(900,470),"Releasing commits the lure's actual destination")
	key(KEY_Z)
	check(game.session.world.lures[0]==Vector2(800,400),"Z undoes a committed lure move")
	history=game.session._undo_history.size()
	mouse(Vector2(800,400),true)
	move(Vector2(900,470))
	move(Vector2(800,400))
	mouse(Vector2(800,400),false)
	check(game.session._undo_history.size()==history,"A drag returned to its starting spot leaves no meaningless undo action")
	# A release over the HUD must not leave the game permanently aiming.
	mouse(Vector2(100,400),true)
	move(Vector2(200,400))
	mouse(Vector2(1300,940),false)
	check(not game.pressing,"A gesture also ends when released over the HUD")
	# Rebuilding after undo must respect restored progress, not redraw every
	# obstacle as closed and every well as new.
	game._start_level(14,Levels.starter(),true)
	game.session.world.open_gates(["g1"])
	game.session.world.switches[0].on=true
	game._place_lure(Vector2(1000,500))
	game._undo_action()
	for index in game.session.world.rocks.size():
		if str(game.session.world.rocks[index].gate)=="g1": check(not game.view.rock_nodes[index].visible,"Undo keeps an already-open stone gate visually open")
	game._start_level(2,Levels.starter(),true)
	game.session.world.crystals[0].alive=false
	game._place_lure(Vector2(330,520))
	game._undo_action()
	check(not game.view.crystal_nodes[0].visible,"Undo keeps already-shattered crystal absent")
	game._start_level(1,Levels.starter(),true)
	game.session.world.goals[0].reached=true
	game._place_lure(Vector2(800,400))
	game._undo_action()
	check(float(game.view.goal_bloom.get(0,0))==1,"Undo restores an awakened sunwell's rendered state immediately")
	# Undoing contact cannot farm new offspring or reroll their genes.
	game._start_level(2,Levels.starter())
	game.breeding_random.seed=99
	game._place_lure(Vector2(330,520))
	for i in range(1800):
		game._process(1.0/30)
		if bool(game.session.world.wilds[0].pollinated): break
	check(game.earned_crosses.has(0),"A real wild contact records its earned family")
	var seed_count: int=game.save.seeds.size()
	var born: String=JSON.stringify(game.save.seeds)
	var rng_state: int=game.breeding_random.state
	game._undo_action()
	check(not game.session.world.wilds[0].pollinated and game.save.seeds.size()==seed_count,"Undo rewinds the encounter while keeping earned seeds")
	check(game.pending_cross.is_empty(),"An obsolete reveal cannot interrupt the rewound attempt")
	game._place_lure(Vector2(330,520))
	game.paused=false
	for i in range(1800):
		game._process(1.0/30)
		if bool(game.session.world.wilds[0].pollinated): break
	check(bool(game.session.world.wilds[0].pollinated),"The same experiment can reach the wild plant again")
	check(game.save.seeds.size()==seed_count and JSON.stringify(game.save.seeds)==born and game.breeding_random.state==rng_state,"Repeating contact after undo neither farms nor rerolls offspring")
	await create_timer(1.6).timeout
	check(game.overlay==null and game.pending_cross.is_empty(),"An old pollination timer cannot reveal an obsolete rewound fruit")
	game.queue_free()
	await process_frame
	if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	print("EXPERIMENT FLOW: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
