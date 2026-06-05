# AntigravityBar Design

Build a native macOS menu bar app that checks Antigravity quota for all saved Google accounts through the `antigravity-usage` CLI.

The panel stays focused. It shows one section per account and only three rows: Claude Opus, Claude Sonnet, and Gemini 3.1 Pro. Other models are ignored. Gemini 3.1 Pro can arrive as High, Low, or `gemini-pro-agent`; the app combines those rows and shows the lowest remaining value.

The app refreshes all accounts on launch, refreshes every 5 minutes, and has a manual refresh button. Emails are masked in the UI. The menu bar title shows the lowest known remaining percentage across all visible rows.

## 2026-06-05 account management update

The account list stays as a compact window menu bar panel.

Each account card gets one small trailing action cluster:

- `doc.on.doc` copies the full email address
- `chevron.down` expands a collapsed card
- `chevron.up` collapses an expanded card
- `trash` asks for native confirmation, then removes the account

Collapsed cards show only fast-scan information:

- masked email
- active badge when needed
- updated time
- one compact summary line with only the visible model percentages

Expanded cards keep the current detailed model rows.

Collapse state is remembered per account email in `UserDefaults`, so the panel restores the last expanded or collapsed state for each account.

Account add and account remove both trigger a reliable follow-up refresh. If a refresh is already in progress, the app queues one more forced refresh and runs it immediately after the current refresh finishes. This prevents stale account lists after OAuth or removal.
