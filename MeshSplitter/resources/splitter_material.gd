@tool
extends Resource
class_name SplitterMaterial

## Wrapper for extracted material with custom icon

@export var material: Material
@export var original_name: String = ""
@export var material_type: String = ""

func _init(p_material: Material = null):
	material = p_material
