class_name DebugRuleConsole
extends RefCounted

# Console de teclas de debug (leis + atalhos de fim de duelo), extraído de
# main.gd. Propositalmente NÃO conhece Board, RulePipeline, DuelBase etc.
# diretamente — ele só chama uma API pública explícita no "host" (hoje,
# main.gd). Isso significa que, quando o fluxo de turno for extraído para
# um DuelTurnController próprio, esta classe não precisa mudar: basta o
# novo dono implementar os mesmos métodos debug_*.
#
# Host precisa implementar:
#   debug_force_win() -> void
#   debug_force_loss() -> void
#   debug_force_sudden_death() -> void
#   debug_restart_run() -> void
#   debug_toggle_rule(rule_id: String, make_rule: Callable) -> void

var _host: Object

func _init(host: Object) -> void:
	_host = host

func handle_key(keycode: int) -> bool:
	match keycode:
		KEY_W:
			_host.debug_force_win()
			return true

		KEY_E:
			_host.debug_force_loss()
			return true

		KEY_Q:
			_host.debug_force_sudden_death()
			return true

		KEY_R:
			_host.debug_restart_run()
			return true

		KEY_1:
			_host.debug_toggle_rule("reverse_movement", func(): return RuleReverseMovement.new())
			return true

		KEY_2:
			_host.debug_toggle_rule("optional_capture", func(): return RuleOptionalCapture.new())
			return true

		KEY_3:
			_host.debug_toggle_rule("early_promotion", func(): return RuleEarlyPromotion.new())
			return true

		KEY_4:
			_host.debug_toggle_rule("ascension_law", func(): return RuleAscension.new())
			return true

		KEY_5:
			_host.debug_toggle_rule("impossible_tie_law", func(): return RuleImpossibleTie.new())
			return true

		KEY_6:
			_host.debug_toggle_rule("ally_hop", func(): return RuleAllyHop.new())
			return true

	return false
