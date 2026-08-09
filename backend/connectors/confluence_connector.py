from fastapi import APIRouter
from pathlib import Path
import json
import os

router = APIRouter(prefix="/connectors/confluence",
                   tags=["Confluence Connector"])
MOCK_MODE = os.getenv("MOCK_MODE", "true").lower() == "true"
MOCK_DATA_PATH = Path(__file__).parent / "mock_data" / "confluence_data.json"

def load_mock_data():
    with open(MOCK_DATA_PATH) as f:
        return json.load(f)

@router.get("/status")
def confluence_status():
    return {
        "connector": "Confluence",
        "mode": "mock" if MOCK_MODE else "live",
        "status": "connected",
        "instance": "mivan.atlassian.net/wiki",
        "spaces": 4,
        "total_pages": 226
    }

@router.get("/spaces")
def get_spaces():
    data = load_mock_data()
    return {"spaces": data["spaces"],
            "total": len(data["spaces"])}

@router.get("/pages")
def get_pages(space: str = None,
              needs_update: bool = None,
              staleness: str = None):
    data = load_mock_data()
    pages = data["pages"]
    if space:
        pages = [p for p in pages if p["space"] == space]
    if needs_update is not None:
        pages = [p for p in pages
                 if p["needs_update"] == needs_update]
    if staleness:
        pages = [p for p in pages
                 if p["staleness_flag"] == staleness.upper()]
    return {"pages": pages, "total": len(pages)}

@router.get("/pages/stale")
def get_stale_pages():
    data = load_mock_data()
    stale = [p for p in data["pages"]
             if p["staleness_flag"] in ["CRITICAL", "HIGH"]]
    stale.sort(key=lambda x: x["staleness_days"], reverse=True)
    return {"stale_pages": stale,
            "total": len(stale),
            "message": "Pages that may contain outdated knowledge in the Digital Brain"}

@router.get("/pages/{page_id}")
def get_page(page_id: str):
    data = load_mock_data()
    for page in data["pages"]:
        if page["id"] == page_id:
            return page
    return {"error": "Page not found"}

@router.get("/recently-updated")
def get_recently_updated():
    data = load_mock_data()
    return {"pages": data["recently_updated"],
            "total": len(data["recently_updated"])}

@router.get("/search")
def search_pages(query: str):
    data = load_mock_data()
    query_lower = query.lower()
    results = []
    for page in data["pages"]:
        if (query_lower in page["title"].lower() or
            query_lower in page["content_summary"].lower() or
            any(query_lower in tag for tag in page["tags"])):
            results.append(page)
    return {"results": results,
            "total": len(results),
            "query": query}

@router.get("/knowledge-gaps")
def get_knowledge_gaps():
    data = load_mock_data()
    gaps = [p for p in data["pages"]
            if p["needs_update"] and
            p.get("linked_ghost_node")]
    return {"gaps": gaps,
            "total": len(gaps),
            "message": "Stale Confluence pages linked to Digital Brain ghost nodes"}

@router.get("/summary")
def get_confluence_summary():
    data = load_mock_data()
    pages = data["pages"]
    return {
        "total_pages_indexed": len(pages),
        "stale_critical": len([p for p in pages
                                if p["staleness_flag"] == "CRITICAL"]),
        "stale_high": len([p for p in pages
                           if p["staleness_flag"] == "HIGH"]),
        "current": len([p for p in pages
                        if p["staleness_flag"] == "CURRENT"]),
        "linked_to_ghost_nodes": len([p for p in pages
                                      if p.get("linked_ghost_node")]),
        "needs_update": len([p for p in pages
                             if p["needs_update"]])
    }
