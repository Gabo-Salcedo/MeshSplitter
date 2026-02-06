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
var progress_bar: ProgressBar
var preview_label: RichTextLabel

# Component checkboxes
var meshes_check: CheckBox
var materials_check: CheckBox
var rig_check: CheckBox
var animations_check: CheckBox
var scene_check: CheckBox
var textures_check: CheckBox
var overwrite_check: CheckBox

# Preset buttons
var preset_all_btn: Button
var preset_meshes_btn: Button
var preset_anims_btn: Button

# Collapsible sections
var components_toggle: CheckButton
var components_content: Control
var options_section_visible: bool = true

var file_dialog: EditorFileDialog
var output_dialog: EditorFileDialog
var _is_ready: bool = false
var editor_interface: EditorInterface
var progress_text: Label

func _ready():
	# Wait a frame for proper initialization when inside a Window
	await get_tree().process_frame

	# Get node references manually since @onready doesn't work well in plugins
	source_file_path = get_node("VBoxContainer/SourceRow/FilePathEdit")
	source_browse_btn = get_node("VBoxContainer/SourceRow/BrowseButton")
	output_path = get_node("VBoxContainer/OutputRow/OutputPathEdit")
	output_browse_btn = get_node("VBoxContainer/OutputRow/BrowseOutputButton")
	structure_option = get_node("VBoxContainer/StructureRow/StructureOption")
	process_btn = get_node("VBoxContainer/ButtonsRow/ProcessButton")
	cancel_btn = get_node("VBoxContainer/ButtonsRow/CancelButton")
	status_label = get_node("VBoxContainer/StatusLabel")
	progress_bar = get_node("VBoxContainer/ProgressBar")
	progress_text = get_node("VBoxContainer/ProgressText")
	preview_label = get_node("VBoxContainer/PreviewLabel")
	
	# Get preset buttons
	if has_node("VBoxContainer/PresetsRow/PresetAllButton"):
		preset_all_btn = get_node("VBoxContainer/PresetsRow/PresetAllButton")
	if has_node("VBoxContainer/PresetsRow/PresetMeshesButton"):
		preset_meshes_btn = get_node("VBoxContainer/PresetsRow/PresetMeshesButton")
	if has_node("VBoxContainer/PresetsRow/PresetAnimsButton"):
		preset_anims_btn = get_node("VBoxContainer/PresetsRow/PresetAnimsButton")
	
	# Get collapsible section toggle
	if has_node("VBoxContainer/ComponentsRow/ComponentsToggle"):
		components_toggle = get_node("VBoxContainer/ComponentsRow/ComponentsToggle")
	if has_node("VBoxContainer/ComponentsContentRow"):
		components_content = get_node("VBoxContainer/ComponentsContentRow")
	
	var grid = "VBoxContainer/ComponentsContentRow/ComponentsGrid/"
	meshes_check = get_node(grid + "MeshesCheck")
	materials_check = get_node(grid + "MaterialsCheck")
	rig_check = get_node(grid + "RigCheck")
	animations_check = get_node(grid + "AnimationsCheck")
	scene_check = get_node(grid + "SceneCheck")
	textures_check = get_node(grid + "TexturesCheck")
	overwrite_check = get_node("VBoxContainer/OptionsRow/OverwriteCheck")
	
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
	output_browse_btn.pressed.connect(_on_browse_output)
	process_btn.pressed.connect(_on_process_model)
	cancel_btn.pressed.connect(_on_cancel)
	
	# Connect preset buttons
	if preset_all_btn:
		preset_all_btn.pressed.connect(_apply_preset_all)
	if preset_meshes_btn:
		preset_meshes_btn.pressed.connect(_apply_preset_meshes_only)
	if preset_anims_btn:
		preset_anims_btn.pressed.connect(_apply_preset_animations)
	
	# Connect collapsible toggle
	if components_toggle:
		components_toggle.toggled.connect(_on_components_toggle)
		components_toggle.button_pressed = true
	
	output_path.text = "res://"
	
	_update_status("Ready to process models", Color.WHITE)
	progress_bar.visible = false
	progress_text.visible = false
	
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

func _on_source_file_selected(path: String):
	source_file_path.text = path
	_update_preview(path)

func _on_output_dir_selected(path: String):
	output_path.text = path

func _on_cancel():
	# Close the window
	if get_parent() and get_parent() is Window:
		get_parent().hide()

func _update_preview(source: String):
	if source.is_empty() or not FileAccess.file_exists(source):
		preview_label.text = "[b]Model Preview[/b]\n\nSelect a valid 3D model to see its components..."
		return
	
	var preview_info = MeshSplitter.preview_model(source)
	
	if preview_info.has("error"):
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
	var source = source_file_path.text.strip_edges()
	var output = output_path.text.strip_edges()
	
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
	var options = {
		"extract_meshes": meshes_check.button_pressed,
		"extract_materials": materials_check.button_pressed,
		"extract_rig": rig_check.button_pressed,
		"extract_animations": animations_check.button_pressed,
		"extract_scene": scene_check.button_pressed,
		"extract_textures": textures_check.button_pressed,
		"overwrite": overwrite_check.button_pressed
	}
	
	# Show progress
	progress_bar.visible = true
	progress_text.visible = true
	process_btn.disabled = true
	_update_progress("Starting...")
	await get_tree().process_frame
	
	_update_progress("Processing model...")
	var result = MeshSplitter.split_model(source, output, structure_type, options)
	
	progress_bar.visible = false
	progress_text.visible = false
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
	if progress_text:
		progress_text.text = "⏳ " + text

func _apply_preset_all():
	meshes_check.button_pressed = true
	materials_check.button_pressed = true
	rig_check.button_pressed = true
	animations_check.button_pressed = true
	scene_check.button_pressed = true
	textures_check.button_pressed = true
	_update_status("Preset: Extract All", Color.CYAN)

func _apply_preset_meshes_only():
	meshes_check.button_pressed = true
	materials_check.button_pressed = true
	rig_check.button_pressed = false
	animations_check.button_pressed = false
	scene_check.button_pressed = false
	textures_check.button_pressed = true
	_update_status("Preset: Meshes & Materials Only", Color.CYAN)

func _apply_preset_animations():
	meshes_check.button_pressed = false
	materials_check.button_pressed = false
	rig_check.button_pressed = true
	animations_check.button_pressed = true
	scene_check.button_pressed = false
	textures_check.button_pressed = false
	_update_status("Preset: Animation Export", Color.CYAN)

func _on_components_toggle(toggled: bool):
	if components_content:
		components_content.visible = toggled
