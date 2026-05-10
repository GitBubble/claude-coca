# Repository Connector Implementation Start

## What Exists Now

Initial ArkTS source scaffolding has been moved under `entry/src/main/ets` for the GitHub/Gitee/GitCode repository feature.

Created modules:

- `repository/domain`: provider-neutral repository, branch, file, commit, issue, review request, credential, and error types.
- `repository/providers`: the provider interface, HTTP-client abstraction, provider registry, and first GitHub adapter shell.
- `repository/providers/mock`: in-memory provider for repository UI work and tests before live HTTP wiring.
- `repository/providers/gitee` and `repository/providers/gitcode`: placeholders that keep provider priority explicit while GitHub is validated first.
- `repository/session`: code-session state machine for repo selection, branch selection, context loading, diff review, commit, and review-request creation.
- `repository/context`: repository context bundle helper for selected remote files/ranges.
- `security`: credential store interface that keeps raw tokens behind a secure-storage boundary.

## Implementation Direction

The code uses direct provider APIs for Claude Coca rather than the Anthropic backend-mediated GitHub endpoints seen in the Android reference. This keeps GitHub, Gitee, and GitCode on one provider-neutral interface.

The GitHub provider currently covers:

- Authenticate token by calling `/user`.
- Validate session.
- List repositories.
- List branches.
- Resolve default branch.
- List repository tree entries through the GitHub contents API.
- Read file contents through the GitHub contents API.
- Compare refs.
- Create branches.
- Create pull requests.
- List issues.
- List pull requests.

Queued next slice:

1. Add a real HarmonyOS HTTP client implementing `RepositoryHttpClient`.
2. Add a real HarmonyOS secure-storage implementation for `CredentialStore`.
3. Implement GitHub multi-file commit creation using GitHub git blobs, trees, commits, and ref update APIs.
4. Add Gitee and GitCode adapters after the GitHub contract stabilizes.

## Safety Notes

- `RepositoryCredential` stores only `tokenRef`; raw tokens are only passed through short-lived `RepositoryAuthContext`.
- Provider errors are normalized through `RepositoryException` and `RepositoryErrorCode`.
- The session state machine keeps base commit SHA in state so commit conflict checks can be enforced before remote writes.