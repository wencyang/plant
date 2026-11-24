extends RefCounted
## Static rules data: the eight founding plant families and their abilities.

const ORDER := ["leaf", "bloom", "root", "spore", "vine", "toxin", "snap", "wisp"]

const DATA := {
	"leaf":  {"name": "Sprigling",  "atk": 2, "hp": 2, "tier": 1, "ability": "reseed",   "hue": 0.30, "flower": 0.20},
	"bloom": {"name": "Sunpetal",   "atk": 1, "hp": 3, "tier": 1, "ability": "sunburst", "hue": 0.27, "flower": 0.12},
	"root":  {"name": "Thornroot",  "atk": 1, "hp": 4, "tier": 1, "ability": "thorns",   "hue": 0.22, "flower": 0.06},
	"spore": {"name": "Puffball",   "atk": 3, "hp": 1, "tier": 1, "ability": "burst",    "hue": 0.35, "flower": 0.98},
	"vine":  {"name": "Whiplash",   "atk": 2, "hp": 3, "tier": 2, "ability": "lash",     "hue": 0.33, "flower": 0.55},
	"toxin": {"name": "Nightcap",   "atk": 1, "hp": 4, "tier": 2, "ability": "venom",    "hue": 0.40, "flower": 0.78},
	"snap":  {"name": "Snapjaw",    "atk": 3, "hp": 3, "tier": 3, "ability": "devour",   "hue": 0.26, "flower": 0.99},
	"wisp":  {"name": "Mistlewisp", "atk": 2, "hp": 4, "tier": 3, "ability": "leech",    "hue": 0.48, "flower": 0.60},
}

const ABILITIES := {
	"reseed":   {"name": "Reseed",   "color": Color("7bd65a")},
	"sunburst": {"name": "Sunburst", "color": Color("ffcf3f")},
	"thorns":   {"name": "Thorns",   "color": Color("c8794a")},
	"burst":    {"name": "Spore Pop", "color": Color("ff8ab3")},
	"lash":     {"name": "Lash",     "color": Color("47c98a")},
	"venom":    {"name": "Venom",    "color": Color("b06cff")},
	"devour":   {"name": "Devour",   "color": Color("ff5a4a")},
	"leech":    {"name": "Leech",    "color": Color("7fe0ff")},
}

static func describe(ability: String, p: int) -> String:
	match ability:
		"reseed": return "Faint: a %d/%d Sproutling pops up in its place." % [p, p]
		"sunburst": return "Battle start: every ally gains +%d attack." % p
		"thorns": return "When hit: deal %d damage back to the attacker." % p
		"burst": return "Faint: blast a random enemy for %d." % (p + 1)
		"lash": return "Battle start: whip the backmost enemy for %d." % (p + 1)
		"venom": return "Hits poison the target: %d damage after every clash." % p
		"devour": return "After a knockout: gain +%d/+%d." % [p, p]
		"leech": return "Battle start: steal %d attack from the front enemy." % p
	return ""

static func tier_for_round(round_number: int) -> int:
	if round_number >= 5: return 3
	if round_number >= 3: return 2
	return 1

static func pool(round_number: int) -> Array:
	var max_tier := tier_for_round(round_number)
	var out: Array = []
	for id in ORDER:
		if int(DATA[id].tier) <= max_tier: out.append(id)
	return out

## Every herbarium entry: unordered pairs of families, including purebreds (36).
static func herbarium_keys() -> Array:
	var keys: Array = []
	for i in ORDER.size():
		for j in range(i, ORDER.size()):
			keys.append(pair_key(ORDER[i], ORDER[j]))
	return keys

static func pair_key(a: String, b: String) -> String:
	return a + "+" + b if ORDER.find(a) <= ORDER.find(b) else b + "+" + a
