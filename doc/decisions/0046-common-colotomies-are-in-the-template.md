# 0046 Common colotomies are defined in the gong-kebyar template

Status: accepted (2026-11-23)

Context: Iteration 2 left colotomies out of the `gong-kebyar` template (recorded in 01, not in an ADR): every piece defined its own. Gilak is used in many compositions, and three of the examples repeated the same definition. A template may already hold `colotomy` forms (01, "use").

Decision: `gong-kebyar` defines the common colotomies, beside the `gong` instrument their parts play: `gilak` (8 pulses: gong lanang on 4, kempur on 5 and 7, gong on 8, as in Tenzer's Baris) and `bapang` (16 pulses: kempur on 4 and 12, klentong on 8, gong on 16, the meter of Gold's Jaya Semara). A piece names one with `:colotomy` and writes no `colotomy` form. It can still define its own, or replace the template's by defining one of the same name, like any definition. Others are added when a piece needs them, named after the form, not a piece.

Consequences: Pieces using gilak or bapang are shorter. The reader is unchanged. The examples, the manual's gong-cycles page and the template tests change: the page shows the template's `gilak` first, then how to define a colotomy.
