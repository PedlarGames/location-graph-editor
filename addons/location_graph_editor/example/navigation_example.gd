# This script provides a comprehensive example of how to navigate a LocationGraph.
# It demonstrates loading graphs, navigation, pathfinding, and dynamic edge management
# (locking/unlocking doors and hiding/revealing secret passages).
extends Control

# Preload the required custom resource types for type safety and efficiency.
const LocationGraph = preload("res://addons/location_graph_editor/resources/location_graph.gd")
const LocationNodeData = preload("res://addons/location_graph_editor/resources/location_node.gd")
const LocationEdgeData = preload("res://addons/location_graph_editor/resources/location_edge.gd")
const LocationGraphRuntime = preload("res://addons/location_graph_editor/runtime/location_graph_runtime.gd")

# --- UI Elements ---
# We use @onready to ensure the nodes are available when we access them.
@onready var load_graph_button: Button = %LoadGraphDataButton
@onready var loaded_graph_name_label: Label = %LoadedGraphNameLabel
@onready var current_location_label: Label = %CurrentLocationValueLabel
@onready var exits_vbox: VBoxContainer = %ExitsContainer
@onready var return_to_start_button: Button = %ReturnButton
@onready var all_locations_vbox: VBoxContainer = %AllLocationsContainer
@onready var path_from_location_input: LineEdit = %PathFromLocationInput
@onready var path_to_location_input: LineEdit = %PathToLocationInput
@onready var find_path_button: Button = %FindPathButton
@onready var route_list_label: Label = %RouteListLabel
@onready var locked_edges_vbox: VBoxContainer = %LockedEdgesContainer
@onready var hidden_edges_vbox: VBoxContainer = %HiddenEdgesContainer

# --- Navigation State ---
# The loaded LocationGraph resource (instanced for runtime modifications).
var location_graph: LocationGraph
var runtime: LocationGraphRuntime = LocationGraphRuntime.new()
# The ID of the location the player is currently at.
var current_location_id: String = ""

# Track initially locked and hidden edges (as [from_id, to_id] pairs)
var initially_locked_edges: Array = []
var initially_hidden_edges: Array = []


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Connect UI signals to their respective handler functions.
	load_graph_button.pressed.connect(_on_load_graph_button_pressed)
	return_to_start_button.pressed.connect(_on_return_to_start_button_pressed)
	find_path_button.pressed.connect(_on_find_path_button_pressed)
	
	# Initialize the UI with default values.
	_update_ui()


# --- Signal Handlers ---

# Called when the "Load Graph" button is pressed.
# Opens a FileDialog to allow the user to select a LocationGraph resource file (*.tres).
func _on_load_graph_button_pressed() -> void:
	var file_dialog := FileDialog.new()
	add_child(file_dialog)
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_RESOURCES
	file_dialog.add_filter("*.tres ; LocationGraph")
	file_dialog.title = "Load Location Graph"
	# Connect to the file_selected signal and load the graph when a file is chosen.
	file_dialog.file_selected.connect(func(path: String):
		_load_graph_from_path(path)
	)
	# Show the dialog.
	file_dialog.popup_centered_ratio(0.6)


# Called when the "Return to Start" button is pressed.
# Resets the current location to the graph's defined start node.
func _on_return_to_start_button_pressed() -> void:
	if location_graph == null:
		return

	# Determine the start node ID using the runtime helper.
	if runtime and runtime.location_graph == location_graph:
		current_location_id = runtime.get_start_or_first_id()
	else:
		runtime.set_graph(location_graph)
		current_location_id = runtime.get_start_or_first_id()
	_update_ui()


# --- Private Logic ---

# Loads a LocationGraph resource from the given file path.
func _load_graph_from_path(path: String) -> void:
	var resource := ResourceLoader.load(path)
	if resource == null or not (resource is LocationGraph):
		loaded_graph_name_label.text = "Failed to load graph."
		return
	
	# Create an instance so we can modify edges at runtime
	location_graph = (resource as LocationGraph).create_instance()
	runtime.set_graph(location_graph)
	loaded_graph_name_label.text = String(path.get_file())
	
	# Track initially locked and hidden edges
	_track_initial_edge_states()
	
	# Set the current location to the graph's start node or fallback to first via runtime.
	current_location_id = runtime.get_start_or_first_id()
			
	# Refresh the UI to reflect the newly loaded graph.
	_update_ui()


# Updates all UI elements to reflect the current navigation state.
func _update_ui() -> void:
	_update_current_location_label()
	_rebuild_exit_buttons()
	_rebuild_all_locations_list()
	_rebuild_locked_edges_list()
	_rebuild_hidden_edges_list()


# Updates the label showing the current location's ID and title.
func _update_current_location_label() -> void:
	if location_graph == null or current_location_id == "":
		current_location_label.text = "No location set"
		return
		
	var current_node_data := runtime.get_location_node(current_location_id)
	if current_node_data:
		# Display both the ID and the custom title for clarity.
		current_location_label.text = "%s (%s)" % [String(current_node_data.id), String(current_node_data.title)]
	else:
		# If the node data can't be found, just show the ID.
		current_location_label.text = current_location_id


# Clears and rebuilds the list of buttons for navigating to adjacent locations.
func _rebuild_exit_buttons() -> void:
	# First, remove any previously generated exit buttons.
	# We iterate through the children of the container and free them.
	for child in exits_vbox.get_children():
		# We only want to remove the dynamically generated exit buttons.
		if child is Button and child != return_to_start_button and String(child.name).begins_with("ExitButton_"):
			exits_vbox.remove_child(child)
			child.queue_free()

	if location_graph == null or current_location_id == "":
		return

	var button_index: int = 0
	
	# --- Create buttons for outgoing edges ---
	for edge in runtime.get_edges_from(current_location_id):
		var destination_node_id := String(edge.to_id)
		
		# Check if edge is locked or hidden
		var is_locked: bool = edge.locked
		var is_hidden: bool = edge.hidden if "hidden" in edge else false
		
		# Determine the button's text. Use the port label if available, otherwise generate a default.
		var button_text := runtime.get_out_port_label(current_location_id, int(edge.from_port))
		if button_text.strip_edges() == "":
			button_text = "To %s" % runtime.get_location_name(destination_node_id)
		
		# Add status indicators
		if is_locked and is_hidden:
			button_text = "[LOCKED & HIDDEN] " + button_text
		elif is_locked:
			button_text = "[LOCKED] " + button_text
		elif is_hidden:
			button_text = "[HIDDEN] " + button_text

		# Create and configure the button.
		var exit_button := Button.new()
		exit_button.name = "ExitButton_%d_%s" % [button_index, destination_node_id]
		exit_button.text = button_text
		exit_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		# Disable locked or hidden buttons
		exit_button.disabled = is_locked or is_hidden
		
		exit_button.pressed.connect(func():
			current_location_id = destination_node_id
			_update_ui()
		)
		
		# Insert the new button before the "Return to Start" button for a consistent layout.
		exits_vbox.add_child(exit_button)
		var return_button_index: int = return_to_start_button.get_index()
		if return_button_index >= 0:
			exits_vbox.move_child(exit_button, return_button_index)
			
		button_index += 1

	# --- Create buttons for incoming bidirectional edges (allowing reverse travel) ---
	# Use edges lookup for incoming bidirectional edges by scanning all edges and
	# selecting those that are bidirectional and target the current location.
	for edge in runtime.get_edges_to(current_location_id):
		# edge is a LocationEdgeData that targets current_location_id
		if not edge.bidirectional:
			continue
			
		var source_node_id := String(edge.from_id)
		
		# Check if edge is locked or hidden
		var is_locked: bool = edge.locked
		var is_hidden: bool = edge.hidden if "hidden" in edge else false
		
		var reverse_navigation_label := runtime.get_in_port_label(current_location_id, int(edge.to_port))
		if reverse_navigation_label.strip_edges() == "":
			reverse_navigation_label = "From %s" % runtime.get_location_name(source_node_id)
		
		# Add status indicators
		if is_locked and is_hidden:
			reverse_navigation_label = "[LOCKED & HIDDEN] " + reverse_navigation_label
		elif is_locked:
			reverse_navigation_label = "[LOCKED] " + reverse_navigation_label
		elif is_hidden:
			reverse_navigation_label = "[HIDDEN] " + reverse_navigation_label
			
		var reverse_exit_button := Button.new()
		reverse_exit_button.name = "ExitButton_%d_%s_rev" % [button_index, source_node_id]
		reverse_exit_button.text = reverse_navigation_label
		reverse_exit_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		reverse_exit_button.disabled = is_locked or is_hidden
		
		reverse_exit_button.pressed.connect(func():
			current_location_id = source_node_id
			_update_ui()
		)
		exits_vbox.add_child(reverse_exit_button)
		var return_button_index: int = return_to_start_button.get_index()
		if return_button_index >= 0:
			exits_vbox.move_child(reverse_exit_button, return_button_index)
		button_index += 1

# Rebuilds the list of all locations in the graph for reference.
func _rebuild_all_locations_list() -> void:
	# Clear existing entries.
	for child in all_locations_vbox.get_children():
		if child is Label and String(child.name).begins_with("LocationLabel_"):
			all_locations_vbox.remove_child(child)
			child.queue_free()
	if location_graph == null:
		return
	# Create a label for each location node in the graph.
	var label_index: int = 0
	for node in location_graph.nodes:
		var location_node: LocationNodeData = node
		var location_label := Label.new()
		location_label.name = "LocationLabel_%d_%s" % [label_index, String(location_node.id)]
		location_label.text = "%s (%s)" % [String(location_node.id), String(location_node.title)]
		location_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		all_locations_vbox.add_child(location_label)
		label_index += 1

# Called when the "Find Path" button is pressed.
# Finds and displays a path between two specified locations.
func _on_find_path_button_pressed() -> void:
	_update_pathfinding_display()


# Updates the pathfinding display with current path
func _update_pathfinding_display() -> void:
	route_list_label.text = ""
	if location_graph == null:
		return
	var from_id := path_from_location_input.text.strip_edges()
	var to_id := path_to_location_input.text.strip_edges()
	
	# Only update if there's an active pathfinding query
	if from_id == "" or to_id == "":
		return
	
	if runtime.get_location_node(from_id) == null:
		route_list_label.text = "From location ID not found: %s" % from_id
		return
	if runtime.get_location_node(to_id) == null:
		route_list_label.text = "To location ID not found: %s" % to_id
		return
	
	# Use weighted pathfinding to find the optimal path
	var result: Dictionary = runtime.find_path_weighted_with_cost(from_id, to_id)
	var path: Array = result.path
	var total_cost: float = result.cost
	
	if path.size() == 0:
		route_list_label.text = "No path found from %s to %s. (Check for locked/hidden edges)" % [from_id, to_id]
		return
	
	# Display the found path with cost
	var cost_display: String
	if is_equal_approx(total_cost, round(total_cost)):
		cost_display = "%d" % int(round(total_cost))
	else:
		cost_display = "%.2f" % total_cost
	
	route_list_label.text = "Path: " + " -> ".join(path) + "\nTotal cost: " + cost_display
	route_list_label.show()


# --- Helper Functions ---

# Tracks which edges are initially locked or hidden when the graph is loaded
func _track_initial_edge_states() -> void:
	initially_locked_edges.clear()
	initially_hidden_edges.clear()
	
	if location_graph == null:
		return
	
	for node in location_graph.nodes:
		var node_id := String(node.id)
		for edge in runtime.get_edges_from(node_id):
			var edge_pair := [String(edge.from_id), String(edge.to_id)]
			
			if edge.locked:
				initially_locked_edges.append(edge_pair)
			
			var is_hidden: bool = "hidden" in edge and edge.hidden
			if is_hidden:
				initially_hidden_edges.append(edge_pair)


# Rebuilds the list of locked edges with unlock buttons.
func _rebuild_locked_edges_list() -> void:
	# Clear existing entries.
	for child in locked_edges_vbox.get_children():
		if String(child.name).begins_with("LockedEdge_"):
			locked_edges_vbox.remove_child(child)
			child.queue_free()
	
	if location_graph == null:
		return
	
	var locked_index: int = 0
	
	# Only show edges that were initially locked
	for edge_pair in initially_locked_edges:
		var from_id: String = edge_pair[0]
		var to_id: String = edge_pair[1]
		
		var edge := runtime.get_edge_between_including_locked(from_id, to_id)
		if edge == null:
			continue
		
		var from_name := runtime.get_location_name(from_id)
		var to_name := runtime.get_location_name(to_id)
		var label: String = edge.label if edge.label != "" else runtime.get_out_port_label(from_id, edge.from_port)
		
		# Create a container for the edge info and button
		var hbox := HBoxContainer.new()
		hbox.name = "LockedEdge_%d" % locked_index
		
		var edge_label := Label.new()
		var edge_text := "%s → %s" % [from_name, to_name]
		if label != "":
			edge_text += " (%s)" % label
		edge_label.text = edge_text
		edge_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(edge_label)
		
		if edge.locked:
			# Add unlock button for locked edges
			var unlock_button := Button.new()
			unlock_button.text = "Unlock"
			unlock_button.pressed.connect(_create_unlock_callback(from_id, to_id))
			hbox.add_child(unlock_button)
		else:
			# Show as unlocked (grayed out with lock button)
			edge_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
			var lock_button := Button.new()
			lock_button.text = "Lock"
			lock_button.pressed.connect(_create_lock_callback(from_id, to_id))
			hbox.add_child(lock_button)
		
		locked_edges_vbox.add_child(hbox)
		locked_index += 1
	
	# Show message if no initially locked edges
	if initially_locked_edges.size() == 0:
		var no_edges_label := Label.new()
		no_edges_label.name = "LockedEdge_None"
		no_edges_label.text = "No locked edges in graph"
		no_edges_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		locked_edges_vbox.add_child(no_edges_label)


# Rebuilds the list of hidden edges with reveal buttons.
func _rebuild_hidden_edges_list() -> void:
	# Clear existing entries.
	for child in hidden_edges_vbox.get_children():
		if String(child.name).begins_with("HiddenEdge_"):
			hidden_edges_vbox.remove_child(child)
			child.queue_free()
	
	if location_graph == null:
		return
	
	var hidden_index: int = 0
	
	# Only show edges that were initially hidden
	for edge_pair in initially_hidden_edges:
		var from_id: String = edge_pair[0]
		var to_id: String = edge_pair[1]
		
		var edge := runtime.get_edge_between_including_locked(from_id, to_id)
		if edge == null:
			continue
		
		var is_hidden: bool = "hidden" in edge and edge.hidden
		var from_name := runtime.get_location_name(from_id)
		var to_name := runtime.get_location_name(to_id)
		var label: String = edge.label if edge.label != "" else runtime.get_out_port_label(from_id, edge.from_port)
		
		# Create a container for the edge info and button
		var hbox := HBoxContainer.new()
		hbox.name = "HiddenEdge_%d" % hidden_index
		
		var edge_label := Label.new()
		var edge_text := "%s → %s" % [from_name, to_name]
		if label != "":
			edge_text += " (%s)" % label
		edge_label.text = edge_text
		edge_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(edge_label)
		
		if is_hidden:
			# Add reveal button for hidden edges
			var reveal_button := Button.new()
			reveal_button.text = "Reveal"
			reveal_button.pressed.connect(_create_unhide_callback(from_id, to_id))
			hbox.add_child(reveal_button)
		else:
			# Show as revealed (grayed out with hide button)
			edge_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
			var hide_button := Button.new()
			hide_button.text = "Hide"
			hide_button.pressed.connect(_create_hide_callback(from_id, to_id))
			hbox.add_child(hide_button)
		
		hidden_edges_vbox.add_child(hbox)
		hidden_index += 1
	
	# Show message if no initially hidden edges
	if initially_hidden_edges.size() == 0:
		var no_edges_label := Label.new()
		no_edges_label.name = "HiddenEdge_None"
		no_edges_label.text = "No hidden edges in graph"
		no_edges_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		hidden_edges_vbox.add_child(no_edges_label)


# Creates a callback for unlocking an edge (needed for proper closure in loops)
func _create_unlock_callback(from_id: String, to_id: String) -> Callable:
	return func():
		if runtime.unlock_edge(from_id, to_id):
			print("Unlocked edge: %s → %s" % [from_id, to_id])
			_update_ui()
			# Delay pathfinding update to next frame to ensure UI is updated
			await get_tree().process_frame
			_update_pathfinding_display()


# Creates a callback for locking an edge (needed for proper closure in loops)
func _create_lock_callback(from_id: String, to_id: String) -> Callable:
	return func():
		if runtime.lock_edge(from_id, to_id):
			print("Locked edge: %s → %s" % [from_id, to_id])
			_update_ui()
			# Delay pathfinding update to next frame to ensure UI is updated
			await get_tree().process_frame
			_update_pathfinding_display()


# Creates a callback for revealing a hidden edge (needed for proper closure in loops)
func _create_unhide_callback(from_id: String, to_id: String) -> Callable:
	return func():
		if runtime.unhide_edge(from_id, to_id):
			print("Revealed edge: %s → %s" % [from_id, to_id])
			_update_ui()
			# Delay pathfinding update to next frame to ensure UI is updated
			await get_tree().process_frame
			_update_pathfinding_display()


# Creates a callback for hiding an edge (needed for proper closure in loops)
func _create_hide_callback(from_id: String, to_id: String) -> Callable:
	return func():
		if runtime.hide_edge(from_id, to_id):
			print("Hidden edge: %s → %s" % [from_id, to_id])
			_update_ui()
			# Delay pathfinding update to next frame to ensure UI is updated
			await get_tree().process_frame
			_update_pathfinding_display()
