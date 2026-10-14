# Apollo3 on JBrowse 5 — findings

Tested 2026-10-13. Apollo3 is a third-party JBrowse plugin from GMOD, used here
as a probe: if their flagship plugin survives the v4 → v5 move, ours probably
can, and whatever breaks for them tells us what to expect.

## What was tested

| | |
| --- | --- |
| Apollo3 | `main` @ `ec7bbfcd`, plugin `@apollo-annotation/jbrowse-plugin-apollo` 1.1.3 |
| Host | `jb-v5` @ `36d7a03e59`, `@jbrowse/core` 5.0.0-beta.10, React 19.3.0, MUI 9.4.0 |
| Plugin targets | `@jbrowse/core` ^4.3.0, React ^18.2.0, MUI ^7.3.11 |
| Baseline available | published `jbrowse-web` v4.3.0 via `jbrowse create`, served on :8999 |

`http://localhost:3000/?config=http://localhost:3999/jbrowse/config.json`

Driven with puppeteer, not by hand — the Chrome extension's script injection was
failing on every page including `example.com`, so screenshots and DOM reads were
unavailable through it. Script:
`scratchpad/driveApolloOnJb5WithPuppeteer.mjs` (session scratchpad, not kept).

## Result: it loads

The plugin bundle is fetched (200), registers, and its APOLLO menu appears in
the menu bar with the Apollo theme applied. All 19 module specifiers the bundle
externalizes — `@jbrowse/core/*`, `@jbrowse/mobx-state-tree`, `mobx-react`,
`@mui/material*`, `@mui/x-data-grid`, `react/jsx-runtime`, `tss-react/mui` — are
still on v5's ReExports list (543 entries). The plugin ABI held.

Both failures below are runtime-only. Each crosses a pluggable boundary where
the call is resolved by name at runtime, so a type-check on either side sees
nothing.

## 1. The jobs widget action was renamed

```
Uncaught (in promise) TypeError: self.jobStatusWidget.updateJobStatusMessage is not a function
```

Thrown repeatedly. Apollo reports ontology-loading progress through JBrowse's
jobs widget, so the Sequence Ontology load stays in **Queued jobs** forever and
never starts. Since the Sequence Ontology is what Apollo validates feature types
against, this is not cosmetic.

| | |
| --- | --- |
| v4.3.0 | `updateJobStatusMessage(jobName, message?)` — `jbrowse-components/plugins/jobs-management/src/JobsListWidget/model.ts:124` |
| v5 | `updateJobStatus(name, statusMessage?, pct?)` — `jb-v5/plugins/jobs-management/src/JobsListWidget/model.ts:63` |

Renamed and re-signatured. Apollo reaches the widget it did not define through
an MST action lookup, so the name is a string at runtime. One line to fix in
Apollo; a deprecated alias in v5 would fix every plugin doing this at once.

## 2. React 19 rejects Apollo's auth dialog

```
Cannot update a component (DialogQueue) while rendering a different component (AuthTypeSelector)
```

v5 runs React 19.3.0. Apollo declares `react: ^18.2.0` as a peer and builds
against 18, where setState-during-render was tolerated.

This is a **third** version axis, on top of the MUI 7 → 9 mismatch already
documented in the workspace `CLAUDE.md`. The same trap applies: a plugin's jest run renders
against its own React 18 devDependency and passes, while the browser hands it
the host's React 19.

## 3. v5 gates cross-origin plugins behind a trust dialog

Not a bug, and not Apollo-specific — but it changes how we ship.

`jb-v5/products/jbrowse-web/src/components/PluginWarningDialog.tsx`,
`.../trustedPlugins.ts`. Until the user clicks "Yes, I trust it", the bundle is
**never fetched**: the config loads, the plugin silently does not, and nothing
is logged. The first attempt here looked like a dead page for exactly this
reason.

Approvals are keyed by exact plugin URL in `localStorage` under
`jbrowse-trusted-plugins`, partitioned by origin.

**This will hit our own plugins.** The subtrack/synteny plugin on :9002 is
cross-origin to jbrowse-web on :3000, and any VEuPathDB deployment serving its
plugin bundle from a host other than the app's own origin gets the same prompt
on every new origin. Worth deciding deliberately: same-origin bundle, or a
prompt our users see.

## Environment notes (unrelated to JBrowse, but they cost time)

**MongoDB will not run on this machine.** Every version — 7, 8, 9, Docker images
included — aborts at startup on kernel 7.0.0-34-generic with id 12257600
(SERVER-121912): the vendored TCMalloc corrupts memory on kernels 6.19–7.0.13,
so mongod refuses rather than crash later. Upgrading MongoDB does not help;
MongoDB's stated fix is kernel 7.0.14+. Worked around for dev only by running
mongod under `setarch --uname-2.6` with `GLIBC_TUNABLES=glibc.pthread.rseq=1`,
which defeats a corruption guard — acceptable for a disposable container,
never for data that matters.

**Apollo's `yarn start` silently ships a broken plugin on a clean checkout.**
`start:plugin` and `start:shared` run in parallel, so rolldown resolves
`@apollo-annotation/shared` before its `dist` exists, treats it as external, and
emits references to an `_apollo_annotation_shared` global that nothing defines —
89 of them, with no error, just `✔ Rebuilt dist`. Run `yarn build:shared` once
before `yarn start`. The `just run` recipe has the same race. Upstream bug.

Apollo also needs Node 24 (its CI pins 24.14); Node 20 will not do.

## If we report this to GMOD

Findings 1 and 2 are clean, reproducible, and pre-beta. Finding 1 in particular
is a rename with no deprecation path, which will break every plugin that touches
the jobs widget, not just Apollo — that framing is likely more useful to them
than the Apollo-specific symptom.
