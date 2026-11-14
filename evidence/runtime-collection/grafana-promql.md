# Runtime verification checklist

Runtime checks were not executed in the preparation environment. Run these against the actual stack and retain timestamped output.

## Docker

```bash
docker compose ps
docker compose logs --since=2h api
docker inspect <api-container> --format 'OOMKilled={{.State.OOMKilled}} ExitCode={{.State.ExitCode}} RestartCount={{.RestartCount}}'
docker stats --no-stream
```

## Prometheus / Grafana

Use the metric names exposed by the configured Prometheus scrape targets; adjust labels to match the environment.

```promql
rate(http_server_requests_total{status=~"5.."}[5m])
container_memory_working_set_bytes
rate(process_cpu_seconds_total[5m])
go_memstats_heap_alloc_bytes
go_memstats_heap_inuse_bytes
rate(go_gc_duration_seconds_count[5m])
```

Correlate API restarts with memory working set, Go heap, request volume, upload concurrency and 5xx rate. A memory limit or cache implementation alone does not prove an OOM event.

## Required evidence

- Container OOMKilled, exit code, restart count and timestamp.
- API logs around each restart.
- Memory working set and Go heap/GC metrics.
- Request volume, 5xx rate and upload concurrency.
- ASP receipt list/message IDs for the 40 BluePeak/Sahara documents.
- Import IDs and invoice status/ASP IDs for Oasis.
