tool
class_name CruSMakeModListItem
extends PanelContainer


#section signals


# @param name: string
signal highlighted(name)
# @param name: string
signal double_clicked(name)
# @param name: CruSMakeMod
signal export_requested(mod_data)


#section members


const ModDataConfig := preload('./ModConfigWindowDialog.tscn')

onready var name_label: Label = $"%Name"
onready var version_label: Label = $"%Version"
onready var context_menu := $ContextMenu as CruSMakeContextMenu

var data: CruSMakeModExport setget set_data
var have_data := false
var base_stylebox: StyleBox
var focus_ui_mode_active := false

var config_dialog: CruSMakeModConfigDialog


#section lifecycle


func _init() -> void:
	if is_inside_tree():
		_reinitialize_script_vars()


func _ready() -> void:

	stylize()

	if is_instance_valid(data):
		update_ui()


func _gui_input(event: InputEvent) -> void:
	if event as InputEventMouseButton:
		var mevent: InputEventMouseButton = event

		if mevent.button_mask == BUTTON_MASK_RIGHT and mevent.pressed and not mevent.is_echo():
			present_context_menu()
			get_tree().set_input_as_handled()
			return

		elif mevent.doubleclick:
			emit_signal("double_clicked", data.name)
			get_tree().set_input_as_handled()
			return


# func _notification(what: int) -> void:
# 	match what:
# 		NOTIFICATION_THEME_CHANGED:
# 			stylize()


#section methods


func _reinitialize_script_vars() -> void:
	name_label = $"%Name"
	version_label = $"%Version"
	if not is_instance_valid(data):
		have_data = false


func present_context_menu():
	context_menu.present()


func update_ui() -> void:
	name_label.text = data.name
	version_label.text = data.version_string


func set_data(value: CruSMakeModExport) -> void:
	data = value

	if is_instance_valid(value): have_data = true

	if is_inside_tree(): update_ui()


func stylize() -> void:
	# Don't update if not in tree or in scene editor
	if not is_inside_tree(): return
	#var edited_scene := get_tree().edited_scene_root
	#if self == edited_scene or edited_scene.is_a_parent_of(self): return

	var box = get_stylebox("Content", "EditorStyles").duplicate()

	#EditorScript.new().get_editor_interface().get_edited_scene_root()

	var v_margin_min := 0.0 # 4.0
	var h_margin_min := 0.0 # 10.0

	box.content_margin_top    = max(box.content_margin_top, v_margin_min)
	box.content_margin_bottom = max(box.content_margin_bottom, v_margin_min)
	box.content_margin_left   = max(box.content_margin_left, h_margin_min)
	box.content_margin_right  = max(box.content_margin_right, h_margin_min)

	if box is StyleBoxFlat or box is StyleBoxTexture:
		box.expand_margin_top     = 0
		box.expand_margin_bottom  = 0
		box.expand_margin_left    = 0
		box.expand_margin_right   = 0

	if box is StyleBoxFlat:
		var fbox := box as StyleBoxFlat
		var base_color := get_color("dark_color_1", "Editor")
		base_color.a = .8
		var contrast_color := get_color("prop_category", "Editor").blend(base_color)
		fbox.bg_color = contrast_color
		var border_radius := 3
		fbox.set_corner_radius_all(border_radius)
		fbox.set_border_width_all(0)

	base_stylebox = box

	add_stylebox_override("panel", box)

	for label in [ name_label, version_label ]:
		(label as Label).add_font_override("font", get_font("expression", "EditorFonts"))

	name_label.add_color_override("font_color", get_color("highlighted_font_color", "Editor"))
	version_label.add_color_override("font_color", get_color("font_color", "Editor"))


func update_focus_ui_mode(state: bool) -> void:
	if state and focus_ui_mode_active: return
	if not state and not focus_ui_mode_active: return

	if state:
		if have_data:
			emit_signal("highlighted", data.name)
		#var box: StyleBoxFlat = base_stylebox.duplicate()
		#box.border_color = Color.red
		#add_stylebox_override("panel", box)
	else:
		pass
		#add_stylebox_override("panel", base_stylebox)

	focus_ui_mode_active = state


func _initialize_config_dialog() -> void:
	config_dialog = ModDataConfig.instance()
	config_dialog.mod_data = data
	config_dialog.popup_exclusive = true
	config_dialog.connect("save_pressed", self, "_on_config_save_pressed")
	add_child(config_dialog)


func save_mod_config() -> void:
	if not is_instance_valid(data):
		push_warning("Can't save export config: no config data bound.")
		return
	var out_res_path := data.get_default_save_path()
	var save_err := ResourceSaver.save(out_res_path, data)
	if save_err != OK:
		push_error('Failed to save export config for %s (error code: %s)'
						% [ data.root_directory, save_err ])
	else:
		print('Saved config for %s' % [ data.root_directory ])


#section handlers


func _on_config_save_pressed() -> void:
	save_mod_config()


func _on_focus_entered() -> void:
	update_focus_ui_mode(true)


func _on_mouse_entered() -> void:
	update_focus_ui_mode(true)


func _on_mouse_exited() -> void:
	update_focus_ui_mode(false)


func _on_ContextMenu_index_pressed(index: int) -> void:
	context_menu.hide()

	match index:
		CruSMakeContextMenu.MENU_ITEMS.BUILD:
			print("Recevived build context menu click")
			emit_signal("export_requested", data)

		CruSMakeContextMenu.MENU_ITEMS.CONFIG:
			if not is_instance_valid(config_dialog):
				_initialize_config_dialog()
			config_dialog.popup_centered(Vector2(1280, 720))
			#config_dialog.popup_centered_ratio(0.75)

		CruSMakeContextMenu.MENU_ITEMS.SAVE:
			save_mod_config()

		_:
			push_warning("Unknown context menu index: %d" % [ index ])


#section statics


#section classes
