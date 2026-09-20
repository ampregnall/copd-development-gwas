# COPD locus literature review — agentic pipeline

[Visit Webpage](https://ampregnall.github.io/copd-development-gwas/)

Traceable, multi-agent literature review for COPD GWAS locus gene prioritization, built
on Claude Code subagents + hooks.

## Quick start

1. `claude` (from this directory) — Claude Code will read `.mcp.json` and connect to the
   PubMed, bioRxiv (which also covers medRxiv), and Open Targets MCP servers automatically
   (first run may prompt you to approve the connections). PubMed/bioRxiv are the researcher
   agent's primary sources; Open Targets (L2G, colocalization, genetic constraint) is used
   by synthesis-lead only — see [Pipeline](#pipeline) below. All three are plain
   project-level `.mcp.json` servers, so no per-user plugin install is required. (An
   `open-targets@life-sciences` marketplace plugin also exists and points at the same
   Open Targets MCP endpoint, but this project uses the `.mcp.json` server directly —
   `mcp__open-targets__*` — not the plugin; if you'd previously installed the plugin for
   this project, it's redundant and safe to remove with `/plugin uninstall
   open-targets@life-sciences`.)
2. Provide locus input, either:
   - **One locus at a time:** copy `loci/EXAMPLE_LOCUS_TEMPLATE.md` to
     `loci/<your-locus-name>.md` and fill it in by hand, or
   - **All loci at once, from your pipeline's output tables:** provide two `.txt` files —
     see [Batch input from two tables](#batch-input-from-two-tables) below.
3. Run `/review-locus <your-locus-name>` for a single locus, or `/review-loci
   [<loci_definitions.txt> <credible_sets.txt>]` to generate and review every locus in the
   two tables (agents/subagents fan out per locus, in small resumable batches — see
   [Resuming an interrupted run](#resuming-an-interrupted-run)).
4. Read `evidence_tables/<your-locus-name>.md` (verified evidence, plus the Open Targets
   summary and prioritized-gene call) and `audits/<your-locus-name>_audit.md`
   (rejected/contested citations, with reasoning) — kept in a separate top-level directory
   from the evidence tables so you can hand out one without the other — **review every
   citation yourself before trusting it.**
5. Full provenance for that run is in `logs/audit.jsonl` (raw) and
   `logs/agent_model_registry.json` (which model + exact system-prompt hash ran).

## Batch input from two tables

Instead of writing `loci/<locus>.md` files by hand, you can provide two tab- (or comma-)
delimited `.txt` files and let `/review-loci` generate all of them and launch the full
pipeline for every locus in parallel:

- **Loci definitions** — one row per locus: `locus, chr, start, stop, lead_variant,
  nearest_gene` (optionally `build`, `ancestry`, `notes`, and `flames_genes`,
  `magma_genes`, `pops_genes`, `abc_genes` — each a comma/semicolon-separated list of
  gene symbols prioritized by that method for the locus). Example:
  `loci/EXAMPLE_loci_definitions.txt`.
- **Credible sets** — one row per credible-set variant: `locus, variant` (optionally `chr`,
  `pos`, `pip`, `gene`, and `consequence`/`impact` — VEP most-severe consequence and impact
  for the variant, e.g. `missense_variant` / `MODERATE`), where `locus` matches the id used
  in the definitions table. Example: `loci/EXAMPLE_credible_sets.txt`. The researcher agent
  uses `consequence`/`impact` to decide which credible-set variants (beyond the lead
  variant) warrant their own literature search — see
  [Scope: genes are the unit of evidence](.claude/agents/researcher.md) in the researcher's
  agent definition.

Column headers are matched case-insensitively with common aliases (e.g. `rsid`/`snp` for
`variant`, `end` for `stop`, `flames`/`flames_gene` for `flames_genes`) — see the docstring
in `scripts/build_loci_from_tables.py` for the full alias list. By default `/review-loci`
looks for `loci/loci_definitions.txt` and `loci/credible_sets.txt`; pass explicit paths as
arguments to use different files or locations.

If you provide the `flames_genes`/`magma_genes`/`pops_genes`/`abc_genes` columns, every
gene they list is rendered into the generated locus file's "Candidate genes from internal
pipeline" section and the researcher agent treats each one as a candidate to research,
whether or not multiple methods agree on it. Any of these columns can be left out — the
generated locus file only lists what you provide — and the researcher agent still falls
back to literature search and an Ensembl region lookup for additional candidate genes
regardless. If you have richer internal-pipeline outputs than this flat-table format
supports, the hand-written template (`loci/EXAMPLE_LOCUS_TEMPLATE.md`) can capture
anything else and generally yields a better-anchored review.

You can also run the generation step alone, without launching the review, with:
```
python3 scripts/build_loci_from_tables.py <loci_definitions.txt> <credible_sets.txt>
```

## Resuming an interrupted run

Each locus's full pipeline (one researcher agent, covering statistical genetics,
structural/developmental lung biology, and immunology/inflammation, + citation-verifier +
red-team-skeptic + synthesis) runs inside one synthesis-lead subagent, and it is
checkpointed **stage by stage**, not just at the end — the researcher agent itself
saves its own progress incrementally, per candidate gene, so even a single long-running
researcher call surviving an interruption only loses whatever gene it was mid-way through.
To survive a session running out of tokens partway through a multi-locus batch,
`/review-loci`:

- has synthesis-lead write `evidence_tables/_status/<locus>.json` (`in_progress` →
  `complete`) as the first and last thing it does for a locus, with per-stage checkpoint
  files under `evidence_tables/_status/<locus>/` in between, and
- processes pending loci in small batches (default 3 concurrent, override with
  `--batch-size N`) rather than launching every locus at once, so at most one batch's
  worth of loci is ever at risk if the session is cut off.

**To resume:** just re-run `/review-loci` (same table paths) in a new session. It
regenerates the locus files (idempotent), checks `evidence_tables/_status/` for what
already finished, and only (re)runs loci that are `not_started` or
`in_progress_or_interrupted`. Check progress any time — no Claude session needed — with:
```
python3 scripts/loci_status.py
```
To force a specific locus to redo despite being marked complete, delete its
`evidence_tables/_status/<locus>.json` (or the whole `_status/` directory to redo
everything). A locus that was cut off mid-pipeline always restarts from scratch — the
checkpoint is per-locus, not per-pipeline-step.

## Pipeline

`/review-loci` runs one copy of this pipeline per locus, in small batches (see above),
after generating `loci/<locus>.md` for every row in the two input tables.

```
loci/<locus>.md
      |
      v
+-----------------------------------------------------------+
|                      synthesis-lead                        |
+-----------------------------------------------------------+
                      |
                      v
              Open Targets lookup
      (synthesis-lead itself, not a subagent: L2G score,
       colocalization, genetic constraint per candidate
       gene, via the open-targets plugin; checkpointed,
       not citation-verified — it's a database query,
       not a literature claim)
                      v
                  researcher
      (statistical genetics + structural/developmental
       lung biology + immunology/inflammation, for every
       candidate gene at the locus; PubMed + bioRxiv/medRxiv
       MCP tools as primary source, WebSearch/WebFetch as
       fallback; given the Open Targets summary as context;
       checkpoints its own progress per gene)
                      v
             citation-verifier
        (existence / retraction / claim match
         via PubMed E-utilities, Crossref,
         Retraction Watch)
                      v
              red-team-skeptic
     (LD/nearest-gene bias, smoking confounding,
      contradicting evidence, overclaiming)
                      v
               synthesis-lead
   (final evidence table -> evidence_tables/<locus>.md;
    excluded/contested appendix -> audits/<locus>_audit.md)
```

There used to be three separate domain-expert agents (statistical genetics; structural/
developmental lung biology; immunology/inflammation) dispatched in parallel per locus; they
are now one consolidated `researcher` agent (`.claude/agents/researcher.md`) covering all
three domains, still one instance per locus.

Open Targets (L2G, colocalization, genetic constraint) was removed early on because the
prior integration was unreliable in practice (frequent rate-limit failures, wasted web
requests — see e.g. the "Note on Open Targets data" in `evidence_tables/1_28200001-28950000.md`
from before the change) and has since been added back, scoped to synthesis-lead only (not
the researcher or red-team-skeptic), via the `open-targets` project-level MCP server
declared in `.mcp.json` (`mcp__open-targets__*` GraphQL tools) — see
[Quick start](#quick-start). Its output is a structured database
lookup, not a literature citation, so it's checkpointed and reported separately from the
verified evidence table and never passes through citation-verifier.

## Tracking token usage and cost

Run, any time, from this directory:
```
python3 scripts/usage_report.py
```
This prints token usage and estimated USD cost broken down by agent type
(researcher/citation-verifier/red-team-skeptic/synthesis-lead) and, separately, by locus.
No setup or opt-in is required — it reads the per-subagent transcript files Claude Code
already writes for every agent invocation (`~/.claude/projects/<project>/<session>/subagents/agent-<id>.jsonl`
+ `.meta.json`), which carry a full `usage` object (input/output/cache tokens, model) per
API response. This is different from, and more complete than, Anthropic's documented
OpenTelemetry mechanism for this — OTel export requires opting in and, per Claude Code's
docs, replaces the `agent.name` attribute with `"custom"` for project-local agents like
ours, which would make a per-agent breakdown impossible; the local transcripts have no
such limitation and need no extra configuration.

Per-locus attribution works by reconstructing the actual dispatch tree (matching each
subagent's `toolUseId` against the `tool_use` block that spawned it, in its parent's own
transcript — not a timestamp guess), then reading the locus id out of the description
`synthesis-lead` was dispatched with (see "Dispatch descriptions must include the locus id
verbatim" in `.claude/agents/synthesis-lead.md`). A gene-name fallback (matching against
each locus's nearest/candidate genes in `loci/<locus>.md`) covers older runs whose
descriptions predate that convention; invocations that still can't be resolved are listed
separately rather than guessed.

Caveats printed by the script itself: cost uses a recorded `cost_usd` when a transcript
line has one, and otherwise estimates from token counts using per-model $/MTok pricing,
with prompt-cache write/read priced at standard Anthropic multipliers (1.25x / 0.1x of the
base input rate) rather than model-specific cache rates — treat estimated (`~`-flagged)
totals as approximate, not billing-accurate.

## Before you rely on this for a manuscript

- **Verify exact MCP tool names once connected.** The `tools:` field in each agent's
  frontmatter lists specific tool names (e.g. `mcp__pubmed__search_articles`) — run `/mcp`
  in a live session to confirm the exact tool names the PubMed/bioRxiv servers expose, and
  adjust the frontmatter if needed.
- **`README_METHODS.md`** is a draft you fill in per manuscript (date ranges, model
  version strings, git commit) — it isn't meant to be quoted verbatim without those.
- **You are the last line of defense.** The verifier and red-team agents materially
  reduce (not eliminate) hallucination risk. Spot-check verified citations yourself,
  especially any marked borderline by the red-team agent.
