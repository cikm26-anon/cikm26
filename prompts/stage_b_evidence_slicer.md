# Stage B — single-shot evidence-slice extraction (SYSTEM_BASE)

## Status
Used (this is the primary Stage B path through the pipeline)

## Stage
Stage B (per-claim evidence slicing)

## Source location
- Defined in: `repro_agent/repro_agent/stages/stage_b_slicing.py` (`SYSTEM_BASE`, `REPORT_TOOL`; function `slice_evidence`)
- Called by: `repro_agent.pipeline.run_stage_b` (line ~636, `slice_evidence(payload, source_files=sources, paper_text=paper_text, client=client)`)
- Entry-point script: `repro_agent/scripts/run_pipeline.py`

## Purpose
For one fused entry (claim + optional code_unit_prior), extract the minimum executable code subset that supports the claim — across multiple files, with anchor bindings and a verdict.

## Inputs inserted into the prompt
- `claim_payload`: dict with `claim_text`, `anchors` (numeric + variable), and optional `code_unit_prior` (containing `unit_id`, `line_ranges`, `summary_text`, `dependencies`). Serialized as JSON in the user message.
- `source_files`: dict `path -> contents`, concatenated into a single cached system block with `=== FILE: ... ===` delimiters.
- `paper_text`: optional results+discussion text appended to the cached system block when `use_paper_context=True` (regime "03c"; otherwise regime "03b").

## Expected output format
Tool-use call to `report_evidence`. Validated through `_normalize_evidence_payload` (handles string-encoded nested objects and flat `line_ranges`) into `EvidenceBundle`:
```
{
  "claim_text": str,
  "anchors": {"numeric": [...], "variable": [...]},
  "supporting_evidence": {
    "code_slice": [{"file": str, "line_ranges": [[int,int],...], "code": str}],
    "data_files": [str],
    "predicted_output": {"stdout_excerpt": str, "artifacts": [str], "extracted_values": [...]},
    "anchor_bindings": [{"anchor_idx": int, "matched_value": ..., "abs_error": ..., "match": bool}],
    "verdict": "verified"|"partially-verified"|"unverified"|"conflicting",
    "caveats": str
  }
}
```

## Exact prompt template
System block 1 (`SYSTEM_BASE`):
```
You are an expert at reading research analysis code (R or Python)
and identifying the minimum subset of code that supports a specific empirical claim.

Rules for the slice:

0. If the user's claim payload includes `code_unit_prior`, treat its `line_ranges`
   as a high-confidence prior. Start the slice from those lines, then walk
   dependencies. Document any pruning in `caveats`.
1. Walk backwards from lines that compute the values referenced by the claim's
   anchors. Include every line they depend on (data load, library load,
   filter / group / transform, intermediate vars, final compute / print / plot).
2. Exclude unrelated code (other figures, tables, models, debug code).
3. Self-check dependencies: every function and non-base var referenced in the
   slice must have its definition inside the slice (custom helpers, themes,
   palettes, helper functions like se, pairwiseLetters). If a dependency is
   missing, either add its definition or note in `caveats`.
4. Predict the slice output. Bind each numeric anchor to a value with
   match: true/false (within rounding tolerance).
5. Verdict: verified | partially-verified | unverified | conflicting.
6. Multi-file: refer to each file by path; line_ranges per file.
7. Hard rules: every line in the slice must appear verbatim in SOURCE; do not
   invent code; do not hallucinate output values.
Output ONLY via the report_evidence tool.
```

System block 2 (cached):
```
## SOURCE

=== FILE: {path1} ===
{content1}
=== END FILE ===

=== FILE: {path2} ===
{content2}
=== END FILE ===
...

## PAPER

{paper_text}     # only present when use_paper_context=True (regime 03c)
```

User message:
```
Process this claim and return one evidence bundle via report_evidence:

```json
{
  "claim_text": "...",
  "anchors": {"numeric": [...], "variable": [...]},
  "code_unit_prior": {"unit_id": "...", "line_ranges": [[...]], "summary_text": "...", "dependencies": [...]} | null
}
```
```

## Notes
- `LLMClient.call_tool` with `stage="B"` (or caller-provided `stage_tag`), `max_tokens=16384`).
- The `_meta` written to `<fid>_evidence.json` records `"regime": "03c"` when `use_paper_context=True`, else `"03b"`.
- Corresponds to manual prompts `repro_agent/prompts/stage_b/03b_session_evidence.md` and `03c_session_evidence_with_paper.md`.
