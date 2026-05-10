# Claude Android Architecture Analysis

**Date**: 2026-05-10  
**Source**: Claude by Anthropic v1.260430.10 (APK decompiled with jadx 1.5.5)  
**Status**: Architecture mapping complete; recommendations for Claude Coca design incorporated

## Executive Summary

Claude for Android is a modern, well-architected mobile application built with:
- **UI Framework**: Jetpack Compose (composable, reactive UI)
- **Architecture Pattern**: Feature-based modular structure with separation of concerns
- **Networking**: Protocol Buffers + Connect RPC (gRPC-compatible)
- **Type Safety**: Strong typing with value objects (SessionId, ChatId, ArtifactId, etc.)
- **State Management**: Coroutines-based (Kotlin)
- **Analytics**: Comprehensive event tracking across all features

The app's clean separation into feature modules and consistent use of type-safe IDs demonstrates high engineering standards. This analysis informs design decisions for Claude Coca on HarmonyOS NEXT.

## Overall Architecture

### Top-Level Module Structure

```
com.anthropic.claude/
├── conway/                    # Chat/conversation feature
├── mainactivity/              # App entry point and main container
├── orbit/                      # Secondary feature or mode
├── protos/push/               # Push notifications + protobuf definitions
├── settings/                  # User settings screens
├── tasks/                      # Task management UI
├── types/                      # Strongly-typed ID and enum definitions
├── usercontent/               # User-generated content (artifacts, code execution)
└── ui/                         # Shared UI components

+ Third-party libraries (coil, okio, androidx, connectrpc, google, squareup, etc.)
```

### Key Architectural Patterns Observed

#### 1. Feature-Based Modularity
- Separate packages for each major feature: `conway` (chat), `settings`, `tasks`, `orbit`
- Each feature likely has its own UI, state management, and data models
- Reduces coupling and enables parallel development

#### 2. Type Safety Through Value Objects
Strongly-typed IDs prevent accidental mixing of different identifier types:
```
types/strings/
├── ChatId.java                # Chat session identifier
├── MessageId.java             # Individual message identifier
├── ArtifactId.java            # Code/artifact identifier
├── ArtifactIdentifier.java    # Artifact metadata
├── SessionId.java             # App session identifier
├── AccountId.java             # User account identifier
├── ProjectId.java             # Project identifier
├── OrganizationId.java        # Organization identifier
├── ModelId.java               # Model/LLM identifier
├── FileId.java                # File identifier
├── TaskId.java                # Task identifier
└── ... (30+ more specialized IDs)
```

**Design principle**: Each ID type is a wrapper around a String, providing compile-time type safety and reducing bugs from ID misuse.

#### 3. Protocol Buffer-Based Communication

Evidence of Protocol Buffers + Connect RPC:
```
protos/push/
├── LoggedInPushOperationsService.java      # Service definition
├── OperationsClaudeRpcKt.java              # RPC stubs (Kotlin)
├── OpenChatRequest.java                    # Request message
├── OpenCodeSessionRequest.java
├── OpenDispatchRequest.java
├── OpenOrbitRequest.java
├── PushOperationEnvelope.java              # Envelope for push messages
└── ConwayWakeRequest.java                  # Chat wake request
```

**Networking model**: Uses Connect RPC (gRPC-compatible) for efficient, strongly-typed RPC calls. Push notifications drive app state updates (open chat, open code session, open dispatch, etc.).

#### 4. User-Generated Content (UGC) Handling

Artifact execution and rendering in a sandboxed environment:
```
usercontent/sandbox/
├── ClaudeCompletionRequest.java
├── ClaudeCompletionResponse.java
├── ExecuteToolRequest.java                 # Execute tool/code
├── ExecuteToolResponse.java
├── RunCodeRequest.java                     # Run user code
├── RunCodeResponse.java
├── RenderPublicArtifactRequest.java        # Render artifact
├── RenderSharedArtifactResponse.java
└── ArtifactHostToSandboxService.java       # Sandbox communication
```

**Key insight**: Code execution and artifact rendering are isolated in a sandbox, with bidirectional communication between host and sandbox (RPC-style).

#### 5. Code/Repository Integration

Evidence of GitHub integration:
```
analytics/events/
├── CodeEvents$GithubAppInstallOpened.java
├── CodeEvents$BranchListingFailed.java
├── CodeEvents$SessionCreated.java
```

**Inference**: App supports GitHub repository browsing, branch listing, and code sessions (likely for repo-based code editing).

#### 6. Comprehensive Analytics

Detailed event tracking across all features:
```
analytics/events/
├── AppStartEvents$*.java                   # App lifecycle
├── ChatEvents$*.java                       # Chat interactions
├── CodeEvents$*.java                       # Code session interactions
├── LoginEvents$*.java                      # Authentication flows
├── VoiceEvents$*.java                      # Voice features
├── MobileToolEvents$*.java                 # Mobile-specific tools
├── DispatchEvents$*.java                   # Dispatch/routing events
├── MemoryEvents$*.java                     # Memory management
├── McpEvents$*.java                        # MCP integration
└── 50+ more event categories
```

**Design implication**: Analytics are first-class citizens, with extensive event tracking for product telemetry and debugging.

#### 7. UI Layers and Responsibilities

```
ui/
├── code/                       # Code viewing/editing
│   ├── DiffLineComment.java
│   ├── PendingAskUserQuestionSelections.java
│   └── SessionInputData.java
├── mainactivity/               # Main app container
│   ├── MainActivity.java        # Entry point
│   └── AssistantOverlayActivity.java  # Floating assistant overlay
└── [settings/, tasks/, orbit/, conway/ each have UI subdirectories]
```

**Architecture**: Each feature has its own UI package with Compose composables (names obfuscated, but pattern is clear).

### Networking & API Layer

**Libraries identified**:
- **OkHttp** (`com.squareup`): HTTP client
- **Connect RPC** (`com.connectrpc`): gRPC-compatible RPC framework
- **Protocol Buffers**: Serialization format for all messages
- **Coil** (`com.coil`): Image loading library

**API communication model**:
1. Requests are built as Protocol Buffer messages
2. Connect RPC routes requests to backend services
3. Responses are streamed back (supports long-lived connections for chat streaming)
4. Push notifications via `LoggedInPushOperationsService` drive state updates

### State Management Approach

Evidence of structured state management:
- **Coroutines-based**: Async/await patterns throughout
- **Type-safe messages**: `ConwayAppScreen`, `SettingsAppScreen` (Compose composables with strongly-typed parameters)
- **Push-driven updates**: Server-sent events trigger app state changes

**Inference**: Likely uses Flow/StateFlow for reactive state management, with MVI (Model-View-Intent) or MVVM patterns.

## Features & Capabilities Observed

### Core Features

1. **Chat/Conversation (Conway)**
   - Multi-turn conversations
   - Message history
   - Stream responses (via gRPC streaming)

2. **Code Sessions**
   - Repository browsing (GitHub integration)
   - In-session code execution
   - Branch management
   - Pull request workflows

3. **Artifacts & Content**
   - Generated content rendering
   - Sandbox execution for user code/artifacts
   - Public and shared artifact support

4. **Overlays & Floating UI**
   - `AssistantOverlayActivity` suggests a floating/overlay UI mode
   - Quick access to assistant without leaving current app

5. **Tasks/Projects**
   - Task management (`tasks/` package)
   - Project-level organization
   - Likely task-to-chat association

6. **Settings & Configuration**
   - User settings screens (`settings/` package)
   - Internal settings for debugging (`settings/internal/`)
   - Model selection, preferences, account management

7. **Voice Features**
   - Voice input/output (inferred from `VoiceEvents`)
   - Speech-to-text and TTS

8. **MCP Integration**
   - Model Context Protocol support (`McpEvents$*.java`)
   - Extensible tool system

### Data Models & Types

**Entity relationships inferred from IDs**:
- Account (AccountId) → Organization (OrganizationId) → Project (ProjectId)
- Chat (ChatId) → Message (MessageId)
- Artifact (ArtifactId) → Code/rendering sessions
- Task (TaskId) → possibly linked to Chat or Project
- Session (SessionId, AppSessionId, VoiceSessionId) → contextual state

## Technology Stack Summary

| Layer | Technology |
|---|---|
| **UI Framework** | Jetpack Compose (composables) |
| **Navigation** | Decompose (arkivanov) |
| **Networking** | OkHttp + Connect RPC + Protocol Buffers |
| **Image Loading** | Coil 3 |
| **State Management** | Coroutines + Flow/StateFlow (inferred) |
| **Analytics** | Custom event tracking (comprehensive) |
| **Authentication** | OAuth/email-based (inferred from LoginEvents) |
| **Database** | Android Room (androidx.room) |
| **Async/Concurrency** | Kotlin Coroutines |
| **Logging** | Lyft Scalpel (likely) |
| **DI Framework** | Unknown (possibly Hilt or Dagger) |

## Lessons for Claude Coca (HarmonyOS NEXT)

### 1. Feature-Based Architecture
✅ **Adopt**: Organize Claude Coca into feature modules (chat, files, repositories, models, settings) mirroring Claude's structure. Reduces complexity and enables parallel development.

### 2. Strong Typing with Value Objects
✅ **Adopt**: Use ArkTS type system to create strongly-typed IDs (`ChatId`, `MessageId`, etc.) for all domain entities. Prevents accidental misuse.

### 3. Protocol Buffers for API Communication
⚠ **Evaluate**: HarmonyOS NEXT supports Connect RPC/gRPC. If targeting Anthropic API (REST-based), evaluate switching to REST with strongly-typed request/response objects. For repository APIs (GitHub, Gitee), use their native REST endpoints.

### 4. Reactive State Management
✅ **Adopt**: Build Claude Coca with reactive state patterns (StateFlow-like in ArkTS). Push-based updates enable responsive UI and simplify sync logic.

### 5. Comprehensive Analytics
✅ **Adopt** (with privacy): Implement event tracking for product telemetry. Focus on user workflows (chat sent, file edited, repo synced) rather than sensitive data.

### 6. Sandbox for User Code Execution
⚠ **Evaluate**: If Claude Coca enables code generation and execution, isolate execution in a sandboxed environment. HarmonyOS NEXT's isolation mechanisms differ from Android; design accordingly.

### 7. Multi-Platform Support
✅ **Note**: Claude Android supports multiple device types (phones, tablets, overlay). Claude Coca should support HarmonyOS tablets and potentially HarmonyOS NEXT-based devices (e.g., Huawei Pad).

### 8. Modular Dependency Injection
❓ **Unknown**: Claude's DI framework is not directly visible in decompiled code (likely Hilt/Dagger). Claude Coca should use ArkTS constructor injection or OpenHarmony's service binding for loose coupling.

## API Patterns Identified

### Service Interfaces (Inferred from Proto Definitions)

```
// Push operations (server → client)
LoggedInPushOperationsService {
  - OpenChatRequest
  - OpenCodeSessionRequest
  - OpenDispatchRequest
  - OpenOrbitRequest
}

// Chat completions (client → server)
ClaudeCompletionService {
  - ClaudeCompletionRequest → ClaudeCompletionResponse
  - SendConversationMessageRequest
}

// Artifact execution (bidirectional)
ArtifactHostToSandboxService {
  - RunCodeRequest → RunCodeResponse
  - ExecuteToolRequest → ExecuteToolResponse
  - RenderArtifactRequest → RenderArtifactResponse
}
```

## Recommendations for Claude Coca Development

### Phase 1: Architecture Foundation
1. **Define feature modules**: Chat, Files, Repositories, Models, Settings
2. **Define entity types**: Use strongly-typed IDs for all domain concepts
3. **Plan state management**: Reactive patterns (Flow-like) for UI updates
4. **Select DI framework**: Decide on HarmonyOS-compatible DI (OpenHarmony services, constructor injection, or custom)

### Phase 2: Networking & APIs
1. **Anthropic API**: Use official REST API (no gRPC needed for public API)
2. **Repository APIs**: Native REST from GitHub, Gitee, GitCode
3. **Token management**: Secure storage (HarmonyOS keychain equivalent)
4. **Error handling**: Consistent error codes and retry logic

### Phase 3: State Sync & Offline
1. **Local database**: Cache conversations, files, repository state
2. **Sync engine**: Diff-based sync for changes (code edits, chat messages)
3. **Conflict resolution**: Last-write-wins or user-selectable merge for edits

### Phase 4: UI Layers
1. **Compose-like UI**: ArkUI declarative model for components
2. **Navigation**: Stack-based for chat threads, repository browsing
3. **Overlays**: Quick-access assistant panel (similar to Claude Android's overlay)

## Decompilation Coverage & Limitations

- ✅ Package structure and feature modules clearly visible
- ✅ Type definitions (IDs, enums) mostly recoverable
- ✅ Proto definitions and service interfaces partially visible
- ⚠️ Implementation logic obfuscated (class/method names mangled)
- ⚠️ Backend API endpoints are partially recoverable from Retrofit-style interfaces; exact live headers, payloads, and timings still require runtime interception
- ❌ DI container setup not directly visible
- ❌ Database schema not visible without static analysis of migrations

## Next Steps

Follow-up static analysis has been captured in [`NETWORK_AND_ARTIFACT_ANALYSIS.md`](NETWORK_AND_ARTIFACT_ANALYSIS.md), including endpoint families, network flow maps, artifact sandbox findings, runtime interception steps, and benchmark methodology.

1. **Runtime endpoint validation**: Use network interception during app usage to capture actual API calls, request/response formats, headers, and cookies.
2. **Network flow verification**: Confirm the statically recovered Anthropic-first API paths, SSE event payloads, and GitHub-through-Claude backend patterns.
3. **Artifact sandbox validation**: Trace WebView host/sandbox messages at runtime and verify user-content host requests.
4. **Performance benchmarking**: Capture latency profiles for chat streaming, file operations, artifact rendering, project knowledge, and repository listing.

---

## Appendix: Package Tree (Top 50 Classes)

```
com.anthropic.claude/
  ├── conway/
  │   ├── ConwayAppScreen.java
  │   ├── protocol/ContentBlock.java
  │   └── [obfuscated: a.java, b.java, ...]
  ├── mainactivity/
  │   ├── MainActivity.java
  │   ├── AssistantOverlayActivity.java
  │   └── [obfuscated]
  ├── orbit/
  │   ├── OrbitInstructSheetDestination.java
  │   └── [obfuscated: a-h.java]
  ├── protos/push/
  │   ├── LoggedInPushOperationsService.java
  │   ├── ConwayWakeRequest.java
  │   ├── OpenChatRequest.java
  │   ├── OpenCodeSessionRequest.java
  │   ├── OpenDispatchRequest.java
  │   ├── OpenOrbitRequest.java
  │   └── [15+ more proto-generated classes]
  ├── settings/
  │   ├── SettingsAppScreen.java
  │   ├── internal/InternalSettingsAppScreen.java
  │   └── [obfuscated: a-j.java]
  ├── tasks/ui/
  │   ├── TasksBottomSheetDestination.java
  │   ├── TasksListOverlay.java
  │   └── [obfuscated: a-y.java]
  ├── types/
  │   ├── environment/AppEnvironment.java
  │   └── strings/
  │       ├── ChatId.java
  │       ├── MessageId.java
  │       ├── ArtifactId.java
  │       ├── SessionId.java
  │       ├── AccountId.java
  │       ├── ProjectId.java
  │       ├── OrganizationId.java
  │       ├── ModelId.java
  │       ├── FileId.java
  │       └── [30+ more typed IDs]
  ├── ui/code/
  │   ├── DiffLineComment.java
  │   ├── PendingAskUserQuestionSelections.java
  │   └── SessionInputData.java
  └── usercontent/
      ├── ErrorResponse.java
      ├── UnknownMessage.java
      └── sandbox/
          ├── ClaudeCompletionRequest.java
          ├── ClaudeCompletionResponse.java
          ├── ExecuteToolRequest.java
          ├── ExecuteToolResponse.java
          ├── RunCodeRequest.java
          ├── RunCodeResponse.java
          ├── RenderPublicArtifactRequest.java
          └── [5+ more artifact-related classes]

(+ 50+ KB of third-party library sources)
```

---

**Analysis Complete**: This report provides sufficient architectural context to inform design decisions for Claude Coca. Proceed to Phase 1 (HarmonyOS NEXT Skeleton) with confidence in the feature structure, state management patterns, and API integration approaches.
