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
}

static func get_palette(name: String) -> Dictionary:
	return P.get(name, P["dawn"])
