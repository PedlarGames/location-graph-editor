# This runtime class provides an interface for interacting with a LocationGraph resource.
# It handles loading the graph data and provides utility functions for navigation,
# such as finding neighbors and pathfinding between locations.
extends Node
class_name LocationGraphRuntime

## --- Member Variables ---

# The loaded LocationGraph resource containing the map data.
var location_graph: LocationGraph

# A dictionary mapping a location ID (String) to an array of its neighboring location IDs (Array[String]).
# This provides a quick lookup for adjacent locations.
var neighbors: Dictionary = {}

# A dictionary mapping a location ID (String) to its corresponding LocationNodeData resource.
# This allows for fast retrieval of location-specific data like title or properties.
var nodes: Dictionary = {}

# Indexed edges for fast lookup: from_id -> [LocationEdgeData], to_id -> [LocationEdgeData]
var edges_from: Dictionary = {}
var edges_to: Dictionary = {}


## --- Public API ---

# Loads a LocationGraph resource from a given file path (e.g., "res://...").
func load_graph(path: String) -> void:
	var resource = ResourceLoader.load(path)
	if resource is LocationGraph:
		set_graph(resource)
	else:
		push_error("Failed to load LocationGraph from path: %s" % path)


# Loads a LocationGraph resource and creates an instance for runtime modification.
# Use this when you need to modify the graph at runtime (e.g., lock/unlock routes).
# The instance will be independent of the original resource.
func load_graph_instanced(path: String) -> void:
	var resource = ResourceLoader.load(path)
	if resource is LocationGraph:
		var instance := (resource as LocationGraph).create_instance()
		set_graph(instance)
	else:
		push_error("Failed to load LocationGraph from path: %s" % path)


# Sets the active graph from an already loaded LocationGraph resource.
func set_graph(graph_resource: LocationGraph) -> void:
	location_graph = graph_resource
	_build_internal_indices()


# Returns the ID of the designated start location in the graph.
# Returns an empty string if no graph is loaded or no start ID is set.
func get_start_id() -> String:
	if location_graph and String(location_graph.start_node_id) != "":
		return String(location_graph.start_node_id)
	return ""


# Retrieves the LocationNodeData for a given location ID.
# Returns null if the location ID does not exist in the graph.
func get_location_node(id: String) -> LocationNodeData:
	return nodes.get(id, null)


# Returns an array of neighboring location IDs for a given location ID.
# This only returns accessible (non-locked) neighbors.
func get_neighbors(id: String) -> Array[String]:
	var result: Array[String] = neighbors.get(id, [])
	return result

# Returns an array of all neighboring location IDs for a given location ID, including locked ones.
func get_all_neighbors(id: String) -> Array[String]:
	var result: Array[String] = []
	
	# Get all outgoing edges from this node
	for edge in get_edges_from(id):
		var to_id := String(edge.to_id)
		if to_id not in result:
			result.append(to_id)
	
	# Get all incoming bidirectional edges to this node
	for edge in get_edges_to(id):
		if edge.bidirectional:
			var from_id := String(edge.from_id)
			if from_id not in result:
				result.append(from_id)
	
	return result


## Convenience helpers to reduce duplication in UI code.

# Returns the start node ID if set, otherwise the first node's ID (or empty string).
func get_start_or_first_id() -> String:
	if location_graph == null:
		return ""
	var sid := get_start_id()
	if sid != "":
		return sid
	if location_graph.nodes.size() > 0:
		return String((location_graph.nodes[0] as LocationNodeData).id)
	return ""

# Returns an array of LocationEdgeData objects that originate from the given node id.
func get_edges_from(from_id: String) -> Array:
	return edges_from.get(from_id, [])


func get_edges_to(to_id: String) -> Array:
	return edges_to.get(to_id, [])


func get_edge_between(from_id: String, to_id: String) -> LocationEdgeData:
	# Return the first matching edge from 'from_id' to 'to_id', or null if none.
	# Skip locked and hidden edges unless specifically requesting them
	for e in get_edges_from(from_id):
		var is_hidden: bool = "hidden" in e and e.hidden
		if String(e.to_id) == to_id and not e.locked and not is_hidden:
			return e
	
	# Also check for bidirectional edges in the reverse direction
	for e in get_edges_from(to_id):
		var is_hidden: bool = "hidden" in e and e.hidden
		if String(e.to_id) == from_id and e.bidirectional and not e.locked and not is_hidden:
			return e
	
	return null

# Returns the edge between two nodes, including locked edges
func get_edge_between_including_locked(from_id: String, to_id: String) -> LocationEdgeData:
	# Return the first matching edge from 'from_id' to 'to_id', or null if none.
	for e in get_edges_from(from_id):
		if String(e.to_id) == to_id:
			return e
	
	# Also check for bidirectional edges in the reverse direction
	for e in get_edges_from(to_id):
		if String(e.to_id) == from_id and e.bidirectional:
			return e
	
	return null

# Checks if an edge between two nodes is locked
func is_edge_locked(from_id: String, to_id: String) -> bool:
	var edge := get_edge_between_including_locked(from_id, to_id)
	return edge != null and edge.locked

# Checks if an edge between two nodes is hidden
func is_edge_hidden(from_id: String, to_id: String) -> bool:
	var edge := get_edge_between_including_locked(from_id, to_id)
	return edge != null and "hidden" in edge and edge.hidden


# Locks an edge between two nodes, preventing travel along that route.
# Returns true if the edge was found and locked, false otherwise.
# NOTE: This modifies the graph, so use an instanced graph for runtime changes.
func lock_edge(from_id: String, to_id: String) -> bool:
	var edge := get_edge_between_including_locked(from_id, to_id)
	if edge == null:
		push_warning("Cannot lock edge: No edge found between %s and %s" % [from_id, to_id])
		return false
	
	if edge.locked:
		return true  # Already locked
	
	edge.locked = true
	_build_internal_indices()  # Rebuild indices to update neighbors list
	return true


# Unlocks an edge between two nodes, allowing travel along that route.
# Returns true if the edge was found and unlocked, false otherwise.
# NOTE: This modifies the graph, so use an instanced graph for runtime changes.
func unlock_edge(from_id: String, to_id: String) -> bool:
	var edge := get_edge_between_including_locked(from_id, to_id)
	if edge == null:
		push_warning("Cannot unlock edge: No edge found between %s and %s" % [from_id, to_id])
		return false
	
	if not edge.locked:
		return true  # Already unlocked
	
	edge.locked = false
	_build_internal_indices()  # Rebuild indices to update neighbors list
	return true


# Hides an edge between two nodes, marking it as hidden in the UI.
# Returns true if the edge was found and hidden, false otherwise.
# NOTE: This modifies the graph, so use an instanced graph for runtime changes.
func hide_edge(from_id: String, to_id: String) -> bool:
	var edge := get_edge_between_including_locked(from_id, to_id)
	if edge == null:
		push_warning("Cannot hide edge: No edge found between %s and %s" % [from_id, to_id])
		return false
	
	if "hidden" in edge and edge.hidden:
		return true  # Already hidden
	
	if "hidden" in edge:
		edge.hidden = true
	else:
		edge.set("hidden", true)
	
	return true


# Unhides an edge between two nodes, making it visible in the UI.
# Returns true if the edge was found and unhidden, false otherwise.
# NOTE: This modifies the graph, so use an instanced graph for runtime changes.
func unhide_edge(from_id: String, to_id: String) -> bool:
	var edge := get_edge_between_including_locked(from_id, to_id)
	if edge == null:
		push_warning("Cannot unhide edge: No edge found between %s and %s" % [from_id, to_id])
		return false
	
	if "hidden" not in edge or not edge.hidden:
		return true  # Already unhidden
	
	edge.hidden = false
	return true


# Returns the out port label (string) for a given node id and port index.
func get_out_port_label(node_id: String, port_index: int) -> String:
	var node := get_location_node(node_id)
	if node == null:
		return ""
	var labels: Array = node.out_port_labels if node.out_port_labels != null else []
	if port_index >= 0 and port_index < labels.size():
		return String(labels[port_index])
	return ""

# Returns the in port label (string) for a given node id and port index.
func get_in_port_label(node_id: String, port_index: int) -> String:
	var node := get_location_node(node_id)
	if node == null:
		return ""
	var labels: Array = node.in_port_labels if node.in_port_labels != null else []
	if port_index >= 0 and port_index < labels.size():
		return String(labels[port_index])
	return ""


# Checks if a direct path (an edge) exists from a 'from_id' to a 'to_id'.
func has_edge(from_id: String, to_id: String) -> bool:
	return to_id in get_neighbors(from_id)


# Finds the shortest path between two locations using a Breadth-First Search (BFS) algorithm.
# Returns an array of location IDs representing the path, or an empty array if no path is found.
func find_path_bfs(start_id: String, goal_id: String) -> Array[String]:
	if not (nodes.has(start_id) and nodes.has(goal_id)):
		push_warning("Pathfinding failed: Start or goal ID not found in the graph.")
		return []

	if start_id == goal_id:
		return [start_id]

	var queue: Array[String] = [start_id]
	var came_from: Dictionary = {start_id: null}

	while not queue.is_empty():
		var current_id: String = queue.pop_front()

		for neighbor_id in get_neighbors(current_id):
			if not came_from.has(neighbor_id):
				came_from[neighbor_id] = current_id
				if neighbor_id == goal_id:
					return _reconstruct_path(came_from, goal_id)
				queue.append(neighbor_id)
	
	# Return an empty array if the goal was not reached.
	return []

# Given a node id and a connected neighbor id, return the in or out port label that connects them.
func get_port_label_between(node_id: String, neighbor_id: String, include_locked: bool = false, include_hidden: bool = false) -> String:
	var edge: LocationEdgeData = get_edge_between_including_locked(node_id, neighbor_id)
	if edge == null:
		return ""
	
	# Don't return labels for locked connections unless requested
	if edge.locked and not include_locked:
		return ""
	
	# Don't return labels for hidden connections unless requested
	var is_hidden: bool = "hidden" in edge and edge.hidden
	if is_hidden and not include_hidden:
		return ""
	
	# If the edge is outgoing from node_id, return the out port label.
	if String(edge.from_id) == node_id:
		return get_out_port_label(node_id, edge.from_port)
	# If the edge is incoming to node_id and bidirectional, return the in port label.
	elif String(edge.to_id) == node_id and edge.bidirectional:
		return get_in_port_label(node_id, edge.to_port)
	# If we found a bidirectional edge in reverse direction (edge goes from neighbor_id to node_id)
	elif String(edge.from_id) == neighbor_id and String(edge.to_id) == node_id and edge.bidirectional:
		return get_out_port_label(neighbor_id, edge.from_port)
	
	return ""

func get_location_name(id: String) -> String:
	var node := get_location_node(id)
	if node:
		return node.title
	return "Unknown"

## --- Private Helper Methods ---

# Pre-processes the loaded graph data to build fast-lookup dictionaries (indices).
# This makes lookups for nodes and neighbors much more efficient (O(1) on average).
func _build_internal_indices() -> void:
	neighbors.clear()
	nodes.clear()
	if location_graph == null:
		return

	# Index all nodes by their ID.
	for node_data in location_graph.nodes:
		var node := node_data as LocationNodeData
		var node_id := String(node.id)
		nodes[node_id] = node
		var string_array: Array[String] = []
		neighbors[node_id] = string_array
		# Prepare empty edge lists for indexing
		edges_from[node_id] = []
		edges_to[node_id] = []

	# Index all edges to build the neighbor list and edge lookups.
	for edge_data in location_graph.edges:
		var edge := edge_data as LocationEdgeData
		var from_id := String(edge.from_id)
		var to_id := String(edge.to_id)
		
		# Always index edges for fast lookups (regardless of locked status)
		if edges_from.has(from_id):
			edges_from[from_id].append(edge)
		else:
			edges_from[from_id] = [edge]
		if edges_to.has(to_id):
			edges_to[to_id].append(edge)
		else:
			edges_to[to_id] = [edge]
		
		# Only add to neighbors list if not locked and not hidden (for pathfinding and normal navigation)
		var is_hidden: bool = "hidden" in edge and edge.hidden
		if not edge.locked and not is_hidden:
			if neighbors.has(from_id):
				var neighbor_list := neighbors[from_id] as Array[String]
				neighbor_list.append(to_id)
			
			# For bidirectional edges, add the connection in the reverse direction as well.
			if edge.bidirectional and neighbors.has(to_id):
				var to_neighbor_list := neighbors[to_id] as Array[String]
				to_neighbor_list.append(from_id)
		


# Reconstructs the path from the 'came_from' map generated by the BFS algorithm.
# It backtracks from the goal to the start.
func _reconstruct_path(came_from: Dictionary, goal_id: String) -> Array[String]:
	var path: Array[String] = []
	var current_id: Variant = goal_id
	while current_id != null:
		path.push_front(current_id)
		current_id = came_from.get(current_id, null)
	return path
