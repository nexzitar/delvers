class_name StatusEffect

enum Kind { ROOT, SLOW, STUN }

var kind: Kind
var remaining: float
var magnitude: float = 1.0
## Stable identifier for BUFF_APPLIED / BUFF_EXPIRED events and
## duplicate checks (e.g. "hamstring_slow").
var id: String = ""
