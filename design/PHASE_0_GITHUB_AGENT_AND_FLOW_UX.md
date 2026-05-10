# Phase 0 Addendum — GitHub Agent Integration & Live "Flow" UX

**Date**: 2026-05-10
**Source**: `design/phase0/decompiled/sources/com/anthropic/claude/{api/sync,sessions,connector,api/feature}/...`,
`design/phase0/decompiled-resources/resources/res/values/strings.xml`
**Companion**: [design/PHASE_0_DEEP_DIVE.md](PHASE_0_DEEP_DIVE.md)

This addendum answers two questions raised about the official Anthropic Claude Android app and translates them into a concrete plan for Claude Coca on HarmonyOS NEXT.

---

## Part 1 — How Claude "installs itself" into a user's GitHub repo

### Short answer

Claude does **not** push code, install a workflow file, or register a webhook from the device. It uses a **first‑party GitHub App** named **`claude`** (URL slug `apps/claude`). The user installs that app on selected repositories; from then on the **Anthropic backend** (not the phone) holds the installation token and acts on the repos via the standard GitHub App REST API. The phone is just an OAuth + status client.

### Evidence from the decompiled APK

**1. The GitHub App install link is hard‑coded.** Two call sites open the GitHub App installation page directly in the system browser:

```java
// design/phase0/decompiled/sources/defpackage/nd1.java
ucgVar.a("https://github.com/apps/claude/installations/new");

// design/phase0/decompiled/sources/defpackage/aq1.java
new Intent("android.intent.action.VIEW",
    Uri.parse("https://github.com/apps/claude/installations/new"));
```

The user-facing strings confirm intent:

```xml
<!-- design/phase0/decompiled-resources/resources/res/values/strings.xml -->
<string name="ccr_github_app_install_button">Install GitHub app</string>
<string name="ccr_github_app_install_button_repo_picker">Install Claude on GitHub</string>
<string name="ccr_github_app_install_description">Repo missing? Install the Claude GitHub app in a private repository to access it here.</string>
<string name="ccr_github_app_not_installed_message">The Claude GitHub app must be installed on your repository to use Claude Code. Install it to enable Claude to create branches and open pull requests.</string>
```

**2. OAuth handshake is brokered by the Anthropic backend.** The Retrofit-style interface `nve` (`com.anthropic.claude.api.sync`) exposes three GitHub endpoints under the user's own organization, plus matching ones for Gmail / Google Calendar / Drive (uniform "sync" connector pattern):

| Method | Path | Body / Response |
|---|---|---|
| `GET` | `organizations/{organization}/sync/github/auth` | `AuthStatus` (current connection state) |
| `POST` | `organizations/{organization}/sync/github/auth/start` | `StartAuthRequest` → `StartAuthResponse` (returns redirect URL) |
| `POST` | `organizations/{organization}/sync/github/auth/finish` | `FinishAuthRequest` (carries the OAuth code) |
| `DELETE` | `organizations/{organization}/sync/github/auth` | disconnect |

The flow on the phone (recovered from `wd2.java` case‑16 coroutine):

```java
// 1. Ask backend for the OAuth start URL keyed to claude.ai's redirect:
objH = pc3Var4.I.h("https://claude.ai/connect/github/callback", this);
// 2. Open it in the system browser:
((Context) obj3).startActivity(
    new Intent("android.intent.action.VIEW", Uri.parse(str17)));
// 3. After GitHub bounces back to claude.ai, backend persists tokens.
//    Phone polls AuthStatus, then the GitHub App install URL is offered.
```

So the secret is: **GitHub OAuth + GitHub App tokens live on Anthropic's servers**. The phone never sees a `Bearer ghp_…` and never calls `api.github.com` directly.

**3. All actual repo work is server-side.** Search for `api.github.com` in `com.anthropic.claude.*` returns nothing. Instead the app talks to a **`GitProxy`** on the Anthropic backend:

```
com/anthropic/claude/sessions/types/GitProxyCompareFile.java
com/anthropic/claude/sessions/types/GitProxyCompareRequest.java
com/anthropic/claude/sessions/types/GitProxyCompareResponse.java
com/anthropic/claude/sessions/types/GitProxyFileRequest.java
com/anthropic/claude/sessions/types/GitProxyFileResponse.java
com/anthropic/claude/sessions/types/CreatePullRequestRequest.java
com/anthropic/claude/sessions/types/CreatePullRequestResponse.java
com/anthropic/claude/sessions/types/RepoListResponse.java
com/anthropic/claude/sessions/types/RepoBranch.java
com/anthropic/claude/sessions/types/RepoStatus.java
com/anthropic/claude/sessions/types/RepoWithStatus.java
com/anthropic/claude/sessions/types/RepoResyncParams.java
com/anthropic/claude/sessions/types/BranchStatus.java
com/anthropic/claude/sessions/types/BranchPullRequest.java
com/anthropic/claude/sessions/types/GenerateTitleAndBranchParams.java
com/anthropic/claude/sessions/types/PrSubscriptionRequest.java
com/anthropic/claude/sessions/types/OutcomeGitInfo.java
```

`BranchStatus` carries the agent‑observed truth back to the device:

```java
// design/phase0/decompiled/sources/com/anthropic/claude/sessions/types/BranchStatus.java
class BranchStatus {
  String repo;
  String branch;
  BranchPullRequest pull_request; // nullable
  boolean branch_exists;
  int commits;
  boolean has_session_binding;
  boolean is_default_branch;
}
class BranchPullRequest {
  int number;
  int additions;
  int deletions;
  int commits;
  boolean auto_merge_enabled;
}
```

### So what is the "agent loop"?

```
┌──────────────┐  HTTPS  ┌────────────────────┐  GitHub App API  ┌────────┐
│   Android    │ ──────► │  Anthropic Backend │ ───────────────► │ GitHub │
│  (Claude UI) │ ◄────── │  (sessions / git-  │ ◄─────────────── │  Repo  │
└──────────────┘         │   proxy / agent)   │                  └────────┘
                         └────────────────────┘
                                    ▲
                                    │ webhook events
                                    │ (push / PR / check)
                                    └── trigger reactive agent runs
```

- Device opens `apps/claude` install page → user grants per‑repo permissions on GitHub.com.
- Backend stores the installation_id; agent runs use `repos/{owner}/{repo}/...` from the server.
- Agent decisions (branch creation, file edit, commit, PR open, merge) are server-side.
- Webhooks (`ccr_github_event_received` string proves this) push back into the session.
- The phone **subscribes** to a session and receives a stream of `Sdk*Event` items; it also queries `/branch-status` for compact state and shows a "Pull request created / draft / merged / closed" badge.

### Permissions implied (informational — not extracted)

The wording "create branches and open pull requests" implies the GitHub App requests:
- `contents:write` (commit, branch)
- `pull_requests:write` (open / update PR)
- `metadata:read` (list repos / branches)
- optionally `issues:write` and `checks:read`

---

## Part 2 — How the app shows a live "flow" of agent work

### Transport

Two channels run in parallel:

1. **`SessionWatchApi`** — long-lived push channel for session state (the class includes `SessionWebSocketClosedException`, indicating WebSocket).
   - `com/anthropic/claude/sessions/api/SessionWatchApi*.java`
   - `SessionWatchApi$DeletedPayload`, `ControlRequestContent`, `ControlResponsePayload` — control-plane envelopes
2. **SSE / chunked HTTP** on `chat_conversations/.../completion` and `tasks/.../events/stream` for the assistant message stream proper.

### The event vocabulary (`SdkEvent` hierarchy)

12 concrete event classes implement `SdkEvent`:

| Class | Purpose | Maps to UI |
|---|---|---|
| `SdkMessageEvent` | A new assistant or non‑assistant message arrived | append bubble |
| `SdkAssistantMessage` (content of message event) | Assistant text/thinking/tool-use payload | render markdown / "thinking" / tool chip |
| `SdkTextContent` | Plain text token chunk | streaming append |
| `SdkThinkingContent` | Hidden chain-of-thought to surface as "Claude is thinking…" | shimmer line |
| `SdkToolUseContent` | Claude invoked a tool (name + input) | tool chip with title |
| `SdkToolResultContent` / `SdkUnknownToolResult` | Tool returned | flip chip to result preview |
| `SdkToolProgressEvent` | **Mid-tool progress** (`tool_use_id`, `parent_tool_use_id`, opaque `type`) | live "…in progress" hint |
| `SdkToolUseSummaryEvent` | Final summary line for the tool call | collapsed chip with summary |
| `SdkSystemEvent` | Session lifecycle (started / ended / paused) | banner |
| `SdkControlRequestEvent` / `…CancelRequestEvent` / `…ResponseEvent` | Backend asks user to approve / cancel | modal sheet |
| `SdkEnvManagerLogEvent` | Sandbox/env manager log line | dev log |
| `SdkResultEvent` | Final result for an agent turn | "Done" + outcome chip |
| `SdkUnknownEvent` | Forward-compat fallback | ignore / log |

Plus the message-content union: `SdkMessageContent` ↔ `{SdkTextContent, SdkThinkingContent, SdkToolUseContent, SdkToolResultContent, SdkImageContent, …, SdkUnknownMessageContent}`.

### How a tool gets a human-readable hint

Two layers:

1. **Per-tool localized strings** keyed by tool name. Examples found in [strings.xml](design/phase0/decompiled-resources/resources/res/values/strings.xml):

   ```xml
   <string name="analysis_tool_analyzing">Analyzing…</string>
   <string name="calendar_events_status_searching">Searching calendar…</string>
   <string name="calendar_list_status_searching">Finding calendars…</string>
   <string name="chart_display_tool_status_loading">Loading chart…</string>
   <string name="map_display_tool_status_loading">Loading map…</string>
   <string name="recipe_display_tool_status_loading">Loading recipe…</string>
   <string name="third_party_app_tool_status_running">Running %1$s…</string>
   <string name="ccr_tool_status_in_progress">In progress</string>
   <string name="task_step_detail_terminal_in_progress">Step in progress</string>
   ```

2. **Repo-session lifecycle strings**:

   ```xml
   <string name="ccr_session_status_idle">Idle</string>
   <string name="ccr_session_status_in_progress">In progress</string>
   <string name="ccr_session_status_pr_draft">Pull request draft</string>
   <string name="ccr_session_status_pr_created">Pull request created</string>
   <string name="ccr_session_status_pr_merged">Pull request merged</string>
   <string name="ccr_session_status_pr_closed">Pull request closed</string>
   <string name="ccr_github_event_received">GitHub event received</string>
   <string name="ccr_diff_empty_description">This branch hasn't diverged from main. Changes will appear here after Claude makes edits.</string>
   ```

So the "flow" the user sees is the deterministic result of:

```
SdkToolUseContent(name="bash", input={cmd:"git diff …"})
   ⇒ chip "Running bash …" (or specialized string if tool name matches a key)

SdkToolProgressEvent(tool_use_id=…)
   ⇒ keep chip in "in progress" state, animate the dot

SdkToolUseSummaryEvent
   ⇒ collapse chip to "Read package.json" / "Edited 3 files"

webhook → SessionWatch push → BranchStatus refresh
   ⇒ swap badge to "Pull request created (#42, +120 −7)"
```

### Polling vs push

- **Push**: WebSocket via `SessionWatchApi` for high-fidelity event stream while the chat is open.
- **SSE** for in-flight chat completions.
- **Push notifications** (`organizations/.../notification/push/*`) wake the app when a long-running session finishes while the app is closed.
- **Periodic batch polling** (`GetBatchBranchStatusRequest`) coalesces branch state for a list view.

---

## Part 3 — Plan to do the same thing in Claude Coca (HarmonyOS NEXT)

We mirror Claude's three-tier model: **(a) GitHub App for trust, (b) Coca backend for OAuth + agent loop, (c) ArkTS client for OAuth handoff + live event rendering**. Crucially, we keep all GitHub credentials off-device.

### Tier A — Register a GitHub App "Claude Coca"

One-time owner action:

1. Create a new GitHub App on github.com with slug `claude-coca`.
2. Permissions: `contents:write`, `pull_requests:write`, `issues:write`, `metadata:read`, `checks:read`.
3. Subscribe to webhook events: `push`, `pull_request`, `check_suite`, `installation`, `installation_repositories`.
4. Set:
   - User authorization callback URL: `https://api.claude-coca.app/connect/github/callback`
   - Setup URL (post-install): `https://api.claude-coca.app/connect/github/installed`
   - Webhook URL: `https://api.claude-coca.app/webhooks/github`
5. Install URL becomes `https://github.com/apps/claude-coca/installations/new`.
6. Store App ID + private key in the backend secrets store. Use `octokit` / `go-github` to mint installation tokens on demand.

(Until Tier B exists, Tier C can be tested against a stub returning canned events.)

### Tier B — Coca backend service

Endpoints (mirroring the proven Claude shape, but self-hosted):

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/organizations/{org}/sync/github/auth` | `{ status: connected\|disconnected, login: …, installations: […] }` |
| `POST` | `/organizations/{org}/sync/github/auth/start` | `{ redirect_uri }` → returns OAuth URL |
| `POST` | `/organizations/{org}/sync/github/auth/finish` | `{ code, state }` → exchanges for user OAuth token |
| `DELETE` | `/organizations/{org}/sync/github/auth` | revoke |
| `GET` | `/organizations/{org}/repos` | `RepoWithStatus[]` |
| `GET` | `/organizations/{org}/repos/{repo}/branches` | `RepoBranch[]` |
| `POST` | `/organizations/{org}/sessions` | create agent session bound to `(repo, base_branch, prompt)` |
| `GET` | `/organizations/{org}/sessions/{id}/events?after={cursor}` | replay events |
| `WS` | `/organizations/{org}/sessions/{id}/watch` | push `SdkEvent` stream |
| `GET` | `/organizations/{org}/sessions/{id}/branch-status` | compact `BranchStatus` |
| `POST` | `/organizations/{org}/sessions/{id}/pr` | create / update PR |
| `POST` | `/webhooks/github` | GitHub → us; fans into session topic |

Server responsibilities:

- Hold per-org GitHub installation tokens (mint via JWT-signed App credentials).
- Run the agent loop: prompt the LLM, execute tool calls in a sandbox, push diffs to a working branch via the GitHub App, open a PR.
- Translate GitHub webhooks into `SdkSystemEvent` / `BranchStatus` updates pushed over the open WebSocket.
- Deliver Push Kit / APNs-style push when the device is offline.

(The server itself is out of scope for the ArkTS app; the app should be designed against this contract so a stub can be swapped for the real service.)

### Tier C — Claude Coca ArkTS app changes

Build on the existing `entry/src/main/ets/repository/...` connector skeleton.

**C.1 New module: `entry/src/main/ets/agent/`**

```
agent/
  domain/
    SdkEvent.ets             // discriminated union (text|thinking|tool_use|tool_progress|tool_summary|system|control|result|unknown)
    SessionStatus.ets        // enum: IDLE, IN_PROGRESS, PR_DRAFT, PR_CREATED, PR_MERGED, PR_CLOSED, ERROR
    BranchStatus.ets         // mirrors Anthropic's BranchStatus / BranchPullRequest
    ToolHint.ets             // { toolName, defaultLabel, runningLabel, completedLabelTemplate }
  transport/
    SessionWatchClient.ets   // WebSocket wrapper (HarmonyOS @ohos.net.webSocket); reconnect + heartbeat
    SessionEventStream.ets   // SSE fallback for /events/stream (HarmonyOS @ohos.net.http or rcp)
    GitHubAuthClient.ets     // wraps the 4 sync/github/auth endpoints
    PushSubscriber.ets       // @ohos.pushManager registration; backend stores token
  state/
    SessionFlowStore.ets     // @ObservedV2 store: messages[], inflightTool?, sessionStatus, branchStatus
    ToolHintRegistry.ets     // map tool name → localized hint (loaded from resource.json)
  ui/
    ConnectGitHubPage.ets    // 3-step: Sign-in → Install App → Pick repo
    RepoPickerSheet.ets      // RepoWithStatus list with re-open install link
    SessionFlowList.ets      // renders SdkEvent stream as chips/messages
    ToolChipComponent.ets    // 3 visual states: pending → running (shimmer) → done
    BranchStatusBadge.ets    // "PR #42 draft (+120 −7)" pill
```

**C.2 Connect-to-GitHub flow (mirrors Claude's 3-step UX)**

```
┌─────────────────────────────┐    ┌─────────────────────────────┐
│ ConnectGitHubPage.ets       │    │ Coca backend                 │
│  [Connect to GitHub]   ────►│    │  POST /sync/github/auth/start│
│                             │◄───│   { redirect_uri }           │
│  open in HarmonyOS browser  │    │                              │
│  (Want.startAbility VIEW)   │    │   GitHub → /finish           │
│                             │    │                              │
│  poll GET /sync/github/auth │◄───│   AuthStatus: connected      │
│                             │    │                              │
│  [Install Claude Coca app] ─┼───►│  open https://github.com/    │
│                             │    │  apps/claude-coca/installa-  │
│                             │    │  tions/new in browser        │
│                             │◄───│   webhook → installations    │
│                             │    │                              │
│  GET /repos → RepoPicker    │    │                              │
└─────────────────────────────┘    └─────────────────────────────┘
```

ArkTS skeleton:

```typescript
// entry/src/main/ets/agent/transport/GitHubAuthClient.ets
export interface AuthStatus {
  status: 'disconnected' | 'connected';
  login?: string;
  installation_count: number;
}

export class GitHubAuthClient {
  constructor(private readonly http: RepositoryHttpClient,
              private readonly orgId: string) {}

  async getStatus(): Promise<AuthStatus> { /* GET /sync/github/auth */ }
  async startAuth(): Promise<string>     { /* POST .../start, return redirect URL */ }
  async finishAuth(code: string, state: string): Promise<void> { /* … */ }
  async disconnect(): Promise<void>      { /* DELETE … */ }
  installAppUrl(): string {
    return 'https://github.com/apps/claude-coca/installations/new';
  }
}
```

**C.3 Live "flow" rendering**

```typescript
// entry/src/main/ets/agent/state/SessionFlowStore.ets
@ObservedV2
export class SessionFlowStore {
  @Trace messages: SdkMessage[] = [];
  @Trace inflightTools: Map<string, ToolInflight> = new Map();
  @Trace sessionStatus: SessionStatus = SessionStatus.IDLE;
  @Trace branchStatus?: BranchStatus = undefined;

  apply(event: SdkEvent): void {
    switch (event.kind) {
      case 'message':       this.appendMessage(event.message); break;
      case 'tool_use':      this.startTool(event); break;
      case 'tool_progress': this.bumpTool(event.toolUseId); break;
      case 'tool_summary':  this.completeTool(event); break;
      case 'system':        this.applySystem(event); break;
      case 'control':       this.queueControl(event); break;
      case 'result':        this.sessionStatus = SessionStatus.IDLE; break;
      default: break;
    }
  }
}
```

```typescript
// entry/src/main/ets/agent/ui/ToolChipComponent.ets
@Component
export struct ToolChipComponent {
  @Prop tool: ToolInflight;

  build() {
    Row() {
      if (this.tool.state === 'running') {
        LoadingProgress().width(16).height(16); // built-in shimmer
      } else if (this.tool.state === 'done') {
        Image($r('app.media.ic_check')).width(16);
      }
      Text(ToolHintRegistry.label(this.tool.name, this.tool.state))
        .fontSize(13)
    }
    .padding({ left: 12, right: 12, top: 6, bottom: 6 })
    .borderRadius(12)
    .backgroundColor($r('app.color.tool_chip_bg'))
  }
}
```

**C.4 Tool hint registry (maps Claude's localized pattern)**

`entry/src/main/resources/base/element/string.json` will contain:

```json
{ "name": "tool_bash_running",   "value": "Running shell…" }
{ "name": "tool_bash_done",      "value": "Ran %s" }
{ "name": "tool_read_running",   "value": "Reading %s…" }
{ "name": "tool_edit_running",   "value": "Editing %s…" }
{ "name": "tool_search_running", "value": "Searching %s…" }
{ "name": "tool_grep_running",   "value": "Searching code for \"%s\"…" }
{ "name": "tool_pr_open_running","value": "Opening pull request…" }
{ "name": "session_status_in_progress", "value": "In progress" }
{ "name": "session_status_pr_draft",    "value": "Pull request draft" }
{ "name": "session_status_pr_created",  "value": "Pull request created" }
{ "name": "session_status_pr_merged",   "value": "Pull request merged" }
```

`ToolHintRegistry` exposes `label(name, state, ...args): Resource | string` and falls back to `Running %s…` for unknown tools (matches `third_party_app_tool_status_running`).

**C.5 WebSocket transport on HarmonyOS NEXT**

```typescript
// entry/src/main/ets/agent/transport/SessionWatchClient.ets
import webSocket from '@ohos.net.webSocket';

export class SessionWatchClient {
  private ws: webSocket.WebSocket | null = null;
  private retryDelayMs = 1000;

  connect(url: string, onEvent: (e: SdkEvent) => void): void {
    this.ws = webSocket.createWebSocket();
    this.ws.on('message', (_err, raw: string | ArrayBuffer) => {
      const text = typeof raw === 'string' ? raw : new TextDecoder().decode(raw);
      onEvent(SdkEvent.parse(text));
    });
    this.ws.on('close', () => this.scheduleReconnect(url, onEvent));
    this.ws.connect(url, { header: { Authorization: `Bearer ${this.token}` } });
  }

  private scheduleReconnect(url: string, cb: (e: SdkEvent) => void): void {
    setTimeout(() => this.connect(url, cb), this.retryDelayMs);
    this.retryDelayMs = Math.min(this.retryDelayMs * 2, 30000);
  }
}
```

SSE fallback uses `@ohos.net.http`'s `requestInStream` to stream the `text/event-stream` body and split on `\n\n`.

**C.6 BranchStatus badge polling**

While a session is open and viewed, poll `/sessions/{id}/branch-status` every 8 s as a low-cost belt-and-braces source. Server pushes via WebSocket are authoritative; the poll just smooths over reconnect gaps. Mirror the Anthropic shape exactly: `repo`, `branch`, `pull_request{ number, additions, deletions, commits, auto_merge_enabled }`, `branch_exists`, `commits`, `has_session_binding`, `is_default_branch`.

---

## Part 4 — Sequencing into existing project plan

Suggested phases (additive to [project-plan.md](project-plan.md)):

1. **Phase 4a — Agent event domain & flow store**
   - Define `SdkEvent` discriminated union, `SessionFlowStore`, `ToolHintRegistry`.
   - Stub event source that replays a canned JSON to drive UI development.

2. **Phase 4b — Connect-to-GitHub UX (offline)**
   - `ConnectGitHubPage` + `RepoPickerSheet` with mocked `GitHubAuthClient`.
   - Wire the "Install Claude Coca on GitHub" button to `Want` browser launch.

3. **Phase 5a — Backend service skeleton**
   - Implement the 12 endpoints above behind a feature flag.
   - Standalone Go/Node service (out of this repo or under `service/` if we expand scope).

4. **Phase 5b — Real WebSocket + SSE wiring**
   - Replace mocks with `SessionWatchClient` / `SessionEventStream`.
   - Add reconnect, replay (`?after={cursor}`), and Push Kit wake-up.

5. **Phase 5c — Branch & PR badges**
   - Render `BranchStatusBadge`; subscribe to `pr_*` system events; map to localized status.

6. **Phase 6 — Hardening**
   - Sandbox tool execution, rate limiting, credential rotation, audit log.

---

## Appendix — File pointers used in this analysis

- API interface: `design/phase0/decompiled/sources/defpackage/nve.java`
- OAuth coroutine: `design/phase0/decompiled/sources/defpackage/wd2.java` (case 16, lines ~1170–1190)
- Install URL handlers: `design/phase0/decompiled/sources/defpackage/nd1.java`, `aq1.java`
- Branch status types: `design/phase0/decompiled/sources/com/anthropic/claude/sessions/types/{BranchStatus,BranchPullRequest,GetBatchBranchStatusResponse}.java`
- Sdk event types: `design/phase0/decompiled/sources/com/anthropic/claude/sessions/types/Sdk*.java`
- Session watch (WebSocket): `design/phase0/decompiled/sources/com/anthropic/claude/sessions/api/SessionWatch*.java`
- Localized hint strings: `design/phase0/decompiled-resources/resources/res/values/strings.xml` (`ccr_*`, `*_tool_status_*`, `*_tool_*ing*`)
- Integration enum (proves Slack/Salesforce/Asana/Outline use the same `sync/*/auth` shape): `design/phase0/decompiled/sources/com/anthropic/claude/api/feature/IntegrationType.java`
