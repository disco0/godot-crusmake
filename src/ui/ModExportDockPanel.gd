tool
class_name CruSMakeModExportPanel
extends Control


#section members


const ExportDirSettingPath = "crusmake/config/export_dir"
const ExportPreseveZipContentDirPath = "crusmake/config/preserve_archive_content_dir"
const ExportPreseveZipContentDirDefault := false

onready var bg_panel: Panel = $"%MainBG"
onready var mod_list_scroll: ScrollContainerFixed = $"%ModListScroll"
onready var mod_list: CruSMakeModList = $"%ModList"
onready var exporter := $"%ModExporter"
onready var export_dialog := $"%ExportInfoDialog" as WindowDialog
onready var export_progress_log := $"%ExportProgressLog"
onready var export_dir_select_dialog: FileDialog = $"%ExportDirSelectDialog"
onready var export_dir_edit: LineEdit = $"%ExportDirValueEdit"
onready var preserve_zip_content_dir_check: CheckBox = $"%PreserveZipContentDirCheck"

var output_dir: String = ReadProjectSetting(
		ExportDirSettingPath,
		(ProjectSettings.globalize_path("res://") + '/../mod-export').simplify_path()
) setget set_output_dir
var preserve_zip_content_dir: bool = get_preserve_zip_content_dir() \
	setget set_preserve_zip_content_dir, get_preserve_zip_content_dir

var roots := PoolStringArray(["res://MOD_CONTENT"])
var base_stylebox: StyleBox
var editor := false
var dir: Directory = Directory.new()


#section lifecycle


func _ready() -> void:
	build_mod_list()

	editor = (
			get_tree().edited_scene_root
			and (
				get_tree().edited_scene_root == self
				or get_tree().edited_scene_root.is_a_parent_of(self)
			)
	)
	if editor:
		#print('Setting debug rect size.')
		rect_size = Vector2(300, ProjectSettings.get_setting("display/window/size/height"))
	else:
		rect_size = get_parent_area_size()

	stylize()
	if editor:
		export_dir_edit.text = output_dir

	preserve_zip_content_dir_check.set_pressed_no_signal(get_preserve_zip_content_dir())


#section methods


func build_mod_list() -> void:
	for root in roots:
		#print("Scanning %s for mods" % [ root ])
		for dir_path in FileSearch.search_pattern('*', root, false):
			load_mod_data(dir_path)


func load_mod_data(mod_dir: String) -> void:
	# Check for existing?
	var saved_config_path := mod_dir.plus_file(CruSMakeModExport.DefaultName)
	if ResourceLoader.exists(saved_config_path, "Resource"):
		var config := load(saved_config_path)
		if config is CruSMakeModExport:
			mod_list.push_item(config)
			return
		push_warning('Found file at expected config path but was not CruSMakeModExport resource: %s'
						% [ saved_config_path ])

	mod_list.push_dir(mod_dir)


func set_preserve_zip_content_dir(value: bool) -> void:
	ProjectSettings.set_setting(ExportPreseveZipContentDirPath, value)
	preserve_zip_content_dir = value


func get_preserve_zip_content_dir() -> bool:
	return ReadProjectSetting(ExportPreseveZipContentDirPath, ExportPreseveZipContentDirDefault)


func set_output_dir(value: String) -> void:
	if not dir.dir_exists(value):
		push_warning('Tried to assign output_dir to directory path that does not exist.')
		return

	ProjectSettings.set_setting(ExportDirSettingPath, output_dir)
	output_dir = value
	if is_instance_valid(export_dir_edit):
		export_dir_edit.text = output_dir


func clear_progress() -> void:
	export_progress_log.clear()
	export_progress_log.bbcode_enabled = true


func stylize() -> void:
	if editor: return

	var mono_font := get_font("expression", "EditorFonts").duplicate()
	var contrast := get_color("contrast_color_2", "Editor")

	if export_dir_edit:
		export_dir_edit.add_font_override("font", mono_font)
		export_dir_edit.add_color_override("font_color", contrast)

	var box: StyleBox = get_stylebox("Background", "EditorStyles").duplicate()
	var margin_min := 0.0
	if box is StyleBoxFlat:
		(box as StyleBoxFlat).bg_color = get_color("prop_section", "Editor")
		box.expand_margin_left   = 0
		box.expand_margin_right  = 0
		box.expand_margin_top    = 0
		box.expand_margin_bottom = 0

	box.content_margin_left   = max(box.content_margin_left,   margin_min)
	box.content_margin_right  = max(box.content_margin_right,  margin_min)
	box.content_margin_top    = max(box.content_margin_top,    margin_min)
	box.content_margin_bottom = max(box.content_margin_bottom, margin_min)

	base_stylebox = box

	#mod_list_scroll.add_stylebox_override("bg", base_stylebox)

	yield(get_tree(), "idle_frame")

	export_progress_log.add_font_override("normal_font", mono_font)
	export_progress_log.add_font_override("mono_font", mono_font)
	export_progress_log.add_font_override("bold_font", mono_font)
	export_progress_log.add_font_override("bold_italics_font", mono_font)
	export_progress_log.add_font_override("italics_font", mono_font)


#section logging


func write_progress_detail(desc: String) -> void:
	export_progress_log.add_text(desc)
	export_progress_log.newline()


func write_progress_dyn(desc: String, color := Color.white, newline := true) -> void:
	export_progress_log.push_color(color)
	export_progress_log.add_text(desc)
	export_progress_log.pop()
	if newline:
		export_progress_log.newline()


func write_progress_warn(desc: String) -> void:
	export_progress_log.push_color(Color.orange)
	export_progress_log.add_text(desc)
	export_progress_log.pop()
	export_progress_log.newline()


#section handlers


func _on_ModList_export_requested(mod_data: CruSMakeMod) -> void:
	if exporter.active: return

	export_dialog.resizable = true
	# FIXME: Window dialog title isn't aligned perfectly
	export_dialog.window_title = "Exporting %s" % [ mod_data.name ]
	export_dialog.popup_centered(Vector2(1200, 800))

	exporter.preserve_zip_content_dir = preserve_zip_content_dir
	exporter.start_export(mod_data, output_dir)


func _on_SelectExportDirButton_pressed() -> void:
	if export_dir_select_dialog.visible: return

	if not output_dir.empty():
		export_dir_select_dialog.current_dir = output_dir

	export_dir_select_dialog.popup_centered_minsize(Vector2(1280, 720))


func _on_ExportDirSelectDialog_dir_selected(dir_path: String) -> void:
	set_output_dir(dir_path)


func _on_OpenExportDirButton_pressed() -> void:
	if dir.dir_exists(output_dir):
		OS.shell_open(output_dir)


func _on_ModExporter_failed(mod_data, reason) -> void:
	export_progress_log.push_color(Color.red)
	export_progress_log.add_text(reason)
	export_progress_log.pop()


func _on_ModExporter_progress_detail(desc, type) -> void:
	match type:
		CruSMakeModExporter.DETAIL_TYPE.PROGRESS:
			write_progress_detail(desc)
		CruSMakeModExporter.DETAIL_TYPE.WARN:
			write_progress_warn(desc)


func _on_ModExporter_progress_dyn(desc, type, color, newline) -> void:
	write_progress_dyn(desc, color, newline)


func _on_ModExporter_success(mod_data, output_file) -> void:
	export_progress_log.push_color(Color.green)
	export_progress_log.add_text("Built mod archive to %s" % [ output_file ])
	export_progress_log.pop()


func _on_ExportProgressLog_hide() -> void:
	export_progress_log.clear()


func _on_resized() -> void:
	return
	if is_instance_valid(mod_list) and is_instance_valid(mod_list.focus_hand_target):
		hand_target_check()


func _on_PreserveZipContentDirCheck_toggled(button_pressed: bool) -> void:
	set_preserve_zip_content_dir(button_pressed)


# assumes called checked if used instances valid
func hand_target_check() -> void:
	#print("Check")
	var hand := mod_list.focus_hand
	var target := mod_list.focus_hand_target

	var container_rect := mod_list_scroll.get_global_rect()
	var target_rect := target.get_global_rect()
	#print("Scroll: %s" % [ container_rect ])
	#print("Target: %s" % [ target_rect ])

	var hand_pos := hand.get_global_position()
	var hand_in_container := container_rect.has_point(hand_pos)
	if hand_in_container:# \
		mod_list.update_focus_hand_target()
	else:
			#or not container_rect.intersects(target.get_global_rect()):
		#print("Hiding hand")
		mod_list.focus_hand_target = null
		mod_list.update_focus_hand_target()
		mod_list.focus_hand.call_deferred('hide')


#section static


static func ReadProjectSetting(config_name: String, default = null):
	if ProjectSettings.has_setting(config_name):
		return ProjectSettings.get_setting(config_name)
	else:
		return default


func _on_PreserveZipContentDirCheckHBox_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mbe: InputEventMouseButton = event

		if mbe.is_echo() or not mbe.pressed: return

		if mbe.button_index == BUTTON_LEFT:
			preserve_zip_content_dir_check.set_pressed_no_signal(
				not preserve_zip_content_dir_check.pressed)

			get_tree().set_input_as_handled()
