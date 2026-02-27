# GitHub Actions Workflow Security Incident Report

**Date:** 2026-02-27
**Workflow:** `.github/workflows/mirror-community-pr.yml`
**Failed Run:** https://github.com/DataDog/dd-trace-rb/actions/runs/22507663892
**Severity:** High (Security vulnerability + Production failure)

## Executive Summary

The mirror-community-pr workflow failed on its first production use due to unsafe interpolation of user-controlled data directly into a JavaScript string. This violated established security guidelines and caused a syntax error when processing PR #5365, which contained code blocks, quotes, and newlines in its description.

## Technical Details

### Root Cause

**Location:** `.github/workflows/mirror-community-pr.yml:285`

The workflow embeds `${{ needs.get-pr-details.outputs.pr-body }}` directly into a JavaScript string within a `github-script` action:

```javascript
const prBody = [
  // ... static strings ...
  '${{ needs.get-pr-details.outputs.pr-body }}'  // UNSAFE
].join('\n');
```

When the PR body contains special characters (newlines, backticks, quotes), the JavaScript parser fails with:
```
SyntaxError: Invalid or unexpected token
```

### Security Implications

This pattern violates the security guidelines in `CLAUDE.md`:
> "NEVER interpolate user input directly in `run:` blocks - use `env:` instead"

**Vulnerable to:**
- Syntax errors (immediate impact)
- Potential script injection if attacker-controlled content is processed
- Code execution in workflow context with elevated permissions

**User-controllable inputs that are dangerous:**
- `github.event.comment.body`
- `github.event.issue.title`
- `github.event.issue.body`
- `github.event.pull_request.title`
- `github.event.pull_request.body`
- `github.head_ref`

### Timeline

- **2026-02-17:** PR #5374 opened adding mirror-community-pr workflow
- **2026-02-17:** Two test runs failed during development (not investigated)
- **2026-02-27 13:46:** Workflow merged to master without successful test run
- **2026-02-27 23:21:** First production use on PR #5365 - immediate failure
- **Impact:** 100% failure rate on production use

## Why This Wasn't Caught

1. **No successful test runs before merge** - Both development test runs failed, but workflow was merged anyway
2. **Manual testing gaps** - Test plan didn't include complex PR descriptions with special characters
3. **Static analysis limitations** - yamllint and actionlint cannot detect runtime JavaScript errors
4. **Code review miss** - Security anti-pattern not flagged despite clear guidelines in CLAUDE.md
5. **Integration testing stated as "not feasible"** - Self-fulfilling prophecy

## The Fix

**Change:** Pass user input via environment variable instead of embedding in script

```yaml
- name: Create or update mirror PR
  uses: actions/github-script@...
  env:
    PR_BODY: ${{ needs.get-pr-details.outputs.pr-body }}  # Add this
  with:
    script: |
      // Change from:
      // const body = '${{ needs.get-pr-details.outputs.pr-body }}';

      // To:
      const body = process.env.PR_BODY;
```

This fixes both the syntax error AND the security vulnerability.

## Recommendations Implemented

1. **Static validation script** - `scripts/validate-github-scripts.sh` to detect unsafe patterns
2. **CI integration** - Add workflow validation to `.github/workflows/check.yml`
3. **Documentation updates** - Add specific examples and checklists to `CLAUDE.md`
4. **PR template** - Add workflow-specific checklist to PR template
5. **Integration tests** - Create test workflow with complex input data
6. **Code review process** - Establish clear validation requirements for workflow changes

## Lessons Learned

1. **Never merge workflows without successful test runs** - Failed tests are red flags, not blockers to ignore
2. **Test with realistic data** - Edge cases with special characters must be part of test plans
3. **Automation over documentation** - Security guidelines in docs are insufficient; need automated enforcement
4. **Integration tests ARE feasible** - Workflows can test themselves with mock data
5. **User input is always dangerous** - Treat all user-controllable data as potentially malicious

## Action Items

- [x] Document incident
- [ ] Fix mirror-community-pr.yml (separate PR/commit)
- [ ] Implement validation tooling
- [ ] Update documentation and processes
- [ ] Audit all existing workflows for similar patterns
- [ ] Establish pre-merge testing requirements for workflows

## References

- Failed workflow run: https://github.com/DataDog/dd-trace-rb/actions/runs/22507663892
- Original workflow PR: #5374
- Triggering PR: #5365
- Security guidelines: `CLAUDE.md` (GitHub Actions section)
- GitHub Actions security hardening: https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions
