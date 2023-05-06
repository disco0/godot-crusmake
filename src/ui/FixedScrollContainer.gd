tool
class_name ScrollContainerFixed
extends ScrollContainer


#section members


export (NodePath) var target_child

onready var _v_scroll := get_v_scrollbar()

var root: Control
var hide_scrollbars := true

var base_horizontal_margin := 4


#section lifecycle


func _ready() -> void:
	update_target_child()
	stylize()

	if is_instance_valid(root):
		_v_scroll.connect("visibility_changed", self, "_on_scroll_bar_visibility_changed")


func update_target_child() -> void:
	var new_target := get_node(target_child)
	if new_target:
		print('[update_target_child] Set target: %s' %  [ new_target ])
		root = new_target
	# Fallback to first child after warning
	else:
		push_warning('target_child unset or failed to resolve to child node path, attempting resolve to first Control based node.')
		var children := get_children()
		if children.size() > 0:
			for child in children:
				if child is Control:
					root = child
					break


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_PARENTED,\
		NOTIFICATION_VISIBILITY_CHANGED,\
		NOTIFICATION_MOVED_IN_PARENT,\
		NOTIFICATION_READY:
			if visible:
				rect_size = .get_parent_area_size()


func _on_scroll_bar_visibility_changed() -> void:
	return
	if not is_instance_valid(root): return

	_v_scroll.get_global_rect().size.x = 0.0
	var x := 0.0
	if _v_scroll.visible:
		root.set("custom_constants/margin_right", base_horizontal_margin)
		root.set("custom_constants/margin_left",  base_horizontal_margin)
	else:
		root.set("custom_constants/margin_right", base_horizontal_margin)
		root.set("custom_constants/margin_left",  base_horizontal_margin)


#section methods


func stylize():
	if _v_scroll and hide_scrollbars:
		var empty := BuildScrollEmptyStylebox()
		for name in [ 'grabber', 'grabber_highlight', 'grabber_pressed', 'scroll', 'scroll_focus' ]:
			_v_scroll.add_stylebox_override(name, empty)


func disable_scrollbars() -> void:
	var invisible_scrollbar_theme = Theme.new()
	var empty_stylebox = StyleBoxEmpty.new()

	invisible_scrollbar_theme.set_stylebox("scroll", "VScrollBar", empty_stylebox)
	invisible_scrollbar_theme.set_stylebox("scroll", "HScrollBar", empty_stylebox)

	get_v_scrollbar().theme = invisible_scrollbar_theme
	get_h_scrollbar().theme = invisible_scrollbar_theme


#section statics


static func BuildScrollEmptyStylebox() -> StyleBoxEmpty:
	var empty := StyleBoxEmpty.new()
	#empty.content_margin_top    = 0
	#empty.content_margin_bottom = 0
	#empty.content_margin_left   = 0
	#empty.content_margin_right  = 0
	return empty



#section classes
