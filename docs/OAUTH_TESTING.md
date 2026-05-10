# OAuth Testing Checklist

Claude Coca uses the **OAuth 2.0 Device Authorization Grant** (RFC 8628)
for the three repository providers. This is the right pattern for an
installed HarmonyOS app: no client secret, no redirect URI, no
deep-link plumbing.

The whole flow is exercised end-to-end on a device. The unit tests under
`entry/src/ohosTest/ets/test/` cover the URL/body shapes, the response
parsers, the polling state machine (including back-off, expiration, and
cancellation), and the credential store round-trip — but they cannot
verify that the provider's OAuth app is wired up correctly. That happens
here.

## 1. Register an OAuth application

Each provider must be told that Claude Coca exists. **Only the public
`client_id` is needed** — Device Flow does not require a client secret,
which is what makes it safe to ship in an installed app.

| Provider | Where to register |
| --- | --- |
| GitHub  | https://github.com/settings/developers → "New OAuth App" → enable "Device Flow" |
| Gitee   | https://gitee.com/profile/applications → "Create application" → tick the device flow scope |
| GitCode | https://gitcode.com → developer console → register an OAuth app and confirm device flow is offered |

> **GitCode / Gitee — verify Device Flow availability.** GitHub
> documents Device Flow explicitly. The GitCode and Gitee endpoints in
> `entry/src/main/ets/oauth/OAuthConfig.ets` follow the standard RFC 8628
> shape; if a provider's developer console shows different paths, update
> the constants in `OAuthConfig.ets` accordingly. If Device Flow is not
> offered at all, fall back to the Authorization Code + PKCE flow (a
> follow-up — see the original PR #1 description).

When the OAuth app is created, copy the public client ID.

## 2. Paste the client ID into Claude Coca

1. Launch the app on a HarmonyOS device or emulator.
2. Tap **Settings → Connector**.
3. Scroll to **OAuth client IDs**.
4. Paste the client ID into the field for the provider you registered.
   (You only need to fill in providers you intend to sign in with.)
5. Return to the welcome screen.

The IDs are stored in `AppSettings.oauthClientIds`. They are not baked
into the source code — different builds and forks can point at their
own OAuth apps without code changes.

## 3. Sign in

1. From the welcome screen tap **Continue with GitHub** (or GitCode /
   Gitee).
2. The modal should appear with:
   - A `user_code` (e.g. `WDJB-MJHT`).
   - A **Copy code** button.
   - An **Open verification page** button (uses `startAbility` with
     `ohos.want.action.viewData`).
   - A live status line ("Waiting for you to authorize on GitHub
     (polling every 5s)…").
3. Tap **Open verification page**, paste the user code, and approve the
   app on the provider's web page.
4. Within one polling interval the modal should disappear and the app
   should navigate to **Workspace**.

If the modal stays on `authorization_pending` indefinitely, check that
the verification page on the provider site actually authorized the app
— some providers require a second confirmation step.

## 4. Confirm the workspace uses the live token

After a successful sign-in:

- The status banner on the welcome screen reads `Signed in to <provider>`.
- The workspace's `RepositoryAuthContext` is now resolved from
  `RepositoryCredentialStore.readActiveCredential(...)` instead of the
  hard-coded `MOCK_CREDENTIAL`. The mock provider is still registered,
  so the on-screen file list will continue to show the mock data — but
  the bearer token in `authContext.accessToken` is the real one.
- To prove this end-to-end, register a real `RepositoryProvider`
  implementation (`GitHubProvider`, `GiteeProvider`, `GitCodeProvider`)
  in `AppServices.ets` instead of (or alongside) `MockRepositoryProvider`,
  and verify a network call carries an `Authorization: Bearer …` header
  that matches the captured token.

## 5. Sad-path checks

The unit tests already cover these in isolation, but a quick on-device
walk-through is worthwhile:

- [ ] Cancel the modal mid-poll → state ends in `Cancelled`, no token
      stored.
- [ ] Decline the OAuth grant on the provider page → modal shows
      "Authorization was declined" (`AccessDenied`).
- [ ] Wait past `expires_in` (typically 15 minutes) without entering the
      code → modal shows "The device code expired before authorization
      was completed" (`ExpiredToken`).
- [ ] Toggle airplane mode mid-flow → modal shows a `Network` error.
- [ ] Clear the GitHub client ID from Settings and retry → modal
      surfaces `MissingClientId` immediately, no HTTP traffic issued.

## 6. Where to look in the code

| Concern | File |
| --- | --- |
| State machine | `entry/src/main/ets/oauth/OAuthService.ets` |
| URL/body builders, response parsers | `entry/src/main/ets/oauth/OAuthParsing.ets` |
| Per-provider endpoints + scopes | `entry/src/main/ets/oauth/OAuthConfig.ets` |
| HTTP transport (mockable) | `entry/src/main/ets/oauth/OAuthHttpAdapter.ets` |
| Persisted credentials | `entry/src/main/ets/security/RepositoryCredentialStore.ets` |
| Welcome screen + modal | `entry/src/main/ets/pages/Index.ets` |
| Connector settings (client IDs) | `entry/src/main/ets/pages/Settings.ets` |
| Hypium tests | `entry/src/ohosTest/ets/test/` |
