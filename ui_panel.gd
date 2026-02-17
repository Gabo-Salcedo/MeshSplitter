@tool
extends Control

var source_file_path: LineEdit
var source_browse_btn: Button
var output_path: LineEdit
var output_browse_btn: Button
var structure_option: OptionButton
var process_btn: Button
var cancel_btn: Button
var status_label: Label
# var progress_bar: ProgressBar
var preview_label: RichTextLabel

# Component buttons (Tags)
var all_tag: Button
var scene_tag: Button
var mesh_tag: Button
var material_tag: Button
var anim_lib_tag: Button
var anim_clip_tag: Button
var rig_tag: Button

# Tag Bar (Summary)
var summary_bar: HBoxContainer
var mesh_type_container: HBoxContainer
var overwrite_check: CheckBox

# Mesh Type buttons
var mesh_type_mesh_btn: Button
var mesh_type_tres_btn: Button
var mesh_type_res_btn: Button

# Collapsible sections (Removed)
# var components_toggle: CheckButton
# var components_content: Control 
var options_section_visible: bool = true

var file_dialog: EditorFileDialog
var output_dialog: EditorFileDialog
var _is_ready: bool = false
var editor_interface: EditorInterface
# var progress_text: Label

const SplitterScript = preload("splitter.gd")

func _ready():
	print("MeshSplitter: UI Panel _ready called")
	# Wait a frame for proper initialization when inside a Window
	await get_tree().process_frame

	# Get node references using Scene Unique Nodes (%) for robustness
	source_file_path = %FilePathEdit
	source_browse_btn = %BrowseButton
	output_path = %OutputPathEdit
	output_browse_btn = %BrowseOutputButton
	structure_option = %StructureOption
	process_btn = %ProcessButton
	cancel_btn = %CancelButton
	status_label = %StatusLabel
	
	# Progress nodes removed by user request
	# progress_bar = find_child("ProgressBar", true, false)
	# progress_text = find_child("ProgressText", true, false)
	preview_label = %PreviewLabel
	
	overwrite_check = %OverwriteCheck
	
	# Create Summary Bar (TagBar) dynamically
	summary_bar = HBoxContainer.new()
	summary_bar.name = "SummaryBar"
	summary_bar.add_theme_constant_override("separation", 8)
	
	# Insert it into the layout - specifically inside the MainVBox
	var main_vbox = %MainVBox
	if main_vbox:
		main_vbox.add_child(summary_bar)
		# Try to place it before buttons if possible
		if main_vbox.get_child_count() > 2:
			main_vbox.move_child(summary_bar, main_vbox.get_child_count() - 2)
	
	# Get mesh type buttons
	# mesh_type_container = %MeshType # Removed to avoid ambiguity with duplicate names
	mesh_type_mesh_btn = %MeshTypeMesh
	mesh_type_tres_btn = %MeshTypeTres
	mesh_type_res_btn = %MeshTypeRes
	
	# Collapsible toggle removed from UI
	# components_toggle = %ComponentsToggle
	# components_content = %ComponentsGrid
	
	scene_tag = %SceneTag
	mesh_tag = %MeshTag
	material_tag = %MaterialTag
	anim_lib_tag = %AnimationLibraryTag
	anim_clip_tag = %AnimationLibraryTag2
	rig_tag = %RigTag
	
	# New "All" button added by user (SCENE UNIQUE NAME VERIFIED IN DIFF 493)
	all_tag = %SceneTag2 

	# Setup Tag Buttons
	if all_tag:
		all_tag.toggle_mode = true
		all_tag.toggled.connect(_on_all_tag_toggled)

	_setup_tag_button(scene_tag)
	_setup_tag_button(mesh_tag)
	_setup_tag_button(material_tag)
	_setup_tag_button(anim_lib_tag)
	_setup_tag_button(anim_clip_tag)
	_setup_tag_button(rig_tag)
	
	# Initialize TagBar
	_update_tag_bar()
	
	file_dialog = EditorFileDialog.new()
	file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	file_dialog.add_filter("*.glb, *.gltf, *.fbx", "3D Models")
	file_dialog.file_selected.connect(_on_source_file_selected)
	add_child(file_dialog)
	
	output_dialog = EditorFileDialog.new()
	output_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_DIR
	output_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	output_dialog.dir_selected.connect(_on_output_dir_selected)
	add_child(output_dialog)
	
	source_browse_btn.pressed.connect(_on_browse_source)
	source_file_path.text_submitted.connect(_on_source_file_selected)
	source_file_path.focus_exited.connect(func(): _on_source_file_selected(source_file_path.text))
	output_browse_btn.pressed.connect(_on_browse_output)
	process_btn.pressed.connect(_on_process_model)
	cancel_btn.pressed.connect(_on_cancel)
	
	# Connect mesh type buttons
	if mesh_type_mesh_btn:
		mesh_type_mesh_btn.toggle_mode = true
		mesh_type_mesh_btn.toggled.connect(func(t): _on_mesh_type_changed(mesh_type_mesh_btn, t))
	if mesh_type_tres_btn:
		mesh_type_tres_btn.toggle_mode = true
		mesh_type_tres_btn.button_pressed = true # Default
		mesh_type_tres_btn.toggled.connect(func(t): _on_mesh_type_changed(mesh_type_tres_btn, t))
	if mesh_type_res_btn:
		mesh_type_res_btn.toggle_mode = true
		mesh_type_res_btn.toggled.connect(func(t): _on_mesh_type_changed(mesh_type_res_btn, t))
	
	# Connect collapsible toggle (Removed from UI)
	# if components_toggle:
	# 	components_toggle.toggled.connect(_on_components_toggle)
	# 	components_toggle.button_pressed = true

	
	output_path.text = "res://"
	
	_update_status("Ready to process models", Color.WHITE)
	# if progress_bar: progress_bar.visible = false
	# if progress_text: progress_text.visible = false
	
	_is_ready = true

func set_editor_interface(interface: EditorInterface):
	editor_interface = interface

func set_source_file(path: String):
	if not _is_ready:
		await ready
	
	if source_file_path:
		source_file_path.text = path
		# Set output to same directory as source
		if output_path:
			output_path.text = path.get_base_dir()
		_update_preview(path)
	_update_status("Model detected: " + path.get_file(), Color.CYAN)

func _on_browse_source():
	file_dialog.popup_centered_ratio(0.6)

func _on_browse_output():
	output_dialog.popup_centered_ratio(0.6)

func _on_all_tag_toggled(toggled: bool):
	if not scene_tag: return
	
	# Block signals to prevent redundant updates while setting all
	scene_tag.set_block_signals(true)
	mesh_tag.set_block_signals(true)
	material_tag.set_block_signals(true)
	anim_lib_tag.set_block_signals(true)
	anim_clip_tag.set_block_signals(true)
	rig_tag.set_block_signals(true)
	
	scene_tag.button_pressed = toggled
	mesh_tag.button_pressed = toggled
	material_tag.button_pressed = toggled
	anim_lib_tag.button_pressed = toggled
	anim_clip_tag.button_pressed = toggled
	rig_tag.button_pressed = toggled
	
	scene_tag.set_block_signals(false)
	mesh_tag.set_block_signals(false)
	material_tag.set_block_signals(false)
	anim_lib_tag.set_block_signals(false)
	anim_clip_tag.set_block_signals(false)
	rig_tag.set_block_signals(false)
	
	_update_tag_bar()

func _setup_tag_button(btn: Button):
	if not btn: return
	btn.toggle_mode = true
	btn.toggled.connect(func(_t): _update_tag_bar())

func _update_tag_bar():
	if not summary_bar: return
	
	# Clear existing children of summary bar
	for child in summary_bar.get_children():
		child.queue_free()
	
	# Add new chips based on selection
	if scene_tag.button_pressed: _add_tag_chip("Scene", Color(0.1, 0.6, 0.1)) # Greenish for Scene
	if mesh_tag.button_pressed: _add_tag_chip("Mesh", Color(0.2, 0.6, 0.8)) # Blueish for Mesh
	if material_tag.button_pressed: _add_tag_chip("Material", Color(0.8, 0.6, 0.2)) # Orange for Material
	if anim_lib_tag.button_pressed: _add_tag_chip("AnimLib", Color(0.6, 0.2, 0.6)) # Purple for AnimLib
	if anim_clip_tag.button_pressed: _add_tag_chip("Clips", Color(0.7, 0.3, 0.7)) # Lighter Purple
	if rig_tag.button_pressed: _add_tag_chip("Rig", Color(0.8, 0.2, 0.2)) # Red for Rig

func _add_tag_chip(text: String, color: Color = Color.WHITE):
	var btn = Button.new()
	btn.text = text
	btn.flat = true
	btn.add_theme_color_override("font_color", color)
	btn.mouse_filter = Control.MOUSE_FILTER_IGNORE # Purely visual
	summary_bar.add_child(btn)

func _on_source_file_selected(path: String):
	path = path.strip_edges()
	if path.is_empty(): return
	source_file_path.text = path
	
	# Auto-set output directory to source directory if not already set or default
	if output_path.text == "res://" or output_path.text.is_empty():
		output_path.text = path.get_base_dir()
		
	_update_preview(path)

func _on_output_dir_selected(path: String):
	output_path.text = path

func _on_cancel():
	# Close the window
	if get_parent() and get_parent() is Window:
		get_parent().hide()

func _update_preview(source: String):
	print("MeshSplitter: Updating preview for: ", source)
	if source.is_empty() or not FileAccess.file_exists(source):
		print("MeshSplitter: Source invalid or does not exist")
		preview_label.text = "[b]Model Preview[/b]\n\nSelect a valid 3D model to see its components..."
		return
	
	print("MeshSplitter: Calling preview_model...")
	var preview_info = SplitterScript.preview_model(source)
	print("MeshSplitter: Preview info received: ", preview_info)
	
	if preview_info.has("error"):
		print("MeshSplitter: Preview error: ", preview_info.error)
		preview_label.text = "[b]Preview Error[/b]\n\n" + preview_info.error
		return
	
	var preview_text = "[b]Model:[/b] %s\n\n" % preview_info.model_name
	preview_text += "[b]Components:[/b]\n"
	preview_text += "• Meshes: %d\n" % preview_info.meshes.size()
	preview_text += "• Materials: %d\n" % preview_info.materials.size()
	var rig_status = "Yes" if preview_info.rig.exists else "No"
	preview_text += "• Rig: %s (%d bones)\n" % [rig_status, preview_info.rig.bone_count]
	preview_text += "• Animations: %d\n" % preview_info.animations.size()
	preview_text += "• Nodes: %d\n\n" % preview_info.node_count
	
	if preview_info.meshes.size() > 0:
		preview_text += "[b]Meshes:[/b]\n"
		for mesh in preview_info.meshes.slice(0, 5):  # Limit to 5 for space
			preview_text += "  • %s\n" % mesh.name
		if preview_info.meshes.size() > 5:
			preview_text += "  ... and %d more\n" % (preview_info.meshes.size() - 5)
	
	if preview_info.animations.size() > 0:
		preview_text += "\n[b]Animations:[/b]\n"
		for anim in preview_info.animations.slice(0, 3):
			var loop_status = "loop" if anim.loop else "once"
			preview_text += "  • %s (%.1fs, %s)\n" % [anim.name, anim.length, loop_status]
		if preview_info.animations.size() > 3:
			preview_text += "  ... and %d more\n" % (preview_info.animations.size() - 3)
	
	preview_label.text = preview_text
	
func _on_process_model():
	print("MeshSplitter: Process button clicked")
	var source = source_file_path.text.strip_edges()
	var output = output_path.text.strip_edges()
	print("MeshSplitter: Source: ", source)
	print("MeshSplitter: Output: ", output)
	
	if source.is_empty():
		_update_status("Error: Please select a source file", Color.RED)
		return
	
	if output.is_empty():
		_update_status("Error: Please select an output directory", Color.RED)
		return
	
	if not FileAccess.file_exists(source):
		_update_status("Error: Source file not found", Color.RED)
		return
	
	var ext = source.get_extension().to_lower()
	if not ext in ["glb", "gltf", "fbx"]:
		_update_status("Error: Only GLB/GLTF/FBX formats supported", Color.ORANGE)
		return
	
	var model_name = source.get_file().get_basename()
	var target_dir = output.path_join(model_name)
	if DirAccess.dir_exists_absolute(target_dir) and not overwrite_check.button_pressed:
		var msg = "Error: Output folder exists. Enable 'Overwrite' or choose different output"
		_update_status(msg, Color.ORANGE)
		return
	
	var structure_type = structure_option.selected

	var mesh_ext = "tres"
	if mesh_type_mesh_btn and mesh_type_mesh_btn.button_pressed: mesh_ext = "mesh"
	elif mesh_type_res_btn and mesh_type_res_btn.button_pressed: mesh_ext = "res"
	
	var options = {
		"extract_meshes": mesh_tag.button_pressed,
		"extract_materials": material_tag.button_pressed,
		"extract_rig": rig_tag.button_pressed,
		"extract_animations": anim_lib_tag.button_pressed or anim_clip_tag.button_pressed, # Combine logic
		"extract_scene": scene_tag.button_pressed,
		"extract_textures": true, # Assuming textures are always extracted if needed, or link to Materials? Defaulting to true for now.
		"overwrite": overwrite_check.button_pressed,
		"mesh_extension": mesh_ext
	}
	
	# Show progress
	# if progress_bar: progress_bar.visible = true
	# if progress_text: progress_text.visible = true
	process_btn.disabled = true
	_update_progress("Starting...")
	await get_tree().process_frame
	
	_update_progress("Processing model...")
	var result = SplitterScript.split_model(source, output, structure_type, options)
	
	# if progress_bar: progress_bar.visible = false
	# if progress_text: progress_text.visible = false
	process_btn.disabled = false
	
	if result.success:
		var manifest = result.manifest
		var summary = "✅ Model split successfully!\n"
		summary += "Meshes: %d | Materials: %d | Animations: %d" % [
			manifest.meshes.size(),
			manifest.materials.size(),
			manifest.animations.count
		]
		
		# Show warnings if any
		if result.warnings.size() > 0:
			summary += "\n⚠ %d warnings (see console)" % result.warnings.size()
		
		_update_status(summary, Color.GREEN if result.warnings.size() == 0 else Color.YELLOW)
		
		if editor_interface:
			var filesystem = editor_interface.get_resource_filesystem()
			if filesystem:
				filesystem.scan()
	else:
		_update_status("❌ Error: " + result.error, Color.RED)
		push_error("Mesh Splitter failed: " + result.error)

func _update_status(text: String, color: Color):
	status_label.text = text
	status_label.add_theme_color_override("font_color", color)

func _update_progress(text: String):
	# Progress text removed from UI, keeping function signature for compatibility or removing body
	# if progress_text:
	# 	progress_text.text = "⏳ " + text
	print("MeshSplitter Progress: ", text)

func _on_mesh_type_changed(btn: Button, toggled: bool):
	if not toggled:
		# Enforce at least one selected (radio behavior)
		if not (mesh_type_mesh_btn.button_pressed or mesh_type_tres_btn.button_pressed or mesh_type_res_btn.button_pressed):
			btn.button_pressed = true
		return
		
	# Uncheck others
	if btn == mesh_type_mesh_btn:
		if mesh_type_tres_btn: mesh_type_tres_btn.button_pressed = false
		if mesh_type_res_btn: mesh_type_res_btn.button_pressed = false
	elif btn == mesh_type_tres_btn:
		if mesh_type_mesh_btn: mesh_type_mesh_btn.button_pressed = false
		if mesh_type_res_btn: mesh_type_res_btn.button_pressed = false
	elif btn == mesh_type_res_btn:
		if mesh_type_mesh_btn: mesh_type_mesh_btn.button_pressed = false
		if mesh_type_tres_btn: mesh_type_tres_btn.button_pressed = false
