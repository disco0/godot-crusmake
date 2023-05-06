tool
class_name CruSMakeExportPlugin
extends EditorExportPlugin


#section members


var exclude_list: CrusMakeExcludeList
var _excluded_dir_list := PoolStringArray()

var export_dir: String
var _exclusion_list_filename := "excluded-dirs.txt"
var _excluded_files := PoolStringArray()


#section lifecycle


func _init(exclude_list: CrusMakeExcludeList = null) -> void:
	if is_instance_valid(exclude_list):
		self.exclude_list = exclude_list


func _export_begin(features: PoolStringArray, is_debug: bool, export_file_path: String, flags: int) -> void:
	export_dir = export_file_path.get_base_dir()
	_excluded_files = PoolStringArray()

	if not is_instance_valid(exclude_list):
		push_error("CruSMake exclude_list not configured.")
		return

	_excluded_dir_list = PoolStringArray(exclude_list.excluded_dirs)
	if _excluded_dir_list.empty():
		push_warning("CruSMake exclude_list.excluded_dirs has no configured directories")


func _export_end() -> void:
	if not is_instance_valid(exclude_list):
		push_error("CruSMake exclude_list not configured.")
		return

	if not _excluded_dir_list.empty():
		print('[CruSMake:_export_end] Directory exclusion list:')
		for excluded in _excluded_dir_list:
			print('[CruSMake:_export_end]  - "%s"' % [ excluded ])
	else:
		push_warning("CruSMake exclude_list.excluded_dirs has no configured directories")

	if not _excluded_files.empty():
		print('[CruSMake:_export_end] Excluded files:')
		for excluded in _excluded_files:
			print('[CruSMake:_export_end]  - "%s"' % [ excluded ])

	# Write directory exclusion list to file for later build step reference (workaround for issue
	# with generated export files not being passed to `_export_file`)
	var dir: Directory = Directory.new()
	var file: File = File.new()
	var exclusion_list_file_path := export_dir.plus_file(_exclusion_list_filename)
	if _excluded_dir_list.empty():
		if dir.file_exists(exclusion_list_file_path):
			var frm_err := dir.remove(exclusion_list_file_path)
			if frm_err != OK:
				push_error('Error %d removing old exclusion list at <%s>' % [ frm_err, exclusion_list_file_path ])
	else:
		var fopen_err := file.open(exclusion_list_file_path, File.WRITE)
		if fopen_err != OK:
			push_error('Error %d opening exclusion list at <%s>' % [ fopen_err, exclusion_list_file_path ])

		file.store_string(_excluded_dir_list.join('\n'))

	if file.is_open(): file.close()


func _export_file(path: String, type: String, features: PoolStringArray) -> void:
	print("[CruSMake:_export_file] %s" % [ path ])
	for excluded in _excluded_dir_list:
		if path.begins_with(excluded):
			print('[CruSMake:_export_file] Excluding %s' % [ path ])
			_excluded_files.push_back(path)

			skip()

			return
