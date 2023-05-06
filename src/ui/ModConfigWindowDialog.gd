tool
class_name CruSMakeModConfigDialog
extends WindowDialog


#section signals


# @param mod_data CruSMakeModExport
signal save_pressed(mod_data)


#section members


onready var file_dialog: FileDialog = $"%IncludeFileDialog"
onready var include_list: ItemList = $"%IncludeList"
onready var add_paths_button: Button = $"%AddPathsButton"
onready var remove_selected_paths_button: Button = $"%RemoveSelectedButton"
onready var excluded_exts_edit: LineEdit = $"%ExcludedExtsEdit"

var mod_data: CruSMakeModExport setget set_mod_data

var selected_include_items := [ ]


#section lifecycle


func _ready() -> void:
	if is_instance_valid(mod_data):
		update_ui_data()

	stylize()


#section methods


func set_mod_data(data: CruSMakeModExport) -> void:
	if not is_instance_valid(data):
		push_warning('Invalid mod export data.')
		return

	mod_data = data
	if is_inside_tree():
		update_ui_data()


# full refresh from existing values
func update_ui_data() -> void:
	assert(is_instance_valid(mod_data), 'Called update with invalid mod_data')

	window_title = '%s' % [ mod_data.name ]
	update_include_list()
	excluded_exts_edit.text = PoolStringArray(mod_data.excluded_file_exts).join(',')


func stylize() -> void:
	var mono_font: Font = get_font("expression", "EditorFonts").duplicate()
	excluded_exts_edit.add_font_override("font", mono_font)


func update_include_list() -> void:
	if not is_instance_valid(include_list): return
	assert(is_instance_valid(mod_data), 'Called update with invalid mod_data')

	var dir: Directory = Directory.new()

	var file_icon := get_icon("File", "EditorIcons")
	var dir_icon  := get_icon("Folder", "EditorIcons")

	var mono_font: Font = get_font("expression", "EditorFonts").duplicate()
	if mono_font is DynamicFont:
		(mono_font as DynamicFont).size = file_icon.get_height()

	include_list.add_font_override("font", mono_font)
	include_list.icon_mode = ItemList.ICON_MODE_LEFT
	include_list.add_constant_override("icon_margin", 4)

	include_list.clear()
	# For now just rebuild list on every change
	for include in mod_data.included_project_paths:
		# NOTE: Path existence should have been checked at time of addition, I think
		include_list.add_item(include,
							  file_icon if dir.file_exists(include) else dir_icon,
							  true)


# Takes string or PoolStringArray
func resolve_file_dialog_results(paths):
	var new_paths: PoolStringArray = (
			paths
				if typeof(paths) == TYPE_STRING_ARRAY else
			PoolStringArray([paths])
	)
	# Should never happen? idk
	if new_paths.empty(): return
	var dir: Directory = Directory.new()
	for path in new_paths:
		if dir.file_exists(path) or dir.dir_exists(path):
			mod_data.include_project_path(path)

	update_include_list()


#section handlers


func _on_AddPath_pressed() -> void:
	print('[on:AddPath_pressed]')
	if not file_dialog.visible:
		file_dialog.popup_centered_ratio(0.6)


func _on_about_to_show() -> void:
	if is_instance_valid(mod_data):
		update_ui_data()


func _on_IncludeFileDialog_path_selected(path: String) -> void:
	resolve_file_dialog_results(PoolStringArray([path]))


func _on_IncludeFileDialog_paths_selected(paths: PoolStringArray) -> void:
	resolve_file_dialog_results(paths)


func _on_IncludeList_nothing_selected() -> void:
	remove_selected_paths_button.disabled = not include_list.is_anything_selected()


func _on_IncludeList_multi_selected(index: int, selected: bool) -> void:
	var existing_idx := selected_include_items.find(index)
	match selected:
		true:
			if existing_idx == -1:
				selected_include_items.push_back(index)

		false:
			if existing_idx != -1:
				selected_include_items.remove(existing_idx)

	remove_selected_paths_button.disabled = selected_include_items.empty()


func _on_IncludeList_item_selected(index: int) -> void:
	selected_include_items = [ index ]
	remove_selected_paths_button.disabled = false


func _on_SaveButton_pressed() -> void:
	emit_signal('save_pressed')


func _on_CloseButton_pressed() -> void:
	hide()


func _on_RemoveSelectedButton_pressed() -> void:
	var includes_selected_idxs := include_list.get_selected_items()
	for selected in includes_selected_idxs:
		var selected_path := include_list.get_item_text(selected)
		var paths_idx := mod_data.included_project_paths.find(selected_path)
		if paths_idx != -1:
			mod_data.included_project_paths.remove(paths_idx)

		include_list.remove_item(selected)


func _on_ExcludedExtsEdit_text_entered(new_text: String) -> void:
	var exts := excluded_exts_edit.text.split(',')
	print('Updated ext list: %s' % [ exts.join(" | ")])
	mod_data.excluded_file_exts = Array(exts)
