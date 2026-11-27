extends SceneTree
## Checkpoint correction keeps exact growth and randomness, never the seed vault.
## No player saves, rendering, or audio are used.
const Session=preload("res://scripts/session.gd")
const Levels=preload("res://scripts/levels.gd")
var checks: int=0
var failures: int=0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool,message: String) -> void:
	checks+=1
	if not value:
		failures+=1
		push_error("UNDO: "+message)

func grow(session,seconds: float) -> void:
	for i in roundi(seconds*30.0): session.step(1.0/30.0)

func snapshot(session) -> Dictionary:
	var result: Dictionary={"world":{},"plant":{},"rng_seed":session.plant.rng.seed,"rng_state":session.plant.rng.state,
		"lures_left":session.lures_left,"prunes_left":session.prunes_left,"tools_used":session.tools_used,"idle_time":session.idle_time,"genome":session.plant.genome.duplicate(true)}
	for key: String in Session.WORLD_FIELDS: result.world[key]=session._copy(session.world.get(key))
	for key: String in Session.PLANT_FIELDS: result.plant[key]=session._copy(session.plant.get(key))
	return result

func fresh(index: int=0,seed: int=17):
	var session=Session.new()
	session.start(Levels.all()[index],Levels.starter(),seed)
	return session

func run() -> void:
	var session=fresh()
	var before: Dictionary=snapshot(session)
	check(not session.can_undo() and session.undo_label().is_empty(),"A new attempt has no correction history")
	check(not session.undo().ok and snapshot(session)==before,"Undo with no history is a pure refusal")
	for point: Vector2 in [Vector2(-1,200),Vector2(2001,200),Vector2(INF,10)]:
		check(not session.add_lure(point) and not session.can_undo() and snapshot(session)==before,"Invalid lure placement cannot consume a tool or create a checkpoint")
	check(not session.remove_lure(-1) and not session.remove_lure(0) and snapshot(session)==before,"Invalid lure recall indices leave the model unchanged")
	check(not session.move_lure(0,Vector2(300,300)) and snapshot(session)==before,"An absent lure cannot be moved")
	check(session.prune(Vector2(0,100),Vector2(200,100)).is_empty() and snapshot(session)==before,"A missed cut does not even add an empty prune event")
	for path: Array in [[],[Vector2.ZERO],[Vector2.ZERO,3],[Vector2.ZERO,Vector2(INF,0)]]:
		check(session.prune_path(path).is_empty() and not session.can_undo() and snapshot(session)==before,"Invalid swipe paths leave state and history unchanged")
	grow(session,1.0)
	before=snapshot(session)
	var old_world=session.world
	var old_plant=session.plant
	var genome=session.plant.genome
	var genome_before: Dictionary=genome.duplicate(true)
	check(session.add_lure(Vector2(700,500)) and session.undo_label()=="Place lure","Lure placement has an understandable correction label")
	grow(session,1.2)
	var restored: Dictionary=session.undo()
	check(restored.ok and restored.kind=="place_lure" and float(restored.rewound_seconds)>1.1,"Correction explains that growth since the action was rewound")
	check(snapshot(session)==before,"Undo placement restores exact geometry, sap, RNG, timers, world state and tool counts")
	check(session.world==old_world and session.plant==old_plant and session.plant.world==session.world,"Correction keeps the existing world and plant objects connected")
	check(genome==genome_before and session.plant.genome==genome_before,"Undo never rewrites the starting genome")
	check(not session.can_undo(),"Undo consumes its checkpoint")
	# One mouse drag coalesces its valid movements while separate drags remain distinct.
	check(session.add_lure(Vector2(500,400)),"Place a lure for a drag")
	before=snapshot(session)
	check(not session.move_lure(0,Vector2(500,400)) and session.undo_label()=="Place lure","An unchanged lure position creates no move history")
	check(session.move_lure(0,Vector2(600,400)),"The first drag motion creates a checkpoint")
	check(session.move_lure(0,Vector2(700,450),true) and session.move_lure(0,Vector2(800,500),true),"Subsequent valid motions can belong to the same drag")
	check(session.undo().action=="Move lure" and snapshot(session)==before,"One undo returns the whole drag to its original position")
	check(session.undo().action=="Place lure" and session.world.lures.is_empty(),"The older placement remains a separate correction")
	check(session.add_lure(Vector2(500,400)),"A new lure can be recalled")
	before=snapshot(session)
	check(session.remove_lure(0) and session.lures_left==int(before.lures_left)+1,"Recall restores the reusable lure budget")
	grow(session,0.2)
	check(session.undo().action=="Recall lure" and snapshot(session)==before,"Undo recall restores the lure, budget, and preceding plant exactly")
	var dark=fresh(3)
	var dark_before: Dictionary=snapshot(dark)
	check(not dark.add_lure(Vector2(1160,420)) and snapshot(dark)==dark_before and not dark.can_undo(),"Forbidden dark placements create no correction history")
	check(dark.add_lure(Vector2(300,300)),"A light can be placed outside the dark")
	dark_before=snapshot(dark)
	check(not dark.move_lure(0,Vector2(1160,420)) and snapshot(dark)==dark_before and dark.undo_label()=="Place lure","Dragging into darkness cannot consume or replace a valid checkpoint")
	# A real cut must resurrect its complete parent/child tree, not just its pixels.
	session=fresh(1,1)
	grow(session,2.0)
	before=snapshot(session)
	var removed: Array=session.prune_path([Vector2(700,770),Vector2(800,770),Vector2(900,770)])
	check(not removed.is_empty() and session.prunes_left==int(before.prunes_left)-1,"A real multi-segment swipe consumes exactly one pruning cut")
	check(session.undo_label()=="Prune stem" and session.plant.alive.has(0),"The removed branch is actually dead before correction")
	grow(session,0.8)
	check(session.undo().kind=="prune" and snapshot(session)==before,"Undo pruning resurrects every node, branch, leader, root, and sap reserve exactly")
	var control=fresh(1,1)
	grow(control,2.0)
	grow(control,0.9)
	grow(session,0.9)
	check(snapshot(session)==snapshot(control),"Restored RNG and tip internals reproduce the same future growth as an untouched control")
	# A direct cut shares the same checkpoint semantics.
	session=fresh(1,1)
	grow(session,2.0)
	before=snapshot(session)
	check(not session.prune(Vector2(700,770),Vector2(900,770)).is_empty(),"Direct pruning still cuts a living stem")
	check(session.undo().ok and snapshot(session)==before,"Direct pruning and swipes both restore a complete checkpoint")
	# All authored environments keep their dynamic discoveries and shared references.
	for index in range(Levels.all().size()):
		session=fresh(index,5)
		grow(session,0.2)
		before=snapshot(session)
		var world=session.world
		var plant=session.plant
		check(session.add_lure(Vector2(30,200)),"Each authored garden accepts a valid correction checkpoint: "+str(index+1))
		for goal: Dictionary in world.goals: goal.reached=true
		for dew: Dictionary in world.dews: dew.taken=true
		for crystal: Dictionary in world.crystals: crystal.alive=false
		for rock: Dictionary in world.rocks: rock.open=true
		for key: Dictionary in world.switches: key.on=true
		for wild: Dictionary in world.wilds: wild.pollinated=true
		world.seed_pos+=Vector2(10,0)
		grow(session,0.4)
		check(session.undo().ok and snapshot(session)==before,"Checkpoint rewinds gates, crystal, wells, dew, pollen contacts, decoys, timers and growth in garden "+str(index+1))
		check(session.world==world and session.plant==plant and plant.world==world,"Garden correction keeps world ownership intact: "+str(index+1))
		for wild_sim in session.wild_sims: check(wild_sim.world==world,"Wild specimen still refers to the restored world")
	# Escaping a drag is a cancellation even when its checkpoint evicts an old one.
	session=fresh()
	session.add_lure(Vector2(200,200))
	for i in range(10):
		session.move_lure(0,Vector2(240+i*20,240))
		session.finish_lure_move()
	before=snapshot(session)
	var history_before: Array=session._undo_history.duplicate(true)
	check(session._undo_history.size()==8,"Cancellation fixture starts with eight committed actions")
	check(not session.cancel_lure_move().ok and snapshot(session)==before and session._undo_history==history_before,"A committed move cannot be canceled after release")
	session.move_lure(0,Vector2(600,500))
	session.move_lure(0,Vector2(650,550),true)
	grow(session,0.2)
	var canceled: Dictionary=session.cancel_lure_move()
	check(canceled.ok and canceled.cancelled and snapshot(session)==before,"Cancel rewinds the open drag and every model value exactly")
	check(session._undo_history==history_before and session._undo_history.size()==8,"Cancel at capacity restores the displaced oldest checkpoint and the exact preceding history")
	check(not session.cancel_lure_move().ok and session._undo_history==history_before,"The same drag cannot be canceled twice")
	session.move_lure(0,Vector2(600,500))
	session.finish_lure_move()
	check(session.undo().ok and session._undo_history.size()==7,"Normal undo of a committed move does not resurrect its expired oldest action")
	session.remove_lure(0)
	before=snapshot(session)
	history_before=session._undo_history.duplicate(true)
	check(not session.cancel_lure_move().ok and snapshot(session)==before and session._undo_history==history_before,"Cancel cannot undo a recall, prune, or other preceding action")
	# Older actions expire after eight snapshots; correction never invents a redo.
	session=fresh()
	session.add_lure(Vector2(200,200))
	var expected: Array=[]
	for i in range(14):
		expected.append(snapshot(session))
		session.move_lure(0,Vector2(250+i*30,250))
		grow(session,0.1)
	for i in range(8):
		var target: Dictionary=expected[expected.size()-1-i]
		check(session.undo().ok and snapshot(session)==target,"Bounded history restores the exact recent checkpoint "+str(i+1))
	check(not session.can_undo() and not session.undo().ok,"Only the eight most recent actions are retained")
	session.start(Levels.all()[0],Levels.starter(),17)
	check(not session.can_undo() and session.tools_used==0 and session.idle_time==0.0,"Starting another attempt resets correction history and counters")
	print("UNDO TEST: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
