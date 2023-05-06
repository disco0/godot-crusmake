tool
class_name CruSMakeContextMenu
extends PopupMenu


#section members


enum MENU_ITEMS {
	BUILD,
	CONFIG,
	SAVE,
}


#section lifecycle


func _enter_tree() -> void:
	stylize()


func _ready() -> void:
	set_size(Vector2.ZERO)
	pass


func _input(event: InputEvent) -> void:
	if not event as InputEventMouseButton: return

	var mevent: InputEventMouseButton = event

	if visible and mevent.pressed:
		var content_rect := Rect2(Vector2(), rect_size)
		var mouse_pos := get_local_mouse_position()
		if content_rect.has_point(mouse_pos):
			pass
		else:
			hide()
			if mevent.button_index == BUTTON_LEFT:
				get_tree().set_input_as_handled()

		return


#section methods


func stylize() -> void:
	# Don't update if not in tree or in scene editor
	if not is_inside_tree(): return
	var edited_scene := get_tree().edited_scene_root
	if edited_scene != null and is_instance_valid(edited_scene):
		if self == edited_scene or edited_scene.is_a_parent_of(self):
			return


func present():
	set_size(Vector2.ZERO)
	set_global_position(get_global_mouse_position() + (rect_size * Vector2(-1.0, 0.0)))
	show()


#section statics


#section classes
