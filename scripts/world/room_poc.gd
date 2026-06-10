extends BaseRoom

const _PARTY_RESOURCES: Array[String] = [
	"res://characters/iris.tres",
	"res://characters/karim.tres",
	"res://characters/margot.tres",
]


func _ready() -> void:
	_seed_full_party()
	super._ready()


func _seed_full_party() -> void:
	for res_path: String in _PARTY_RESOURCES:
		var combatant: Combatant = Combatant.from_definition(load(res_path) as CombatantDefinition)
		if not PartyManager.has_member(combatant.character_name):
			PartyManager.add_member(combatant)
