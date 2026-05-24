# Stage A.RIGHT — code-unit mining (output-anchored evidence units)

## Source
- `src/repro_agent/stages/stage_a_claims.py`
  - `mine_code_units()` — single LLM tool-use call over the paper's source files
  - `report_code_units` tool (integer line-range contract)
  - deterministic range normalizer (drops non-integer ranges, e.g. `<UNKNOWN>`)
  - `slice_code_from_file()` — verbatim re-read of the selected line ranges
- Called by `src/repro_agent/stages/stage_a_runner.py:run_stage_a`.

## Purpose

Stage A.RIGHT mines output-anchored reproducible evidence units from the
paper's code repository `K_p`. In a single tool-use call over the source
files, the model starts from computational **sinks** — statements that emit
statistical results, summaries, figures, tables, files, or printed outputs
(e.g. `summary`, `anova`, `print`, `cat`, `write.csv`, `ggsave`,
`plt.show`) — and, for each sink, includes the upstream statements needed to
reproduce the emitted result. It walks backward through data dependencies
until it reaches a data-loading operation, a helper boundary, or an
unresolved dependency.

The model **does not produce code text**: it emits only integer line ranges
into named source files plus structured metadata. The verbatim slice is then
re-read from the repository using the returned ranges, so the executable
evidence is always the original repository source.

## Inputs inserted into the prompt

- `source_files` — the paper's analysis source files (R/Python), each
  rendered with 1-indexed line numbers and `=== FILE: ... ===` delimiters.

## Expected output

Tool-use call to `report_code_units`, returning one record per mined unit
(validated as `CodeUnit`):

```
{
  "code_units": [
    {
      "unit_id": str,
      "file": str,                      # named source file
      "line_ranges": [[int, int], ...], # integer ranges only
      "emit_type": str,                 # figure | table | stat | file | print | ...
      "artifact_name": str | null,      # when available
      "data_files": [str],              # data files consumed
      "dependencies": [str],            # dependency notes / unresolved symbols
      "summary": str,                   # factual summary
      "extracted_values": [...],        # when deterministically readable
      "provenance": {"file": str}       # file-level provenance
    }
  ]
}
```

## Exact prompt template

System block:

```
You are a computational-evidence miner for claim-grounded reproducibility.

You receive the paper's analysis source files (R or Python). Identify the
output-anchored computational units they contain. Start from computational
SINKS: statements that emit statistical results, summaries, figures, tables,
files, or printed outputs (e.g. summary, anova, print, cat, write.csv,
ggsave, plt.show, and related operations).

For each sink, include the upstream statements needed to reproduce the
emitted result. Walk BACKWARD through data dependencies until you reach one
of: a data-loading operation, a helper boundary, or an unresolved dependency.

You DO NOT produce code text. You emit ONLY integer line ranges into named
source files, together with structured metadata: emit type, artifact name
(when available), data files consumed, dependency notes, a factual summary,
and extracted values when deterministically readable.

Hard rules:
  R1. Emit integer [start, end] line ranges only; never invent or rewrite
      code. Ranges that cannot be parsed as integers (e.g. <UNKNOWN>) are
      discarded downstream.
  R2. One unit per sink; include only the lines the sink depends on, up to a
      data-loading op, helper boundary, or unresolved dependency.
  R3. Output ONLY via the report_code_units tool.
```

User message:

```
## SOURCE_FILES

=== FILE: {path1} ===
{content1, 1-indexed line numbers}
=== END FILE ===

=== FILE: {path2} ===
{content2, 1-indexed line numbers}
=== END FILE ===
...

Mine the output-anchored code units from these files and report them via
report_code_units. Emit integer line ranges only; do not produce code text.
```

## Notes

- `LLMClient.call_tool` with `stage="A_RIGHT"`, `max_tokens=16384`; one call
  per paper over the source files.
- The LLM performs unit identification and boundary selection only; the
  executable evidence is always the verbatim repository source, re-read from
  the returned line ranges via `slice_code_from_file`.
- Units whose ranges are non-integer (e.g. `<UNKNOWN>`) are dropped by a
  deterministic normalizer before Stage A.FUSE.
- Large code bases use a hierarchical mode: each source file is mined under
  the same prompt, and units sharing data dependencies across files are
  joined via the `dependencies` field.
- The structured segment features used for A.FUSE scoring (outcome,
  predictors, statistical_method, sample_size, interventions, study_groups,
  populations) are computed separately and consumed in Stage A.FUSE; A.RIGHT
  itself emits only line-range code units.
