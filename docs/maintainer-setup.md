# Maintainer setup

Repo-scoped configuration only maintainers need. Contributors don't have to
read this.

## Required repository secrets

The Commerce Apps CAP-PR automation depends on two secrets configured under
**Settings → Secrets and variables → Actions** on this repository.

| Secret | Consumed by | Purpose |
|---|---|---|
| `GUS_SFDX_AUTH_URL` | `.github/workflows/gus-security-review.yml` | Auth for the `sf` CLI against the GUS org so the workflow can create an `ADM_Work__c` record when an external contributor submits a net-new CAP. |
| `SLACK_WEBHOOK_URL` | `.github/workflows/notify-slack-cap-pr.yml` | Incoming webhook that receives the CAP-PR canary message posted for every PR touching `**/*.zip`, regardless of author. |

If either secret is missing the corresponding workflow logs a
`::error::` line naming the missing secret and exits non-zero — the PR check
turns red so a maintainer notices immediately.

### 1. `GUS_SFDX_AUTH_URL`

The value is a single-line `force://...` SFDX auth URL produced by the
Salesforce CLI. It is bound to a specific service account and must be
regenerated whenever that account's password / token rotates.

**Generate:**

```bash
# One-time login on the maintainer's laptop against the GUS org that owns
# the ADM_Work__c object.
sf org login web \
  --instance-url https://gus.my.salesforce.com \
  --alias gus

# Print the SFDX auth URL for the just-authenticated org. This is the value
# to paste into the GitHub secret.
sf org display --target-org gus --verbose --json \
  | jq -r '.result.sfdxAuthUrl'
```

The workflow authenticates by writing the secret to a temp file and running
`sf org login sfdx-url --sfdx-url-file <file>` — the auth URL never appears on
a command line where a diagnostic dump could leak it into build logs.

**Rotation:** rerun the two commands above and update the secret. There is no
staged handoff; a stale value will surface as a red `Authenticate to GUS via
sfdx-url` step in the next PR check.

### 2. `SLACK_WEBHOOK_URL`

An Incoming Webhook URL for the dedicated CAP-PR canary channel in the
Salesforce.com Slack workspace.

**Generate:**

1. In the Salesforce.com Slack workspace, create (or reuse) a Slack App that
   owns Incoming Webhooks (`https://api.slack.com/apps` → **Create New App**
   → **From scratch**, name it e.g. `commerce-apps CAP-PR canary`).
2. Under the app's **Incoming Webhooks** feature, toggle the feature on and
   click **Add New Webhook to Workspace**. Select the target channel (a
   dedicated CAP-PR canary channel — not `#general`).
3. Copy the generated URL (`https://hooks.slack.com/services/...`) into the
   `SLACK_WEBHOOK_URL` secret on this repository.

The workflow posts payloads built with `jq --arg` / `--argjson`, so a hostile
PR title or manifest field cannot break the JSON envelope or escape into
Slack markup.

**Rotation:** delete-and-recreate the webhook in the Slack app, then update
the secret. Existing PR comments carrying the `<!-- slack-cap-notify -->`
marker will keep the workflow idempotent through the transition.

## Auto-filed GUS Work Items

When the classifier at `.github/scripts/classify-cap-pr.sh` decides a PR is
both **external-authored** and a **net-new** ISV directory,
`gus-security-review.yml` creates one `ADM_Work__c` record under:

- **Epic:** `C360 PSA: Commerce Apps - Submissions` (`a3QEE000002VGqX2AW`)
- **Product Tag:** `a1aEE000001NDFJYA4`
- **Scrum Team:** `a00EE00001Ux7RuYAJ`
- **Assignee:** `005B0000006B9w0IAC`
- **Record Type:** User Story (`0129000000006gDAAQ`)
- **Priority:** P2

Idempotency is enforced by the hidden HTML marker
`<!-- gus-security-review-wi -->` in a PR comment: if the marker is already
present, the workflow logs "already filed" and exits before touching GUS.

The Slack canary uses the equivalent marker
`<!-- slack-cap-notify -->` and posts exactly one message per PR even across
`synchronize` events.

## Why both workflows use `pull_request_target`

External CAP submissions arrive from **forks**. Under GitHub's default
`pull_request` trigger, fork-PR workflow runs get an empty `secrets.*`
context and a read-only `GITHUB_TOKEN` — meaning neither the GUS auth
step nor the Slack post nor the "drop idempotency marker" comment can
succeed on the exact PRs these workflows exist to handle.

Both workflows therefore trigger on `pull_request_target` and follow the
**fetch-but-do-not-execute** pattern:

1. Check out the base ref only (`ref: github.event.pull_request.base.sha`).
   Every script that subsequently runs — `classify-cap-pr.sh`, the inline
   `jq` payload builders, the Slack action reference — comes from the
   trusted base commit, NOT from the PR head.
2. `git fetch` the PR head into the object database
   (`+refs/pull/N/head:refs/remotes/origin/pr/N`). The head commit is now
   reachable for `git show HEAD_SHA:path` and `git diff BASE HEAD`, but
   nothing from it lands on the working tree.
3. The classifier reads the PR-head manifest via `git show`, never
   `cat manifest.json`.

**When modifying either workflow, do not add a `checkout` of `head.sha`
or any step that pipes head-provided content into `bash` / `sh` / `node`
/ `python` / etc.** Doing so would let a fork PR exfiltrate
`GUS_SFDX_AUTH_URL` and `SLACK_WEBHOOK_URL`.
