# SEF-Slice — refinement prompt (sef_full / sef_minus / sef_retry)

## Status
Used (only by the SEF-Slice ablation experiment, not by the main pipeline)

## Stage
SEF refinement (post-Stage-B execution-feedback refinement on Q2 candidates: gold_pass AND pred_fail)

## Source location
- Defined in: `scripts/run_sef_slice.py` — `SYSTEM_PROMPT_TEMPLATE` constant, `build_refine_prompt(...)` (system + user assembly), and `FeedbackSignal.render_for_prompt(variant)` for the per-variant `## EXECUTION_FEEDBACK` block.
- Called by: same file, in `_run_one_refinement` / `_run_refinement_loop` which call `LLMClient.call_with_messages(system_blocks=sys_blocks, messages=messages, ...)` (around lines 753–768).
- Entry-point script: `scripts/run_sef_slice.py` (CLI: `--pilot` / `--full --methods ...`).

## Purpose
The same LLM that produced the original (failed) Stage B slice is asked to refine it. Three sibling variants share the same SYSTEM template; they differ only in the `## EXECUTION_FEEDBACK` block produced by `FeedbackSignal.render_for_prompt`:
- `sef_full`: typed structured feedback (status, error_type, missing_symbol, error_excerpt last 3 lines, executed_to_line, iteration).
- `sef_minus`: a one-line "your slice failed when executed. Try again." block.
- `sef_retry`: no feedback block at all; resample at T=0.7 from the original prompt.

## Inputs inserted into the prompt
- `claim_text` (one sentence)
- `language` ("R" or "PYTHON") — substituted into the SYSTEM template
- `paper_code_rendered`: full paper source with 1-indexed line numbers
- `failed_slice_code`: the previously generated slice
- `feedback`: a `FeedbackSignal` dataclass — rendered variant-specifically; `None` for `sef_retry`
- `refinement_history`: optional list of `{iter, error_type, missing_symbol}` summarising earlier failed refines

## Expected output format
A single JSON object (no markdown fence, no prose):
```
{
  "selected_ranges": {
    "<filename>": [[start_line, end_line], ...],
    ...
  },
  "rationale": "<one short sentence>"
}
```
Parsed by `parse_selected_ranges`.

## Exact prompt template
System block 1 (`SYSTEM_PROMPT_TEMPLATE`, with `{language}` substituted via `.format(language=language)`):
```
You are an expert scientific-code slicer. Your task is to refine a previously generated slice that failed to execute.

You will receive:
  1. The research claim (one sentence)
  2. The paper's full {language} source code, with 1-indexed line numbers
  3. The previously generated slice (which failed)
  4. Structured execution feedback (when available)

YOU MUST OUTPUT A SINGLE JSON OBJECT with exactly these keys:

  {
    "selected_ranges": {
      "<filename>": [[start_line, end_line], ...],
      ...
    },
    "rationale": "<one short sentence>"
  }

CONSTRAINTS — these are hard contracts, not suggestions:
  1. Line numbers MUST refer to existing lines in PAPER_CODE.
  2. You may NOT invent, fabricate, or modify line content. You only SELECT.
  3. Output ONLY the JSON. No prose, no markdown fences, no explanation.
  4. The selected ranges should form a MINIMAL slice that:
     (a) executes without error
     (b) computes the claim's quantitative result(s)
  5. Always include necessary library/import lines and data-loading lines
     from PAPER_CODE; never assume a global namespace exists.

You will not be shown numeric values from any prior execution stdout — only
the position (line number) where execution stopped. This is by design.
```
The SYSTEM block is then concatenated (still in the same cached system block) with:
```
PAPER_CODE follows. Each line is prefixed with its 1-indexed
line number. Refer to these line numbers in `selected_ranges`.

```r       # or ```python — chosen by language=="R"
{paper_code_rendered}
```
```

User message — concatenation of these parts (separated by `\n\n`):
```
## CLAIM
{claim_text}

## YOUR_PREVIOUS_SLICE (failed)
```r          # or ```python
{failed_slice_code}
```

{feedback.render_for_prompt(variant)}     # see EXECUTION_FEEDBACK variants below; sef_retry contributes nothing

## REFINEMENT_HISTORY (do not repeat failed fixes)     # only if refinement_history non-empty
- iter=1: error_type=missing_function symbol=foo → still failed
- iter=2: ...

## TASK
Produce the corrected `selected_ranges` JSON now. JSON only. No code fence. No prose.
```

### Variant-specific `## EXECUTION_FEEDBACK` block

**sef_full** (typed structured feedback):
```
## EXECUTION_FEEDBACK
- status:             {self.status}
- error_type:         {self.error_type}
- missing_symbol:     {self.missing_symbol or 'n/a'}
- error_excerpt:      |
    {last_line_1_of_stderr}
    {last_line_2_of_stderr}
    {last_line_3_of_stderr}
- executed_to_line:   {self.executed_to_line}/{self.slice_total_lines}  (position only; no values shown)
- iteration:          {self.iteration}
```

**sef_minus** (uninformative feedback):
```
## EXECUTION_FEEDBACK
- status: your slice failed when executed. Try again.
```

**sef_retry**: emits an empty string — no `## EXECUTION_FEEDBACK` block in the user message at all.

## Notes
- System block is wrapped with `cached(...)` (see `repro_agent.models.client.cached`) so the heavy paper-code block is prompt-cached across iterations.
- `sef_retry` is intentionally resampled at temperature 0.7 in the calling code (the other two run at temperature 0.0) — this is configured in `_run_one_refinement`.
- `max_tokens=4096` for all three variants (`sef_full` / `sef_minus` / `sef_retry`).
- DESIGN: partial stdout is NEVER passed to the LLM. Only position (executed_to_line) is shown.
- The Routing table (`ROUTING`) maps each method to its model: `claude_full → anthropic:claude-sonnet-4-5`, `gpt4o_full → openai:gpt-4o`, `gpt4o_mini_full → openai:gpt-4o-mini`.
