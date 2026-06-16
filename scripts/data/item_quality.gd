class_name ItemQuality

## WoW-familiar item tiers and border colors.
enum Tier {
	COMMON,
	UNCOMMON,
	RARE,
	EPIC,
	LEGENDARY,
}

const NAMES := {
	Tier.COMMON: "Common",
	Tier.UNCOMMON: "Uncommon",
	Tier.RARE: "Rare",
	Tier.EPIC: "Epic",
	Tier.LEGENDARY: "Legendary",
}

const COLORS := {
	Tier.COMMON: Color("#ffffff"),
	Tier.UNCOMMON: Color("#1eff00"),
	Tier.RARE: Color("#0070dd"),
	Tier.EPIC: Color("#a335ee"),
	Tier.LEGENDARY: Color("#ff8000"),
}

static func tier_name(tier: int) -> String:
	return NAMES.get(tier, "Common")

static func color(tier: int) -> Color:
	return COLORS.get(tier, COLORS[Tier.COMMON])

static func frame_style(tier: int) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.06, 0.04, 0.03, 0.92)
	s.border_color = color(tier)
	s.set_border_width_all(2)
	s.set_corner_radius_all(4)
	s.set_content_margin_all(3)
	return s
