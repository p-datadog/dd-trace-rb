<!--
Check out the
https://github.com/DataDog/dd-trace-rb/blob/master/docs/DevelopmentGuide.md
for guidance on how to set up your development environment,
run the test suite, write new integrations, and more.
-->

**What does this PR do?**
<!-- A brief description of the change being made with this pull request. -->

**Motivation:**
<!-- What inspired you to submit this pull request? -->

**Change log entry**
<!--
If you are a Datadog employee:

If this is a customer-visible change, a brief summary to be placed
into the change log. This will be the ONLY mention of the change in the
release notes; it should be self-contained and understandable by customers.

If you are not a Datadog employee:

You can skip this section and it will be filled or deleted during PR review.
Please do not remove this section from the PR though.
-->

**Additional Notes:**
<!--
If you used AI, have you read and understood what AI wrote?

Anything else we should know when reviewing?
-->

**How to test the change?**
<!--
Describe here how the change can be validated.
You are strongly encouraged to provide automated tests for this PR (unit or integration).
If this change cannot be feasibly tested, please explain why,
unless the change does not modify code (e.g. only modifies docs, comments).
-->

**For PRs that modify `.github/workflows/`:**
<!--
GitHub Actions workflows have elevated permissions and process user input,
requiring extra security scrutiny. Complete this checklist:
-->

- [ ] No user input embedded directly in `script:` blocks (use `env:` instead)
- [ ] Tested with realistic complex data (code blocks, quotes, newlines, special chars)
- [ ] All validation passes: `yamllint`, `actionlint`, `bin/validate-github-workflows`
- [ ] At least one successful test run (in CI or via `workflow_dispatch`)
- [ ] Proper `permissions:` declarations (minimal required permissions only)
- [ ] Actions pinned to specific SHA (not tags)
- [ ] For `issue_comment` or `pull_request_target`: security review completed

<!-- See CLAUDE.md GitHub Actions section and workflow-security-incident-report.md -->

<!-- Unsure? Have a question? Request a review! -->
