extends PanelContainer
signal benched(id: String)
func _can_drop_data(_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("plant_id")
func _drop_data(_position: Vector2, data: Variant) -> void:
	benched.emit(str(data.plant_id))
