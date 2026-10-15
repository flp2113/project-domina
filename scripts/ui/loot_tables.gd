class_name LootTables

# =========================================================
# BANCO DE DADOS CENTRAL (Adicione novas cartas/regras AQUI)
# =========================================================

static func get_all_rules() -> Array[RuleCard]:
	var rules: Array[RuleCard] = [
		RuleReverseMovement.new(),
		RuleOptionalCapture.new(),
		RuleEarlyPromotion.new(),
		RuleCarnage.new(),
		RuleRevenge.new(),
		RuleAllyHop.new(),
		RuleSoulMirror.new(),
		RuleSecondMove.new(),
		RulePowerCenter.new(),
		RuleBlood.new(),
		RuleAdvance.new(),
		RuleShield.new(),
		RuleShockwave.new(),
		RuleSacredZone.new(),
		RuleVengefulFury.new(),
		RuleAscension.new(),
		RuleImpossibleTie.new(),
		RuleWeight.new(),
		RuleMourning.new(),
		RuleEcho.new(),
		RuleFaithfulCoin.new()
	]
	return rules

# Leis EXCLUSIVAS de inimigo (nunca vendidas nem sorteadas pro jogador): ficam
# fora de get_all_rules() de propósito. Um Duelo Forte recebe uma delas.
static func get_enemy_unique_rules() -> Array[RuleCard]:
	var rules: Array[RuleCard] = [
		RuleRoyalGuard.new(),
		RuleCounterAttack.new(),
		RulePoison.new()
	]
	return rules

static func get_all_action_cards() -> Array[ActionCard]:
	var cards: Array[ActionCard] = [
		CardExtraTurn.new(),
		CardCoronation.new(),
		CardRetreat.new(),
		CardSacrifice.new(),
		CardRecruit.new(),
		CardVision.new(),
		CardRetaliation.new(),
		CardRebuild.new(),
		CardCorrupt.new(),
		CardFortify.new(),
		CardHeroicAdvance.new(),
		CardProphecy.new(),
		CardGrandReinforcement.new(),
		CardCoinOfDestiny.new(),
		CardLuckyDuel.new(),
		CardSecondChance.new(),
		CardRebellion.new(),
		CardPause.new(),
		CardRecycle.new(),
		CardRestock.new(),
		CardLoadedCoin.new(),
		CardDemote.new(),
		CardHeir.new(),
		CardFlyingQueen.new(),
		CardGuillotine.new(),
		CardAmbush.new(),
		CardScorchedEarth.new()
	]
	return cards

# =========================================================
# MÉTODOS DE SORTEIO PONDERADO
# =========================================================

static func get_random_rules(count: int, exclude_ids: Array[String] = []) -> Array[RuleCard]:
	var pool = get_all_rules().filter(func(r: RuleCard): return not exclude_ids.has(r.id))
	return pick_weighted_rules(pool, count)

# Leis seguras pra conceder à IA (inimigo). Só as que decidem seu efeito
# através de hooks filtrados por time no RulePipeline (modify_move_directions,
# modify_step_distance, evaluate_mandatory_capture, check_custom_promotion,
# try_prevent_capture) — as demais (Carnificina, Vingança, Espelho de Almas,
# Casas de Poder, Sangue, Onda de Choque, Fúria Vingativa) checam
# "attacker.owner_team == board.human_team_color" direto dentro do próprio
# efeito (on_game_event) ou via id hardcoded em Board, então ficariam
# inertes ou incorretas (beneficiando o jogador por engano) se concedidas
# à IA por fora dessa lista.
const AI_ELIGIBLE_RULE_IDS: Array[String] = [
	"reverse_movement", "optional_capture", "early_promotion",
	"ally_hop", "advance", "shield", "sacred_zone",
	"ascension_law", "impossible_tie_law"
]

static func get_random_ai_rules(count: int) -> Array[RuleCard]:
	var pool = get_all_rules().filter(func(r: RuleCard): return AI_ELIGIBLE_RULE_IDS.has(r.id))
	var chosen = pick_weighted_rules(pool, count)
	for r in chosen:
		r.scope = RuleCard.Scope.AI_ONLY
	return chosen

static func get_random_action_cards(count: int, exclude_ids: Array[String] = []) -> Array[ActionCard]:
	var pool = get_all_action_cards().filter(func(c: ActionCard): return not exclude_ids.has(c.id))
	return pick_weighted_actions(pool, count)

# Cartas seguras pra dar à IA: as que não dependem de um recurso que só o
# jogador tem (Ouro) nem de informação unidirecional (Visão/Profecia só
# fazem sentido de um lado pro outro). Recrutamento/Reconstrução/Recuar/
# Investida Heroica/Segundo Turno já foram ajustadas pra funcionar
# simetricamente pra qualquer time.
const AI_ELIGIBLE_CARD_IDS: Array[String] = [
	"fortify", "grand_reinforcement", "corrupt",
	"recruit", "rebuild", "extra_turn", "retreat", "heroic_advance",
	"coin_of_destiny", "lucky_duel", "second_chance",
	"rebellion", "demote", "heir", "guillotine", "ambush"
]

static func get_ai_starting_deck(count: int) -> Array[ActionCard]:
	var pool = get_all_action_cards().filter(func(c: ActionCard): return AI_ELIGIBLE_CARD_IDS.has(c.id))
	pool.shuffle()
	if count >= pool.size():
		return pool
	var result: Array[ActionCard] = []
	for i in range(count):
		result.append(pool[i])
	return result

static func pick_weighted_rules(available_pool: Array[RuleCard], count: int) -> Array[RuleCard]:
	var result: Array[RuleCard] = []
	var pool = available_pool.duplicate()

	while result.size() < count and not pool.is_empty():
		var total_weight = 0
		for rule in pool:
			total_weight += RuleCard.get_rarity_weight(rule.rarity)

		var roll = randi_range(1, total_weight)
		var accum = 0
		var chosen_idx = 0

		for i in range(pool.size()):
			accum += RuleCard.get_rarity_weight(pool[i].rarity)
			if roll <= accum:
				chosen_idx = i
				break

		result.append(pool[chosen_idx])
		pool.remove_at(chosen_idx)

	return result

static func pick_weighted_actions(available_pool: Array[ActionCard], count: int) -> Array[ActionCard]:
	var result: Array[ActionCard] = []
	var pool = available_pool.duplicate()

	while result.size() < count and not pool.is_empty():
		var total_weight = 0
		for card in pool:
			total_weight += ActionCard.get_rarity_weight(card.rarity)

		var roll = randi_range(1, total_weight)
		var accum = 0
		var chosen_idx = 0

		for i in range(pool.size()):
			accum += ActionCard.get_rarity_weight(pool[i].rarity)
			if roll <= accum:
				chosen_idx = i
				break

		result.append(pool[chosen_idx])
		pool.remove_at(chosen_idx)

	return result
