# Stage D RAG — render_stage_d_prompt (full / skeleton)

## Status
Used (in `run_stage_d_rag_eval.py` evaluation harness)

## Stage
Stage D — RAG / generation ablation evaluation

## Source location
- Prompt assembled in `repro_agent/repro_agent/retrieval/stage_d_prompt_builder.py` — `render_stage_d_prompt(query, retrieval_context, mode=…, prompt_version=…, retrieved_example_style="full"|"skeleton")`.
- LLM call wrapped by `_call_model(client, prompt_body=…)` in `repro_agent/scripts/run_stage_d_rag_eval.py` (line ~392) which invokes `client.call_text(system_blocks=[{...thin system text...}], messages=[{"role":"user","content":prompt_body}], temperature=0.0, stage=stage, request_timeout_s=…)`.
- Called by: `repro_agent/scripts/run_stage_d_rag_eval.py` (line ~1905 `render_stage_d_prompt(...)`, line ~1933 `_call_model(...)`).
- Entry-point script: `repro_agent/scripts/run_stage_d_rag_eval.py`.

## Purpose
DTREG R/Python code generator under retrieval-augmented modes (D0_ZERO, D1_DOCS, D2_SIMILAR_NO_FILTER, D5_FULL, etc.). The full prompt body is delivered as one user message — the SYSTEM framing is part of the rendered body itself.

## Inputs inserted into the prompt
- `query` (`StageDGenerationTarget`): tuple_id, paper_id, claim_text, evidence_code, handle_pid / handle_label / handle_url / constructor_name / language, plus extracted structure (function_calls, libraries, formula_canonical, formula_family, target_variable, fixed_effects, random_effects, grouping_factors, input_data_objects, output_objects, artifact_names, input_files, output_n_rows / cols, emit_op_type, gold_dtreg_code for retrieved examples).
- `retrieval_context` (`StageDRetrievalContext`): mode + `api_docs` (a `StageDApiDocsBundle`) + `applied_examples` (list of `StageDRetrievedExample`).
- `mode`: optional — must match `retrieval_context.mode`.
- `prompt_version`: default `stage_d_rag_v1`.
- `retrieved_example_style`: `"full"` (default; per-example DTREG_PATTERN_CODE + EXAMPLE_EVIDENCE_SUMMARY) or `"skeleton"` (single placeholder-only skeleton + thin metadata stubs).

## Expected output format
A single fenced code block in the chosen language — `_OUTPUT_REQUIREMENTS_R` (for R) or `_OUTPUT_REQUIREMENTS_PY` (for Python) — with `load_datatype("<handle_url>")`, the `dt$<constructor_name>(...)` call, `dtreg::to_jsonld(...)`, and a `write()` of the JSON-LD to `<tuple_id>.jsonld` (or to the provided output filename). No prose outside the fence.

## Exact prompt template
Body assembled in `render_stage_d_prompt(...)` as the concatenation (no extra separator beyond the per-section trailing newlines) of the following blocks:

1. `<!-- prompt_version: {prompt_version} -->`
2. `## SYSTEM` + `_SYSTEM_HEADER` (lines 56–96 of source — full 12-item hard constraint list).
3. If `mode == "D2_SIMILAR_NO_FILTER"`: `_D2_UNSAFE_WARNING` (lines 98–105).
4. `_NESTED_OBJECT_HARD_RULE` (lines 306–350 — Forbidden vs Required R/Python examples for object-valued slots).
5. `_ANTI_NULL_OBJECT_SLOT_RULE` (lines 444–465 — never fill object slots with None/NULL).
6. `_data_analysis_wrapper_rule(query.language)` — either `_DATA_ANALYSIS_WRAPPER_RULE_R` (lines 353–385) or `_DATA_ANALYSIS_WRAPPER_RULE_PY` (lines 388–421).
7. `## CURRENT HANDLE INFO` — JSON block with handle_pid, handle_label, handle_url, constructor_name, language.
8. `## CONSTRUCTOR FIELD CARD ({ctor})` — per-constructor allowed/forbidden field card from `_CONSTRUCTOR_FIELD_CARDS` (`data_analysis`, `data_preprocessing`, `descriptive_statistics`, `class_discovery`, `correlation_analysis`, `factor_analysis`, `regression_analysis`, `group_comparison`, `class_prediction`, `multilevel_analysis`, `algorithm_evaluation`).
9. `## DTREG API CONTRACT` (when `api_docs.has_docs()`):
```
R structure:
```r
library(dtreg)
dt_analysis <- dtreg::load_datatype("https://doi.org/21.T11969/feeb33ad3e4440682a4d")
dt_method   <- dtreg::load_datatype("<handle_url>")
part        <- dt_method$<constructor_name>(...)
instance    <- dt_analysis$data_analysis(has_part = part, ...)
json        <- dtreg::to_jsonld(instance)
write(json, "<tuple_id>.jsonld")
```
Python structure:
```python
from dtreg.load_datatype import load_datatype
from dtreg.to_jsonld import to_jsonld
dt_analysis = load_datatype("https://doi.org/21.T11969/feeb33ad3e4440682a4d")
dt_method   = load_datatype("<handle_url>")
part        = dt_method.<constructor_name>(...)
instance    = dt_analysis.data_analysis(has_part=part, ...)
jsonld      = to_jsonld(instance)
with open("<tuple_id>.jsonld", "w") as f:
    f.write(jsonld)
```
Allowed fields for `<ctor>`: <list>
Forbidden fields (do NOT pass):
- `<field>`: <reason>
...
Do not use `show_fields(...)` in generated code unless explicitly needed.
Do not print or inspect fields. Generate the metadata object directly.
```
Conditionally appended: `_PYTHON_FALLBACK_WARNING`, `_FIELD_NAME_MISMATCH_WARNING`.

10. Anti-copy rule: `_ANTI_COPY_RULE_SKELETON` when `retrieved_example_style == "skeleton"` else `_ANTI_COPY_RULE` (only when retrieved-examples block is non-empty).
11. Retrieved-examples block — `full` mode renders per-example with TUPLE_ID, PAPER_ID, WHY_RETRIEVED, CLAIM, EXAMPLE_EVIDENCE_SUMMARY, DTREG object references, and `DTREG_PATTERN_CODE` (compact load_datatype+construction tail extracted from gold). `skeleton` mode renders a single `## SAME-HANDLE EXAMPLE STRUCTURE` block with the constructor-aware placeholder skeleton plus thin per-example metadata stubs.
12. `## CURRENT CLAIM` + the claim text.
13. `## CURRENT EVIDENCE_CODE` — fenced in the query's language, with C1 head/marker/tail compaction (threshold 4000 chars, head 2000 / tail 2000, marker `# ... [evidence_code truncated for prompt budget; full code available in trace] ...`).
14. `## CURRENT EXTRACTED_STRUCTURE` — JSON block of extracted structure.
15. `## CURRENT SLOT MAPPING HINTS` — per-slot derivation (has_input / has_output / executes / targets / level / evaluates / evaluates_for / formula_canonical / output matrix size) with explicit "do NOT pass None/NULL" reminders.
16. `## OUTPUT REQUIREMENTS` — `_OUTPUT_REQUIREMENTS_R` or `_OUTPUT_REQUIREMENTS_PY` (R lines 510–556; Python lines 558–585).

Thin system block sent alongside (from `_call_model`):
```
Respond strictly per the structured task body below.
```

## Notes
- `LLMClient.call_text` (not `call_tool`) — the model is free-form, output is parsed by downstream code-eval scripts.
- `temperature=0.0`; `stage=<varies>`; `request_timeout_s` is forwarded so hung calls surface as `LLMRequestTimeout`.
- Prompt body is also dumped to `out_dir/prompt_dumps/<retrieval_trace_id>.md` for audit.
- See `repro_agent/repro_agent/retrieval/stage_d_prompt_builder.py` (1843 lines total) for the full literal text of every block.
- Used by ablation runs under `evals/stage_d_rag/full_dryrun_*` (D0_ZERO, D0_ZERO_c1, D1_DOCS, D1_DOCS_c1, D5_FULL, D5_FULL_c1).
