# Evidence index

This folder contains the investigation artefacts prepared for the five Invoicely Lite support cases.

## Source and workbook analysis

- [Consolidated case analysis](source-analysis/CASE_ANALYSIS.md)
- Case-specific notes and the Al Noor calculation CSV are maintained alongside the consolidated analysis where available.

## Runtime verification

- [SQL reconciliation queries](runtime-collection/queries.sql) — use against the supplied database after the stack is running.
- [Docker and Grafana/Prometheus checks](runtime-collection/grafana-promql.md) — commands and queries for confirming restart, memory, and service behaviour.

## Screenshots

- [Screenshot evidence note](screenshots/README.md) explains why no runtime screenshots are included.

## Important evidence boundary

The application stack was not executed during preparation. Therefore this folder does not claim live database results, Docker restart/OOM state, Grafana measurements, successful ASP message IDs, or customer emails sent. Source-level findings and workbook calculations are distinguished from runtime facts that still need confirmation. Do not present a suggested query or command as an executed result.
