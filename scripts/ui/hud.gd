extends CanvasLayer

# Bar colors per the design spec
const COLOR_HP_FULL  := Color(0.25, 0.85, 0.35)   # green
const COLOR_HP_LOW   := Color(0.85, 0.20, 0.20)   # red  (lerped as HP drops)
const COLOR_PP       := Color(0.55, 0.20, 0.85)   # purple
const COLOR_ATB      := Color(1.00, 1.00, 1.00)   # white
const COLOR_LIMIT_BUREAU     := Color(0.55, 0.55, 0.55)   # gray — metered
const COLOR_LIMIT_JAILBROKEN := Color(1.00, 0.80, 0.10)   # gold  — uncapped

# One entry per party slot (up to 4)
@export var party_panels: Array[Control] = []

var _party: Array[Combatant] = []


func bind_party(party: Array[Combatant]) -> void:
	_party = party


func _process(_delta: float) -> void:
	for i in mini(_party.size(), party_panels.size()):
		_update_panel(party_panels[i], _party[i])


func _update_panel(panel: Control, combatant: Combatant) -> void:
	var hp_bar: ProgressBar  = panel.get_node("HPBar")
	var pp_bar: ProgressBar  = panel.get_node("PPBar")
	var atb_bar: ProgressBar = panel.get_node("ATBBar")
	var limit_bar: ProgressBar = panel.get_node("LimitBar")
	var name_label: Label    = panel.get_node("NameLabel")

	name_label.text = combatant.character_name

	# HP — lerp color green → red as HP falls
	hp_bar.value = combatant.hp_ratio() * 100.0
	hp_bar.modulate = COLOR_HP_FULL.lerp(COLOR_HP_LOW, 1.0 - combatant.hp_ratio())

	# PP — always purple
	pp_bar.value = combatant.pp_ratio() * 100.0
	pp_bar.modulate = COLOR_PP

	# ATB — white fill
	atb_bar.value = combatant.atb_ratio() * 100.0
	atb_bar.modulate = COLOR_ATB

	# Limit — gray if Bureau, gold if Jailbroken; max value reflects the cap
	limit_bar.max_value = combatant.limit_cap()
	limit_bar.value = combatant.limit_gauge
	match combatant.sigil_type:
		Combatant.SigilType.BUREAU:
			limit_bar.modulate = COLOR_LIMIT_BUREAU
		Combatant.SigilType.JAILBROKEN:
			limit_bar.modulate = COLOR_LIMIT_JAILBROKEN
		_:
			limit_bar.modulate = COLOR_ATB

	# Pulse name label when ATB is full and awaiting input
	name_label.modulate.a = 1.0 if not combatant.atb_full() else \
		(0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006))
