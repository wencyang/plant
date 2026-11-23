extends SceneTree
## Player-directed time keeps the real breeding/seed system and old saves.
const State=preload("res://scripts/garden_state.gd")
const DNA=preload("res://scripts/plant_dna.gd")
var failures: int=0
var checks: int=0

func check(value: bool,message: String) -> void:
	checks+=1
	if not value:
		failures+=1
		push_error("GARDEN DAY: "+message)

func _initialize() -> void:
	var path: String="/tmp/plant_garden_day_%d.json" % Time.get_ticks_usec()
	var state:=State.new(path)
	state.new_game()
	var a: String=str(state.plant_order[0])
	var b: String=str(state.plant_order[1])
	var genome: String=DNA.canonical(state.get_plant(a).genes)
	var light: int=int(state.resources.sunlight)
	var cross: Dictionary=state.adventure_begin_cross(a,b)
	check(bool(cross.ok),"Any two original grown plants can still cross")
	var embryos: String=DNA.canonical(state.pollinations[a].seeds)
	check(not bool(state.fruit_status(a).cross_ready),"A new real fruit begins growing")
	var preview: Dictionary=state.garden_day_preview()
	check(int(preview.hybrid_fruit)==1,"Morning preview names the growing hybrid fruit")
	check(state.garden_day==1,"New gardens begin on day one")
	state.advance_garden_day()
	check(state.garden_day==2 and bool(state.fruit_status(a).cross_ready),"A chosen morning ripens the actual fruit")
	check(DNA.canonical(state.pollinations[a].seeds)==embryos,"Rest cannot reroll either offspring genome")
	check(int(state.resources.sunlight)==light-State.POLLINATION_COST,"Rest has no currency cost or farmable gift")
	var result: Dictionary=state.adventure_siblings(a)
	check(bool(result.ok) and result.plant_ids.size()==2,"The same two embryos can be harvested and sown")
	for id: String in result.plant_ids:
		check(not bool(state.get_plant(id).mature),"Both independent siblings begin as seedlings")
	state.advance_garden_day()
	for id: String in result.plant_ids:
		var p: Dictionary=state.get_plant(id)
		check(bool(p.mature) and float(p.life_age)==0,"Seedlings waking this morning start a fresh grown life")
		check(p.parents==[a,b] and int(p.generation)==2,"Rest preserves full lineage and generation")
	check(DNA.canonical(state.get_plant(a).genes)==genome,"Passing days never changes parental DNA")
	var loaded:=State.new(path)
	check(loaded.load_game() and loaded.garden_day==3,"Chosen day and real siblings survive reload")
	loaded.get_plant(a).life_age=State.WITHER_SECONDS-State.GARDEN_DAY_AGE
	check(loaded.garden_day_preview().retiring.has(a),"Upcoming loss is announced before the player rests")
	loaded.advance_garden_day()
	check(bool(loaded.get_plant(a).withered),"Plants still have a real lifecycle")
	check(bool(loaded.fruit_crops[a].get("final",false)) and bool(loaded.fruit_status(a).natural_ready),"A withered plant leaves a ripe seed-bearing legacy")
	check(not loaded.get_plant(a).genes.is_empty(),"The final family record retains its DNA")
	var legacy: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	legacy.erase("garden_day")
	var file:=FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	var migrated:=State.new(path)
	check(migrated.load_game() and migrated.garden_day==1,"Older gardens migrate without a day field")
	check(migrated.get_plant(a).genes==loaded.get_plant(a).genes,"Migration leaves existing genomes intact")
	for suffix: String in ["",".tmp"]:
		if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(path+suffix)
	var backup: String=path.get_basename()+".backup.json"
	if FileAccess.file_exists(backup): DirAccess.remove_absolute(backup)
	print("GARDEN DAYS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
