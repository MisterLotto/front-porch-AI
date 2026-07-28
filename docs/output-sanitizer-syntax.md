# Output Sanitizer — Find & Replace Syntax

The Output Sanitizer lets you automatically find text in AI responses and replace it with something else. Each rule has two fields:

- **Find** — what to look for (supports simple wildcards)
- **Replace** — what to put in its place (can reuse what was found)

Rules run top to bottom. If a rule doesn't match anything, it's skipped.

Each rule also has a **Stop after match** toggle (the icon beside the rule). When it is on and that rule actually changes the text, every rule below it is skipped for that response. If the rule matches but its replacement is identical to what it matched, nothing changed — so the remaining rules still run.

---

## Plain text

If you type `hello` in the find field, it matches the word "hello" exactly. Special characters like `(`, `)`, `+`, `*`, `[`, `]`, etc. are treated as normal text — they won't do anything fancy unless you use the wildcard syntax described below.

---

## Wildcards (masks)

A wildcard is a short code that matches "any character of this type." Type a backslash `\` followed by a letter:

| What you type | What it matches | Example |
|---|---|---|
| `\a` | Any printable character (letter, digit, punctuation, or space) | `\a` matches `A`, `3`, `!`, ` ` |
| `\w` | Any letter or digit (a word character) | `\w` matches `a`, `Z`, `7` but not `!` or ` ` |
| `\d` | Any digit | `\d` matches `0` through `9` |
| `\l` | Any letter | `\l` matches `a` through `z` and `A` through `Z` |
| `\p` | Any punctuation, symbol, or space | `\p` matches `!`, `.`, `@`, ` ` but not `a` or `5` |
| `\\` | A literal backslash | `\\` matches `\` |

**Example:** Find: `\d\d\d` matches any three digits in a row, like `427`.

---

## Repeating patterns (quantifiers)

You can add a suffix to a wildcard to say how many times it should repeat:

| Suffix | Meaning | Example |
|---|---|---|
| (none) | Exactly once | `\d` = one digit |
| `?` | Zero or one (optional) | `\d?` = optional digit |
| `+` | One or more | `\d+` = one or more digits |
| `*` | Zero or more | `\d*` = zero or more digits |
| `{n}` | Exactly n times | `\d{3}` = exactly 3 digits |
| `{n,m}` | Between n and m times | `\d{2,4}` = 2 to 4 digits |
| `{n,}` | n or more times | `\d{3,}` = 3 or more digits |

**Example:** Find: `\l+` matches one or more letters — any word like `hello` or `A`.

---

## Capture groups — saving part of a match

Sometimes you want to find a pattern but only replace *part* of it. For example: find `(hello)` and replace it with `[hello]` — you want to keep the word but change the brackets.

Capture groups let you "save" part of what you match so you can use it in the replace field.

### How to write a capture group

Use `\(` to open the group and a bare `)` (without a backslash) to close it. Everything between them is the pattern to match and save.

**Find:** `\(\d+)`
**What it does:** Matches one or more digits and saves them.

On the text `abc 123 def`, this:
- `\(` opens the capture group (does not match any text)
- `\d+` matches `123` and saves it
- `)` closes the capture group (does not match any text)

The saved part (`123`) can now be used in the replace field (see below).

### `(` vs `\(` — this matters

- `\(` (with backslash) = **opens a capture group**. This is not part of the text being matched — it's an instruction to "start saving here."
- `(` (without backslash) = matches a **literal `(` character** in the text. It does not open a group.

### Inside a capture group

The text between `\(` and `)` is **not** read using the wildcard table above — it is handed straight to the underlying regular-expression engine. That has three consequences:

- `\)` (backslash + close paren) matches a **literal `)` character** — it does NOT close the group. Only a bare `)` closes the group.
- `\d` and `\w` still work, because standard regex has them too. (Small difference: inside a group, `\w` also matches the underscore `_`; the `\w` wildcard outside a group does not.)
- **`\a`, `\l` and `\p` do NOT work inside a group.** Those three are Front Porch wildcards, not standard regex, so the engine reads them as the plain letters `a`, `l` and `p`. `\(\a+)` on `banana` captures the letter `a` — not "any printable character". Nothing warns you: the rule saves normally and simply matches the wrong thing.

Inside a group, use standard character classes instead: `[a-zA-Z]` for any letter, `[0-9]` for any digit, `.` for any character. **Find:** `\([a-zA-Z]+)` on `hello` captures `hello`.

**Example:** Find: `\(\w+\))` — this matches a word followed by a literal `)`, all inside a capture group. On the text `hello)`, it captures `hello)`.

### Matching literal parentheses around content

If the text is `(hello)` and you want to capture just the word `hello` without the `()`, use:

**Find:** `\(\w+)`
**Text:** `(hello)` → captures `hello`

The `\(` opens the group, `\w+` matches the word, and the bare `)` closes the group. The parentheses in the text are just regular characters — `\(` and `)` in the find field are group delimiters, not literal matches.

If you also want to consume the literal parentheses in the match (so the replace covers the whole thing):

- put them outside the group:

**Find:** `(\(\w+))`
- `(` (bare) = literal `(` in text (auto-escaped by the compiler)
- `\(` = opens capture group
- `\w+` = matches the word
- first `)` = closes capture group
- second `)` (bare) = literal `)` in text

On text `(hello)`: matches `(hello)`, captures `hello`.

> **Write the closing paren as a bare `)` here, not `\)`.** Outside a capture group a backslash is only valid before `(`, another backslash, or one of the five wildcard letters — so `\)` out there is rejected as an unknown wildcard and the rule will not save at all.

- or use 

**Find:** `\(\(\w+\))`
- `\(` = opens capture group
- second `\(` = inside group works as literal `(` - `\` used as escape
- `\w+` = matches the word
- `\)` escaped = literal `)` in group
- `)` = closes capture group

On text `(hello)`: matches `(hello)`, captures `(hello)`.

### Multiple capture groups

You can have more than one capture group in a single rule. They are numbered in the order they open:

**Find:** `\(\w+) \(\d+)`
- First `\(`...`)` = capture group 1 (saves the word)
- Second `\(`...`)` = capture group 2 (saves the number)

On text `hello 42`: group 1 = `hello`, group 2 = `42`.

---

## The replace field

The replace field controls what gets written in place of the matched text.

### Using saved content (backreferences)

Type `\` followed by a number to paste what a capture group saved:

| What you type | What it pastes |
|---|---|
| `\1` | What capture group 1 matched |
| `\2` | What capture group 2 matched |
| `\3` | What capture group 3 matched |
| ... | ... |

**Example:**
- Find: `\(\d+)` Replace: `[\1]`
- On text `abc 123 def`: the group saves `123`, replace pastes it inside brackets → `abc [123] def`

You can use backreferences more than once, or combine them with other text:

- Find: `\(\w+)` Replace: `\1 and \1`
- On text `abc hello def` → `abc hello and hello def`

### Literal dollar sign

If you need a literal `$` in the replacement, type `$$`:

- Replace: `$$100` → outputs `$100`

**One caveat:** if the same rule also uses capture groups, don't put a digit straight after `$$`. Backreferences are filled in *after* `$$` becomes `$`, so in a rule with one capture group a replacement of `$$100` is read as "group 1, then `00`". Either add a space (`$$ 100` → `$ 100`), or use a rule without capture groups. Without capture groups, `$$100` → `$100` works exactly as shown above.

### Literal backslash

If you need a literal `\` in the replacement, type `\\`:

- Replace: `\\path` → outputs `\path`

### Plain text

Any text without `\` followed by a number is kept as-is:

- Find: `hello` Replace: `goodbye`
- On text `hello world` → `goodbye world`

---

## Worked examples

### Example 1: Wrap numbers in brackets

**Find:** `\(\d+)`
**Replace:** `[\1]`

| Input | Output |
|---|---|
| `abc 123 def` | `abc [123] def` |
| `order 456 shipped` | `order [456] shipped` |

The capture group saves the digits. The replace field wraps them in brackets.

### Example 2: Swap two parts

**Find:** `\(\w+) \(\d+)`
**Replace:** `\2 \1`

| Input | Output |
|---|---|
| `hello 42` | `42 hello` |

Group 1 saves `hello`, group 2 saves `42`. The replace field puts group 2 first, then group 1.

### Example 3: Replace but don't reuse

**Find:** `\(\d+)`
**Replace:** `NUMBER`

| Input | Output |
|---|---|
| `abc 123 def` | `abc NUMBER def` |
| `order 456 shipped` | `order NUMBER shipped` |

The capture group still matches, but the replace field doesn't use `\1` — it just writes "NUMBER" every time.

### Example 4: Remove em dashes

**Find:** `—`
**Replace:** ` - `

| Input | Output |
|---|---|
| `she said—hello` | `she said - hello` |

No capture groups needed — this is a simple find-and-replace of a special character (and only default rule shipped - because all this was started exactly due to the annoying habit of one otherwise wonderful LLM to use em-dashes without spacing...).

### Example 5: Normalize multiple spaces to one

**Find:** `\( )+`
**Replace:** ` ` (a single space)

| Input | Output |
|---|---|
| `hello   world` | `hello world` |
| `a  b   c    d` | `a b c d` |

`\( )` opens a capture group containing a single literal space, and `+` makes it match one or more. The replace pastes one space back.

Why not `\p\p+`? Because `\p` matches any non-word character — punctuation, symbols, and spaces alike. `\p\p+` would happily eat `, `, `...`, `! `, and other punctuation+space combinations, turning `hello, world` into `hello world`. The pattern `\( )+` targets only spaces. That said, it can be exactly what you want in some situation...
