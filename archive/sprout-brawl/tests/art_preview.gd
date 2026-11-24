extends SceneTree
## Renders every family and a row of hybrids to screenshots/art-families.png
## godot --path . --script res://tests/art_preview.gd

const Plant := preload("res://scripts/sim/plant.gd")
const Breeding := preload("res://scripts/sim/breeding.gd")
const Species := preload("res://scripts/sim/species.gd")
const PlantView := preload("res://scripts/view/plant_view.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1400, 760)
	var bg := ColorRect.new()
	bg.color = Color("cfe8c4")
	bg.size = Vector2(1400, 760)
	root.add_child(bg)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var founders: Array = []
	for i in Species.ORDER.size():
		var p = Plant.create(Species.ORDER[i], rng)
		founders.append(p)
		var v := PlantView.new()
		root.add_child(v)
		v.position = Vector2(110 + i * 165, 300)
		v.scale = Vector2(1.25, 1.25)
		v.setup(p, 1.0)
	var pairs := [[0, 6], [1, 3], [2, 4], [5, 7], [6, 2], [3, 5], [4, 1], [7, 0]]
	for i in pairs.size():
		var c = Breeding.cross(founders[pairs[i][0]], founders[pairs[i][1]], rng, i % 3 == 0)
		var g = Breeding.cross(c, founders[(i + 3) % 8], rng)
		var v := PlantView.new()
		root.add_child(v)
		v.position = Vector2(110 + i * 165, 640)
		v.scale = Vector2(1.25, 1.25)
		v.setup(g if i % 2 == 0 else c, 1.0 if i % 2 == 0 else -1.0)
		v.angry = i % 4 == 1
	for f in 20: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/art-families.png")
	print("saved")
	quit()
