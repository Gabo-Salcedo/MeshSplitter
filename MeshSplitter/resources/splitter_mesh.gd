@tool
extends Resource
class_name SplitterMesh

## Wrapper for extracted mesh with custom icon

@export var mesh: Mesh
@export var original_name: String = ""
@export var vertex_count: int = 0

func _init(p_mesh: Mesh = null):
	mesh = p_mesh
