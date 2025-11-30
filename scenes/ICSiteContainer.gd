extends FoldableContainer
class_name ICSiteContainer

@export var container : VBoxContainer
var has_image_issues: bool = false

signal on_press_export_all(container: ICSiteContainer)

func _on_button_pressed() -> void:
	on_press_export_all.emit(self)


func set_issue_state(active: bool):
	has_image_issues = active
	self_modulate = Color(1, 0.6, 0.6) if active else Color(1, 1, 1)
