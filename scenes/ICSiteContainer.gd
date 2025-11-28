extends FoldableContainer
class_name ICSiteContainer

@export var container : VBoxContainer

signal on_press_export_all(container: ICSiteContainer)

func _on_button_pressed() -> void:
	on_press_export_all.emit(self)
