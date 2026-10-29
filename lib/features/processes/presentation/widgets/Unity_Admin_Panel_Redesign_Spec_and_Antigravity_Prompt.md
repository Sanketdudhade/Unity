# UNITY — Manufacturing & Production Tracking
## Admin Panel Redesign Specification + Antigravity Implementation Prompt

**Version:** 1.0  
**Design direction:** Option A — Modern Enterprise  
**Implementation:** Flutter / Material 3  
**Themes:** Light, Dark, Follow System  
**Scope:** Presentation-only refactor of the existing admin experience  
**Target:** All platforms already enabled in the repository, including the Windows desktop view shown in the reference screenshot and the Android app  
**Non-negotiable:** Keep Firebase schema, business rules, existing navigation contracts, permissions, and all working features intact.

---

# PART A — IMPLEMENTATION SPECIFICATION

## A1. Baseline and boundaries

The reference screenshot shows a dark top bar labeled Admin Console, a welcome/organization panel, KPI tiles (Total Employees, Active Processes, Pending Tasks, Low Stock Alerts), and oversized management-module cards. The main problems are excessive blank space, weak information hierarchy, navigation presented as empty cards, and insufficient attention to live operational work.

This redesign concerns **only the visual layer and UI composition**. The implementation agent must first inspect the actual repository. This document does not assert that every suggested module already exists. Implement and restyle each module actually found in the codebase; where a module or field is absent, **do not invent Firebase models, new business features, sample records, or nonworking navigation links**.

### Invariants — must not change

- Existing Firebase project, app initialization, Authentication users/claims, Firestore database, Storage buckets and paths, Cloud Functions, security rules, indexes, collection/document names, nested subcollections, field names/types, document identifiers, serializers, and timestamp semantics.
- Organization-level tenancy scoping, employee/admin RBAC, auth guards, permissions, query filters, and access decisions.
- Existing application routes, route identifiers, deep-link behavior, navigation arguments/return values, login/logout, redirects, and back-navigation semantics.
- Existing providers/controllers/services/repositories, domain entities, state transitions, validation, task assignment, process update logic, stock deductions, audit trails, and transactional writes.
- Existing Firestore subscription lifecycles, pagination semantics, error recovery, and real-time data correctness.
- Existing working export, upload, download, search, filters, edit, delete, confirmation, and reporting behavior, wherever currently supported.
- Employee-facing screens must not be unintentionally restyled or functionally modified. A shared theme change requires checking employee screens, or scope the new theme to the admin shell.

No data migration, no new schema, no new Firestore writes for UI preferences, no new required Firebase indexes, no speculative analytics reads, no rewriting service APIs, and no dependency upgrades unrelated to the redesign.

## A2. User experience goals

1. Make the most important operational information visible within the first desktop viewport.
2. Separate **navigation** from **data**: fixed sidebar for destinations; content area for KPIs, alerts, activity, and working tables.
3. Increase information density without becoming cramped: use a predictable 8 px spacing system.
4. Provide fast scanning for admins reviewing employees, products, production progress, deadlines, and inventory.
5. Maintain equivalent capabilities across light, dark, phone, tablet, and desktop layouts.
6. Present truthful values from existing Firebase data. Never display mock percentages or fabricated activity as live production statistics.
7. Keep accessibility, keyboard workflows, and window resizing first-class.

## A3. Theme system and design tokens

Use `ThemeData`, `ColorScheme`, theme/component themes, `TextTheme`, and a small custom `ThemeExtension` only for semantic app-specific tokens that Material does not cover. Prefer `ColorScheme.fromSeed` for initial scheme generation, followed by intentional component styling. No scattered hex literals inside pages.

### Colors

| Token | Light | Dark | Purpose |
|---|---|---|---|
| `canvas` | `#F5F7FA` | `#0B1220` | App workspace |
| `surface` | `#FFFFFF` | `#152235` | Cards, tables, dialog surfaces |
| `surfaceRaised` | `#FFFFFF` | `#1C2B41` | Menus, hover/raised containers |
| `sidebar` | `#142238` | `#0E1728` | Navigation chrome |
| `primary` | `#0F766E` | `#2DD4BF` | Selection, key actions |
| `primarySoft` | `#E6F5F2` | `#123A3A` | Selection backgrounds |
| `textPrimary` | `#0F172A` | `#E8EEF7` | Main content |
| `textSecondary` | `#64748B` | `#A6B6CB` | Supporting text |
| `divider` | `#E2E8F0` | `#304155` | Borders and rules |
| `success` | `#15803D` | `#4ADE80` | Successful state |
| `warning` | `#B45309` | `#FBBF24` | Pending/attention |
| `danger` | `#B91C1C` | `#F87171` | Errors/critical stock |
| `info` | `#1D4ED8` | `#60A5FA` | Information/in progress |

These are design targets, not permission to sacrifice text contrast. Use readable foreground/background pairs from the effective `ColorScheme`, including status labels and sidebar navigation. Meet WCAG AA contrast for normal text wherever practicable (4.5:1), and at least 3:1 for significant nontext UI indicators. Do not communicate state by color alone.

### Typography

- Font: **Inter** or existing bundled/type-safe alternative; do not introduce remote font loading or license-restricted assets.
- Displayed brand: `UNITY` with secondary `Manufacturing Operations` label when width permits.
- Page title: 24 px, weight 700; on compact phones 20–22 px.
- Section title: 17–18 px, weight 600.
- Card title / table heading: 13–14 px, weight 600.
- Body / form labels: 14 px, weight 400–500.
- Secondary helper/meta: 12–13 px.
- Primary KPI number: 28–32 px, weight 700, tabular digits where practical.
- Honor `MediaQuery.textScalerOf(context)`; do not force fixed-height text boxes that clip at larger text sizes.

### Shapes, spacing, elevation, and motion

- Spacing scale: `4 / 8 / 12 / 16 / 24 / 32` logical px.
- Content padding: desktop 24 px, tablet 20 px, phone 16 px.
- Card radius: 12 px; input/button radius: 8–10 px; badges/chips: 6–8 px or pills when appropriate.
- Card border: 1 px subtle outline. Prefer borders + tonal surface over large shadows.
- Hover elevation/state should be subtle; clear focus ring for keyboard users.
- Animation duration: roughly 150–220 ms for navigation hover/expansion/theme transitions; honor reduced-motion preferences.
- Touch targets: target 48 logical px for primary touch actions; compact desktop controls must remain comfortably usable.

## A4. Responsive shell / app chrome

**Use available width**, measured with `LayoutBuilder` or `MediaQuery.sizeOf`, not `Platform.isAndroid` or device-orientation checks.

| Available width | Shell | Content |
|---|---|---|
| `< 600 px` | Material 3 `NavigationDrawer` through `Scaffold.drawer`; compact app bar | 1 KPI column (or 2 only if cards fit), stacked sections, mobile card/list alternatives to wide tables |
| `600–1023 px` | Compact/collapsible rail for a few primary destinations plus accessible More / grouped destinations; no long overflow rail | 2 KPI columns, balanced layout; dense table scrolling where appropriate |
| `>= 1024 px` | Fixed sidebar approximately 240–256 px wide; optional collapsed mode approximately 72 px | 4 KPI columns when content constraints allow; 2-column analytics/alert region; full-width data tables |

The app can be resized, so widgets must react without data reloads or losing form state. Use constraints rather than unconditional fixed heights. Cap excessive content width at approximately 1440–1600 logical px and center it where suitable.

### Desktop navigation

- Fixed navy sidebar. Top: brand + organizational context.
- Visible primary destinations mapped to **existing routes only**: Dashboard, Employees, Products, Inventory, and actual process/task/assignment/reporting modules discovered by code audit.
- Group destinations by operational role (Overview, Operations, Management, Insights, Settings), only when matching existing pages.
- Highlight current destination; reveal groups containing active nested routes.
- Each item shows a consistent icon, label, hover, selection, keyboard focus, and optional count badge only where already available.
- Bottom area: authenticated profile, role, settings/theme control (if an existing settings mechanism can host it), and functioning sign-out.
- Collapse sidebar without changing the route or state. No decorative `Active` badge on every module.
- Material 3 `NavigationRail` is suitable for a small set of top-level tablet destinations; use an adaptive/custom sidebar or More menu for the larger ERP navigation hierarchy.

### App bar

- 64–72 px high on wide screens and compact on phones.
- Left: current page title and breadcrumb/back affordance where existing flow supports it.
- Right: organization label, theme menu (Light, Dark, System), profile menu, and notifications **only if a real notification route/action exists**.
- Do not add clickable search, bell, help, or profile icons that do nothing.
- Keep organization identifier readable but de-emphasized: if the code already has an organization display name, show it with the ID available in a tooltip/details area.

## A5. Dashboard information architecture

### Section 1 — Context header

Compact, no oversized welcome banner. Show `Production Overview`, organization context, last refreshed/stream state if that information already exists, and an existing primary action such as assignment creation **only if implemented**.

### Section 2 — KPI tiles (real data only)

- Total Employees (as currently defined by app: do not silently change active/all filter).
- Active Processes (retain existing current status definition).
- Pending Tasks/Assignments (retain exact current filter and naming).
- Low Stock Alerts (retain existing threshold and count semantics).

Each 100–160 px-tall tile: category icon, short label, prominent value, optional explanatory subtext, and contextual click-through only if the destination/filter already exists. Use clear loading skeleton, zero state, permission error, and retry behavior. Existing example screenshot numbers are **not constants** and must never be hardcoded.

### Section 3 — Action-required zone

Two-thirds panel for active process/work-order overview, one-third panel for alert/activity summaries at desktop widths. Suggested elements, only if data is already available:

- Urgent stock alerts with item name, actual available quantity, current threshold, and an existing Inventory destination.
- Due/overdue work assignments, progress, and responsible employee where supported by current data model.
- Latest recorded process updates and updater identity, if existing audit/activity data and authorization support them.

Empty state is informative; never display fake 'live cloud' tags if metrics are not successfully connected.

### Section 4 — Production visibility

Choose **one** or **two** high-value visualizations derived from existing fetched data without extra unbounded Firestore reads:

- Stage count distribution: pending / in progress / completed / blocked **only if all these states are actually present in the model**.
- Progress-by-stage or completion trend only if real, historically sufficient data exists.
- If no reliable aggregation/history is available, display an actionable table instead. Do not manufacture a chart just to fill space.

### Section 5 — Recent work / updates

Compact table of 5–8 actual recent rows or existing assignment list preview. Columns depend on available data: ID, product, stage, assignee, due date, status. Add `View all` only if route exists. No empty giant cards and no duplication of module navigation.

## A6. Module-by-module visual specification

The agent must find all actual admin routes and apply a consistent shell, page headers, search/filter toolbars, data containers, status chips, empty/loading/error states, dialogs and form styles. The following behaviors are **design requirements only for capabilities already present**.

### Employees

- Summary line: employee count according to existing rules.
- Toolbar: current search, role/status filters if currently supported, Add Employee action if currently supported.
- Desktop: compact `DataTable` / `PaginatedDataTable` / existing table implementation with employee name, identity, role, active work/status, and scoped actions based on actual data.
- Mobile: employee list cards; preserve exact actions via menus/details.
- Detail/edit forms: clear sections, validation and messages; no field contract changes.
- Never expose sensitive fields simply to populate the UI.

### Products / Parts

- Catalogue with name, existing part number/reference, workflow or linked process if applicable, and available drawings/attachments if implemented.
- Product detail uses structured sections or tabs, not long ungrouped text.
- Preserve all attachment paths, upload/download behavior, and CRUD operations.
- Represent genuinely missing metadata with `—`, not guessed values.

### Inventory / Materials

- Table with item/material, unit, quantity, existing low-stock threshold, status and applicable actions.
- Quantity uses clear numeric typography with units, not a fabricated progress bar.
- Low-stock states should be prominent, with text + icon + semantic color.
- Existing material issuance/usage and employee attribution must remain intact.
- Preserve atomic stock deduction and stock validation exactly as implemented; never move these operations into a UI-only approximation.
- Keep add/edit/adjust/usage flows and their validations.

### Production Processes / Stages

- Show the existing process hierarchy and stages in the order and status rules already defined.
- Clear status chip, responsible employee, progress data if supported, and deadline where present.
- Use a stepper/timeline in details where natural; use a sortable/filterable list on summary pages if already supported.
- Preserve stage transition restrictions and who-is-allowed-to-update behavior.

### Tasks / Work Assignments

- List with the actual assigned-to, deadline, priority/status (only if fields exist) and related product/process.
- Use existing queries and filters; avoid new Firestore filters requiring indexes.
- Preserve create/assign/reassign/update/cancel/complete actions and existing validations.
- Clear overdue indicator only when based on an actual due date and state definition.

### Reports / Analytics

- Restyle existing reports only; keep aggregations, formulas, date filters, exports and role scope untouched.
- Clear legends, accessible tooltips, empty-data messages, and meaningful number formatting.
- Charts must never infer fabricated production history from current snapshot counts.

### Profile / Settings / Others

- Apply unified form, dialog and list styling to **every additional existing admin screen**, including profile, organization management, logs, categories, or other routes that the repository reveals.
- Preserve every route and action. No placeholder screen is acceptable as a replacement for a working screen.

## A7. Reusable Flutter components

Organize around actual architecture; **do not move or rename existing service/domain files** solely for aesthetics. A suggested presentational layout (adapt to repo names):

```text
lib/
  core/
    theme/
      unity_theme.dart
      unity_colors.dart
      unity_theme_controller.dart       # existing state mechanism preferred
      unity_theme_extension.dart        # only if needed
    responsive/
      app_breakpoints.dart
  features/
    admin/
      presentation/
        shell/
          admin_shell.dart
          admin_sidebar.dart
          admin_top_bar.dart
          admin_navigation_items.dart   # maps EXISTING route names
        widgets/
          admin_page_header.dart
          metric_card.dart
          status_chip.dart
          section_card.dart
          admin_data_table.dart
          empty_state.dart
          error_state.dart
          loading_skeleton.dart
          filter_toolbar.dart
          confirmation_dialog.dart
        screens/
          ...                           # restyle existing screens, keep contracts
```

Other useful components: compact `SearchField`, filter dropdown, pagination footer, validation message, confirmation dialog, loading button, standard snackbar/toast. Extract only when used at least twice or clearly beneficial. Avoid adding a large new UI library or a second state-management framework.

## A8. Light / Dark / System implementation

- Use one source of truth for theme selection: `ThemeMode.light`, `.dark`, `.system`.
- Respect OS preference when System is selected; respond to OS theme changes while the app is running.
- Persist selection locally using the app's existing preference mechanism, or a minimal supported local preference solution if absent. **Do not write theme preference to Firestore**.
- Avoid changing employee UI unexpectedly: scope admin Theme appropriately unless the project is already built around a shared global app theme.
- Ensure dialogs, dropdowns, inputs, menus, bottom sheets, charts, tooltips, tables, scrollbars, text selection and status chips switch properly; no hardcoded white surfaces or black text.
- Test theme change without restarting and verify selection survives restart (where persistence is implemented).
- Prevent flicker by resolving a saved theme preference before initial theme render when practical, without blocking auth or showing an incorrect admin shell.

## A9. Firebase, state management and performance

- Preserve provider/bloc/riverpod/change notifier patterns already present; no new state architecture.
- Presentational widgets subscribe through existing controllers/providers. Do not instantiate new Firestore listeners in leaf KPI cards.
- Derive multiple visible summaries from existing data subscriptions where feasible. Maintain original result correctness, query filters and ordering.
- Do not run Firestore queries on every `build()`, allocate repeated subscriptions when switching tabs, or add per-row N+1 document reads.
- Preserve loading, error, offline and empty states, and existing write failures.
- Preserve existing transaction/batch operations, validation, stock integrity, audit entries, and clock/server timestamp handling.
- Use `const` where possible; extract small widgets, `ListView.builder` for long lists, limit chart animation, and avoid unnecessary rebuilds.
- Preserve scroll/filter/edit state across resizing and theme switches where current architecture permits.
- The redesign must not meaningfully increase Firebase read/write volume for the same workflow; document any unavoidable change.

## A10. Desktop/mobile interaction and accessibility

- Mouse hover/focus and pointer cursors on actions; keyboard traversal, Enter/Space activation, Esc to close menus/dialogs.
- Visible focus and adequate contrast. Semantic labels/tooltips on icon-only buttons.
- Responsive table behavior: horizontal scrolling with visible affordance or mobile cards; never clip trailing action columns.
- Validation next to the relevant field, along with friendly failure and retry messages.
- Confirm destructive actions with existing business-language labels; do not alter how the repository enforces the operation.
- No inaccessible tiny taps or layout overflows at 320/360/390/600/768/1024/1440/1920 logical pixels and text scaling 1.0/1.3/1.5.
- Support desktop window resize, scroll wheel and keyboard; avoid forced fixed portrait orientation.
- Treat color as a secondary state signal; always include status text/icon.

## A11. Implementation phases

1. **Audit and baseline** — Identify all admin routes/screens, navigation, Firebase reads/writes, state management, app themes, reusable widgets and test coverage. Run baseline `flutter analyze`, tests and supported platform builds; save findings. Inventory current UI actions and their target handlers.
2. **Tokens and shell** — Introduce light/dark/system tokens and admin-scoped shell with responsive sidebar/rail/drawer; preserve routes, auth and organization context.
3. **Dashboard** — Replace oversized dashboard module cards with compact live KPI/alerts/operations content; avoid new data queries or invented charts.
4. **Every existing admin module** — Uniform forms, tables, status chips, filters, dialogs, responsive card layouts. Execute features one screen at a time; keep existing callbacks/repositories.
5. **Polish and verification** — Themes, focus/touch, loading/error/empty states, smaller widths, existing operations and real-time updates. Run analyzer/tests/builds and fix introduced issues.

## A12. Acceptance criteria and test matrix

**Required outcomes**

- All preexisting admin routes are reachable with correct selected navigation state.
- Admin-only content remains guarded by the preexisting roles and organization rules.
- Every existing create/edit/delete/assign/complete/update/stock-usage/upload/download/export operation continues to work as before.
- The original Firestore schema, query filters, services, rules and transaction logic remain unchanged.
- Existing counts still reconcile with their original query/filter definitions.
- Both light and dark themes have readable complete screens; System follows platform preference.
- Sidebar/drawer/rail adapt cleanly through window resize; no `RenderFlex overflow` in expected window sizes.
- No dummy content, inactive buttons, fabricated records, or substitute placeholders.
- Existing employee features remain functional and visually unaffected unless the current app already intentionally shares a global theme.
- No material increase in database reads or listener counts for identical usage.
- Analyzer and test suite pass, or pre-existing failures are clearly distinguished and documented.

**Regression scenarios to verify against actual implemented features:** sign in/out; session restore; permission redirects; change organization (if supported); every navigation destination; query-filtered staff directory; employee create/update; product create/update/attachments; add materials, use materials, and inspect audit trail; assign and update process/task; verify real-time status; low-stock alerts; search/filter/pagination; error/empty/offline states; theme switch and restart; Windows window resize; Android portrait; keyboard operations. Use authorized test data or Firebase emulator where available, and do not mutate production records merely to test styling.

**Suggested checks:**

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d windows          # only if Windows target is configured
flutter run -d chrome           # only if web target is configured
flutter devices                 # select an available Android target
```

Do not claim success unless actually executed. Record baseline failures separately from regressions.

**Implementation handoff:** provide list of changed/new files, high-level explanation of shell/theme implementation, screenshots of dashboard and each available admin module in light and dark mode, commands/tests actually executed and results, any blockers, and explicit confirmation of unchanged Firebase/domain/route contracts. If a command cannot run, explain exactly why and what remains unverified.

---

# PART B — READY-TO-PASTE ANTIGRAVITY IMPLEMENTATION PROMPT

You are a senior Flutter architect, Material 3 UI/UX engineer, and Firebase application maintenance specialist. You have access to my existing **UNITY — Manufacturing & Production Tracking** Flutter repository. It is an operational application with an admin console and employee functionality. Existing features currently work. Your mission is to **implement a premium Modern Enterprise redesign of the ADMIN interface only**, supporting **Light, Dark, and Follow System**, without breaking any working operation.

## Absolute operating constraints

1. **Start by inspecting the repository, not by inventing a new app.** Identify `main.dart`, routing, admin screens/widgets, existing state management, authentication/role guards, themes, Firestore repositories and every existing admin navigation destination. Report a brief factual inventory before editing.
2. **Preserve all functional contracts.** Do not rename or change Firebase collection names, paths, document IDs, field types, security rules, queries, indexes, streams, transactions, CRUD semantics, business rules, permissions, employee/admin role checks, navigation route names/arguments, controller/provider APIs, and all existing validations.
3. **Frontend refactor only.** Do not redesign the database, write migrations, seed test records, substitute fake data, or introduce new backend integrations. No Firestore writes for UI preferences. Do not change existing employee-facing screens except what is strictly required to prevent shared theme regressions.
4. **No empty placeholders.** Every existing feature and user action must remain implemented and clickable. Do not add fake charts, mock notifications, dummy metrics, or navigation destinations for features not in this repository.
5. **No unnecessary dependencies.** Reuse the existing state-management, navigation and component dependencies. Only add a justified minimal presentation/local-preference package if necessary and compatible with the pinned Flutter version.
6. **Make changes incrementally and verify.** Do not replace large working files blindly, discard existing logic, or silently remove widgets. Maintain backup/diff visibility and run supported checks after each logical phase.

## Visual brief — Modern Enterprise

Create the experience of a contemporary manufacturing ERP dashboard, with compact operational data rather than large decorative feature cards. The admin UI must be polished and professional on the Windows desktop screen and remain functional on Android devices.

**Design tokens:**
- Light canvas `#F5F7FA`; light surface `#FFFFFF`; dark canvas `#0B1220`; dark surface `#152235`.
- Fixed navigation navy `#142238` (light theme), darker navy `#0E1728` (dark theme).
- Primary teal `#0F766E` (light), `#2DD4BF` (dark). Use semantic success, warning, danger, and info colors with strong contrast.
- Body text light `#0F172A`, dark `#E8EEF7`; secondary text light `#64748B`, dark `#A6B6CB`; border light `#E2E8F0`, dark `#304155`.
- Inter or existing compatible sans-serif. 24 px page headings, 17–18 px section headings, 14 px body, 12–13 px secondary, 28–32 px KPI numbers.
- 8 px spacing system, 12 px card radius, 8–10 px input/button radius; mostly thin borders and restrained elevation. Use actual `ThemeData`, `ColorScheme`, Material component themes and `ThemeExtension` as appropriate. Never hardcode conflicting colors throughout screen widgets.
- Strong contrast, readable statuses, smooth 150–220 ms transitions when animation is enabled, obvious focus states and accessible tap targets.

## Admin navigation and shell

- At `>=1024` logical px: persistent approximately 248 px dark navy sidebar, optionally collapsible to approximately 72 px, with UNITY branding, grouped links to all EXISTING admin routes, selected-route indicator, authenticated user/profile, and sign-out at the bottom.
- From `600` to `1023` px: compact rail for a limited number of primary destinations plus accessible grouped/More navigation for remaining existing routes. Do not cram 7–10 full destinations into a short `NavigationRail`.
- Below `600` px: Material 3 `NavigationDrawer`, compact app bar, responsive pages with vertical stacks and mobile alternatives to wide tables.
- Main region: clean neutral canvas; compact top bar with page title, context and real existing actions. Organization identifier/name from existing auth context.
- Map sidebar destinations to the **same existing route names and route parameters**; preserve nested route selection, browser/back-button semantics and all existing auth redirects. Navigation chrome must NOT trigger fresh Firebase data fetches on each rebuild.
- Do not present fake notification/search/menu buttons. Profile/theme/sign-out controls must work as described or be omitted when absent.

## Dashboard — replace current layout

The screenshot currently shows a welcome card, four KPI cards and oversized Employees/Products/Inventory management cards. Replace this with:

1. Compact `Production Overview` header (organization context and a real existing primary action only if supported).
2. Four compact live KPI cards wired to the EXISTING source logic: Total Employees, Active Processes, Pending Tasks, Low Stock Alerts. Preserve the exact calculations and filters. Show zero, loading, error, and empty states correctly.
3. Main operational area: currently active process/task summary (left) and low-stock / urgent alerts (right), based strictly on currently available fields and queries.
4. One meaningful stage/status visualization, only if it can be derived accurately from already fetched data without speculative reads. Otherwise use a useful real table.
5. Recent work or process updates table/list, only if such history/list exists and permissions allow it.

No gigantic empty module cards, repeated `Active` decorations, hardcoded example counts, made-up completion percentages, or misleading `live` indicators.

## Module redesign: adapt to files that actually exist

- **Employees:** data-dense searchable directory with current roles/status, readable actions, add/edit/details and mobile cards. Keep the real fields and role protections.
- **Products/Parts:** compact catalog table/cards and clear detail layout; preserve part fields, drawings, attachments, upload/download/storage behavior.
- **Inventory:** material quantity/units, genuine low-stock thresholds, actual usage/employee attribution, adjustments and stock operations with unchanged validations and transactions.
- **Production Processes:** stages, existing progress and statuses, assignee, actual deadlines, stage timeline/details and unchanged transition conditions.
- **Assignments/Tasks/Work Orders:** current assignment, deadline, status, actions and filtering; retain current task lifecycle and queries. Use only actual fields.
- **Reports/Analytics:** restyle existing reports, charts, filters and exports without changing formulas or adding unsupported data.
- **All other current admin screens:** apply the same design system to existing profile/settings/audit/organization/other screens. Do not silently leave admin pages in the old visual style.

For each screen: consistent `PageHeader`, filter/toolbar, compact `SectionCard`, `StatusChip`, styled tables/forms/dialogs, loading skeleton, informative empty state, permission/error state and responsive layout. Ensure correct keyboard/mouse behavior on Windows and touch behavior on Android.

## Theme implementation

Implement a working Light / Dark / Follow System choice using one centralized controller tied to the app's existing state pattern. Honor OS preference dynamically for System and persist the choice locally with the current preference solution (add a minimal local-only mechanism only if needed). Check whether root themes are shared with employee screens; avoid unintended employee UI restyling. Make all dialogs, inputs, dropdowns, tables, charts, popups, scrollbars and nested routes adhere to the active theme. The choice must not alter Firebase data.

## Code organization

Fit into current repository architecture instead of imposing a new feature layout. Where useful, create `core/theme` tokens/controller; an `admin_shell` with `admin_sidebar`/`admin_top_bar`; small reusable admin presentation widgets such as metric card, data table, status chip, page header, filter toolbar and empty/error/loading states. Avoid duplicating logic or touching repositories just to style a screen.

Use `LayoutBuilder` / `MediaQuery.sizeOf(context)` constraints for window-width behavior. Choose grid columns based on width: phone 1 (or safe 2), tablet 2, desktop 4. Keep forms/tables scrollable and avoid overflow at 320, 390, 600, 768, 1024 and 1440+ logical widths. Respect scaled text, keyboard navigation, tooltips, semantics, hover, focus and reduced motion. Preserve form state during resize and theme changes.

## Firebase and performance rules

Use the current existing Firebase streams/providers. Do not add Firestore listeners inside each KPI card or run queries in `build()`. Avoid N+1 row reads and duplicate subscriptions. Maintain original org-scoped predicates, pagination, sorting and indexes. Keep stock deductions, assignments and process status updates atomic and accurate exactly as before. Do not mutate live production data just to test UI. Keep current loading/error/offline handling and never conceal permission failures.

## Required work sequence

**Phase 1: Repo audit + baseline** — inventory existing routes/pages/files/features and current working interactions; establish baseline `flutter analyze` and tests; identify current theme/router/state solution.

**Phase 2: Theme and responsive shell** — implement app tokens, admin-only theme behavior, Light/Dark/System switch and responsive sidebar/rail/drawer. Validate route mapping, auth and sign-out.

**Phase 3: Dashboard** — redesign according to the exact rules above, binding unchanged Firebase-derived KPIs and real operational panels.

**Phase 4: All existing admin modules** — systematically restyle every current admin screen, detail screen, modal and form; preserve callbacks and validation. Maintain an audited checklist mapping route -> screen -> redesigned status.

**Phase 5: Verification** — run analyzer and relevant tests; verify Android/Windows targets that exist in the project; correct overflows, theme contrast, tab/keyboard behavior and Firebase listener regressions. Compare before/after critical actions.

Do not stop after creating a dashboard mockup. Implement all existing admin pages within scope. If the repository cannot be inspected or a blocker prevents completion, report the exact blocker and do not claim that an unverified implementation is finished.

## Expected final output

1. Full implementation in the existing Flutter project, not standalone demo code.
2. File-by-file change summary, noting any new presentation-only components and untouched Firebase/domain logic.
3. List of every existing admin screen/route audited and redesigned; call out any exceptions.
4. Screenshots or precise visual verification of dashboard, Employees, Products, Inventory, Processes/Tasks, and other actual admin modules in **both light and dark themes**, for supported targets.
5. Actual `flutter analyze` / `flutter test` / supported build commands run and their results. Distinguish old failures from newly introduced failures.
6. Regression checklist results covering auth, routes, CRUD, assignments, process status, stock deduction/audit trail, permissions, live metrics, theme persistence and responsive layout, limited to the features actually implemented in the repository.
7. Confirmation that Firebase collections/fields/rules, business logic, state transitions, existing routes, API/data-flow contracts and employee-facing functionality have not been altered; if any deviation was unavoidable, explicitly list it and why.

**Quality bar:** production-oriented, coherent visual hierarchy, no oversize empty cards, no broken workflows, no fake demo data, no new Firebase charges caused by cosmetic refactoring, consistent responsive Material 3 polish across every real admin screen. Begin by auditing the repository and then implement the changes phase by phase.
