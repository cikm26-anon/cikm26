# Stage D — dtreg R/Python code generation

## Status
Used

## Stage
Stage D (DTREG code generation)

## Source location
- Defined in: `repro_agent/repro_agent/stages/stage_d_dtreg.py` (`SYSTEM_PROMPT_BASE`, helper `_build_few_shot_section`, `DTREG_FEW_SHOTS`, `REPORT_TOOL`; function `generate_dtreg_code`)
- Called by:
  * `repro_agent.pipeline.run_stage_d` (line ~820, `generate_dtreg_code(claim, bundle, classified, output_filename=f"{fid}.json", client=client)`)
  * `repro_agent.scripts.run_stage_d_zero_shot.py` (line 138, `gen = generate_dtreg_code(...)`)
  * `scripts/gen_paper_stage_d_v3.py` (line 560, `gen = generate_dtreg_code(...)`)
- Entry-point scripts: `repro_agent/scripts/run_pipeline.py`, `repro_agent/scripts/run_stage_d_zero_shot.py`, `scripts/gen_paper_stage_d_v3.py`

## Purpose
Generates dtreg R (or Python) code that, when executed, emits a JSON-LD record conforming to the TIB Knowledge Loom / Loom-style JSON-LD form. Output is consumed by Stage E's sandbox runner.

## Inputs inserted into the prompt
- `claim`: dict `{claim_text, anchors}` rendered as JSON.
- `evidence_bundle`: full Stage B evidence dict rendered as JSON (truncated to 8000 chars).
- `classified`: full Stage C classification dict rendered as JSON.
- `r_vars`: list of R variable names extracted from the evidence code slice via `_extract_r_variables` regex (only included when non-empty).
- `script_url`: optional URL string.
- `output_filename`: optional filename for the `write()` call (e.g. `<fid>.json`).
- `snippet_filename`: optional snippet filename for `is_implemented_by`.
- `handle`: the predicted handle (from `classified["predicted_handle"]`).
- `expected_constructor`: looked up from `HANDLE_TO_CONSTRUCTOR[handle]`.
- The full constructor map and the few-shot section are appended into the system prompt.

## Expected output format
Tool-use call to `report_dtreg_code`:
```
{
  "language": "r"|"python",
  "code": str,
  "constructor_name": str,
  "expected_output_filename": str,
  "caveats": str
}
```
Validated as `DtregGenResult`. Markdown fence stripping is applied defensively to `code`.

## Exact prompt template
System prompt is `SYSTEM_PROMPT_BASE + constructor_lines + "\n\n" + _build_few_shot_section(target_handle=handle)`.

`SYSTEM_PROMPT_BASE` (verbatim):
```
You generate dtreg R code (dtreg 1.1.2+) that, when
executed, emits a JSON-LD record matching the TIB Knowledge Loom / Loom-style JSON-LD
canonical form. Every record wraps a sub-handle inside the universal
`data_analysis` parent.

CANONICAL SKELETON (mirror this shape exactly):

  library(dtreg)
  # 1. Load BOTH the parent (data_analysis) AND the child sub-handle.
  dt1 <- dtreg::load_datatype("https://doi.org/21.T11969/feeb33ad3e4440682a4d")  # Data analysis (parent)
  dt2 <- dtreg::load_datatype("https://doi.org/21.T11969/<CHILD_HANDLE>")         # sub-handle

  # 2. Build the WHOLE record in ONE nested constructor expression
  #    (constructor-arg style; NOT field-by-field assignment).
  instance <- dt1$data_analysis(
    is_implemented_by = check_resource_url("<source-snippet>.R"),
    has_part = dt2$<child_constructor>(
      label    = "<one-sentence description of the analysis unit>",
      executes = dt2$software_method(
        label             = "<function-name, e.g. lm, prcomp, glmmTMB>",
        is_implemented_by = "<the exact call, e.g. lm(rL ~ plotareaL, data=df)>",
        has_support_url   = "<docs URL if known, else omit>",
        part_of = dt2$software_library(
          label           = "<package name, e.g. stats, glmmTMB>",
          version_info    = "<package version>",
          has_support_url = "<CRAN/Bioconductor URL>",
          part_of = dt2$software(
            label           = "R",
            version_info    = "4.2.3",
            has_support_url = "https://www.r-project.org"
          )
        )
      ),
      has_input = dt2$data_item(
        source_table       = <r_variable_name_in_scope>,
        has_part           = list( dt2$component(label="<col1>"),
                                   dt2$component(label="<col2>") ),
        has_characteristic = dt2$matrix_size(
          number_of_rows    = nrow(<r_variable_name_in_scope>),
          number_of_columns = ncol(<r_variable_name_in_scope>)
        )
      ),
      has_output = dt2$data_item(
        label              = "<one-sentence description of the output>",
        source_table       = <r_variable_name_in_scope>,
        has_part           = list( dt2$component(label="<colA>"),
                                   dt2$component(label="<colB>") ),
        has_characteristic = dt2$matrix_size(
          number_of_rows    = nrow(<r_variable_name_in_scope>),
          number_of_columns = ncol(<r_variable_name_in_scope>)
        ),
        has_expression     = dt2$figure(
          source_url = check_resource_url("<plot-file>.png")
        )
      )
    )
  )

  # 3. Serialise + write via the editorial helper.
  json <- dtreg::to_jsonld(instance)
  write(json, check_name_mapping("<OUTPUT_FILENAME>", file_type = "json"))

Hard rules (read all before writing code):

R1. STYLE = constructor-arg. Every field is an argument to its parent
    constructor; do NOT use `inst$field <- value` after construction.
    Field-assignment produces structurally-shallower JSON-LD than gold.

R2. PARENT = data_analysis. The outermost call is ALWAYS
    `dt1$data_analysis(...)` with handle `feeb33ad3e4440682a4d`. The
    Stage-C-classified handle is the CHILD, placed in `has_part = dt2$<...>(...)`.

R3. SUB-HANDLE LOADING. Always call `load_datatype()` twice: once for
    the parent handle (constant) and once for the child handle.

R4. INPUT/OUTPUT IDIOM. Every `data_item` carries:
      - `source_table = <R variable in scope>` (NOT a string URL)
      - `has_part     = list( component(label=...), ... )` for columns
      - `has_characteristic = matrix_size(nrow(...), ncol(...))`
    Plot outputs additionally carry `has_expression = figure(...)`.

R5. SOFTWARE STACK. `executes` is always
    `software_method(label, is_implemented_by, part_of=software_library(
       label, version_info, part_of=software(label="R", version_info)))`.
    Fill `is_implemented_by` with the literal call from the evidence
    code slice.

R6. HELPERS. Use `check_resource_url("filename")` for any URL/file
    reference (snippet path, figure path). Use `check_name_mapping(
    "out.json", file_type="json")` in the final `write()` call. The
    sandbox stubs both as identity for execution; in production the
    TIB Knowledge Loom framework supplies the real implementations.

R7. R VARIABLE REFERENCES. The `source_table=<var>` slot references R
    objects produced upstream by the evidence code (e.g. `m_pca`,
    `comm_pca_plot`, `df`). Use the variable names that appear in the
    evidence code_slice; the sandbox auto-stubs them as mock
    data.frames when not in scope.

R8. OUTPUT FORMAT. Output ONLY R code, inside one fenced ```r``` block.
    The very last line MUST be the `write(json, check_name_mapping(
    "<OUTPUT_FILENAME>", file_type="json"))` call so the sandbox finds
    the emitted file.

DO NOT (regressions from older v1 prompt):
  - field-assignment after construction (`inst$has_input <- ...`)
  - top-level `<child_constructor>` without the `data_analysis` parent
  - `source_url = "string"` for tabular data (use `source_table = <var>`)
  - skipping `has_characteristic = matrix_size(...)`
  - skipping `has_part = list(component(...), ...)` on data_items
  - quoting helpers ("check_resource_url('x')" as a string)

Constructor name map (snake_case, used as `dt$<name>()`):
```

Appended to the system prompt: the constructor map, e.g.:
```
  feeb33ad3e4440682a4d -> ds$data_analysis()
  37182ecfb4474942e255 -> ds$data_preprocessing()
  5b66cb584b974b186f37 -> ds$descriptive_statistics()
  5e782e67e70d0b2a022a -> ds$algorithm_evaluation()
  c6b413ba96ba477b5dca -> ds$multilevel_analysis()
  3f64a93eef69d721518f -> ds$correlation_analysis()
  b9335ce2c99ed87735a6 -> ds$group_comparison()
  286991b26f02d58ee490 -> ds$regression_analysis()
  6e3e29ce3ba5a0b9abfe -> ds$class_prediction()
  c6e19df3b52ab8d855a9 -> ds$class_discovery()
  437807f8d1a81b5138a3 -> ds$factor_analysis()
```

Then `_build_few_shot_section(target_handle=handle)` appends a `## FEW-SHOT EXAMPLES` block. Each example renders as:
```
### Example {i} — {ex.label} ({ex.handle}){ " (handle-matched)" if matched else "" }
- CLAIM: {ex.claim}
- EVIDENCE: {ex.evidence}
- CLASSIFIED_TYPE: {ex.handle}
- GENERATED_CODE:
```r
{ex.dtreg_code}
```
```
Header text is one of:
- (handle-matched found) "The first example below uses the SAME handle as your target (handle-matched). Mirror its constructor names and field layout."
- (no handle match) "No handle-matched few-shot available for your target handle (`{target_handle}`). The example below shows the canonical SHAPE (parent + child + matrix_size + components + figure); substitute the child constructor name from the constructor map and adapt the labels/columns to your evidence code."
- (no few-shots configured) "(no few-shots configured; rely on rules above and the API skeleton)"

The currently-configured `DTREG_FEW_SHOTS` contains exactly one entry (Factor Analysis, handle `437807f8d1a81b5138a3`) — see source for the full embedded code example.

User message (`user_msg`, assembled by `"\n\n".join(user_parts)`):
```
## CLASSIFIED_TYPE

```json
{json.dumps(classified, indent=2)}
```

## CLAIM

```json
{json.dumps(claim, indent=2, ensure_ascii=False)}
```

## EVIDENCE_BUNDLE

```json
{json.dumps(evidence_bundle, indent=2, ensure_ascii=False)[:8000]}
```

## R_VARIABLES_IN_SCOPE                   # only if r_vars non-empty
These R variables are assigned by the evidence code and are available in the executing scope. Use them as the value of `source_table=<var>` (NOT as strings):
  `var1`, `var2`, ...

## SCRIPT_URL                             # only if script_url provided
{script_url}

## OUTPUT_FILENAME                        # only if output_filename provided
{output_filename}

## SNIPPET_FILENAME                       # only if snippet_filename provided
The evidence code snippet is written alongside the generated R file as `{snippet_filename}`. Use this exact name for the `is_implemented_by` field of the `data_analysis` parent:
  `is_implemented_by = check_resource_url("{snippet_filename}")`
Do NOT invent any other filename (no segment ids, no paths).

Sub-handle (CHILD) constructor: `dt2${expected_constructor}()` with handle `{handle}`.
Universal parent constructor: `dt1$data_analysis()` with handle `feeb33ad3e4440682a4d` (always).
Build the record as `dt1$data_analysis(is_implemented_by=..., has_part = dt2${expected_constructor}(...))` per system rule R2.
Load both schemas:
  dt1 <- load_datatype("https://doi.org/21.T11969/feeb33ad3e4440682a4d")
  dt2 <- load_datatype("https://doi.org/21.T11969/{handle}")
Generate the dtreg R code via report_dtreg_code.
```

## Notes
- `LLMClient.call_tool` with `stage="D"`, `max_tokens=4096`.
- Defensive markdown fence stripping is applied to `raw["code"]` post-tool-call (handles gpt-4o that sometimes wraps the code with ```r ... ```).
- Corresponds to manual prompt `repro_agent/prompts/stage_d/08_generate_dtreg_code.md`.

## Language selection (R vs Python)

The active prompt contains **two parallel skeletons** — a CANONICAL R
SKELETON and a CANONICAL PYTHON SKELETON. The system prompt instructs
the model to emit code in the language stated under
`## TARGET_LANGUAGE` in the user message.

`TARGET_LANGUAGE` is computed by `_detect_dtreg_target_language()` from
the evidence bundle:
- file-extension signals (`.py` / `.ipynb` → python; `.r` / `.rmd` → r)
- syntax signals (`import `, `def `, `np.`, `pd.`, `plt.` → python;
  `library(`, `<- `, `%>%`, `ggplot(` → r)

The hard rules (R1-R8) apply to both languages; rule R4 / R7 / R8 each
list the R-specific and Python-specific idioms side by side. The
constructor map at the bottom of the system prompt uses dotted-access
notation (`dt.<name>()`) which is valid in both languages once the LLM
chooses the per-language style (R uses `dt$<name>()` in practice).

The Stage D few-shot inventory (`DTREG_FEW_SHOTS`) currently contains
one R example (Factor Analysis). When the model targets Python, the
`_build_few_shot_section` fallback paragraph instructs it to mirror
the canonical Python SHAPE rather than the R syntax of the example.

## Sandbox auto-stub disclosure (rule R7)

The system prompt rule R7 now explicitly discloses the Stage D
sandbox auto-stub behaviour:

> SANDBOX BEHAVIOR (disclosed in audit): when a referenced variable
> is not defined in the executing scope, the sandbox auto-stubs it
> as a mock data.frame (R) or pandas DataFrame (Python). This means
> a generated script that references an undefined variable may
> still produce exit=0 — runtime validity therefore measures schema
> materialization, NOT scientific correctness of the upstream
> computation.

This disclosure is also documented in `docs/known_limitations.md`
§ "Stage D sandbox auto-stubs undefined variables" so reviewers see
the same caveat from both directions (prompt + limitation doc).

## Glossary cross-reference
- "handle" = "DTREG handle" = "analysis handle" — see `docs/glossary.md`
- "runtime validity" = schema materialization, not scientific
  correctness — see `docs/glossary.md` and `docs/known_limitations.md`.
