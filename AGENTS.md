# Project Working Rules

## Conversation Style

- Work in manageable blocks within one conversation.
- Do not provide too much content at once.
- Prefer short, practical checklists and step-by-step guidance.
- Before moving to the next large block of work, summarise what changed and what the next step is.
- Treat `CHECKLIST.md` as the authoritative execution tracker and complete its review gates before advancing phases.

## Editing Boundaries

- Only edit documentation files unless the user explicitly asks for code or script changes.
- Do not edit scripts, notebooks, SQL, infrastructure files, or generated artefacts by default.
- When a script, notebook, SQL statement, or command is needed, provide it in the conversation for the user to paste and run manually.
- Do not create Azure resources, run deployment commands, or change cloud state unless explicitly asked.
- Keep `PROJECT_PLAN.md`, `CHECKLIST.md`, and implemented artefacts aligned when an approved design decision changes.

## Engineering Practice

- Build the project as a controlled clinical costing workflow, not as a generic data-engineering platform.
- Before writing SQL, confirm table definitions from existing SQL scripts in `sql` folder.
- Before writing SQL, confirm the source grain, keys, mappings, allocation rules, and expected control totals.
- Keep patient-cost allocation logic in SQL Server. Excel should consume controlled reporting views and must not implement a competing costing model.
- Preserve traceability from general-ledger transaction to cost pool, allocation driver, patient-level result, and management total.
- Treat data quality and reconciliation as core controls; never silently discard or spread unresolved costs.
- Keep SQL scripts clear, ordered, reproducible, and safe to rerun where practical.
- Validate Excel totals against SQL and financial control totals.
- Use only synthetic data, avoid credentials and sensitive information, and label simulated stakeholder activities honestly.
- Interpret cost alongside clinical context, safety, quality, and patient experience; do not equate lower cost with better care or high cost with inefficiency.
- Keep implementation detail in `PROJECT_PLAN.md`, `CHECKLIST.md`, SQL comments, and project documentation. Keep this file limited to durable working rules.
