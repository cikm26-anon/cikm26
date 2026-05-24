# Stage C RAG v4 — gpt-4o-mini ablation variants

## Status
Used (in `run_stage_c_rag_eval.py` when `--prompt-version` is one of `stage_c_rag_v4a / v4b / v4c / v4ab / v4all`)

## Stage
Stage C — RAG ablation (v4 cluster experiments)

## Source location
- Prompt body in `repro_agent/repro_agent/retrieval/stage_c_prompt_builder_v4.py` — `render_stage_c_prompt(query, retrieved_examples, available_handles, prompt_version=…)`.
- Wired into `repro_agent/repro_agent/stages/stage_c_rag_classifier.py:classify_stage_c_with_llm` which dispatches to the v4 renderer when `prompt_version in V4_PROMPT_VERSIONS` (lines 417–425).
- Called by: `repro_agent/scripts/run_stage_c_rag_eval.py`.

## Purpose
Targeted cluster edits over the v3 builder, intended to lift gpt-4o-mini accuracy by hardening the Data Preprocessing vs Descriptive Statistics boundary and pinning a confidence rubric. Three orthogonal clusters:
- Cluster A — DataPrep hardening (DataPrep vs Descriptive disambiguation).
- Cluster B — Structural framing (C0 rule baseline + decision tree with Descriptive above DataPrep).
- Cluster C — Metadata signals (per-example DECISIVE_OPERATOR_FOR_LABEL line + confidence rubric).

Variants:
- `stage_c_rag_v4a` — only A
- `stage_c_rag_v4b` — only B (reorders precedence: Descriptive sits at #8, Data Preprocessing at #9)
- `stage_c_rag_v4c` — only C
- `stage_c_rag_v4ab` — A + B
- `stage_c_rag_v4all` — A + B + C (default for the v4 builder)

## Inputs inserted into the prompt
Identical to the v3 builder: `query` (`StageCExample`), `retrieved_examples` (list of `RetrievedExample`), `available_handles` (closed taxonomy), `no_corpus_support_handles`, `prompt_version`.

## Expected output format
Same as v3 — tool-use call to `report_rag_classification` (see `stage_c_rag_classifier.md`).

## Exact prompt template
Body sections (each `"\n\n"`-joined; precise text in `stage_c_prompt_builder_v4.py`):

1. `"SYSTEM:\n" + _SYSTEM_HEADER` (v4 variant, lines 132–147 — identical to v3 except mentions DataPrep/Descriptive disambiguation rule).
2. `f"PROMPT_VERSION: {prompt_version}"`
3. Rule precedence — `_RULE_PRECEDENCE_TEXT_V4_CLUSTER_B` when Cluster B is on (Descriptive above DataPrep), else `_RULE_PRECEDENCE_TEXT_V4_BASE` (DataPrep at #8, Descriptive at #9). Both are 9 numbered rules with sharpened wording for rules 8 and 9 vs v3.
4. `_BOUNDARY_RULE_TEXT` (verbatim from v3).
5. `_CLAIM_LANGUAGE_WARNING_TEXT` (verbatim from v3).
6. Cluster A only: `_DATAPREP_HARDENING_TEXT` (DATA PREPROCESSING vs DESCRIPTIVE STATISTICS DISAMBIGUATION, sub-rules A1 / A2; lines 268–298).
7. Cluster B only: `_C0_RULE_BASELINE_TEXT` (lines 303–316) followed by `_MINI_DECISION_TREE_TEXT` (lines 318–336).
8. Cluster C only: `_CONFIDENCE_RUBRIC_TEXT` (lines 341–356).
9. `_render_no_corpus_support_note(...)` (same NOTE block as v3).
10. `_render_handles_block(available_handles)`.
11. Retrieved-examples block (rendered by `_render_example_block` with `include_decisive_operator=flags.c`). When Cluster C is on, each example gets:
```
DECISIVE_OPERATOR_FOR_LABEL:
To inherit `{ex.gold_handle_label}` from this retrieved
    example, the CURRENT QUERY's EVIDENCE_CODE_DIGEST must
    contain {operator_family_from_HANDLE_DECISIVE_OPERATOR_table}. Without that operator in the CURRENT
    QUERY, do NOT predict `{ex.gold_handle_label}`.
```
12. Anti-copy note + (conditional) boundary caution + end marker (same as v3).
13. `"CURRENT QUERY:"` + `_render_query_block(query)`.
14. `_build_decision_checklist(flags)` — dynamic 4–7 item checklist depending on which clusters are on.
15. `_OUTPUT_SCHEMA_TEXT`.

User message (sent by `classify_stage_c_with_llm`): same `Classify the CURRENT QUERY using the report_rag_classification tool. Emit EXACTLY one tool call. Do not include any prose outside the tool call.`

## Notes
- All clusters reuse v3's evidence-code digest, anti-copy note, boundary caution, end marker, and output schema verbatim. Only the precedence text, three cluster blocks, the per-example DECISIVE_OPERATOR_FOR_LABEL line, and the dynamic decision checklist differ.
- Selected via `--prompt-version stage_c_rag_v4all` (or another variant) on `run_stage_c_rag_eval.py`.
- See `repro_agent/repro_agent/retrieval/stage_c_prompt_builder_v4.py` (module docstring) for the design rationale.
