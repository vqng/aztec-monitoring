#!/usr/bin/env python3
"""
Metric exporter that pushes metrics to VictoriaMetrics.
"""
import os
import time
from datetime import datetime
import sys
import requests
from prometheus_client import CollectorRegistry, Gauge, generate_latest

# Number of runs to backfill on startup
BACKFILL_COUNT = 10000

# Interval to poll for new runs, in seconds
POLL_INTERVAL = 300

WORKFLOW_STATUSES = [
    "completed",
    "cancelled",
    "failure",
    "success",
    "timed_out",
    "in_progress",
]

VICTORIAMETRICS_URL = os.getenv("VM_URL")

OWNER = "AztecProtocol"
REPO = "aztec-packages"
WORKFLOW_FILE = "ci3.yml"
GITHUB_API = "https://api.github.com"

if not VICTORIAMETRICS_URL:
    print("Error: VM_URL environment variable is not set", file=sys.stderr)
    sys.exit(1)


def push_metric_to_victoriametrics(
    timestamp: int,
    metric_name: str,
    metric_value: float,
    victoriametrics_url: str = VICTORIAMETRICS_URL,
    exemplar: dict[str, str] | None = None,
    labels: dict[str, str] | None = None,
):
    """
    Push a metric to VictoriaMetrics using the Prometheus remote write format.

    Args:
        metric_name: Name of the metric
        metric_value: Value of the metric
        victoriametrics_url: Base URL of VictoriaMetrics instance
        exemplar: Optional dictionary of exemplar labels (e.g., {"run_id": "12345", "span_id": "def456"})
                  These are attached as exemplars without creating new time series (low cardinality)
        timestamp: Optional timestamp in milliseconds since epoch. If None, uses current time.
        labels: Optional dictionary of labels to add to the metric.
    """
    # Create a registry and gauge metric WITHOUT labels to avoid high cardinality
    registry = CollectorRegistry()
    if not labels:
        labels = {}
    labelnames = list(labels.keys())
    gauge = Gauge(
        metric_name,
        f'Workflow runs metric: {metric_name}',
        labelnames=labelnames,
        registry=registry
    )
    gauge.labels(*[labels[labelname] for labelname in labelnames]).set(metric_value)
    # Generate Prometheus format metrics
    metrics_data = generate_latest(registry)

    # Parse metrics and add timestamps and exemplars to metric value lines
    lines = metrics_data.decode('utf-8').split('\n')
    annotated_lines = []
    for line in lines:
        # Skip comments and empty lines
        if line.startswith('#') or not line.strip():
            annotated_lines.append(line)
            continue

        # We need to add timestamp and optionally exemplars
        annotated_line = f"{line} {timestamp}"
        if exemplar:
            exemplar_str = ','.join([f'{k}="{v}"' for k, v in exemplar.items()])
            annotated_line = f"{annotated_line} # {exemplar_str}"
        annotated_lines.append(annotated_line)

    metrics_data_with_timestamp = '\n'.join(annotated_lines).encode('utf-8')
    print(f"Metrics data with timestamp: {metrics_data_with_timestamp.decode('utf-8')}")

    # Push to VictoriaMetrics
    push_url = f"{victoriametrics_url}/api/v1/import/prometheus"
    headers = {'Content-Type': 'application/openmetrics-text'}

    try:
        response = requests.post(push_url, data=metrics_data_with_timestamp, headers=headers, timeout=10)
        response.raise_for_status()
        print(f"Successfully pushed {metric_name}={metric_value} to VictoriaMetrics (timestamp: {timestamp})")
        return True
    except requests.exceptions.RequestException as e:
        print(f"Error pushing metric to VictoriaMetrics: {e}")
        return False


def get_github_headers():
    """Get headers for GitHub API requests."""
    headers = {"Accept": "application/vnd.github+json"}
    token = os.environ.get("GITHUB_TOKEN")
    if token:
        headers["Authorization"] = f"Bearer {token}"
    return headers


def get_merge_queue_runs_count_by_status(status: str = "completed") -> int:
    """Get the count of merge queue runs by status."""
    url = f"{GITHUB_API}/repos/{OWNER}/{REPO}/actions/workflows/{WORKFLOW_FILE}/runs"
    params = {
        "event": "merge_group",
        "status": status,
    }
    response = requests.get(url, headers=get_github_headers(), params=params)
    response.raise_for_status()
    return response.json()["total_count"]


def get_merge_queue_runs(per_page: int = 30, page: int = 1) -> dict:
    """
    Fetch workflow runs triggered by merge_group events.

    GitHub API: GET /repos/{owner}/{repo}/actions/workflows/{workflow_id}/runs
    Docs: https://docs.github.com/en/rest/actions/workflow-runs#list-workflow-runs-for-a-workflow
    """
    url = f"{GITHUB_API}/repos/{OWNER}/{REPO}/actions/workflows/{WORKFLOW_FILE}/runs"
    params = {
        "event": "merge_group",
        "status": "completed",
        "per_page": per_page,
        "page": page,
    }

    response = requests.get(url, headers=get_github_headers(), params=params)
    response.raise_for_status()
    return response.json()


def parse_run_data(run: dict) -> dict:
    """Extract relevant fields from a workflow run."""
    created_at = datetime.fromisoformat(run["created_at"].replace("Z", "+00:00"))
    updated_at = datetime.fromisoformat(run["updated_at"].replace("Z", "+00:00"))

    # Duration is from creation to completion
    duration_seconds = (updated_at - created_at).total_seconds()

    return {
        "id": run["id"],
        "run_number": run["run_number"],
        "status": run["status"],  # queued, in_progress, completed
        "conclusion": run["conclusion"],  # success, failure, cancelled, etc.
        "created_at": created_at,
        "updated_at": updated_at,
        "duration_seconds": duration_seconds,
        "duration_minutes": duration_seconds / 60,
        "html_url": run["html_url"],
        "head_branch": run["head_branch"],
        "head_sha": run["head_sha"][:8],
    }


def fetch_all_runs(max_runs: int = 100) -> list[dict]:
    """Fetch multiple pages of runs up to max_runs."""
    page = 1
    remaining_runs = max_runs
    per_page = min(100, max_runs)  # GitHub max is 100 per page

    while remaining_runs:
        data = get_merge_queue_runs(per_page=per_page, page=page)
        runs = data.get("workflow_runs", [])

        if not runs:
            break

        for run in runs:
            if remaining_runs <= 0:
                break
            yield parse_run_data(run)
            remaining_runs -= 1

        page += 1


def backfill_runs(count=BACKFILL_COUNT):
    for run in fetch_all_runs(max_runs=count):
        timestamp = int(run["created_at"].timestamp() * 1000)
        metric_value = run["duration_seconds"]
        run_id = str(run["id"])
        labels = {"workflow_file": WORKFLOW_FILE}
        exemplar = {"run_id": run_id}
        push_metric_to_victoriametrics(
            timestamp,
            "workflow_runs_duration_seconds",
            metric_value,
            labels=labels,
            exemplar=exemplar
        )


def push_metrics():
    """Poll for workflow runs and Push metrics to VictoriaMetrics."""
    processed_runs = set[str]()
    while True:
        now = int(time.time() * 1000)
        for status in WORKFLOW_STATUSES:
            count = get_merge_queue_runs_count_by_status(status=status)
            print(f"{status} runs: {count}")
            labels = {"status": status, "workflow_file": WORKFLOW_FILE}
            push_metric_to_victoriametrics(now, "workflow_runs_count", count, labels=labels)

        for run in fetch_all_runs(max_runs=100):
            timestamp = int(run["created_at"].timestamp() * 1000)
            metric_value = run["duration_seconds"]
            run_id = str(run["id"])

            if run_id in processed_runs:
                continue
            processed_runs.add(run_id)

            labels = {"workflow_file": WORKFLOW_FILE}
            exemplar = {"run_id": run_id}
            push_metric_to_victoriametrics(
                timestamp,
                "workflow_runs_duration_seconds",
                metric_value,
                labels=labels,
                exemplar=exemplar
            )

        time.sleep(POLL_INTERVAL)


def main():
    """Main function to push workflow metrics."""
    if "--backfill" in sys.argv:
        backfill_runs(count=BACKFILL_COUNT)
    push_metrics()


if __name__ == "__main__":
    main()
