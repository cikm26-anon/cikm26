# Stage A.JUDGE — programmatic alignment of EXTRACTED vs GOLD claims

## Status
Used

## Stage
Stage A evaluation (judge)

## Source location
- Defined in: `repro_agent/repro_agent/stages/stage_a_judge.py` (`SYSTEM_PROMPT`, `REPORT_TOOL`; function `judge_alignment`)
- Called by: `repro_agent.pipeline.run_stage_a_eval` (line ~388), for each regime in `[L, R, F]`.
- Entry-point script: `repro_agent/scripts/run_pipeline.py`

## Purpose
Aligns the extracted claim/unit list (per regime) to a curated GOLD claim list, producing precision/recall/F1 and per-item diagnoses. Also used to filter Stage B/C/D to gold-aligned fused_ids when `filter_by_gold=True`.

## Inputs inserted into the prompt
- `regime`: one of `"L"`, `"R"`, `"F"` (printed at top of user message).
- `gold`: the curated claim list (loaded from `gold/<paper>/claims_gold.json`).
- `extracted`: the regime-specific list — `claims` from mining_left, `code_units` from mining_right, or matched-entries from mining_fused — normalized so each item has a `claim_text` key.

## Expected output format
Tool-use call to `report_alignment` (validated as `AlignmentResult`). Returns:
- `matches`: gold_idx ↔ extracted_idx with confidence in {high, medium, low}
- `unmatched_gold`: reason ∈ {missed, partial-only, wrong-granularity}
- `unmatched_extracted`: category ∈ {plausible-extra, hallucination, non-codeable-leak}
- `metrics`: n_gold, n_extracted, n_matched, recall, precision, f1, hallucination_rate
- `summary`: free-text string

## Exact prompt template
System block (`SYSTEM_PROMPT`):
```
You are aligning two lists of scientific claims about the
same paper.

GOLD is the human-curated reference list.
EXTRACTED is the list produced by an automatic miner (paper-driven, code-driven,
or fused; the regime label is provided).

Match each gold claim to AT MOST ONE extracted claim and vice versa. Match
only when both refer to the same empirical finding (wording may differ; the
underlying empirical content must be the same).

For each match assign confidence ∈ {high, medium, low}. Reject low-confidence
proposed matches; split them into unmatched_gold + unmatched_extracted.

For unmatched_extracted, classify:
- plausible-extra: a real finding from the paper/code that gold happens not to cover.
- hallucination: an assertion not supported by the paper/code.
- non-codeable-leak: an interpretation/citation that should have been filtered.

For unmatched_gold, classify:
- missed: extractor did not find a match
- partial-only: gold is a composite that splits across several extracted items
- wrong-granularity: extractor bundles or splits at a different granularity

Output ONLY via the report_alignment tool.
```

User message:
```
Regime: {regime}

## GOLD

```json
{json.dumps(gold, indent=2, ensure_ascii=False)}
```

## EXTRACTED

```json
{json.dumps(extracted_norm, indent=2, ensure_ascii=False)}
```

Align them and report via report_alignment.
```

## Notes
- `LLMClient.call_tool` with `stage=f"judgeA_{regime}"`, `max_tokens=8192`.
- `extracted_norm` is produced by `_serialize_extracted` which converts code-units to `claim_text`-shaped dicts using `summary_text`. **Caveat**: in the R regime, the LLM judge sees code-unit summaries paraphrased as if they were claim text. Reviewers reading judge precision/recall should interpret R-regime numbers as alignment to a code-summary proxy, not to scientific claims directly.
- Corresponds to manual prompt `repro_agent/prompts/stage_a/02_judge_alignment.md`.

## Use in the pipeline — disclosure

A.JUDGE is **not part of the main pipeline**. It is a diagnostic
component used by:

1. **`run_stage_a_eval`**: produces the `eval_L.json`, `eval_R.json`,
   `eval_F.json` artifacts that report claim-level / unit-level / fused-
   level recall/precision/F1 against the human-curated gold. These
   numbers are **diagnostic**; they are not the headline metrics
   reported in the paper's main tables.

2. **`filter_by_gold` flag** (default `False`): when enabled by the
   pipeline caller, downstream Stages B/C/D operate **only** on fused
   entries that A.JUDGE deemed gold-aligned. This is an analysis
   convenience for inspecting downstream-stage failures conditional on
   gold-alignment. **It is not used to produce the headline numbers in
   `results/summaries/`.** If you ever enable this flag, the resulting
   metrics must be labeled as "gold-aligned subset" — the underlying
   pipeline cannot route claims to gold at production time.

3. The judge itself is an **LLM-based estimator**. The recall/precision
   numbers it produces are estimator outputs, not human-validated
   ground truth. Reviewers wanting human-grade alignment metrics would
   need a separate inter-annotator study (we do not run one here).

See `docs/known_limitations.md` § "Stage A.JUDGE: `filter_by_gold` is
a controlled-leakage flag" for the full disclosure.
