@tool
class_name MeshSplitter

## Core class for splitting 3D models into modular components
## Handles GLB/GLTF formats and extracts meshes, materials, rigs, and animations

enum FolderStructure {
	ORGANIZED, # mesh/, materials/, anims/ subfolders
	FLAT, # all files with prefixes in root
	SINGLE # all files together without prefixes
}

static func preview_model(source_path: String) -> Dictionary:
	var preview = {
		"model_name": "",
		"meshes": [],
		"materials": [],
		"rig": {"exists": false, "bone_count": 0},
		"animations": [],
		"node_count": 0
	}
	
	if not FileAccess.file_exists(source_path):
		preview["error"] = "Source file not found"
		return preview
	
	var scene = load(source_path)
	if not scene:
		print("MeshSplitter: Failed to load source file: ", source_path)
		preview["error"] = "Failed to load source file"
		return preview
	
	var root = scene.instantiate()
	if not root:
		print("MeshSplitter: Failed to instantiate scene: ", source_path)
		preview["error"] = "Failed to instantiate scene"
		return preview
	
	preview.model_name = source_path.get_file().get_basename()
	preview.node_count = _count_nodes(root)
	
	var mesh_nodes = _find_nodes_by_type(root, MeshInstance3D)
	for mesh_node in mesh_nodes:
		if mesh_node.mesh:
			var vertex_count = 0
			if mesh_node.mesh.get_faces():
				vertex_count = mesh_node.mesh.get_faces().size()
			preview.meshes.append({
				"name": mesh_node.name,
				"vertex_count": vertex_count
			})
	
	var material_set = {}
	for mesh_node in mesh_nodes:
		if mesh_node.mesh:
			for i in range(mesh_node.mesh.get_surface_count()):
				var mat = mesh_node.get_surface_override_material(i)
				if not mat:
					mat = mesh_node.mesh.surface_get_material(i)
				if mat and not material_set.has(mat):
					var mat_name = mat.resource_name
					if not mat_name:
						mat_name = "material_%d" % material_set.size()
					preview.materials.append({
						"name": mat_name,
						"type": mat.get_class()
					})
					material_set[mat] = true
	
	var skeleton = _find_node_by_type(root, Skeleton3D)
	if skeleton:
		preview.rig.exists = true
		preview.rig.bone_count = skeleton.get_bone_count()
	
	var anim_player = _find_node_by_type(root, AnimationPlayer)
	if anim_player:
		var anim_list = anim_player.get_animation_list()
		for anim_name in anim_list:
			var animation = anim_player.get_animation(anim_name)
			if animation:
				preview.animations.append({
					"name": anim_name,
					"length": animation.length,
					"loop": animation.loop_mode != Animation.LOOP_NONE
				})
	
	root.queue_free()
	return preview

static func split_model(
	source_path: String,
	output_base_path: String,
	structure_type: int = FolderStructure.ORGANIZED,
	options: Dictionary = {}
) -> Dictionary:
	var result = {
		"success": false,
		"error": "",
		"manifest": {},
		"warnings": []
	}
	
	# Set default options
	var default_options = {
		"extract_meshes": true,
		"extract_materials": true,
		"extract_rig": true,
		"extract_animations": true,
		"extract_scene": true,
		"extract_textures": true,
		"overwrite": false
	}
	
	# Merge user options with defaults
	for key in default_options:
		if not options.has(key):
			options[key] = default_options[key]
	
	# Validate source file
	if not FileAccess.file_exists(source_path):
		result.error = "Source file not found: " + source_path
		return result
	
	var scene = load(source_path)
	if not scene:
		result.error = "Failed to load source file"
		return result
	
	var root = scene.instantiate()
	if not root:
		result.error = "Failed to instantiate scene"
		return result
	
	var model_name = source_path.get_file().get_basename()
	var base_dir = output_base_path.path_join(model_name)
	
	if DirAccess.dir_exists_absolute(base_dir) and not options.overwrite:
		result.error = "Output directory already exists. Enable overwrite option."
		root.queue_free()
		return result
	
	var manifest = {
		"source": source_path,
		"timestamp": Time.get_datetime_string_from_system(),
		"model_name": model_name,
		"structure_type": structure_type,
		"options": options
	}
	
	if options.extract_meshes:
		var mesh_result = _extract_meshes(root, base_dir, model_name, structure_type, options)
		manifest["meshes"] = mesh_result.data
		if mesh_result.has("warnings"):
			result.warnings.append_array(mesh_result.warnings)
	else:
		manifest["meshes"] = []
	
	if options.extract_materials:
		var mat_result = _extract_materials(
			root, base_dir, model_name, structure_type, options.extract_textures
		)
		manifest["materials"] = mat_result.data
		if mat_result.has("warnings"):
			result.warnings.append_array(mat_result.warnings)
	else:
		manifest["materials"] = []
	
	if options.extract_rig:
		manifest["rig"] = _extract_rig(root, base_dir, model_name, structure_type)
	else:
		manifest["rig"] = {"exists": false, "path": "", "bone_count": 0}
	
	if options.extract_animations:
		var anim_result = _extract_animations(root, base_dir, model_name, structure_type)
		manifest["animations"] = anim_result.data
		if anim_result.has("warnings"):
			result.warnings.append_array(anim_result.warnings)
	else:
		manifest["animations"] = {"count": 0, "individual": [], "library": ""}
	
	if options.extract_scene:
		manifest["scene"] = _create_clean_scene(root, base_dir, model_name)
	else:
		manifest["scene"] = {"path": "", "node_count": 0}
	
	_save_manifest(manifest, base_dir)
	_create_readme(base_dir, manifest)
	
	root.queue_free()
	
	result.success = true
	result.manifest = manifest
	return result

static func _create_directories(base_dir: String, _structure_type: int) -> Dictionary:
	var result = {"success": true, "error": ""}
	
	# Only create base directory - subdirectories will be created on demand
	var err = DirAccess.make_dir_recursive_absolute(base_dir)
	if err != OK:
		result.success = false
		result.error = "Failed to create base directory (error code: %d)" % err
		return result
	
	return result

static func _ensure_dir_exists(dir_path: String) -> bool:
	if DirAccess.dir_exists_absolute(dir_path):
		return true
	var err = DirAccess.make_dir_recursive_absolute(dir_path)
	return err == OK

static func _extract_meshes(
	root: Node,
	base_dir: String,
	_model_name: String,
	structure_type: int,
	options: Dictionary = {}
) -> Dictionary:
	var result = {"data": [], "warnings": []}
	var mesh_nodes = _find_nodes_by_type(root, MeshInstance3D)
	var name_counter = {}
	
	# Create mesh directory only if we have meshes (ORGANIZED structure only)
	if mesh_nodes.size() > 0 and structure_type == FolderStructure.ORGANIZED:
		_ensure_dir_exists(base_dir.path_join("mesh"))
	
	# Get extension from options, default to tres
	var ext = "tres"
	if options.has("mesh_extension"):
		ext = options.mesh_extension
		# Ensure dot is not duplicated if passed (though we pass "tres", "mesh" etc)
		ext = ext.replace(".", "")
	
	for mesh_node in mesh_nodes:
		if mesh_node.mesh:
			var mesh_name = mesh_node.name.to_snake_case()
			if mesh_name == "":
				mesh_name = "mesh_%d" % result.data.size()
			
			# Handle duplicate names
			if name_counter.has(mesh_name):
				name_counter[mesh_name] += 1
				var original_name = mesh_name
				mesh_name = "%s_%d" % [mesh_name, name_counter[mesh_name]]
				var warn = "Duplicate mesh name '%s' renamed to '%s'"
				result.warnings.append(warn % [original_name, mesh_name])
			else:
				name_counter[mesh_name] = 0
			
			# Build path based on structure type
			var mesh_path = ""
			match structure_type:
				FolderStructure.ORGANIZED:
					mesh_path = base_dir.path_join("mesh/%s.%s" % [mesh_name, ext])
				FolderStructure.FLAT:
					mesh_path = base_dir.path_join("mesh_%s.%s" % [mesh_name, ext])
				FolderStructure.SINGLE:
					mesh_path = base_dir.path_join("%s.%s" % [mesh_name, ext])
			
			# Optimization: converting to ArrayMesh and optimizing indices if it's not already optimal
			var mesh_to_save = mesh_node.mesh
			if mesh_to_save is ArrayMesh:
				# Regenerate shadow mesh for mobile/compatibility if needed, or optimize
				# For now, just ensure it's a clean ArrayMesh. 
				# If the user means "optimize for cache", we can do:
				# mesh_to_save.regen_normal_maps() # if needed
				pass
			elif mesh_to_save is ImporterMesh:
				# Should not happen in runtime typically, but handle just in case
				pass
				
			var err = ResourceSaver.save(mesh_node.mesh, mesh_path)
			if err == OK:
				var vertex_count = 0
				if mesh_node.mesh.get_faces():
					vertex_count = mesh_node.mesh.get_faces().size()
				result.data.append({
					"name": mesh_node.name,
					"path": mesh_path,
					"vertex_count": vertex_count
				})
			else:
				var warn = "Failed to save mesh '%s' (error code: %d)"
				result.warnings.append(warn % [mesh_node.name, err])
	
	return result

static func _extract_materials(
	root: Node,
	base_dir: String,
	_model_name: String,
	structure_type: int,
	extract_textures: bool = true
) -> Dictionary:
	var result = {"data": [], "warnings": []}
	var material_set = {}
	var name_counter = {}
	var mesh_nodes = _find_nodes_by_type(root, MeshInstance3D)
	var has_materials = false
	
	# First pass: check if we have any materials
	for mesh_node in mesh_nodes:
		if mesh_node.mesh:
			for i in range(mesh_node.mesh.get_surface_count()):
				var mat = mesh_node.get_surface_override_material(i)
				if not mat:
					mat = mesh_node.mesh.surface_get_material(i)
				if mat:
					has_materials = true
					break
		if has_materials:
			break
	
	# Create directories only if we have materials
	if has_materials and structure_type == FolderStructure.ORGANIZED:
		_ensure_dir_exists(base_dir.path_join("materials"))
		if extract_textures:
			_ensure_dir_exists(base_dir.path_join("textures"))
	
	for mesh_node in mesh_nodes:
		if mesh_node.mesh:
			for i in range(mesh_node.mesh.get_surface_count()):
				var mat = mesh_node.get_surface_override_material(i)
				if not mat:
					mat = mesh_node.mesh.surface_get_material(i)
				
				if mat and not material_set.has(mat):
					var mat_name = mat.resource_name
					if not mat_name:
						mat_name = "material_%d" % material_set.size()
					mat_name = mat_name.to_snake_case()
					
					# Handle duplicate names
					if name_counter.has(mat_name):
						name_counter[mat_name] += 1
						var original_name = mat_name
						mat_name = "%s_%d" % [mat_name, name_counter[mat_name]]
						var warn = "Duplicate material name '%s' renamed to '%s'"
						result.warnings.append(warn % [original_name, mat_name])
					else:
						name_counter[mat_name] = 0
					
					# Extract textures if requested
					var textures_extracted = []
					if extract_textures and mat is StandardMaterial3D:
						textures_extracted = _extract_textures_from_material(
							mat, base_dir, mat_name, structure_type
						)
					
					# Build path based on structure type
					var mat_path = ""
					match structure_type:
						FolderStructure.ORGANIZED:
							mat_path = base_dir.path_join("materials/%s.tres" % mat_name)
						FolderStructure.FLAT:
							mat_path = base_dir.path_join("mat_%s.tres" % mat_name)
						FolderStructure.SINGLE:
							mat_path = base_dir.path_join("%s.tres" % mat_name)
					
					var err = ResourceSaver.save(mat, mat_path)
					if err == OK:
						result.data.append({
							"name": mat_name,
							"path": mat_path,
							"type": mat.get_class(),
							"textures": textures_extracted
						})
						material_set[mat] = true
					else:
						var warn = "Failed to save material '%s' (error code: %d)"
						result.warnings.append(warn % [mat_name, err])
	
	return result

static func _extract_textures_from_material(
	mat: StandardMaterial3D,
	base_dir: String,
	mat_name: String,
	structure_type: int
) -> Array:
	var textures = []
	var texture_props = [
		{"prop": "albedo_texture", "suffix": "albedo"},
		{"prop": "metallic_texture", "suffix": "metallic"},
		{"prop": "roughness_texture", "suffix": "roughness"},
		{"prop": "normal_texture", "suffix": "normal"},
		{"prop": "emission_texture", "suffix": "emission"},
		{"prop": "ao_texture", "suffix": "ao"}
	]
	
	for tex_info in texture_props:
		var texture = mat.get(tex_info.prop)
		if texture and texture is Texture2D:
			var tex_name = "%s_%s" % [mat_name, tex_info.suffix]
			var tex_path = ""
			
			match structure_type:
				FolderStructure.ORGANIZED:
					tex_path = base_dir.path_join("textures/%s.png" % tex_name)
				FolderStructure.FLAT:
					tex_path = base_dir.path_join("tex_%s.png" % tex_name)
				FolderStructure.SINGLE:
					tex_path = base_dir.path_join("%s.png" % tex_name)
			
			# Try to save texture
			var img = texture.get_image()
			if img:
				var err = img.save_png(tex_path)
				if err == OK:
					textures.append({
						"type": tex_info.suffix,
						"path": tex_path
					})
	
	return textures

static func _extract_rig(
	root: Node,
	base_dir: String,
	_model_name: String,
	structure_type: int
) -> Dictionary:
	var rig_data = {
		"exists": false,
		"path": "",
		"bone_count": 0
	}
	
	var skeleton = _find_node_by_type(root, Skeleton3D)
	if skeleton:
		rig_data.exists = true
		rig_data.bone_count = skeleton.get_bone_count()
		
		# Create rig directory only for ORGANIZED structure
		if structure_type == FolderStructure.ORGANIZED:
			_ensure_dir_exists(base_dir.path_join("rig"))
		
		# Build path based on structure type
		var rig_path = ""
		match structure_type:
			FolderStructure.ORGANIZED:
				rig_path = base_dir.path_join("rig/skeleton_info.txt")
			FolderStructure.FLAT:
				rig_path = base_dir.path_join("rig_skeleton_info.txt")
			FolderStructure.SINGLE:
				rig_path = base_dir.path_join("skeleton_info.txt")
		
		var file = FileAccess.open(rig_path, FileAccess.WRITE)
		if file:
			file.store_string("Skeleton: %s\n" % skeleton.name)
			file.store_string("Bone count: %d\n" % skeleton.get_bone_count())
			for i in range(skeleton.get_bone_count()):
				file.store_string("  - %s\n" % skeleton.get_bone_name(i))
			file.close()
		rig_data.path = rig_path
	
	return rig_data

static func _extract_animations(
	root: Node,
	base_dir: String,
	_model_name: String,
	structure_type: int
) -> Dictionary:
	var result = {
		"data": {
			"count": 0,
			"individual": [],
			"library": ""
		},
		"warnings": []
	}
	
	var anim_player = _find_node_by_type(root, AnimationPlayer)
	if not anim_player:
		return result
	
	var library = AnimationLibrary.new()
	var anim_list = anim_player.get_animation_list()
	var name_counter = {}
	
	# Create anims directory only if we have animations (ORGANIZED structure only)
	if anim_list.size() > 0 and structure_type == FolderStructure.ORGANIZED:
		_ensure_dir_exists(base_dir.path_join("anims"))
	
	for anim_name in anim_list:
		var animation = anim_player.get_animation(anim_name)
		if animation:
			# Save individual animation
			var safe_name = anim_name.to_snake_case()
			if safe_name == "":
				safe_name = "animation_%d" % result.data.individual.size()
			
			# Handle duplicate names
			if name_counter.has(safe_name):
				name_counter[safe_name] += 1
				var original_name = safe_name
				safe_name = "%s_%d" % [safe_name, name_counter[safe_name]]
				var warn = "Duplicate animation name '%s' renamed to '%s'"
				result.warnings.append(warn % [original_name, safe_name])
			else:
				name_counter[safe_name] = 0
			
			# Build path based on structure type
			var anim_path = ""
			match structure_type:
				FolderStructure.ORGANIZED:
					anim_path = base_dir.path_join("anims/%s.res" % safe_name)
				FolderStructure.FLAT:
					anim_path = base_dir.path_join("anim_%s.res" % safe_name)
				FolderStructure.SINGLE:
					anim_path = base_dir.path_join("%s.res" % safe_name)
			
			var err = ResourceSaver.save(animation, anim_path)
			if err == OK:
				result.data.individual.append({
					"name": anim_name,
					"path": anim_path,
					"length": animation.length,
					"loop": animation.loop_mode != Animation.LOOP_NONE
				})
				
				# Add to library
				library.add_animation(anim_name, animation)
			else:
				var warn = "Failed to save animation '%s' (error code: %d)"
				result.warnings.append(warn % [anim_name, err])
	
	# Save animation library
	if result.data.individual.size() > 0:
		# Build library path based on structure type
		var lib_path = ""
		match structure_type:
			FolderStructure.ORGANIZED:
				lib_path = base_dir.path_join("anims/AnimationLibrary.tres")
			FolderStructure.FLAT:
				lib_path = base_dir.path_join("anim_library.tres")
			FolderStructure.SINGLE:
				lib_path = base_dir.path_join("AnimationLibrary.tres")
		
		var err = ResourceSaver.save(library, lib_path)
		if err == OK:
			result.data.library = lib_path
			result.data.count = result.data.individual.size()
		else:
			result.warnings.append("Failed to save animation library (error code: %d)" % err)
	
	return result

static func _create_clean_scene(root: Node, base_dir: String, model_name: String) -> Dictionary:
	var scene_data = {
		"path": "",
		"node_count": 0
	}
	
	# Duplicate the root to preserve hierarchy
	var clean_root = root.duplicate()
	clean_root.name = model_name
	
	# Count nodes
	scene_data.node_count = _count_nodes(clean_root)
	
	var packed_scene = PackedScene.new()
	var err = packed_scene.pack(clean_root)
	
	if err == OK:
		# Determine scene path and create directory if needed
		var scene_path = ""
		var scene_dir = base_dir.path_join("scene")
		
		# Create scene directory only if it doesn't exist (ORGANIZED structure)
		if scene_dir.contains("/scene"):
			_ensure_dir_exists(scene_dir)
			scene_path = scene_dir.path_join("%s_clean.tscn" % model_name.to_snake_case())
		else:
			scene_path = base_dir.path_join("%s_clean.tscn" % model_name.to_snake_case())
		
		err = ResourceSaver.save(packed_scene, scene_path)
		if err == OK:
			scene_data.path = scene_path
	
	clean_root.queue_free()
	return scene_data

static func _save_manifest(manifest: Dictionary, base_dir: String) -> void:
	var manifest_path = base_dir.path_join("manifest.json")
	var file = FileAccess.open(manifest_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(manifest, "\t"))
		file.close()

static func _create_readme(base_dir: String, manifest: Dictionary) -> void:
	var readme_path = base_dir.path_join("README.txt")
	var file = FileAccess.open(readme_path, FileAccess.WRITE)
	if file:
		var separator = "=".repeat(60)
		var line_sep = "-".repeat(60)
		
		file.store_string(separator + "\n")
		file.store_string("  MESH SPLITTER - Extracted Components\n")
		file.store_string(separator + "\n\n")
		file.store_string("Model: %s\n" % manifest.model_name)
		file.store_string("Source: %s\n" % manifest.source)
		file.store_string("Generated: %s\n\n" % manifest.timestamp)
		file.store_string("CONTENTS:\n")
		file.store_string(line_sep + "\n")
		file.store_string("• Meshes: %d\n" % manifest.meshes.size())
		file.store_string("• Materials: %d\n" % manifest.materials.size())
		file.store_string("• Animations: %d\n" % manifest.animations.count)
		var rig_status = "Yes" if manifest.rig.exists else "No"
		file.store_string("• Rig: %s\n" % rig_status)
		var scene_status = "Created" if manifest.scene.path else "None"
		file.store_string("• Scene: %s\n\n" % scene_status)
		file.store_string("Structure Type: ")
		match manifest.structure_type:
			0: file.store_string("Organized (subfolders)\n")
			1: file.store_string("Flat (with prefixes)\n")
			2: file.store_string("Single (all together)\n")
		file.store_string("\n" + separator + "\n")
		file.store_string("Generated by Mesh Splitter Plugin for Godot\n")
		file.close()

static func _find_nodes_by_type(root: Node, type) -> Array:
	var result = []
	_find_nodes_recursive(root, type, result)
	return result

static func _find_nodes_recursive(node: Node, type, result: Array) -> void:
	if is_instance_of(node, type):
		result.append(node)
	
	for child in node.get_children():
		_find_nodes_recursive(child, type, result)

static func _find_node_by_type(root: Node, type):
	var nodes = _find_nodes_by_type(root, type)
	return nodes[0] if nodes.size() > 0 else null

static func _count_nodes(node: Node) -> int:
	var count = 1
	for child in node.get_children():
		count += _count_nodes(child)
	return count
