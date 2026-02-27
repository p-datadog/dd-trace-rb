# Absolute Rules

## Pull Requests

- ALWAYS push branches to `DataDog/dd-trace-rb`, not forks
- ALWAYS use `--repo DataDog/dd-trace-rb` with gh commands (defaults are unreliable)
- PR descriptions MUST use `.github/PULL_REQUEST_TEMPLATE.md` as the starting point
- Write for the developer performing code review; be concise
- Use one sentence per relevant point in summary/motivation sections
- Changelog entries are written for customers only; consider changes from user/customer POV
- Internal changes (telemetry, CI, tooling) = "None" for changelog
- Add `--label "AI Generated"` when creating PRs (do not mention AI in description; label is sufficient)

## Never

- Use `git commit --amend` unless the user explicitly and clearly requests it (always create new commits by default)
- Push commits to remote (`git push`) unless the user explicitly requests it
- Commit secrets, tokens, or credentials
- Edit files under `gemfiles/` (auto-generated; use `bundle exec rake dependency:generate`)
- Change versioning (`lib/datadog/version.rb`, `CHANGELOG.md`)
- Leave resources open (terminate threads, close files)
- Make breaking public API changes

## Ask First

- Modifying dependencies in `datadog.gemspec`, `appraisal/`, or `Matrixfile`
- Editing CI workflows or release automation
- Touching vendored third-party code (except `vendor/rbs`)
- Modifying `@public_api` annotated code (read `docs/PublicApi.md` first)

## GitHub Actions

When creating or modifying workflows in `.github/workflows/`:

### Security

**CRITICAL: Never embed user input directly in scripts**

This applies to BOTH `run:` blocks AND `actions/github-script`:

```yaml
# ❌ BAD - Will break with newlines/quotes/backticks and enables injection
uses: actions/github-script@...
with:
  script: |
    const body = '${{ github.event.issue.body }}';  // UNSAFE!
    const title = '${{ needs.job.outputs.pr-title }}';  // UNSAFE!
```

```yaml
# ✅ GOOD - Safe from injection and syntax errors
uses: actions/github-script@...
env:
  ISSUE_BODY: ${{ github.event.issue.body }}
  PR_TITLE: ${{ needs.job.outputs.pr-title }}
with:
  script: |
    const body = process.env.ISSUE_BODY;
    const title = process.env.PR_TITLE;
```

```yaml
# ❌ BAD - Shell injection risk
run: echo "${{ github.event.comment.body }}"
```

```yaml
# ✅ GOOD - Safe
env:
  COMMENT: ${{ github.event.comment.body }}
run: echo "$COMMENT"
```

**User-controllable inputs (NEVER interpolate directly):**
- `github.event.comment.body`
- `github.event.issue.title` / `github.event.issue.body`
- `github.event.pull_request.title` / `github.event.pull_request.body`
- `github.head_ref`
- `needs.*.outputs.*` (if they contain user data)

**Other security requirements:**
- Pin actions to SHA: `uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6.0.2`
- Set `permissions: {}` at workflow level; explicit minimal permissions per job
- Prefer `pull_request` over `pull_request_target`

### Shell Scripts

- Always quote variables: `"$VAR"` not `$VAR`
- Quote `$GITHUB_OUTPUT`: `echo "key=value" >> "$GITHUB_OUTPUT"`
- Group multiple redirects: `{ echo "a"; echo "b"; } >> "$GITHUB_OUTPUT"`
- Avoid heredocs; use echo grouping instead

### Validation

Run these checks before committing workflow changes:

```bash
yamllint --strict .github/workflows/your-workflow.yml
actionlint .github/workflows/your-workflow.yml
bin/validate-github-workflows  # Checks for security anti-patterns
```

### Pre-Merge Checklist for Workflow Changes

Before merging PRs that modify `.github/workflows/`:

- [ ] No user input embedded directly in `script:` blocks (use `env:` instead)
- [ ] Tested with realistic complex data (code blocks, quotes, newlines, special chars)
- [ ] All validation passes: `yamllint`, `actionlint`, `bin/validate-github-workflows`
- [ ] At least one successful test run in CI or via workflow_dispatch
- [ ] Proper `permissions:` declarations (minimal required permissions)
- [ ] Actions pinned to specific SHA (not tags)
- [ ] For `issue_comment` or `pull_request_target`: security review completed

See `workflow-security-incident-report.md` for why this matters.

## Code Changes

- Read files before editing them
- When user says "suggest" or asks a question: analyze only, do not modify code
- When user says "fix", "change", "update": make the changes
- If a requested change contradicts code evidence, alert user before proceeding
- If unable to access a requested web page, explicitly state this and explain basis for any suggestions

## Environment Variables

- Use `DATADOG_ENV`, never `ENV` directly (see `docs/AccessEnvironmentVariables.md`)
- Run `rake local_config_map:generate` when adding new env vars

# Reference

See `AGENTS.md` for:
- Project structure and directory layout
- Docker container setup (`docker compose run --rm tracer-3.4 /bin/bash`)
- Bundle, rake, and rspec commands
- Integration patterns (`patcher.rb`, `integration.rb`, `ext.rb`, `configuration/settings.rb`)

See `docs/` for:
- `DevelopmentGuide.md` - detailed development workflows
- `GettingStarted.md` - user-facing documentation (update when adding settings/env vars)
- `StaticTypingGuide.md` - RBS and Steep usage
- `PublicApi.md` - public API guidelines

## Quick Commands

```bash
bundle exec rake test:main              # Smoke tests
bundle exec rake standard typecheck     # Lint and type check
bundle exec steep check [sources]       # Type check (sources = files or dirs, optional)
bundle exec rspec spec/path/file_spec.rb:123  # Run specific test
```

## Gotchas

- Pipe rspec output: `2>&1 | tee /tmp/rspec.log | grep -E 'Pending:|Failures:|Finished' -A 99`
- Transport noise (`Internal error during Datadog::Tracing::Transport::HTTP::Client request`) is expected
- Profiling specs fail on macOS without additional setup

# Style

Enforced by StandardRB: `bundle exec rake standard:fix`

Additional team preferences:
- Trailing commas in multi-line arrays, hashes, and arguments
- RBS type definitions in `sig/` mirror `lib/` structure
- Avoid `untyped`; use `Type?` not `(nil | Type)`
