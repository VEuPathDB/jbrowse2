# JBrowse 2/5 migration — workstreams

One page, so the whole thing can be held in your head at once. Updated
2026-10-14.

Three of these are waiting on someone else. Those are not behind.

---

## 1. Subtrack / synteny plugin — **done**

Repo: `jbrowse-plugin-subtrack-renderer`

PR #3 merged to `main` (`d378ba0`, 2026-10-07). 111 tests, typecheck clean,
builds. Subtracks, synteny rescale, ortholog shading all working and verified
in-browser.

Loose ends, none blocking:
- README still describes subtracks only — nothing about synteny, rescale or
  shading.
- `facet.labels` upstream ask written up in that repo's `docs/facet-upstream-gaps.md`, so
  chips read "Genes" instead of `subtrack: gene`. Not sent.
- Ortholog shading at many open lanes on one chromosome is untested.

## 2. Synteny data pipeline — **working, not committed**

Repos: `ApiCommonData` (canonical), `~/jbrowse2/synteny_data` (untracked dev copy)

`Load/bin/makeSyntenyGff.pl` + `Load/lib/sql/syntenyGff.sql` produce the GFF from
a single `--organismAbbrev`. Reads only — every statement is a SELECT. Verified
byte-identical across two implementations (md5 `167e895e…`), 1,446,969 features
for pknoH. No `apidbtuning` references; uses partitioned `webready` tables.

**Next:** commit the two files to ApiCommonData. Then decide what happens to
`~/jbrowse2/synteny_data` — it now holds a diverged copy of the same SQL, which
is how someone edits the wrong one.

## 3. Track configs at scale — **not started**

This is the big unstarted piece. >500 organisms, hundreds of tracks each.

`buildSyntenyTrackConfig.py` is dev-only today: it hardcodes
`BASE_URL = "http://localhost:9003"` and emits absolute URIs.

Needs: emit paths relative to the data root; restructure around JBrowse
connections rather than one flat `tracks` array (lazy, and makes entitlement
filtering cheap); decide generation-time vs request-time filtering for
restricted datasets. See "Track configuration at VEuPathDB scale" in
`ARCHITECTURE-NOTES.md`.

## 4. Hosting / deployment — **decision pending, yours**

Repo: this one, branch `jbrowse5-with-plugins` (uncommitted)

Leaning: Jenkins publishes a versioned build artifact, Apache serves it on each
site, Apollo stays a container Apache proxies. The v5 container sketch is on the
branch if the other option wins.

**Next:** the short write-up for Mustafa and the other developer, then a
decision. Nothing downstream is blocked on it.

## 5. Auth — **waiting on sysadmin**

OIDC at the Apache perimeter. The one technical requirement is that data and
config paths return 401 rather than redirecting. Apollo can accept the identity
Apache establishes via its custom-auth extension point.

Not yours to implement. Yours to make sure the 401 detail doesn't get lost.

## 6. Apollo3 on JBrowse 5 — **blocked upstream**

Two measured breaks (`APOLLO-ON-JBROWSE5.md`): a renamed jobs-widget action, and
a React 19 setState-during-render. Both small.

**Decision to make:** wait for GMOD, or send two PRs and unblock ourselves.
Until then a combined app isn't possible — but browse-only on v5 is.

## 7. JBrowse 5 release — **blocked on GMOD**

No GitHub release exists; betas are npm-only under `next`. Until one ships, a
build is a nightly or something we build and store. Affects only how the
artifact is pinned.

---

## If you only do one thing next

Commit the ApiCommonData files (#2). It is finished work sitting uncommitted,
and it is the only item here where the risk is losing something that already
works.
