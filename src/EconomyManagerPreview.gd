extends Node

const SUCCESS = "SUCCESS"
const INSUFFICIENT_FUNDS = "INSUFFICIENT_FUNDS"
const OUT_OF_STOCK = "OUT_OF_STOCK"
const INSUFFICIENT_SPACE = "INSUFFICIENT_SPACE"

func can_afford(cost: Dictionary) -> bool:
	if PlayerState.credits < cost.get("credits", 0):
		return false
	if PlayerState.barter_points < cost.get("barter_points", 0):
		return false
	var req_items = cost.get("items", {})
	for item_id in req_items:
		if PlayerState.get_item_count(item_id) < req_items[item_id]:
			return false
	return true

func execute_transaction(cost: Dictionary, gains: Dictionary, target_inventory: String = "pockets") -> void:
	if cost.get("credits", 0) > 0:
		PlayerState.remove_credits(cost["credits"])
		
	var req_items = cost.get("items", {})
	for item_id in req_items:
		PlayerState.remove_item(item_id, req_items[item_id])
		
	var gain_items = gains.get("items", {})
	for item_id in gain_items:
		PlayerState.add_item_to_container(item_id, gain_items[item_id], target_inventory)

func buy_from_mason(item_id: String, vendor_stock: Dictionary, target_inventory: String = "pockets") -> String:
	var item = ItemDatabase.get_item(item_id)
	
	if vendor_stock.get(item_id, 0) <= 0:
		return OUT_OF_STOCK
		
	if not PlayerState.can_accept_item(item_id, 1, target_inventory):
		return INSUFFICIENT_SPACE
		
	var cost = { "credits": item.base_value }
	if not can_afford(cost):
		return INSUFFICIENT_FUNDS
		
	var gains = { "items": { item_id: 1 } }
	execute_transaction(cost, gains, target_inventory)
	
	vendor_stock[item_id] = vendor_stock[item_id] - 1
	return SUCCESS

func apply_fine(amount: int) -> void:
	if amount <= 0: return
	
	var shortfall = PlayerState.remove_credits(amount)
	if shortfall > 0:
		# Convert debt into reputation/resonance decay
		var trust_penalty = max(1, int(shortfall / 10.0))
		var res_penalty = max(1, int(shortfall / 10.0))
			
		PlayerState.remove_trust(trust_penalty)
		PlayerState.remove_resonance(res_penalty)
