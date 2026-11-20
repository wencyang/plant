extends SceneTree
const Locale = preload("res://scripts/localization.gd")
var checks: int = 0
var failures: int = 0
func _initialize() -> void:
	call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func run() -> void:
	Locale.set_language("en")
	check(Locale.text("Quiet Conservatory") == "Quiet Conservatory","English remains canonical")
	Locale.set_language("zh-CN")
	check(Locale.get_language() == "zh_CN","Simplified Chinese locale alias is normalized")
	check(Locale.text("Quiet Conservatory") == "静谧温室","Garden heading is translated")
	check(Locale.get_ui_font() is FontFile and Locale.get_ui_font().has_char(0x4e2d) and Locale.get_ui_font().has_char(0x6587),"Bundled Chinese glyphs render without installed system fonts")
	check(Locale.text("A wild Ghostcap!") == "野生幽光菇！","Formatted encounter titles translate their species")
	check(Locale.text("Collect · 98%") == "采集 · 98%","Formatted collection percentages preserve values")
	check(Locale.text("Vitality 122   Growth 17   Bloom 21") == "生命 122  生长 17  绽放 21","Dynamic stat values translate without changing numbers")
	check(Locale.text("Common · Bloom · G3") == "普通 · 花 · 第3代","Typed phenotype labels localize in formatted structures")
	check(Locale.text("Silver Thread") == "银丝","Founder names have stable display translations")
	check(Locale.text("Glass Crown") == "琉璃冠","Recognizable generated botanical names are translated")
	check(Locale.text("Crossbreeding") == "杂交育种" and Locale.text("Fruit & seeds") == "果实与种子","Core breeding and harvest navigation translates")
	check(Locale.text("Hybrid fruit developing · 12 seconds") == "杂交果实生长中 · 剩余12秒","Hybrid fruit countdown preserves the actual remaining time")
	check(Locale.text("Harvested 2 fruit. Open the fruit to collect its seeds. +40 gathered light.") == "已采收2个果实，打开即可收集种子。获得40采集光照。","Fruit harvest results retain exact fruit and light counts")
	check(Locale.text("Collected 3 seeds. Their full genomes and parentage are preserved for planting.") == "已收集3颗种子，完整基因和双亲记录均已保存，可继续播种。","Full-genome seed collection has a complete Chinese explanation")
	check(Locale.text("My custom Iris 8") == "My custom Iris 8","Unknown custom names remain unchanged")
	check(Locale.text("2880 × 2000 pixels  ·  Interface 200%") == "2880 × 2000像素 · 界面缩放200%","Display output keeps exact dimensions and scaling")
	check(Locale.text("The roots grew quiet after 123 seconds. Connected growth restored 20 vitality. 3 bloom events; 142 vitality remains.").contains("123秒"),"Assembled battle summaries translate sentence fragments")
	var panel := VBoxContainer.new()
	root.add_child(panel)
	var label := Label.new()
	label.text = "Collect · 80%"
	panel.add_child(label)
	var edit := LineEdit.new()
	edit.text = "Custom Fern / 我的植物"
	edit.placeholder_text = "Name this plant"
	panel.add_child(edit)
	var choices := OptionButton.new()
	choices.add_item("Radiation · broad mutation")
	choices.add_item("Chemical · pattern-focused")
	choices.set_item_metadata(0,"radiation")
	choices.set_item_metadata(1,"chemical")
	panel.add_child(choices)
	var button := Button.new()
	button.text = "Explore wilds →"
	button.tooltip_text = "Tap to inspect · Hold for genes · Drag to plant"
	panel.add_child(button)
	Locale.apply_tree(panel)
	check(label.text == "采集 · 80%","Existing labels translate")
	check(edit.text == "Custom Fern / 我的植物","Editable plant names are never translated")
	check(edit.placeholder_text == "为这株植物命名","Name field placeholder translates")
	check(choices.get_item_text(0) == "辐射 · 广泛突变","Option labels translate")
	check(choices.get_item_metadata(0) == "radiation" and choices.get_item_metadata(1) == "chemical","Option IDs and backend values remain canonical")
	check(button.tooltip_text == "点击查看 · 长按查看基因 · 拖动栽种","Tooltips translate")
	check(button.get_theme_font("font") == Locale.get_ui_font(),"Chinese controls use a CJK-capable font")
	label.text = "Collect · 90%"
	Locale.apply_tree(panel)
	check(label.text == "采集 · 90%","Fresh dynamic English values update while Chinese is active")
	Locale.set_language("en")
	Locale.apply_tree(panel)
	check(label.text == "Collect · 90%","Switching back restores the latest English source")
	check(choices.get_item_text(0) == "Radiation · broad mutation","Option labels restore on language change")
	check(button.text == "Explore wilds →","Button English source restores")
	check(not button.has_theme_font_override("font"),"Original inherited font is restored")
	check(edit.text == "Custom Fern / 我的植物","Round-trip translation leaves user input untouched")
	var path: String = "/tmp/conservatory_language_%d.cfg" % Time.get_ticks_usec()
	Locale.set_language("zh_CN")
	Locale.save_settings(path)
	Locale.set_language("en")
	Locale.load_settings(path)
	check(Locale.get_language() == "zh_CN","Selected language persists in an isolated preference file")
	check(Locale.text("Travel to Glassfall Landing") == "前往琉璃渡口","Expanded-map destinations translate")
	check(Locale.text("160 / 182 patches resting") == "160 / 182处植物正在休养","Expanded-map progress retains counts")
	Locale.set_language("en")
	panel.queue_free()
	DirAccess.remove_absolute(path)
	await process_frame
	print("LOCALIZATION TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
