@tool
extends EditorPlugin

var floating_window: Window
var ui_panel: Control

func _enter_tree():
	# Load and create floating window
	var panel_scene = load("res://addons/MeshSplitter/ui_panel.tscn")
	if panel_scene:
		ui_panel = panel_scene.instantiate()
		
		# Create floating window
		floating_window = Window.new()
		floating_window.title = "Mesh Splitter"
		floating_window.size = Vector2i(600, 700)
		floating_window.min_size = Vector2i(500, 600)
		floating_window.unresizable = false
		floating_window.transient = true
		floating_window.exclusive = false
		
		# Add panel to window
		floating_window.add_child(ui_panel)
		
		# Add window to editor
		get_editor_interface().get_base_control().add_child(floating_window)
		
		# Position window
		var screen_size = DisplayServer.screen_get_size()
		floating_window.position = Vector2i(screen_size.x - 650, 100)
		
		# Give the panel a moment to fully initialize
		await get_tree().process_frame
		
		if ui_panel.has_method("set_editor_interface"):
			ui_panel.set_editor_interface(get_editor_interface())
	else:
		push_error("Failed to load ui_panel.tscn")
	
	# Connect to file system for auto-detection
	var filesystem = get_editor_interface().get_resource_filesystem()
	if filesystem:
		filesystem.filesystem_changed.connect(_on_filesystem_changed)
		filesystem.resources_reimported.connect(_on_resources_imported)

func _exit_tree():
	if floating_window:
		floating_window.queue_free()
		floating_window = null
	ui_panel = null

func _on_filesystem_changed():
	# Scan for newly added 3D models
	var filesystem = get_editor_interface().get_resource_filesystem()
	if filesystem and ui_panel:
		_check_for_3d_models()

func _check_for_3d_models():
	# This is called when filesystem changes, let's check recent files
	# For now, we won't auto-open on filesystem changes to avoid being intrusive
	pass

func _on_resources_imported(resources: PackedStringArray):
	# Auto-detect imported 3D models
	for path in resources:
		var ext = path.get_extension().to_lower()
		if ext in ["glb", "gltf", "fbx"]:
			# Show and focus the floating window
			if floating_window:
				floating_window.show()
				floating_window.move_to_foreground()
			# Show popup notification
			_show_model_detected_popup(path)
			# Auto-set file when 3D model is imported
			if ui_panel:
				# Wait a frame to ensure panel is ready
				await get_tree().process_frame
				if ui_panel.has_method("set_source_file"):
					ui_panel.set_source_file(path)
			break  # Only process the first 3D model found

func _show_model_detected_popup(model_path: String):
	var dialog = AcceptDialog.new()
	dialog.title = "3D Model Detected"
	dialog.dialog_text = "New 3D model imported:\n%s\n\nThe Mesh Splitter window is now open and ready to process it." % model_path.get_file()
	dialog.ok_button_text = "Got it!"
	get_editor_interface().get_base_control().add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func(): dialog.queue_free())
	dialog.close_requested.connect(func(): dialog.queue_free())
