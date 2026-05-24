# Stage A.LEFT — anchor-aware claim extraction

## Source
- `src/repro_agent/stages/stage_a_left.py`
  - `ANCHOR_EXTRACTOR_SYSTEM_PROMPT`
  - `REPORT_CLAIM_FEATURES_TOOL`
  - `extract_anchors_for_claim()`
- Called by `src/repro_agent/stages/stage_a_runner.py:run_stage_a`.

## Purpose

Given an input claim and the paper's Results+Discussion text, the stage:

1. Splits the section into paragraphs (deterministic, ≥80 chars).
2. Computes sentence-transformer cosine similarity
   (`all-MiniLM-L6-v2`) between the claim and each paragraph.
3. Selects the top-K paragraphs (default K=5, score floor 0.15).
4. Sends the claim plus retrieved paragraphs (each prefixed with `[¶N]`)
   to the LLM, which extracts a two-tier structured representation:

   - **Tier 1 — atomic anchors**: `numerical_anchors`,
     `variable_anchors`, `comparison_group_anchors`,
     `experimental_condition_anchors`, `figure_table_refs`,
     `statistical_method_anchors`, `metric_anchors`. Each anchor
     records `paragraph_idx` (1-indexed) for provenance.
   - **Tier 2 — semantic roles**: `outcome`, `predictors`,
     `statistical_method` (canonical from a closed 40+ term taxonomy),
     `sample_size`, `interventions`, `study_groups`, `populations`.

## Inputs inserted into the prompt

- `claim_text` — one input claim.
- `retrieved_paragraphs` — the top-K paragraphs from the
  Results+Discussion section, each prefixed with `[¶N]` for
  attribution.

## Expected output

Tool-use call to `report_claims`, validated as `ClaimFeatures`
in `src/repro_agent/stages/stage_a_features.py`.

## Exact prompt template

```
You are a claim-evidence extractor for claim-grounded reproducibility analysis.

You receive (1) ONE research claim and (2) a small set of paragraphs from
the same paper that the retriever judged most likely to support the claim.
Each paragraph is prefixed with [¶N], a 1-indexed paragraph identifier.

Your job is to extract the structured evidence the claim relies on,
attributing every anchor to a specific paragraph index.

Extract TWO tiers:

TIER 1 — atomic anchors:
  - numerical_anchors:    numeric values with unit and short qualifier
  - variable_anchors:     variable / column / metric identifier names
  - comparison_group_anchors:   treatment or group labels used in a comparison
  - experimental_condition_anchors:   conditions / interventions / cohort descriptors
  - figure_table_refs:    references to Figure/Table/Supplementary
  - statistical_method_anchors: method mentions (raw form + canonical hint)
  - metric_anchors:       reported metric names (R^2, p-value, F1, accuracy, ...)

TIER 2 — semantic roles (derived from anchors):
  - outcome, predictors, statistical_method, sample_size,
    interventions, study_groups, populations

Rules:
  R1. Each Tier-1 anchor MUST include paragraph_idx pointing at the [¶N]
      paragraph it was attributed to.
  R2. Tier-2 features may be derived from the claim text alone if Tier-1
      anchors are sparse; they do NOT require paragraph_idx.
  R3. statistical_method.canonical MUST be one of the closed taxonomy
      entries (linear_regression, anova, t_test, linear_mixed_effects, ...).
      If none fits, return "unknown".
  R4. Do not invent. If a feature has no evidence in the claim or
      retrieved paragraphs, omit it.
  R5. Output ONLY via the report_claims tool.
```

User message format:

```
## CLAIM

{claim_text}

## RETRIEVED_PARAGRAPHS

[¶3] ... first retrieved paragraph ...

[¶7] ... second retrieved paragraph ...

...

Extract atomic anchors and semantic roles for this claim.
Attribute every Tier-1 anchor to the [¶N] paragraph that contains it.
Report via report_claims.
```

## Notes

- `LLMClient.call_tool` with `stage="A_LEFT"`, `max_tokens=8192`.
- Embedder used by retrieval: `all-MiniLM-L6-v2` (sentence-transformers).
- See `docs/glossary.md` for terminology (`anchor`, `semantic role`,
  `analysis handle`).
