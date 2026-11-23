# 0030 Colotomies generate the gong and kempli parts

Status: superseded by 0038

Context: Every piece repeats a colotomic meter, and writing the gong and kempli out for every cycle is repetitive and easy to get wrong. Gold reads cycles with the gong on the last pulse, and many pieces open on the gong, one pulse before the first complete cycle.

Decision: `(colotomy NAME LENGTH (PART INSTRUMENT TOKEN ...) ...)` defines a cycle of LENGTH pulses and the gong parts that mark it. A piece names its colotomy (`:colotomy NAME`) and may start with a pickup (`:pickup P`, whole pulses, at most one cycle). The colotomy's parts are generated for the whole piece and keep their names (`gong`); the timekeeper, the part `kempli` with one stroke per pulse, is always generated. A piece is its pickup plus whole cycles. Positions are cycle and pulse, and `||` checks a cycle boundary.

Consequences: Pieces are shorter, and errors can say "cycle 2, pulse 4". Generated parts are printed by naming them in a score, like any other. Departing from or changing the colotomy, sections, another timekeeper and longer pickups are later.
