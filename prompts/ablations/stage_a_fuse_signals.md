# Stage A.FUSE — evidence-signals judge variant (ablation)

## Status
Ablation — **run and reported**. One of the two reported ablations in the
paper (A.FUSE-signals and SEF). Opt-in variant of the Stage A.FUSE judge,
not the shipped-pipeline default.

## Stage
Stage A.FUSE — judge variant that additionally surfaces, per entry, the
evidence signals behind each claim–code match.

## Purpose
A.FUSE-signals emits the **same `report_fusion` contract** as the default
Stage A.FUSE judge (`stage_a_fuse.JUDGE_SYSTEM_PROMPT`). On top of the base
confirm/reject decision, it reports — per entry — which evidence signals
**matched** and which are **missing**, through additive optional schema
fields that default to empty. A consumer that ignores those fields sees
byte-identical behaviour, so Stages B/C/D consume the result unchanged.

The intent is to make the evidence grounding of each match auditable and to
characterise how much of the alignment rests on grounded, claim-specific
signals rather than topical / semantic overlap.

## Signal taxonomy
The reported signals are the Stage A.FUSE features (Section A-Fuse).

A *strong* signal:

- exact numeric anchor overlap (matched value within ±5%),
- canonical statistical-method match (`method.canonical` equal on both sides),
- explicit figure/table reference shared by claim and code unit,
- outcome variable name match (after the alias bridge).

A *weaker* signal:

- predictor-set Jaccard ≥ 0.5,
- grouping/intervention/population token overlap,
- sample-size proximity (within ±5%),
- semantic cosine on outcome description ≥ 0.7.

## Confidence (unchanged from the default judge)
Same rubric as `JUDGE_SYSTEM_PROMPT`; the variant does **not** change these
decisions — it only emits the matched/missing signals explicitly:

- high:   ≥2 strong matches, or a single unambiguous anchor
- medium: ≥1 strong match supported by ≥1 weaker match
- low:    a single weak match or only semantic-similarity overlap
          (prefer confirm with low rather than reject unless clearly absurd)

## Output schema (additive)
Same `report_fusion` tool as the default judge; each decision additionally
carries two optional fields that default to empty:

```
{
  "decisions": [
    {
      "fused_id": "m0",
      "verdict": "confirm" | "reject",
      "confidence": "high" | "medium" | "low" | null,
      "paper_only_category": "<enum>" | null,
      "code_only_category": "<enum>" | null,
      "rationale": "...",
      "matched_signals": ["numeric_anchor", "method.canonical", ...],  # additive, optional
      "missing_signals": ["figure_ref", ...]                           # additive, optional
    }
  ]
}
```

Consumers that ignore `matched_signals` / `missing_signals` behave
identically to the default judge.

## Notes
- `LLMClient.call_tool` with `stage="A_FUSE"`, `max_tokens=16384`,
  temperature 0.0; one call per paper (paper Table: "1 per paper (abl.)").
- Selected via the opt-in `judge_variant="signals"` argument on `fuse(...)`;
  the default is `stage_a_fuse.JUDGE_SYSTEM_PROMPT`.
- The deterministic per-feature scoring and Hungarian assignment are the
  same as the default A.FUSE; only the judge prompt changes (it now also
  reports matched/missing signals).
