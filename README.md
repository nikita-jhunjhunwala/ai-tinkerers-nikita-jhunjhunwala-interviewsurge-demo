# I don't trust my coding agents, so I made them prove it

The copy-paste pattern from my AI Tinkerers Seattle talk (2026-10-20).

I build a job-search product, InterviewSurge, where coding agents (Claude Code, plus
Qwen and DeepSeek models) write most of the code, and I'm the only product engineer. An
agent saying "done, tests pass" is not evidence. This repo is the small set of checks that
turned "trust me" into "here is the proof": about 200 lines of bash, plus a toy to try them on.
The product code stays private; every rule here comes from a real incident in it.

## Run it (about 90 seconds)

In a browser: **Code → Codespaces → Create codespace**, then in the terminal:

```bash
bash demo.sh
```

Or locally: `git clone`, then `bash demo.sh`. Needs bash, git and python3; works on macOS and Linux.

## The three pieces

### 1. A hook that says no, and says why: `hooks/bash-guard.sh`

A Claude Code `PreToolUse` hook. Before the agent runs a shell command, the hook sees it and
can deny it, with a reason the agent reads and acts on. `.claude/settings.json` wires it up.
`hooks/test-bash-guard.sh` checks every rule both ways: a command it must deny, and a close
neighbour it must allow, so a guard that blocks everything fails its own tests.

| Rule | The incident behind it |
|---|---|
| No `git push --no-verify`, no re-pointing `core.hooksPath` | My push gate's "no" was being thrown away: a push with 65 red tests went straight through, and nothing objected. I rebuilt the gate as a real git hook, and agents may not skip it. |
| No `<test or lint> \| tail` | `tail` always exits 0, so the pipe hid every failure. My pre-commit check said green, and two PRs merged with red CI. |
| No `git add -A` / `.` | Broad staging sweeps unrelated files into a commit. |

### 2. Prove "done" with a mutation you watched fail: `mutate.sh`

A passing test proves nothing until you've seen it fail. `mutate.sh` breaks one line, runs
the tests, and restores the file byte for byte:

- `KILLED`: the tests failed with the line broken. They really guard that line.
- `SURVIVED`: the tests still passed. No test guards that line.
- `REFUSED`: the edit changed nothing, so it isn't a mutation.

The toy is a real bug from my product, shrunk. A CV checker must catch a CV claiming a
certification the person doesn't hold. The word list stored `"pmi-acp"`, but text is matched
after hyphens become spaces, so a fake PMI-ACP claim could never be caught. One character.
`mutate-guard.sh` tests the mutation tool itself: a checker you have never seen fail is not a checker.

Every change records its proof in `PROOF.md`: the mutation applied, and the test that went red.

### 3. A push gate that checks every push: `githooks/pre-push`

A plain git hook, so it runs whoever pushes: Claude, another agent, or me in a terminal. It
refuses a change to `toy/` with no `PROOF.md` entry, and it refuses failing tests. If it
can't run, it refuses. Arm it once per clone (agents should not run this; you do):

```bash
git config core.hooksPath githooks
```

## Use it in your repo today

1. Copy `hooks/bash-guard.sh` and `.claude/settings.json`. Add one rule per incident you've
   actually had, and put the reason in the message: the agent reads it.
2. Copy `mutate.sh`. Before you accept "done", break the line that was fixed and watch a test go red.
3. Copy `githooks/pre-push` and point it at your own test command and code paths.

## What it doesn't do

- A human can still run `git push --no-verify`. A hook is a guardrail, not a wall.
- `bash-guard.sh` matches command text, so a determined agent can find a shape it misses. My
  own hook once checked for `git push` only at the start of a command, and
  `git -C dir push --no-verify` slipped through. The push gate is the backstop.
- The Claude hook only sees Claude Code. Other agent tools need their own equivalent, which
  is why the push gate lives in git.
- Not tested against prompt injection. It stops mistakes, not an attacker.

## Rules I learned the hard way

- Apply the mutation first, then run the test. A green run taken before the break proves nothing.
- Zero tests ran is a failure, not a pass.
- Restore byte for byte and check it. Python can reuse stale `.pyc` bytecode after a
  same-second revert, which keeps a reverted test red; `run-tests.sh` uses `python3 -B`.
- Delete what can't go red. A check that has never failed may not be checking anything.

MIT licence.
