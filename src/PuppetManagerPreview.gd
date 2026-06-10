class_name PuppetManager
extends Node

signal puppet_changed(new_puppet: Node)

var active_puppet: Node = null

func _ready() -> void:
	name = "PuppetManager"

func set_active_puppet(puppet: Node) -> void:
	if active_puppet == puppet:
		return

	# 1. Disable old puppet's Input
	if active_puppet:
		_set_input_package_state(active_puppet, false)

	# 2. Enable new puppet
	active_puppet = puppet
	_set_input_package_state(active_puppet, true)

	puppet_changed.emit(active_puppet)

func _set_input_package_state(puppet: Node, enabled: bool) -> void:
	var input_package = puppet.find_child("InputPackage")
	if input_package:
		if not enabled and input_package.has_method("reset_state"):
			input_package.reset_state()
		input_package.process_mode = Node.PROCESS_MODE_ALWAYS if enabled else Node.PROCESS_MODE_DISABLED
	else:
		push_warning("PuppetManager: No InputPackage found on " + puppet.name)
