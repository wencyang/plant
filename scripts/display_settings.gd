extends RefCounted
class_name GameDisplaySettings
## Canvas items render at the physical window resolution. Only the interface's
## coordinate system scales; no low-resolution render target is enlarged.
signal changed()
const DESIGN_SIZE := Vector2i(1440, 1000)
const LARGE_SIZE := Vector2i(2880, 2000)
const STORAGE := "user://display_v1.cfg"
var enabled: bool = false
var window: Window
var windowed_size := LARGE_SIZE
var storage_path: String = STORAGE
var _updating: bool = false
var preferred_screen: int = -1

func _init(path: String = STORAGE) -> void:
	storage_path = path

static func canvas_scale(physical_size: Vector2i) -> float:
	return clampf(minf(float(physical_size.x) / DESIGN_SIZE.x, float(physical_size.y) / DESIGN_SIZE.y), 1.0, 2.0)

static func fitted_size(requested: Vector2i, usable: Vector2i) -> Vector2i:
	var available := Vector2i(maxi(390, usable.x - 80), maxi(780, usable.y - 100))
	var ratio: float = minf(1.0, minf(float(available.x) / requested.x, float(available.y) / requested.y))
	return Vector2i(maxi(390, roundi(requested.x * ratio)), maxi(780, roundi(requested.y * ratio)))

func configure(target: Window, restore: bool = true) -> void:
	window = target
	enabled = DisplayServer.get_name() != "headless" and not OS.has_feature("web") and not OS.has_feature("mobile")
	if not enabled: return
	window.content_scale_size = Vector2i.ZERO
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	if restore:
		var prefs := ConfigFile.new()
		if prefs.load(storage_path) == OK:
			var stored: Variant = prefs.get_value("display", "window_size", LARGE_SIZE)
			preferred_screen = int(prefs.get_value("display","screen",-1))
			if stored is Vector2i: windowed_size = stored
			elif stored is Vector2: windowed_size = Vector2i(stored)
	if preferred_screen < 0 or preferred_screen >= DisplayServer.get_screen_count():
		preferred_screen = 0
		var largest_area: int = 0
		for index in range(DisplayServer.get_screen_count()):
			var dimensions: Vector2i = DisplayServer.screen_get_size(index)
			if dimensions.x * dimensions.y > largest_area:
				largest_area = dimensions.x * dimensions.y
				preferred_screen = index
	window.current_screen = preferred_screen
	_set_windowed_size(windowed_size)
	if not window.size_changed.is_connected(_resized): window.size_changed.connect(_resized)
	_refresh_scale()

func _screen_rect() -> Rect2i:
	return DisplayServer.screen_get_usable_rect(window.current_screen)

func _set_windowed_size(requested: Vector2i) -> void:
	if not enabled: return
	var screen: Rect2i = _screen_rect()
	var target: Vector2i = fitted_size(requested, screen.size)
	_updating = true
	window.mode = Window.MODE_WINDOWED
	window.position = screen.position + (screen.size - target) / 2
	window.size = target
	window.position = screen.position + (screen.size - window.size) / 2
	windowed_size = target
	_updating = false
	_refresh_scale()

func set_preset(requested: Vector2i) -> void:
	_set_windowed_size(requested)
	_save()

func set_screen(index: int) -> void:
	if not enabled or index < 0 or index >= DisplayServer.get_screen_count(): return
	preferred_screen = index
	window.current_screen = index
	_set_windowed_size(windowed_size)
	_save()

func use_large_window() -> void:
	set_preset(LARGE_SIZE)

func toggle_fullscreen() -> void:
	if not enabled: return
	_updating = true
	if is_fullscreen():
		window.mode = Window.MODE_WINDOWED
		_updating = false
		_set_windowed_size(windowed_size)
	else:
		windowed_size = window.size
		window.mode = Window.MODE_FULLSCREEN
		_updating = false
		_refresh_scale()
	_save()

func is_fullscreen() -> bool:
	return enabled and window.mode in [Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN]

func _resized() -> void:
	if _updating: return
	_refresh_scale()

func _refresh_scale() -> void:
	if not enabled: return
	var factor: float = canvas_scale(window.size)
	if not is_equal_approx(window.content_scale_factor, factor): window.content_scale_factor = factor
	changed.emit()

func description() -> String:
	if not is_instance_valid(window): return ""
	return "%d × %d pixels  ·  Interface %d%%" % [window.size.x, window.size.y, roundi(window.content_scale_factor * 100)]

func _save() -> void:
	if not enabled: return
	var prefs := ConfigFile.new()
	prefs.set_value("display", "window_size", windowed_size)
	prefs.set_value("display", "screen", window.current_screen)
	prefs.save(storage_path)
