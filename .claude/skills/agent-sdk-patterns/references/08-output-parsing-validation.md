# 08 — Output Parsing & Validation

## The Reliability Pipeline

AI output is unreliable by default. This pipeline makes it deterministic:

```
Token Generation    →    JSON Schema (output_format, strict: True)
                              ↓
Result Extraction   →    extract_list() / extract_dict()
                              ↓  ResultQuality enum
Validation          →    Pydantic validators
                              ↓  (valid, rejected) tuples
DB Persistence      →    store.create_*()
```

**Rule: "Prompts are guidance, code is law."** Never trust AI output directly. Always validate before persisting.

## Step 1: JSON Schema (Constrain at Token Level)

Use `output_format` with `strict: True` to constrain what the model can output:

```python
ITEMS_SCHEMA = {
    "type": "object",
    "properties": {
        "items": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "name": {"type": "string", "minLength": 1, "maxLength": 500},
                    "description": {"type": "string", "minLength": 1, "maxLength": 5000},
                    "priority": {
                        "type": "string",
                        "enum": ["critical", "high", "medium", "low"],
                    },
                    "tags": {
                        "type": "array",
                        "items": {"type": "string", "maxLength": 100},
                        "maxItems": 20,
                    },
                },
                "required": ["name", "description"],
            },
            "minItems": 1,
        },
    },
    "required": ["items"],
}

options = ClaudeAgentOptions(
    output_format={
        "type": "json_schema",
        "schema": ITEMS_SCHEMA,
        "strict": True,  # ALWAYS True — enforces at token generation
    },
    ...
)
```

**Why `strict: True` matters**: Without it, the schema is advisory — the model might output valid JSON that doesn't match the schema. With `strict: True`, token generation is constrained so the model physically cannot produce non-conforming output.

## Step 2: Result Extraction (Handle All Edge Cases)

```python
import json
import logging
from dataclasses import dataclass
from enum import Enum
from typing import Optional

log = logging.getLogger(__name__)


class ResultQuality(Enum):
    """Quality level of extracted result."""
    STRUCTURED = "structured"      # SDK schema enforcement worked
    PARSED = "parsed"              # json.loads fallback succeeded
    EMPTY = "empty"                # Valid structure but 0 items
    PARSE_FAILED = "parse_failed"  # Could not extract at all


@dataclass
class ExtractionResult:
    """Explicit contract for AI output extraction — no silent failures."""
    data: list[dict]
    quality: ResultQuality
    error: Optional[str] = None

    @property
    def is_usable(self) -> bool:
        return (
            self.quality in {ResultQuality.STRUCTURED, ResultQuality.PARSED}
            and len(self.data) > 0
        )


def extract_list(message, list_key: str, label: str = "output") -> ExtractionResult:
    """Extract a list from a ResultMessage with explicit quality tracking.

    Args:
        message: The ResultMessage from the SDK.
        list_key: The JSON key to extract (e.g., "items", "results").
        label: Human-readable label for log messages.

    Returns:
        ExtractionResult with quality level, data, and optional error.
    """
    # Priority 1: SDK structured output (schema-enforced at token level)
    structured = getattr(message, "structured_output", None)
    if structured and isinstance(structured, dict):
        items = structured.get(list_key, [])
        if items:
            log.info(f"[{label}] Structured output: {len(items)} items")
            return ExtractionResult(data=items, quality=ResultQuality.STRUCTURED)
        log.warning(f"[{label}] Structured output present but '{list_key}' is empty")
        return ExtractionResult(data=[], quality=ResultQuality.EMPTY)

    # Priority 2: Parse result text as JSON fallback
    result_text = getattr(message, "result", "") or ""
    if not result_text:
        return ExtractionResult(
            data=[], quality=ResultQuality.PARSE_FAILED,
            error="No output received from AI",
        )

    try:
        parsed = json.loads(result_text)
        items = parsed.get(list_key, [])
        if items:
            log.info(f"[{label}] Parsed fallback: {len(items)} items")
            return ExtractionResult(data=items, quality=ResultQuality.PARSED)
        return ExtractionResult(data=[], quality=ResultQuality.EMPTY)
    except json.JSONDecodeError as e:
        return ExtractionResult(
            data=[], quality=ResultQuality.PARSE_FAILED,
            error=f"Failed to parse AI output as JSON: {e}",
        )


def extract_dict(message, label: str = "output") -> ExtractionResult:
    """Extract a dict from a ResultMessage (for single-object output)."""
    structured = getattr(message, "structured_output", None)
    if structured and isinstance(structured, dict):
        return ExtractionResult(data=[structured], quality=ResultQuality.STRUCTURED)

    result_text = getattr(message, "result", "") or ""
    if not result_text:
        return ExtractionResult(
            data=[], quality=ResultQuality.PARSE_FAILED,
            error="No output received from AI",
        )

    try:
        parsed = json.loads(result_text)
        if isinstance(parsed, dict):
            return ExtractionResult(data=[parsed], quality=ResultQuality.PARSED)
        return ExtractionResult(
            data=[], quality=ResultQuality.PARSE_FAILED,
            error="AI output is not a JSON object",
        )
    except json.JSONDecodeError as e:
        return ExtractionResult(
            data=[], quality=ResultQuality.PARSE_FAILED,
            error=f"Failed to parse: {e}",
        )
```

**Usage in a WebSocket handler:**

```python
if isinstance(message, ResultMessage):
    result = extract_list(message, "items", "generate-items")
    if result.is_usable:
        items = result.data
    elif result.error:
        log.warning(f"Extraction failed: {result.error}")
        await send({"type": "error", "message": result.error})
```

## Step 3: Pydantic Validation (Business Rules)

The JSON schema constrains structure. Pydantic validates business rules:

```python
from pydantic import BaseModel, Field, field_validator


class ValidatedItem(BaseModel):
    """Validated item from AI output."""
    name: str = Field(min_length=1, max_length=500)
    description: str = Field(min_length=1, max_length=5000)
    priority: str = "medium"
    tags: list[str] = Field(default_factory=list)

    @field_validator("priority")
    @classmethod
    def clamp_priority(cls, v: str) -> str:
        allowed = {"critical", "high", "medium", "low"}
        return v.lower() if isinstance(v, str) and v.lower() in allowed else "medium"

    @field_validator("tags")
    @classmethod
    def clamp_tags(cls, v: list) -> list[str]:
        if not isinstance(v, list):
            return []
        return [str(t)[:100] for t in v[:20]]


def validate_items(raw: list[dict]) -> tuple[list[ValidatedItem], list[dict]]:
    """Validate a batch of AI-generated items.

    Returns:
        (valid_items, rejected_items) — rejected includes error details.
    """
    valid: list[ValidatedItem] = []
    rejected: list[dict] = []
    for item in raw:
        try:
            valid.append(ValidatedItem(**item))
        except Exception as e:
            rejected.append({"item": item, "error": str(e)})

    if rejected:
        log.warning(f"Rejected {len(rejected)}/{len(raw)} items during validation")

    return valid, rejected
```

**Key design decisions:**
- **Clamp, don't reject**: Unknown priority becomes "medium" instead of raising an error
- **Return (valid, rejected)**: Caller decides how to handle partial failures
- **Log rejected items**: For debugging, never silently discard

## Full Flow: Schema + Extraction + Validation

```python
from claude_agent_sdk import ClaudeAgentOptions, ClaudeSDKClient, ResultMessage

async def generate_items(prompt: str):
    options = ClaudeAgentOptions(
        model="claude-sonnet-4-6",
        setting_sources=["user", "project", "local"],
        permission_mode="bypassPermissions",
        output_format={
            "type": "json_schema",
            "schema": ITEMS_SCHEMA,
            "strict": True,
        },
        max_turns=30,
    )

    client = ClaudeSDKClient(options=options)
    await client.connect()

    try:
        await client.query(prompt)

        async for message in client.receive_response():
            if isinstance(message, ResultMessage):
                # Step 2: Extract with quality tracking
                result = extract_list(message, "items", "generate")
                if not result.is_usable:
                    return {"error": result.error, "items": []}

                # Step 3: Validate with Pydantic
                valid, rejected = validate_items(result.data)

                # Step 4: Persist to database
                saved = []
                for item in valid:
                    saved.append(store.create_item(
                        name=item.name,
                        description=item.description,
                        priority=item.priority,
                        tags=item.tags,
                    ))

                return {
                    "items": saved,
                    "quality": result.quality.value,
                    "rejected": len(rejected),
                }
    finally:
        await client.disconnect()
```

## Never Default to "Passed" or "Success"

When the AI evaluates something (tests, analysis, scan), NEVER default the status to a positive outcome:

```python
# WRONG — silent false positive
status = "passed"  # This is DANGEROUS

# CORRECT — inconclusive until proven otherwise
status = "inconclusive"  # Default
if has_positive_evidence(result):
    status = "passed"
elif has_failure_evidence(result):
    status = "failed"
# else: stays "inconclusive" — honest about uncertainty
```
