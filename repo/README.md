# repo/

koompi-repo signing and publishing — the specification is
docs/REPO_POLICY.md.

`build-repo.sh` generates a signing key under the gitignored `build/` if
one doesn't exist yet, exports its public half into
`packages/koompi-archive-keyring/`, builds every package under
`packages/`, and publishes them into a `reprepro`-managed repo under
`build/repo/` using `conf/distributions`. Runs inside a Debian container
(needs `debhelper`, `dpkg-dev`, `git`, `gnupg`, `reprepro` — see
`scripts/builder.Containerfile`), never on this host directly.

No CI publishing pipeline yet (REPO_POLICY.md §2.5) — this only covers
building and signing a local repo for the ISO (docs/ARCHITECTURE.md §6,
Phase 4's QEMU run).
