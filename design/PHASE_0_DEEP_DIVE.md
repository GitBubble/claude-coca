# Phase 0 Deep Dive — Reverse-Engineered API Surface

**Date**: 2026-05-10
**Source**: `design/phase0/decompiled/sources/` (jadx 1.5.5 output of `com.anthropic.claude` v1.260430.10)
**Resources**: `design/phase0/decompiled-resources/` (jadx `--no-src` extraction, 16 MB)
**Analysis files**: `design/phase0/analysis/`

## Why this exists

The earlier Phase 0 report stopped at "extraction validated; install pending device". This pass actually **reads** the decompiled artifacts to recover information that informs the HarmonyOS NEXT clone:

- Real API hosts and path templates
- Module decomposition of the Android app
- Asset/resource inventory (strings, layouts, drawables, fonts)
- Confirmation of the transport stack (Connect-RPC over OkHttp + Wire/protobuf, **not** Retrofit)

## Hosts discovered

| Host | Purpose |
|---|---|
| `https://api.claude.ai` | Production API |
| `https://api.claude-ai.staging.ant.dev` | Staging API |
| `https://claude.ai` | Web base, OAuth callbacks |
| `https://claude-ai.staging.ant.dev` | Staging web |
| `https://assets.claude.ai` | Static assets, fonts |
| `https://api.anthropic.com/api/directory/servers` | MCP server directory |
| `https://www.claudeusercontent.com` | User-uploaded content (prod) |
| `https://staging.claudeusercontent.com` | User-uploaded content (staging) |
| `https://sandbox.claudemcpcontent.com/mcp_apps` | MCP sandbox apps |
| `https://staging.claudemcpcontent.com/mcp_apps` | MCP sandbox apps (staging) |
| `https://code.claude.com/docs/en/{remote-control,security}` | Code docs |
| `https://privacy.{claude,anthropic}.com/...` | Privacy / data retention |
| `https://www.anthropic.com/legal/...` | ToS, privacy |

Full list: [design/phase0/analysis/anthropic-urls.txt](design/phase0/analysis/anthropic-urls.txt).

## API path templates (90 found)

All recovered paths are organization-scoped (`organizations/{organization_uuid}/...`). Key endpoints relevant to Claude Coca's MVP:

### Chat / completion

- `organizations/{organization}/chat_conversations` — list/create
- `organizations/{organization}/chat_conversations/{chat}` — get/delete
- `organizations/{organization}/chat_conversations/{chat}/completion` — **streaming chat**
- `organizations/{organization}/chat_conversations/{chat}/retry_completion`
- `organizations/{organization}/chat_conversations/{chat}/stop_response`
- `organizations/{organization}/chat_conversations/{chat}/title`
- `organizations/{organization}/chat_conversations/{chat}/model_fallback`
- `organizations/{organization}/chat_conversations/{chat}/tool_approval`
- `organizations/{organization}/chat_conversations/{chat}/tool_result`
- `organizations/{organization}/chat_conversations/{chat}/share` / `shares`
- `organizations/{organization}/chat_conversations/delete_many` / `move_many`
- `organizations/{organization_uuid}/conversation/search`

### Projects (workspace-equivalent)

- `organizations/{organization_uuid}/projects` / `projects_v2`
- `organizations/{organization_uuid}/projects/{project_uuid}` (CRUD)
- `organizations/{organization_uuid}/projects/{project_uuid}/conversations`
- `organizations/{organization_uuid}/projects/{project_uuid}/docs[/{doc_uuid}]`
- `organizations/{organization_uuid}/projects/{project_uuid}/upload`
- `organizations/{organization_uuid}/projects/{project_uuid}/files/delete_many`
- `organizations/{organization_uuid}/projects/{project_uuid}/kb/{resync,stats}` — knowledge-base
- `organizations/{organization_uuid}/projects/{project_uuid}/files` (`/api/...` form)

### Files / artifacts

- `organizations/{organization_uuid}/conversations/{conversation_uuid}/files/prepare-upload`
- `organizations/{organization_uuid}/conversations/{conversation_uuid}/wiggle/upload-file`
- `organizations/{organization_uuid}/conversations/{conversation_uuid}/wiggle/delete-file`
- `organizations/{organization_uuid}/conversations/{conversation_uuid}/wiggle/convert-file-to-artifact`
- `organizations/{organization}/artifacts/{conversationUuid}/versions`
- `organizations/{organization}/artifact-versions/{artifactId}/visibility`
- `organizations/{organization}/publish_artifact`
- `organizations/{organization}/convert_document`

### Tasks / agent runs

- `organizations/{organization_uuid}/tasks` (list/create)
- `organizations/{organization_uuid}/tasks/{task_uuid}` (get)
- `organizations/{organization_uuid}/tasks/{task_uuid}/{approve,reject,message}`
- `organizations/{organization_uuid}/tasks/{task_uuid}/{stream,events,events/stream}`
- `organizations/{organization_uuid}/chat_conversations/{chat_conversation_uuid}/task/{task_id}/{stop,mobile_status}`

### MCP (Model Context Protocol)

- `organizations/{organization}/mcp/bootstrap` / `mcp/v2/bootstrap`
- `organizations/{organization}/mcp/remote_servers`
- `organizations/{organization}/mcp/start-auth/{server}`
- `organizations/{organization}/mcp/logout/{server}`
- `organizations/{organization}/mcp/attach_prompt`
- `organizations/{organization}/mcp/attach_resource`
- `/api/mcp/auth_callback`

### Memory / styles / orbit / experiences

- `organizations/{organization_uuid}/memory` (`memory/reset`)
- `organizations/{organization_uuid}/list_styles`
- `organizations/{organization_uuid}/orbit/{briefings,monochat}`
- `organizations/{organization_uuid}/orbit/actions/{action_uuid}`
- `organizations/{organization_uuid}/orbit/insights/{insight_uuid}/feedback`
- `organizations/{organization}/orbit/settings`
- `organizations/{organization}/experiences[/action,/track]`

### Notifications / push

- `organizations/{organization_uuid}/notification/channels`
- `organizations/{organization_uuid}/notification/preferences`
- `organizations/{organization_uuid}/notification/push/track_open`
- `organizations/{organization_uuid}/notification/debug/test_push`

### Feedback / snapshots / misc

- `organizations/{organization}/chat_snapshots/{snapshot}[/report]`
- `organizations/{organization}/chat_conversations/{chat}/chat_messages/{message}/chat_feedback`
- `organizations/{organization}/feature_settings`
- `organizations/{organization}/app_feedback`
- `organizations/{organization_uuid}/sessions/{session_id}/browser_sessions/current/fill_sensitive_text`
- `organizations/{organization_uuid}/chat_conversations/{chat_conversation_uuid}/browser_sessions/current/fill_sensitive_text`
- `organizations/{organization}/chat_conversations/{chat}/chat_messages/{message}/flags` (DELETE)

### Telemetry (Datadog)

- `/api/v2/profile`
- `/api/v2/rum`
- `/api/v2/spans`

Full list: [design/phase0/analysis/api-paths-organizations.txt](design/phase0/analysis/api-paths-organizations.txt), [api-paths-api.txt](design/phase0/analysis/api-paths-api.txt).

## Transport stack

- **HTTP**: OkHttp (`okhttp3`)
- **RPC**: Connect-RPC (`connectrpc/`) + Wire (`com.squareup.wire`)
- **Serialization**: Protobuf (Wire), kotlinx-serialization JSON
- **NOT** Retrofit (zero `@GET/@POST/@Path` annotations found in `com.anthropic.claude`)
- Streaming: SSE-style on `/completion` and task `/stream` endpoints

## Module decomposition (`com.anthropic.claude.*`)

37 top-level packages:

```
agentchat   analytics  api          app        application
artifact    audio      bell         chat       chatlist
code        configs    connector    conway     core
db          deeplink   firebase     login      mainactivity
mcpapps     models     networking   orbit      policy
project     protos     sessions     settings   stt
tasks       tool       types        ui         wear
widget
```

`api/` alone has 31 sub-packages mirroring the endpoint groups above (account, artifacts, chat, common, consent, conway, errors, events, experience, export, feature, feedback, kyc, login, mcp, memory, mobile, model, notification, orbit, project, purchase, result, share, styles, sync, tasks, trusteddevice, usage, verification, wiggle).

`api/chat/` contains 52 DTOs — `ChatCompletionEvent.java`, `ChatCompletionRequest.java`, `ChatConversation.java`, `ChatMessage.java`, `MessageImageAsset.java`, etc. — directly informative for the Claude Coca model layer.

## Resources extracted (16 MB)

Located at `design/phase0/decompiled-resources/resources/`:

- `AndroidManifest.xml` — 701 lines, 70+ permissions, full activity/service/receiver graph
- `res/values/strings.xml` — 2 073 lines (UI copy reference)
- `res/values/{colors,dimens,styles,attrs,arrays,plurals,bools,integers,public}.xml`
- `res/{layout,layout-v31,layout-v33,layout-watch}/` — XML layouts
- `res/{drawable,drawable-anydpi,drawable-night,drawable-v31,drawable-watch}/` — vector + bitmap drawables
- `res/{anim,animator,interpolator}/`
- `res/{values-night*,values-h*,values-land,values-large,values-anydpi}/` — adaptive variants
- `assets/composeResources/{claude.agentchat,claude.theme}.generated.resources/` — Compose resource bundles
- `assets/fonts/` — Anthropic Sans family (also fetched from `assets.claude.ai/Fonts/AnthropicSans-Text-{Regular,Medium,Semibold,Bold}{,-Italic}-Static.otf`)
- `assets/{highlight.min.js,token-highlight.js}` — code-block syntax highlighting
- `assets/PublicSuffixDatabase.list` — OkHttp PSL data

## What this means for Claude Coca

1. **Model HTTP client**: implement an organization-scoped client targeting `api.claude.ai` (config-switchable to staging). Path templates above can be lifted directly when an Anthropic API key is wired.
2. **Streaming**: use SSE on `/completion` (matches the `StreamEvent` shape we already defined in [entry/src/main/ets/models/domain/ModelTypes.ets](entry/src/main/ets/models/domain/ModelTypes.ets)).
3. **Repository connector**: GitHub OAuth callback path is `https://claude.ai/connect/github/callback` — relevant when designing our own flow.
4. **MCP**: Anthropic exposes a public MCP server directory (`api.anthropic.com/api/directory/servers`) and per-org MCP bootstrap; this aligns with the project plan's later phases.
5. **Visual reference**: extracted layouts/colors/strings can guide the ArkUI redesign without copying any code.

## Excluded from public repository

The following are intentionally **not** committed (size + Anthropic copyright):

- `*.apk`, `*.xapk` binaries (~80 MB total) — gitignored
- `design/phase0/decompiled/sources/` (~173 MB Java) — gitignored
- `design/phase0/decompiled-resources/sources/` (~empty stub) — gitignored

What **is** committed (work-product summaries):

- `design/phase0/analysis/*.txt` — endpoint, URL, and API-call indices
- `design/phase0/decompiled-resources/resources/AndroidManifest.xml` only
- `design/phase0/xapk-extracted/manifest.json` only
- This document and the other `design/*.md` analysis files
