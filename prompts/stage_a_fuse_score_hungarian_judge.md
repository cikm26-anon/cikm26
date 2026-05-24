# Stage A.FUSE — scoring + Hungarian + LLM judge

## Source
- `src/repro_agent/stages/stage_a_fuse.py`
  - `DEFAULT_WEIGHTS` (reliability weights)
  - `compute_pair_score()` — pairwise score formula
  - `build_score_matrix()` — full |C|×|K| matrix
  - `hungarian_assignment()` — `scipy.optimize.linear_sum_assignment` wrapper
  - `JUDGE_SYSTEM_PROMPT`
  - `REPORT_JUDGED_FUSION_TOOL`
  - `fuse()` — end-to-end orchestrator
- Called by `src/repro_agent/stages/stage_a_runner.py:run_stage_a`.

## Algorithm

### Step 1 — pair scoring

For each `(claim_i, segment_j)` pair, the weighted feature score is:

```
weight_used = Σ_f w_f · 𝟙_f(c,k)        # singleton policy
raw_score   = Σ_f w_f · s_f(c,k) · 𝟙_f(c,k)
score(c,k)  = raw_score / weight_used if weight_used > 0 else 0
```

Feature similarities `s_f`:

| Feature | s_f method | Notes |
|---|---|---|
| outcome_name | name_similarity (exact / contained / Jaccard) + alias bridge | 1.0 exact, 0.7 contained, 0.5·J for J≥0.5 |
| outcome_semantic | sentence-transformer cosine on description | semantic bridge |
| predictors | Jaccard on normalised names | |
| statistical_method | canonical match (1.0) or family match (0.6) | closed taxonomy |
| sample_size | numeric_close with rtol=0.05 | binary |
| interventions | Jaccard on normalised tokens | |
| study_groups | Jaccard on normalised tokens | |
| populations | Jaccard on normalised tokens | |
| figure_refs | binary intersection on `{kind:number}` tags | cross-modal bridge |

Default weights (sum ≈ 1.0 when all features present):

```
outcome_name=0.20, outcome_semantic=0.15, predictors=0.15,
statistical_method=0.15, sample_size=0.05, interventions=0.10,
study_groups=0.05, populations=0.05, figure_refs=0.10
```

### Step 2 — Hungarian one-to-one assignment

```python
from scipy.optimize import linear_sum_assignment

cost = -M
row_idx, col_idx = linear_sum_assignment(cost)
```

Pairs scoring below `score_threshold` (default 0.15) are dropped from
the assignment — those claims become paper-only, those units code-only.

### Step 3 — LLM judge

For each Hungarian-proposed match, the judge sees:

- the claim text and structured features
- the matched code unit's file, line ranges, summary, features
- the deterministic score + per-feature breakdown
- up to 3 alternative code units that scored highest among the
  unmatched candidates

The judge:

1. **Confirms** the proposed match with confidence ∈ {high, medium, low}, or
2. **Rejects** it, re-classifying the claim as paper-only and the
   code unit as code-only with diagnostic categories from the schema enums.

The judge cannot change the assignment direction — the one-to-one
structure is preserved. The judge only filters and adds rationale.

## Inputs to the judge LLM call

A single batched call (one per paper) with all Hungarian proposals.

The user message includes a JSON array of proposals; each contains:

```json
{
  "fused_id": "m{i}",
  "claim": {claim_key, claim_text, outcome, predictors, ...},
  "matched_code_unit": {unit_id, file, line_ranges, ..., formula_raw, ...},
  "deterministic_score": {score, weight_used, raw_score, per_feature},
  "alternatives": [{unit_id, file, score}, ...]
}
```

## Exact judge prompt template

System block (`JUDGE_SYSTEM_PROMPT`):

```
You are a structural-match verifier for claim-grounded reproducibility.

For each proposed (claim, code_unit) match produced by the deterministic
scoring + Hungarian solver, you decide whether the pairing is correct
and assign a confidence. You also generate the rationale field.

You are given, per proposal:
  - the claim text + anchors + features
  - the matched code unit with structured features
  - the deterministic score + per-feature breakdown
  - up to 3 alternatives that scored highest among unmatched candidates

Your decisions are constrained:
  J1. You CANNOT change the assignment direction. Only confirm or reject.
  J2. Confidence rubric:
        high:   ≥2 strong feature matches OR a single unambiguous anchor
        medium: ≥1 strong match supported by ≥1 weaker match
        low:    a single weak match or only semantic-similarity overlap.
                Prefer CONFIRM with low rather than REJECT unless the
                pairing is clearly absurd.
  J3. Generate a 1-2 sentence rationale citing which features supported
      the verdict.
  J4. Output ONLY via the report_fusion tool.
```

User message:

```
## PROPOSALS

```json
[
  {
    "fused_id": "m0",
    "claim": {...},
    "matched_code_unit": {...},
    "deterministic_score": {"score": 0.62, "weight_used": 0.65, ...},
    "alternatives": [...]
  },
  ...
]
```

Verify each proposal and report decisions via report_fusion.
```

## Output schema (`report_fusion` tool)

```json
{
  "decisions": [
    {
      "fused_id": "m0",
      "verdict": "confirm" | "reject",
      "confidence": "high" | "medium" | "low" | null,
      "paper_only_category": "<enum>" | null,
      "code_only_category": "<enum>" | null,
      "rationale": "..."
    }
  ]
}
```

The orchestrator maps confirmed proposals to
`FusedEntry(provenance="matched")` and rejected proposals to a
paper-only + code-only pair, producing a `FusionResult` consumed by
Stages B/C/D.

## Notes

- `LLMClient.call_tool` with `stage="A_FUSE"`, `max_tokens=16384`.
- `enable_llm_judge=False` runs scoring + Hungarian only and auto-
  confirms all matches at `medium` confidence (deterministic-only
  mode).
