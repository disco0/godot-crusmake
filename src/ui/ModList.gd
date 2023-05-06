tool
class_name CruSMakeModList
extends VBoxContainer


# TODO: meme hand logic is jank


#section signals


# @param mod_data CruSMakeMod
signal export_requested(mod_data)


#section members


const ListItem := preload("./ModListItem.tscn")
const CruSHandPath := "res://Textures/Menu/mouse_cursor.png"
const ListItemGroup := 'mod-list-item'

# Used by parent scrollcontainer
var focus_hand_disabled := false
var focus_hand: TextureRect
var focus_hand_target: Control setget set_focus_hand_target
var dock := EditorScript.new().get_editor_interface().get_file_system_dock()
var CruSHand: Texture

var edited_scene: bool = true


#section lifecycle


func _init() -> void:
	# Get hand if in project
	if ResourceLoader.exists(CruSHandPath):
		CruSHand = load(CruSHandPath)
		if not CruSHand as Texture:
			CruSHand = null


func _ready() -> void:
	var edited_scene_root := get_tree().edited_scene_root
	edited_scene = (
			edited_scene_root == self
			or is_instance_valid(edited_scene_root) and edited_scene_root.is_a_parent_of(self)
	)

	build_focus_hand()
	set_notify_local_transform(true)
	set_notify_transform(true)

	pass


func _notification(what: int) -> void:
	match what:
		#NOTIFICATION_VISIBILITY_CHANGED:
		#	print("vis change")
		#	print("  self: %s" % [ is_visible() ])
		#	print("  in tree: %s" % [ is_visible_in_tree() ])
		#	update_focus_hand_visibility()

		NOTIFICATION_RESIZED,\
		NOTIFICATION_SCROLL_END,\
		NOTIFICATION_SCROLL_BEGIN,\
		NOTIFICATION_MOVED_IN_PARENT,\
		NOTIFICATION_TRANSFORM_CHANGED,\
		NOTIFICATION_VISIBILITY_CHANGED,\
		NOTIFICATION_LOCAL_TRANSFORM_CHANGED:
			update_focus_hand_visibility()


#section methods


func update_focus_hand_visibility() -> void:
	if not is_instance_valid(focus_hand): return

	if edited_scene:
		# Any editor view behaviour would go here
		focus_hand.hide()
	elif not is_visible_in_tree():
		focus_hand.hide()
	else:
		if is_instance_valid(focus_hand_target):
			update_focus_hand_target(focus_hand_target)
		else:
			focus_hand.hide()


func get_list_items() -> Array:
	var list := [ ]

	for item in get_children():
		if (item as Node).is_in_group(ListItemGroup):
			list.push_back(item)

	return list


func get_item_for_mod(mod_name: String) -> CruSMakeModListItem:
	for item in get_children():
		if (item as Node).is_in_group(ListItemGroup) and item.data.name == mod_name:
			if not item is CruSMakeModListItem:
				push_error('Resolved non CruSMakeModListItem control with expected group name "%s"' % [ ListItemGroup ])
				continue
			return item

	return null


func create_item_instance(data: CruSMakeModExport = null) -> CruSMakeModListItem:
	if not is_instance_valid(data):
		push_warning("Invalid CruSMakeModExport instance.")
		return null

	var node: CruSMakeModListItem = ListItem.instance()

	node.add_to_group(ListItemGroup)

	node.connect("highlighted", self, "_on_item_highlight")
	node.connect("double_clicked", self, "_try_open_mod_item_in_filesystem_dock")
	node.connect("export_requested", self, "_on_export_requested")

	if is_instance_valid(data):
		node.set_data(data)

	return node


func push_item(data: CruSMakeModExport) -> void:
	# Check if already added
	for item in get_list_items():
		if data.name == item.data.name:
			return

	var item := create_item_instance(data)
	if item:
		add_child(item)


func push_dir(dir: String) -> void:
	var data := CruSMakeModExport.new()
	data.set_root_directory(dir)
	push_item(data)


func _try_open_mod_item_in_filesystem_dock(mod_name: String) -> void:
	var list_item := get_item_for_mod(mod_name)
	if list_item:
		dock.navigate_to_path(list_item.data.root_directory)


func build_focus_hand() -> void:
	if is_instance_valid(focus_hand):
		if focus_hand.is_inside_tree():
			focus_hand.get_parent().remove_child(focus_hand)
		focus_hand.queue_free()
		focus_hand = null

	var new_hand := TextureRect.new()
	new_hand.rect_clip_content = false
	new_hand.rect_size = Vector2(1,1)
	new_hand.rect_min_size = Vector2.ZERO
	new_hand.texture = CruSHand
	new_hand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	new_hand.visible = false

	var insertion_point := get_parent_control().get_parent_control()
	yield(get_tree(), "idle_frame")
	insertion_point.add_child(new_hand)
	var rid := new_hand.get_canvas_item()
	VisualServer.canvas_item_set_z_index(rid, 1)

	focus_hand = new_hand


func set_focus_hand_target(value: Control):
	if not is_instance_valid(value): return

	focus_hand_target = value

	if not is_inside_tree(): return

	var container_rect := get_parent_control().get_global_rect()
	var target_rect := value.get_global_rect()

	if container_rect.intersects(target_rect):
		update_focus_hand_target(value)


func update_focus_hand_target(item: Control = focus_hand_target) -> void:
	if not is_inside_tree(): return
	if not is_instance_valid(focus_hand): return
	if not focus_hand.is_inside_tree(): return

	if not is_instance_valid(item) or not item.visible:
		#print('[update_focus_hand_target] Hiding hand')
		focus_hand.visible = false
		return

	var hand_rect := focus_hand.get_global_rect()
	var item_rect := item.get_global_rect()
	focus_hand.set_global_position(
			item_rect.position
				+ item_rect.size * Vector2(1.0, 0.5)
				- Vector2(hand_rect.size.x * 1.0, 0)
	)

	if get_parent_control().get_global_rect().has_point(focus_hand.get_global_position()):
		focus_hand.visible = true


# assumes called checked if used instances valid
func hand_target_check() -> void:
	if not is_inside_tree(): return
	var hand := focus_hand
	var target := focus_hand_target

	var container_rect := get_parent_control().get_global_rect()
	var target_rect := target.get_global_rect()
	#print("Scroll: %s" % [ container_rect ])
	#print("Target: %s" % [ target_rect ])

	var hand_pos := hand.get_global_position()
	var hand_in_container := container_rect.intersects(target_rect)
	if hand_in_container:# \
		#update_focus_hand_target()
		return
	else:
		#or not container_rect.intersects(target.get_global_rect()):
		focus_hand_target = null
		focus_hand.hide()
		#update_focus_hand_target()
		#focus_hand.call_deferred('hide')


func _on_item_highlight(item_name: String) -> void:
	var target := get_item_for_mod(item_name)
	if is_instance_valid(target):
		set_focus_hand_target(target)


func _on_export_requested(mod_data: CruSMakeMod) -> void:
	print("[CruSMakeModList] Build request %s" % [ mod_data.name ])
	emit_signal("export_requested", mod_data)


#section statics


#section classes
