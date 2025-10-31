@tool
extends Resource
class_name LocationEdgeData

@export var from_id: StringName
@export var to_id: StringName
@export var from_port: int = 0
@export var to_port: int = 0
@export var label: String = ""
@export var condition: String = ""
@export var bidirectional: bool = false
@export var locked: bool = false
@export var hidden: bool = false
