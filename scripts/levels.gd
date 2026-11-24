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
		"Driftcap":
			return Genome.make({"name": "Driftcap", "species": "Driftcap", "hue": 0.57, "hue2": 0.11, "leaf_shape": 5, "flower": 4, "petals": 9, "pattern": 2, "stem": 0,
				"branch": 0.5, "spread": 0.8, "speed": 70.0, "curl": -0.5, "buoyant": 1, "leaf_size": 1.15})
		"Emberwax":
			return Genome.make({"name": "Emberwax", "species": "Emberwax", "hue": 0.99, "hue2": 0.07, "leaf_shape": 4, "flower": 5, "petals": 5, "pattern": 3, "stem": 1,
				"branch": 0.45, "spread": 0.7, "speed": 66.0, "waxy": 1, "leaf_size": 1.2})
		"Moonpetal":
			return Genome.make({"name": "Moonpetal", "species": "Moonpetal", "hue": 0.69, "hue2": 0.15, "leaf_shape": 2, "flower": 2, "petals": 6, "pattern": 3, "stem": 2,
				"branch": 0.45, "spread": 0.75, "speed": 64.0, "curl": 0.3, "glow": 1, "roots": 1, "leaf_size": 1.0})
		"Briarbell":
			return Genome.make({"name": "Briarbell", "species": "Briarbell", "hue": 0.90, "hue2": 0.53, "leaf_shape": 3, "flower": 0, "petals": 5, "pattern": 1, "stem": 2,
				"branch": 0.55, "spread": 0.85, "speed": 72.0, "curl": 0.8, "thorns": 1, "tendrils": 1, "reach": 480.0, "leaf_size": 1.0})
	return starter()

const SPECIES := ["Spinebrush", "Lanternwort", "Hookvine", "Deeproot", "Driftcap", "Emberwax", "Moonpetal", "Briarbell"]

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

static func ground_span(x0: float, x1: float, y: float, s := 1) -> Array:
	var pts: Array = [Vector2(x0 - 30, 1300), Vector2(x0, y + 14)]
	var n := int((x1 - x0) / 90.0)
	for i in range(n + 1):
		var x := lerpf(x0 + 20, x1 - 20, float(i) / max(1, n))
		pts.append(Vector2(x, y + sin(i * 1.1 + s) * 8.0))
	pts.append(Vector2(x1, y + 14))
	pts.append(Vector2(x1 + 30, 1300))
	return pts

static func vent_column(x: float, r := 105.0) -> Array:
	var out: Array = []
	var y := 900.0
	while y > -120.0:
		out.append({"pos": Vector2(x, y), "r": r})
		y -= r * 1.3
	return out

static func all() -> Array:
	return [
		{
			"id": "first_light", "title": "First Light",
			"intro": "Your seedling grows toward light on its own. Stems can only reach so far into open air — they need rock to lean on.",
			"hint": "Click to place a light lure. Drag it to steer.",
			"palette": "dawn", "seed": Vector2(300, 852), "energy": 2400.0, "lures": 1, "prunes": 2,
			"rocks": [{"poly": ground(866, 8, 1), "soil": true}, {"poly": blob(600, 620, 160, 50, 2)}, {"poly": blob(930, 490, 150, 46, 3)}],
			"dews": [Vector2(470, 700), Vector2(930, 400), Vector2(1420, 640)], "par": 1,
			"goals": [{"pos": Vector2(1180, 360)}],
			"guide": [{"lure": Vector2(760, 520)}],
		},
		{
			"id": "twin_wells", "title": "Twin Wells",
			"intro": "Two sunwells, one plant. Cut the young stem and it splits into two shoots — one for each well.",
			"hint": "Swipe across the stem along the dotted line. Each half finds its own light.",
			"palette": "dawn", "seed": Vector2(800, 852), "energy": 3600.0, "lures": 2, "prunes": 4,
			"rocks": [{"poly": ground(866, 10, 2), "soil": true}, {"poly": blob(520, 690, 120, 40, 5)}, {"poly": blob(1080, 690, 120, 40, 6)}],
			"dews": [Vector2(800, 520), Vector2(330, 600), Vector2(1270, 600)], "par": 2,
			"goals": [{"pos": Vector2(545, 610)}, {"pos": Vector2(1055, 610)}],
			"guide": [{"swipe": [Vector2(720, 770), Vector2(880, 770)]}],
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
			"dews": [Vector2(330, 560), Vector2(1250, 600), Vector2(800, 110)], "par": 2,
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
			"dews": [Vector2(380, 640), Vector2(1350, 300), Vector2(980, 720)], "par": 1,
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
			"dews": [Vector2(1460, 230), Vector2(600, 560), Vector2(930, 780)], "par": 1,
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
			"dews": [Vector2(1100, 380), Vector2(700, 700), Vector2(1460, 250)], "par": 1,
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
			"dews": [Vector2(700, 540), Vector2(1200, 120), Vector2(1480, 700)], "par": 2,
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
			"dews": [Vector2(300, 600), Vector2(1000, 360), Vector2(1290, 110)], "par": 3,
			"goals": [{"pos": Vector2(700, 340)}, {"pos": Vector2(1290, 240)}],
			"wilds": [{"pos": Vector2(380, 852), "genome": "Hookvine", "energy": 260.0}],
		},
		{
			"id": "drift_chasm", "title": "Drift Chasm",
			"intro": "The ground falls away. No stem can lean on nothing... unless it floats.",
			"hint": "Buoyant plants grow floating bladders and reach almost twice as far.",
			"palette": "mist", "seed": Vector2(300, 852), "energy": 2600.0, "lures": 1, "prunes": 2,
			"rocks": [{"poly": ground_span(-200, 540, 866, 1), "soil": true}, {"poly": ground_span(1100, 1800, 866, 2), "soil": true}],
			"dews": [Vector2(820, 640), Vector2(1500, 620), Vector2(240, 650)], "par": 1,
			"goals": [{"pos": Vector2(1230, 760)}],
			"wilds": [{"pos": Vector2(470, 852), "genome": "Driftcap", "energy": 260.0}],
		},
		{
			"id": "ember_vents", "title": "Ember Vents",
			"intro": "A curtain of heat rises from the fissure. Tender shoots wither in it.",
			"hint": "Waxy plants shrug off the heat.",
			"palette": "ash", "seed": Vector2(300, 852), "energy": 2800.0, "lures": 1, "prunes": 2,
			"rocks": [{"poly": ground(866, 8, 9), "soil": true}, {"poly": blob(690, 640, 110, 38, 15)}, {"poly": blob(1080, 540, 120, 38, 16)}],
			"vents": vent_column(880.0),
			"dews": [Vector2(880, 300), Vector2(470, 620), Vector2(1460, 360)], "par": 1,
			"goals": [{"pos": Vector2(1290, 470)}],
			"wilds": [{"pos": Vector2(540, 852), "genome": "Emberwax", "energy": 260.0}],
		},
		{
			"id": "moon_garden", "title": "Moon Garden",
			"intro": "Thirsty soil, and a sunwell drowned in night. One wild plant here carries two gifts at once.",
			"hint": "Some wild plants carry more than one gift.",
			"palette": "aurora", "seed": Vector2(520, 852), "energy": 520.0, "lures": 1, "prunes": 2,
			"rocks": [{"poly": ground(866, 8, 10), "soil": true}, {"poly": blob(800, 650, 110, 38, 17)}, {"poly": blob(1040, 520, 100, 36, 18)}],
			"waters": [Rect2(300, 935, 720, 48)],
			"darks": [{"pos": Vector2(1210, 400), "r": 300.0}],
			"dews": [Vector2(1400, 260), Vector2(900, 540), Vector2(300, 700)], "par": 1,
			"goals": [{"pos": Vector2(1220, 380)}],
			"wilds": [{"pos": Vector2(680, 852), "genome": "Moonpetal", "energy": 260.0}],
		},
		{
			"id": "briar_gate", "title": "Briar Gate",
			"intro": "A glass spire holds up a crystal gate. Climb, then break through.",
			"hint": "Briarbell carries thorns and tendrils together.",
			"palette": "jungle", "seed": Vector2(1175, 852), "energy": 2600.0, "lures": 1, "prunes": 2,
			"rocks": [{"poly": ground(866, 8, 11), "soil": true},
				{"poly": [Vector2(1150, -100), Vector2(1195, -100), Vector2(1195, 376), Vector2(1150, 380)], "slick": true},
				{"poly": [Vector2(1385, -100), Vector2(1430, -100), Vector2(1430, 380), Vector2(1385, 376)], "slick": true},
				{"poly": [Vector2(1262, 1100), Vector2(1260, 384), Vector2(1290, 378), Vector2(1320, 384), Vector2(1318, 1100)], "slick": true}],
			"crystals": [[Vector2(1195, 336), Vector2(1290, 324), Vector2(1385, 336), Vector2(1385, 376), Vector2(1290, 384), Vector2(1195, 376)]],
			"dews": [Vector2(1290, 90), Vector2(920, 520), Vector2(1500, 700)], "par": 2,
			"goals": [{"pos": Vector2(1290, 180)}],
			"wilds": [{"pos": Vector2(880, 852), "genome": "Briarbell", "energy": 260.0}],
			"guide": [{"lure": Vector2(880, 690)}],
		},
		{
			"id": "coral_steps", "title": "Coral Steps",
			"intro": "Three sunwells on the coral shelves. Wake the middle one, then split your plant to reach the others.",
			"hint": "After the first sunwell wakes, swipe the stem low down to send two shoots outward.",
			"palette": "coral", "seed": Vector2(800, 852), "energy": 4800.0, "lures": 3, "prunes": 5,
			"rocks": [{"poly": ground(866, 10, 12), "soil": true}, {"poly": blob(500, 720, 110, 38, 19)}, {"poly": blob(1100, 720, 110, 38, 20)}],
			"dews": [Vector2(800, 330), Vector2(300, 620), Vector2(1300, 620)], "par": 3,
			"goals": [{"pos": Vector2(800, 600)}, {"pos": Vector2(520, 645)}, {"pos": Vector2(1080, 645)}],
			"wilds": [{"pos": Vector2(250, 852), "genome": "Driftcap", "energy": 240.0}, {"pos": Vector2(1380, 852), "genome": "Hookvine", "energy": 240.0}],
			"guide": [{"swipe": [Vector2(720, 800), Vector2(880, 800)]}],
		},
		{
			"id": "long_bloom", "title": "The Long Bloom",
			"intro": "A chasm, a wall of heat, and a sunwell lost in night. Breed a plant that floats, endures and glows.",
			"hint": "Bring a glowing seed. Cross it with what grows here, then cross again.",
			"palette": "abyss", "seed": Vector2(540, 852), "energy": 4200.0, "lures": 2, "prunes": 3,
			"rocks": [{"poly": ground_span(-200, 640, 866, 3), "soil": true}, {"poly": ground_span(1120, 1800, 866, 4), "soil": true}],
			"vents": vent_column(1250.0, 95.0),
			"darks": [{"pos": Vector2(1440, 600), "r": 230.0}],
			"dews": [Vector2(880, 660), Vector2(1250, 250), Vector2(1500, 420)], "par": 3,
			"goals": [{"pos": Vector2(1450, 600)}],
			"wilds": [{"pos": Vector2(615, 852), "genome": "Driftcap", "energy": 250.0}, {"pos": Vector2(330, 852), "genome": "Emberwax", "energy": 250.0}],
			"guide": [{"lure": Vector2(340, 700)}, {"lure": Vector2(1180, 760)}],
		},
		{
			"id": "lockstone", "title": "Lockstone",
			"intro": "The sunwell sleeps behind a stone gate. The key-bloom that opens it lies at the bottom of a pit.",
			"hint": "Place a lure down in the pit — shoots will grow downward to it. Touch the gold bud to open the gate.",
			"palette": "dusk", "seed": Vector2(930, 852), "energy": 4200.0, "lures": 2, "prunes": 2, "par": 2,
			"rocks": [{"poly": ground_span(-200, 520, 866, 5), "soil": true}, {"poly": ground_span(760, 1800, 866, 6), "soil": true},
				{"poly": [Vector2(440, 1300), Vector2(440, 975), Vector2(840, 975), Vector2(840, 1300)]},
				{"poly": [Vector2(1100, -100), Vector2(1700, -100), Vector2(1700, 140), Vector2(1100, 140)]},
				{"poly": [Vector2(1450, 140), Vector2(1700, 140), Vector2(1700, 610), Vector2(1450, 610)]},
				{"poly": [Vector2(1100, 560), Vector2(1450, 560), Vector2(1450, 610), Vector2(1100, 610)]},
				{"poly": [Vector2(1100, 140), Vector2(1150, 140), Vector2(1150, 560), Vector2(1100, 560)], "gate": "g1"},
				{"poly": blob(1000, 470, 80, 28, 22)}, {"poly": blob(880, 680, 70, 26, 35)}],
			"switches": [{"pos": Vector2(640, 945), "opens": ["g1"]}],
			"dews": [Vector2(600, 940), Vector2(1300, 200), Vector2(250, 700)],
			"goals": [{"pos": Vector2(1300, 350)}],
			"guide": [{"lure": Vector2(640, 930)}],
		},
		{
			"id": "false_dawn", "title": "False Dawn",
			"intro": "A violet wisp drifts above the vents, and young shoots chase it to their death. Give them a truer light.",
			"hint": "Decoy wisps pull shoots like lures. A lure placed nearer your shoot pulls harder.",
			"palette": "ash", "seed": Vector2(760, 852), "energy": 2800.0, "lures": 1, "prunes": 2, "par": 1,
			"rocks": [{"poly": ground(866, 8, 13), "soil": true}, {"poly": blob(1010, 640, 110, 36, 23)}, {"poly": blob(1180, 520, 90, 32, 24)}],
			"vents": vent_column(420.0, 110.0),
			"decoys": [{"path": [Vector2(470, 380), Vector2(560, 700), Vector2(470, 520)], "speed": 70.0}],
			"dews": [Vector2(640, 520), Vector2(1450, 300), Vector2(1200, 760)],
			"goals": [{"pos": Vector2(1220, 455)}],
			"guide": [{"lure": Vector2(1000, 560)}],
		},
		{
			"id": "updraft_spires", "title": "Updraft Spires",
			"intro": "The sunwell hangs far above. Warm air rises off to one side — inside a current, a shoot is carried and never droops.",
			"hint": "Lure your shoot sideways into the updraft and let it carry you up.",
			"palette": "mist", "seed": Vector2(1450, 852), "energy": 3200.0, "lures": 1, "prunes": 2, "par": 1,
			"rocks": [{"poly": ground(866, 8, 14), "soil": true}, {"poly": blob(1260, 175, 110, 30, 26)}, {"poly": blob(420, 420, 110, 32, 25)}],
			"updrafts": [{"rect": Rect2(930, 140, 190, 720), "dir": Vector2.UP}],
			"dews": [Vector2(1035, 520), Vector2(420, 360), Vector2(1520, 300)],
			"goals": [{"pos": Vector2(1330, 110)}],
			"guide": [{"lure": Vector2(1040, 800)}],
		},
		{
			"id": "two_keys", "title": "Two Keys",
			"intro": "Two stone doors seal the sunwell, and each has its own key-bloom, one on either side.",
			"hint": "Lures are waypoints: a shoot visits the nearest, then moves on to the next. Chain them through both keys.",
			"palette": "violet", "seed": Vector2(260, 852), "energy": 4200.0, "lures": 2, "prunes": 3, "par": 2,
			"rocks": [{"poly": ground(866, 8, 15), "soil": true},
				{"poly": [Vector2(640, -100), Vector2(960, -100), Vector2(960, 300), Vector2(640, 300)]},
				{"poly": [Vector2(640, 300), Vector2(680, 300), Vector2(680, 720), Vector2(640, 720)]},
				{"poly": [Vector2(920, 300), Vector2(960, 300), Vector2(960, 720), Vector2(920, 720)]},
				{"poly": [Vector2(680, 670), Vector2(920, 670), Vector2(920, 720), Vector2(680, 720)], "gate": "g1"},
				{"poly": [Vector2(680, 600), Vector2(920, 600), Vector2(920, 650), Vector2(680, 650)], "gate": "g2"},
				{"poly": slab(560, 812, 1040, 880, 3)}],
			"switches": [{"pos": Vector2(520, 838), "opens": ["g1"]}, {"pos": Vector2(860, 785), "opens": ["g2"]}],
			"dews": [Vector2(800, 360), Vector2(150, 600), Vector2(1450, 600)],
			"goals": [{"pos": Vector2(800, 450)}],
			"guide": [{"lure": Vector2(520, 838)}, {"lure": Vector2(860, 785)}],
		},
		{
			"id": "sunken_bloom", "title": "Sunken Bloom",
			"intro": "This sunwell fell through the earth. Find the shaft, grow down into the dark cave below.",
			"hint": "Lure your plant to the shaft's mouth. Down below, only a glowing plant can see.",
			"palette": "aurora", "seed": Vector2(380, 546), "energy": 3000.0, "lures": 1, "prunes": 2, "par": 1,
			"rocks": [{"poly": [Vector2(-100, 620), Vector2(-100, 560), Vector2(300, 556), Vector2(600, 562), Vector2(700, 560), Vector2(700, 620)], "soil": true},
				{"poly": [Vector2(790, 620), Vector2(790, 560), Vector2(1100, 556), Vector2(1400, 564), Vector2(1800, 558), Vector2(1800, 620)], "soil": true},
				{"poly": [Vector2(-100, 1300), Vector2(-100, 965), Vector2(500, 960), Vector2(900, 968), Vector2(1300, 962), Vector2(1800, 966), Vector2(1800, 1300)]},
				{"poly": blob(1100, 560, 30, 20, 29)}],
			"darks": [{"pos": Vector2(1120, 800), "r": 360.0}],
			"dews": [Vector2(745, 760), Vector2(1500, 900), Vector2(200, 480)],
			"goals": [{"pos": Vector2(1200, 760)}],
			"wilds": [{"pos": Vector2(180, 546), "genome": "Lanternwort", "energy": 240.0}],
			"guide": [{"lure": Vector2(745, 660)}],
		},
		{
			"id": "mirror_wells", "title": "Mirror Wells",
			"intro": "Three sunwells, and each sleeps until the one before it wakes. One shoot can't wake them all.",
			"hint": "Wake them in order. Each time one wakes, prune low to send a fresh shoot to the next.",
			"palette": "coral", "seed": Vector2(800, 852), "energy": 4600.0, "lures": 2, "prunes": 4, "par": 4,
			"rocks": [{"poly": ground(866, 8, 16), "soil": true}, {"poly": blob(560, 740, 100, 32, 30)}, {"poly": blob(1080, 640, 100, 32, 31)}, {"poly": blob(800, 430, 100, 30, 32)}],
			"dews": [Vector2(800, 560), Vector2(150, 600), Vector2(1480, 380)],
			"goals": [{"pos": Vector2(580, 675)}, {"pos": Vector2(1060, 575), "after": 0}, {"pos": Vector2(800, 365), "after": 1}],
			"guide": [{"swipe": [Vector2(720, 800), Vector2(880, 800)]}],
		},
		{
			"id": "heartwood", "title": "The Heartwood",
			"intro": "Ride the updraft to the key-bloom, pass the heat, and wake the sunwell sealed in the dark heartwood.",
			"hint": "One seed must glow and endure heat. Ride the updraft to the key, then lure your shoot to the open gate.",
			"palette": "night", "seed": Vector2(240, 852), "energy": 6200.0, "lures": 2, "prunes": 3, "par": 4,
			"rocks": [{"poly": ground(866, 8, 17), "soil": true}, {"poly": blob(680, 200, 90, 30, 33)},
				{"poly": [Vector2(1180, -100), Vector2(1700, -100), Vector2(1700, 220), Vector2(1180, 220)]},
				{"poly": [Vector2(1250, 560), Vector2(1700, 560), Vector2(1700, 610), Vector2(1250, 610)]},
				{"poly": [Vector2(1180, 220), Vector2(1225, 220), Vector2(1225, 560), Vector2(1180, 560)], "gate": "g1"},
				{"poly": blob(1050, 680, 90, 30, 34)}, {"poly": blob(1000, 430, 70, 26, 36)}],
			"updrafts": [{"rect": Rect2(440, 240, 150, 620), "dir": Vector2.UP}],
			"switches": [{"pos": Vector2(515, 215), "opens": ["g1"]}],
			"vents": vent_column(860.0, 100.0),
			"darks": [{"pos": Vector2(1420, 390), "r": 200.0}],
			"dews": [Vector2(860, 450), Vector2(1450, 280), Vector2(100, 600)],
			"goals": [{"pos": Vector2(1420, 400)}],
			"wilds": [{"pos": Vector2(140, 852), "genome": "Emberwax", "energy": 240.0}, {"pos": Vector2(340, 852), "genome": "Lanternwort", "energy": 240.0}],
			"guide": [{"lure": Vector2(515, 820)}, {"lure": Vector2(1200, 420)}],
		},
	]
