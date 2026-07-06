class_name StatusEffect

enum Kind { ROOT, SLOW, STUN, POISON, REGEN, SLUGGISH, FORTIFY }

var kind: Kind
var remaining: float
## SLOW: speed factor. POISON: damage/s. REGEN: healing/s.
## SLUGGISH: attack-speed factor. FORTIFY: damage-taken factor.
var magnitude: float = 1.0
## Stable identifier for BUFF_APPLIED / BUFF_EXPIRED events and
## duplicate checks (e.g. "hamstring_slow").
var id: String = ""
## Who inflicted it (poison damage attribution and threat).
var source_id: int = -1
## POISON: fractional damage accumulator between whole ticks.
var accum: float = 0.0
