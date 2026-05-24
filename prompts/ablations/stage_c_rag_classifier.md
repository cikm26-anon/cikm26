# Stage C RAG classifier — render_stage_c_prompt (v3) and minimal (v4_minimal)

## Status
Used (in `run_stage_c_rag_eval.py` evaluation harness, not in the production pipeline by default)

## Stage
Stage C — RAG / classifier ablation evaluation

## Source location
- Prompt body assembled in `repro_agent/repro_agent/retrieval/stage_c_prompt_builder.py` — `render_stage_c_prompt(query, retrieved_examples, available_handles, ...)` and `render_stage_c_prompt_minimal(query, available_handles, ...)`.
- LLM tool call assembled in `repro_agent/repro_agent/stages/stage_c_rag_classifier.py` — `classify_stage_c_with_llm(...)` invokes `client.call_tool(system_blocks=[{"type":"text","text":rendered.body}], tool=RAG_REPORT_TOOL, messages=[...])`.
- Called by: `repro_agent/scripts/run_stage_c_rag_eval.py` for retrieval modes `C0-llm`, `C0-llm-minimal`, `C1`, `C2`, `C3`, `C4`, `C5` (lines ~270, 288, 294, 330).
- Entry-point script: `repro_agent/scripts/run_stage_c_rag_eval.py`

## Purpose
RAG-augmented Stage C classifier with deterministic, byte-stable prompt rendering. Closed-taxonomy classification with retrieved supporting examples (`RetrievedExample`).

## Inputs inserted into the prompt
- `query`: a `StageCExample` (paper_id, claim_text, evidence_code/evidence_code_short, extracted features, rule_activations, primary_rule, competing_rules, is_boundary_case, emit_op_type).
- `retrieved_examples`: list of `RetrievedExample` items (tuple_id, role, why_retrieved, claim_text, evidence code, extracted features, gold_handle_label, gold_handle_provenance, boundary_note).
- `available_handles`: list of `(handle_pid, label)` pairs — the full closed taxonomy.
- `no_corpus_support_handles`: optional list of labels with zero retrieved support.
- `prompt_version`: defaults to `"stage_c_rag_v3"` (or `"stage_c_rag_v4_minimal"` in the minimal variant). v4 ablation versions (`v4a/v4b/v4c/v4ab/v4all`) are routed to `stage_c_prompt_builder_v4.render_stage_c_prompt` instead.

## Expected output format
Tool-use call to `RAG_REPORT_TOOL` named `report_rag_classification`:
```
{
  "predicted_handle": <one of HANDLES enum>,
  "predicted_label":  <one of LABELS enum>,
  "confidence":       float 0..1,
  "rationale":        str,
  "secondary_candidate": {"handle": <enum>, "label": <enum>} | null,
  "decision_rule":    int 0..9,
  "boundary_invoked": bool,
  "retrieval_overrode_evidence": bool
}
```
Parsed into `StageCRagClassificationResult` (telemetry-side fields like `retrieval_mode`, `retrieved_tuple_ids` are stamped by the caller, not by the LLM).

## Exact prompt template (v3 — `render_stage_c_prompt`)
Body is built as `"\n\n".join(sections).rstrip() + "\n"` with the following ordered sections (each a literal block from `stage_c_prompt_builder.py`):

1. `"SYSTEM:\n" + _SYSTEM_HEADER`:
```
SYSTEM:
You are REPRO-AGENT Stage C classifier.

Classify a scientific claim and its evidence code into exactly one
DTREG handle from the AVAILABLE HANDLES list below.

- Use evidence code as the primary signal.
- Use claim text only as a weak prior.
- Retrieved examples are guidance for boundary cases, not ground truth.
- If retrieved examples conflict with the current evidence code, trust
  the current evidence code.
- Return only valid JSON matching the OUTPUT SCHEMA at the end of
  this prompt.
```

2. `f"PROMPT_VERSION: {prompt_version}"`

3. `_RULE_PRECEDENCE_TEXT` (verbatim from source — 9 numbered handle precedence rules, see `stage_c_prompt_builder.py` lines 336–374).

4. `_BOUNDARY_RULE_TEXT`:
```
BOUNDARY RULE:

`cld(emmeans(...))` alone is not enough. Always inspect the upstream
model:
- `lmer`/`glmer` with random effects  ==>  Multilevel Analysis
- `aov`/`lm` without random effects + post-hoc tests  ==>
  Group Comparison
- group summaries without tests  ==>  Descriptive Statistics
```

5. `_CLAIM_LANGUAGE_WARNING_TEXT`:
```
CLAIM-LANGUAGE WARNING:

Words like "significant", "higher", "different", "associated",
"correlated" in the claim are weak signals only. The evidence code
decides the handle.
```

6. NOTE block — varies on `no_corpus_support_handles`:
```
NOTE ON RETRIEVED EXAMPLES:

The retrieved examples are drawn from a finite corpus that may
not contain examples for every taxonomy handle. {absence_clause}
Absence of examples is NOT evidence against a handle.
```
Where `absence_clause` is either "All handles in the AVAILABLE HANDLES list have at least one retrieved example available in the wider corpus." OR `f"Specifically, the following handles are valid prediction\ntargets but have ZERO retrieved support in this corpus: {labels}."`.

7. `_render_handles_block(available_handles)`:
```
AVAILABLE HANDLES:

  {pid1}  {label1}
  {pid2}  {label2}
  ...
```

8. Retrieved-examples block — when non-empty:
```
RETRIEVED EXAMPLES:
(Digest keeps analytical operator lines and removes boilerplate.)

### Retrieved Example {i}: {ex.gold_handle_label}

TUPLE_ID:
{ex.tuple_id}

RETRIEVAL_ROLE:
{ex.role}

WHY_RETRIEVED:
{ex.why_retrieved or "(no rationale recorded)"}

CLAIM:
{ex.claim_text or "(empty)"}

EVIDENCE_CODE_DIGEST:
```r
{digest}     # _render_evidence_code_digest output, ≤ 700 chars by default
```

EXTRACTED_FEATURES:
- function_calls: {[…]}
- libraries: {[…]}
- formula_family: '<...>'
- rule_activations: {[…]}

GOLD_HANDLE_PROVENANCE:
{ex.gold_handle_provenance or "(unspecified)"}

# optional:
BOUNDARY_NOTE:
{ex.boundary_note}
```
Followed by:
```
Retrieved example `gold_handle_label` values are labels for THOSE retrieved examples only. Do NOT copy or inherit any retrieved example's `gold_handle_label` into your `predicted_label` for the CURRENT QUERY. Use retrieved examples only as structural / operator patterns to inform your reading of the CURRENT QUERY's own evidence.
```
And, if any example has `role == "boundary"`:
```
BOUNDARY EXAMPLE CAUTION: A retrieved example tagged with `RETRIEVAL_ROLE: boundary` illustrates a confusable pattern. It does NOT mean the CURRENT QUERY is itself a boundary case. Apply boundary logic only when the CURRENT QUERY has non-empty `competing_rules` or `is_boundary_case = True`.
```
And:
```
END OF RETRIEVED EXAMPLES — now classify only the CURRENT QUERY evidence.
```

When `retrieved_examples` is empty:
```
RETRIEVED EXAMPLES:

(no retrieved examples for this query)
```

9. `"CURRENT QUERY:"` then `_render_query_block(query)`:
```
### Current query

PAPER_ID:
{query.paper_id}

CLAIM:
{query.claim_text or "(empty)"}

EVIDENCE_CODE_DIGEST:
```r
{digest}
```

EXTRACTED_FEATURES:
- function_calls: {[…]}
- libraries: {[…]}
- formula_family: '<...>'
- rule_activations: {[…]}
- primary_rule: '<...>'
- competing_rules: {[…]}
- is_boundary_case: {True|False}
- emit_op_type: '<...>'
```

10. `_DECISION_CHECKLIST_TEXT` (6-item checklist, see source lines 76–101).

11. `_OUTPUT_SCHEMA_TEXT` (JSON shape spec).

User message (sent by `classify_stage_c_with_llm`):
```
Classify the CURRENT QUERY using the report_rag_classification tool. Emit EXACTLY one tool call. Do not include any prose outside the tool call.
```

## Exact prompt template (minimal — `render_stage_c_prompt_minimal`, used by `C0-llm-minimal`)
Sections:
1. `"SYSTEM:\n" + _SYSTEM_HEADER_MINIMAL` (shorter system header, see source lines 708–716).
2. `PROMPT_VERSION: {prompt_version}` (default `stage_c_rag_v4_minimal`).
3. `_RULE_PRECEDENCE_TEXT_MINIMAL` (9 rules in compact form, lines 718–742).
4. AVAILABLE HANDLES block.
5. `CURRENT QUERY:` + `_render_query_block(query)`.
6. `_OUTPUT_SCHEMA_TEXT`.

No retrieved-examples section, no boundary caution, no claim-language warning, no NOTE block, no decision checklist.

## Notes
- `LLMClient.call_tool` with `stage=f"C_RAG_{retrieval_mode}"`, `max_tokens=1024`.
- Used only when running `repro_agent/scripts/run_stage_c_rag_eval.py` — NOT invoked from `repro_agent.pipeline` (which uses the simpler `stage_c_classify.classify_unit`).
- v4 ablation prompts (`stage_c_rag_v4a/b/c/ab/all`) are sibling renderers in `stage_c_prompt_builder_v4.py` — see `stage_c_rag_v4_ablation.md` for that variant.
