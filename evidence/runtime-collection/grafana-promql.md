# Grafana / Prometheus evidence queries

Set the time range to **16 Nov 2026, 09:25–13:00 Asia/Dubai** (or the actual replay window if you run at another time).

## API restart / impact
- API restarts: `changes(process_start_time_seconds{job="api"}[15m])`
- API availability: `up{job="api"}`
- API 5xx count: `sum(increase(invoicely_http_request_duration_seconds_count{code=~"5.."}[15m]))`
- API memory: `container_memory_working_set_bytes{container_label_com_docker_compose_service="api"}`
- Go heap: `go_memstats_heap_inuse_bytes{job="api"}`
- Go heap objects: `go_memstats_heap_objects{job="api"}`
- API goroutines: `go_goroutines{job="api"}`
- Request p95: `histogram_quantile(0.95, sum by (le, route) (rate(invoicely_http_request_duration_seconds_bucket{route!~"/metrics|/healthz"}[5m])))`

## Oasis upload latency
- Import duration p95: `histogram_quantile(0.95, sum by (le) (rate(invoicely_import_duration_seconds_bucket[5m])))`
- Participant lookup p95: `histogram_quantile(0.95, sum by (le) (rate(invoicely_participant_lookup_duration_seconds_bucket[5m])))`
- Participant lookup rate: `sum by (result) (rate(invoicely_participant_lookup_duration_seconds_count[1m]))`
- AE-BR-09 increases: `sum(increase(invoicely_validation_failures_total{rule="AE-BR-09"}[15m]))`

## Sahara throttling / outcomes
- ASP HTTP responses: `sum by (code) (increase(invoicely_asp_responses_total[5m]))`
- ASP document outcomes: `sum by (outcome) (increase(asp_documents_total[5m]))`
- API submissions: `sum by (outcome) (increase(invoicely_submissions_total[5m]))`
- Queue depth: `invoicely_submission_queue_depth`

Dashboard panels in `observability/grafana/dashboards/invoicely-overview.json` include `API process restarts (1h)`, `5xx responses (15m)`, `Import processing time p50 / p95`, `Participant lookups`, `ASP responses by HTTP status`, `ASP: documents by outcome (ASP side)`, `Container memory (working set)` and `API Go heap in use`.
