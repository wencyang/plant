extends RefCounted
## Persistent meta progress: herbarium discoveries and records.

const PATH := "user://sprout_brawl.json"

var herbarium: Dictionary = {}   # pair key -> {"count": int, "mutant": bool}
var best_trophies := 0
var cups := 0
var runs := 0
var muted := false
var seen_tutorial := false
var path := PATH

func _init(p := PATH) -> void:
	path = p
	load_data()

func load_data() -> void:
	if not FileAccess.file_exists(path): return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null: return
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY: return
	herbarium = data.get("herbarium", {})
	best_trophies = int(data.get("best_trophies", 0))
	cups = int(data.get("cups", 0))
	runs = int(data.get("runs", 0))
	muted = bool(data.get("muted", false))
	seen_tutorial = bool(data.get("seen_tutorial", false))

func save() -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null: return
	f.store_string(JSON.stringify({"herbarium": herbarium, "best_trophies": best_trophies, "cups": cups, "runs": runs, "muted": muted, "seen_tutorial": seen_tutorial}))

## Returns true when this is a brand-new entry.
func discover(key: String, mutant: bool) -> bool:
	var is_new := not herbarium.has(key)
	var entry: Dictionary = herbarium.get(key, {"count": 0, "mutant": false})
	entry.count = int(entry.count) + 1
	entry.mutant = bool(entry.mutant) or mutant
	herbarium[key] = entry
	save()
	return is_new
