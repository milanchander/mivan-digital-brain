# AWS Access Request — Mivan Digital Brain Chat

**Requested by:** Milan Chander (milan.chander@accenture.com)
**Purpose:** Host the Mivan Digital Brain chat backend so the portal's "Ask the
Digital Brain" feature works off a shared/hosted page (not just a local laptop).
The backend calls **Amazon Bedrock (Anthropic Claude)** for answers — no
personal API key or personal login is used.

There are **two tiers** below. **Tier 1 is enough to get the chat working** and
is a small, low-risk grant. **Tier 2** is the durable, always-on production
deployment. Please grant Tier 1 first if the full deploy needs more review.

---

## Tier 1 — Minimal (get the chat working)

Goal: let the backend authenticate to Bedrock and invoke Claude. The backend can
run locally or on a small server; only Bedrock access is required.

**1. Developer sign-in to the Mivan AWS account**
- Access via **IAM Identity Center (SSO)** preferred, so I can run
  `aws configure sso` on my machine. (Access keys are an acceptable fallback.)
- Region: please confirm the standard Mivan region (assume **us-east-1** unless
  told otherwise).

**2. Enable Amazon Bedrock model access (account-level, admin action)**
- In the AWS console: **Bedrock → Model access → enable the Anthropic Claude
  models** (Claude Sonnet at minimum; Claude Opus optional).
- Note: enabling Anthropic models on Bedrock may require submitting a short
  use-case description — this is a claims-domain internal knowledge assistant.

**3. IAM permission for my identity/role — Bedrock invoke only**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "BedrockInvokeClaude",
      "Effect": "Allow",
      "Action": [
        "bedrock:InvokeModel",
        "bedrock:InvokeModelWithResponseStream"
      ],
      "Resource": [
        "arn:aws:bedrock:*::foundation-model/anthropic.claude-*",
        "arn:aws:bedrock:*:*:inference-profile/us.anthropic.claude-*"
      ]
    },
    {
      "Sid": "BedrockListModels",
      "Effect": "Allow",
      "Action": ["bedrock:ListFoundationModels", "bedrock:GetFoundationModel"],
      "Resource": "*"
    }
  ]
}
```

With Tier 1 alone, the chat works (backend runs locally/tunneled, calling Bedrock).

---

## Tier 2 — Durable hosting (always-on, no laptop dependency)

Goal: run the backend 24/7 in AWS behind HTTPS so the GitHub Pages / hosted
portal can reach it at a stable `wss://` URL.

**Target architecture:** container image in **ECR** → **ECS Fargate** service →
**Application Load Balancer** (HTTPS/WSS via **ACM** cert) → calls **Bedrock**.
Config/secrets in **Secrets Manager**, logs in **CloudWatch**.

**Permissions needed to build/deploy** (my identity or a CI role):
- **ECR:** create repository, push/pull images
- **ECS:** create cluster, task definitions, service; update service
- **ELB (ALB):** create load balancer, target groups, listeners
- **EC2/VPC:** use existing VPC/subnets + create/attach security groups
- **ACM:** request or use an existing TLS certificate for the chosen domain
- **IAM:** `iam:PassRole` for the two task roles below (or have the cloud team
  create them and share the ARNs)
- **CloudWatch Logs:** create log groups / put log events
- **Secrets Manager:** read the backend's secret

**Two roles the cloud team may prefer to create:**

1. **Task execution role** — pull image + read secrets + write logs
   (`AmazonECSTaskExecutionRolePolicy` + Secrets Manager read).
2. **Task role** (what the running app uses) — the **Bedrock invoke** policy from
   Tier 1 above (this is all the app itself needs at runtime).

**Also needed:**
- A **DNS name** for the backend (e.g. `digital-brain-api.<mivan-domain>`) and a
  matching **ACM certificate**, so the browser can use `wss://`.

---

## What I will provide

- Dockerfile + container for the backend (`backend/app.py`), Bedrock-enabled.
- ECS task definition + deploy steps (or Terraform/CloudFormation if preferred).
- Frontend change so `index.html` points at the hosted backend URL.

## Open questions for the AWS/cloud team

1. Standard **region**?
2. Is **Bedrock** already enabled in this account, and are Anthropic models
   approved? If not, who approves the use case?
3. Preferred **IaC** (Terraform / CloudFormation / CDK) and any tagging/naming
   standards?
4. Existing **VPC/subnets** and a domain + ACM cert we should use?
5. Any **access-control** requirement for the endpoint (SSO, token, IP allow-list)
   given this serves claims-domain knowledge?
