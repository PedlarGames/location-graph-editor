# Location Graph Editor for Godot 4

A handy Godot 4 plugin for creating, managing, and utilizing node-based location graphs. Useful for narrative-driven games, RPGs, adventure games, or any project that requires a structured map of interconnected locations.

This plugin provides a dedicated editor dock, custom resources for storing graph data, and a runtime helper to make in-game navigation simple and efficient.

## Features

- **Visual Editor**: A dedicated dock using `GraphEdit` to visually design your location maps.
- **Customizable Nodes**: Each location node can be customized with a unique ID, title and tags.
- **Multi-Port Connections**: Create complex locations with multiple entry and exit points, each with its own descriptive label.
- **Smart Connection Rules**: Each port can only have one connection, preventing connection conflicts.
- **Bidirectional Connections**: Easily toggle connections as bidirectional with a single button click. The editor provides clear visual feedback:
  - **Green Lines & Ports**: Indicate a bidirectional connection.
  - **Amber Lines & Ports**: Indicate a one-way connection.
- **Locked and Hidden Connections**: Right-click on connection lines to lock/unlock/hide them. Locked and/or hidden connections provide visual and gameplay restrictions:
  - **Red Ports**: Indicate locked connections in the editor.
  - **Blue Ports**: Indicate hidden connections in the editor.
  - **Purple Ports**: Indicate connections that are both locked and hidden.
  - **Runtime Exclusion**: Locked/hidden connections are excluded from pathfinding and normal navigation.
  - **UI Integration**: Can be displayed as disabled or hidden options in game UI to show inaccessible paths.
- **Connection Context Menu**: Right-click on connection lines to access locking options and other connection-specific actions.
- **Robust Save/Load**: Save your graphs as a custom `LocationGraph` resource (`.tres` file) and load them easily in-game.
- **Smart Start Node Management**: First node automatically becomes start node, with automatic reference updating when nodes are renamed.
- **Optimized Runtime Navigation API**: A performant runtime script (`location_graph_runtime.gd`) with indexed lookups for fast graph traversal, pathfinding, and data retrieval.
- **Example Scene**: Includes a ready-to-use example scene demonstrating how to load a graph and implement player navigation.
