# Claude Coca Project Plan

## Goal

Build a native HarmonyOS NEXT app named **Claude Coca** for AI-assisted coding on local files and remote repositories. The Android Claude XAPK is a reference artifact for installation validation and feature study only; the HarmonyOS NEXT app should be implemented natively with ArkTS/ArkUI but we can learn to how to reverse it and use it from android claude

## Current Inputs

- Workspace app plan: `project-plan.md`
- Reference package: `Claude by Anthropic_1.260430.10_apkcombo.com.xapk`
- Reference package metadata found so far:
	- App: `Claude`
	- Package: `com.anthropic.claude`
	- Version: `1.260430.10`
	- Version code: `26043010`
	- Min SDK: `29`
	- Target SDK: `36`
	- Bundle shape: XAPK zip with base APK plus density, language, and CPU split APKs

## Important Constraint

HarmonyOS NEXT does not run ordinary Android APKs as the app implementation target. The XAPK runnable check is therefore an Android/reference validation task. The production app should be a HarmonyOS NEXT project built with DevEco Studio, ArkTS, ArkUI, and HarmonyOS platform APIs.

## Product Scope

### 1. Chat And Coding Assistant

- Multi-turn chat with streaming responses.
- Code-aware prompts with file and repository context.
- Attach selected local files, folders, and repository snippets.
- Apply model-generated edits through a review screen before writing to disk.
- Keep conversation history per workspace/repository.

### 2. Repository Connections

- GitHub support first.
- Add Gitee support after the GitHub flow is stable.
- Add GitCode support after the connector abstraction is proven.
- Expected connector features:
	- OAuth or personal access token sign-in.
	- List repositories, branches, files, issues, and pull requests where available.
	- Clone or open repository content for local editing.
	- Commit changes to a branch.
	- Create pull request or merge request where the platform supports it.

### 3. Model Vendor Connections

- Anthropic: Claude Opus/Sonnet family where API access is available.
- DeepSeek: DeepSeek chat/coder models.
- GLM/Zhipu.
- MiniCPM.
- Kimi/Moonshot.
- Local or custom OpenAI-compatible endpoint if useful.
- Expected model layer features:
	- Provider registry.
	- Per-provider API key storage.
	- Model picker.
	- Streaming responses.
	- Tool/function calling abstraction where supported.
	- Capability flags for context length, image input, file input, tool use, and reasoning mode.

### 4. Local File Access

- Read and write files using HarmonyOS NEXT document/file APIs.
- Request permissions only when needed.
- Support workspace folder selection.
- Provide file tree, file viewer, and editor handoff.
- Track pending edits before saving.
- Protect against accidental overwrite by checking current file content before write.

### 5. Security And Privacy

- Store API keys and tokens in HarmonyOS secure storage.
- Never log raw tokens or complete secret-bearing headers.
- Show clear consent before sending local file content to a model provider.
- Keep provider, repository, and file permissions scoped.
- Add a local-only mode for browsing/editing files without model calls.

## Architecture Plan

### App Layers

- **UI layer:** ArkUI pages and reusable components.
- **State layer:** session state, repository state, model request state, file operation state.
- **Provider layer:** model provider interface and concrete provider clients.
- **Repository layer:** GitHub/Gitee/GitCode connectors and Git operations.
- **File layer:** HarmonyOS file picker, workspace access, read/write services.
- **Persistence layer:** secure credentials, app settings, cached repository metadata, conversation index.

### Core Interfaces

- `ModelProvider`: list models, stream response, cancel response, report capabilities.
- `RepositoryProvider`: authenticate, list repositories, read file, write branch changes, create review request.
- `WorkspaceFileService`: select folder, read file, write file, check file version, list tree.
- `ConversationStore`: create session, append messages, attach context, restore history.

## Phased Delivery

### Phase 0: Reference APK Validation

Goal: prove the supplied XAPK is structurally valid and runnable on an Android device/emulator for reference testing.

- Install `xapktool` from `https://github.com/koai-dev/xapktool.git` or use equivalent split APK tooling.
- Extract the XAPK into its split APK set.
- Install the base APK plus required splits together with `adb install-multiple` or a compatible installer.
- Confirm launch on Android SDK 29+.
- Capture package/version/device notes.
- reverse it, we got skills located in: ~/.openclaw/workspace/skills/android-reverse-engineering-skill/


Validation notes:

- Package name: `com.anthropic.claude`
- Required install shape: base APK plus matching `config.*.apk` split files.
- Likely required split choices: device ABI, screen density, and language.

### Phase 1: HarmonyOS NEXT Skeleton

Goal: create a native app shell named Claude Coca.

- Create DevEco Studio HarmonyOS NEXT project.
- Configure bundle name, app icon placeholder, signing profile, and minimum compatible SDK.
- Add main navigation:
	- Chat
	- Files
	- Repositories
	- Models
	- Settings
- Add empty-state screens and app settings store.

### Phase 2: Model Provider MVP

Goal: make the app useful with one provider before adding all vendors.

- Implement provider abstraction.
- Add one OpenAI-compatible provider adapter first for faster testing, or Anthropic first if API access is confirmed.
- Add secure API key entry.
- Add streaming chat UI.
- Add cancellation and retry.
- Add basic error states for invalid key, network failure, rate limit, and unsupported model.

### Phase 3: Local Files MVP

Goal: let the assistant read and propose edits to local files.

- Implement folder/file picker.
- Render file tree.
- Read selected files into chat context.
- Add generated edit preview.
- Apply accepted edits to files.
- Add overwrite protection and backup/recovery strategy.

### Phase 4: GitHub MVP

Goal: support direct coding workflows against GitHub repositories.

- Implementation started in `src/main/ets/repository` with provider-neutral domain types, provider interface, session state machine, credential boundary, provider registry, and GitHub adapter shell.
- Current implementation notes are in `REPOSITORY_CONNECTOR_IMPLEMENTATION.md`.
- Add GitHub auth.
- List repositories and branches.
- Browse files.
- Create branch for edits.
- Commit accepted changes.
- Open pull request.
- Add status and error handling for common GitHub API failures.

Next implementation slices:

- Add HarmonyOS HTTP client for `RepositoryHttpClient`.
- Add HarmonyOS secure-storage implementation for `CredentialStore`.
- Use the mocked repository provider for UI and unit tests before live credentials are wired.
- Complete GitHub multi-file commit creation through git blob/tree/commit/ref APIs.
- Build the repository browser UI after the app skeleton exists.

### Phase 5: Additional Repository Providers

Goal: expand the repository connector layer.

- Keep Gitee and GitCode behind the same `RepositoryProvider` interface used by GitHub.
- Add Gitee connector.
- Add GitCode connector.
- Normalize branch, commit, pull/merge request, issue, and file APIs behind the repository abstraction.
- Add provider-specific capability flags.

### Phase 6: Additional Model Vendors

Goal: support the requested model ecosystem.

- Add Anthropic models.
- Add DeepSeek models.
- Add GLM/Zhipu models.
- Add MiniCPM endpoint support.
- Add Kimi/Moonshot models.
- Add model capability metadata and provider-specific request formatting.

### Phase 7: Coding Workflow Polish

Goal: make repo and local coding feel reliable.

- Multi-file edit plan view.
- Diff viewer.
- Selective apply/reject per file or hunk.
- Conversation-to-commit summary.
- Prompt templates for explain, fix, refactor, test, and review.
- Search across workspace/repository.

### Phase 8: Testing And Release Readiness

Goal: prepare a stable test build.

- Unit tests for provider/request formatting.
- Unit tests for repository connector behavior using mocked APIs.
- File write safety tests.
- Manual test matrix across devices and network conditions.
- Security review for token handling and file consent.
- Package internal beta build.

## Immediate Next Steps

1. Create the native HarmonyOS NEXT project skeleton around the new `src/main/ets` source foundation.
2. Confirm the target HarmonyOS NEXT SDK/API version and DevEco Studio version.
3. Wire a real HarmonyOS HTTP client into `RepositoryHttpClient`.
4. Wire HarmonyOS secure storage into `CredentialStore`.
5. Finish the GitHub commit flow and repository browser UI.
6. Decide whether the first live model provider should be Anthropic or an OpenAI-compatible endpoint.

## Open Questions

- Should Claude Coca use only official provider APIs, or also support custom OpenAI-compatible proxy endpoints?
- Should repository editing happen through platform APIs first, or through a local Git implementation first?
- Which repository provider is most important after GitHub: Gitee or GitCode?
- Should the first editor be a built-in text editor, or should the app hand files off to another editor when possible?
- What login methods are acceptable for each provider: OAuth, personal access token, API key, or all of them?

# steps

1, first analyze the claude android app use xapktool to convert it to apk

2, reverse enginereering the claude apk to get to know how it works.
