@tool
extends EditorPlugin

var ui_panel: Control
var import_dock: Control

func _enter_tree():
	# Load and add UI panel to bottom panel
	var panel_scene = load("res://addons/MeshSplitter/ui_panel.tscn")
	if panel_scene:
		ui_panel = panel_scene.instantiate()
		add_control_to_bottom_panel(ui_panel, "Mesh Splitter")
		# Give the panel a moment to fully initialize
		await get_tree().process_frame
		
		if ui_panel.has_method("set_editor_interface"):
			ui_panel.set_editor_interface(get_editor_interface())
	else:
		push_error("Failed to load ui_panel.tscn")
	
	# Connect to file system for auto-detection (disabled for now until script loading is stable)
	# var filesystem = get_editor_interface().get_resource_filesystem()
	# if filesystem:
	#	filesystem.resources_reimported.connect(_on_resources_imported)
	
	# 	filesystem.resources_reimported.connect(_on_resources_imported)

func _exit_tree():
		ui_panel.queue_free()

func _on_resources_imported(resources: PackedStringArray):
	# Auto-detect imported 3D models
	for path in resources:
		var ext = path.get_extension().to_lower()
		if ext in ["glb", "gltf"]:
			# Auto-show panel when 3D model is imported
			if ui_panel:
				make_bottom_panel_item_visible(ui_panel)
				# Wait a frame to ensure panel is ready
				await get_tree().process_frame
				if ui_panel.has_method("set_source_file"):
					ui_panel.set_source_file(path)
