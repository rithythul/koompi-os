# Default models: BGE-M3 embedder (welds the schema dim), clean-license chat tier, build-time LICENSE gate

**BGE-M3 (MIT, 1024-dim, Khmer-capable) is the default embedder.** This **welds
`embedding_dim=1024`** into the index schema (`vec_chunks float[N]`), so it is **high
lock-in** — changing the embedder later forces a destroy-and-re-embed of the entire corpus.
We chose it because it is the one embedder that is *both* clean-license *and* Khmer-capable;
it must be fixed before any L1 schema code lands ([[0001-degrade-local-never-silent-cloud]]
sets the Floor that sizes it).

**Chat defaults to a clean-license TIER** (Sailor2 / SEA-LION family, Apache/MIT), pinned to
an **exact model + quant per RAM tier at build time** — 8 GB Floor: a ~1–3B Q4 Khmer-capable
model; 16 GB+: Sailor2-8B. The v1 **reasoning-model tier is cut** (no usably-small reasoning
model fits the Floor).

**Model weights are first-class, license-gated dependencies.** A CI step reads each bundled
weight's actual `LICENSE` file and **fails the build** on use-restricted terms — explicitly
rejecting Qwen-research, Gemma custom terms, and Llama-MAU as bundled defaults. Verify the
file, never SEO claims.

**Honest consequence:** floor-tier Khmer chat is **modest**; strong Khmer is a **16 GB+**
experience. At the Floor the fallback is reduced-local or a *consented* cloud option, never a
silent cloud fallback ([[0001-degrade-local-never-silent-cloud]]).

## Open (owner: KOOMPI model eval)

The exact chat model per tier is pinned at build **after a Khmer eval** — no specific model
mandated yet.
