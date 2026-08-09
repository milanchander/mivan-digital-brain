from fastapi import APIRouter
from pathlib import Path
import json
import os

router = APIRouter(prefix="/connectors/servicenow",
                   tags=["ServiceNow Connector"])
MOCK_MODE = os.getenv("MOCK_MODE", "true").lower() == "true"
MOCK_DATA_PATH = Path(__file__).parent / "mock_data" / "servicenow_data.json"

def load_mock_data():
    with open(MOCK_DATA_PATH) as f:
        return json.load(f)

@router.get("/status")
def servicenow_status():
    return {
        "connector": "ServiceNow",
        "mode": "mock" if MOCK_MODE else "live",
        "status": "connected",
        "instance": "mivan.service-now.com",
        "open_incidents": 4
    }

@router.get("/incidents")
def get_incidents(priority: str = None,
                  status: str = None,
                  component: str = None):
    data = load_mock_data()
    incidents = data["incidents"]
    if priority:
        incidents = [i for i in incidents
                     if i["priority"] == priority]
    if status:
        incidents = [i for i in incidents
                     if i["status"] == status]
    if component:
        incidents = [i for i in incidents
                     if component.lower() in
                     i["affected_component"].lower()]
    return {"incidents": incidents, "total": len(incidents)}

@router.get("/incidents/{incident_id}")
def get_incident(incident_id: str):
    data = load_mock_data()
    for inc in data["incidents"]:
        if inc["number"] == incident_id:
            return inc
    return {"error": "Incident not found"}

@router.get("/incidents/component/{component}")
def get_incidents_by_component(component: str):
    data = load_mock_data()
    incidents = [i for i in data["incidents"]
                 if component.upper() in
                 i["affected_component"].upper()]
    return {"incidents": incidents,
            "total": len(incidents),
            "component": component}

@router.get("/change-requests")
def get_change_requests(status: str = None):
    data = load_mock_data()
    changes = data["change_requests"]
    if status:
        changes = [c for c in changes if c["status"] == status]
    return {"change_requests": changes, "total": len(changes)}

@router.get("/problems")
def get_problem_records():
    data = load_mock_data()
    return {"problems": data["problem_records"],
            "total": len(data["problem_records"])}

@router.get("/knowledge-gaps")
def get_knowledge_gaps():
    data = load_mock_data()
    gaps = []
    for inc in data["incidents"]:
        if not inc.get("knowledge_extracted") and \
           inc.get("related_ghost_node"):
            gaps.append({
                "incident": inc["number"],
                "title": inc["title"],
                "ghost_node": inc["related_ghost_node"],
                "programs": inc["programs_involved"],
                "knowledge_extracted": False
            })
    return {"gaps": gaps,
            "total": len(gaps),
            "message": "These incidents contain knowledge not yet extracted to the Digital Brain"}

@router.get("/summary")
def get_servicenow_summary():
    data = load_mock_data()
    incidents = data["incidents"]
    return {
        "total_incidents": len(incidents),
        "p1_incidents": len([i for i in incidents
                              if i["priority"] == "P1"]),
        "p2_incidents": len([i for i in incidents
                              if i["priority"] == "P2"]),
        "knowledge_not_extracted": len([i for i in incidents
                                        if not i.get("knowledge_extracted")]),
        "open_problems": len(data["problem_records"]),
        "scheduled_changes": len([c for c in data["change_requests"]
                                   if c["status"] == "scheduled"])
    }
