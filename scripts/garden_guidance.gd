extends RefCounted
## Read-only guidance for Bloomward's authored gardens. Gifts describe the
## intended puzzle route, not a promise that a particular seed will win.
## No simulation, random rolls, saved data, or tool actions are performed here.
const Genome := preload("res://scripts/genome.gd")
const Levels := preload("res://scripts/levels.gd")

# These requirements are authored against levels.gd geometry and solve_test.gd.
# In particular, an environmental hazard alone does not imply a required gift:
# False Dawn avoids its heat, and Updraft Spires uses a current instead of Float.
const PROFILES := {
	"first_light": {
		"required_gifts": [], "learning_focus": "Light and support",
		"brief": "Grow into the golden sunwell above the stone shelves.",
		"action": "Let the shoot grow toward the sunwell. Place or drag a light lure if you want to change its course.",
		"why": "Shoots follow light automatically. Nearby stone supports the stem so it can keep reaching.",
		"steps": ["Plant any seed.", "Watch the shoot follow light and lean on stone.", "Touch the golden sunwell with a living shoot."]},
	"twin_wells": {
		"required_gifts": [], "learning_focus": "Pruning creates two shoots",
		"brief": "Wake both sunwells, one to either side of the seed.",
		"action": "Let a short stem grow, then swipe across the young stem to split it toward the two wells.",
		"why": "A successful cut wakes two fresh shoots. Each can follow a different sunwell.",
		"steps": ["Grow a short stem above the seed.", "Swipe across the stem along the dotted cut marker.", "Let the two new shoots reach the left and right wells."]},
	"crystal_throat": {
		"required_gifts": ["thorns"], "learning_focus": "Pollinate, then replant",
		"brief": "Break the crystal sealing the narrow passage and reach the sunwell above it.",
		"action": "Guide a thorny shoot into the crystal in the middle opening.",
		"why": "Thorns shatter crystal on contact. A plain shoot cannot break that seal.",
		"steps": ["Touch the wild Spinebrush on the left ledge to make hybrid seeds.", "Plant a seed with Thorns; the first hybrid seed keeps both parents' gifts.", "Guide its thorny shoot through the crystal toward the sunwell."]},
	"lanternless": {
		"required_gifts": ["glow"], "learning_focus": "Carry light into darkness",
		"brief": "Reach the sunwell inside the dark pool on the right.",
		"action": "Grow a glowing shoot toward the sunwell inside the dark area.",
		"why": "Glow travels with the plant. Lures cannot be placed inside darkness.",
		"steps": ["Touch Lanternwort near the middle shelf.", "Plant a seed carrying Glow.", "Let its own light carry it into the dark area."]},
	"glass_cliff": {
		"required_gifts": ["tendrils"], "learning_focus": "Climb glassy rock",
		"brief": "Climb the glass cliff on the right and reach the sunwell above its top.",
		"action": "Guide a shoot with Tendrils onto the glass cliff and up toward the sunwell.",
		"why": "Tendrils grip slick rock; ordinary shoots slip instead of climbing it.",
		"steps": ["Touch Hookvine on the left shelf.", "Plant a seed carrying Tendrils.", "Guide it onto the glass cliff to climb."]},
	"thirst": {
		"required_gifts": ["roots"], "learning_focus": "Roots refill sap",
		"brief": "Drink the underground water, then reach the high sunwell on the right.",
		"action": "Let the roots grow down into the water under the soil while the shoot grows upward.",
		"why": "This garden starts with little sap. Roots refill it when they reach water.",
		"steps": ["Touch Deeproot to make a seed carrying Roots.", "Replant it and let its roots find the underground water.", "Use the renewed sap to reach the high sunwell."]},
	"shattered_spire": {
		"required_gifts": ["thorns", "glow"], "learning_focus": "Combine two gifts in one seed",
		"brief": "One shoot must break the crystal and grow into the dark spire.",
		"action": "Guide a shoot carrying both Thorns and Glow through the crystal into the dark sunwell.",
		"why": "Thorns break the crystal seal; Glow lets the same shoot continue through the night above it.",
		"steps": ["Bring a Thorns seed from Crystal Throat.", "Touch this garden's Lanternwort, then plant its first hybrid seed.", "Use the seed carrying Thorns and Glow to pass both obstacles."]},
	"heart_grove": {
		"required_gifts": ["thorns", "glow", "tendrils"], "learning_focus": "Keep earlier gifts while adding a new one", "carry_from":"shattered_spire",
		"brief": "Wake both sunwells beyond glass, crystal and darkness.",
		"action": "Climb the central glass spire, then guide a shoot through the crystal toward the dark well on the right.",
		"why": "This route uses Tendrils to climb, Thorns to break the seal, and Glow to continue inside the darkness.",
		"steps": ["Bring your Thorns-and-Glow seed from Shattered Spire.", "Touch Hookvine and replant the first hybrid seed to add Tendrils.", "Climb to the first well, then guide a shoot to the sealed dark well."]},
	"drift_chasm": {
		"required_gifts": ["buoyant"], "learning_focus": "Cross open air",
		"brief": "Grow across the unsupported gap to the sunwell on the far bank.",
		"action": "Guide a Buoyant shoot across the gap and toward support on the far side.",
		"why": "Floating bladders extend how far a stem can grow without rock to lean on.",
		"steps": ["Touch Driftcap near the edge of your bank.", "Plant a seed carrying Buoyant.", "Guide it across the chasm and onto the far bank."]},
	"ember_vents": {
		"required_gifts": ["waxy"], "learning_focus": "Grow through heat",
		"brief": "Pass the wall of ember vents and reach the sunwell on the right.",
		"action": "Guide a Waxy shoot through the ember vents toward the right-hand sunwell.",
		"why": "Waxy skin protects growing shoots from the heat.",
		"steps": ["Touch Emberwax on your side of the vents.", "Plant a seed carrying Waxy.", "Grow through the heat to the sunwell."]},
	"moon_garden": {
		"required_gifts": ["glow", "roots"], "learning_focus": "One wild parent can supply two gifts",
		"brief": "Refill your sap underground and reach the sunwell inside the night on the right.",
		"action": "Let Roots drink underground while a glowing shoot reaches the dark sunwell.",
		"why": "The small sap reserve calls for Roots; the final dark area calls for Glow. Moonpetal carries both.",
		"steps": ["Touch Moonpetal beside the seed bed.", "Plant a seed with both Glow and Roots.", "Let the roots refill sap as the shoot grows toward the dark well."]},
	"briar_gate": {
		"required_gifts": ["thorns", "tendrils"], "learning_focus": "Climb, then break through",
		"brief": "Climb the glass spire and break the crystal gate above it.",
		"action": "Guide a shoot with Tendrils up the glass spire, then into the crystal with Thorns.",
		"why": "Tendrils grip the glass; Thorns break the crystal cap. Briarbell carries both gifts.",
		"steps": ["Guide a shoot left to touch Briarbell.", "Plant a seed with Thorns and Tendrils.", "Climb the glass and shatter the crystal to reach the well."]},
	"coral_steps": {
		"required_gifts": [], "learning_focus": "Branch after the first sunwell",
		"brief": "Wake the middle sunwell, then the wells on the two coral shelves.",
		"action": "Reach the middle sunwell first. After it wakes, prune low on the stem to send new shoots outward.",
		"why": "This is a branching puzzle. Extra gifts are optional; pruning creates the new directions you need.",
		"steps": ["Let the first shoot reach the middle well.", "Swipe low across its stem after that well wakes.", "Guide the fresh shoots to the left and right wells."]},
	"long_bloom": {
		"required_gifts": ["glow", "buoyant", "waxy"], "learning_focus": "Breed across several attempts",
		"brief": "Cross the chasm, survive the vents and reach the sunwell inside darkness.",
		"action": "Guide a seed carrying Glow, Buoyant and Waxy across the gap, through heat and into the dark well.",
		"why": "The gap needs floating reach, the vents need waxy skin, and the last well is inside darkness.",
		"steps": ["Bring a Glow seed.", "Touch Driftcap and replant a seed that keeps Glow and adds Buoyant.", "Touch Emberwax and replant a seed that keeps both gifts and adds Waxy.", "Guide the combined seed toward support on the far bank, then through the heat."]},
	"lockstone": {
		"required_gifts": [], "learning_focus": "Lures can steer downward",
		"brief": "Touch the gold key-bloom in the pit to open the stone gate, then reach the sunwell.",
		"action": "Place or drag a light lure down into the pit so a shoot touches the gold key-bloom.",
		"why": "This is a switch puzzle, not a gift lock. Shoots follow lures downward as well as upward.",
		"steps": ["Steer a shoot down into the pit toward the gold bud.", "Touching the bud opens the matching stone gate.", "Move the lure toward the sunwell inside the open chamber."]},
	"false_dawn": {
		"required_gifts": [], "learning_focus": "Distinguish lures from decoys",
		"brief": "Lead the shoot right to the sunwell, away from the violet wisp and the vents on the left.",
		"action": "Place or drag a lure on the safe right-hand route, nearer the growing shoot than the violet wisp.",
		"why": "The moving wisp is false light. A nearer lure can lead the shoot away from the dangerous route; Waxy is optional.",
		"steps": ["Notice the violet decoy drifting above the left-hand vents.", "Use your own lure to lead the shoot right, away from that heat.", "Keep steering toward the sunwell on the right."]},
	"updraft_spires": {
		"required_gifts": [], "learning_focus": "Use the environment as support",
		"brief": "Ride the rising current to reach the sunwell high above.",
		"action": "Place or drag a lure sideways into the rising air current, then let it carry the shoot upward.",
		"why": "The updraft supports a shoot in open air. This route does not require the Buoyant gift.",
		"steps": ["Steer left from the seed into the visible rising current.", "Let the current carry the shoot upward without drooping.", "Guide the shoot out toward the high sunwell."]},
	"two_keys": {
		"required_gifts": [], "learning_focus": "Chain light-lure waypoints",
		"brief": "Touch both gold key-blooms to open the two doors below the sunwell.",
		"action": "Chain your two lures through the left key-bloom, then the key-bloom beside the chamber.",
		"why": "Each key opens one stone door. A shoot visits a lure, then moves on to the next waypoint.",
		"steps": ["Lead the shoot through the first gold key on the left.", "Continue toward the second gold key beside the chamber.", "With both doors open, guide a shoot up to the sunwell."]},
	"sunken_bloom": {
		"required_gifts": ["glow"], "learning_focus": "Grow downward into darkness",
		"brief": "Find the narrow shaft and grow down into the dark cave to reach its fallen sunwell.",
		"action": "Guide a glowing shoot to the shaft opening, then down toward the sunwell in the cave.",
		"why": "Glow allows growth in the cave. Reaching the goal also requires steering down through the actual opening in the rock.",
		"steps": ["Touch the Lanternwort to the left if you need Glow.", "Plant a glowing seed.", "Steer toward the shaft mouth, then descend into the cave."]},
	"mirror_wells": {
		"required_gifts": [], "learning_focus": "Wake ordered sunwells",
		"brief": "Wake the left, right and upper sunwells in that order.",
		"action": "Wake the first well on the left, then prune low to send a new shoot toward the next awake target.",
		"why": "Each well wakes only after the previous one. Pruning renews the shoot after its earlier branch has passed the next target.",
		"steps": ["Reach the first sunwell on the left.", "Prune low to reach the newly available well on the right.", "Prune again and reach the final upper well."]},
	"heartwood": {
		"required_gifts": ["glow", "waxy"], "learning_focus": "Combine gifts with environmental tools",
		"brief": "Ride the current to the key-bloom, pass the heat and reach the sunwell inside the dark heartwood.",
		"action": "Guide a glowing, Waxy shoot into the updraft to touch the high gold key, then through the open gate.",
		"why": "Waxy protects against the vent wall and Glow works inside the heartwood. The current and key-bloom solve the height and stone gate.",
		"steps": ["Use a seed with Glow and Waxy, or add them from the two wild plants here.", "Lead a shoot into the updraft and touch the high gold key.", "Lead it through the heat and open gate toward the dark sunwell."]},
}

const GIFT_REASONS := {
	"thorns": "Thorns break crystal when a growing shoot touches it.",
	"glow": "Glow lets shoots continue growing inside darkness.",
	"tendrils": "Tendrils grip and climb glassy rock.",
	"roots": "Roots drink underground water to refill sap.",
	"buoyant": "Buoyant bladders extend a stem's unsupported reach across open air.",
	"waxy": "Waxy skin protects growing shoots from ember vents.",
}
const SOURCE_GARDENS := {"thorns":"crystal_throat", "glow":"lanternless", "tendrils":"glass_cliff", "roots":"thirst", "buoyant":"drift_chasm", "waxy":"ember_vents"}

static func _profile(level: Dictionary) -> Dictionary:
	var id: String=str(level.get("id",""))
	var data: Dictionary=PROFILES.get(id,{}).duplicate(true)
	# A future authored level may provide its own explicit guidance. Geometry is
	# never guessed to mean 'all vents need Waxy' or 'all gaps need Buoyant'.
	var authored: Variant=level.get("guidance",{})
	if authored is Dictionary and not authored.is_empty(): data.merge(authored.duplicate(true),true)
	return data

static func gift_names(gifts: Array) -> String:
	var names: Array[String]=[]
	for key: Variant in gifts:
		if Genome.TRAIT_INFO.has(str(key)): names.append(str(Genome.TRAIT_INFO[str(key)].name))
	return " + ".join(names)

static func level_info(level: Dictionary) -> Dictionary:
	var profile: Dictionary=_profile(level)
	var gifts: Array[String]=[]
	for key: Variant in profile.get("required_gifts",[]):
		if Genome.TRAITS.has(str(key)) and not gifts.has(str(key)): gifts.append(str(key))
	var reasons: Dictionary={}
	for key: String in gifts: reasons[key]=str(GIFT_REASONS[key])
	var wild_sources: Array=[]
	for wild: Dictionary in level.get("wilds",[]):
		var genome: Dictionary=wild.genome if wild.get("genome") is Dictionary else Levels.wild(str(wild.get("genome","")))
		var relevant: Array[String]=[]
		for key: String in gifts:
			if int(genome.get(key,0))>0: relevant.append(key)
		wild_sources.append({"name":str(genome.get("name","Wild plant")),"gifts":Genome.traits(genome),"useful_gifts":relevant,"pos":wild.get("pos",Vector2.ZERO)})
	var count: int=level.get("goals",[]).size()
	return {"id":str(level.get("id","")),"title":str(level.get("title","Garden")),"authored":not profile.is_empty(),
		"required_gifts":gifts,"gift_reasons":reasons,"learning_focus":str(profile.get("learning_focus","Guide living growth")),
		"brief":str(profile.get("brief","Grow a living shoot into every golden sunwell.")),
		"objective":"Wake %d sunwell%s." % [count,"" if count==1 else "s"],
		"action":str(profile.get("action","Watch the shoot grow toward light; place or drag a lure to steer it.")),
		"why":str(profile.get("why","A living shoot wakes a golden sunwell when it touches it.")),
		"steps":profile.get("steps",[]).duplicate(true),"wild_sources":wild_sources,"carry_from":str(profile.get("carry_from",""))}

static func seed_fit(level: Dictionary,genome: Dictionary) -> Dictionary:
	var info: Dictionary=level_info(level)
	var present: Array[String]=[]
	var missing: Array[String]=[]
	for key: String in info.required_gifts:
		if int(genome.get(key,0))>0: present.append(key)
		else: missing.append(key)
	var additions: Array[String]=[]
	var elsewhere: Array[String]=[]
	var carry_gifts: Array[String]=[]
	for key: String in info.required_gifts:
		var locally_available: bool=false
		for source: Dictionary in info.wild_sources:
			if source.gifts.has(key): locally_available=true
		if not locally_available: carry_gifts.append(key)
	var donors: Array[String]=[]
	for key: String in missing:
		var supplied: bool=false
		for source: Dictionary in info.wild_sources:
			if source.gifts.has(key):
				supplied=true
				if not donors.has(str(source.name)): donors.append(str(source.name))
		if supplied: additions.append(key)
		else: elsewhere.append(key)
	var ready: bool=missing.is_empty()
	var summary: String="No special gifts needed" if info.required_gifts.is_empty() else ("Gifts ready" if ready else "Missing: %s" % gift_names(missing))
	if not bool(info.authored): summary="Explore this garden"
	var why: String=str(info.why) if ready else "This garden's intended route uses %s. Pollination makes new seeds; it does not add gifts to the plant already growing." % gift_names(missing)
	var source_explanation: String="The useful gifts are already present. You still guide the plant's route."
	if info.required_gifts.is_empty(): source_explanation=str(info.why)
	elif not elsewhere.is_empty(): source_explanation="Start with a seed carrying %s; the wild plants here cannot supply those gifts." % gift_names(carry_gifts)
	elif not additions.is_empty(): source_explanation="Touch %s, then replant a hybrid seed to add %s." % [" or ".join(donors),gift_names(additions)]
	return {"ready":ready,"present":present,"missing":missing,"required_gifts":info.required_gifts.duplicate(),
		"matches":present.size(),"total":info.required_gifts.size(),"summary":summary,"why":why,"learning_focus":info.learning_focus,
		"learnable_here":elsewhere.is_empty(),"missing_elsewhere":elsewhere,"local_additions":additions,"carry_gifts":carry_gifts,"source_explanation":source_explanation,"authored":bool(info.authored)}

static func _better_fit(a: Dictionary,b: Dictionary) -> bool:
	# A seed that already carries an unavailable gift is a useful starting point
	# even when another seed has more gifts that can all be learned locally.
	if a.missing_elsewhere.size()!=b.missing_elsewhere.size(): return a.missing_elsewhere.size()<b.missing_elsewhere.size()
	return int(a.matches)>int(b.matches)

static func recommend_seed(level: Dictionary,seeds: Array) -> Dictionary:
	var best: Dictionary={"index":-1,"seed":{},"fit":{},"ready":false,"reason":"No seeds are available."}
	for index in range(seeds.size()):
		if not seeds[index] is Dictionary: continue
		var seed: Dictionary=seeds[index]
		var fit: Dictionary=seed_fit(level,seed)
		# Ties preserve vault order. Extra gifts, a fancy name or a generation
		# number do not invent suitability or guarantee a route through geometry.
		if int(best.index)>=0 and not _better_fit(fit,best.fit): continue
		var reason: String="Any seed can try this tool puzzle; no special gift is required." if int(fit.total)==0 else ("%s carries the gifts used by this garden. You still guide its growth." % str(seed.get("name","This seed")) if fit.ready else "%s already carries %s. %s" % [str(seed.get("name","This seed")),gift_names(fit.present) if not fit.present.is_empty() else "none of the useful gifts",str(fit.source_explanation)])
		best={"index":index,"seed":seed.duplicate(true),"fit":fit,"ready":bool(fit.ready),"reason":reason}
	return best

static func _living_segments(plant) -> bool:
	for index in range(1,plant.pos.size()):
		if int(plant.alive[index])==0 or int(plant.kind[index])!=0: continue
		var parent: int=int(plant.parent[index])
		if parent>=0 and plant.pos[index].distance_to(plant.pos[parent])>0.5: return true
	return false

static func _tip_position(plant) -> Vector2:
	var best: Dictionary={}
	for tip: Dictionary in plant.tips:
		var node: int=int(tip.get("node",-1))
		if int(tip.get("kind",0))!=0 or node<0 or node>=plant.pos.size() or int(plant.alive[node])==0: continue
		if str(tip.get("state","")) not in ["grow","stalled"]: continue
		if best.is_empty() or int(tip.get("rank",0))<int(best.get("rank",0)): best=tip
	if not best.is_empty(): return plant.pos[int(best.node)]
	# A stopped tip is still at its actual end, not back at the seed. Prefer
	# the most recently grown living leader rather than an old dead side branch.
	for index in range(plant.tips.size()-1,-1,-1):
		var tip: Dictionary=plant.tips[index]
		var node: int=int(tip.get("node",-1))
		if int(tip.get("kind",0))==0 and int(tip.get("rank",0))==0 and node>=0 and node<plant.pos.size() and int(plant.alive[node])==1:
			return plant.pos[node]
	for index in range(plant.pos.size()-1,0,-1):
		if int(plant.kind[index])==0 and int(plant.alive[index])==1: return plant.pos[index]
	return plant.pos[0] if not plant.pos.is_empty() else Vector2.ZERO

static func _cut_position(plant) -> Vector2:
	# Show an actual healthy segment low on the plant. A point on the seed or
	# on an already removed branch cannot demonstrate a valid swipe.
	for index in range(1,plant.pos.size()):
		if int(plant.alive[index])==0 or int(plant.kind[index])!=0: continue
		var parent: int=int(plant.parent[index])
		if parent>=0 and int(plant.alive[parent])==1 and plant.pos[index].distance_to(plant.pos[parent])>0.5:
			return (plant.pos[index]+plant.pos[parent])*0.5
	return _tip_position(plant)

static func _current_issue(session) -> Dictionary:
	var plant=session.plant
	var moving: Array=[]
	for tip: Dictionary in plant.tips:
		var node: int=int(tip.get("node",-1))
		if int(tip.get("kind",0))!=0 or node<0 or node>=plant.pos.size() or int(plant.alive[node])==0: continue
		if str(tip.get("state","")) in ["grow","stalled"]: moving.append(tip)
	if not moving.is_empty():
		moving.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
			if int(a.get("rank",0))!=int(b.get("rank",0)): return int(a.get("rank",0))<int(b.get("rank",0))
			return str(a.get("state",""))=="grow" and str(b.get("state",""))!="grow")
		var leader: Dictionary=moving[0]
		var point: Vector2=plant.pos[int(leader.node)]
		if str(leader.state)=="stalled" and int(plant.genome.get("glow",0))==0 and session.world.in_dark(point) and not session.world.lure_near(point):
			return {"state":"dark","reason":"dark","pos":point,"explanation":"The leading shoot is currently stalled in darkness."}
		return {"state":"growing","reason":"","pos":point,"explanation":""}
	var best: Dictionary={}
	var newest: float=-INF
	for tip: Dictionary in plant.tips:
		var node: int=int(tip.get("node",-1))
		if int(tip.get("kind",0))!=0 or node<0 or node>=plant.pos.size() or int(plant.alive[node])==0 or str(tip.get("state",""))!="stopped": continue
		var time: float=float(plant.born[node])
		var leading: bool=int(tip.get("rank",0))==0
		var was_leading: bool=not best.is_empty() and int(best.get("rank",0))==0
		if best.is_empty() or (leading and not was_leading) or (leading==was_leading and time>=newest):
			best=tip
			newest=time
	var why: String=str(best.get("why",""))
	var explanation: String={"burn":"The latest leading shoot withered in an ember vent.","slick":"The latest leading shoot slipped on glassy rock.","droop":"The latest leading shoot drooped after reaching too far without support.","blocked":"The latest leading shoot met solid rock.","stuck":"The latest leading shoot became wedged."}.get(why,"")
	return {"state":"stopped","reason":why,"pos":_tip_position(plant),"explanation":explanation}

static func _wild_candidates(session,missing: Array) -> Array:
	var out: Array=[]
	var tip: Vector2=_tip_position(session.plant)
	for index in range(session.world.wilds.size()):
		var wild: Dictionary=session.world.wilds[index]
		var genome: Dictionary=wild.get("genome",{}) if wild.get("genome",{}) is Dictionary else Levels.wild(str(wild.get("genome","")))
		var adds: Array[String]=[]
		for key: String in missing:
			if int(genome.get(key,0))>0: adds.append(key)
		if adds.is_empty(): continue
		out.append({"index":index,"name":str(genome.get("name","Wild plant")),"genome":genome,"adds":adds,
			"pollinated":bool(wild.get("pollinated",false)),"pos":wild.get("pos",Vector2.ZERO),"distance":tip.distance_to(wild.get("pos",Vector2.ZERO))})
	out.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
		if a.adds.size()!=b.adds.size(): return a.adds.size()>b.adds.size()
		return float(a.distance)<float(b.distance))
	return out

static func _source_garden(gift: String,preferred_id: String="") -> Dictionary:
	var wanted: String=preferred_id if not preferred_id.is_empty() else str(SOURCE_GARDENS.get(gift,""))
	var levels: Array=Levels.all()
	for index in range(levels.size()):
		if str(levels[index].id)==wanted: return {"id":wanted,"title":str(levels[index].title),"index":index}
	return {}

static func _result(base: Dictionary,phase: String,title: String,action: String,why: String,target_kind: String="",target: Vector2=Vector2.INF,target_index: int=-1) -> Dictionary:
	var result: Dictionary=base.duplicate(true)
	var current: Dictionary=base.get("current_issue",{})
	var current_explanation: String=str(current.get("explanation",""))
	if phase!="complete" and not current_explanation.is_empty(): why=current_explanation+" "+why
	result.merge({"phase":phase,"title":title,"action":action,"why":why,"target_kind":target_kind,"target":target,"target_index":target_index},true)
	return result

static func next_step(session,seeds: Array=[]) -> Dictionary:
	if session==null or session.world==null or session.plant==null:
		return {"phase":"choose_seed","title":"Plant a seed","objective":"Wake the golden sunwells.","action":"Choose a seed to start this garden.","why":"Its shoots will grow toward light on their own.","target_kind":"vault","target":Vector2.INF,"target_index":-1,"missing_gifts":[],"required_gifts":[],"progress":""}
	var info: Dictionary=level_info(session.def)
	var fit: Dictionary=seed_fit(session.def,session.plant.genome)
	var recommendation: Dictionary=recommend_seed(session.def,seeds)
	var done: int=0
	var active_goal: int=-1
	for index in range(session.world.goals.size()):
		var goal: Dictionary=session.world.goals[index]
		if bool(goal.reached): done+=1
		elif active_goal<0 and not session.world.sleeping(goal): active_goal=index
	var total: int=session.world.goals.size()
	var issue: Dictionary=_current_issue(session)
	var base: Dictionary={"level_id":str(info.id),"objective":str(info.brief),"progress":"%d / %d sunwells awake" % [done,total],
		"goals_done":done,"goals_total":total,"required_gifts":info.required_gifts.duplicate(),"missing_gifts":fit.missing.duplicate(),
		"fit":fit,"recommendation":recommendation,"can_lure":int(session.lures_left)>0 or not session.world.lures.is_empty(),
		"can_prune":int(session.prunes_left)>0 and _living_segments(session.plant),"learning_focus":info.learning_focus,"current_issue":issue}
	if session.won():
		return _result(base,"complete","Every sunwell is awake","Continue to the next garden, or replay to collect more dew and improve your stars.","The growing shoot has reached every required sunwell.")
	var stopped: bool=session.stuck() or str(issue.state)=="stopped"
	var growing: bool=str(issue.state)=="growing" and session.plant.is_growing()
	var can_prune: bool=bool(base.can_prune)
	var missing: Array=fit.missing
	if not missing.is_empty():
		# A saved seed is already real. Prefer replanting it to sending an
		# unsuitable shoot into a barrier or making a redundant cross.
		if int(recommendation.get("index",-1))>=0 and _better_fit(recommendation.fit,fit):
			var seed_name: String=str(recommendation.seed.get("name","the recommended seed"))
			return _result(base,"replant","A better seed is in your vault","Plant %s from the Seed Vault." % seed_name,str(recommendation.reason),"vault",Vector2.INF,int(recommendation.index))
		var candidates: Array=_wild_candidates(session,missing)
		var available: Array=[]
		var contacted: Array=[]
		for candidate: Dictionary in candidates:
			if candidate.pollinated: contacted.append(candidate)
			else: available.append(candidate)
		# Missing gifts with no local source must be brought from an earlier
		# garden. A local single-gift cross cannot conjure the absent other gift.
		var absent: Array[String]=[]
		for gift: String in missing:
			var local: bool=false
			for candidate: Dictionary in candidates:
				if candidate.adds.has(gift): local=true
			if not local: absent.append(gift)
		if not absent.is_empty():
			var source: Dictionary=_source_garden(absent[0],str(info.get("carry_from","")))
			var carry: Array=fit.carry_gifts
			return _result(base,"bring_seed","Bring %s into this garden" % gift_names(carry),
				"Return to %s and breed a seed carrying %s, then bring it here." % [str(source.get("title","an earlier garden")),gift_names(carry)],
				"The wild plants in this garden cannot supply that missing gift. Their seeds only inherit gifts actually carried by their parents.","garden",Vector2.INF,int(source.get("index",-1)))
		if not contacted.is_empty():
			var donor: Dictionary=contacted[0]
			return _result(base,"replant_hybrid","The new gift is in the seeds","Open the fruit from %s and plant its first hybrid seed." % str(donor.name),
				"Touching a wild plant makes three new seeds. The first keeps every gift of both parents; your current shoot stays unchanged.","fruit",donor.pos,int(donor.index))
		if not available.is_empty():
			var donor: Dictionary=available[0]
			var why: String="%s carries %s. Your growing shoot must touch its stems to make hybrid seeds; then replant a seed with the new gift." % [str(donor.name),gift_names(donor.adds)]
			if stopped and not growing:
				if can_prune:
					return _result(base,"prune_to_pollinate","Grow a fresh shoot toward %s" % str(donor.name),"Swipe across a living stem, then guide a new shoot toward %s." % str(donor.name),why,"wild",donor.pos,int(donor.index))
				return _result(base,"retry_pollination","Touch the wild plant first","Replant and guide your shoot to %s before trying the blocked route." % str(donor.name),why,"wild",donor.pos,int(donor.index))
			return _result(base,"pollinate","First, touch %s" % str(donor.name),"Place or drag a light lure toward %s so your shoot touches it." % str(donor.name),why,"wild",donor.pos,int(donor.index))
	# With the useful gifts present, an exhausted plant needs practical recovery,
	# rather than a seed recommendation that pretends a generation grants power.
	if float(session.plant.energy)<=0.0 and not growing:
		if can_prune:
			return _result(base,"recover_sap","This attempt has run out of sap","Prune a living stem to reclaim some sap and wake fresh shoots, or replant.","Pruning refunds part of the cut growth. A root already drinking would refill sap automatically.","plant",_cut_position(session.plant))
		return _result(base,"retry","This attempt has run out of sap","Replant and spend less growth reaching the next sunwell or dew.","There is no living stem left to prune for sap.","seed",session.world.seed_pos)
	# Only the latest relevant living leader contributes a stop reason. A new
	# healthy shoot makes an older side branch's failure obsolete.
	var stop_reason: String=str(issue.get("reason",""))
	if str(issue.state)=="dark":
		return _result(base,"dark","This shoot needs light","Use a seed with Glow, or move a lure outside the dark edge close enough to light the stalled shoot.","A shoot without Glow stops in darkness when no nearby lure reaches it.","plant",issue.pos)
	if stopped and not growing:
		var why: String="The useful gifts are present, but the shoot still needs a workable route and enough support."
		if stop_reason=="droop": why="The shoot reached too far without support. Even a Buoyant plant has a reach limit; steer toward nearby rock or ground."
		elif stop_reason=="blocked" or stop_reason=="stuck": why="The growing tip became blocked. Move a lure toward an opening or wake a fresh shoot from a lower stem."
		return _result(base,"prune" if can_prune else "retry","Give the next shoot a better route",
			"Swipe across a living stem to wake fresh shoots, then move a lure toward the next well." if can_prune else "Replant and guide the shoot through the visible opening toward the next well.",why,"plant",_cut_position(session.plant))
	# Key-blooms take priority over targets sealed behind their stone gates.
	for index in range(session.world.switches.size()):
		var key: Dictionary=session.world.switches[index]
		if bool(key.on): continue
		var action: String="Place or drag a lure toward the gold key-bloom so a shoot touches it."
		if str(info.id)=="lockstone": action="Steer a shoot down into the pit to touch the gold key-bloom."
		elif str(info.id)=="two_keys": action="Lead a shoot through the first gold key-bloom." if index==0 else "Continue to the second gold key-bloom; the first door is already open."
		elif str(info.id)=="heartwood": action="Steer the shoot into the rising current, then let it carry the shoot up to the gold key-bloom."
		return _result(base,"switch","Open the stone gate first",action,"Touching this gold key-bloom opens its matching stone door; no new gift is needed for the key.","switch",key.pos,index)
	var target: Vector2=session.world.goals[active_goal].pos if active_goal>=0 else Vector2.INF
	# Tool-only levels keep their authored explanation; earned progress changes
	# the immediate instruction rather than repeating the opening tutorial.
	if str(info.id) in ["coral_steps","mirror_wells"] and done>0:
		return _result(base,"prune_next","%d sunwell%s still waiting" % [total-done,"" if total-done==1 else "s"],
			"Prune low on a living stem to send fresh shoots toward the next sunwell." if can_prune else ("Let a short stem grow, then prune low to send fresh shoots toward the next sunwell." if int(session.prunes_left)>0 else "Move a lure toward the next sunwell; no pruning cuts remain."),
			"The earlier well is already awake. A fresh shoot can take a new direction toward the next available well.","goal",target,active_goal)
	if str(info.id)=="twin_wells" and int(session.prunes_left)==int(session.def.get("prunes",0)) and not session.plant.pos.is_empty():
		return _result(base,"prune","Split one stem into two shoots",str(info.action),str(info.why),"plant",_cut_position(session.plant))
	if str(info.id) in ["lockstone","two_keys","heartwood"] and not session.world.switches.is_empty():
		return _result(base,"grow","The gate is open","Move a lure toward the sunwell inside the open chamber.","The key-blooms are already touched. The shoot can now use the open stone passage.","goal",target,active_goal)
	if str(info.id)=="updraft_spires":
		var carried: bool=false
		for tip: Dictionary in session.plant.tips:
			if bool(tip.get("carried",false)) and str(tip.get("state",""))!="stopped": carried=true
		if not carried:
			return _result(base,"updraft","Ride the rising current",str(info.action),str(info.why),"updraft",session.world.updrafts[0].rect.get_center() if not session.world.updrafts.is_empty() else Vector2.INF,0)
		return _result(base,"grow","The current is carrying your shoot","Guide the carried shoot out toward the high sunwell.","The rising air is supporting it, so it can reach higher without a special floating gift.","goal",target,active_goal)
	return _result(base,"grow","Reach the next golden sunwell",str(info.action),str(info.why),"goal",target,active_goal)
