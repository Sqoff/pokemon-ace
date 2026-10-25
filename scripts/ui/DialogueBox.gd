class_name DialogueBox
extends Control

@onready var panel: Panel = $Panel
@onready var speaker_label: Label = $Panel/SpeakerLabel
@onready var text_label: Label = $Panel/TextLabel
@onready var prompt_label: Label = $Panel/PromptLabel


func set_dialogue(speaker: String, text: String, has_next: bool = true) -> void:
	if speaker_label:
		speaker_label.text = speaker
		speaker_label.visible = speaker != ""
	if text_label:
		text_label.text = text
	if prompt_label:
		prompt_label.text = "▼" if has_next else "■"
