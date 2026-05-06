extends Node

@onready var _dialogue_box: DialogueBox = $"../DialogueBox"
@onready var _runner: Node = $"../DialogueRunner"


func run_line_async(line: Dictionary) -> void:
	var speaker := _get_speaker(line)
	var text: String = line.get("text", {}).get("text_without_character_name", "")
	_dialogue_box.show_line(speaker, text)
	await _dialogue_box.line_advanced


func run_options_async(options: Array, set_option: Callable) -> void:
	var texts: Array = []
	for opt in options:
		texts.append(opt.get("line", {}).get("text", {}).get("text_without_character_name", ""))
	_dialogue_box.show_choices(texts)
	var idx: int = await _dialogue_box.option_selected
	set_option.call(idx)


func on_dialogue_complete_async() -> void:
	_dialogue_box.dismiss()


func start_dialogue(node_id: String) -> void:
	_runner.start_dialogue_forget(node_id)


func _get_speaker(line: Dictionary) -> String:
	for attr in line.get("text", {}).get("attributes", []):
		if attr.get("name") == "character":
			return str(attr.get("properties", {}).get("name", ""))
	return ""
