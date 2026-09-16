---
name: thermos
description: "Launch both thermo-nuclear review subagents in parallel, then synthesize their findings. Use for thermos, double thermo review, or combined bug/security and code-quality branch audits."
disable-model-invocation: true
---

<!-- Adaptado desde https://github.com/cursor/plugins/tree/main/thermos (MIT, ver LICENSE en la raíz de este plugin): la orquestación original usa subagent_type propios de Cursor ("shell", "explore", "thermo-nuclear-review-subagent", "thermo-nuclear-code-quality-review-subagent"), que no existen en Claude Code. Reescrito para usar el Agent tool y los dos agentes de este mismo plugin (thermos:thermo-nuclear-review-subagent, thermos:thermo-nuclear-code-quality-review-subagent). -->

# Thermos

Run the two thermo review passes as parallel subagents, then synthesize their results.

## Workflow

1. Determine the review scope from the user request, PR, current branch, or relevant changed files.
2. Gather `git diff <base>...HEAD` (default base `main`) and the full contents of the changed files yourself with Bash/Read — no separate subagent is needed just to collect this.
3. Launch both review subagents with the Agent tool **in a single message** so they run in parallel:
   - `subagent_type: "thermos:thermo-nuclear-review-subagent"` for bugs, breakages, security, devex regressions, feature-flag leaks, and other branch-audit risks.
   - `subagent_type: "thermos:thermo-nuclear-code-quality-review-subagent"` for maintainability, structure, file-size growth, spaghetti, abstractions, and codebase-health risks.
4. Pass each subagent the same scoped diff/file context in its prompt (labeled `### Git / diff output` and `### Changed file contents`) and ask it to return prioritized findings with file references and evidence.
5. After both finish, synthesize the results with findings first, deduplicated across reviewers. Weight overlapping findings more heavily, resolve disagreements with your own judgment, and keep summaries brief.

If individual background summaries are already visible to the user, do not restate them wholesale. Surface the unified verdict, the highest-signal findings, and any remaining uncertainty.
