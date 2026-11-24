extends RefCounted
## Per-level colour moods for the luminous alien landscapes.

const P := {
	"dawn":   {"top": Color("141a33"), "bottom": Color("c98a6a"), "haze": Color("f0b88a"), "far": Color("5d5878"), "mid": Color("2f2c47"), "rock_a": Color("6d5f7e"), "rock_b": Color("1a1828"), "moss": Color("8af0b0"), "speck": Color("ffcf9a"), "stars": 0.25, "sun": Color("ffd9a0")},
	"cavern": {"top": Color("05080d"), "bottom": Color("16262c"), "haze": Color("2f6a66"), "far": Color("12232a"), "mid": Color("0b161b"), "rock_a": Color("4d5d66"), "rock_b": Color("0d1114"), "moss": Color("5fffd8"), "speck": Color("7ff0ff"), "stars": 0.0, "sun": Color("bff8ff")},
	"dusk":   {"top": Color("0d0820"), "bottom": Color("5a2b58"), "haze": Color("c0608a"), "far": Color("3b2452"), "mid": Color("1e1334"), "rock_a": Color("5c4270"), "rock_b": Color("130d1c"), "moss": Color("ff9ad8"), "speck": Color("ffc0e8"), "stars": 0.6, "sun": Color("ffc2d8")},
	"teal":   {"top": Color("041a22"), "bottom": Color("2a7272"), "haze": Color("8fe0c8"), "far": Color("194a50"), "mid": Color("0d2a30"), "rock_a": Color("3f6870"), "rock_b": Color("0a181c"), "moss": Color("c2ff80"), "speck": Color("d8fff0"), "stars": 0.2, "sun": Color("e0fff0")},
	"ochre":  {"top": Color("1e1006"), "bottom": Color("b86a34"), "haze": Color("f4b46a"), "far": Color("6a3a22"), "mid": Color("341c0e"), "rock_a": Color("80583a"), "rock_b": Color("1c1008"), "moss": Color("ffd27a"), "speck": Color("fff0b0"), "stars": 0.1, "sun": Color("fff0c0")},
	"violet": {"top": Color("070414"), "bottom": Color("36206a"), "haze": Color("9a7aff"), "far": Color("281a50"), "mid": Color("140c2e"), "rock_a": Color("4c3e7a"), "rock_b": Color("0c0818"), "moss": Color("d29bff"), "speck": Color("e8d0ff"), "stars": 0.7, "sun": Color("efe0ff")},
	"night":  {"top": Color("010309"), "bottom": Color("0d2036"), "haze": Color("3f74aa"), "far": Color("0c1a2a"), "mid": Color("06101a"), "rock_a": Color("3a4a5c"), "rock_b": Color("070a10"), "moss": Color("7ffcff"), "speck": Color("b0f8ff"), "stars": 1.0, "sun": Color("d0f4ff")},
	"mist":   {"top": Color("1a2230"), "bottom": Color("8fa3b0"), "haze": Color("dfe8ee"), "far": Color("6a7a88"), "mid": Color("3a4652"), "rock_a": Color("6c7884"), "rock_b": Color("1c2228"), "moss": Color("bff0ff"), "speck": Color("ffffff"), "stars": 0.1, "sun": Color("fffaf0")},
	"ash":    {"top": Color("120606"), "bottom": Color("5a1c10"), "haze": Color("ff7a3a"), "far": Color("3a1a14"), "mid": Color("1e0c08"), "rock_a": Color("4a3634"), "rock_b": Color("120a0a"), "moss": Color("ffb060"), "speck": Color("ff8a40"), "stars": 0.2, "sun": Color("ffe0b0")},
	"aurora": {"top": Color("03070f"), "bottom": Color("10324a"), "haze": Color("5affc0"), "far": Color("13324a"), "mid": Color("08182a"), "rock_a": Color("2e4a5a"), "rock_b": Color("060c14"), "moss": Color("8affd0"), "speck": Color("c8a0ff"), "stars": 1.0, "sun": Color("e8fff4")},
	"jungle": {"top": Color("031208"), "bottom": Color("1f5a32"), "haze": Color("9ae07a"), "far": Color("16402a"), "mid": Color("0a2416"), "rock_a": Color("34503c"), "rock_b": Color("08140c"), "moss": Color("e8ff7a"), "speck": Color("f0ffb0"), "stars": 0.1, "sun": Color("f4ffd0")},
	"coral":  {"top": Color("12071a"), "bottom": Color("c8607a"), "haze": Color("ffb0b8"), "far": Color("6a3050"), "mid": Color("3a1630"), "rock_a": Color("8a4a5c"), "rock_b": Color("200a16"), "moss": Color("7affe8"), "speck": Color("ffe0f0"), "stars": 0.3, "sun": Color("fff0f0")},
	"abyss":  {"top": Color("000000"), "bottom": Color("1a0a2a"), "haze": Color("ff6ab0"), "far": Color("1a0e2a"), "mid": Color("0c0616"), "rock_a": Color("3a2a4a"), "rock_b": Color("06040a"), "moss": Color("ff8ad8"), "speck": Color("ffb0e0"), "stars": 1.0, "sun": Color("ffe8f4")},
}

static func get_palette(name: String) -> Dictionary:
	return P.get(name, P["dawn"])
