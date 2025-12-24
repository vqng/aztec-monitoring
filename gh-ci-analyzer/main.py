"""
GitHub CI Analyzer - Fetches merge queue workflow data from GitHub Actions API.

This demonstrates that the required data is accessible programmatically.
"""

import os
from datetime import datetime
from pprint import pprint

import requests

# Configuration
OWNER = "AztecProtocol"
REPO = "aztec-packages"
WORKFLOW_FILE = "ci3.yml"
GITHUB_API = "https://api.github.com"


def get_headers():
    """Get headers for GitHub API requests."""
    headers = {"Accept": "application/vnd.github+json"}
    token = os.environ.get("GITHUB_TOKEN")
    if token:
        headers["Authorization"] = f"Bearer {token}"
    return headers


def get_merge_queue_runs(per_page: int = 30, page: int = 1) -> dict:
    """
    Fetch workflow runs triggered by merge_group events.

    GitHub API: GET /repos/{owner}/{repo}/actions/workflows/{workflow_id}/runs
    Docs: https://docs.github.com/en/rest/actions/workflow-runs#list-workflow-runs-for-a-workflow
    """
    url = f"{GITHUB_API}/repos/{OWNER}/{REPO}/actions/workflows/{WORKFLOW_FILE}/runs"
    params = {
        "event": "merge_group",
        "per_page": per_page,
        "page": page,
    }

    response = requests.get(url, headers=get_headers(), params=params)
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
    all_runs = []
    page = 1
    per_page = min(100, max_runs)  # GitHub max is 100 per page

    while len(all_runs) < max_runs:
        data = get_merge_queue_runs(per_page=per_page, page=page)
        runs = data.get("workflow_runs", [])

        if not runs:
            break

        all_runs.extend(runs)
        page += 1

        # Check if we've fetched all available runs
        if len(runs) < per_page:
            break

    return all_runs[:max_runs]


def calculate_stats(parsed_runs: list[dict]) -> dict:
    """Calculate basic statistics from parsed runs."""
    if not parsed_runs:
        return {}

    # Filter completed runs
    completed = [r for r in parsed_runs if r["status"] == "completed"]

    # Failure rate
    failures = [r for r in completed if r["conclusion"] == "failure"]
    failure_rate = len(failures) / len(completed) if completed else 0

    # Duration stats (only for completed runs)
    durations = sorted([r["duration_minutes"] for r in completed])

    def percentile(data: list, p: int) -> float:
        if not data:
            return 0
        idx = int(len(data) * p / 100)
        return data[min(idx, len(data) - 1)]

    return {
        "total_runs": len(parsed_runs),
        "completed_runs": len(completed),
        "failures": len(failures),
        "failure_rate": f"{failure_rate:.1%}",
        "duration_p50_minutes": round(percentile(durations, 50), 1),
        "duration_p95_minutes": round(percentile(durations, 95), 1),
        "duration_max_minutes": round(max(durations) if durations else 0, 1),
    }


def main():
    print("Fetching merge queue workflow runs from GitHub...")
    print(f"Repo: {OWNER}/{REPO}")
    print(f"Workflow: {WORKFLOW_FILE}")
    print(f"Event filter: merge_group")
    print("-" * 60)

    # Check for token
    if not os.environ.get("GITHUB_TOKEN"):
        print("Note: No GITHUB_TOKEN set. Rate limits will be stricter.")
        print("Set GITHUB_TOKEN env var for higher rate limits.\n")

    # Fetch a sample of runs
    raw_runs = fetch_all_runs(max_runs=50)
    print(f"\nFetched {len(raw_runs)} workflow runs\n")

    if not raw_runs:
        print("No merge queue runs found!")
        return

    # Parse the data
    parsed_runs = [parse_run_data(run) for run in raw_runs]

    # Show sample of recent runs
    print("Recent merge queue runs:")
    print("-" * 60)
    for run in parsed_runs[:5]:
        print(f"  #{run['run_number']} | {run['conclusion']:10} | "
              f"{run['duration_minutes']:.1f} min | {run['created_at'].date()}")

    # Calculate and display stats
    print("\n" + "=" * 60)
    print("STATISTICS (from fetched sample)")
    print("=" * 60)
    stats = calculate_stats(parsed_runs)
    for key, value in stats.items():
        print(f"  {key}: {value}")

    # Show raw API response structure for one run
    print("\n" + "=" * 60)
    print("SAMPLE RAW RUN DATA (key fields)")
    print("=" * 60)
    sample = raw_runs[0]
    relevant_fields = {
        "id": sample["id"],
        "run_number": sample["run_number"],
        "status": sample["status"],
        "conclusion": sample["conclusion"],
        "event": sample["event"],
        "created_at": sample["created_at"],
        "updated_at": sample["updated_at"],
        "html_url": sample["html_url"],
    }
    pprint(relevant_fields)


if __name__ == "__main__":
    main()
