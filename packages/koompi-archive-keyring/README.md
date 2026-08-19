# koompi-archive-keyring

`usr/share/keyrings/koompi-archive-keyring.gpg` is generated, not
committed — `repo/build-repo.sh` exports it from the signing key it
generates under `build/repo-signing/` before building this package. The
file is gitignored; a checkout has nothing here until that script runs.
