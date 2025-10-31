@tool
extends Resource
class_name LocationNodeData

@export var id: StringName
@export var title: String = ""
@export var position: Vector2 = Vector2.ZERO
@export var size: Vector2 = Vector2.ZERO
@export var tags: Array[String] = []
@export var out_port_labels: Array[String] = []
@export var in_port_labels: Array[String] = []
