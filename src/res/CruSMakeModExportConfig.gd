tool
class_name CruSMakeModExport
extends CruSMakeMod


#section signals


# Just fires when using include_project_path interface for now
signal include_paths_changed()


#section members


const DefaultName = 'export_config.tres'

export (Array, String, FILE) var included_project_paths: Array = [ ]
export (Array, String) var excluded_file_exts: Array = [ "psd" ]


#section lifecycle


func _init(root: String = "").(root) -> void: pass


#section methods


func remove_project_path_include(path: String) -> void:
	path = path.simplify_path()

	var idx := included_project_paths.find(path)
	if idx >= 0:
		included_project_paths.remove(idx)


func clear_included_project_paths() -> void:
	included_project_paths.clear()


func include_project_path(res_path: String) -> void:
	if not IsResPath(res_path):
		var msg := "Not a res:// path: %s" % [ res_path ]
		assert(false, msg)
		push_error(msg)
		return

	res_path = res_path.simplify_path()

	if not included_project_paths.has(res_path):
		included_project_paths.push_back(res_path)
		emit_signal("include_paths_changed")


func get_default_save_path() -> String:
	assert(not root_directory.empty())
	return root_directory.plus_file(DefaultName)


#section statics


static func _CoerceInitArgs(arg) -> String:
	match typeof(arg):
		TYPE_STRING: return arg
		TYPE_OBJECT: return arg.root_directory
		_:           return ""


static func IsResPath(path: String) -> bool:
	return path.is_abs_path() and path.begins_with('res://')


#section classes
