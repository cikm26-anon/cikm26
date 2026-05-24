# Prompts

This folder contains **reviewer-facing audit copies** of the prompts used
by the pipeline reported in the paper.

## Authoritative source

For prompts that are tightly coupled to Pydantic schemas (Stage A, B, C, D),
**the Python constant inside `src/repro_agent/stages/*.py` is the runtime
authoritative source**, not the Markdown copies here. The Markdown copies
in this folder are byte-for-byte audit copies that may differ from the
Python constants only in surrounding commentary (not in prompt body).

The mapping between Markdown copies, Python constants, and runtime stage
tags is documented in `prompt_inventory.csv`.

## Files

| Prompt file | Stage | Output contract |
|---|---|---|
| `stage_a_left_claim_extractor.md` | A.LEFT | `report_claims` tool JSON |
| `stage_a_right_code_unit_miner.md` | A.RIGHT | `report_code_units` tool JSON |
| `stage_a_fuse_score_hungarian_judge.md` | A.FUSE | `report_fusion` tool JSON |
| `stage_a_judge_alignment.md` | A.JUDGE (eval) | judge-alignment JSON |
| `stage_b_evidence_slicer.md` | B | `report_evidence` tool JSON |
| `stage_c_claim_type_router.md` | C | `report_classification` tool JSON |
| `stage_d_record_generator.md` | D | `report_dtreg_code` tool JSON + DTREG code |
| `sef_execution_guided_refiner.md` | SEF | refined `selected_ranges` JSON |
| `ablations/stage_a_fuse_signals.md` | A.FUSE-signals (opt-in) | `report_fusion` (schema-additive) |
| `ablations/stage_c_rag_classifier.md` | C-RAG v3 | `report_classification` |
| `ablations/stage_c_rag_v4_ablation.md` | C-RAG v4 | `report_classification` |
| `ablations/stage_d_rag_render.md` | D-RAG | `report_dtreg_code` |

## SEF refinement variants

The `sef_execution_guided_refiner.md` file documents the three SEF
feedback shapes (SEF-Full, SEF-Minus, SEF-Retry). The variant-selection
logic lives in `scripts/run_sef_slice.py:render_for_prompt`. All three
variants share the same prompt skeleton and output schema; they differ
only in the body of the `## EXECUTION_FEEDBACK` block.

## Tool output schemas

The exact JSON-Schema enforced at runtime for each `report_*` tool lives
beside the Python constant in the corresponding `src/repro_agent/stages/*.py`
file (e.g., `EXTRACTION_TOOL`, `REPORT_TOOL`).
