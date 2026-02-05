@tool
extends Resource
class_name SplitterAnimation

## Wrapper for extracted animation with custom icon

@export var animation: Animation
@export var original_name: String = ""
@export var length: float = 0.0
@export var loop: bool = false

func _init(p_animation: Animation = null):
	animation = p_animation
