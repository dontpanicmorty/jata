---
name: git-identity
description: The author identity every commit in this repository must use, and what never goes into commit history. Use this before any git commit, amend, rebase, merge or history rewrite in this repository.
---

# Git identity for this repository

This repository is public, so its commit history is public too.

## Author email: always the private GitHub address

Every commit must be authored and committed with:

```
62984107+dontpanicmorty@users.noreply.github.com
```

Never use the owner's personal email address in a commit, as author or committer. It was rewritten out of
this repository's history on purpose, to keep it private.

- The repository's local git config already sets it (`git config user.email` here returns the address
  above). Check it before committing, especially in a fresh clone, where the local config isn't copied:
  `git config user.email 62984107+dontpanicmorty@users.noreply.github.com`.
- If a commit is made with any other email, amend or rewrite it before pushing.

## Never in commit messages

- No `Co-Authored-By` trailers, and no lines crediting an AI tool. (The project's own documentation already
  says agentic AI was used to build it.)
- No employer names, internal ticket or workspace identifiers, or links to private systems.
