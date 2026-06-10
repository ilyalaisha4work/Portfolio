class_name VectorStatsManager
extends Node

signal stats_recalculated()
signal sidecar_grid_added(key: String, grid: InventoryGrid)
signal sidecar_grid_removed(key: String)

@export var cargo_main: InventoryGrid
@export var hardware_mods: InventoryGrid
@export var hull_grids: Array[InventoryGrid] = []
@export var hardpoint_grids: Array[InventoryGrid] = []

var sidecar_grids: Dictionary = {}
var base_stats: VectorStats
var active_stats: VectorStats
var speeder_node: RigidBody3D

func _ready() -> void:
	PlayerState.active_speeder_stats = self
	
	cargo_main = PlayerState.cargo_grid
	hardware_mods = InventoryGrid.new(6, 6, false, true) # Enforces Port Limits
	
	hull_grids = [
		InventoryGrid.new(1, 1, false, false, "Hull"),
		InventoryGrid.new(1, 1, false, false, "Hull")
	]
	
	hardpoint_grids = [
		InventoryGrid.new(1, 1, false, false, "Hardpoints"),
		InventoryGrid.new(1, 1, false, false, "Hardpoints")
	]
	
	# Bind grid updates to recalculation logic
	var grids = [cargo_main, hardware_mods] + hull_grids + hardpoint_grids
	for grid in grids:
		grid.changed.connect(recalculate_stats)

func recalculate_stats() -> void:
	if not base_stats:
		base_stats = load("res://Actors/Vector/Data/DefaultVectorStats.tres")
			
	active_stats = base_stats.duplicate()
	var active_sidecar_keys: Array[String] = []
	
	var installed_mods: Array[InventoryItem] = hardware_mods.get_all_items()
	for grid in hull_grids + hardpoint_grids:
		if grid.get_all_items().size() > 0:
			installed_mods.append(grid.get_all_items()[0])
	
	for item in installed_mods:
		var item_data = ItemDatabase.get_item(item.id)
		if not item_data or not item_data.stat_modifiers is Dictionary: continue
			
		var mods = item_data.stat_modifiers
		
		if mods.get("adds_sidecar_grid", false):
			var key = "mod_" + str(item.grid_position.x) + "_" + str(item.grid_position.y)
			active_sidecar_keys.append(key)
			
		for prop in mods:
			if prop in active_stats:
				var current_val = active_stats.get(prop)
				if typeof(current_val) == TYPE_INT or typeof(current_val) == TYPE_FLOAT:
					active_stats.set(prop, current_val + mods[prop])
					
	# Instantiate dynamically added sub-grids
	for key in active_sidecar_keys:
		if not sidecar_grids.has(key):
			var new_grid = InventoryGrid.new(2, 3, false, false)
			sidecar_grids[key] = new_grid
			new_grid.changed.connect(recalculate_stats)
			sidecar_grid_added.emit(key, new_grid)
			
	# Cleanup removed sidecars securely
	var keys_to_remove: Array[String] = []
	for key in sidecar_grids:
		if not key in active_sidecar_keys:
			keys_to_remove.append(key)
			
	for key in keys_to_remove:
		remove_sidecar_grid(key)
		
	if speeder_node and speeder_node.has_method("apply_stats_manager_recalculation"):
		speeder_node.apply_stats_manager_recalculation()
		
	stats_recalculated.emit()

func remove_sidecar_grid(key: String) -> void:
	if sidecar_grids.has(key):
		var grid = sidecar_grids[key]
		var items_to_move = grid.get_all_items().duplicate()
		for item in items_to_move:
			PlayerState.home_stash_grid.auto_place(item.id, item.stack_size)
			grid.remove_item(item)
		sidecar_grids.erase(key)
		sidecar_grid_removed.emit(key)
