"""
initialize_claude_patch.py
──────────────────────────
Auto-injected by install_kali.sh.
Sets OpenRouter free model as the default model for Agent Zero
when no other model is explicitly configured in settings.
"""

import os


def apply_default_model_envs():
    """
    Set environment variables Agent Zero reads for model configuration.
    Uses os.environ.setdefault so user overrides in .env are respected.
    Defaults are set to OpenRouter's free model (openrouter/free) for
    chat and utility, and a HuggingFace embedding model.
    """
    defaults = {
        # Primary conversational model (OpenRouter free tier)
        "A0_CHAT_MODEL_PROVIDER":    "openrouter",
        "A0_CHAT_MODEL_NAME":        "openrouter/free",
        # Utility / summarization (same model for parity)
        "A0_UTILITY_MODEL_PROVIDER": "openrouter",
        "A0_UTILITY_MODEL_NAME":     "openrouter/free",
        # Local embedding model — no API key required
        "A0_EMBED_MODEL_PROVIDER":   "huggingface",
        "A0_EMBED_MODEL_NAME":       "sentence-transformers/all-MiniLM-L6-v2",
    }
    for key, value in defaults.items():
        os.environ.setdefault(key, value)


apply_default_model_envs()
