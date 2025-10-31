@tool
extends Resource
class_name LocationGraph

## List of LocationNodeData resources
@export var nodes: Array = []
## List of LocationEdgeData resources
@export var edges: Array = []
@export var start_node_id: StringName = ""
@export var version: int = 1


## Creates a new instance of this location graph with unique properties.
## Use this method when loading a graph for runtime use to allow modifications
## (like locking/unlocking routes) without affecting the original resource.
func create_instance() -> LocationGraph:
	return duplicate(true)  # true = deep copy (copies nested resources too)
