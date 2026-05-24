# Stage C — analytical-unit type classifier (8-handle taxonomy)

## Status
Used (this is the baseline Stage C path through the pipeline)

## Stage
Stage C (classification)

## Source location
- Defined in: `src/repro_agent/stages/stage_c_classify.py` (`SYSTEM_PROMPT` built from `TAXONOMY`; `REPORT_TOOL`; function `classify_unit`)
- Called by:
  * `src/repro_agent/pipeline.py:run_stage_c` (`classify_unit(claim, evidence_code, client=client)`)
- Entry-point script: `scripts/run_pipeline.py`

## Purpose
Classifies one `(claim, evidence_code)` pair into one of the 8 DTREG handles (closed taxonomy).

### Why 8 handles, not 10?

The full DTREG ontology contains 10 analysis handles. Two of them —
**Class Prediction** (`6e3e29ce3ba5a0b9abfe`) and **Class Discovery**
(`c6e19df3b52ab8d855a9`) — have zero gold instances in the scope used
by this artifact. Including them would cost prompt budget and risk
spurious predictions, so Stage C's output is restricted to the 8
handles that appear in the gold standard.

The two reserved handles are listed in
`stage_d_dtreg._RESERVED_HANDLES` so a maintainer can re-enable them
by adding entries back to `HANDLE_TO_CONSTRUCTOR` and `TAXONOMY`.

## Inputs inserted into the prompt
- `claim`: dict `{claim_text, anchors}` (rendered as JSON in the user message).
- `evidence_code`: concatenated `code` strings from the Stage B evidence bundle's `code_slice` (rendered inside a fenced code block; the fence language tag matches the evidence code's language).

## Expected output format
Tool-use call to `report_classification` (validated as `ClassificationResult`):
```
{
  "predicted_handle": <one of 8 enum handles>,
  "predicted_label":  <corresponding label>,
  "confidence":       float 0..1,
  "rationale":        str,
  "secondary_candidate": {"handle": <enum>, "label": <enum>} | null,
  "decision_rule":    int 1..10
}
```

## Exact prompt template
System block (`SYSTEM_PROMPT` — assembled f-string in source):
```
You classify a research analytical unit into ONE of 8 DTREG analysis handles
(closed list, see source). The label space is closed.

Types (handle suffix → canonical label):
  37182ecfb4474942e255  Data Preprocessing
  5b66cb584b974b186f37  Descriptive Statistics
  5e782e67e70d0b2a022a  Algorithm Evaluation
  c6b413ba96ba477b5dca  Multilevel Analysis
  3f64a93eef69d721518f  Correlation Analysis
  b9335ce2c99ed87735a6  Group Comparison
  286991b26f02d58ee490  Regression Analysis
  437807f8d1a81b5138a3  Factor Analysis

Decision rules (apply in order; first match wins):
1. Random-effects formula (`(...|...)` in lmer/glmer/lme) → Multilevel Analysis.
2. Latent-variable `=~` in lavaan, or factanal/psych::fa, or PCA / SEM model
   producing latent-variable loadings as the unit output → Factor Analysis.
3. t.test, wilcox.test, aov/anova(lm), pairwiseTest, pairwise.t.test, kruskal.test,
   compact-letter display from pairwise tests without random effects →
   Group Comparison.
4. cor / cor.test / Hmisc::rcorr / psych::corr.test producing correlation
   coefficient/p-value as the unit output → Correlation Analysis.
5. lm() / glm() / MASS::glm.nb without random effects, output is coefficients
   table → Regression Analysis.
6. Supervised classification with held-out evaluation: predict() + accuracy/F1/AUC
   metric as the unit output → Algorithm Evaluation. (Note: pure predictions
   without an evaluation metric and pure unsupervised clustering / dimension
   reduction fall outside the active label space; in such cases pick the
   nearest handle with low confidence + secondary_candidate.)
7. group_by + summarise / aggregate / tapply / summary tables of mean/SE per
   category, no inferential test → Descriptive Statistics.
8. Pure pre-analysis (recode/factor/filter/select/mutate/pivot/join) producing a
   prepared dataset, not an analytical result → Data Preprocessing.
9. Multiple ops: pick the type at the EMIT artifact the claim references.
10. Ambiguous: confidence < 0.7 + secondary_candidate.

Output ONLY via the report_classification tool. predicted_label MUST exactly
match one of the 8 canonical labels above.
```

User message:
```
## CLAIM

```json
{json.dumps(claim, indent=2, ensure_ascii=False)}
```

## EVIDENCE_CODE

```{lang}
{evidence_code}
```

Classify via report_classification.
```
(See "Language tag" note below.)

## Notes
- `LLMClient.call_tool` with `stage="C"`, `max_tokens=1024`.
- The `TAXONOMY` constant is also imported by `stage_d_dtreg.HANDLE_TO_CONSTRUCTOR` (lock-stepped via assertion at import).
- The language tag of the fenced evidence-code block is derived from the evidence-code language metadata (R or Python).

## Glossary cross-reference
- "handle" = "DTREG handle" = "analysis handle" — see `docs/glossary.md`.
