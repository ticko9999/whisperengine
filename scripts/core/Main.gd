extends Node

func _ready() -> void:
	print("=== 城中风声 后台框架已启动 ===")
	SimulationManager.start_new_run()
	SimulationManager.inject_demo_event_star_scandal()
