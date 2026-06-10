class_name InventoryGrid
extends Resource

@export var width: int = 6
@export var height: int = 6
@export var items: Array[InventoryItem] = []
@export var locked: bool = false

# Rules configuration flags
@export var restrict_to_1x1: bool = false
@export var enforce_port_limits: bool = false
@export var allowed_port_type: String = ""
@export var is_socket: bool = false

# Bounding boxes for specific logical port zones
const PORT_AREAS = {
	"Drive Shaft": Rect2i(0, 0, 2, 4),
	"Power Bus": Rect2i(2, 0, 3, 3),
	"Undercarriage": Rect2i(5, 0, 1, 4),
	"Silicon Cortex": Rect2i(0, 4, 1, 2)
}

var blocked_cells: Dictionary = {}
var _suppress_signals: bool = false

func _emit_changed() -> void:
	if not _suppress_signals:
		changed.emit()

func _init(p_w: int = 6, p_h: int = 6, p_restrict_1x1: bool = false, p_enforce_ports: bool = false, p_allowed_port: String = "", p_socket: bool = false) -> void:
	width = p_w
	height = p_h
	restrict_to_1x1 = p_restrict_1x1
	enforce_port_limits = p_enforce_ports
	allowed_port_type = p_allowed_port
	is_socket = p_socket
	items = []
	locked = false
	blocked_cells = {}

func can_place_item(item: InventoryItem, cell: Vector2i) -> bool:
	if locked:
		return false
		
	if allowed_port_type != "":
		var item_data = ItemDatabase.get_item(item.id)
		if not item_data or item_data.port_type != allowed_port_type:
			return false

	if is_socket:
		if items.size() > 0:
			if items.size() == 1 and items[0] == item:
				return true
			return false
		return true

	var w = item.get_width()
	var h = item.get_height()
	
	if cell.x < 0 or cell.y < 0 or cell.x + w > width or cell.y + h > height:
		return false
		
	if restrict_to_1x1:
		if w > 1 or h > 1:
			return false
			
	if enforce_port_limits:
		var item_data = ItemDatabase.get_item(item.id)
		if not item_data or item_data.category != ItemDatabase.CAT_MOD:
			return false
			
		var port_name = item_data.port_type
		if not PORT_AREAS.has(port_name):
			return false 
			
		var allowed_rect = PORT_AREAS[port_name]
		var item_rect = Rect2i(cell.x, cell.y, w, h)
		if not _is_rect_inside(item_rect, allowed_rect):
			return false

	for x in range(cell.x, cell.x + w):
		for y in range(cell.y, cell.y + h):
			var current_cell = Vector2i(x, y)
			
			if blocked_cells.get(current_cell, false):
				return false
				
			var other = get_item_at(current_cell)
			if other:
				if w == 1 and h == 1 and other.id == item.id:
					var other_max = other.get_max_stack()
					if other.stack_size + item.stack_size <= other_max:
						continue 
				return false 
				
	return true

func place_item(item: InventoryItem, cell: Vector2i) -> bool:
	if locked:
		return false
		
	if not can_place_item(item, cell):
		return false
		
	var w = item.get_width()
	var h = item.get_height()
	
	if w == 1 and h == 1:
		var other = get_item_at(cell)
		if other and other.id == item.id:
			other.stack_size += item.stack_size
			_emit_changed()
			return true
			
	item.grid_position = cell
	items.append(item)
	_emit_changed()
	return true

func rotate_item(item: InventoryItem) -> bool:
	if locked:
		return false
		
	var item_data = ItemDatabase.get_item(item.id)
	if item_data and item_data.width == item_data.height:
		return false 
		
	if not items.has(item):
		return false
		
	var old_rot = item.rotated
	items.erase(item)
	item.rotated = not item.rotated
	
	if can_place_item(item, item.grid_position):
		items.append(item)
		_emit_changed()
		return true
	else:
		item.rotated = old_rot
		items.append(item)
		return false

func get_item_at(cell: Vector2i) -> InventoryItem:
	for item in items:
		var start_x = item.grid_position.x
		var start_y = item.grid_position.y
		var end_x = start_x + item.get_width()
		var end_y = start_y + item.get_height()
		
		if cell.x >= start_x and cell.x < end_x and cell.y >= start_y and cell.y < end_y:
			return item
	return null

func auto_place(item_id: String, qty: int) -> int:
	if locked:
		return 0
		
	var item_data = ItemDatabase.get_item(item_id)
	if not item_data:
		return 0
		
	var max_stack = item_data.max_stack if item_data.max_stack > 0 else 1
			
	var remaining = qty
	var changed_any = false
	
	var prev_suppress = _suppress_signals
	_suppress_signals = true
	
	for item in items:
		if item.id == item_id and item.stack_size < max_stack:
			var space = max_stack - item.stack_size
			var add_qty = min(remaining, space)
			item.stack_size += add_qty
			remaining -= add_qty
			changed_any = true
			if remaining <= 0:
				break
				
	if remaining > 0:
		while remaining > 0:
			var place_qty = min(remaining, max_stack)
			var temp_item = InventoryItem.new(item_id, Vector2i.ZERO, false, place_qty)
			var placed = false
			
			for y in range(height):
				for x in range(width):
					var cell = Vector2i(x, y)
					if can_place_item(temp_item, cell):
						if place_item(temp_item, cell):
							remaining -= place_qty
							placed = true
							changed_any = true
							break
				if placed:
					break
					
			if not placed:
				break
				
	_suppress_signals = prev_suppress
	if changed_any:
		_emit_changed()
			
	return qty - remaining

func _is_rect_inside(inner: Rect2i, outer: Rect2i) -> bool:
	return inner.position.x >= outer.position.x and \
		inner.position.y >= outer.position.y and \
		inner.position.x + inner.size.x <= outer.position.x + outer.size.x and \
		inner.position.y + inner.size.y <= outer.position.y + outer.size.y
