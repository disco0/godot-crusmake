tool
class_name CruSMakeModExporter
extends Node


#section signals


# @param mod_data: CruSMakeMod
# @param reason:   String
signal failed(mod_data, reason)
# @param mod_data:    CruSMakeMod
# @param output_file: String
signal success(mod_data, output_file)
# @param desc: String
# @param type: DETAIL_TYPE
signal progress_detail(desc, type)
# @param desc: String
# @param type: DETAIL_TYPE
# @param color: Color
# @param newline: bool
signal progress_dyn(desc, type, color, newline)


#section members


const BlacklistedDirNames := PoolStringArray([".git"])
enum DETAIL_TYPE {
	PROGRESS,
	WARN,
}

var active: bool = false


#section lifecycle


func _ready() -> void:
	pass


#section methods


func start_export(mod_data: CruSMakeModExport, output_dir: String) -> void:
	section_idx = 0
	if not is_instance_valid(mod_data):
		log_failed(mod_data, "Passed invalid CruSMakeModExport instance.")

	# 4 yields
	var tree := get_tree()

	var dir: Directory = Directory.new()
	if not dir.dir_exists(output_dir):
		var output_mkdirp_err := dir.make_dir_recursive(output_dir)
		if output_mkdirp_err != OK:
			emit_signal("failed", mod_data, "Failed to create exports base directory: %s (error: %s)"
												% [ output_dir, output_mkdirp_err ])
			active = false
		return

	yield(tree, "idle_frame")

	log_section("Config")

	var mod_project_dir := mod_data.root_directory
	var MOD_CONTENT_ROOT := 'res://MOD_CONTENT'
	var archive_content_dir_path := ProjectSettings.globalize_path(output_dir.plus_file(mod_data.name))
	log_step('archive_content_dir_path:   %s' % [ archive_content_dir_path ])

	# Effectively root of the inner archive
	#    <content-zip>/mod.zip
	# -> <content-zip>/mod_json/
	var MODZIP_TEMP_DIR := 'mod_json'
	var modzip_content_dir_path := archive_content_dir_path.plus_file(MODZIP_TEMP_DIR)
	log_step('modzip_content_dir_path:    %s' % [ modzip_content_dir_path ])

	var modzip_imports_path := modzip_content_dir_path.plus_file('.import')

	var archive_mod_inner_mod_dir := modzip_content_dir_path.plus_file("MOD_CONTENT")\
															.plus_file(mod_project_dir.trim_prefix(MOD_CONTENT_ROOT))
	log_step('archive_mod_inner_mod_dir:  %s' % [ archive_mod_inner_mod_dir ])

	#var archive_mod_inner_root := modzip_content_dir_path.plus_file("MOD_CONTENT")
	#log_step('archive_mod_inner_root:     %s' % [ archive_mod_inner_root ])

	var mod_zip_output_path := archive_content_dir_path.plus_file('mod.zip')
	var output_archive_path := archive_content_dir_path + '.zip'

	var mod_json_path_initial := archive_mod_inner_mod_dir.plus_file('mod.json')
	var mod_json_path_final   := archive_content_dir_path.plus_file('mod.json')

	log_step("Building mod to path %s" % [ output_archive_path ])
	yield(tree, "idle_frame")

	log_section("Clean")

	# Remove any existing files/folders in operating paths
	for path in [ archive_content_dir_path, output_archive_path ]:
		if dir.dir_exists(path):
			log_step("Removing existing directory at path %s" % [ path ])
			yield(tree, "idle_frame")
			var rm_err := OS.move_to_trash(path) # dir.remove(archive_content_dir_path)
			if rm_err != OK:
				log_failed(mod_data, "Failed to remove existing directory preparing for export.")
				yield(tree, "idle_frame")
				return

			continue

		if dir.file_exists(path):
			log_step("Removing existing file at path %s" % [ path ])
			yield(tree, "idle_frame")
			var rm_err := OS.move_to_trash(path) # dir.remove(archive_content_dir_path)
			if rm_err != OK:
				log_failed(mod_data, "Failed to remove existing directory to create archive content folder.")
				yield(tree, "idle_frame")
				return

			continue

	log_section("Copy")

	# Create output archive content folder in configured output folder
	# Create deep copy of mod folder
	var excluded_dir_names := BlacklistedDirNames
	log_step("Copying mod folder into %s" % [ archive_mod_inner_mod_dir ])
	yield(tree, "idle_frame")
	var cprec_err := RecursiveCopy(mod_project_dir, archive_mod_inner_mod_dir, excluded_dir_names)

	# TODO: Config
	var mod_dir_exclusions := BlacklistedDirNames
	for exclusion in mod_dir_exclusions:
		var excluded_path := archive_content_dir_path.plus_file(exclusion)
		if dir.dir_exists(excluded_path) or dir.file_exists(excluded_path):
			log_step("Removing excluded mod folder leaf %s" % [ excluded_path ])
			yield(tree, "idle_frame")
			OS.move_to_trash(excluded_path)

	# Move mod.json into output archive content folder
	if dir.file_exists(mod_json_path_initial):
		log_step("Moving mod.json into base of content folder (%s)" % [ mod_json_path_final ])
		var mj_mv_err := dir.rename(mod_json_path_initial, mod_json_path_final)
		if mj_mv_err != OK:
			log_failed(mod_data, "Error moving mod.json from initial location (error: %s)"
									% [ mj_mv_err ])
			yield(tree, "idle_frame")
			return

	# Clean up mod json folder before zip
	log_step('Removing excluded content from mod.zip')
	yield(tree, "idle_frame")
	yield(clean_mod_zip_dir(modzip_content_dir_path, mod_data.excluded_file_exts), "completed")

	# Copy all included project files
	log_step('Copying included project paths')
	for include_path in mod_data.included_project_paths:
		var scheme := (include_path as String).get_slice('//', 0)
		if scheme != 'res:':
			log_warn(' - <WARN> Non-res:// paths not supported (%s)' % [ include_path ])

		var include_leaf := (include_path as String).get_slice('//', 1)
		var include_target_path = modzip_content_dir_path.plus_file(include_leaf)

		var inc_cp_err: int

		if dir.dir_exists(include_path):
			log_step(' - <DIR>  %s' % [ include_path ])
			yield(tree, "idle_frame")

			inc_cp_err = RecursiveCopy(include_path, include_target_path, excluded_dir_names)

		elif dir.file_exists(include_path):
			log_step(' - <FILE> %s' % [ include_path ])
			yield(tree, "idle_frame")

		# Same for either case
		log_step('      ->  %s' % [ include_target_path ])
		yield(tree, "idle_frame")

		# Catch either cases' error
		if inc_cp_err != OK:
			# NOTE: Maybe fail?
			log_warn('    -> Error: %s' % [ inc_cp_err ])

	log_section("Imports")

	# Collect all required import files
	# NOTE: Expects all import files to actually be in .import
	log_step('Collecting import files')
	var import_files := collect_import_files(modzip_content_dir_path)

	# Make .import folder now that its actually needed
	if not import_files.empty():
		var import_mkdir_err := dir.make_dir_recursive(modzip_imports_path)
		if import_mkdir_err != OK:
			log_failed(mod_data, 'Failed to create mod.zip .import dir (error code: %s)'
									% [ import_mkdir_err ])
			return

	for import_file_path in import_files:
		log_step('  -> %s' % [ import_file_path ])
		yield(tree, "idle_frame")

		var deps := resolve_import_files(import_file_path)
		if deps.empty(): continue

		for dep_path in deps:
			var dep_leaf := (dep_path as String).get_slice('//', 1)
			var dep_out_path := modzip_content_dir_path.plus_file(dep_leaf)
			log_step('     > %s' % [ dep_path ])
			log_step('       %s' % [ dep_out_path ])

			var dep_cp_err := dir.copy(dep_path, dep_out_path)
			if dep_cp_err != OK:
				log_warn('    FAILED: Error %s' % [ dep_cp_err ])

		yield(tree, "idle_frame")

	# Create archive of mod folder in output archive content folder

	log_section("mod.zip")

	log_step('Writing inner mod archive to %s' % [ mod_zip_output_path ])
	yield(tree, "idle_frame")
	var zwrite_err := write_zip(modzip_content_dir_path, mod_zip_output_path)
	if zwrite_err != OK:
		log_failed(mod_data, "Error writing inner mod.json file (error: %s)" % [ zwrite_err ])
		yield(tree, "idle_frame")
		return

	# Remove inner zip content dir
	log_step('Removing mod.zip content dir %s' % [ modzip_content_dir_path ])
	yield(tree, "idle_frame")
	var rm_err := OS.move_to_trash(modzip_content_dir_path)
	if rm_err != OK:
		log_failed(mod_data, "Failed to remove mod.zip content directory %s (error: %s)"
									% [ modzip_content_dir_path, rm_err ])
		yield(tree, "idle_frame")
		return

	log_section("Build archive")

	# Create final archive from output archive content folder
	log_step('Writing final archive to %s' % [ output_archive_path ])
	var ozwrite_err = write_zip(archive_content_dir_path, output_archive_path)
	if ozwrite_err != OK:
		log_failed(mod_data, "Error writing final release archive to %s (error: %s)"
									% [ output_archive_path, ozwrite_err ])
		yield(tree, "idle_frame")
		return

	log_section("Post-Build")

	# Remove output archive content folder
	log_step('Removing work folder at %s' % [ archive_content_dir_path ])
	rm_err = OS.move_to_trash(archive_content_dir_path)
	# NOTE: Letting this pass without failing for now as the zip is already created
	if rm_err != OK:
		log_warn("Failed to remove work folder content directory %s (error: %s)"
						% [ archive_content_dir_path, rm_err ])
		yield(tree, "idle_frame")
		return

	emit_signal("success", mod_data, output_archive_path)


func collect_import_files(search_root: String) -> PoolStringArray:
	return PoolStringArray(FileSearch.search_pattern('*.import', search_root).keys())


# Given a known .import file, returns all dependency files
# Ex:
#   Input: "res://path/to/image.png.import"
#   Output: PoolStringArray([
#       "res://.import/image.png-b8650ecb7e2f637f38d98725dad50be5.s3tc.stex",
#       "res://.import/sky2-wrap.png-b8650ecb7e2f637f38d98725dad50be5.etc2.stex"
#   ])
func resolve_import_files(import_file: String) -> PoolStringArray:
	# NOTE: Only works for texture import files?
	var conf := ConfigFile.new()
	var copen_err := conf.load(import_file)
	if copen_err != OK:
		push_warning("Failed to load as config file: %s" % [ import_file ])

	return PoolStringArray(conf.get_value('deps', 'dest_files', PoolStringArray()))


func clean_mod_zip_dir(root_dir: String, excluded_exts = []) -> void:
	# TODO: add FileSearch.directory_pattern
	var base_patterns := PoolStringArray([
		# files in .git
		'*/.git/*'
	])
	var patterns := base_patterns

	for pattern in patterns:
		log_step(" - %s" % [ root_dir.plus_file(pattern) ])
		yield(get_tree(), "idle_frame")

		var results := FileSearch.search_pattern_full_path(pattern, root_dir, true, true).keys()
		log_step("  Found %d matches" % [ results.size() ])

		results.invert()
		for result in results:
			log_step("   - Removing: %s" % [ result ])
			OS.move_to_trash(result)
			yield(get_tree(), "idle_frame")

	if typeof(excluded_exts) == TYPE_STRING_ARRAY:
		excluded_exts = PoolStringArray(excluded_exts)

	for ext in excluded_exts:
		var results := FileSearch.search_pattern("*.%s" % [ ext ], root_dir, true, true).keys()
		if results.empty(): continue

		log_step('  - Found %d files with ext "%s"' % [ results.size(), ext ])
		yield(get_tree(), "idle_frame")

		for result in results:
			log_step("    - Removing: %s" % [ result ])
			OS.move_to_trash(result)
			yield(get_tree(), "idle_frame")

	yield(get_tree(), "idle_frame")


func write_zip(source_dir: String, output_path: String) -> int:
	var writer = GDNativeZipFileWriter.new()
	writer.source_dir = ProjectSettings.globalize_path(source_dir)
	writer.output_path = ProjectSettings.globalize_path(output_path)

	return writer.write_zip()


#section logging


func log_step(desc: String) -> void:
	print('[ModExporter:log_step] %s' % [ desc ])
	emit_signal("progress_detail", desc, DETAIL_TYPE.PROGRESS)


func log_dyn(desc: String, color := Color.white, newline := true) -> void:
	print('[ModExporter:log_step] %s' % [ desc ])
	emit_signal("progress_dyn", desc, DETAIL_TYPE.PROGRESS, color, newline)


var section_idx := 0
func log_section(desc: String) -> void:
	emit_signal("progress_dyn",
				("# %s" if section_idx == 0 else "\n# %s") % [ desc ],
				DETAIL_TYPE.PROGRESS,
				Color.chartreuse,
				true)
	section_idx += 1


func log_warn(desc: String) -> void:
	push_warning('[ModExporter:log_warn] %s' % [ desc ])
	emit_signal("progress_detail", desc, DETAIL_TYPE.WARN)


func log_failed(mod_data: CruSMakeMod, desc: String) -> void:
	push_error('' % [ desc ])
	emit_signal("failed", mod_data, desc)


#section statics


# Would b good to avoid multiple dir instances if possible
static func RecursiveCopy(dirpath: String, new_dirpath: String, excluded_dir_names := PoolStringArray(), depth: int = 0) -> int:
	var dir: Directory = Directory.new()
	var copy_dir: Directory = Directory.new()
	var dopen_err := dir.open(dirpath)
	if dopen_err != OK:
		push_error("Failed to open %s for copying! (error: %s)" % [ dirpath, dopen_err ])
		return dopen_err

	if not copy_dir.dir_exists(new_dirpath):
		var mkdirp_err := copy_dir.make_dir_recursive(new_dirpath)
		if mkdirp_err != OK:
			push_error("Failed to make output directory %s (error: %s)" % [ new_dirpath, mkdirp_err ])
			return mkdirp_err

	var cp_dopen_err := copy_dir.open(new_dirpath)
	if cp_dopen_err != OK:
		push_error("Failed to open %s for copying (error: %s)" % [ new_dirpath,cp_dopen_err ])
		return cp_dopen_err

	dir.list_dir_begin(true, true)

	var fname = dir.get_next()
	while fname != "":
		var p     := dirpath.plus_file(fname)
		var new_p := new_dirpath.plus_file(fname)
		if dir.current_is_dir():
			if not excluded_dir_names.has(fname):
				var copy_dir_err := RecursiveCopy(p, new_p, excluded_dir_names, depth + 1)
				if copy_dir_err != OK:
					return copy_dir_err
		else:
			var cp_err := dir.copy(p, new_p)
			if cp_err != OK:
				return cp_err

		fname = dir.get_next()

	dir.list_dir_end()

	return OK


#section classes
