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

## Who made it, and where it comes from

The `piece` line can also say who made the music and where your
notation comes from:

```scheme
{{#include ../../../examples/manual/piece-information.nts}}
```

Each of these is optional, and each takes text in double quotes,
written however you like (`"1964"`, `"1930s"` or `"c. 1964"` for a
year):

| Key | What it says |
|---|---|
| `:composer` | Who composed the music. |
| `:composition-year` | When it was composed. |
| `:transcriber` | Who wrote it down. |
| `:transcription-year` | When it was written down. |
| `:source` | Where it comes from: a book, a recording, a teacher. |
| `:contributor` | Who contributed the file. |
| `:contribution-year` | When it was contributed. |
| `:performer` | Who plays the music your notation follows. |
| `:remarks` | Anything else: its history, what is left out. |

notasi keeps them with the piece but doesn't print them in the score.

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
