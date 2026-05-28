extends Node

signal dialogue_opened
signal dialogue_closed

@onready var _dialogue_box: DialogueBox = $CanvasLayer/DialogueBox
@onready var _yarn_bridge: Node = $CanvasLayer/YarnDialogueBridge


func _ready() -> void:
	_dialogue_box.opened.connect(func() -> void: dialogue_opened.emit())
	_dialogue_box.closed.connect(func() -> void: dialogue_closed.emit())


func run_node(yarn_node_id: String) -> void:
	_yarn_bridge.start_dialogue(yarn_node_id)


func show_text(text: String) -> void:
	_dialogue_box.show_text(text)


func show_narration(text: String) -> void:
	_dialogue_box.show_narration(text)


func skip_or_dismiss() -> void:
	_dialogue_box.skip_or_dismiss()
