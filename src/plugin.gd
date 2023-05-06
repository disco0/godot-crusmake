tool
class_name CrusMakePlugin
extends EditorPlugin


#section members


var plugin := self
const plugin_name    := 'crusmake'
const plugin_path    := "res://addons/" + plugin_name
const plugin_ui_name := 'CruSMake'

var editor_selection := get_editor_interface().get_selection()
var initialized := false
var export_plugin: EditorExportPlugin
var mod_panel: CruSMakeModExportPanel
var mod_panel_pos := EditorPlugin.DOCK_SLOT_RIGHT_UL

var build_exclusion_path := "res://addons/crusmake/excluded.tres"


#section lifecycle


func _init() -> void:
	name = plugin_ui_name
	if not OS.has_feature("editor"):
		queue_free()
		return


func _ready() -> void:
	var file: File = File.new()
	if file.file_exists(build_exclusion_path) and ResourceLoader.exists(build_exclusion_path):
		var excluded := load(build_exclusion_path)
		print('[CruSMake] Registering export plugin with exclude config: %s' % [ excluded ])
		export_plugin = CruSMakeExportPlugin.new(excluded)
		add_export_plugin(export_plugin)

	mod_panel = preload("ui/ModExportDockPanel.tscn").instance()
	add_control_to_dock(mod_panel_pos, mod_panel)


func _exit_tree() -> void:
	teardown()


func enable_plugin() -> void: pass


func disable_plugin() -> void:
	teardown()


func has_main_screen() -> bool: return false


func get_plugin_name() -> String:
	return plugin_ui_name


#section methods


func teardown() -> void:
	if is_instance_valid(export_plugin):
		remove_export_plugin(export_plugin)

	if is_instance_valid(mod_panel):
		remove_control_from_docks(mod_panel)
		mod_panel.queue_free()

	if is_instance_valid(self): self.queue_free()
