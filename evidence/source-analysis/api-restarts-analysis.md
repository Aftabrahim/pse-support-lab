# Incident 2 — API restarts: evidence-based leading hypothesis, runtime confirmation required

## Confirmed from source/configuration
- Grafana alert in the inbox reports three API container restarts in 15 minutes and severity `critical`.
- `docker-compose.yml:43-63` caps the API container at 128 MB (`mem_limit: 128m`, `memswap_limit: 128m`) and restarts it automatically.
- `services/api/internal/importer/sources.go:11-35` defines a source-cache entry containing the raw uploaded bytes, an `*excelize.File` workbook and parsed invoice objects. `SourceCache.Put` adds each import to a map; there is no TTL, size limit, eviction or delete method.
- `services/api/internal/importer/importer.go:87-96` inserts every import's invoices and permanently adds its source to this in-memory cache.
- `tools/cmd/loadgen/main.go:172-220` defines a peak test of 240 uploads with 8 concurrent workers; `make load` invokes this peak workload after replaying customer uploads.

## Leading hypothesis
The unbounded retention of raw workbooks + parsed workbook objects + invoice objects, combined with a 128 MB hard memory limit and a 240-upload peak replay, creates a credible OOM/restart mechanism. It also fits intermittent 502s when the API process is unavailable during restart.

**This is a source/configuration-supported hypothesis, not a confirmed OOM finding.** The alert itself only proves restarts. It does not show why the process exited.

## Runtime checks required
- `docker inspect "$(docker compose ps -q api)" --format '{{.RestartCount}} {{.State.OOMKilled}} {{.State.ExitCode}} {{.State.Error}}'`
- `docker compose logs --since "2026-11-16T09:25:00" api`
- Grafana panels: `Container memory (working set)`, `API Go heap in use`, `API process restarts (1h)`, `5xx responses (15m)`, `API up`, `Import processing time p50/p95`.
- PromQL:
  - `go_memstats_heap_inuse_bytes{job="api"}`
  - `container_memory_working_set_bytes{container_label_com_docker_compose_service="api"}`
  - `changes(process_start_time_seconds{job="api"}[15m])`
  - `sum(increase(invoicely_http_request_duration_seconds_count{code=~"5.."}[15m]))`
- Check `docker inspect` OOMKilled and container exit code before calling this an OOM.

## Mitigation / prevention
Bound and expire source-cache entries, retain original workbook in object/file storage instead of process memory, avoid holding duplicate parsed structures, enforce upload size/concurrency limits, and load-test with the 240-upload peak scenario. If OOM is confirmed, temporarily increase memory only as a containment measure, not as the sole fix.
