# Agent instructions

## Documentation

If a question is about a library, framework, SDK, API, CLI, or cloud service, use Context7. First resolve the library ID. Then query the current documentation.

Do not use Context7 for general programming concepts, business logic debugging, code review, or refactoring.

Write every Markdown file in `docs/`, including files in subdirectories, in plain English. Write `AGENTS.md` and `README.md` in plain English also. Use the `simple-english` skill for this work.

## Agent skills

### Issue tracker

Track issues in GitHub Issues for `micfre/efficient-quests`. See `docs/agents/issue-tracker.md`.

### Triage labels

Use the default triage labels. See `docs/agents/triage-labels.md`.

### Domain docs

Use the single-context layout. See `docs/agents/domain.md`.
