# [review:need-review] PHASE-01/24-ai-insights-endpoint-button
# summary: anthropic SDK client wrapper (claude-sonnet-5); LLMError mapping; no content/key logging
from __future__ import annotations

import anthropic

from app.llm.prompts import INSIGHTS_SYSTEM_PROMPT

INSIGHTS_MODEL = "claude-sonnet-5"
# Generous timeout: report generation over a month of data is a long request.
LLM_TIMEOUT_SECONDS = 120.0
# Total output budget (Sonnet 5 runs adaptive thinking by default,
# which shares this budget with the visible report text).
MAX_REPORT_TOKENS = 8192


class LLMError(Exception):
    """LLM call failed: upstream API error, timeout, or empty response."""


class InsightsClient:
    """
    Interface for insight generation.

    Tests mock at this boundary (see tests/test_insights.py); the real
    implementation is AnthropicInsightsClient below.
    """

    model: str = INSIGHTS_MODEL

    async def generate(self, context: str) -> str:
        """Generate a markdown insight report for the given period context."""
        raise NotImplementedError


class AnthropicInsightsClient(InsightsClient):
    """Insight generation backed by the Anthropic Messages API."""

    def __init__(self, api_key: str) -> None:
        self._client = anthropic.AsyncAnthropic(
            api_key=api_key, timeout=LLM_TIMEOUT_SECONDS
        )

    async def generate(self, context: str) -> str:
        try:
            response = await self._client.messages.create(
                model=INSIGHTS_MODEL,
                max_tokens=MAX_REPORT_TOKENS,
                system=INSIGHTS_SYSTEM_PROMPT,
                messages=[{"role": "user", "content": context}],
            )
        except anthropic.APIError as exc:
            # Only the exception class name is propagated: no prompt/report
            # content and no API key ever reach logs or error messages.
            raise LLMError(f"anthropic API error: {type(exc).__name__}") from exc

        text = "".join(block.text for block in response.content if block.type == "text")
        if not text:
            raise LLMError("empty response from LLM")
        return text
