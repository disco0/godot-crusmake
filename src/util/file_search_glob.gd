tool
#class_name FileGlobSearch
extends Reference

# ~Modified version of godot-next file_search.gd for glob search~
# Further reduced version

# author: willnationsdev
# license: MIT
# description: A utility with helpful methods to search through one's project files (or any directory).


class FileEvaluator extends Reference:
	var file_path: String = "" setget set_file_path
	var base_path: String = "" setget set_base_path
	var base_len: int = 0 setget __
	var match_mode: int = MATCH_MODE.NAME
	var path_types: int = TARGET_TYPES.FILE


	func __(noop) -> void: pass


	# Assigns a new file path to the object.
	func _is_match() -> bool:
		return true


	# If _is_match() returns true, returns the key used to store the data.
	func _get_key():
		return file_path


	# If _is_match() returns true, returns the data associated with the file.
	func _get_value() -> Dictionary:
		return { "path": file_path }


	# Assigns a new file path to the object.
	func set_file_path(p_value):
		file_path = p_value


	func set_base_path(p_value: String) -> void:
		base_path = p_value.trim_suffix('/') + '/'
		base_len = base_path.length()


	enum MATCH_MODE {
		NAME,
		FULL,
		LEAF,
	}

	enum TARGET_TYPES {
		FILE = 1 << 0,
		DIR  = 1 << 1,
		ANY  = (1 << 0) + (1 << 1),
	}


class GlobEvaluator extends FileEvaluator:
	var _regex := RegEx.new()
	var _regex_source: String = ""
	var _match: RegExMatch = null

	func _init(p_glob_str: String, p_match_mode := MATCH_MODE.LEAF, p_path_types := TARGET_TYPES.ANY):
		_regex_source = BuildGlobRegex(p_glob_str)
		print(_regex_source)
		if OK != _regex.compile(_regex_source):
			push_error('RegEx source generated for glob failed to compile.\nGlob: %s\nGenerated: %s'
							% [ p_glob_str, _regex_source ])

		match_mode = p_match_mode
		path_types = p_path_types


	func _is_match() -> bool:
		if not _regex.is_valid():
			return false

		_match = _search()
			# _regex.search(file_path if _compare_full_path else file_path.get_file())
		return _match != null


	func _search() -> RegExMatch:
		if match_mode == MATCH_MODE.NAME:
			return _regex.search(file_path.get_file())
		elif match_mode == MATCH_MODE.FULL:
			return _regex.search(file_path)
		else: #elif match_mode == MATCH_MODE.LEAF:
			return _regex.search(file_path.substr(base_len))


	func _get_value() -> Dictionary:
		var data = ._get_value()
		data.match = _match
		return data

	func _to_repl() -> Dictionary:
		return {
			source = _regex_source,
			base = base_path,
		}

	static func BuildGlobRegex(pattern: String) -> String:
		assert(not pattern.empty())

		var src := ""
		var idx := 0
		var pat_len := pattern.length()

		#var last: int = CHAR_TYPE.NONE

		# Start cases
		if pattern[idx] == CHAR.SEP:
			src += '(?:^)'
			idx += 1
			#last = CHAR_TYPE.SEP
		elif pattern.begins_with(CHAR.DOT + CHAR.SEP):
			src += '(?:^[\\/])'
			idx += 2
			#last = CHAR_TYPE.SEP

		while idx < pat_len:
			var curr := pattern[idx]
			var has_next := idx + 1 < pat_len
			var next: String = pattern[idx + 1] if has_next else ""
			#print('%s | %s' % [ curr, next ])
			match curr:
				CHAR.STAR:
					if next == CHAR.STAR:
						# Peek again:
						#  - Not empty, check for separator (expected/correct next char)
						#    - If not separator, fail back to single star
						#  - If empty end its full wildcard
						if idx + 2 < pat_len:
							match pattern[idx + 2]:
								CHAR.SEP:
									src += EXPR.DSTAR_CLOSED
									idx += 1

								# Eat remaining stars, then continue as single star
								CHAR.STAR:
									var steps := 2
									while idx + steps < pat_len and pattern[idx + steps] == CHAR.STAR:
										steps += 1
									idx += steps
									src += EXPR.STAR
									# Break out before default increment
									continue

								# Probably need to refine
								_:
									src += EXPR.STAR
						else:
							src += EXPR.DSTAR
					else:
						src += EXPR.STAR

					idx += 1

				CHAR.SEP:
					src += EXPR.SEP
					idx += 1

				CHAR.QSTN:
					src += EXPR.ANYCHAR
					idx += 1

				CHAR.DOT:
					# TODO: Handle/error out on .{.,}/
					src += EXPR.DOT
					idx += 1

				CHAR.PLUS:
					src += '[+]'
					idx += 1

				CHAR.ESC:
					src += EXPR.ESC
					if next.empty(): # uhhh
						#src += EXPR.ESC
						pass
					else:
						idx += 1
						#src += EXPR.ESC
						if (next).rstrip('\\[]{}()/^$*').empty():
							src += next
						else: # uhhh
							src += EXPR.ESC + next

					idx += 1

				#CHAR.SEP:
				_:
					src += curr
					idx += 1

		# TODO: Need to add optional directory separator on end when not made explicit.
		#       May need to do something more involved if any additional expansion implemented
		if pattern[pat_len - 1] != CHAR.SEP:
			src += EXPR.SEP_OPT

		src += '$'
		return src

	const EXPR := {
		SEP   = '[\\/]',
		SEP_OPT= '(?:[\\/])?',

		STAR  = '[^\\/]+',
		DSTAR = '(?:.*[^\\/]|)',
		# **/file.gd
		#  -> file.gd
		#  -> a/b/c/d/file.gd
		DSTAR_CLOSED = '(?:.*[^\\/][\\/]|)',
		DOT   = '[.]',
		ANYCHAR = '[^\\/]', # '.'?

		ESC   = '\\',
	}

	const CHAR := {
		SEP     = '/',
		ESC     = '\\',
		DOT     = '.',
		L_BRACE = '{',
		R_BRACE = '}',
		STAR    = '*',
		PLUS    = '+',
		QSTN    = '?',
	}

	enum CHAR_TYPE {
		NONE,
		SEP,
		CHAR,
	}


static func search_glob(p_glob: String, p_from_dir: String = "res://", p_recursive: bool = true, p_hidden: bool = true) -> Dictionary:
	var glob := GlobEvaluator.new(p_glob, FileEvaluator.MATCH_MODE.LEAF, FileEvaluator.TARGET_TYPES.ANY)
	glob.base_path = p_from_dir.simplify_path()
	return _search(glob, p_from_dir, p_recursive, p_hidden)
	#return _search(FilesThatMatchRegex.new(p_regex, true), p_from_dir, p_recursive, p_hidden)


static func search_globs(p_glob_patterns: PoolStringArray, p_from_dir: String = "res://", p_recursive: bool = true, p_hidden: bool = true) -> PoolStringArray: # Dictionary:
	if p_glob_patterns.empty(): return PoolStringArray()

	var base_path := p_from_dir.simplify_path()

	var globs := [ ]
	for pat in p_glob_patterns:
		#print(pat)
		var glob := GlobEvaluator.new(pat, FileEvaluator.MATCH_MODE.LEAF, FileEvaluator.TARGET_TYPES.ANY)
		#print('%s -> %s' % [ pat, glob._regex_source ])
		glob.base_path = base_path
		globs.push_back(glob)

	return _multi_search(globs, p_from_dir, p_recursive, p_hidden)
	#return _search(FilesThatMatchRegex.new(p_regex, true), p_from_dir, p_recursive, p_hidden)


static func MakeTestGlob(glob_pattern := '**/*.gd', base_path := 'res://MOD_CONTENT/freelancer'):
	var glob := GlobEvaluator.new(glob_pattern)
	glob.base_path = base_path
	return glob


static func TestGlobSearch(glob_pattern := '**/*.gd', base_path := 'res://MOD_CONTENT/freelancer'):
	#base_path = base_path.simplify_path()
	#var glob := GlobEvaluator.new('**/*.gd')
	#glob.base_path = base_path

	return search_glob(glob_pattern, base_path, true, true)


static func TestGlobsSearch(glob_patterns, base_path := 'res://MOD_CONTENT/freelancer'):
	#base_path = base_path.simplify_path()
	#var glob := GlobEvaluator.new('**/*.gd')
	#glob.base_path = base_path

	return search_globs(glob_patterns, base_path, true, true)


class MultiGlobEvaluator:
	var evals := [ ]
	var path_types: int setget, get_path_types


	func _init(p_evals: Array) -> void:
		if p_evals.empty():
			assert(not p_evals.empty())
			return

		evals.append_array(p_evals)


	func set_file_path(path: String):
		for eval in evals:
			eval.set_file_path(path)


	func get_path_types() -> int:
		(evals[0] as GlobEvaluator).path_types

		return -1

	func _is_match() -> bool:
		for eval in evals:
			if (eval as GlobEvaluator)._is_match():
				return true

		return false


	func _get_key() -> String:
		return evals[0]._get_key()


	# Just returns first result, caller assumes responsibility for checking
	func _get_value() -> Dictionary:
		return evals[0]._get_value()
		for eval in evals:
			if (eval as GlobEvaluator)._is_match():
				return (eval as GlobEvaluator)._get_value()

		return {}


# evals: GlobEvaluator[]
# p_from_dir: The starting location from which to scan.
# p_recursive: If true, scan all sub-directories, not just the given one.
static func _multi_search(_evals, p_from_dir: String = "res://", p_recursive: bool = true, p_hidden := false) -> PoolStringArray: # Dictionary:
	var matches := PoolStringArray()

	if _evals.empty(): return matches

	var evals := MultiGlobEvaluator.new(_evals)
	var dirs: Array = [p_from_dir]
	var dir: Directory = Directory.new()
	var data: Dictionary = {}
	var include_dirs := bool(evals.path_types & FileEvaluator.TARGET_TYPES.DIR)

	# Generate 'data' map.
	while not dirs.empty():
		var dir_name = dirs.back()
		dirs.pop_back()

		if dir.open(dir_name) == OK:
			#warning-ignore:return_value_discarded
			dir.list_dir_begin()
			var file_name = dir.get_next()
			while file_name:
				# Ignore hidden content.
				#if not file_name.begins_with("."):
				if ShouldProcess(file_name, p_hidden):
					var a_path := dir.get_current_dir().plus_file(file_name)

					#eval.set_file_path(a_path)

					# If a directory, then add to list of directories to visit.
					if p_recursive and dir.current_is_dir():
						dirs.push_back(a_path)
						evals.set_file_path(a_path + "/")

						# Evaluate directory like files below if matching dirs
						# TODO: Find best way to indicate directory is being evaluated if
						#       appending / fails
						if include_dirs and not data.has(a_path) and evals._is_match():
							#print('MATCH DIR: %s' % [ a_path ])
							#data[evals._get_key()] = evals._get_value()
							matches.push_back(evals._get_key())
					else:
						evals.set_file_path(a_path)
						# If a file, check if we already have a record for the same name.
						# Only use files with extensions.
						#if not data.has(a_path) and evals._is_match():
						if not matches.has(a_path) and evals._is_match():
							#print('MATCH FILE: %s' % [ a_path ])
							#data[evals._get_key()] = evals._get_value()
							matches.push_back(evals._get_key())

				# Move on to the next file in this directory.
				file_name = dir.get_next()

			# We've exhausted all files in this directory. Close the iterator.
			dir.list_dir_end()

	return matches # data


# p_evaluator: A FileEvaluator type.
# p_from_dir: The starting location from which to scan.
# p_recursive: If true, scan all sub-directories, not just the given one.
static func _search(p_evaluator: FileEvaluator, p_from_dir: String = "res://", p_recursive: bool = true, p_hidden := false) -> Dictionary:
	var dirs: Array = [p_from_dir]
	var dir: Directory = Directory.new()
	var data: Dictionary = {}
	var eval: FileEvaluator = p_evaluator
	var include_dirs := bool(eval.path_types & FileEvaluator.TARGET_TYPES.DIR)

	# Generate 'data' map.
	while not dirs.empty():
		var dir_name = dirs.back()
		dirs.pop_back()

		if dir.open(dir_name) == OK:
			#warning-ignore:return_value_discarded
			dir.list_dir_begin()
			var file_name = dir.get_next()
			while file_name:
				# Ignore hidden content.
				#if not file_name.begins_with("."):
				if ShouldProcess(file_name, p_hidden):
					var a_path = dir.get_current_dir().plus_file(file_name)
					eval.set_file_path(a_path)

					# If a directory, then add to list of directories to visit.
					if p_recursive and dir.current_is_dir():
						dirs.push_back(a_path)
						eval.set_file_path(a_path + "/")

						# Evaluate directory like files below if matching dirs
						# TODO: Find best way to indicate directory is being evaluated if
						#       appending / fails
						if include_dirs and not data.has(a_path) and eval._is_match():
							data[eval._get_key()] = eval._get_value()

					# If a file, check if we already have a record for the same name.
					# Only use files with extensions.
					elif not data.has(a_path) and eval._is_match():
						data[eval._get_key()] = eval._get_value()

				# Move on to the next file in this directory.
				file_name = dir.get_next()

			# We've exhausted all files in this directory. Close the iterator.
			dir.list_dir_end()

	return data


static func ShouldProcess(file_name: String, allow_hidden: bool) -> bool:
	if not allow_hidden:
		return not file_name.begins_with(".")
	else:
		return not NavigationalLeaf.has(file_name)
	#return (not file_name.begins_with(".")
	#			if not allow_hidden else
	#		not NavigationalLeaf.has(file_name))


const NavigationalLeaf := [ ".", ".." ]
