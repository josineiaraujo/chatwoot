# Chatwoot Development Guidelines

## Build / Test / Lint

- **Setup**: `bundle install && pnpm install`
- **Run Dev**: `pnpm dev` or `overmind start -f ./Procfile.dev`
- **Seed Local Test Data**: `bundle exec rails db:seed` (quickly populates minimal data for standard feature verification)
- **Seed Search Test Data**: `bundle exec rails search:setup_test_data` (bulk fixture generation for search/performance/manual load scenarios)
- **Seed Account Sample Data (richer test data)**: `Seeders::AccountSeeder` is available as an internal utility and is exposed through Super Admin `Accounts#seed`, but can be used directly in dev workflows too:
  - UI path: Super Admin → Accounts → Seed (enqueues `Internal::SeedAccountJob`).
  - CLI path: `bundle exec rails runner "Internal::SeedAccountJob.perform_now(Account.find(<id>))"` (or call `Seeders::AccountSeeder.new(account: Account.find(<id>)).perform!` directly).
- **Lint JS/Vue**: `pnpm eslint` / `pnpm eslint:fix`
- **Lint Ruby**: `bundle exec rubocop -a`
- **Test JS**: `pnpm test` or `pnpm test:watch`
- **Test Ruby**: `bundle exec rspec spec/path/to/file_spec.rb`
- **Single Test**: `bundle exec rspec spec/path/to/file_spec.rb:LINE_NUMBER`
- **Run Project**: `overmind start -f Procfile.dev`
- **Ruby Version**: Manage Ruby via `rbenv` and install the version listed in `.ruby-version` (e.g., `rbenv install $(cat .ruby-version)`)
- **rbenv setup**: Before running any `bundle` or `rspec` commands, init rbenv in your shell (`eval "$(rbenv init -)"`) so the correct Ruby/Bundler versions are used
- Always prefer `bundle exec` for Ruby CLI tasks (rspec, rake, rubocop, etc.)

## Code Style

- **Ruby**: Follow RuboCop rules (150 character max line length)
- **Vue/JS**: Use ESLint (Airbnb base + Vue 3 recommended)
- **Vue Components**: Use PascalCase
- **Events**: Use camelCase
- **I18n**: No bare strings in templates; use i18n
- **Error Handling**: Use custom exceptions (`lib/custom_exceptions/`)
- **Models**: Validate presence/uniqueness, add proper indexes
- **Type Safety**: Use PropTypes in Vue, strong params in Rails
- **Naming**: Use clear, descriptive names with consistent casing
- **Vue API**: Always use Composition API with `<script setup>` at the top

## Styling

- **Tailwind Only**:  
  - Do not write custom CSS  
  - Do not use scoped CSS  
  - Do not use inline styles  
  - Always use Tailwind utility classes  
- **Colors**: Refer to `tailwind.config.js` for color definitions

## General Guidelines

- MVP focus: Least code change, happy-path only
- No unnecessary defensive programming
- Ship the happy path first: limit guards/fallbacks to what production has proven necessary, then iterate
- Prefer minimal, readable code over elaborate abstractions; clarity beats cleverness
- Break down complex tasks into small, testable units
- Iterate after confirmation
- Avoid writing specs unless explicitly asked
- Remove dead/unreachable/unused code
- Don’t write multiple versions or backups for the same logic — pick the best approach and implement it
- Prefer `with_modified_env` (from spec helpers) over stubbing `ENV` directly in specs
- Specs in parallel/reloading environments: prefer comparing `error.class.name` over constant class equality when asserting raised errors

## Codex Worktree Workflow

- Use a separate git worktree + branch per task to keep changes isolated.
- Keep Codex-specific local setup under `.codex/` and use `Procfile.worktree` for worktree process orchestration.
- The setup workflow in `.codex/environments/environment.toml` should dynamically generate per-worktree DB/port values (Rails, Vite, Redis DB index) to avoid collisions.
- Start each worktree with its own Overmind socket/title so multiple instances can run at the same time.

## Commit Messages

- Prefer Conventional Commits: `type(scope): subject` (scope optional)
- Example: `feat(auth): add user authentication`
- Don't reference Claude in commit messages

## PR Description Format

- Start with a short, user-facing paragraph describing the product change.
- Add a `Closes` section with relevant issue links (GitHub, Linear, etc.).
- For feature PRs, add `How to test` from a product/UX standpoint.
- For bugfix PRs, use `How to reproduce` when helpful.
- Optionally add a `What changed` section for implementation highlights.
- Do not add a `How this was tested` section listing specs/commands.

## Project-Specific

- **Translations**:
  - Only update `en.yml` and `en.json`
  - Other languages are handled by the community
  - Backend i18n → `en.yml`, Frontend i18n → `en.json`
- **Frontend**:
  - Use `components-next/` for message bubbles (the rest is being deprecated)

## Ruby Best Practices

- Use compact `module/class` definitions; avoid nested styles

## Enterprise Edition Notes

- Chatwoot has an Enterprise overlay under `enterprise/` that extends/overrides OSS code.
- When you add or modify core functionality, always check for corresponding files in `enterprise/` and keep behavior compatible.
- Follow the Enterprise development practices documented here:
  - https://chatwoot.help/hc/handbook/articles/developing-enterprise-edition-features-38

Practical checklist for any change impacting core logic or public APIs
- Search for related files in both trees before editing (e.g., `rg -n "FooService|ControllerName|ModelName" app enterprise`).
- If adding new endpoints, services, or models, consider whether Enterprise needs:
  - An override (e.g., `enterprise/app/...`), or
  - An extension point (e.g., `prepend_mod_with`, hooks, configuration) to avoid hard forks.
- Avoid hardcoding instance- or plan-specific behavior in OSS; prefer configuration, feature flags, or extension points consumed by Enterprise.
- Keep request/response contracts stable across OSS and Enterprise; update both sets of routes/controllers when introducing new APIs.
- When renaming/moving shared code, mirror the change in `enterprise/` to prevent drift.
- Tests: Add Enterprise-specific specs under `spec/enterprise`, mirroring OSS spec layout where applicable.
- When modifying existing OSS features for Enterprise-only behavior, add an Enterprise module (via `prepend_mod_with`/`include_mod_with`) instead of editing OSS files directly—especially for policies, controllers, and services. For Enterprise-exclusive features, place code directly under `enterprise/`.

## Branding / White-labeling note

- For user-facing strings that currently contain "Chatwoot" but should adapt to branded/self-hosted installs, prefer applying `replaceInstallationName` from `shared/composables/useBranding` in the UI layer (for example tooltip and suggestion labels) instead of adding hardcoded brand-specific copy.

## Fork and Update Workflow

- This repository should keep two remotes:
- `origin` = your repository `https://github.com/josineiaraujo/chatwoot.git`
- `upstream` = original Chatwoot repository `https://github.com/chatwoot/chatwoot.git`
- Keep local `develop` as a clean mirror of `upstream/develop`
- Do not commit custom changes directly to `develop`
- Create and maintain your changes in `custom/develop`
- Build and publish your Docker image from `custom/develop`

Why this repository uses a separate branch for custom work:

- `develop` should stay as close as possible to the upstream project so updates can be applied cleanly
- all local customizations, branding, behavior changes, and infrastructure adjustments should live in `custom/develop`
- this separation reduces merge conflicts, makes debugging easier, and avoids mixing vendor updates with your own business logic
- when something breaks after an upstream update, it is easier to identify whether the cause came from Chatwoot or from your custom changes
- production images must be generated from `custom/develop`, never from `develop`

Recommended initial setup:

```bash
git remote rename origin fork
git remote add upstream https://github.com/chatwoot/chatwoot.git
git remote add origin https://github.com/josineiaraujo/chatwoot.git
git fetch --all --prune
git checkout develop
git branch --set-upstream-to=upstream/develop develop
git checkout -b custom/develop
git push -u origin custom/develop
```

Daily workflow:

- Never modify `develop`
- Make all product, branding, and Docker changes in `custom/develop`
- Push your work to `origin/custom/develop`
- Generate your Docker image from `custom/develop`

To receive updates from the original project:

```bash
git fetch upstream
git checkout develop
git reset --hard upstream/develop
git checkout custom/develop
git merge develop
```

Recommended update routine:

- fetch from `upstream`
- fast-forward or hard-reset local `develop` to match `upstream/develop`
- merge `develop` into `custom/develop`
- resolve conflicts only in your custom branch
- test the application
- push the updated `custom/develop` to your fork

Suggested command sequence:

```bash
git fetch upstream
git checkout develop
git reset --hard upstream/develop
git checkout custom/develop
git merge develop
git push origin custom/develop
```

If you prefer a linear history and are comfortable resolving conflicts, you may replace the final `git merge develop` with:

```bash
git rebase develop
```

Practical rules to reduce future conflicts:

- Keep customizations in small, focused commits
- Prefer using the upstream Docker files whenever possible instead of creating a parallel production flow
- Keep local-only environment values outside versioned files whenever possible
- Avoid unnecessary edits to core files that change frequently upstream
- Build and publish your own production image from `custom/develop` using the upstream `docker/Dockerfile`
- Avoid editing files only to change formatting or reorder code unless required
- Prefer configuration, extension points, and isolated patches over broad invasive rewrites
- When upstream files must be changed, keep the diff minimal and document why
- Before merging upstream updates, review local custom commits so conflict resolution stays intentional

Example image build and publish flow:

```bash
docker build -f docker/Dockerfile -t josineiaraujo/chatwoot-custom:custom-develop .
docker push josineiaraujo/chatwoot-custom:custom-develop
```

Production image guidance:

- always build the production image from `custom/develop`
- prefer a tag that identifies the branch, release, or deployment date
- push the generated image to your own Docker repository
- deploy production using your published image, not the default upstream image

Example with a release tag:

```bash
git checkout custom/develop
docker build -f docker/Dockerfile -t josineiaraujo/chatwoot-custom:2026-03-11 .
docker push josineiaraujo/chatwoot-custom:2026-03-11
```

Before building a production image:

- make sure `custom/develop` is updated with the latest `upstream/develop`
- confirm the application boots locally
- verify database migrations are valid
- review environment-specific variables separately from the image build
- remove any temporary local testing changes before production build or deploy

Temporary local-only testing note:

- any change made in `lib/chatwoot_hub.rb` to simulate, force, or unlock plan behavior is for local testing only
- such changes must never be included in production images, production deploys, or final release commits
- before publishing a production image, review `lib/chatwoot_hub.rb` and remove any local testing override

Pre-production review checklist:

- review `lib/chatwoot_hub.rb` and remove any temporary local testing override
- review `docker-compose.yaml`, `docker-compose.production.yaml`, and `docker/Dockerfile` for local-only edits
- review `.env` usage and confirm production secrets are not coming from local development files
- review `db/schema.rb` and commit it only when there is an intentional schema change
- remove backup files, temporary scripts, downloaded artifacts, and local debugging files before building the final image
- confirm the production image is being built from `custom/develop`, not from `develop`
