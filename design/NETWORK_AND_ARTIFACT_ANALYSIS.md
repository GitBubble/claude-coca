# Claude Android Network and Artifact Analysis

## Scope

This report follows the next steps from `CLAUDE_ANDROID_ARCHITECTURE.md`:

1. Extract backend API endpoints.
2. Analyze network flows.
3. Study artifact rendering.
4. Prepare performance benchmarking.

The endpoint list below is based on static analysis of the decompiled APK. No live HTTPS interception has been completed yet because this workstation currently has no connected Android device or emulator, and `mitmproxy`/`mitmdump` is not installed.

## Runtime Capture Readiness

Checked locally:

- `adb`: available at `/opt/homebrew/bin/adb`.
- `adb devices`: no connected devices or emulators.
- `mitmproxy` / `mitmdump`: not installed.
- `python3`: available at `/opt/homebrew/bin/python3`.

Result: exact observed request/response bodies, cookies, headers, and timing values are pending runtime capture.

## Base URLs and API Roots

Static environment classes preserve these host roots:

- Production app host: `https://claude.ai`.
- Staging app host: `https://claude-ai.staging.ant.dev`.
- Local development host: `http://localhost:8000`.
- Android emulator local host: `http://10.0.2.2:8000`.
- Production user content host: `https://www.claudeusercontent.com`.
- Staging user content host: `https://staging.claudeusercontent.com`.
- Production MCP app content host: `https://sandbox.claudemcpcontent.com/mcp_apps`.
- Staging MCP app content host: `https://staging.claudemcpcontent.com/mcp_apps`.
- Local MCP app content host: `http://localhost:4010/mcp_apps`.

The app constructs at least two major API bases from the app host:

- `${baseUrl}/api/` for most product APIs.
- `${baseUrl}/v1/mobile/` for a separate mobile API client.

Production examples therefore resolve to paths such as:

- `https://claude.ai/api/organizations/{organization}/chat_conversations`.
- `https://claude.ai/api/organizations/{organization}/chat_conversations/{chat}/completion`.
- `https://claude.ai/v1/mobile/...` for mobile-specific services.

## Annotation Legend

The decompile keeps Retrofit-style annotations but with obfuscated names. Based on usage:

- `@gu6`: GET.
- `@i2b`: POST.
- `@eh4`: DELETE.
- `@l2b`: PATCH-like update.
- `@h2b`: PUT-like update.
- `@w67(method = "DELETE", hasBody = true)`: custom HTTP method.
- `@i87({"Accept: text/event-stream"})` plus `@qme`: server-sent event stream.
- `@w7a`: multipart form upload.

## Static Endpoint Inventory

### Authentication and App Start

Evidence: `defpackage/z39.java`, `defpackage/pza.java`, `defpackage/ptd.java`, `defpackage/p69.java`, `defpackage/d0g.java`.

| Method | Path | Purpose |
| --- | --- | --- |
| GET | `bootstrap/{organizationUuid}/app_start` | App bootstrap, growthbook/system prompt config. |
| POST | `auth/send_magic_link` | Start email magic-link login. |
| POST | `auth/verify_magic_link` | Complete magic-link login. |
| POST | `auth/verify_google_mobile` | Google mobile login verification. |
| GET | `enterprise_auth/sso_callback?code=&state=` | SSO callback verification. |
| POST | `auth/logout` | Logout. |
| GET | `auth/session_reattest/device_key/challenge` | Device re-attestation challenge. |
| POST | `auth/session_reattest/device_key` | Device re-attestation response. |
| POST | `auth/trusted_devices` | Trusted device registration. |

### Account, Legal, Usage, Settings

Evidence: `defpackage/t6.java`, `defpackage/ycg.java`, `defpackage/mq8.java`, `defpackage/ga6.java`, `defpackage/l7.java`, `defpackage/dqe.java`, `defpackage/qt3.java`.

| Method | Path | Purpose |
| --- | --- | --- |
| GET | `account` | Current account. |
| PATCH | `account` | Update account. |
| DELETE | `account` | Delete account. |
| GET | `account/deletion-allowed` | Account deletion eligibility. |
| PUT | `account/settings` | Account settings update. |
| POST | `account/grove_notice_viewed` | Mark notice seen. |
| PATCH | `account/accept_legal_docs` | Accept legal docs. |
| GET | `account_profile` | Account profile. |
| GET | `legal` | Legal docs/status. |
| POST | `accounts/me/consents/check` | Consent check. |
| POST | `accounts/me/consents/revoke` | Consent revoke. |
| GET | `organizations/{orgId}/usage` | Organization usage. |
| GET | `organizations/{organization}/feature_settings` | Feature settings. |
| GET | `organizations/{organization_uuid}/list_styles` | List style config. |

### Chat and Streaming Completion

Evidence: `defpackage/t42.java`.

| Method | Path | Purpose |
| --- | --- | --- |
| GET | `organizations/{organization}/chat_conversations` | List conversations. Query params include `consistency`, `searchQuery`, `limit`, `offset`, `starred`. |
| GET | `organizations/{organization}/chat_conversations/{chat}` | Load conversation. Query params include `rendering_mode`, `render_all_mobile_tools`, `tools`, `return_dangling_human_message`, `include_extracted_content`. |
| PATCH | `organizations/{organization}/chat_conversations/{chat}` | Update conversation metadata. |
| DELETE | `organizations/{organization}/chat_conversations/{chat}` | Delete one conversation. |
| POST SSE | `organizations/{organization}/chat_conversations/{chat}/completion` | Stream a chat completion. Uses `Accept: text/event-stream`. Body is `ChatCompletionRequest`. |
| POST SSE | `organizations/{organization}/chat_conversations/{chat}/retry_completion` | Retry completion stream. Uses `Accept: text/event-stream`. Body is `ChatCompletionRequest`. |
| POST | `organizations/{organization}/chat_conversations/{chat}/stop_response` | Stop active response. |
| POST | `organizations/{organization}/chat_conversations/{chat}/title` | Generate/update chat title. |
| POST | `organizations/{organization}/chat_conversations/move_many` | Move conversations. |
| POST | `organizations/{organization}/chat_conversations/delete_many` | Bulk delete conversations. |
| GET | `organizations/{organization_uuid}/conversation/search` | Search conversations. Query params: `query`, `n`, `project_uuid`. |
| POST | `organizations/{organization}/chat_conversations/{chat}/chat_messages/{message}/chat_feedback` | Submit message feedback. |
| PATCH | `organizations/{organization}/chat_conversations/{chat}/chat_messages/{message}/chat_feedback` | Update message feedback. |
| DELETE body | `organizations/{organization_uuid}/chat_conversations/{chat_conversation_uuid}/chat_messages/{message}/flags` | Delete a message flag with request body. |
| POST | `organizations/{organization}/chat_conversations/{chat}/tool_result` | Record tool result. |
| POST | `organizations/{organization}/chat_conversations/{chat}/tool_approval` | Record tool approval. |
| POST | `organizations/{organization_uuid}/chat_conversations/{chat_conversation_uuid}/task/{task_id}/stop` | Stop chat-attached research task. |
| GET | `organizations/{organization_uuid}/chat_conversations/{chat_conversation_uuid}/task/{task_id}/mobile_status` | Poll mobile research status. |
| POST | `organizations/{organization_uuid}/chat_conversations/{chat_conversation_uuid}/browser_sessions/current/fill_sensitive_text` | Browser session sensitive text fill. |
| POST | `organizations/{organization_uuid}/sessions/{session_id}/browser_sessions/current/fill_sensitive_text` | Session browser sensitive text fill. |
| POST multipart | `organizations/{organization}/convert_document` | Convert uploaded document. |
| POST multipart | `{organization}/upload` | Generic chat file upload. |

### Files, Wiggle, and Filestore

Evidence: `defpackage/we6.java`, `defpackage/pwg.java`, `defpackage/srb.java`, `defpackage/bk.java`, `defpackage/pc3.java`, `defpackage/m5g.java`, `defpackage/zab.java`, `defpackage/ue6.java`.

| Method | Path | Purpose |
| --- | --- | --- |
| POST | `organizations/{organization_uuid}/conversations/{conversation_uuid}/files/prepare-upload` | Prepare upload. Body is `PrepareUploadRequest`. |
| POST multipart | `/v1/filestore/fs/createFile` | Create filestore file. Includes `x-organization-uuid` header. |
| POST multipart | `organizations/{organization_uuid}/conversations/{conversation_uuid}/wiggle/upload-file` | Wiggle upload. |
| POST | `organizations/{organization_uuid}/conversations/{conversation_uuid}/wiggle/delete-file` | Wiggle delete. |
| POST | `organizations/{organization_uuid}/conversations/{conversation_uuid}/wiggle/convert-file-to-artifact` | Convert Wiggle file to artifact. |
| GET dynamic | `/api/organizations/{organization}/conversations/{conversation}/wiggle/download-file?path={path}` | Wiggle file download, built manually. |
| GET dynamic | `/api/organizations/{organization}/files/{file}/contents` | File contents, built manually. |
| GET dynamic | `/api/{organization}/files/{file}/preview` | File preview, built manually in some clients. |
| GET | `{organization}/files/{fileUuid}/preview` | File preview through API client. |

### Projects and Knowledge

Evidence: `defpackage/jwb.java`, `defpackage/lyb.java`.

| Method | Path | Purpose |
| --- | --- | --- |
| GET | `organizations/{organization_uuid}/projects_v2` | Paginated project list. Query params include `filter`, `limit`, `offset`, `searchQuery`, `starred`, `is_archived`. |
| GET | `organizations/{organization_uuid}/projects/{project_uuid}` | Project detail. |
| POST | `organizations/{organization_uuid}/projects` | Create project. |
| PATCH | `organizations/{organization_uuid}/projects/{project_uuid}` | Update project. |
| DELETE | `organizations/{organization_uuid}/projects/{project_uuid}` | Delete project. |
| GET | `organizations/{organization_uuid}/projects/{project_uuid}/conversations` | Project conversations. |
| GET | `/api/organizations/{organization_uuid}/projects/{project_uuid}/files` | Project files. |
| POST multipart | `organizations/{organization_uuid}/projects/{project_uuid}/upload` | Project file upload. |
| GET | `organizations/{organization_uuid}/projects/{project_uuid}/docs` | Project docs. |
| POST | `organizations/{organization_uuid}/projects/{project_uuid}/docs` | Create project doc. |
| DELETE | `organizations/{organization_uuid}/projects/{project_uuid}/docs/{doc_uuid}` | Delete project doc. |
| POST | `organizations/{organization_uuid}/projects/{project_uuid}/files/delete_many` | Bulk delete project files. |
| GET | `organizations/{organization_uuid}/projects/{project_uuid}/kb/stats` | Knowledge base stats. |
| POST | `organizations/{organization_uuid}/projects/{project_uuid}/kb/resync` | Knowledge base resync. |

### Artifact Sharing and Artifact Gallery

Evidence: `defpackage/to0.java`, `defpackage/t42.java`, `defpackage/zr2.java`.

| Method | Path | Purpose |
| --- | --- | --- |
| POST | `organizations/{organization}/publish_artifact` | Publish artifact. |
| POST | `organizations/{organization}/artifact-versions/{artifactId}/visibility` | Update artifact visibility. |
| DELETE | `organizations/{organization}/published_artifacts/{artifactId}` | Delete published artifact. |
| GET | `organizations/{organization}/artifacts/{conversationUuid}/versions` | Artifact versions for a conversation. Query param: `source`. |
| GET | `organizations/{organization}/user_artifacts` | User artifact gallery. Query params include `offset`, `limit`, `include_latest_published_artifact_uuid`. |
| POST | `organizations/{organization}/published_artifacts/{publishedArtifactId}/remixv2` | Remix published artifact into a chat. |
| GET | `organizations/{organization}/chat_conversations/{chat}/shares` | Conversation shares. |
| POST | `organizations/{organization}/chat_conversations/{chat}/share` | Share conversation. |
| GET | `organizations/{organization}/shares` | Share list. |
| GET | `organizations/{organization}/chat_snapshots/{snapshot}` | Snapshot detail. |
| POST | `organizations/{organization}/chat_snapshots/{snapshot}/report` | Report snapshot. |
| DELETE | `organizations/{organization}/share/{snapshot}` | Delete share. |

### Code Remote, Sessions, GitHub, and Environments

Evidence: `defpackage/nvd.java`.

| Method | Path | Purpose |
| --- | --- | --- |
| GET | `v1/sessions` | List code/remote sessions. Query params include `before_id`, `after_id`, `limit`, `tags`. |
| POST | `v1/sessions` | Create session. |
| GET | `v1/sessions/{sessionId}` | Session resource. |
| PATCH/POST | `v1/sessions/{sessionId}` | Update session. |
| POST | `v1/sessions/{sessionId}/archive` | Archive session. |
| GET | `v1/sessions/{sessionId}/events` | Event list. |
| POST | `v1/sessions/{sessionId}/events` | Send session events. |
| GET SSE | `v1/sessions/watch` | Session watch stream. |
| POST | `v1/sessions/{sessionId}/mark_read` | Mark session read. |
| GET | `v1/code/sessions/{sessionId}` | Code session detail v2. |
| POST | `v1/code/sessions/{sessionId}/client/presence` | Report client presence. |
| POST | `v1/session_ingress/session/{sessionId}/git_proxy/file` | Git proxy file. |
| POST | `v1/session_ingress/session/{sessionId}/git_proxy/compare` | Git proxy compare. |
| GET | `api/organizations/{organizationId}/code/repos/all` | Repository list. |
| POST | `api/organizations/{organizationId}/code/repos/resync` | Repository resync. |
| POST | `api/organizations/{organizationId}/code/shares/scan_secrets` | Scan code share secrets. |
| GET | `api/github/organizations/{organizationId}/github/{owner}/{repo}/branches` | GitHub branch list. Query params include `query`, `after`, `ghe_configuration_id`. |
| POST | `api/github/organizations/{organizationId}/github_create_pr` | Create GitHub PR. |
| POST | `v1/code/github/batch-branch-status` | Batch branch status. |
| POST | `v1/code/github/subscribe-pr` | Subscribe to PR. |
| POST | `v1/code/github/unsubscribe-pr` | Unsubscribe from PR. |
| POST | `v1/code/github/set-pr-auto-merge` | Set PR auto-merge. |
| GET | `v1/environment_providers/private/organizations/{organizationId}/environments` | Environment list. |
| GET | `v1/environment_providers/private/organizations/{organizationId}/environments/{environmentId}` | Environment detail. |
| POST | `v1/environment_providers/private/organizations/{organizationId}/cloud/create` | Create cloud environment. |
| GET | `v1/code/runners/self-hosted/pools` | Self-hosted runner pools. |
| POST | `api/organizations/{organizationId}/cowork/dispatch/sessions` | Create/get dispatch session. |
| POST | `api/organizations/{organizationId}/dust/generate_title_and_branch` | Generate code session title and branch. |
| GET | `v1/sessions-share/{shareId}` | Shared session data. |
| POST | `v1/sessions-share` | Create session share. |
| DELETE | `v1/sessions-share/{shareId}` | Delete session share. |
| GET | `v1/sessions/{sessionId}/share-status` | Session share status. |

### Tasks

Evidence: `defpackage/u3f.java`.

| Method | Path | Purpose |
| --- | --- | --- |
| GET | `organizations/{organization_uuid}/tasks` | Paginated task list. Query params include `limit`, `offset`, `conversation_uuid`, `statuses`. |
| GET | `organizations/{organization_uuid}/tasks/{task_uuid}` | Task detail. |
| DELETE | `organizations/{organization_uuid}/tasks/{task_uuid}` | Delete task. |
| POST | `organizations/{organization_uuid}/tasks/{task_uuid}/message` | Send task message. |
| POST | `organizations/{organization_uuid}/tasks/{task_uuid}/approve` | Approve task. |
| POST | `organizations/{organization_uuid}/tasks/{task_uuid}/reject` | Reject task. |
| GET | `organizations/{organization_uuid}/tasks/{task_uuid}/events` | Task events page. |
| GET SSE | `organizations/{organization_uuid}/tasks/{task_uuid}/stream` | Task stream. |
| GET SSE | `organizations/{organization_uuid}/tasks/{task_uuid}/events/stream` | Task event stream. Query params: `step_id`, `after`. |

### MCP and Connectors

Evidence: `defpackage/ei9.java`, `defpackage/nve.java`, `defpackage/qi9.java`, `defpackage/gz3.java`.

| Method | Path | Purpose |
| --- | --- | --- |
| GET | `organizations/{organization}/mcp/bootstrap` | MCP server bootstrap. |
| GET SSE | `organizations/{organization}/mcp/v2/bootstrap` | MCP v2 bootstrap stream. |
| GET | `organizations/{organization}/mcp/start-auth/{server}` | Start MCP auth. Query params include `product_surface`, `response_format`, `conversation_uuid`, `tool_use_id`. |
| GET | `mcp/auth_callback` | Complete MCP auth callback. Query params include `code`, `state`, `response_format`. |
| POST | `organizations/{organization}/mcp/remote_servers` | Create remote MCP server. |
| POST | `organizations/{organization}/mcp/logout/{server}` | MCP logout. |
| POST | `organizations/{organization}/mcp/attach_prompt` | Attach MCP prompt. |
| POST | `organizations/{organization}/mcp/attach_resource` | Attach MCP resource. |
| GET dynamic | Directory URL supplied at runtime | Connector directory listing. Query params include `visibility`, `sort`, `limit`, `q`, `cursor`, `category`, `type`. |
| GET/POST/DELETE | `organizations/{organization}/sync/{gmail,gcal,github,mcp/drive}/auth...` | Connector sync auth status/start/finish/delete. |
| POST | `/v1/toolbox/shttp/mcp/{...}` | Toolbox MCP service HTTP proxy, built dynamically. |
| GET/POST/DELETE | `sandbox/conway/webhooks...` and `sandbox/conway/refresh_mcp` | Conway sandbox webhook/MCP refresh. |

### Notifications and Push Tracking

Evidence: `defpackage/kia.java`, `com/anthropic/claude/firebase/fcm/AnthropicFirebaseMessagingService.java`, `com/anthropic/claude/protos/push/LoggedInPushOperationsServiceDescriptors.java`.

| Method | Path | Purpose |
| --- | --- | --- |
| GET | `organizations/{organization_uuid}/notification/preferences` | Notification preferences. |
| PUT | `organizations/{organization_uuid}/notification/preferences` | Update preferences. |
| GET | `organizations/{organization_uuid}/notification/channels` | Notification channels. |
| POST | `organizations/{organization_uuid}/notification/channels` | Update channel. |
| POST | `organizations/{organization_uuid}/notification/debug/test_push` | Send test push. |
| POST | `organizations/{organization_uuid}/notification/push/track_open` | Track opened push. |

Push operation flow is not an HTTP endpoint in the app. It arrives through Firebase Cloud Messaging and is decoded as a protobuf `PushOperationEnvelope`:

- `service`: string.
- `method`: string.
- `request`: Wire `AnyMessage`.

Known push service:

- `anthropic.claude.push.LoggedInPushOperationsService`.

Known push methods:

- `OpenChat`.
- `OpenCodeSession`.
- `OpenDispatch`.
- `OpenOrbit`.
- `ConwayWake`.

The FCM service decodes the envelope, matches the method descriptor, unpacks the typed request, and launches notification/deeplink flows into `DeepLinkActivity`.

### Voice, Orbit, Experiences, Billing, and Miscellaneous

Evidence: `defpackage/b71.java`, `defpackage/yua.java`, `defpackage/q36.java`, `defpackage/g9c.java`, `defpackage/he0.java`, `defpackage/thb.java`.

| Method | Path | Purpose |
| --- | --- | --- |
| WebSocket | `/api/ws/organizations/{organization}/phone-calls/{call}/monitor` | Voice call monitor. |
| GET | `organizations/{organization_uuid}/orbit/actions/{action_uuid}` | Orbit action. |
| GET | `organizations/{organization_uuid}/orbit/briefings` | Orbit briefings. |
| GET | `organizations/{organization_uuid}/orbit/monochat` | Orbit monochat. |
| POST/DELETE | `organizations/{organization_uuid}/orbit/insights/{insight_uuid}/feedback` | Orbit insight feedback. |
| POST | `organizations/{organization}/experiences/action` | Experience action. |
| GET | `organizations/{organization}/experiences` | Experiences. |
| POST | `organizations/{organization}/experiences/track` | Track experience. |
| POST | `google-play-iap/purchase` | Google Play purchase. |
| POST multipart | `organizations/{organization}/app_feedback` | App feedback upload. |
| POST | `auth/send_phone_code` | Phone verification start. |
| POST | `auth/verify_phone_code` | Phone verification complete. |

## Network Flow Analysis

### Chat Completion Flow

1. App loads account and app bootstrap state from `account` and `bootstrap/{organizationUuid}/app_start`.
2. Chat list is fetched with `GET organizations/{organization}/chat_conversations`.
3. A specific conversation is fetched with `GET organizations/{organization}/chat_conversations/{chat}` and mobile rendering params.
4. Sending a message calls `POST organizations/{organization}/chat_conversations/{chat}/completion` with body `ChatCompletionRequest`.
5. The completion request uses `Accept: text/event-stream` and returns an SSE stream.
6. Retry uses the same body class and `POST .../retry_completion` as an SSE stream.
7. Stop, tool approval, tool result, feedback, and title updates are separate POST/PATCH calls.

HarmonyOS implication: implement chat as a streaming-first API. The UI model should tolerate partial content blocks, tool events, artifact creation/update events, and explicit stop/retry controls.

### File and Artifact Creation Flow

1. For general chat files, the app can use multipart `POST {organization}/upload` or document conversion `POST organizations/{organization}/convert_document`.
2. Wiggle file flows use conversation-scoped endpoints: prepare upload, upload, download by path, delete, and convert file to artifact.
3. Artifact creation can arrive as part of streamed chat content/tool results. Persisted/published artifacts then use dedicated artifact endpoints for version listing, publication, visibility, gallery, and remix.
4. File preview/content URLs are sometimes constructed manually, so runtime interception must record both Retrofit-managed and manual URL requests.

HarmonyOS implication: separate the upload pipeline from artifact rendering. Do not assume every rendered artifact was created from a persisted file; some artifact content comes directly from stream/tool payloads.

### Code Remote and GitHub Flow

1. Repository selection calls `GET api/organizations/{organizationId}/code/repos/all`.
2. Branch search calls `GET api/github/organizations/{organizationId}/github/{owner}/{repo}/branches`.
3. A remote code session is created with `POST v1/sessions` and then updated/listened to through `v1/sessions/{sessionId}` and `v1/sessions/watch`.
4. Git file and compare operations go through session ingress endpoints rather than direct GitHub API URLs.
5. PR operations are first-party endpoints, not direct `api.github.com` calls.

HarmonyOS implication: model code remote as a first-party session system. GitHub is represented through Anthropic backend endpoints, so the client should not couple UI directly to GitHub REST schemas.

### MCP and Connector Flow

1. MCP bootstrap uses `organizations/{organization}/mcp/bootstrap` or streaming `mcp/v2/bootstrap`.
2. Auth starts with `mcp/start-auth/{server}` and returns callback state.
3. Auth completes at `mcp/auth_callback` or sync-specific finish endpoints.
4. Directory listing may use an absolute/dynamic URL, so capture needs to include hosts beyond `claude.ai`.
5. MCP apps render from a content host separate from the core API host.

HarmonyOS implication: treat connectors as independently authenticated backends with dynamic directory URLs and stream-capable bootstrap.

### Push Flow

1. Firebase receives notification data.
2. App parses notification JSON into `PushOperationEnvelope`.
3. Envelope `service` and `method` select a known operation descriptor.
4. Wire `AnyMessage` payload is decoded into a typed request:
   - `OpenChatRequest`: `account_uuid`, `organization_uuid`, `conversation_uuid`, `sampling_completed_timestamp`, `message_uuid`.
   - `OpenCodeSessionRequest`: `account_uuid`, `organization_uuid`, `session_id`.
   - `OpenDispatchRequest`: `account_uuid`, `organization_uuid`, `session_id`.
   - `OpenOrbitRequest`: `account_uuid`, `organization_uuid`, `conversation_uuid`.
   - `ConwayWakeRequest`: `account_uuid`, `organization_uuid`, `conway_session_id`.
5. App builds notifications/deeplinks and opens the appropriate screen.

HarmonyOS implication: keep push payload handling type-safe and route through app navigation, not ad hoc string switches in UI code.

## Artifact Rendering Model

### Artifact Data Types

Evidence: `com/anthropic/claude/artifact/model/ArtifactMetadata.java`, `com/anthropic/claude/artifact/model/ArtifactType.java`, `com/anthropic/claude/api/chat/tool/ArtifactToolInput.java`.

Artifact metadata includes:

- `uuid`.
- `versionUuid`.
- `identifier`.
- `type`.
- `title`.
- `language`.
- `isComplete`.

Artifact tool input includes:

- `id`.
- `type`.
- `title`.
- `source`.
- `command`.
- `content`.
- `md_citations`.

Supported artifact types and MIME markers:

- Code: `application/vnd.ant.code`.
- HTML: `text/html`.
- Markdown: `text/markdown`.
- Mermaid: `application/vnd.ant.mermaid`.
- React: `application/vnd.ant.react`.
- REPL: `application/vnd.ant.repl`.
- SVG: `image/svg+xml`.
- Text: `text/plain`.
- Binary document: arbitrary binary MIME type.

### Sandbox Protocol

Evidence: `anthropic/claude/usercontent/sandbox/*`.

The artifact sandbox package exists under `anthropic/claude/usercontent/sandbox`, not under the `com/anthropic/claude` source root. It defines a protobuf/Wire bridge between host and sandbox.

Wire request envelope:

- `channel`.
- `request_id`.
- `method`.
- `payload`: `AnyMessage`.

Host-to-sandbox artifact methods:

- `anthropic.claude.usercontent.sandbox.SetContent`.
- `anthropic.claude.usercontent.sandbox.RenderPublicArtifact`.
- `anthropic.claude.usercontent.sandbox.RenderSharedArtifact`.
- `anthropic.claude.usercontent.sandbox.ReportPublicArtifact`.

Host-to-sandbox REPL/tool methods:

- `anthropic.claude.usercontent.sandbox.RunCode`.
- `anthropic.claude.usercontent.sandbox.ToolExecutionHostToSandboxService.ExecuteTool`.

Sandbox-to-host system methods:

- `anthropic.claude.usercontent.sandbox.ReadyForContent`.
- `anthropic.claude.usercontent.sandbox.OpenExternal`.

`SandboxContent` fields:

- `content`.
- `type`.
- `conversation_uuid`.

This strongly indicates a message-passing sandbox architecture rather than direct native rendering for executable artifacts.

### WebView Integration and Observability

Evidence: `com/anthropic/claude/chat/bottomsheet/h.java`, `com/anthropic/claude/analytics/events/WebViewEvents$WebViewKind.java`, `com/anthropic/claude/analytics/events/WebViewEvents$WebViewRenderProcessGone.java`.

Static findings:

- Artifact rendering uses a dedicated sandbox WebView kind: `ARTIFACT_SANDBOX`.
- The app records WebView renderer process crashes as `mobile_webview_render_process_gone`.
- Artifact sandbox creation failure logs: `ChatScreenArtifactSheetHost: Failed to create Artifact SandboxWebView`.
- A `sandbox_webview_crash_count` key is updated around fallback behavior.

HarmonyOS implication: use an isolated Web component for artifact rendering, not direct injection into the chat UI. The renderer should have its own lifecycle, error boundary, crash telemetry, external link gate, and reset/fallback path.

## Performance and Observability Findings

Evidence: `defpackage/tpc.java`, `com/anthropic/claude/configs/MobileObservabilityConfig.java`, Datadog integration in app startup, WebView analytics events.

The app has a sampled network interceptor that records:

- Endpoint name/path.
- Duration in milliseconds.
- HTTP status code.
- Error type/message.
- Failure reason: network exception vs client exception.
- Cronet-specific success/failure events.

`MobileObservabilityConfig` controls:

- `network_request_sample_rate`.
- `datadog_request_trace_sample_rate`.
- `datadog_rum_profiler_sample_rate`.
- `streaming_jank_sample_rate`.

When config is absent, the network request sample path falls back to approximately `0.05`.

## Runtime Interception Plan

### Setup

1. Connect a test Android device or launch an emulator.
2. Confirm with `adb devices`.
3. Install or confirm the converted APK:
   - `adb install -r xapktool/claude-signed.apk`
4. Install a proxy tool:
   - `brew install mitmproxy`
5. Start capture:
   - `mitmdump -w phase0/captures/claude-runtime.mitm --set stream_large_bodies=10m`
6. Configure device proxy:
   - Emulator: use host `10.0.2.2`, port `8080`.
   - Physical device: use the Mac LAN IP, port `8080`.
7. Install/trust the proxy certificate on the device.
8. Clear proxy after testing:
   - `adb shell settings put global http_proxy :0`

Important caveat: Android release apps on Android 7+ usually do not trust user-added CAs unless configured to do so. A static search did not surface obvious certificate pinning classes, but TLS interception may still fail because of normal release trust rules. If capture is blocked, use an authorized rooted test device, system CA installation, or an authorized instrumentation approach. Do not bypass protections on accounts or devices without permission.

### Capture Script

Run these flows with a test account and redact credentials/tokens before saving output:

1. Cold launch app and select organization.
2. Login: magic link or Google mobile flow.
3. Load account/bootstrap/config.
4. Load chat list.
5. Open a chat.
6. Send a simple prompt and capture full SSE stream.
7. Stop and retry a response.
8. Upload a small text file and a PDF/image.
9. Convert a file to artifact.
10. Open an HTML/SVG/React/Mermaid artifact and record user content host requests.
11. Publish, change visibility, delete/unpublish an artifact if available.
12. Create or open a project, upload project knowledge, fetch project files/docs.
13. Open code remote repository selector, list repos, search branches.
14. Create/open a code session and fetch git file/compare operations.
15. Open tasks and a task stream if available.
16. Open MCP connector directory and complete a test auth flow if available.
17. Trigger/open a push notification and record `notification/push/track_open`.

### Output Artifacts

Save:

- Raw proxy capture: `phase0/captures/claude-runtime.mitm`.
- Redacted HAR: `phase0/captures/claude-runtime.redacted.har`.
- Endpoint table CSV: `phase0/captures/endpoints.csv`.
- SSE event samples: `phase0/captures/chat-completion-sse.ndjson`.
- Artifact render event log: `phase0/captures/artifact-render-events.ndjson`.
- Benchmark summary: `phase0/captures/performance-summary.md`.

## Benchmark Plan

### Metrics

Measure p50, p90, p95, and max for each operation. Run at least 10 warm and 5 cold iterations where account/rate limits allow.

App and account:

- Cold start to first usable screen.
- `bootstrap/{organizationUuid}/app_start` latency.
- Account/config fetch latency.

Chat:

- Conversation list latency.
- Conversation detail latency.
- Chat send request start to first response byte.
- Chat send request start to first visible content block.
- Inter-SSE-event gap distribution.
- Full response completion time.
- Stop-response latency.
- Retry-completion latency.
- Streaming UI jank while receiving tokens.

Files:

- Prepare upload latency.
- Filestore create latency and bytes uploaded.
- Wiggle upload latency.
- Wiggle download latency.
- File preview/content latency.
- Document conversion latency.
- Project upload and project KB resync latency.

Artifacts:

- Artifact model creation time from stream event to UI affordance.
- Sandbox WebView creation time.
- `SetContent` sent to `ReadyForContent` time.
- Artifact first paint time per type: HTML, SVG, Markdown, Mermaid, React, REPL, text.
- Renderer crash count and recovery time.
- External link/open request handling time.

Code remote and GitHub:

- Repository list latency.
- Branch search latency.
- Session creation latency.
- Session event stream connection time.
- Git proxy file latency.
- Git proxy compare latency.
- PR creation request latency.

Tasks and MCP:

- Task list/detail/event latency.
- Task stream connection time.
- MCP bootstrap latency.
- MCP v2 stream connection time.
- MCP auth start/callback latency.
- Directory listing latency.

### Tools

- Proxy timings from mitmproxy/HAR.
- `adb logcat` for app analytics/error event timestamps.
- Android Studio Profiler or `adb shell dumpsys gfxinfo com.anthropic.claude` for jank/frame timing.
- `adb shell dumpsys meminfo com.anthropic.claude` for memory snapshots around WebView/artifact rendering.
- Device screen recording for first-paint correlation if logs are insufficient.

### Benchmark Procedure

1. Reset app state or define a repeatable warm-cache state.
2. Record device model, Android version, network type, app version, and account tier.
3. Start proxy capture and logcat capture with synchronized timestamps.
4. Execute one flow at a time.
5. Mark user actions with visible timestamps or log markers.
6. Export HAR and parse timings by path family.
7. Split cold vs warm runs.
8. Report p50/p95 and failure count by operation.
9. For artifact rendering, report per MIME type and crash/retry counts.
10. Compare HarmonyOS implementation against these baseline budgets once live values exist.

## Pending Runtime Validation

The following cannot be truthfully completed without live capture:

- Exact production request headers and cookies.
- Exact request/response body examples for each endpoint.
- SSE event names and payload sequence under current production behavior.
- User content host requests made inside artifact WebViews.
- Whether TLS trust or certificate pinning blocks proxy capture.
- Actual latency, throughput, memory, and jank metrics.
- Error response formats under network failure, auth expiry, and rate limits.

## HarmonyOS Implementation Takeaways

- Build the API layer around first-party `claude.ai` endpoints and streaming SSE, not direct vendor APIs such as GitHub REST.
- Preserve typed navigation IDs for organizations, chats, sessions, tasks, projects, artifacts, and files.
- Treat artifact rendering as a sandboxed Web component with a protobuf-like host/sandbox envelope.
- Keep artifact rendering isolated from chat rendering and add explicit lifecycle telemetry.
- Implement network instrumentation from the beginning: endpoint, duration, status, failure reason, and stream timing.
- Design upload, file preview, artifact conversion, and project knowledge flows as separate pipelines.
- Use runtime interception before final API implementation because static endpoint names do not prove current response schemas.