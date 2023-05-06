tool
class_name CruSMakeMod
extends Resource


#section members


const ModMetadataFileName = "mod.json"

export (String, FILE) var root_directory: String = "" setget set_root_directory

var name: String
var author: String
var description: String
var version_string: String
# For missing mod.json
var invalid := true


#section lifecycle


func _init(root: String = "") -> void:
	# Don't initialize if already set
	if root_directory.empty() and not root.empty():
		var dir: Directory = Directory.new()
		if dir.dir_exists(root):
			set_root_directory(root)


#section methods


func set_root_directory(path: String) -> void:
	root_directory = path
	# Assume directory name is mod name until mod.json read
	name = root_directory.get_file()
	var dir: Directory = Directory.new()
	if dir.dir_exists(path):
		load_metadata()


func load_metadata() -> void:
	var file: File = File.new()
	var meta_file_path := root_directory.plus_file(ModMetadataFileName)
	if not file.file_exists(meta_file_path):
		invalid = true
		push_warning('Metadata file not found for mod %s' % [ name ])
		return

	var fopen_err := file.open(meta_file_path, File.READ)
	if fopen_err != OK:
		invalid = true
		push_error('Failed to open metadata file for mod %s (error: %d)' % [ name, fopen_err ])
		return

	var content := file.get_as_text(true)
	var parse := JSON.parse(content)
	if parse.error:
		invalid = true
		push_error('Failed to parse metadata file for mod %s (error: %d)'
					% [ name, parse.error_string ])
		return

	var result = parse.result
	if typeof(result) != TYPE_DICTIONARY:
		invalid = true
		push_error('Metadata file for mod %s is non-object json.' % [ name ])
		return

	var meta: Dictionary = result

	# Update name
	name = meta.get("name", name)
	author = meta.get("author", "")
	description = meta.get("description", "")
	version_string = meta.get('version', "")

	invalid = false


#section statics


#section classes
