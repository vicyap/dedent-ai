# dedent-ai

Small Phoenix LiveView tool for cleaning up pasted terminal output from Claude Code and Codex. Strips the leading `●`/`•` marker, dedents the common indent, repairs wrapped Markdown lines, surfaces `★ Insight ───` callouts, and offers a "Copy formatted" option that pastes as rich text into Gmail / Notion / Docs.

## Local

```sh
mise trust
mise install
mix setup
mix phx.server
```

Open http://localhost:4000.

## Checks

```sh
mix precommit
docker build -t dedent_ai:local .
```

## Fly

The app is configured for `dedent-ai.fly.dev` with one auto-starting, auto-stopping machine.

```sh
flyctl deploy -a dedent-ai --ha=false
```
