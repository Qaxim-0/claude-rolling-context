#!/bin/bash
# Stress test: have Claude Code generate lots of context to trigger compression.
# Using low trigger (5000 tokens) so it should compress after a few exchanges.

export ANTHROPIC_BASE_URL="http://127.0.0.1:5588"

echo "=== Starting stress test ==="
echo "Trigger: $ROLLING_CONTEXT_TRIGGER tokens"
echo "Target: $ROLLING_CONTEXT_TARGET tokens"
echo ""

# Single prompt that asks Claude to be verbose, generating enough tokens
claude -p "I need you to do several things, be detailed:
1. Write a Python function that implements binary search with full docstring and type hints
2. Then write comprehensive unit tests for it using pytest
3. Then explain how the algorithm works step by step
4. Then write a JavaScript version of the same thing
5. Then compare the two implementations
Please be thorough and detailed in all responses."
