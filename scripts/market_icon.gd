extends Control
## Original little market goods on a crisp 24 × 24 pixel grid.
var kind: String = "stall":
	set(value):
		kind = value
		queue_redraw()
var _unit: float = 1.0
var _origin := Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	resized.connect(queue_redraw)

func _p(x: int,y: int,w: int,h: int,color: String) -> void:
	draw_rect(Rect2(_origin+Vector2(x,y)*_unit,Vector2(w,h)*_unit),Color(color))

func _draw() -> void:
	_unit = maxf(1.0,floorf(minf(size.x,size.y)/24.0))
	_origin = ((size-Vector2(24,24)*_unit)*0.5).floor()
	match kind:
		"coin":
			_p(3,15,13,5,"ba8947"); _p(2,14,15,3,"e6b65f")
			_p(4,13,11,2,"ffe59b"); _p(4,18,11,2,"d79c4f")
			_p(11,5,8,13,"b98442"); _p(9,7,12,9,"d9a04a")
			_p(11,6,8,11,"f5c96b"); _p(10,8,10,7,"f5c96b")
			_p(12,8,6,7,"e6b052"); _p(14,8,2,7,"fff0ae")
			_p(12,10,6,3,"fff0ae"); _p(11,7,2,2,"fff1be")
		"seed":
			_p(5,4,14,17,"bc995f"); _p(6,3,12,17,"f2d99d")
			_p(7,5,10,12,"fff0bf"); _p(6,18,12,2,"d7af6c")
			_p(11,10,2,6,"67964a"); _p(8,8,4,4,"8fbc62")
			_p(13,7,4,4,"a4c977"); _p(10,15,5,2,"ba884e")
			_p(8,5,8,1,"d6ad6b")
		"fruit":
			_p(5,9,14,10,"bb7750"); _p(4,11,16,6,"e78e62")
			_p(6,8,12,12,"f4af75"); _p(7,10,10,8,"ffbd82")
			_p(8,19,8,2,"d98659"); _p(10,9,3,10,"e99b62")
			_p(12,4,2,5,"8b7045"); _p(14,4,5,3,"7eae5a")
			_p(8,5,4,2,"a4c976"); _p(7,10,2,3,"ffe3a8")
		"receipt":
			_p(6,3,13,18,"bfa77a"); _p(5,2,13,18,"fff0c7")
			_p(7,5,9,2,"7da16b"); _p(7,9,7,1,"b8bf8a")
			_p(7,12,9,1,"b8bf8a"); _p(7,15,5,1,"b8bf8a")
			_p(5,19,2,3,"fff0c7"); _p(9,19,2,3,"fff0c7")
			_p(13,19,2,3,"fff0c7"); _p(17,19,1,3,"fff0c7")
			_p(15,15,5,4,"d88666"); _p(16,14,3,6,"d88666")
			_p(17,16,1,2,"ffe4bd")
		"sunlight":
			_p(10,2,4,3,"e0ac49"); _p(10,19,4,3,"e0ac49")
			_p(2,10,3,4,"e0ac49"); _p(19,10,3,4,"e0ac49")
			_p(5,5,2,2,"eac168"); _p(17,5,2,2,"eac168")
			_p(5,17,2,2,"eac168"); _p(17,17,2,2,"eac168")
			_p(8,6,8,12,"e6b64f"); _p(6,8,12,8,"e6b64f")
			_p(8,7,8,10,"ffdc7c"); _p(7,9,10,6,"ffdc7c")
			_p(9,8,3,3,"fff0b2")
		"kit":
			_p(7,3,10,5,"86744e"); _p(9,4,6,3,"fff0bf")
			_p(4,7,16,14,"638e72"); _p(5,8,14,12,"a5cf9d")
			_p(4,8,16,4,"7aab83"); _p(10,10,4,4,"e1b56b")
			_p(7,15,10,4,"82b28a"); _p(7,8,2,2,"d7e7b8")
		"graft":
			_p(11,3,2,13,"8a7447"); _p(7,6,4,3,"91b666")
			_p(13,4,5,3,"accd7a"); _p(9,10,6,5,"e2c789")
			_p(10,11,4,1,"fff0bd"); _p(10,13,4,1,"fff0bd")
			_p(3,14,5,7,"c4805b"); _p(4,15,3,4,"f2c68a")
			_p(16,14,5,7,"c4805b"); _p(17,15,3,4,"f2c68a")
			_p(7,13,3,3,"91a8a0"); _p(14,13,3,3,"91a8a0")
			_p(9,16,6,2,"758e88"); _p(11,16,2,2,"e5e7bf")
		"agent":
			_p(9,2,6,3,"9c8355"); _p(8,5,8,3,"d8c1a2")
			_p(6,8,12,13,"9a82a4"); _p(7,8,10,11,"cbb5d3")
			_p(8,12,8,6,"a788b6"); _p(9,10,2,2,"f1dbe7")
			_p(12,14,2,2,"edcce3"); _p(8,8,2,4,"fff0d2")
			_p(18,5,2,2,"dfb77b"); _p(20,3,2,2,"dfb77b")
		_:
			# Coral-striped canvas, warm timber and a freshly potted little sprout.
			_p(4,5,2,17,"a68050"); _p(18,5,2,17,"a68050")
			_p(4,2,16,4,"f0a17a"); _p(2,6,20,3,"e38d68")
			_p(4,3,3,6,"fff0c5"); _p(10,3,3,6,"fff0c5")
			_p(16,3,3,6,"fff0c5"); _p(2,9,3,2,"d7805f")
			_p(8,9,3,2,"d7805f"); _p(14,9,3,2,"d7805f")
			_p(20,9,2,2,"d7805f"); _p(3,17,18,4,"b68a52")
			_p(4,18,16,2,"dfb67a"); _p(5,21,3,2,"906e47")
			_p(16,21,3,2,"906e47"); _p(7,14,5,3,"cc8e5b")
			_p(9,10,1,5,"6c9d50"); _p(6,11,3,2,"9dc36a")
			_p(10,9,4,2,"88b75d"); _p(15,13,3,4,"efd284")
			_p(15,12,3,1,"b39553")
