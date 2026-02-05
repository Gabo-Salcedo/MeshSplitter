@tool
extends Control

var source_file_path: LineEdit
var source_browse_btn: Button
var output_path: LineEdit
var output_browse_btn: Button
var structure_option: OptionButton
var process_btn: Button
var preview_btn: Button
var status_label: Label
var progress_bar: ProgressBar

# Component checkboxes
var meshes_check: CheckBox
var materials_check: CheckBox
var rig_check: CheckBox
var animations_check: CheckBox
var scene_check: CheckBox
var textures_check: CheckBox
var overwrite_check: CheckBox

var file_dialog: EditorFileDialog
var output_dialog: EditorFileDialog
var preview_dialog: AcceptDialog
var _is_ready: bool = false
var editor_interface: EditorInterface

func _ready():

	# Get node references manually since @onready doesn't work well in plugins
	source_file_path = get_node("VBoxContainer/SourceRow/FilePathEdit")
	source_browse_btn = get_node("VBoxContainer/SourceRow/BrowseButton")
	output_path = get_node("VBoxContainer/OutputRow/OutputPathEdit")
	output_browse_btn = get_node("VBoxContainer/OutputRow/BrowseOutputButton")
	structure_option = get_node("VBoxContainer/StructureRow/StructureOption")
	process_btn = get_node("VBoxContainer/ProcessButton")
	preview_btn = get_node("VBoxContainer/OptionsRow/PreviewButton")
	status_label = get_node("VBoxContainer/StatusLabel")
	progress_bar = get_node("VBoxContainer/ProgressBar")
	
	progress_bar = get_node("VBoxContainer/ProgressBar")
	
	var grid = "VBoxContainer/ComponentsRow/ComponentsGrid/"
	meshes_check = get_node(grid + "MeshesCheck")
	materials_check = get_node(grid + "MaterialsCheck")
	rig_check = get_node(grid + "RigCheck")
	animations_check = get_node(grid + "AnimationsCheck")
	scene_check = get_node(grid + "SceneCheck")
	textures_check = get_node(grid + "TexturesCheck")
	overwrite_check = get_node("VBoxContainer/OptionsRow/OverwriteCheck")
	
	overwrite_check = get_node("VBoxContainer/OptionsRow/OverwriteCheck")
	
	file_dialog = EditorFileDialog.new()
	file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	file_dialog.add_filter("*.glb, *.gltf", "3D Models")
	file_dialog.file_selected.connect(_on_source_file_selected)
	add_child(file_dialog)
	
	output_dialog.dir_selected.connect(_on_output_dir_selected)
	add_child(output_dialog)
	
	preview_dialog = AcceptDialog.new()
	preview_dialog.title = "Model Preview"
	preview_dialog.dialog_text = "Loading preview..."
	preview_dialog.size = Vector2i(600, 400)
	add_child(preview_dialog)
	
	process_btn.pressed.connect(_on_process_model)
	preview_btn.pressed.connect(_on_preview_model)
	
	output_path.text = "res://"
	
	_update_status("Ready to process models", Color.WHITE)
	progress_bar.visible = false
	
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
	_update_status("Model detected: " + path.get_file(), Color.CYAN)

func _on_browse_source():
	file_dialog.popup_centered_ratio(0.6)

func _on_browse_output():
	output_dialog.popup_centered_ratio(0.6)

func _on_source_file_selected(path: String):
	source_file_path.text = path

func _on_output_dir_selected(path: String):
	output_path.text = path

func _on_preview_model():
	var source = source_file_path.text.strip_edges()
	
		_update_status("Preview failed: " + preview_info.error, Color.RED)
		return
	
	var preview_text = "[b]Model:[/b] %s\n\n" % preview_info.model_name
	preview_text += "[b]Components Found:[/b]\n"
	preview_text += "• Meshes: %d\n" % preview_info.meshes.size()
	preview_text += "• Materials: %d\n" % preview_info.materials.size()
	var rig_status = "Yes" if preview_info.rig.exists else "No"
	preview_text += "• Rig: %s (%d bones)\n" % [rig_status, preview_info.rig.bone_count]
	preview_text += "• Animations: %d\n" % preview_info.animations.size()
	preview_text += "• Total Nodes: %d\n\n" % preview_info.node_count
	
	if preview_info.meshes.size() > 0:
		preview_text += "[b]Meshes:[/b]\n"
		for mesh in preview_info.meshes:
			preview_text += "  • %s (%d vertices)\n" % [mesh.name, mesh.vertex_count]
	
	if preview_info.materials.size() > 0:
		preview_text += "\n[b]Materials:[/b]\n"
		for mat in preview_info.materials:
			preview_text += "  • %s (%s)\n" % [mat.name, mat.type]
	
	if preview_info.animations.size() > 0:
		preview_text += "\n[b]Animations:[/b]\n"
		for anim in preview_info.animations:
			var loop_status = "loop" if anim.loop else "once"
			preview_text += "  • %s (%.2fs, %s)\n" % [anim.name, anim.length, loop_status]
	
	# Create rich text label for preview
	var rich_label = RichTextLabel.new()
	rich_label.bbcode_enabled = true
	rich_label.text = preview_text
	rich_label.fit_content = true
	rich_label.custom_minimum_size = Vector2(550, 350)
	
	# Clear previous content and add new
	for child in preview_dialog.get_children():
		if child is RichTextLabel:
			child.queue_free()
	
	preview_dialog.add_child(rich_label)
	preview_dialog.popup_centered()
	
	_update_status("Preview loaded", Color.GREEN)

	_update_status("Preview loaded", Color.GREEN)
	
func _on_process_model():
	var source = source_file_path.text.strip_edges()
	var output = output_path.text.strip_edges()
	
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
	if not ext in ["glb", "gltf"]:
		_update_status("Error: Only GLB/GLTF formats supported currently", Color.ORANGE)
		return
	
		return
	
	var model_name = source.get_file().get_basename()
	var target_dir = output.path_join(model_name)
	if DirAccess.dir_exists_absolute(target_dir) and not overwrite_check.button_pressed:
		var msg = "Error: Output folder exists. Enable 'Overwrite' or choose different output"
		_update_status(msg, Color.ORANGE)
		return
	
		"overwrite": overwrite_check.button_pressed
	}
	
	var result = ModelSplitter.split_model(source, output, structure_type, options)
	
	progress_bar.visible = false
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
