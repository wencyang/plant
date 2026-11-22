extends RefCounted
class_name GameLocale
## Presentation-only localization. Saved genes, IDs, names and OptionButton
## metadata always remain canonical, so changing language never changes a plant.
const DEFAULT_SETTINGS := "user://language_v1.cfg"
const CATALOG_PATH := "res://assets/i18n/zh_CN.json"
const CJK_FONT_PATH := "res://assets/fonts/NotoSansCJKsc-Regular.otf"
static var _language: String = "en"
static var _settings_path: String = DEFAULT_SETTINGS
static var _catalog: Dictionary = {}
static var _folded: Dictionary = {}
static var _templates: Array = []
static var _translation_cache: Dictionary = {}
static var _loaded: bool = false
static var _font: Font
static var _phrase_regex: RegEx
static var _format_regex: RegEx
static var _sentences: RegEx
static var _name_first := {"Pearl":"珠光","Dusk":"暮色","Quiet":"静谧","Amber":"琥珀","Hollow":"空幽","Glass":"琉璃","Rain":"雨","Velvet":"绒","Pale":"苍白","Silt":"泥沙","Silver":"银","Woven":"织"}
static var _name_last := {"Veil":"纱","Crown":"冠","Whisper":"低语","Lantern":"灯","Thread":"丝","Lumen":"光","Frond":"蕨叶","Vessel":"器","Bloom":"花","Husk":"壳","Chalice":"杯","Spiral":"螺旋"}

static func get_language() -> String:
	return _language

static func set_language(code: String) -> void:
	_language = "zh_CN" if code.to_lower().replace("-","_") in ["zh","zh_cn","zh_hans","cn"] else "en"
	TranslationServer.set_locale(_language)
	_ensure_catalog()

static func load_settings(path: String = DEFAULT_SETTINGS) -> void:
	_settings_path = path
	var cfg := ConfigFile.new()
	if cfg.load(path) == OK:
		set_language(str(cfg.get_value("language","locale","en")))
	else:
		set_language("en")

static func save_settings(path: String = "") -> void:
	if not path.is_empty(): _settings_path = path
	var cfg := ConfigFile.new()
	cfg.set_value("language","locale",_language)
	cfg.save(_settings_path)

static func get_ui_font() -> Font:
	if _font == null and FileAccess.file_exists(CJK_FONT_PATH):
		var bundled := FontFile.new()
		bundled.data = FileAccess.get_file_as_bytes(CJK_FONT_PATH)
		if bundled.has_char(0x4e2d): _font = bundled
	if _font == null and ResourceLoader.exists(CJK_FONT_PATH): _font = load(CJK_FONT_PATH) as Font
	if _font == null:
		var cjk := SystemFont.new()
		# Prefer a real installed CJK family. Some macOS PingFang UI entries
		# are reserved font-service stubs and cannot be read by FreeType.
		var available: PackedStringArray = OS.get_system_fonts()
		var selected: String = "Arial"
		for family in ["Heiti SC","Microsoft YaHei","Noto Sans CJK SC","Noto Sans SC","WenQuanYi Zen Hei","Songti SC","PingFang SC"]:
			if family in available:
				var path: String = OS.get_system_font_path(family)
				if FileAccess.file_exists(path) and not path.contains("/Reserved/"):
					selected = family
					break
		cjk.font_names = PackedStringArray([selected])
		cjk.font_weight = 400
		_font = cjk
	return _font

static func text(english: String) -> String:
	if _language == "en" or english.is_empty(): return english
	_ensure_catalog()
	if _translation_cache.has(english): return str(_translation_cache[english])
	var result: String = _translate(english,0)
	if _translation_cache.size() > 4096: _translation_cache.clear()
	_translation_cache[english] = result
	return result

static func _escape_regex(value: String) -> String:
	var result: String = ""
	for i in range(value.length()):
		var ch: String = value.substr(i,1)
		if ch in ["\\",".","^","$","|","?","*","+","(",")","[","]","{","}"]: result += "\\"
		result += ch
	return result

static func _ensure_catalog() -> void:
	if _loaded: return
	_loaded = true
	if FileAccess.file_exists(CATALOG_PATH):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
		if data is Dictionary: _catalog = data
	_format_regex = RegEx.new()
	_format_regex.compile("%%|%[-+0 #]*[0-9]*(?:\\.[0-9]+)?[sdf]")
	_sentences = RegEx.new()
	_sentences.compile("[^.!?\\n]+(?:[.!?](?=\\s|$)|$)")
	var phrases: Array = []
	for key: String in _catalog:
		_folded[key.to_lower()] = str(_catalog[key])
		var matches: Array = _format_regex.search_all(key)
		var has_argument: bool = false
		for found: RegExMatch in matches:
			if found.get_string() != "%%": has_argument = true
		if has_argument:
			var expression: String = "(?s)^"
			var cursor: int = 0
			var kinds: Array = []
			var literal_size: int = key.length()
			for found: RegExMatch in matches:
				expression += _escape_regex(key.substr(cursor,found.get_start()-cursor))
				var spec: String = found.get_string()
				if spec == "%%": expression += "%"
				else:
					kinds.append(spec.right(1))
					literal_size -= spec.length()
					expression += "(.*?)" if spec.ends_with("s") else ("(-?[0-9]+)" if spec.ends_with("d") else "(-?[0-9]+(?:\\.[0-9]+)?)")
				cursor = found.get_end()
			expression += _escape_regex(key.substr(cursor))+"$"
			if literal_size >= 2:
				var regex := RegEx.new()
				if regex.compile(expression) == OK: _templates.append({"regex":regex,"kinds":kinds,"target":_catalog[key],"weight":literal_size})
		elif key.length() > 1 and key.length() < 65 and not key.contains("\n") and not key.contains("%"):
			phrases.append(key)
	_templates.sort_custom(func(a,b): return int(a.weight) > int(b.weight))
	phrases.sort_custom(func(a,b): return str(a).length() > str(b).length())
	var escaped: Array[String] = []
	for phrase: String in phrases: escaped.append(_escape_regex(phrase))
	_phrase_regex = RegEx.new()
	_phrase_regex.compile("(?i)(?<![A-Za-z0-9_])(?:"+"|".join(escaped)+")(?![A-Za-z0-9_])")

static func _translate(source: String, depth: int) -> String:
	if source.is_empty() or depth > 5: return source
	if _catalog.has(source): return str(_catalog[source])
	if _folded.has(source.to_lower()): return str(_folded[source.to_lower()])
	var stripped: String = source.strip_edges()
	if stripped != source:
		var start: int = source.find(stripped)
		return source.substr(0,start)+_translate(stripped,depth+1)+source.substr(start+stripped.length())
	if source.begins_with("↳ "): return "↳ "+_translate(source.substr(2),depth+1)
	var pieces: PackedStringArray = source.split(" ",false)
	if pieces.size() == 2 and _name_first.has(pieces[0]) and _name_last.has(pieces[1]):
		return str(_name_first[pieces[0]])+str(_name_last[pieces[1]])
	for entry: Dictionary in _templates:
		var matched: RegExMatch = entry.regex.search(source)
		if matched == null: continue
		var values: Array = []
		for i in range(entry.kinds.size()):
			var captured: String = matched.get_string(i+1)
			match str(entry.kinds[i]):
				"d": values.append(int(captured))
				"f": values.append(float(captured))
				_: values.append(_translate(captured,depth+1))
		return str(entry.target) % values
	if source.contains("\n"):
		var lines: PackedStringArray = source.split("\n")
		for i in range(lines.size()): lines[i] = _translate(lines[i],depth+1)
		return "\n".join(lines)
	# Garden stories can be assembled sentence by sentence in canonical English.
	var sentences: Array = _sentences.search_all(source)
	if sentences.size() > 1:
		var translated: Array[String] = []
		for sentence: RegExMatch in sentences: translated.append(_translate(sentence.get_string().strip_edges(),depth+1))
		return " ".join(translated)
	var translated: String = ""
	var cursor: int = 0
	for found: RegExMatch in _phrase_regex.search_all(source):
		translated += source.substr(cursor,found.get_start()-cursor)
		translated += str(_folded.get(found.get_string().to_lower(),found.get_string()))
		cursor = found.get_end()
	translated += source.substr(cursor)
	return translated

static func _property(node: Object, property: StringName) -> void:
	var original_key := StringName("_locale_source_"+str(property))
	var rendered_key := StringName("_locale_rendered_"+str(property))
	var current: String = str(node.get(property))
	var source: String = str(node.get_meta(original_key,current))
	var previous: String = str(node.get_meta(rendered_key,""))
	if not node.has_meta(original_key) or current != previous:
		source = current
		node.set_meta(original_key,source)
	var rendered: String = text(source)
	if current != rendered: node.set(property,rendered)
	node.set_meta(rendered_key,rendered)

static func _options(node: OptionButton) -> void:
	var sources: Array = node.get_meta("_locale_option_sources",[])
	var rendered: Array = node.get_meta("_locale_option_rendered",[])
	if sources.size() != node.item_count:
		sources = []
		rendered = []
		for i in range(node.item_count): sources.append(node.get_item_text(i)); rendered.append("")
	for i in range(node.item_count):
		if node.get_item_text(i) != rendered[i]: sources[i] = node.get_item_text(i)
		var value: String = text(str(sources[i]))
		if node.get_item_text(i) != value: node.set_item_text(i,value)
		rendered[i] = value
	node.set_meta("_locale_option_sources",sources)
	node.set_meta("_locale_option_rendered",rendered)

static func _control_font(control: Control) -> void:
	if not control.has_meta("_locale_original_font_present"):
		control.set_meta("_locale_original_font_present",control.has_theme_font_override("font"))
		if control.has_theme_font_override("font"): control.set_meta("_locale_original_font",control.get_theme_font("font"))
	if _language == "zh_CN":
		if not control.has_theme_font_override("font") or control.get_theme_font("font") != get_ui_font(): control.add_theme_font_override("font",get_ui_font())
	elif bool(control.get_meta("_locale_original_font_present",false)):
		var original: Font = control.get_meta("_locale_original_font")
		if control.get_theme_font("font") != original: control.add_theme_font_override("font",original)
	else:
		control.remove_theme_font_override("font")

static func apply_tree(root: Node) -> void:
	if not is_instance_valid(root): return
	if root is OptionButton:
		_options(root)
		_control_font(root)
	elif root is Label or root is Button or root is RichTextLabel:
		_property(root,&"text")
		_control_font(root)
	elif root is LineEdit:
		_property(root,&"placeholder_text")
		_control_font(root)
	if root is Control and (not root.tooltip_text.is_empty() or root.has_meta("_locale_source_tooltip_text")):
		_property(root,&"tooltip_text")
	for child: Node in root.get_children(): apply_tree(child)
