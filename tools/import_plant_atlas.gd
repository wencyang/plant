extends SceneTree
## Losslessly separates the eight authored botanical sprites. Run after selecting
## an atlas; alpha is retained and each source frame is saved before runtime crop.
const TYPES := ["leaf","bloom","vine","root","spore","toxin","parasite","carnivorous"]
func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	var path: String = arguments[0] if not arguments.is_empty() else "res://assets/plants/botanical-atlas-v1.png"
	var atlas := Image.load_from_file(path)
	if atlas == null or atlas.is_empty():
		push_error("Cannot read botanical atlas: "+path)
		quit(1)
		return
	var transparent: int = 0
	for y in range(atlas.get_height()):
		for x in range(atlas.get_width()):
			if atlas.get_pixel(x,y).a < 0.05: transparent += 1
	var alpha_fraction: float = float(transparent)/(atlas.get_width()*atlas.get_height())
	print("BOTANICAL ATLAS: ",atlas.get_size()," / transparent fraction ",alpha_fraction," / corner ",atlas.get_pixel(0,0))
	if alpha_fraction < 0.20:
		push_error("The atlas must have a real transparent background before import.")
		quit(1)
		return
	var cell := Vector2i(atlas.get_width()/4,atlas.get_height()/2)
	for index in TYPES.size():
		var frame := atlas.get_region(Rect2i(Vector2i(index%4,index/4)*cell,cell))
		var result := frame.save_png("res://assets/plants/"+TYPES[index]+".png")
		if result != OK:
			push_error("Cannot save "+TYPES[index])
			quit(1)
			return
		print("Saved ",TYPES[index]," · ",cell)
	quit()
