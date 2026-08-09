from fastapi import APIRouter
from pathlib import Path
import json
import os

router = APIRouter(prefix="/connectors/github", tags=["GitHub Connector"])
MOCK_MODE = os.getenv("MOCK_MODE", "true").lower() == "true"
MOCK_DATA_PATH = Path(__file__).parent / "mock_data" / "github_data.json"

def load_mock_data():
    with open(MOCK_DATA_PATH) as f:
        return json.load(f)

@router.get("/status")
def github_status():
    return {
        "connector": "GitHub",
        "mode": "mock" if MOCK_MODE else "live",
        "status": "connected",
        "org": "mivan-health",
        "repos_available": 4
    }

@router.get("/repos")
def get_repos():
    data = load_mock_data()
    return {"repos": data["repos"], "total": len(data["repos"])}

@router.get("/pull-requests")
def get_pull_requests(status: str = None, repo: str = None):
    data = load_mock_data()
    prs = data["pull_requests"]
    if status:
        prs = [pr for pr in prs if pr["status"] == status]
    if repo:
        prs = [pr for pr in prs if pr["repo"] == repo]
    return {"pull_requests": prs, "total": len(prs)}

@router.get("/pull-requests/{pr_id}")
def get_pull_request(pr_id: str):
    data = load_mock_data()
    for pr in data["pull_requests"]:
        if pr["id"] == pr_id:
            return pr
    return {"error": "PR not found"}

@router.get("/commits")
def get_recent_commits(repo: str = None):
    data = load_mock_data()
    commits = data["recent_commits"]
    if repo:
        commits = [c for c in commits if c["repo"] == repo]
    return {"commits": commits, "total": len(commits)}

@router.get("/issues")
def get_open_issues(priority: str = None, label: str = None):
    data = load_mock_data()
    issues = data["open_issues"]
    if priority:
        issues = [i for i in issues if i["priority"] == priority]
    if label:
        issues = [i for i in issues
                  if label in i.get("labels", [])]
    return {"issues": issues, "total": len(issues)}

@router.get("/summary")
def get_github_summary():
    data = load_mock_data()
    return {
        "total_repos": len(data["repos"]),
        "open_prs": len(data["pull_requests"]),
        "awaiting_review": len([p for p in data["pull_requests"]
                                 if p["status"] == "awaiting_review"]),
        "ghost_node_issues": len([i for i in data["open_issues"]
                                   if "ghost-node" in i.get("labels", [])]),
        "recent_commits_24h": len(data["recent_commits"])
    }
