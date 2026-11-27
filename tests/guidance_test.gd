extends SceneTree
## Guidance reads actual Bloomward genomes and attempt progress; it never
## grants gifts, changes the simulation, or reads/writes the player's save.
const Guidance := preload("res://scripts/garden_guidance.gd")
const Levels := preload("res://scripts/levels.gd")
const Genome := preload("res://scripts/genome.gd")
const Session := preload("res://scripts/session.gd")
var checks: int=0
var failures: int=0
var levels: Array=[]

func _initialize() -> void: call_deferred("run")
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:
		failures+=1
		push_error("GUIDANCE: "+message)

func gifts(keys: Array) -> Dictionary:
	var g: Dictionary=Levels.starter().duplicate(true)
	for key: String in keys: g[key]=1
	return g

func attempt(index: int,genome: Dictionary):
	var session=Session.new()
	session.start(levels[index],genome,1)
	return session

func signature(session,seeds: Array) -> String:
	return var_to_str([session.def,session.world.rocks,session.world.crystals,session.world.goals,session.world.wilds,
		session.world.switches,session.world.lures,session.world.dews,session.world.time,session.plant.genome,
		session.plant.pos,session.plant.alive,session.plant.tips,session.plant.energy,session.idle_time,
		session.lures_left,session.prunes_left,session.tools_used,seeds])

func stop_plant(session,why: String="") -> void:
	for tip: Dictionary in session.plant.tips:
		tip.state="stopped"
		if not why.is_empty(): tip.why=why
	session.idle_time=2.0

func run() -> void:
	levels=Levels.all()
	# This is the intended-route gift table validated by the existing solve
	# regression. The tricky tool gardens intentionally require no new gift.
	var expected: Array=[[],[],["thorns"],["glow"],["tendrils"],["roots"],["thorns","glow"],
		["thorns","glow","tendrils"],["buoyant"],["waxy"],["glow","roots"],["thorns","tendrils"],[],
		["glow","buoyant","waxy"],[],[],[],[],["glow"],[],["glow","waxy"]]
	check(levels.size()==21 and Guidance.PROFILES.size()==21,"Every authored garden has an explicit guidance profile")
	for index in range(levels.size()):
		var info: Dictionary=Guidance.level_info(levels[index])
		check(info.authored and info.required_gifts==expected[index],"Accurate intended gifts for "+str(levels[index].id))
		check(not str(info.brief).is_empty() and not str(info.learning_focus).is_empty() and info.steps.size()>=3,"Garden has a plain objective and playable learning steps")
		var supplied: Dictionary=gifts(expected[index])
		var ready: Dictionary=Guidance.seed_fit(levels[index],supplied)
		check(ready.ready and ready.missing.is_empty(),"Actual useful genes are recognized for "+str(levels[index].id))
		for key: String in expected[index]:
			var lacking: Dictionary=supplied.duplicate(true)
			lacking[key]=0
			check(not Guidance.seed_fit(levels[index],lacking).ready,"Removing a real gift changes suitability: "+str(levels[index].id)+" / "+key)
		for source: Dictionary in info.wild_sources:
			for row: Dictionary in levels[index].get("wilds",[]):
				if row.pos!=source.pos: continue
				check(source.gifts==Genome.traits(Levels.wild(str(row.genome))),"Wild source lists only gifts in its real genome")
	# Do not mistake the seventh garden for the twelfth.
	check(Guidance.level_info(levels[6]).required_gifts==["thorns","glow"],"Shattered Spire needs Thorns and Glow, not Tendrils")
	check(Guidance.level_info(levels[11]).required_gifts==["thorns","tendrils"],"Briar Gate needs Thorns and Tendrils, not Glow")
	check(not levels[15].vents.is_empty() and Guidance.level_info(levels[15]).required_gifts.is_empty(),"False Dawn has heat but solves by steering away; Waxy is not required")
	check(not levels[16].updrafts.is_empty() and Guidance.level_info(levels[16]).required_gifts.is_empty(),"Updraft Spires uses the actual current rather than pretending Buoyant is needed")
	check(Guidance.level_info(levels[12]).required_gifts.is_empty(),"Optional wild Driftcap and Hookvine do not turn Coral Steps into a gift gate")
	var renamed: Dictionary=Levels.starter()
	renamed.name="Thorns Glow Waxy G99"
	renamed.gen=99
	renamed.parents=["Spinebrush","Lanternwort"]
	check(not Guidance.seed_fit(levels[6],renamed).ready,"Names, parents and generation cannot impersonate actual gift genes")
	var unknown: Dictionary={"id":"unregistered","title":"Unknown","goals":[{"pos":Vector2(10,10)}],"vents":[{"pos":Vector2.ZERO,"r":20}]}
	check(not Guidance.level_info(unknown).authored and Guidance.level_info(unknown).required_gifts.is_empty(),"Unknown geometry is not guessed into a false authored gift requirement")
	# Recommendation respects a viable local breeding path, not gift count or G.
	var glow: Dictionary=gifts(["glow"])
	glow.name="Glow seed"
	var thorn: Dictionary=gifts(["thorns"])
	thorn.name="Thorns seed"
	var both: Dictionary=gifts(["thorns","glow"])
	both.name="Combined seed"
	check(Guidance.recommend_seed(levels[6],[glow,thorn]).index==1,"Spire recommends Thorns, since its wild Lanternwort can add Glow but cannot add Thorns")
	check(Guidance.recommend_seed(levels[6],[glow,thorn,both]).index==2,"An already suitable combined seed is preferred to another redundant cross")
	var float_wax: Dictionary=gifts(["buoyant","waxy"])
	check(Guidance.recommend_seed(levels[13],[float_wax,glow]).index==1,"Long Bloom needs a starting Glow seed; its two local wilds can add the other two gifts")
	check(Guidance.recommend_seed(levels[0],[renamed,Levels.starter()]).index==0,"An ungated tool puzzle preserves stable seed order instead of promoting a decorative generation")
	check(Guidance.recommend_seed(levels[6],[]).index==-1,"An empty vault does not invent a recommended plant")
	# A real contact followed by an actual cross is the important player loop.
	var crystal=attempt(2,Levels.starter())
	var tip: Dictionary=Guidance.next_step(crystal,[Levels.starter()])
	check(tip.phase=="pollinate" and tip.target_kind=="wild" and tip.target_index==0,"Missing Thorns first directs the player to the wild plant, not into the crystal")
	check(tip.why.contains("replant") and tip.action.contains("Spinebrush"),"The action explains physical contact and the need to replant")
	crystal.add_lure(Vector2(330,520))
	for frame in range(2700):
		crystal.step(1.0/30.0)
		if bool(crystal.world.wilds[0].pollinated): break
	check(crystal.world.wilds[0].pollinated,"The regression reaches Spinebrush through real simulated growth")
	check(Guidance.next_step(crystal,[Levels.starter()]).phase=="replant_hybrid","Actual wild contact changes the action to planting a hybrid seed")
	check(int(crystal.plant.genome.thorns)==0,"Pollination does not silently add Thorns to the growing parent")
	var random:=RandomNumberGenerator.new()
	random.seed=237
	var children: Array=Genome.cross(crystal.plant.genome,crystal.world.wilds[0].genome,random)
	check(Guidance.seed_fit(levels[2],children[0]).ready,"The genuine guaranteed union seed has the new useful gift")
	var choose: Dictionary=Guidance.next_step(crystal,[Levels.starter()]+children)
	check(choose.phase=="replant" and choose.recommendation.index==1,"Saved offspring are recommended without touching the same wild plant again")
	var inherited=attempt(2,children[0])
	check(Guidance.next_step(inherited,children).phase=="grow","Replanting the actual useful seed advances the instruction to the puzzle route")
	var spire=attempt(6,glow)
	check(Guidance.next_step(spire,[glow]).phase=="bring_seed" and Guidance.next_step(spire,[glow]).target_index==2,"A missing nonlocal gift explicitly sends the player back to Crystal Throat")
	check(Guidance.next_step(spire,[glow,thorn]).phase=="replant","A saved Thorns seed prevents an unnecessary backtracking instruction")
	var heart=attempt(7,gifts(["thorns","glow"]))
	check(Guidance.next_step(heart,[]).phase=="pollinate" and Guidance.next_step(heart,[]).action.contains("Hookvine"),"Carried gifts are preserved while adding Tendrils in Heart of the Grove")
	var heart_unprepared=attempt(7,Levels.starter())
	var carry_help: Dictionary=Guidance.next_step(heart_unprepared,[])
	check(carry_help.phase=="bring_seed" and carry_help.target_index==6 and carry_help.action.contains("Thorns + Glow"),"Heart of the Grove sends a player for the actual combined seed from Shattered Spire, not a two-gift seed impossible to breed in Crystal Throat")
	var moon=attempt(10,Levels.starter())
	check(Guidance.next_step(moon,[]).why.contains("Glow + Roots"),"Moonpetal is identified as the real two-gift source")
	# Tool puzzles react to actual switches and ordered goal flags.
	var keys=attempt(17,Levels.starter())
	check(Guidance.next_step(keys,[]).phase=="switch" and Guidance.next_step(keys,[]).target_index==0,"Two Keys begins at its actual first unopened key")
	keys.world.switches[0].on=true
	keys.world.open_gates(keys.world.switches[0].opens)
	check(Guidance.next_step(keys,[]).target_index==1 and Guidance.next_step(keys,[]).action.contains("second"),"Opening the first real gate advances the instruction to the second key")
	keys.world.switches[1].on=true
	keys.world.open_gates(keys.world.switches[1].opens)
	check(Guidance.next_step(keys,[]).phase=="grow" and Guidance.next_step(keys,[]).title=="The gate is open","Both touched keys remove the obsolete key instruction")
	var mirror=attempt(19,Levels.starter())
	mirror.step(1.5)
	mirror.world.goals[0].reached=true
	var second: Dictionary=Guidance.next_step(mirror,[])
	check(second.phase=="prune_next" and second.target_index==1 and second.goals_done==1,"Mirror Wells points at the currently awake second well")
	mirror.world.goals[1].reached=true
	check(Guidance.next_step(mirror,[]).target_index==2,"The final upper well is selected only after its predecessor wakes")
	mirror.world.goals[2].reached=true
	check(Guidance.next_step(mirror,[]).phase=="complete","Completed real goal flags override further tools or gift suggestions")
	var draft=attempt(16,Levels.starter())
	check(Guidance.next_step(draft,[]).phase=="updraft" and Guidance.next_step(draft,[]).target_kind=="updraft","Initial updraft guidance highlights the environmental current")
	draft.plant.tips[0].carried=true
	check(Guidance.next_step(draft,[]).phase=="grow","A shoot already carried by the current is told to head for the well")
	# Recovery describes this attempt instead of replaying a historical failure.
	var recovering=attempt(0,Levels.starter())
	recovering.step(2.0)
	stop_plant(recovering)
	check(Guidance.next_step(recovering,[]).phase=="prune","Stopped growth with a living cuttable stem offers real recovery")
	recovering.plant.energy=0.0
	check(Guidance.next_step(recovering,[]).phase=="recover_sap","Current sap exhaustion is identified from the plant itself")
	recovering.prunes_left=0
	check(Guidance.next_step(recovering,[]).phase=="retry","No cuts remain, so recovery does not promise an unavailable prune")
	var failed_pollination=attempt(2,Levels.starter())
	stop_plant(failed_pollination)
	failed_pollination.prunes_left=0
	check(Guidance.next_step(failed_pollination,[]).phase=="retry_pollination","A stopped giftless plant is told to retry contact, not to steer a dead shoot into crystal")
	# Read current stalled leaders even if the render loop drained all events.
	var dark=attempt(3,Levels.starter())
	dark.plant.pos[int(dark.plant.tips[0].node)]=dark.world.darks[0].pos
	dark.plant.tips[0].state="stalled"
	dark.plant.events.clear()
	var dark_help: Dictionary=Guidance.next_step(dark,[])
	check(dark_help.current_issue.reason=="dark" and dark_help.why.contains("currently stalled in darkness"),"A live dark stall is diagnosed from tip state and actual geometry without historical events")
	check(dark_help.phase=="pollinate" and dark_help.action.contains("Lanternwort"),"The useful action still supplies the missing Glow before trying the dark barrier")
	var unexpected_dark=attempt(0,Levels.starter())
	unexpected_dark.world.darks.append({"pos":unexpected_dark.plant.pos[1],"r":80.0})
	unexpected_dark.plant.tips[0].state="stalled"
	check(Guidance.next_step(unexpected_dark,[]).phase=="dark","Current dark geometry is explained even outside a named gift lesson")
	var latest=attempt(0,Levels.starter())
	for frame in range(60): latest.step(1.0/30.0)
	for tip_record: Dictionary in latest.plant.tips:
		latest.plant._stop(tip_record,"burn",latest.plant.pos[int(tip_record.node)])
	latest.plant._spawn_tip(int(latest.plant.tips[0].node),Vector2.UP,0)
	var newer: Dictionary=latest.plant.tips.back()
	latest.plant._stop(newer,"droop",latest.plant.pos[int(newer.node)])
	latest.plant.events.clear()
	latest.idle_time=2.0
	var latest_help: Dictionary=Guidance.next_step(latest,[])
	check(latest_help.current_issue.reason=="droop" and not latest_help.why.contains("withered"),"Latest stopped leader replaces an obsolete older branch's burn diagnosis")
	var on_living_segment: bool=false
	for index in range(1,latest.plant.pos.size()):
		var parent_index: int=int(latest.plant.parent[index])
		if int(latest.plant.alive[index])==1 and int(latest.plant.kind[index])==0 and parent_index>=0 and latest.plant.pos[index].distance_to(latest.plant.pos[parent_index])>0.5:
			if Geometry2D.get_closest_point_to_segment(latest_help.target,latest.plant.pos[index],latest.plant.pos[parent_index]).distance_to(latest_help.target)<0.01: on_living_segment=true
	check(latest_help.phase=="prune" and on_living_segment and latest_help.target!=latest.world.seed_pos,"Recovery focuses a real living stem segment suitable for a swipe, not the seed origin")
	latest.plant._spawn_tip(int(newer.node),Vector2.UP,0)
	latest.idle_time=0.0
	var healthy_help: Dictionary=Guidance.next_step(latest,[])
	check(healthy_help.phase=="grow" and healthy_help.current_issue.reason.is_empty() and not healthy_help.why.contains("drooped"),"A fresh growing leader clears old stop diagnoses immediately")
	var roots_only=attempt(5,gifts(["roots"]))
	for frame in range(30): roots_only.step(1.0/30.0)
	for tip_record: Dictionary in roots_only.plant.tips:
		if int(tip_record.kind)==0: roots_only.plant._stop(tip_record,"blocked",roots_only.plant.pos[int(tip_record.node)])
	roots_only.idle_time=0.0
	check(roots_only.plant.is_growing(),"The root fixture is still genuinely growing underground")
	check(Guidance.next_step(roots_only,[]).phase=="prune","Root activity does not hide that every above-ground shoot has stopped")
	var seed_snapshot: Array=[glow,thorn,both,children[0]]
	var before: String=signature(crystal,seed_snapshot)
	for index in range(5):
		Guidance.next_step(crystal,seed_snapshot)
		Guidance.level_info(levels[6])
		Guidance.recommend_seed(levels[6],seed_snapshot)
	check(signature(crystal,seed_snapshot)==before,"Repeated HUD and seed-card queries leave genomes, physics, tools, world progress and seeds unchanged")
	check(Guidance.next_step(null,[]).phase=="choose_seed","No attempt yields a harmless seed-choice instruction")
	print("GUIDANCE TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
