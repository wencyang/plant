extends RefCounted
## Plant genomes are plain Dictionaries (easy to save). Every gene is visible:
## growth behaviour, form, colour, organs. Crossing takes each gene from one
## parent, so a hybrid visibly wears features from both.

const TRAITS := ["thorns", "glow", "tendrils", "roots", "buoyant", "waxy"]
const TRAIT_INFO := {
	"thorns":   {"name": "Thorns",   "desc": "Thorny tips shatter crystal.",          "color": Color(1.0, 0.45, 0.35)},
	"glow":     {"name": "Glow",     "desc": "Glows, so it can grow in the dark.",    "color": Color(0.55, 1.0, 0.85)},
	"tendrils": {"name": "Tendrils", "desc": "Tendrils cling and climb glassy rock.", "color": Color(0.75, 0.95, 0.35)},
	"roots":    {"name": "Roots",    "desc": "Roots seek water and drink energy.",   "color": Color(0.95, 0.8, 0.55)},
	"buoyant":  {"name": "Buoyant",  "desc": "Floating bladders let it reach far across open air.", "color": Color(0.6, 0.8, 1.0)},
	"waxy":     {"name": "Waxy",     "desc": "A waxy skin lets it grow through ember vents.",   "color": Color(1.0, 0.7, 0.3)},
}
const LEAF_NAMES := ["blade", "fan", "frond", "needle", "heart", "ribbon"]
const FLOWER_NAMES := ["bell", "star", "lantern", "frill", "puff", "orchid"]
const PATTERN_NAMES := ["plain", "banded", "spotted", "veined"]
const STEM_NAMES := ["smooth", "jointed", "twisted"]

# float genes and their ranges
const RANGES := {
	"speed": [45.0, 120.0], "branch": [0.05, 0.9], "spread": [0.25, 1.2], "photo": [0.2, 1.2],
	"curl": [-1.2, 1.2], "reach": [300.0, 560.0], "leaf_size": [0.6, 1.6], "hue": [0.0, 1.0], "hue2": [0.0, 1.0],
}
const VISUAL_INTS := {"leaf_shape": 3, "flower": 3, "pattern": 3, "stem": 2, "petals": 9}

static func make(d: Dictionary) -> Dictionary:
	var g := {
		"name": "Firstling", "species": "Firstling", "gen": 1, "parents": [],
		"speed": 70.0, "branch": 0.35, "spread": 0.6, "photo": 0.7, "curl": 0.0, "reach": 420.0,
		"hue": 0.36, "hue2": 0.12, "leaf_shape": 0, "leaf_size": 1.0, "flower": 0, "petals": 5, "pattern": 0, "stem": 0,
		"thorns": 0, "glow": 0, "tendrils": 0, "roots": 0, "buoyant": 0, "waxy": 0, "origin": {},
	}
	for k in d: g[k] = d[k]
	return g

static func traits(g: Dictionary) -> Array:
	var out: Array = []
	for t in TRAITS:
		if int(g.get(t, 0)) > 0: out.append(t)
	return out

## Returns three seedlings. Seed 0 always carries every trait of both
## parents, so pollinating the right wild plant is always rewarded.
static func cross(a: Dictionary, b: Dictionary, rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	for i in 3:
		var c := {}
		var origin := {}
		for k in RANGES:
			var from_a := rng.randf() < 0.5
			var v: float = float(a[k]) if from_a else float(b[k])
			if k != "hue" and k != "hue2":
				v *= rng.randf_range(0.93, 1.08)
				v = clampf(v, RANGES[k][0], RANGES[k][1])
			else:
				v = wrapf(v + rng.randf_range(-0.03, 0.03), 0.0, 1.0)
			c[k] = v
			origin[k] = a.species if from_a else b.species
		for k in VISUAL_INTS:
			var from_a := rng.randf() < 0.5
			c[k] = a[k] if from_a else b[k]
			origin[k] = a.species if from_a else b.species
		if rng.randf() < 0.08:  # small petal-count mutation
			c.petals = clampi(int(c.petals) + (1 if rng.randf() < 0.5 else -1), 3, 9)
		for t in TRAITS:
			var ta := int(a.get(t, 0)) > 0
			var tb := int(b.get(t, 0)) > 0
			var has := false
			if i == 0: has = ta or tb
			elif ta and tb: has = rng.randf() < 0.9
			elif ta or tb: has = rng.randf() < 0.5
			c[t] = 1 if has else 0
			if has: origin[t] = a.species if (ta and (not tb or rng.randf() < 0.5)) else b.species
		c.gen = max(int(a.gen), int(b.gen)) + 1
		c.parents = [a.name, b.name]
		c.species = "Hybrid"
		c.name = hybrid_name(a, b, rng)
		c.origin = origin
		out.append(make(c))
	return out

static func hybrid_name(a: Dictionary, b: Dictionary, rng: RandomNumberGenerator) -> String:
	var x: String = a.name
	var y: String = b.name
	var left := x.substr(0, max(2, int(ceil(x.length() * rng.randf_range(0.35, 0.6)))))
	var right := y.substr(int(y.length() * rng.randf_range(0.4, 0.65)))
	var n := (left + right.to_lower())
	if n.length() > 13: n = n.substr(0, 13)
	return n

static func hue_color(h: float, s := 0.6, v := 0.9) -> Color:
	return Color.from_hsv(h, s, v)

static func feature_summary(g: Dictionary) -> String:
	return "%s leaves · %s flowers (%d petals) · %s · %s stem" % [LEAF_NAMES[int(g.leaf_shape)], FLOWER_NAMES[int(g.flower)], int(g.petals), PATTERN_NAMES[int(g.pattern)], STEM_NAMES[int(g.stem)]]
