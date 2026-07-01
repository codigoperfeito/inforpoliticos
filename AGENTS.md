# AGENTS.md

This document helps automated agents and contributors work safely and consistently in the `InfoPoliticos` Flutter app.

## Project Overview

`InfoPoliticos` is a Flutter mobile app that displays Brazilian political data, mainly:

- Federal deputies
- Senators
- Supporting content such as votes, expenses, summaries, and related metadata

The app consumes public HTTP APIs and presents the results in Flutter screens with search, filters, charts, and detail views.

## Tech Stack

- Flutter / Dart
- `http` for REST requests
- `shared_preferences` for lightweight local persistence
- `cached_network_image` for remote images
- `url_launcher` for outbound links
- `google_fonts` for typography
- `xml` for XML parsing when needed

## Main App Areas

- `lib/main.dart` - app entry point and routing/bootstrap
- `lib/screens/` - UI screens
- `lib/services/` - API clients, repositories, caches, and data helpers
- `lib/models/` - strongly typed data models
- `assets/data/` - local JSON assets and fixtures

## Working Rules

1. Prefer small, targeted changes over broad rewrites unless the user explicitly asks for a full refactor.
2. Keep API parsing defensive. Public datasets may change shape, use null-safe parsing and fallback values.
3. Do not assume every endpoint returns the same structure across years or political offices.
4. Preserve existing user-facing behavior unless the request is clearly to replace it.
5. If you change a data contract, update the matching model, service, and screen together.
6. Avoid introducing new dependencies unless they solve a clear problem.

## API Handling Guidance

- Treat remote data as untrusted input.
- Check response status codes before parsing.
- Parse `JSON` with `dart:convert`.
- Use typed models with `fromJson` factories when possible.
- Keep network logic inside services or repositories, not inside widgets.
- When an endpoint is unstable or has multiple formats, add safe fallbacks instead of hard failures.

## UI Guidance

- Follow the existing Material Design direction used in the app.
- Keep screens responsive and mobile-friendly.
- Prefer reusable widgets for repeated cards, chips, and list rows.
- Use loading, empty-state, and error-state handling on every remote data screen.
- Avoid rebuilding an entire page when only one section changes; keep state localized when possible.

## Senator / Deputy Features

- Senator and deputy flows are separate and should remain logically independent.
- If a screen is for senators, do not reuse deputy-specific labels or filters unless the user explicitly wants shared behavior.
- Expense and summary views should be linked to the correct identifier for each political office.
- Keep filters, year selectors, and pagination consistent with the data source being consumed.

## Linting and Quality

- Respect `analysis_options.yaml` and Flutter lint rules.
- Remove unused imports, unused widgets, and unnecessary interpolation braces.
- Prefer descriptive names over abbreviations unless the domain uses a canonical identifier.
- Run `flutter analyze` after meaningful edits when possible.

## Common Pitfalls

- Do not mix HTML, XML, and JSON parsing assumptions.
- Do not hardcode fields that come from external APIs unless they are stable and documented.
- Do not assume every politician has a photo, party, or activity record.
- Do not block the UI thread with heavy parsing or processing.

## Before Finishing Work

- Verify that the relevant screen still opens.
- Verify that loading and error states still work.
- Verify that the data mapping matches the current API response.
- If a change affects navigation or state, sanity-check the flow on both Android and iOS.

## Notes for Future Agents

- When a user asks to “make it work,” inspect the service layer first, then the model layer, then the screen.
- If a feature is duplicated between deputies and senators, look for shared patterns, but avoid forcing both into one implementation if their data sources differ.
- When in doubt, prioritize correctness, resilience, and clear UI feedback over clever abstractions.
