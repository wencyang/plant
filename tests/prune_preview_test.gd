extends SceneTree
## Preview must match the paused tree's actual sequential prune_path without
## spending a tool, changing any plant data, or consuming future growth RNG.
const Plant := preload("res://scripts/plant_sim.gd")
const World := preload("res://scripts/world_sim.gd")
const Levels := preload("res://scripts/levels.gd")
const Session := preload("res://scripts/session.gd")
var checks: int=0
var failures: int=0

func _initialize() -> void: call_deferred("run")
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:
		failures+=1
		push_error("PRUNE PREVIEW: "+message)

func tree():
	var p=Plant.new()
	p.genome=Levels.starter()
	p.rng.seed=612
	p.world=World.new()
	p.world.load_level({"seed":Vector2(100,300),"goals":[],"rocks":[]})
	p.energy=100.0
	p.energy_max=100.0
	p._add_node(Vector2(100,300),-1,0) # 0 base
	p._add_node(Vector2(100,250),0,0) # 1 trunk
	p._add_node(Vector2(100,200),1,0) # 2 branch junction
	p._add_node(Vector2(50,200),2,0) # 3 left branch
	p._add_node(Vector2(50,150),3,0) # 4 left tip
	p._add_node(Vector2(150,200),2,0) # 5 right branch
	p._add_node(Vector2(150,150),5,0) # 6 right tip
	p._add_node(Vector2(100,350),0,1) # 7 root
	p._add_node(Vector2(100,400),7,1) # 8 root tip
	p.tips=[{"node":4,"state":"grow","kind":0,"rank":0,"dir":Vector2.UP},
		{"node":6,"state":"grow","kind":0,"rank":0,"dir":Vector2.UP},
		{"node":8,"state":"grow","kind":1,"rank":0,"dir":Vector2.DOWN}]
	p.blooms=[4,6]
	p.fruits=[5]
	return p

func signature(p) -> String:
	return var_to_str([p.genome,p.wild,p.rng.seed,p.rng.state,p.pos,p.parent,p.born,p.desc,p.kind,p.alive,p.children,p.tips,p.blooms,p.fruits,
		p.energy,p.energy_max,p.grown,p.time,p.events,p.world.rocks,p.world.crystals,p.world.goals,p.world.wilds,p.world.lures,p.world.time])

func ids(segments: Array,max_node: int=-1) -> Array:
	var found: Array=[]
	for segment in segments:
		var id: int=int(segment[2])
		if max_node>=0 and id>=max_node: continue
		if not found.has(id): found.append(id)
	found.sort()
	return found

func sorted(values: Array) -> Array:
	var result: Array=values.duplicate()
	result.sort()
	return result

func apply_path(p,points: Array) -> Array:
	var removed: Array=[]
	for index in range(points.size()-1): removed.append_array(p.prune(points[index],points[index+1]))
	return removed

func matches_actual(p,points: Array,context: String) -> Dictionary:
	var before: String=signature(p)
	var before_count: int=p.pos.size()
	var before_energy: float=p.energy
	var preview: Dictionary=p.preview_prune_path(points)
	check(signature(p)==before,context+" preview changes no plant, world, event or RNG state")
	var actual: Array=apply_path(p,points)
	check(sorted(preview.removed_node_ids)==ids(actual,before_count),context+" lists the exact original nodes removed by the actual path")
	check(sorted(preview.all_removed_node_ids)==ids(actual),context+" includes any temporary tips removed by later curved-path pieces")
	check(is_equal_approx(float(preview.sap_refund),p.energy-before_energy),context+" predicts the actual sap refund")
	check(bool(preview.has_hits)==not actual.is_empty(),context+" hit status matches actual pruning")
	var new_tips: Array=[]
	for tip: Dictionary in p.tips:
		if int(tip.node)>=before_count and int(tip.kind)==0 and int(p.alive[int(tip.node)])==1: new_tips.append(tip)
	check(int(preview.new_shoots)==new_tips.size(),context+" predicts the exact surviving new-shoot count")
	check(preview.new_shoot_positions.size()==new_tips.size() and preview.new_shoot_directions.size()==new_tips.size(),context+" provides one real anchor and direction per surviving new shoot")
	for index in range(new_tips.size()):
		var tip: Dictionary=new_tips[index]
		check(preview.new_shoot_positions[index].is_equal_approx(p.pos[int(tip.node)]),context+" ghost shoot starts at its actual retained parent")
		check(preview.new_shoot_directions[index].is_equal_approx(tip.dir),context+" ghost shoot follows the actual split direction")
	return preview

func run() -> void:
	var air=tree()
	var air_before: String=signature(air)
	var empty: Dictionary=air.preview_prune_path([Vector2(0,0),Vector2(10,10)])
	check(not empty.has_hits and empty.cuts.is_empty() and empty.removed_node_ids.is_empty(),"Empty air does not promise a cut or highlight a branch")
	check(empty.sap_refund==0.0 and empty.new_shoots==0,"Empty air promises neither sap nor shoots")
	check(signature(air)==air_before,"Empty-air preview is completely pure")
	check(not air.preview_prune_path([Vector2(100,325),Vector2(100,375)]).has_hits,"A swipe along a root never becomes a shoot cut")
	check(not air.preview_prune_path([Vector2(80,325),Vector2(120,325)]).has_hits,"A swipe crossing only a root never prunes it")
	check(not air.preview_prune_path([]).has_hits and not air.preview_prune_path([Vector2.ZERO]).has_hits,"A click or an unfinished path is harmless")
	check(not air.preview_prune_path([Vector2.ZERO,"bad point"]).valid,"Malformed points fail safely without mutating anything")
	var simple=tree()
	var one: Dictionary=matches_actual(simple,[Vector2(70,225),Vector2(130,225)],"Single trunk cut")
	check(sorted(one.removed_node_ids)==[2,3,4,5,6],"Cutting the trunk removes its actual descendant branches")
	check(one.cuts.size()==1 and one.new_shoots==2,"One ordinary cut creates the actual two shoots")
	check(one.cut_positions[0].is_equal_approx(Vector2(100,225)),"The cut marker uses the swipe's exact intersection")
	check(one.cuts[0].anchor.is_equal_approx(Vector2(100,250)),"Ghost shoots use the actual parent anchor rather than the middle of the removed segment")
	check(is_equal_approx(float(one.sap_refund),150.0),"Five 50-unit segments return the actual 60 percent sap")
	check(int(simple.alive[7])==1 and int(simple.alive[8])==1,"Actual roots survive the trunk cut")
	var split=tree()
	var two: Dictionary=matches_actual(split,[Vector2(25,175),Vector2(175,175)],"Two disjoint branches")
	check(two.cuts.size()==2 and two.new_shoots==4,"A line through two separate branches previews both real split pairs")
	var nested=tree()
	var junction: Dictionary=matches_actual(nested,[Vector2(25,200),Vector2(175,200)],"Shared junction")
	check(junction.crossed_node_ids.size()>junction.cuts.size(),"A swipe can intersect several edges at one branch junction")
	check(junction.cuts.size()==1 and junction.new_shoots==2,"Nested hits do not invent extra splits above a branch already removed")
	var curve=tree()
	var curve_points: Array=[Vector2(25,175),Vector2(75,175),Vector2(75,225),Vector2(175,225),Vector2(175,175),Vector2(125,175)]
	var curved: Dictionary=matches_actual(curve,curve_points,"Curved swipe with later lower cuts")
	check(curved.cuts.size()==3,"The real polyline is respected instead of connecting only its first and last points")
	check(curved.all_removed_node_ids.size()>curved.removed_node_ids.size(),"Temporary fresh tips removed later are distinct from the original visible tree")
	check(curved.new_shoots==2,"Only the final surviving split produces ghost shoots")
	check(not curved.cuts[0].survives and curved.cuts[0].directions.is_empty(),"A later lower cut removes obsolete earlier ghost arrows")
	var repeated=tree()
	var repeat: Dictionary=matches_actual(repeated,[Vector2(70,225),Vector2(130,225),Vector2(70,225),Vector2(130,225)],"Repeated crossing of one removed branch")
	check(repeat.cuts.size()==1 and repeat.new_shoots==2,"Re-crossing removed growth does not charge extra cuts or add fake shoots")
	var detached=tree()
	detached.prune(Vector2(125,175),Vector2(125,225))
	var dead_before: String=signature(detached)
	check(not detached.preview_prune_path([Vector2(130,175),Vector2(170,175)]).has_hits,"Detached dead growth is never a new swipe target")
	var live_preview: Dictionary=detached.preview_prune_path([Vector2(70,225),Vector2(130,225)])
	check(not live_preview.removed_node_ids.has(5) and not live_preview.removed_node_ids.has(6),"A later trunk preview excludes already detached dead branches")
	check(signature(detached)==dead_before,"Querying an already pruned tree remains pure")
	var marked=tree()
	marked.alive[4]=0
	check(marked.tips.size()==3 and marked.active_tips()==2,"A newly dead tip frees capacity before the deferred tips-list cleanup")
	var full_trunk=tree()
	for index in range(Plant.MAX_TIPS-full_trunk.active_tips()): full_trunk._spawn_tip(0,Vector2.UP,0)
	check(full_trunk.active_tips()==Plant.MAX_TIPS,"Capacity fixture reaches the real active-tip cap")
	var recovered: Dictionary=matches_actual(full_trunk,[Vector2(70,225),Vector2(130,225)],"Trunk recovery at full tip capacity")
	check(recovered.new_shoots==2 and recovered.cuts[0].directions.size()==2,"Removing two active branches at capacity restores both replacement shoots")
	check(full_trunk.active_tips()==Plant.MAX_TIPS,"Two freed slots are reused without exceeding the active-tip cap")
	var full=tree()
	for index in range(Plant.MAX_TIPS-full.active_tips()): full._spawn_tip(0,Vector2.UP,0)
	var capped: Dictionary=matches_actual(full,[Vector2(125,175),Vector2(125,225)],"Single-branch cut at full tip capacity")
	check(capped.has_hits and capped.new_shoots==1 and capped.cuts[0].directions.size()==1,"Removing one active tip at capacity permits exactly one real replacement")
	check(full.active_tips()==Plant.MAX_TIPS,"A one-slot replacement never exceeds the cap")
	var stopped_branch=tree()
	stopped_branch.tips[0].state="stopped"
	stopped_branch.tips[1].state="stopped"
	for index in range(Plant.MAX_TIPS-stopped_branch.active_tips()): stopped_branch._spawn_tip(0,Vector2.UP,0)
	var no_room: Dictionary=matches_actual(stopped_branch,[Vector2(125,175),Vector2(125,225)],"Stopped branch cut without freeing active slots")
	check(no_room.has_hits and no_room.new_shoots==0 and no_room.cuts[0].directions.is_empty(),"Cutting only inactive growth creates no shoots while all active slots remain occupied")
	check(stopped_branch.active_tips()==Plant.MAX_TIPS,"Inactive-branch pruning cannot bypass active-tip capacity")
	var last_slot=tree()
	for index in range(Plant.MAX_TIPS-last_slot.active_tips()-1): last_slot._spawn_tip(0,Vector2.UP,0)
	var single: Dictionary=matches_actual(last_slot,[Vector2(125,175),Vector2(125,225)],"One free slot plus one slot released by the cut")
	check(single.new_shoots==2 and single.new_shoot_directions.size()==2,"An existing free slot and a newly freed slot permit the actual two-shoot split")
	check(last_slot.active_tips()==Plant.MAX_TIPS,"Combined existing and recovered capacity still respects the cap")
	var three_slots=tree()
	for index in range(Plant.MAX_TIPS-three_slots.active_tips()-3): three_slots._spawn_tip(0,Vector2.UP,0)
	var three: Dictionary=matches_actual(three_slots,[Vector2(25,175),Vector2(175,175)],"Capacity released across two independent cuts")
	check(three.new_shoots==4 and three.cuts[0].new_shoots==2 and three.cuts[1].new_shoots==2,"Each cut immediately reclaims its removed active capacity before spawning")
	check(three_slots.active_tips()<=Plant.MAX_TIPS,"Several cut roots cannot overfill the active-tip limit")
	var full_curve=tree()
	for index in range(Plant.MAX_TIPS-full_curve.active_tips()): full_curve._spawn_tip(0,Vector2.UP,0)
	var curved_cap: Dictionary=matches_actual(full_curve,curve_points,"Curved recovery at full capacity")
	check(curved_cap.new_shoots==2 and full_curve.active_tips()<=Plant.MAX_TIPS,"A later lower cut reclaims earlier replacement tips and leaves only the final live pair")
	check(curved_cap.cuts[0].spawned_shoots==1 and curved_cap.cuts[1].spawned_shoots==1 and curved_cap.cuts[2].spawned_shoots==2,"Preview reads actual sequential spawn records rather than a pre-cut capacity approximation")
	# An actual paused Twin Wells attempt exercises live simulated geometry and
	# Session's real sequential path behavior, rather than only authored fixtures.
	var session=Session.new()
	session.start(Levels.all()[1],Levels.starter(),5)
	for frame in range(60): session.step(1.0/30.0)
	var original_count: int=session.plant.pos.size()
	var original_energy: float=session.plant.energy
	var session_before: String=signature(session.plant)
	var stock: int=session.prunes_left
	var used: int=session.tools_used
	var actual_points: Array=[Vector2(720,770),Vector2(805,780),Vector2(880,770)]
	var actual_preview: Dictionary=session.plant.preview_prune_path(actual_points)
	check(signature(session.plant)==session_before and session.prunes_left==stock and session.tools_used==used,"Previewing a real session spends neither tools nor energy")
	var actual: Array=session.prune_path(actual_points)
	check(actual_preview.has_hits and ids(actual,original_count)==sorted(actual_preview.removed_node_ids),"The curved preview matches Session.prune_path on a real growing tree")
	check(is_equal_approx(float(actual_preview.sap_refund),session.plant.energy-original_energy),"Real session sap recovery matches the preview")
	check(session.prunes_left==stock-1 and session.tools_used==used+1,"The actual whole path still costs one pruning tool")
	# A preview is a query: future random growth must be identical to a control.
	var observed=Session.new()
	var control=Session.new()
	observed.start(Levels.all()[0],Levels.starter(),321)
	control.start(Levels.all()[0],Levels.starter(),321)
	for frame in range(45): observed.step(1.0/30.0); control.step(1.0/30.0)
	for repeat_index in range(10): observed.plant.preview_prune_path([Vector2(200,800),Vector2(400,800),Vector2(500,700)])
	check(observed.plant.rng.state==control.plant.rng.state,"Repeated preview leaves the original RNG state untouched")
	for frame in range(180): observed.step(1.0/30.0); control.step(1.0/30.0)
	check(signature(observed.plant)==signature(control.plant),"Subsequent real-time growth remains exactly identical after previews")
	print("PRUNE PREVIEW TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
