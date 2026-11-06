# JBrowse 5 release artifact

This repo builds `jbrowse5-<version>.tar.gz`, a static JBrowse 5 web app with
VEuPathDB's plugins already in it, and publishes it as a GitHub release asset.
ApiCommonWebsite's `build.xml` downloads a pinned version, checks its sha256 and
untars it into the WDK webapp root.

Nothing is built from source here, and there is no container.

## What the tarball contains

```
jbrowse5/
  index.html, static/, ...   jbrowse-web from GMOD's GitHub release (test_data/ removed)
  plugins/<file>             each plugin's UMD bundle, from the plugin's own release
  config.json                {"plugins": [{"name", "url": "plugins/<file>"}]} and nothing else
  build-info.txt             artifact version, every pinned URL + sha256, this repo's commit and commit time
```

**Not in it:** track data, assemblies, and per-site configuration. The site
supplies those. `config.json` only registers the plugins, by relative URL, so
the tarball has no hostnames and works under any path.

## `build-manifest.json`

Every input is pinned here and nowhere else:

- `jbrowse`: the jbrowse-components `tag`, the `url` of its `jbrowse-web-<tag>.zip`
  release asset, and that asset's `sha256`.
- `plugins`: one `{name, url, sha256, file}` per plugin. `name` is the JBrowse
  plugin name, `url` is the plugin's release asset, and `file` is the name it is
  served under in `plugins/`.

To add a plugin, add one entry to `plugins`. To bump JBrowse or a plugin,
change its `url` and `sha256`.

### File names a VEuPathDB site can serve

The WDK webapp strips cache-busting fingerprints from asset URLs
(`EbrcWebsiteCommon/Site/webapp/WEB-INF/urlrewrite.xml`, rule "Resolve
assets"):

```
^(.*)-.{32}\.(ico|js|css|jpeg|jpg|gif|png)$   ->   $1.$2
```

Any file whose name has a `-` exactly 33 characters before the extension
gets served under a different name and 404s. Plugin release assets are
often named like this, for example
`jbrowse-plugin-subtrack-renderer-1.0.0-beta.18.umd.production.min.js`. That's
why `file` can differ from the asset's own name. The build fails, listing
every offending path, if anything under `jbrowse5/` matches the rule
(case-insensitive, as the rewrite filter applies it). If that happens, pick a
different `file`.

## Building locally

```bash
scripts/build-artifact.sh 0.0.0-dev
```

This needs `curl`, `jq`, `unzip`, GNU `tar`, `gzip` and `sha256sum`. It writes
`dist/jbrowse5-<version>.tar.gz` and `.sha256`, and caches downloads under
`build/`. Any sha256 mismatch fails the build.

The tarball is reproducible: two builds of one commit give the same sha256.
`build-info.txt` records `jbrowse2_tree: dirty` when built from uncommitted
changes.

To try it, serve the unpacked directory and open `index.html`:

```bash
tar -xzf dist/jbrowse5-0.0.0-dev.tar.gz -C /tmp && npx serve --cors /tmp/jbrowse5
```

## Releasing

The artifact has its own semver, independent of the JBrowse version it
contains. The first release is `v0.1.0`, and versions stay below 1.0 while
JBrowse 5 is in beta. `build-info.txt` records which JBrowse and plugins a
given version contains.

Push a `v*` tag. `.github/workflows/release.yml` checks the tag out, runs
`scripts/build-artifact.sh <tag without v>`, and attaches the tarball and its
`.sha256` to the tag's GitHub release, creating the release if needed. A version
containing `-` is published as a pre-release.

```bash
git tag v1.2.3 && git push origin v1.2.3
```

To publish an existing tag, run the workflow by hand: **Actions → release →
Run workflow** with `tag`, or

```bash
gh workflow run release.yml -f tag=v1.2.3
```

It builds the tagged commit using the workflow on the default branch. A re-run
replaces the assets.

## Asset URLs ApiCommonWebsite pins

```
https://github.com/VEuPathDB/jbrowse2/releases/download/v<version>/jbrowse5-<version>.tar.gz
https://github.com/VEuPathDB/jbrowse2/releases/download/v<version>/jbrowse5-<version>.tar.gz.sha256
```

## Other files

- `buildJbrowse2Config.sh` writes a JBrowse 2 `config.json` (assemblies and
  tracks) by scanning a webServices files tree for one build's genome FASTA and
  GFF indexes. It predates this artifact, and no build or deploy step uses it.
- `sample_files/` holds a PlasmoDB-61 *P. falciparum* 3D7 genome, its GFF and a
  matching `config.json`, used for trying JBrowse locally. Nothing references it.

## Migration documentation

Status, decisions and notes for the JBrowse 5 migration live in
[VEuPathDB/agentic-project-management](https://github.com/VEuPathDB/agentic-project-management/tree/main/jbrowse5-migration).
