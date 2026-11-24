extends RefCounted
## Hand-built puzzle gardens. World is 1600 × 1000, y grows downward.

const Genome := preload("res://scripts/genome.gd")

static func starter() -> Dictionary:
	return Genome.make({"name": "Firstling", "species": "Firstling", "hue": 0.40, "hue2": 0.93, "leaf_shape": 0, "flower": 1, "petals": 5, "pattern": 0, "stem": 0,
		"speed": 72.0, "branch": 0.2, "spread": 0.6, "photo": 0.75, "reach": 430.0})

static func wild(species: String) -> Dictionary:
	match species:
		"Spinebrush":
			return Genome.make({"name": "Spinebrush", "species": "Spinebrush", "hue": 0.02, "hue2": 0.11, "leaf_shape": 3, "flower": 3, "petals": 7, "pattern": 1, "stem": 1,
				"branch": 0.7, "spread": 0.9, "speed": 64.0, "thorns": 1, "reach": 400.0, "leaf_size": 0.9})
		"Lanternwort":
			return Genome.make({"name": "Lanternwort", "species": "Lanternwort", "hue": 0.50, "hue2": 0.44, "leaf_shape": 1, "flower": 2, "petals": 4, "pattern": 3, "stem": 0,
				"branch": 0.45, "spread": 0.7, "speed": 66.0, "curl": 0.5, "glow": 1, "leaf_size": 1.25})
		"Hookvine":
			return Genome.make({"name": "Hookvine", "species": "Hookvine", "hue": 0.21, "hue2": 0.77, "leaf_shape": 2, "flower": 0, "petals": 6, "pattern": 2, "stem": 2,
				"branch": 0.4, "spread": 0.8, "speed": 80.0, "curl": 1.0, "tendrils": 1, "reach": 520.0, "leaf_size": 1.1})
		"Deeproot":
			return Genome.make({"name": "Deeproot", "species": "Deeproot", "hue": 0.08, "hue2": 0.60, "leaf_shape": 1, "flower": 1, "petals": 8, "pattern": 1, "stem": 1,
				"branch": 0.5, "spread": 0.75, "speed": 60.0, "roots": 1, "leaf_size": 1.0})
	return starter()

static func blob(cx: float, cy: float, rx: float, ry: float, s := 1, n := 16) -> Array:
	var pts: Array = []
	for i in n:
		var a := TAU * i / n
		var wob := 1.0 + 0.13 * sin(a * 3.0 + s * 1.7) + 0.08 * sin(a * 5.0 + s * 4.1)
		var flat := 0.85 if sin(a) > 0 else 1.0
		pts.append(Vector2(cx + cos(a) * rx * wob, cy + sin(a) * ry * wob * flat))
	return pts

static func ground(y: float, wave := 10.0, s := 1) -> Array:
	var pts: Array = [Vector2(-100, 1300)]
	for i in 19:
		var x := -100.0 + i * 100.0
		pts.append(Vector2(x, y + sin(i * 0.9 + s) * wave + sin(i * 2.3 + s * 2.0) * wave * 0.5))
	pts.append(Vector2(1800, 1300))
	return pts

static func slab(x0: float, y0: float, x1: float, y1: float, s := 1) -> Array:
	var pts: Array = []
	var n := 8
	for i in range(n + 1):
		var x := lerpf(x0, x1, float(i) / n)
		pts.append(Vector2(x, y0 + sin(i * 1.3 + s) * 6.0))
	for i in range(n, -1, -1):
		var x := lerpf(x0, x1, float(i) / n)
		pts.append(Vector2(x, y1 + sin(i * 1.7 + s) * 6.0))
	return pts

static func all() -> Array:
	return [
		{
			"id": "first_light", "title": "First Light",
			"intro": "Your seedling grows toward light on its own. Stems can only reach so far into open air — they need rock to lean on.",
			"hint": "Click to place a light lure. Drag it to steer.",
			"palette": "dawn", "seed": Vector2(300, 852), "energy": 2400.0, "lures": 1, "prunes": 2,
			"rocks": [{"poly": ground(866, 8, 1), "soil": true}, {"poly": blob(600, 620, 160, 50, 2)}, {"poly": blob(930, 490, 150, 46, 3)}],
			"goals": [{"pos": Vector2(1180, 360)}],
		},
		{
			"id": "twin_wells", "title": "Twin Wells",
			"intro": "Two sunwells. A plant that only grows one way won't make it.",
			"hint": "Swipe across a stem to prune it: the stump splits into two fresh shoots.",
			"palette": "dawn", "seed": Vector2(800, 852), "energy": 4200.0, "lures": 2, "prunes": 3,
			"rocks": [{"poly": ground(866, 10, 2), "soil": true}, {"poly": blob(800, 610, 170, 44, 4)}, {"poly": blob(510, 470, 110, 40, 5)}, {"poly": blob(1090, 470, 110, 40, 6)}],
			"goals": [{"pos": Vector2(320, 300)}, {"pos": Vector2(1280, 300)}],
		},
		{
			"id": "crystal_throat", "title": "Crystal Throat",
			"intro": "Crystal seals the only way up. Something wild on the ledge has thorns...",
			"hint": "Touch a wild plant to pollinate it. Then plant one of the hybrid seeds.",
			"palette": "cavern", "seed": Vector2(800, 852), "energy": 1900.0, "lures": 1, "prunes": 2,
			"rocks": [{"poly": ground(866, 8, 3), "soil": true},
				{"poly": [Vector2(-100, -100), Vector2(180, -100), Vector2(200, 300), Vector2(170, 700), Vector2(190, 1100), Vector2(-100, 1100)]},
				{"poly": [Vector2(1420, -100), Vector2(1700, -100), Vector2(1700, 1100), Vector2(1410, 1100), Vector2(1430, 600), Vector2(1400, 300)]},
				{"poly": slab(170, 380, 762, 470, 1)}, {"poly": slab(838, 380, 1420, 470, 2)},
				{"poly": [Vector2(180, 650), Vector2(560, 640), Vector2(575, 668), Vector2(540, 690), Vector2(180, 692)]}],
			"crystals": [[Vector2(762, 372), Vector2(800, 360), Vector2(838, 372), Vector2(842, 480), Vector2(800, 492), Vector2(758, 480)]],
			"goals": [{"pos": Vector2(800, 190)}],
			"wilds": [{"pos": Vector2(530, 642), "genome": "Spinebrush", "energy": 300.0}],
		},
		{
			"id": "lanternless", "title": "Lanternless",
			"intro": "Shoots stall in the dark. Nothing here can see... except the plant that glows.",
			"hint": "Dark stops growth, and lures can't be placed in it. A glowing plant brings its own light.",
			"palette": "dusk", "seed": Vector2(560, 852), "energy": 3200.0, "lures": 1, "prunes": 2,
			"rocks": [{"poly": ground(866, 12, 4), "soil": true}, {"poly": blob(820, 630, 120, 44, 7)}, {"poly": blob(1080, 520, 90, 36, 8)}, {"poly": blob(1300, 650, 110, 40, 9)}],
			"darks": [{"pos": Vector2(1160, 420), "r": 380.0}],
			"goals": [{"pos": Vector2(1190, 380)}],
			"wilds": [{"pos": Vector2(760, 598), "genome": "Lanternwort", "energy": 320.0}],
		},
		{
			"id": "glass_cliff", "title": "Glass Cliff",
			"intro": "The cliff is glassy. Ordinary shoots slip and die on it. Something with hooks could climb.",
			"hint": "Tendrils cling to glass and climb it.",
			"palette": "teal", "seed": Vector2(870, 852), "energy": 2800.0, "lures": 1, "prunes": 2,
			"rocks": [{"poly": ground(866, 8, 5), "soil": true},
				{"poly": [Vector2(980, 1100), Vector2(976, 700), Vector2(988, 470), Vector2(982, 330), Vector2(1100, 312), Vector2(1300, 320), Vector2(1700, 310), Vector2(1700, 1100)], "slick": true},
				{"poly": [Vector2(380, 640), Vector2(700, 632), Vector2(712, 660), Vector2(680, 680), Vector2(380, 682)]}],
			"goals": [{"pos": Vector2(1260, 255)}],
			"wilds": [{"pos": Vector2(540, 636), "genome": "Hookvine", "energy": 260.0}],
		},
		{
			"id": "thirst", "title": "Thirst",
			"intro": "Barely enough sap to sprout. Water glints deep under the soil.",
			"hint": "Roots grow down through soil and drink, refilling energy.",
			"palette": "ochre", "seed": Vector2(820, 852), "energy": 520.0, "lures": 1, "prunes": 2,
			"rocks": [{"poly": ground(866, 8, 6), "soil": true}, {"poly": blob(1040, 640, 110, 40, 10)}, {"poly": blob(1230, 470, 100, 38, 11)}],
			"waters": [Rect2(260, 935, 760, 50)],
			"goals": [{"pos": Vector2(1340, 300)}],
			"wilds": [{"pos": Vector2(540, 852), "genome": "Deeproot", "energy": 330.0}],
		},
		{
			"id": "shattered_spire", "title": "Shattered Spire",
			"intro": "A sunwell sealed in crystal, inside a pool of night. One plant will need two gifts.",
			"hint": "A hybrid's first seed always carries every gift of both parents.",
			"palette": "violet", "seed": Vector2(900, 852), "energy": 3000.0, "lures": 1, "prunes": 3,
			"rocks": [{"poly": ground(866, 10, 7), "soil": true}, {"poly": blob(1200, 650, 130, 40, 12)},
				{"poly": [Vector2(960, -100), Vector2(1010, -100), Vector2(1022, 440), Vector2(970, 450)]},
				{"poly": [Vector2(1380, -100), Vector2(1430, -100), Vector2(1440, 450), Vector2(1385, 440)]}],
			"crystals": [[Vector2(1018, 420), Vector2(1200, 404), Vector2(1388, 420), Vector2(1388, 466), Vector2(1200, 480), Vector2(1018, 466)]],
			"darks": [{"pos": Vector2(1200, 250), "r": 230.0}],
			"goals": [{"pos": Vector2(1200, 230)}],
			"wilds": [{"pos": Vector2(620, 852), "genome": "Lanternwort", "energy": 300.0}],
		},
		{
			"id": "heart_grove", "title": "Heart of the Grove",
			"intro": "Glass, crystal and night. Only a plant with every gift can wake both sunwells.",
			"hint": "Cross what you've bred with the wild Hookvine.",
			"palette": "night", "seed": Vector2(520, 852), "energy": 4200.0, "lures": 2, "prunes": 3,
			"rocks": [{"poly": ground(866, 10, 8), "soil": true},
				{"poly": [Vector2(640, 1100), Vector2(642, 420), Vector2(700, 396), Vector2(760, 420), Vector2(758, 1100)], "slick": true},
				{"poly": blob(985, 440, 100, 32, 13)}, {"poly": blob(1290, 650, 120, 40, 14)},
				{"poly": [Vector2(1150, -100), Vector2(1195, -100), Vector2(1205, 440), Vector2(1155, 450)]},
				{"poly": [Vector2(1385, -100), Vector2(1430, -100), Vector2(1435, 450), Vector2(1390, 440)]}],
			"crystals": [[Vector2(1200, 420), Vector2(1290, 406), Vector2(1392, 420), Vector2(1392, 466), Vector2(1290, 478), Vector2(1200, 466)]],
			"darks": [{"pos": Vector2(1290, 260), "r": 200.0}],
			"goals": [{"pos": Vector2(700, 340)}, {"pos": Vector2(1290, 240)}],
			"wilds": [{"pos": Vector2(380, 852), "genome": "Hookvine", "energy": 260.0}],
		},
	]
