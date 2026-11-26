# 0053 The template has bapang in two lengths, named for them, and gegaboran

Status: accepted (2026-11-26)

Context: ADR 0046 put `bapang` in the `gong-kebyar` template as a 16-pulse cycle, "the meter of Gold's Jaya Semara". Checking the sources showed that this is only half right. Gold's basic bapang is 8 beats (figure 5.11, p. 110: kempur on 2 and 6, klentong on 4, gong on 8). Bapang also comes in elongated forms of 16 and 32 beats (pp. 111, 142), and Jaya Semara's pangecet is the 16-beat form (pp. 58, 140). Other glossaries agree that bapang has more than one length. Gegaboran (16 beats) has exactly the strokes of the 16-beat bapang (figure 5.11): gongs alone don't tell meters apart, which also differ in drumming, mood and genre.

Decision: The template's `bapang` is replaced by `bapang-8` (kempur on 2 and 6, klentong on 4, gong on 8) and `bapang-16` (kempur on 4 and 12, klentong on 8, gong on 16), and it gets `gegaboran`, with `bapang-16`'s strokes. Plain `bapang` becomes an unknown colotomy, with no migration, so a file that names it is told instead of silently changing length. notasi has no operation that stretches a colotomy: each length of a meter is its own colotomy, and other lengths (the 32-pulse bapang) are written in the piece until one is needed in the template. `gegaboran` is an exception to ADR 0046's rule that the template holds only colotomies an example uses, so a writer can name the meter they mean. The documentation says what a colotomy is: notasi's word for one named meter at one length, not a Balinese term; the writer's label for the meter, since the strokes don't decide it; and a length from a source says whose count it is (Gold's beats are notasi's pulses).

Consequences: Jaya Semara names `bapang-16`; its music and drawings don't change. Files that wrote `:colotomy bapang` must choose a length. The manual's gong-cycles page, the template's comments and the template tests change, and the manual's made-up colotomy example is replaced by a real one, the 32-pulse bapang of Gold's "Jagra Parwata". The rest of ADR 0046 (common colotomies in the template, named after the form) still holds.

Supersedes: 0046
