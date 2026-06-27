extends PanelContainer

@onready var bgm_slider: HSlider = %BGMSlider
@onready var sfx_slider: HSlider = %SFXSlider
@onready var ambience_slider: HSlider = %AmbienceSlider
@onready var voice_slider: HSlider = %VoiceSlider

@onready var bgm_value_label: Label = %BGMValueLabel
@onready var sfx_value_label: Label = %SFXValueLabel
@onready var ambience_value_label: Label = %AmbienceValueLabel
@onready var voice_value_label: Label = %VoiceValueLabel

@onready var reset_button: Button = %ResetButton


func _ready() -> void:
	_setup_slider(bgm_slider, AudioSettings.BUS_BGM)
	_setup_slider(sfx_slider, AudioSettings.BUS_SFX)
	_setup_slider(ambience_slider, AudioSettings.BUS_AMBIENCE)
	_setup_slider(voice_slider, AudioSettings.BUS_VOICE)

	bgm_slider.value_changed.connect(_on_bgm_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	ambience_slider.value_changed.connect(_on_ambience_changed)
	voice_slider.value_changed.connect(_on_voice_changed)
	reset_button.pressed.connect(_on_reset_button_pressed)

	_refresh_labels()


func _setup_slider(slider: HSlider, bus_name: StringName) -> void:
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.set_value_no_signal(AudioSettings.get_volume(bus_name))


func _on_bgm_changed(value: float) -> void:
	AudioSettings.set_volume(AudioSettings.BUS_BGM, value)
	_refresh_labels()


func _on_sfx_changed(value: float) -> void:
	AudioSettings.set_volume(AudioSettings.BUS_SFX, value)
	_refresh_labels()


func _on_ambience_changed(value: float) -> void:
	AudioSettings.set_volume(AudioSettings.BUS_AMBIENCE, value)
	_refresh_labels()


func _on_voice_changed(value: float) -> void:
	AudioSettings.set_volume(AudioSettings.BUS_VOICE, value)
	_refresh_labels()


func _on_reset_button_pressed() -> void:
	AudioSettings.reset_to_default()

	bgm_slider.set_value_no_signal(AudioSettings.get_volume(AudioSettings.BUS_BGM))
	sfx_slider.set_value_no_signal(AudioSettings.get_volume(AudioSettings.BUS_SFX))
	ambience_slider.set_value_no_signal(AudioSettings.get_volume(AudioSettings.BUS_AMBIENCE))
	voice_slider.set_value_no_signal(AudioSettings.get_volume(AudioSettings.BUS_VOICE))

	_refresh_labels()


func _refresh_labels() -> void:
	bgm_value_label.text = _to_percent_text(bgm_slider.value)
	sfx_value_label.text = _to_percent_text(sfx_slider.value)
	ambience_value_label.text = _to_percent_text(ambience_slider.value)
	voice_value_label.text = _to_percent_text(voice_slider.value)


func _to_percent_text(value: float) -> String:
	return "%d%%" % int(round(value * 100.0))
