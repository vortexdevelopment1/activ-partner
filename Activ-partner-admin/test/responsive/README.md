# Responsive layout audit

Run from `Activ-partner-admin`:

```powershell
npm.cmd run dev -- --config test/responsive/vite.config.ts
```

Open `http://127.0.0.1:5174/test/responsive/index.html?run=1` in Chrome.

The fixture server renders the actual admin components with synthetic API responses. Mutations are rejected, Maps delivery is disabled, and no production credentials or records are needed. Test-only Vite transforms open internal dialog and wizard states; the normal Vite configuration and production bundle do not include them.

The audit checks 54 routes/component states at 10 viewport sizes: 320×640, 360×740, 390×844, 430×932, 640×360, 768×1024, 1024×768, 1280×800, 1440×900, and 1920×1080. It covers all 23 application routes, standalone forms, venue wizard steps, bank/GST/change-request decisions, activity/log details, notifications, search, the navigation drawer, and partner search.

Checks flag elements extending outside the horizontal viewport, dialogs extending outside the visible height, and render/data failures. Intentional horizontal scrolling inside a table is allowed. Inputs, names, email addresses, URLs, rejection reasons, and messages include long content. Use **Preview selection** to inspect individual cases and interact with fields and dropdowns; writes remain disabled.

Run the geometry and navigation regression tests:

```powershell
node --test test/floatingPanel.test.cjs test/notificationNavigation.test.cjs
```

Browser viewport checks cover layout, not physical device hardware. Real Safari/Chrome mobile keyboard behavior and third-party Google Maps suggestions still warrant device testing.
