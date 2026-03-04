# Testing GitHub Actions Workflows Before Merge

This guide explains how to safely test workflow changes before merging to master.

## Current Situation

You have 7 commits on master that need to be tested:
```bash
git log --oneline HEAD~7..HEAD
```

## Step 1: Move Commits to Feature Branch

Create a feature branch with your changes:

```bash
# Create and switch to new branch from current HEAD
git checkout -b workflow-security-improvements

# Reset master to before your changes (WITHOUT losing work)
git checkout master
git reset --hard HEAD~7

# Switch back to feature branch
git checkout workflow-security-improvements
```

Now your commits are safely on a feature branch, and master is back to its original state.

## Step 2: Push Feature Branch to Remote

```bash
# Push the feature branch to the DataDog repo (as per CLAUDE.md rules)
git push -u u workflow-security-improvements
```

## Step 3: Test Methods

### Method A: Create Pull Request (Recommended)

This triggers all the actual CI workflows:

```bash
# Create PR using gh CLI
gh pr create \
  --title "Add workflow security validation and testing" \
  --body "$(cat <<'EOF'
**What does this PR do?**

Implements comprehensive security validation for GitHub Actions workflows in response to the mirror-community-pr incident where user input was unsafely embedded in JavaScript strings.

**Motivation:**

On 2026-02-27, the mirror-community-pr workflow failed on first production use due to unsafe interpolation of PR body content directly into github-script blocks. This PR implements multiple preventive measures to catch similar issues before they reach production.

**Change log entry**

None (internal tooling and CI improvements)

**Additional Notes:**

Changes include:
- Validation script: `bin/validate-github-workflows`
- CI integration in `check.yml`
- Integration tests in `test-workflow-security.yml`
- Updated documentation in `CLAUDE.md`
- PR template checklist for workflow changes
- Comprehensive incident report

**How to test the change?**

1. This PR will automatically trigger:
   - `check.yml` workflow (validates all workflows)
   - `test-workflow-security.yml` (tests safe input handling)

2. Manual verification:
   - Check Actions tab for successful workflow runs
   - Review validation output in check.yml logs
   - Verify test-workflow-security passes all tests

3. Local testing (see TESTING-WORKFLOWS.md):
   - Run `bin/validate-github-workflows`
   - Test with act (optional)

**For PRs that modify `.github/workflows/`:**

- [x] No user input embedded directly in `script:` blocks (use `env:` instead)
- [x] Tested with realistic complex data (code blocks, quotes, newlines, special chars)
- [x] All validation passes: `yamllint`, `actionlint`, `bin/validate-github-workflows`
- [ ] At least one successful test run (in CI or via `workflow_dispatch`) - will verify after PR creation
- [x] Proper `permissions:` declarations (minimal required permissions only)
- [x] Actions pinned to specific SHA (not tags)
- [x] For `issue_comment` or `pull_request_target`: security review completed
EOF
)" \
  --label "ci" \
  --label "AI Generated"
```

Once the PR is created:
- Go to the Actions tab: https://github.com/DataDog/dd-trace-rb/actions
- Watch for the workflow runs
- Check that both `check` and `test-workflow-security` workflows complete successfully

### Method B: Manual Workflow Dispatch

Test the security test workflow manually without creating a PR:

```bash
# Trigger the test workflow manually
gh workflow run test-workflow-security.yml \
  --ref workflow-security-improvements

# Wait a moment, then check the status
gh run list --workflow=test-workflow-security.yml --limit 1

# View the run details (get the run ID from the list)
gh run view <RUN_ID> --log
```

### Method C: Local Testing with `act`

Test workflows locally using [act](https://github.com/nektos/act):

```bash
# Install act (if not already installed)
# macOS: brew install act
# Linux: see https://github.com/nektos/act#installation

# Test the validation workflow
act pull_request \
  --workflows .github/workflows/check.yml \
  --job validate-workflows

# Test the security test workflow
act pull_request \
  --workflows .github/workflows/test-workflow-security.yml
```

**Note:** `act` has limitations and may not perfectly replicate GitHub Actions environment.

## Step 4: Local Testing (No GitHub Required)

Test the validation script directly:

```bash
# Run validation on current workflows
bin/validate-github-workflows

# Expected output: Should report issues in existing workflows
# (5 workflows have unsafe patterns that need fixing)

# Test that it's working by checking the exit code
if bin/validate-github-workflows; then
  echo "No issues found (or script broken?)"
else
  echo "Issues detected (expected!)"
fi
```

Test specific checks:

```bash
# Check YAML syntax
yamllint --strict .github/workflows/test-workflow-security.yml

# Check with actionlint
docker run --rm -v "$PWD:/repo" --workdir /repo \
  rhysd/actionlint:latest \
  -color \
  .github/workflows/test-workflow-security.yml

# Or if you have actionlint installed:
actionlint .github/workflows/test-workflow-security.yml
```

## Step 5: Verify Test Workflow Content

Manually verify the test workflow will catch issues:

```bash
# Check that the test includes complex input
grep -A 20 "PR_BODY:" .github/workflows/test-workflow-security.yml

# Verify it tests the validation script
grep -A 10 "Test validation script" .github/workflows/test-workflow-security.yml
```

## Step 6: Review Before Merge

Once PR checks pass:

1. **Review Actions tab output:**
   - All checks should be green ✅
   - `validate-workflows` should report the 5 existing issues
   - `test-workflow-security` should pass all tests

2. **Check the validation output:**
   ```bash
   # From PR checks, look for the validate-workflows job
   # It should list the unsafe patterns in existing workflows:
   # - add-milestone-to-pull-requests.yml
   # - ensure-changelog-entry.yml
   # - mirror-community-pr.yml
   # - publish.yml
   # - typing-stats.yml
   ```

3. **Verify test coverage:**
   - Tests should handle newlines, quotes, backticks
   - Tests should verify env: pattern works safely
   - Tests should confirm validation script catches issues

4. **Request review:**
   ```bash
   # Request review from team members
   gh pr review --approve  # (after self-review)
   ```

## Step 7: Merge

After successful testing and approval:

```bash
# Merge the PR (via GitHub UI or CLI)
gh pr merge --squash --delete-branch

# Or keep commits separate:
gh pr merge --rebase --delete-branch
```

## Troubleshooting

### If workflows don't trigger on PR:

Check the workflow trigger conditions:
```yaml
on:
  pull_request:
    paths:
      - '.github/workflows/*.yml'
```

The workflows only trigger when workflow files change, which they do in this PR.

### If validation script fails locally:

```bash
# Check script is executable
ls -la bin/validate-github-workflows

# Run with bash explicitly
bash bin/validate-github-workflows

# Check for syntax errors
shellcheck bin/validate-github-workflows  # if you have shellcheck
```

### If tests fail in CI:

1. Check the Actions tab logs for specific failure
2. Look for the exact error message
3. Test locally with same input data
4. Fix and push to same branch (workflows re-run automatically)

## Quick Test Checklist

Before requesting review:

- [ ] Feature branch created and pushed
- [ ] PR created with proper description
- [ ] `check.yml` workflow runs and passes
- [ ] `test-workflow-security.yml` workflow runs and passes
- [ ] Validation script reports expected issues in existing workflows
- [ ] No unexpected failures in CI
- [ ] Local testing completed (`bin/validate-github-workflows`)
- [ ] Documentation reviewed and accurate

## Next Steps After Merge

1. **Fix existing workflows:** Create follow-up PRs to fix the 5 workflows with unsafe patterns
2. **Monitor effectiveness:** Watch for the validation catching issues in future PRs
3. **Iterate:** Update validation rules if new patterns emerge
