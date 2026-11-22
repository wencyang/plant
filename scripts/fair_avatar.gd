extends Control
## Friendly original fair-goers and prize ribbons on a 32-pixel drawing grid.
## Kind: mira / jun / pip / ribbon. Set ribbon=true for a small winner's badge.
var kind: String = "mira":
	set(value):
		kind=value.to_lower()
		queue_redraw()
var ribbon: bool = false:
	set(value):
		ribbon=value
		queue_redraw()
var _unit: float = 1.0
var _origin := Vector2.ZERO

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	resized.connect(queue_redraw)

func _p(x: int,y: int,w: int,h: int,pigment: String) -> void:
	draw_rect(Rect2(_origin+Vector2(x,y)*_unit,Vector2(w,h)*_unit),Color(pigment))

func _draw() -> void:
	if size.x<1 or size.y<1: return
	_unit=maxf(1,floorf(minf(size.x,size.y)/32.0))
	_origin=((size-Vector2(32,32)*_unit)*0.5).floor()
	if kind=="ribbon":
		_draw_ribbon(3,1)
		return
	var skin: String="efc19b"
	var hair: String="a56d47"
	var shirt: String="eea17d"
	var field: String="e8efd0"
	match kind:
		"jun": skin="dba482";hair="40574a";shirt="8cbeb2";field="e1eee0"
		"pip": skin="f0cbac";hair="806047";shirt="d9b875";field="f6e8bc"
	# Stepped paper portrait frame, with a warm shadow instead of a dark box.
	_p(3,2,26,28,"b9c895");_p(2,4,28,24,"b9c895")
	_p(3,3,26,24,field);_p(4,2,24,26,field)
	_p(7,9,18,14,hair);_p(9,7,14,18,hair)
	_p(10,9,12,15,skin);_p(8,13,16,7,skin)
	_p(10,22,12,3,skin);_p(13,24,6,3,skin)
	# Little dot eyes and a two-step smile make the faces readable at 48px.
	_p(11,15,2,2,"3d4d3c");_p(19,15,2,2,"3d4d3c")
	_p(11,14,2,1,"fff1cf");_p(19,14,2,1,"fff1cf")
	_p(14,20,5,1,"9d654e");_p(15,21,3,1,"9d654e")
	_p(10,18,3,1,"e8a38b");_p(20,18,3,1,"e8a38b")
	_p(7,25,18,6,shirt);_p(5,28,22,4,shirt)
	match kind:
		"jun":
			# Leaf cap, square glasses, green apron, and a tiny brass fastener.
			_p(9,6,14,4,"81ad67");_p(7,9,18,2,"619052")
			_p(16,4,6,2,"a8cd79");_p(20,3,4,2,"a8cd79")
			_p(10,14,5,5,"527363");_p(17,14,5,5,"527363")
			_p(11,15,3,3,skin);_p(18,15,3,3,skin)
			_p(12,16,1,1,"3d4d3c");_p(19,16,1,1,"3d4d3c")
			_p(15,15,2,1,"527363");_p(10,25,3,7,"628e6a")
			_p(20,25,3,7,"628e6a");_p(12,28,9,4,"79a47a")
			_p(13,28,1,1,"efd48b")
		"pip":
			# A broad straw hat with a coral band and a little daisy.
			_p(9,3,14,7,"dbb86d");_p(7,7,18,3,"ecca83")
			_p(5,9,23,3,"d6ab61");_p(8,7,16,2,"d28a66")
			_p(23,6,4,3,"fff0c8");_p(24,5,2,5,"fff0c8")
			_p(24,7,2,1,"efc868");_p(13,25,6,2,"fff0c8")
			_p(14,28,4,4,"cf9460");_p(15,29,1,1,"fff0c8")
			_p(10,18,1,1,"bb8261");_p(12,18,1,1,"bb8261")
			_p(20,18,1,1,"bb8261");_p(22,18,1,1,"bb8261")
		_:
			# Coral beret, loose copper curls and a cheerful sprout pin.
			_p(8,4,17,5,"e59674");_p(6,7,19,3,"f0ad86")
			_p(10,3,12,2,"edaa83");_p(19,1,3,3,"a97b4d")
			_p(21,1,4,2,"92b967");_p(7,12,3,12,hair)
			_p(22,11,3,13,hair);_p(8,23,4,3,hair)
			_p(21,23,4,3,hair);_p(12,26,8,6,"89aa6e")
			_p(20,27,1,4,"67904f");_p(18,27,2,2,"a5ca77")
			_p(21,26,3,2,"a5ca77")
	if ribbon:
		_p(24,23,5,8,"d98c7a");_p(23,23,7,5,"f0bd72")
		_p(24,22,5,7,"f0bd72");_p(25,24,3,3,"fff0ba")

func _draw_ribbon(x: int,y: int) -> void:
	_p(x+5,y+17,7,12,"cc8c79");_p(x+14,y+17,7,12,"cc8c79")
	_p(x+6,y+17,5,10,"efac98");_p(x+15,y+17,5,10,"efac98")
	_p(x+6,y+27,3,3,"efac98");_p(x+17,y+27,3,3,"efac98")
	_p(x+6,y+2,14,21,"c49a54");_p(x+2,y+6,22,13,"c49a54")
	_p(x+5,y+4,16,17,"f1c875");_p(x+4,y+6,18,13,"f1c875")
	_p(x+8,y+7,10,11,"fff0ba");_p(x+7,y+9,12,7,"fff0ba")
	# A little leaf in the middle marks a cheerful garden prize.
	_p(x+12,y+9,2,8,"87aa60");_p(x+9,y+10,3,3,"a3c675")
	_p(x+14,y+8,4,3,"a3c675");_p(x+4,y+3,2,2,"fff5d2")
	_p(x+22,y+1,2,2,"efcc7f");_p(x+24,y+3,2,2,"efcc7f")
