# ksamintpro

Profile site for 郭峰 GUO Feng: `profileref.md` (index) and `event.md` are
rendered to HTML with pandoc, styled by `site.css` and `includes/fonts-head.html`.

## Build

```sh
scripts/build-site.sh            # into _site/ (ignored); needs pandoc
```

## Publish

There are no GitHub Actions workflows (owner decision 2026-11-05). The operator
publishes from their own machine:

```sh
scripts/publish-gh-pages.sh            # build, commit to gh-pages, push (no force)
scripts/publish-gh-pages.sh --no-push  # build the gh-pages commit only
```

The script refuses a dirty tree or a HEAD that is not `origin/main`, builds in
a clean temporary worktree, commits `_site` on top of the `gh-pages` branch
(an orphan branch the first time) and pushes it with your git credentials.

One-time owner setting: GitHub > Settings > Pages > Build and deployment >
Source "Deploy from a branch", branch `gh-pages`, folder `/ (root)`.
