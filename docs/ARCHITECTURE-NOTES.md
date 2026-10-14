# JBrowse 2/5 at VEuPathDB — architecture notes

Working notes from the migration investigation, October 2026. Decisions here are
leanings, not commitments; the open questions at the end are genuinely open.
Claims about JBrowse internals cite the file they came from so a reader can
check them rather than trust them — several contradict what the docs imply.

## The pieces, and what each assumes

| | version | assumes |
| --- | --- | --- |
| This container (`main`) | JBrowse 2.6.3 | static files, no plugins, no auth |
| Apollo3 plugin 1.1.3 | `@jbrowse/core` ^4.3.0 | React 18, MUI 7 |
| subtrack/synteny plugin | `@jbrowse/core` ^5.0.0-beta.10 | React 19, MUI 9, `@jbrowse/render-core` |
| jbrowse-web (target) | 5.0.0-beta | — |

**Plugins do not bundle their own React, MUI or core.** Those are externalised,
so every plugin runs against the host's single copy. There is no per-plugin
version isolation, which is why the table above is a constraint and not just
trivia.

Our plugin cannot fall back to JBrowse 4: it needs `@jbrowse/render-core`, which
does not exist in the 4.3.0 tree. So the shared host has to be 5, and the
combined app is blocked until Apollo supports 5 — see
`APOLLO-ON-JBROWSE5.md`.

JBrowse 5 has no GitHub release yet. The CLI filters prereleases out of
"latest", and `--tag v5.0.0-beta.x` 404s because the tags carry no release. The
betas are on npm under the `next` tag only. Until GMOD cuts a release, a build
is either a nightly or something we build and store ourselves.

## Deployment shape

**JBrowse is files; Apollo is a program.** Once built, JBrowse is HTML, JS and
CSS that never executes on the server. Containerising that means running a web
server inside a container so Apache can forward requests to it — two web servers
doing one's job. The leaning is for Jenkins to publish a versioned build
artifact (JBrowse plus our plugin bundles) that Apache serves on each site.

The Apollo collaboration server is a Node application with MongoDB behind it, so
it stays containerised under either option, reverse-proxied by Apache under the
site's own hostname. It needs a persistent MongoDB running as a replica set
(Apollo's own compose file does this) and a backup story.

Operational gotcha: MongoDB refuses to start on Linux kernels 6.19 through
7.0.13 — a vendored TCMalloc incompatibility, MongoDB issue SERVER-121912. It
affects every version including the Docker images. Check the target hosts' kernel
before planning anything else.

## Same origin is the load-bearing property

Three separate things depend on it, which is why it is worth stating as a rule
rather than discovering three times.

**Authentication is free when it holds.** JBrowse's data fetches do not override
`credentials`, so the browser default (`same-origin`) applies and the session
cookie rides along automatically, including from the web workers that do the
actual BAM/tabix reads. If the app, its config and the data files are all on the
site's own hostname, JBrowse authenticates with no configuration at all. The
moment anything moves to another origin, cookies stop flowing and it takes CORS
with credentials plus a JBrowse `internetAccounts` entry to recover.

**The plugin security prompt never fires.** JBrowse 5 warns before loading
plugins named by a cross-origin config. The gate is one line in
`products/jbrowse-web/src/SessionLoader.ts`:

```js
const isCrossOrigin = configUri.origin !== window.location.origin
```

Plugin URL origins do not enter into it — only the config's. Approvals are
remembered per origin in `localStorage` under `jbrowse-trusted-plugins`.

**Relative plugin URLs resolve predictably.** From
`packages/core/src/PluginLoader.ts`: a relative plugin url resolves against
`window.location.href` — *the JBrowse instance, not the config that named it*.
So `"plugins/foo.js"` always means "beside this index.html" even when Apollo's
server emitted the config. (`umdLoc`/`esmLoc` with `baseUri` is the form that
resolves against the config instead.)

Consequence: bake both plugin bundles into the build artifact beside
`index.html` and reference them relatively. Apollo expects exactly this — its
`PLUGIN_LOCATION` defaults to the relative `apollo.js`.

Whether JBrowse is a directory Apache serves or a container Apache proxies does
not matter here. What matters is that it is reachable only under the site's own
hostname, and only through Apache.

## Auth

With OIDC at the Apache perimeter, the flow completes before JBrowse loads and
everything above applies.

**Data and config paths must return 401, not redirect.** A 302 to the identity
provider is right for a page load and fatal for a worker fetching a BAM chunk:
the worker follows the redirect, gets an HTML login page with a 200, and hands
it to a binary parser. The symptom is corrupt track data, not a login prompt.
In mod_auth_openidc this is `OIDCUnAuthAction 401` scoped to those locations.

Also set `Cache-Control: private` on protected paths, and make sure nothing in
the chain compresses already-compressed files — mod_deflate on a `.gz` or `.bam`
silently breaks range requests, which is the entire access pattern.

**Apollo can accept the identity Apache already established.** Its documented
`Apollo-RegisterCustomAuth` extension point takes a handler that receives the
raw request and returns `{name, email}`; reading Apache's `REMOTE_USER` /
`OIDC_CLAIM_*` headers is the `needsPopup: false` case their docs describe.
Reference implementation: GMOD's `jbrowse-plugin-apollo-orcid-login`.

**This is only safe if the Apollo service is unreachable except through Apache.**
An exposed port means anyone can set the header and become any curator. Treat
that as a security property, not a deployment detail.

Note the contract is `{name, email}` — identity only. Apollo's roles (admin /
user / readOnly) live in its own Mongo records, so group membership and
per-organism edit rights do not transfer. That mapping is real work and nobody
else can do it for us.

## Track configuration at VEuPathDB scale

\>500 organisms, hundreds of tracks for the well-studied ones. JBrowse 1 handled
this with dynamically generated per-organism track files; JBrowse 5 has a
mechanism that is a close match.

**Connections are lazy and the track selector hydrates them on expand.** From
`plugins/data-management/src/HierarchicalTrackSelectorWidget/model.ts`:

```js
// expanding a dormant connection's category loads the connection
if (collapsed && group?.connectionId !== undefined) {
  getSession(self).hydrateConnection?.(group.connectionId)
}
```

So the shape is: a root config holding plugins, assemblies and N
`JB2TrackHubConnection` stubs, each pointing at a generated config under
`/data/<org>/<datatype>/`. The workflow keeps generating per-organism track
files exactly as it does today — different filename and schema, same job.

Three properties that matter at this scale, all from source rather than
inference:

- **Saved sessions stay small.** The `BaseConnection` config schema says it
  outright: JBrowse holds a connection's track list in memory and does not write
  it into a saved or shared session; only opened tracks are stored, keyed by
  `trackId`.
- **Each generated config is self-contained.** `doConnect` runs
  `addRelativeUris` against the config's own URL, so a per-organism directory
  can be moved or mirrored without rewriting its contents.
- **Connections declare `assemblyNames`**, so the selector can filter them to
  the assembly in view.

**The cost of lazy:** the faceted selector and track text-search only see
*loaded* tracks. In JBrowse 1 everything was in the trackList, so search was
total. If cross-datatype track discovery matters — and for a 400-track organism
it probably does — that needs either a server-side track search or a lightweight
always-loaded catalog with the heavy configs behind connections.

**Authorization lands here, not on Apache.** Restricted and pre-release datasets
mean config.json must be filtered to the user's entitlements; a track the user
cannot fetch is worse than a track they cannot see. Connections make that
filtering cheap — omit the stub. Open question is whether filtering happens at
generation time or request time, which decides whether config.json is a static
file or something dynamic behind Apache.

## Who owns config.json

In a combined app, Apollo has to. Its `getConfig` is role-dependent and dynamic:
anonymous requests get plugins and internetAccounts only, authenticated requests
get assemblies and `ApolloTrack` entries built from Mongo at request time,
`merge`d over a stored config document. A static file cannot reproduce that.

That means VEuPathDB's tracks go into Apollo's stored config — pushed with
`apollo jbrowse set-config config.json`, which exists in their CLI. **Put them
there as connections, not as inline tracks**, or Apollo's response grows with
the organism count. Track *files* stay where they are and are served by Apache.

Worth measuring: what Apollo's own `getAssemblies()` does at 500 organisms. That
one is theirs and we have not tested it.

## Cross-site

Within one site, absolute URLs on that site's own hostname behave exactly like
relative ones. Cross-site breaks in three places:

- **Comparative data spanning sites.** A PlasmoDB config naming a ToxoDB URL is
  a cross-origin fetch with no cookie. Simplest fix is to proxy the other site's
  data under the local hostname so the config only ever names one origin.
- **Shared session links.** Sessions and the trusted-plugin store are
  origin-partitioned; a session shared from one site opened on another is
  cross-origin for both config and data, and trips the plugin warning.
- **Anything hardcoded in the build.** "One artifact, all sites" only holds if
  the build contains no hostnames. Per-site absolute URLs belong in the per-site
  config.

## Synteny is a new access pattern

In JBrowse 1 synteny came from dynamic SQL — `gene:syntenyJBrowseScaled` in
`ApiCommonModel/Model/lib/xml/jbrowse/genomeQueries.xml` — so the server
returned only what the window needed. In the new design it is a tabix-indexed
GFF: for Pf3D7, 126 lanes, 1,469,211 features, ~47MB, read by range like any
other track.

Per-request latency is unchanged (same store service, same range reads), but the
client-side work is new: lanes that are not visible are hidden *after* fetch, so
a whole-chromosome view parses on the order of 200k features to display about
7% of them. Fine at the default 10 open lanes; worth watching at thirty.

## Open questions

- Generation-time vs request-time filtering of config.json for entitlements.
- Whether cross-site sessions and cross-site comparative views need to work.
- Where VEuPathDB roles map onto Apollo's role model.
- Whether a central track catalog is needed to keep search total under lazy
  loading.
- Apollo's scaling behaviour at 500 organisms.
- Per-range-request overhead through OIDC + the store servlet. jb-v5 ships
  `products/jbrowse-web/browser-tests/measure-load-latency.ts`, which reports
  what serialises a load; pointing it at a real site would answer this.
