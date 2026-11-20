extends Control
## Rungs correspond to the displayed game's ACTG genome, not decorative random
## marks. The exact sequence and expressed/carried allele values are below it.
var sequence: String = ""
const COLORS := {"A":Color("d7b575"),"C":Color("bd8f9f"),"G":Color("b8cda5"),"T":Color("77b5b2")}
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size.y = 94
func _draw() -> void:
	if sequence.is_empty(): return
	var count: int = mini(36,sequence.length())
	var step: float = maxf(1,(size.x-12)/float(count))
	var front := PackedVector2Array()
	var back := PackedVector2Array()
	for index in range(count):
		var x: float = 6+(index+0.5)*step
		var offset: float = sin(index*0.53)*27
		var a := Vector2(x,43+offset)
		var b := Vector2(x,43-offset)
		front.append(a)
		back.append(b)
		var color: Color = COLORS.get(sequence[index],COLORS.A)
		draw_line(a,b,Color(color,0.43),2)
		draw_rect(Rect2(a-Vector2(2,2),Vector2(4,4)),color)
		draw_rect(Rect2(b-Vector2(2,2),Vector2(4,4)),color.darkened(0.22))
		draw_string(get_theme_default_font(),Vector2(x-3,90),sequence[index],HORIZONTAL_ALIGNMENT_LEFT,-1,9,color)
	draw_polyline(front,Color("779f83"),1.5)
	draw_polyline(back,Color("4f8479"),1.5)
