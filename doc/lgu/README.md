# LGU Gap Analysis — Source of Truth

This folder holds the **canonical LGU gap analysis** for Municipality of Mariveles (Bataan) HRMO requirements against HCM360 HRIS v1.0. The Excel workbook is always regenerated from a single Python file so every update stays consistent.

---

## Files in this folder

| File | Purpose |
|---|---|
| **`generate.py`** | Source of truth — edit this to update the analysis |
| `LGU_Mariveles_Gap_Analysis_AsOf_<YYYY-MM-DD>.xlsx` | Most-recent dated snapshot |
| `archive/` | Prior dated snapshots (auto-moved on regeneration) |
| `README.md` | This file |

---

## How to update the analysis

1. **Open `generate.py` in any editor.**
2. **Edit one of three data lists** near the top of the file:
   - `MATRIX` — the full requirement list (tuples of `section, requirement, status, module, page, notes, priority`)
   - `GAP_BACKLOG` — only GAP items with estimates
   - `PARTIAL_BACKLOG` — refinement tasks for PARTIAL items
3. **Re-run the generator:**
   ```bash
   cd /Users/capsanchez/Downloads/hcm360
   python3 doc/lgu/generate.py
   ```
4. **A new file** named `LGU_Mariveles_Gap_Analysis_AsOf_<today>.xlsx` appears here.
5. **Any prior snapshots** are automatically moved into `archive/`.

That's it. All six sheets (Summary, Full Matrix, Gap Backlog, Partial Refinements, Module Coverage, Roadmap) rebuild from the same data — formulas, coverage counts, and module pivots stay in sync automatically.

---

## Status values (only these three)

| Value | Meaning |
|---|---|
| `COVERED` | Fully implemented in HCM360 v1.0 |
| `PARTIAL` | Exists but needs LGU-specific tuning or templates |
| `GAP` | Net new development required |

Status cells are auto-colored (green / amber / red) in the Excel output.

---

## Typical edit patterns

### Marking a GAP as done
1. In `MATRIX`, change the requirement's status from `'GAP'` to `'COVERED'` and update the Gap/Notes column.
2. Remove the corresponding `'G##'` row from `GAP_BACKLOG`.
3. Re-run.

### Promoting a PARTIAL to COVERED
1. In `MATRIX`, change status to `'COVERED'`; update notes.
2. Remove the matching `'P##'` row from `PARTIAL_BACKLOG`.
3. Re-run.

### Adding a new LGU requirement
1. Append a new tuple to `MATRIX` (section, requirement, status, module, page, notes, priority).
2. If status is `GAP`, also add a row to `GAP_BACKLOG` with ID, effort, estimate.
3. Re-run.

---

## Requirements

- Python 3.8+
- `openpyxl` (`pip install openpyxl` if missing)

---

## Sheet reference

| # | Sheet | Contents |
|---|---|---|
| 1 | Summary | Cover + coverage stats with live `COUNTIF` formulas + critical gap callouts |
| 2 | Full Matrix | Every requirement with status, module, page, notes, priority (with autofilter) |
| 3 | Gap Backlog | Only `GAP` items — build list with effort and timeline |
| 4 | Partial Refinements | Only `PARTIAL` items — configuration and small-build list |
| 5 | Module Coverage | Pivot by module: `COUNTIFS` of COVERED / PARTIAL / GAP with coverage % |
| 6 | Roadmap | 4-phase 20-week deployment plan, color-coded by phase |

All sheets are styled with Arial, zebra striping on headers, color-coded statuses, frozen header rows, and auto-filter where applicable.
