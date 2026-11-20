extends Control
## A cheap low-resolution topology map; the terrain itself stays in HD chunks.
signal destination_selected(tile: Vector2i)
var world: Control
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
func map_rect() -> Rect2:
	if not is_instance_valid(world):return Rect2()
	var scale: float = minf(size.x/world.MAP_WIDTH,size.y/world.MAP_HEIGHT)
	var extent := Vector2(world.MAP_WIDTH,world.MAP_HEIGHT)*scale
	return Rect2((size-extent)*0.5,extent)
func _draw() -> void:
	if not is_instance_valid(world) or world._atlas_texture==null:return
	var rect: Rect2 = map_rect()
	draw_rect(rect.grow(2),Color("a8bb8b"),false,2)
	draw_texture_rect(world._atlas_texture,rect,false)
	var unit := rect.size/Vector2(world.MAP_WIDTH,world.MAP_HEIGHT)
	var discovered: Array = world.state.expedition.get("discovered_biomes",[]) if world.state!=null else []
	# Unvisited habitats remain readable, with a soft veil of unexplored ecology.
	for region_y in range(2):
		for region_x in range(4):
			var tile := Vector2i(region_x*40+20,region_y*64+40)
			if not discovered.has(world.biome_at(tile)):
				draw_rect(Rect2(rect.position+Vector2(region_x*40,region_y*64)*unit,Vector2(40,64)*unit),Color(0.04,0.10,0.09,0.40))
	for site: Dictionary in world.SITES:
		if world._site_unavailable(str(site.id)):continue
		if not discovered.has(str(site.biome)):continue
		var point: Vector2 = rect.position+(Vector2(site.x,site.y)+Vector2(0.5,0.5))*unit
		draw_rect(Rect2(point-Vector2.ONE,Vector2(2,2)),Color("cbd6a0"))
	var visited: Array = world.state.expedition.get("visited_landmarks",[]) if world.state!=null else []
	for camp: Dictionary in world.LANDMARKS:
		var point: Vector2 = rect.position+(Vector2(camp.x,camp.y)+Vector2(0.5,0.5))*unit
		var known: bool = camp.id=="home" or visited.has(camp.id)
		draw_rect(Rect2(point-Vector2(3,3),Vector2(7,7)),Color("e9cf8e") if known else Color("a8aaa0"))
		draw_rect(Rect2(point-Vector2(1,1),Vector2(3,3)),Color("3f5b44"))
	var player: Vector2 = rect.position+(Vector2(world.player_tile)+Vector2(0.5,0.5))*unit
	draw_rect(Rect2(player-Vector2(4,4),Vector2(9,9)),Color("182c2b"))
	draw_rect(Rect2(player-Vector2(2,2),Vector2(5,5)),Color("eff0cc"))
	if world._touch_goal.x>=0:
		var goal: Vector2 = rect.position+(Vector2(world._touch_goal)+Vector2(0.5,0.5))*unit
		draw_rect(Rect2(goal-Vector2(4,4),Vector2(9,9)),Color("e5b37c"),false,2)
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
		var rect: Rect2 = map_rect()
		if rect.has_point(event.position):
			var tile := Vector2i((event.position-rect.position)/rect.size*Vector2(world.MAP_WIDTH,world.MAP_HEIGHT))
			destination_selected.emit(tile)
			accept_event()
