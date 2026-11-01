# Safety Escalation

For reviewers handling reports. Language in every message to a member stays neutral, and a
member is never told who reported them.

## Levels

| Level | Examples | First response | Action |
|---|---|---|---|
| Urgent | Threat of violence, a minor on the platform, sexual exploitation | At once, however it arrives | Hold the profile, uphold the report, escalate to the owner of the service. Follow local law on reporting to the police |
| High | Asking for money, investment scams, impersonation, already married | Same working day | Hold if the evidence is credible, ask for documents |
| Normal | Inappropriate photos or messages, harassment, fake profile | Within your published target | Decide from the report and the profile |
| Low | Disagreement, unclear report | Next review session | Dismiss, or ask for details |

The response times above are a starting point. Do not publish a promise until there is staff to
keep it.

## Steps

1. Open **Review queue → Reports**. The reporter's identity is not shown, so judge the content.
2. Read the reason, details and context. Three open reports hold a profile automatically.
3. Decide:
   - **Dismiss** if nothing breaks the rules.
   - **Uphold** if it does. Then reject the profile from the queue if the member should leave.
   - **Release hold** if a held profile did nothing wrong. This restores approval.
4. Reviewers do not read conversations from the app. If evidence from a conversation is
   needed, ask the reporter for screenshots. No tool gives reviewers access to private messages,
   and none should be added without legal review.
5. Every decision writes to `auditLogs`.

## High message volume

A report with the reporter `system` and reason "High message volume" means a member passed
`suspiciousMessagesPerDay`. It is a prompt to look, not proof. Nothing happens to the member
until a reviewer decides.

## After a decision

Tell the member only what they need: "Our team reviewed your profile." Never say who reported,
how many did, or what they said.

## Records

Audit entries hold ids and action names only. Reports stay according to the retention table in
`FIREBASE_SECURITY.md`.

## Not legal advice

This procedure needs review by a lawyer in each country of operation (blocker X-4), especially
the duties around minors and the police.
