# Your first piece

A notasi piece is a plain text file whose name ends in `.nts`, such as
`gilak.nts`. You can write it in any text editor.

Every piece starts with a title. Here is a whole file:

```scheme
{{#include ../../../examples/manual/first-piece.nts}}
```

- `(piece "Gilak for practice")` names the piece. The title goes in
  double quotes, and the whole line is wrapped in round brackets.
- A semicolon `;` starts a comment. Everything after it on that line is
  for you, not for notasi, so use comments to note where a piece comes
  from or what a line means.

## The rules

- The `piece` line comes first, before anything else except comments
  and blank lines.
- A file has exactly one `piece` line.
- Spaces and line breaks don't matter, so you can spread a line over
  several lines when it gets long.

## What you get

notasi reads this file as a piece called *Gilak for practice*, with no
music in it yet. Next, tell notasi about your
[scales and stroke sets](scales-and-strokes.md) and
[instruments](instruments.md). Once it has parts, you can
[draw it as a score](drawing.md).
