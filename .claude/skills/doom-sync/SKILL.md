---
name: doom-sync
description: Update Doom Emacs, then audit this literate Doom config against the installed Doom modules and against Tecosaur's config - find redundant, conflicting and outdated settings, sections that drifted from Tecosaur's, and features of his worth adopting - and apply only what the user approves, one commit per change. Use when the user wants to update, upgrade or sync Doom, compare the config with Tecosaur's, prune redundant settings, or clean up the Doom config.
---

# doom-sync

Run from `~/.config/doom`. References, never edited:

- `DOOM=~/.config/emacs` — the doom-emacs checkout (`bin/doom`, `modules/`, `lisp/`, `static/`).
- `T=~/Projects/third-party/tecosaur/emacs-config` — Tecosaur's config; `$T/config.org` is it.

The config is literate (`:config literate`): `config.org` is the only source.
`init.el`, `config.el` and `packages.el` are tangled from it and gitignored —
read them for line-level evidence, never edit them. `cli.el` is gitignored too.

State lives in `.claude/skills/doom-sync/tecosaur.md` (create it on the first
run):

```markdown
rev: <full hash of $T reviewed last>

## Declined
- <$T heading> — <idea> (<YYYY-MM-DD>): <user's reason, if given>
```

## 1. Preflight

- `git status --porcelain` here and `git -C "$DOOM" status --porcelain` must
  both be empty. If not, stop and say so.
- No other `doom` process may be running (`pgrep -af 'bin/doom'`): a concurrent
  `doom sync` wipes `$DOOM/.local` and breaks every check below. Wait or stop.
- `OLD=$(git -C "$DOOM" rev-parse HEAD)`.
- Baselines, saved to scratch: `doom doctor` output, and the startup check
  from step 9. Pre-existing warnings are findings, not regressions.

## 2. Update Doom

```sh
"$DOOM/bin/doom" upgrade      # git pull + doom sync -u; takes minutes
NEW=$(git -C "$DOOM" rev-parse HEAD)
```

Nothing to commit: package pins live in `$DOOM`. If `OLD == NEW`, say so and
still run the audit.

A sync can rebuild `$DOOM/.local` from scratch, which drops the compiled
tree-sitter grammars (`libtree-sitter-*`); every `+tree-sitter` language then
prompts on first open. If `find "$DOOM/.local" -name 'libtree-sitter-*'` is
empty, report it and ask before installing them — it downloads and compiles.

## 3. Upstream Doom changes (`OLD..NEW`, skip if equal)

Doom has no changelog; read the history.

- `git -C "$DOOM" log --oneline OLD..NEW`, then the full message of every
  `type!:` commit and every commit with `BREAKING CHANGE` in its body.
- `git -C "$DOOM" diff OLD..NEW -- static/init.example.el` — added, removed
  and renamed modules and flags.
- `git -C "$DOOM" diff OLD..NEW -G 'make-obsolete|define-obsolete' -- lisp modules`.
- Deprecation and "removed flag" lines in the new `doom doctor` output (this
  is how `+roam2 → +roam` surfaced).

## 4. Update Tecosaur

```sh
git -C "$T" pull --ff-only
REV=$(sed -n 's/^rev: //p' .claude/skills/doom-sync/tecosaur.md)   # empty on first run
git -C "$T" log --oneline "$REV"..HEAD -- config.org
git -C "$T" diff "$REV"..HEAD -- config.org
```

If the pull fails (network, diverged), report it and audit against the local
checkout as is. With no `REV`, there is no diff: do the full mapping in step 6.

## 5. Local config

- `config.org` by heading (`grep -n '^\*' config.org`). Module selection is
  the `init.el` block and its `doom-<category>` noweb blocks; `package!` lines
  are the `:tangle packages.el` blocks.
- `custom.el` — anything there that belongs in `config.org` is a finding.
- `snippets/`.
- `git log` — recent `fix(config):` commits record deliberate deviations
  (e.g. typst-ts-mode disabled, python without `+conda`). Don't re-flag them
  unless an upstream change makes them break or unnecessary.

## 6. Classify

Read the actual source; don't rely on memory of Doom or of Tecosaur's config.
Every finding carries: `config.org:line`, category, the proving path
(`$DOOM/modules/<cat>/<mod>/{config,packages}.el:line` or `$T/config.org:line`),
the proposed change, and risk.

- **Redundant** — `setq`/`after!`/`map!`/`package!` that an enabled module
  (with its enabled flags) already does identically; `unpin!`s or package
  recipes Doom now pins itself.
- **Conflicting** — overrides fighting an enabled module: two LSP clients or
  completion frontends for one mode, a package disabled in one place and
  configured in another, keybindings shadowing a module's without evident
  intent, `custom.el` values contradicting `config.org`.
- **Outdated** — modules, flags, variables, functions or macros removed,
  renamed or obsoleted in `OLD..NEW` or flagged by the startup check (obsolete
  macro warnings from `config.el` map back to `config.org` through the
  `:comments link` markers); `unpin!`/workarounds whose upstream reason is gone.
- **Tecosaur: drifted** — sections already shared with him (matched by heading
  or by code, since many headings here mirror his) where `REV..HEAD` changed
  his version. On the first run, compare every shared section against his
  current version instead.
- **Tecosaur: worth adopting** — anything in `$T/config.org` not present here
  that would plausibly help this user: no local evidence required, but say what
  it gives. Exclude entries in `## Declined`; things bound to his own
  infrastructure (mail accounts, personal paths, his publishing/CI); and his
  scaffolding itself (`confpkg`, `package!` hacks to support it). Port the
  substance, not his `confpkg` wrappers. Rank by value; prefer self-contained
  items.

## 7. Ask — always with `AskUserQuestion`

Never ask "should I…?" in free text. First print a short grouped summary
(counts per category, top items), then:

- **Redundant / conflicting / outdated / drifted** — one `multiSelect`
  question per category; each option is one finding (label
  `<heading>: short claim`, description = proving path + risk). Limit is 4
  questions × 4 options per call: batch in rounds, highest-risk category first.
- **Conflicts or drift with several valid resolutions** — a single-select
  question of their own, one option per resolution with its trade-off
  (e.g. "Take his version", "Keep mine", "Merge: …").
- **Worth adopting** — single-select per item: "Adopt (Recommended)", "Adopt,
  adapted: <how>", "Decline", with `preview` showing the exact org block to
  insert and the heading it goes under. At most ~8 per run, best first; items
  not reached stay unreviewed (not declined) and come back next run.

Declined adoptions go into `## Declined` (with the reason if the user gave
one, via Other/notes). Declined redundant/conflicting/outdated findings are
intentional deviations: leave them and don't re-propose them this session.

## 8. Apply

- Minimal edit per approved finding, in `config.org` only; don't touch
  unrelated sections. Adoptions go under the heading mirroring Tecosaur's
  (create it in the matching top-level section if missing), as an org
  subsection with prose explaining the why, like the rest of the file.
- Module/flag changes edit the matching `doom-<category>` noweb block.
- New packages: a `#+begin_src emacs-lisp :tangle packages.el` block next to
  their configuration, as elsewhere in the file.
- If a change needs an external binary (LSP server, formatter, CLI), propose
  the Nix change via `AskUserQuestion`; never rely on a package downloading it.
- Comments only for non-obvious decisions.

## 9. Verify each change before committing

```sh
"$DOOM/bin/doom" sync        # tangles config.org; must exit 0
"$DOOM/bin/doom" doctor      # no warnings beyond the step-1 baseline
```

Startup check — a private daemon, so a running Emacs is untouched:

```sh
S=doom-sync-check
timeout 180 emacs --daemon=$S 2>&1 | grep -E 'Error|Warning' ; # must print nothing new vs baseline
timeout 30 emacsclient -s $S --eval '(progn (require (quote subr-x)) (format "INIT=%s WARN=[%s] MSG=[%s]" doom-init-time (if (get-buffer "*Warnings*") (with-current-buffer "*Warnings*" (string-trim (buffer-string))) "") (with-current-buffer "*Messages*" (string-join (seq-filter (lambda (l) (string-match-p "[Ee]rror\\|[Ww]arning" l)) (split-string (buffer-string) "\n")) " | "))))'
timeout 10 emacsclient -s $S --eval '(kill-emacs)'
# expect INIT=<seconds> and WARN/MSG no worse than baseline
```

For a language/LSP change, start the daemon again and open a sample file of
that language in a scratch git repo. Never block inside `--eval`: any prompt
(missing tree-sitter grammar, lsp project root, server install) freezes the
daemon and every later `emacsclient` call. Open the file from a timer, then
poll; an active minibuffer prompt is a finding — report its text, never
answer it on the user's behalf:

```sh
F=$SCRATCH/repo/sample.EXT     # git init $SCRATCH/repo first
timeout 20 emacsclient -s $S --eval "(progn (setq lsp-auto-guess-root t) (run-at-time 0 nil (lambda () (switch-to-buffer (find-file-noselect \"$F\")))) t)"
for i in $(seq 12); do sleep 5
  timeout 5 emacsclient -s $S --eval "(if (active-minibuffer-window) (format \"PROMPT=%s\" (with-current-buffer (window-buffer (active-minibuffer-window)) (substring-no-properties (buffer-string)))) (with-current-buffer (get-file-buffer \"$F\") (format \"MODE=%s CLIENTS=%s\" major-mode (mapcar (lambda (w) (lsp--client-server-id (lsp--workspace-client w))) (bound-and-true-p lsp--buffer-workspaces)))))"
done
# expect e.g. MODE=python-ts-mode CLIENTS=(basedpyright); PROMPT=… means stop and report
```

If the daemon still stops answering, kill it by PID —
`kill $(pgrep -f -- '/emacs --daemon=doom-sync-check$')` — not with a
`pkill -f` pattern that also matches this shell.

If verification fails, fix or revert that change and report it — never commit
a failing change.

## 10. Commit

One commit per logical change, directly on `main`, matching `git log` style:
`fix(config): …` for redundant/conflicting/outdated, `sync(config): …` for
Tecosaur drift, `feat(config): … from tecosaur` for adoptions; the body says
what and why. No attribution lines.

Last, update `tecosaur.md` — `rev:` to `$T` HEAD (even if everything was
declined) and the new `## Declined` entries — and commit it alone:
`chore(claude): record tecosaur review at <short-hash>`. If the pull failed,
keep the rev pointing at what was actually reviewed.

Finish with a summary: Doom `OLD → NEW`, Tecosaur `REV → HEAD`, applied (with
commit hashes), declined, unreviewed adoptions left for next run, and manual
follow-up (restart Emacs, `nix profile` changes).
