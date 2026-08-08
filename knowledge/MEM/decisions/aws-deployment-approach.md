---
layer: MEM
node_type: decision
topic: Backend deployment approach for Digital Brain portal
date: 2026-08-08
captured_by: Milan Chander
status: draft
related_nodes:
  - backend/app.py
  - docs/aws-access-request.md
ghost_node_id: null
graduation_target: knowledge/L1-enterprise/mivan-enterprise-context.md (cloud footprint section)
---

# Decision — AWS Deployment Approach for Digital Brain Backend

## Context
The Digital Brain portal chat backend (FastAPI 
WebSocket server) currently runs locally on 
the developer's laptop. For team sharing and 
demo purposes it needs a permanent public URL.
AWS access request has been filed.

## Content
**Proposed deployment approach:**

Option A (preferred): AWS ECS Fargate
- Containerize the FastAPI backend
- Deploy to ECS Fargate in Mivan-Dev AWS account
- API key / Bedrock credentials via AWS Secrets Manager
- Frontend on S3 + CloudFront
- WebSocket URL becomes wss://[cloudfront-domain]/ws/chat

Option B: AWS Lambda + API Gateway
- Package FastAPI as Lambda function
- WebSocket support via API Gateway WebSocket API
- More complex for streaming responses
- Lower cost at low traffic

Option C: EC2
- Simple but requires instance management
- Not recommended for this use case

**Recommendation: Option A — ECS Fargate**

## Open Questions
- AWS access not yet confirmed — pending approval
- Bedrock vs direct Anthropic API — to be decided 
  once access lands
- CORS origin — needs to be tightened to 
  CloudFront domain once known

## Action Required
- Await AWS access confirmation
- Choose Bedrock vs API key auth
- Add boto3 to requirements.txt
- Add Bedrock toggle to app.py (line 72)
- Update BACKEND_WS_URL in index.html to AWS endpoint

## Graduation Checklist
- [ ] AWS access confirmed
- [ ] Deployment approach finalized
- [ ] Bedrock auth implemented
- [ ] Frontend URL updated
- [ ] Graduate to L1 cloud footprint section
