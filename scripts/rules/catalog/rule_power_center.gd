class_name RulePowerCenter
extends RuleCard

func _init() -> void:
	id = "power_center"
	name = "Casas de Poder"
	description = "Suas pecas paradas nas 4 casas centrais do tabuleiro nao podem ser capturadas por pecas inimigas comuns."
	category = Category.BOARD
	scope = Scope.PLAYER_ONLY
	priority = 40
