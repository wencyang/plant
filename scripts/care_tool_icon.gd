extends Control
## Tiny original pixel tools, drawn sharply at the interface's actual resolution.
var tool: String = "water"
var _unit: float = 1.0
var _origin := Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _p(x: float,y: float,w: float,h: float,color: String) -> void:
	draw_rect(Rect2(_origin+Vector2(x,y)*_unit,Vector2(w,h)*_unit),Color(color))

func _draw() -> void:
	_unit = maxf(1.0,floorf(minf(size.x,size.y)/24.0))
	_origin = (size-Vector2(24,24)*_unit)*0.5
	match tool:
		"water":
			_p(5,8,12,11,"498a9b"); _p(6,8,10,8,"81c8d4")
			_p(2,10,4,6,"498a9b"); _p(3,11,2,3,"e9f5d2")
			_p(16,9,3,3,"498a9b"); _p(18,7,3,4,"81c8d4")
			_p(19,5,3,2,"498a9b"); _p(8,6,6,2,"498a9b")
			_p(20,11,2,3,"67bfe0"); _p(22,15,2,3,"67bfe0")
			_p(9,11,2,4,"c8edf0")
		"longevity":
			_p(9,3,6,3,"c18b4e"); _p(8,6,8,3,"eeb086")
			_p(6,9,12,12,"b96e68"); _p(7,9,10,10,"f2b4b1")
			_p(9,12,2,2,"d56a73"); _p(13,12,2,2,"d56a73")
			_p(9,14,6,2,"d56a73"); _p(11,16,2,2,"d56a73")
			_p(8,9,2,3,"ffe9d6")
		"growth":
			_p(5,8,14,13,"c99b54"); _p(6,7,12,12,"ffe29b")
			_p(7,4,10,4,"dcb36d"); _p(10,12,4,6,"71a751")
			_p(8,12,8,2,"71a751"); _p(10,10,4,2,"71a751")
			_p(11,8,2,2,"71a751"); _p(6,19,12,2,"ad8148")
		"compost":
			_p(4,11,16,10,"b77a50"); _p(5,12,14,6,"dbb078")
			_p(3,10,18,2,"8d6945"); _p(7,8,10,2,"775637")
			_p(9,6,6,2,"9b7547"); _p(11,3,2,5,"719f4e")
			_p(7,3,4,3,"9ac56b"); _p(13,2,5,3,"8db963")
			_p(7,14,2,2,"b78755"); _p(15,15,2,2,"b78755")
		"sunlamp":
			_p(10,3,4,10,"d5a04b"); _p(7,6,10,4,"d5a04b")
			_p(8,4,8,8,"ffe27f"); _p(10,6,4,4,"fff4bd")
			_p(3,7,2,2,"e7b75b"); _p(19,7,2,2,"e7b75b")
			_p(11,15,2,5,"719d55"); _p(7,15,4,3,"91bd66")
			_p(13,13,5,3,"91bd66"); _p(8,20,8,2,"c49460")
		"ripening":
			_p(8,3,10,3,"6e9d77"); _p(8,6,5,4,"6e9d77")
			_p(6,10,11,11,"d88458"); _p(7,10,9,9,"ffbd83")
			_p(8,12,7,5,"fff0ba"); _p(11,13,2,3,"e69158")
			_p(19,5,2,2,"8ed3ca"); _p(21,8,2,2,"8ed3ca")
		"spark":
			_p(10,3,4,18,"f1bd52"); _p(3,10,18,4,"f1bd52")
			_p(7,7,10,10,"ffe591"); _p(10,10,4,4,"fff7c9")
