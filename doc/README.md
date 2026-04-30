# HCM360 HRIS — Documentation

**Version 1.0.0** · April 2026

All documents are published in both `.docx` (Microsoft Word) and `.pdf` formats.

---

## Technical Documentation

For developers, system administrators, and operations engineers.

| # | Document | Description |
|---|---|---|
| 01 | [Architecture Overview](technical/01_architecture_overview.pdf) | How the frontend, backend, database, and integrations fit together |
| 02 | [Data Structure](technical/02_data_structure.pdf) | Schemas, tables, relationships, and data flow |
| 03 | [APIs and Logic](technical/03_apis_and_logic.pdf) | Request routing, business rules, service layer, AJAX endpoints |
| 04 | [Deployment Setup](technical/04_deployment_setup.pdf) | Docker Compose, environment variables, backups, troubleshooting |
| 05 | [Access and Security](technical/05_access_and_security.pdf) | Roles, access matrix, privacy rules, audit logs, compliance |

## LGU Gap Analysis

Each LGU engagement has its own sub-folder with a `generate.py` source of truth.
Edit the data lists in the script, re-run, and the dated Excel snapshot is rebuilt
with all sheets in sync. See [`lgu/README.md`](lgu/README.md) for update instructions.

| Client | Folder | Latest Snapshot | Generator |
|---|---|---|---|
| Municipality of Mariveles (Bataan) HRMO | [lgu/](lgu/) | [LGU_Mariveles_Gap_Analysis_AsOf_2026-04-22.xlsx](lgu/LGU_Mariveles_Gap_Analysis_AsOf_2026-04-22.xlsx) | [lgu/generate.py](lgu/generate.py) |

Each workbook has 6 sheets: Summary, Full Matrix, Gap Backlog, Partial Refinements, Module Coverage (pivot), and a 4-phase Deployment Roadmap. Prior snapshots are auto-archived on regeneration.

## User Documentation

For end users, managers, and HR administrators.

| # | Document | Description |
|---|---|---|
| 06 | [User Guide](user/06_user_guide.pdf) | Step-by-step walkthroughs for everyday tasks |
| 07 | [Process Flows](user/07_process_flows.pdf) | How transactions move through the system (lifecycle diagrams) |
| 08 | [Feature Overview](user/08_feature_overview.pdf) | What each of the 16 modules does and who it serves |
| 09 | [Admin Guide](user/09_admin_guide.pdf) | Configuring HCM360 as a system administrator |
| 10 | [KPI Explanation](user/10_kpi_explanation.pdf) | What every dashboard metric means and how it is computed |

---

## Folder Structure

```
doc/
├── README.md                   (this file)
├── technical/                  (5 .docx + 5 .pdf)
│   ├── 01_architecture_overview.docx / .pdf
│   ├── 02_data_structure.docx / .pdf
│   ├── 03_apis_and_logic.docx / .pdf
│   ├── 04_deployment_setup.docx / .pdf
│   └── 05_access_and_security.docx / .pdf
├── user/                       (5 .docx + 5 .pdf)
│   ├── 06_user_guide.docx / .pdf
│   ├── 07_process_flows.docx / .pdf
│   ├── 08_feature_overview.docx / .pdf
│   ├── 09_admin_guide.docx / .pdf
│   └── 10_kpi_explanation.docx / .pdf
└── _build/                     (source)
    ├── generator.py            (docx + pdf renderer)
    └── content/                (10 content modules)
```

## Regenerating

```bash
cd doc/_build
python3 generator.py
```

Requires: `python-docx` and `reportlab` (`pip install python-docx reportlab`).

The generator reads each content module in `_build/content/`, and produces both
`.docx` and `.pdf` from the shared block model. Edit the content modules to
update text; the renderer handles consistent styling across both formats.
