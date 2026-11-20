# cinema_app

Online cinema — a Flutter **Web PWA**: catalog of movies and series, HLS/MP4 player with watch progress, series subscriptions with a daily Web Push digest, and an admin panel. Backend: **Supabase** (Postgres + RLS + RPC, Auth, Storage, Edge Functions, pg_cron).

## Tech stack

| Area | Choice | Why |
|---|---|---|
| Platform | Flutter Web (PWA) | Web is the only target for now; `android/` and `ios/` exist but are not maintained |
| Architecture | Feature-first, layers `data` / `domain` / `presentation` | Features stay isolated; dependency direction is checked automatically |
| State management | **Bloc / Cubit** (`flutter_bloc`) | Explicit, testable state transitions (`bloc_test`), one immutable state per screen, a standard pattern every contributor knows. **Cubit by default**; `Bloc` + `bloc_concurrency` only where event transformers are needed (search debounce, player events) |
| Routing | `go_router` + path URL strategy | Deep links without `#`, guards via `redirect` |
| Backend SDK | `supabase_flutter` (added in card 3.5) | |
| Models | **`equatable` + manual `fromJson`/`toJson` mapping** | No code generation to maintain; revisit `json_serializable` only if DTO mapping gets heavy |
| Lints | `very_good_analysis` | Strict casts/inference/raw types and ~200 rules; `public_member_api_docs` is off (app, not a package) |
| Tests | `flutter_test`, `bloc_test`, `mocktail`, `integration_test` | |

## Project structure

```
lib/
  main.dart              bootstrap only: URL strategy, BlocObserver, runApp
  app/                   CinemaApp widget, router factory (DI wiring later)
  core/
    bloc/                AppBlocObserver (debug logging of state changes/errors)
    config/              env config (String.fromEnvironment)
    errors/              domain failures
    l10n/                AppStrings — all user-facing (Russian) strings
    router/              AppRoutes — single source of route paths
    supabase/            Supabase client init
    ui/                  shared widgets (NotFoundPage; theme, breakpoints, ui-kit later)
    utils/
  features/
    <feature>/           auth, catalog, title, player, subscriptions,
      data/              profile, admin, push, about
      domain/
      presentation/      cubit|bloc/, pages/, widgets/
test/                    mirrors lib/
integration_test/        critical e2e flows (one file per flow)
test_driver/             integration_test driver for web
```

Every feature has all three layer folders from the start. Empty folders contain an empty `.gitkeep`; the card that adds the first real file to a folder deletes it.

### Layer rules

Dependency direction: `presentation → domain ← data`.

| Layer | May import | Must not import |
|---|---|---|
| `domain` | own domain, `core` (non-UI), `package:flutter/foundation.dart` | Flutter UI, `data`, `presentation`, backend SDKs, bloc packages |
| `data` | `domain`, own `data`, `core`, `core/supabase`, backend SDKs | Flutter UI, `presentation`, bloc packages |
| `presentation` cubit/bloc | `domain`, `core`, bloc packages | `data`, Flutter UI, backend SDKs |
| `presentation` pages/widgets | `domain`, cubits/blocs, `core`, `core/ui`, Flutter, `go_router` | `data`, backend SDKs, `Supabase.instance` |
| `core` (non-UI) | `core`, backend SDKs | `features/`, `app/`, `core/ui` |

- A feature never imports another feature's `data/` or `presentation/`; share through `core/` or a domain interface.
- Only `main.dart` and `app/` import `app/`.
- `dart:html`, `dart:js`, `package:js` are forbidden — use `dart:js_interop` + `package:web`.
- Blocs depend on repository interfaces injected via constructor; pages are thin.
- Rules are enforced by `node ~/.claude/scripts/arch-check.js` (local hooks and the gate).

## Routing

- `usePathUrlStrategy()` in `main.dart`: URLs look like `/about`, not `/#/about`.
- All paths are constants in `lib/core/router/app_routes.dart` (`AppRoutes`); the router is built by `createRouter()` in `lib/app/router.dart`. Unknown paths render `NotFoundPage`.
- Hosting must rewrite every path to `index.html` (SPA fallback), otherwise a direct URL or reload returns 404. Configured in card 0.6.
- Filter and season state lives in query parameters; auth/admin guards are added via the router `redirect`.

## Environments

Config is baked in at compile time via `--dart-define-from-file` and read only in `lib/core/config/` (`EnvConfig`). Keys: `SUPABASE_URL`, `SUPABASE_ANON_KEY`.

| Env | File | Target |
|---|---|---|
| dev | `env/dev.json` | local Supabase `http://127.0.0.1:54321` |
| prod | `env/prod.json` | Supabase Cloud |

- `env/dev.json` and `env/prod.json` are gitignored; only `env/example.json` (placeholders) is tracked. Copy `env/example.json` to `env/dev.json` / `env/prod.json` and fill the values.
- Values come from `npx supabase status` (local, after card 0.3) and Supabase dashboard → Project Settings → API (prod, after card 0.4).
- The placeholder `env/prod.json` builds but does not work — never deploy it before card 0.4 fills real values.
- Only the public anon key goes here. Service role, TMDB and VAPID private keys never.
- Running without defines does not crash; in debug mode a warning names the missing keys.

## Lints

`analysis_options.yaml` includes `package:very_good_analysis/analysis_options.yaml`. Generated files (`*.g.dart`, `*.freezed.dart`) and platform folders are excluded. Code must pass `flutter analyze` with no issues. Deviations from `very_good_analysis`: `public_member_api_docs` is off (app code, not a package) and `unnecessary_type_name_in_constructor` is off — constructors use the classic `const ClassName({super.key})` form, not the Dart 3.13 `const new(...)` form. All other Dart 3.13 features are fine to use.

## Commands

```bash
flutter pub get
flutter run -d chrome --dart-define-from-file=env/dev.json   # dev
flutter analyze
dart format .
flutter test                                            # unit + widget tests
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/app_smoke_test.dart -d chrome   # e2e (needs chromedriver on :4444)
flutter build web --release --dart-define-from-file=env/prod.json   # production build
```

## Contributing

- One Trello card = one branch = one PR. Branches: `feature/<card>-<slug>`, `fix/<card>-<slug>`, `chore/<slug>`.
- Commits follow Conventional Commits (`feat(scope): ...`, `fix`, `refactor`, `test`, `docs`, `chore`, `build`); the body references the card.
- Never commit directly to `main`.
- Each PR description lists the card, acceptance criteria and test cases (see `.github/pull_request_template.md`).
- Every database change is a new migration; applied migrations are never edited.
- UI text is Russian and lives in `lib/core/l10n/`; code, comments and docs are English.
- Secrets never go into the Flutter code or git; `env/*.json` is gitignored (only `env/example.json` is committed).
