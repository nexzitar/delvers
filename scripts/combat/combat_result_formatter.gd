class_name CombatResultFormatter

static func format(result: CombatResult) -> String:

	var lines := []

	lines.append("=== Combat Result ===")

	if result.victory:
		lines.append("Victory!")
	else:
		lines.append("Defeat!")

	lines.append("Duration: %.1f seconds" % result.duration)

	lines.append("")

	lines.append("Surviving Heroes:")

	for hero in result.surviving_heroes:
		lines.append(
			"- %s (%d HP remaining)"
			% [hero.entity_name, hero.current_health]
		)

	lines.append("")

	lines.append("Surviving Enemies:")

	for enemy in result.surviving_enemies:
		lines.append(
			"- %s (%d HP remaining)"
			% [enemy.entity_name, enemy.current_health]
		)

	return "\n".join(lines)
