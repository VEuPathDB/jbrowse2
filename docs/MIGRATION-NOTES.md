# Moving this container to JBrowse 5

Sketch, not a finished image — nothing here has been built or deployed. It
exists to make the deployment questions concrete.

## What changed and why

**nginx actually serves the files now.** The image was already `FROM nginx` but
ran `npx serve` instead, which meant node, npm and a global package install in
the runtime layer for a job nginx was already there to do. The build is now two
stages and the runtime carries no node at all.

**The sed rewrite is gone.** The old container republished config.json every 30
seconds through `sed 's|uri": "|uri": "data/|'`, which prefixes *every* `uri`,
absolute ones included — an `http://...` URI became `data/http://...`. Track
data is now served at a stable `/data/` path by nginx, so a generated
config.json names `/data/<file>` and is simply correct.

**This needs a change on our side.** `buildSyntenyTrackConfig.py` hardcodes
`BASE_URL = "http://localhost:9003"` and emits absolute URIs. That is a dev
convenience; for anything deployed here it has to emit `/data/...`.

**Plugins are baked into the image and merged into the config at startup.**
`plugins.json` lists what the image carries; `startup.sh` merges it into
whatever config.json the mount supplies. The workflow writing config.json does
not need to know which plugins exist or where they live, and the image does not
need the workflow's cooperation to add one.

**Same origin, deliberately.** The plugin bundle is served from the same host as
the app, as a relative URL. JBrowse 5 prompts the user to approve any
*cross-origin* plugin before it will load one — config loads, plugin silently
does not, nothing is logged. Serving the bundle from a CDN or a separate host
would put that prompt in front of every user on every new browser. The topology
avoids it rather than working around it.

**The image can say what it is.** `/build-info.txt` records the JBrowse release
flag, the version, the plugin commit and the build time, and is served. A
deployed container that cannot report its own provenance cannot be debugged from
outside the host.

## The part that is not good, and is not avoidable yet

The builder runs `jbrowse create --nightly`, which builds from GMOD's `main`.

This is wrong for production and the comment in the Dockerfile says so. The
reason it is here: **JBrowse 5 has no GitHub release.** The CLI skips
prereleases when resolving "latest" (`!r.prerelease` in its release lookup), and
`--tag v5.0.0-beta.13` 404s because the tag has no release attached. The betas
exist on npm under the `next` tag only.

Three ways out, in order of preference:

1. **Wait for the v5 release and pin `--tag`.** Correct, and costs nothing but
   time. Everything else here is independent of it.
2. **Build jbrowse-web from source** at a pinned commit in the builder stage.
   Reproducible, but it pulls the whole monorepo build into the image build
   (~7GB RAM) for an artifact GMOD will shortly publish anyway.
3. **`--url` pointing at an artifact we build and store once.** Pins the bytes
   without pinning our build to GMOD's; needs somewhere to keep it.

Until one of those, do not treat an image built from this as reproducible: two
builds a day apart contain different JBrowse. `/build-info.txt` at least makes
them distinguishable.

## Not addressed here: Apollo

Apollo3 is a different deployment shape. It needs a Nest application server,
MongoDB, and write volumes; this stack is static files and a read-only mount.
Adding it means adding services to the compose stack, not editing this image.

It is also blocked on something upstream: Apollo 1.1.3 targets `@jbrowse/core`
^4.3.0 and React 18, and breaks in two measured places on JBrowse 5. See
`APOLLO-ON-JBROWSE5.md`.

## Still to decide

- **Plugin versions are `main`.** `SUBTRACK_PLUGIN_REF` defaults to a branch,
  which makes the image unreproducible for the same reason `--nightly` does.
  Tag the plugin and pin the tag.
- **Where the Apollo collaboration server and MongoDB live** — this stack, a
  sibling stack, or a managed Mongo.
- **Whether `/data/` should be a separate Traefik route.** Serving large track
  files through the same nginx as the app is fine at current volumes and may not
  be at production ones.
