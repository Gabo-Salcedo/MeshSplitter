@tool
extends Resource
class_name SplitterModelData

## Container resource for split model components
## Holds references to all extracted resources while keeping them as standard files

@export_group("Model Info")
@export var model_name: String = ""
@export var source_file: String = ""
@export var timestamp: String = ""
@export var structure_type: int = 0

@export_group("Components")
@export var meshes: Array[Resource] = []
@export var materials: Array[Material] = []
@export var animation_library: AnimationLibrary
@export var skeleton_info: String = ""
@export var clean_scene: PackedScene

@export_group("Metadata")
@export var mesh_count: int = 0
@export var material_count: int = 0
@export var animation_count: int = 0
@export var bone_count: int = 0
@export var has_rig: bool = false

func _init():
	resource_name = "SplitterModelData"

func get_summary() -> String:
	var summary = "Model: %s\n" % model_name
	summary += "Meshes: %d | Materials: %d | Animations: %d\n" % [
		mesh_count, material_count, animation_count
	]
	summary += "Rig: %s (%d bones)\n" % ["Yes" if has_rig else "No", bone_count]
	return summary
