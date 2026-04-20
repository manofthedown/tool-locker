"""Phase 0 smoke tests.

Exists solely to give pytest a non-empty test suite so that `make test`
and CI have something real to execute. Replace with genuine tests as
each phase lands.
"""

from __future__ import annotations

import importlib


def test_python_runtime_is_supported() -> None:
    """The project targets Python 3.11+."""
    import sys

    assert sys.version_info >= (
        3,
        11,
    ), f"Python 3.11+ required, got {sys.version_info.major}.{sys.version_info.minor}"


def test_app_namespaces_importable() -> None:
    """Each app package must import cleanly from a fresh checkout."""
    for name in ("apps", "apps.api", "apps.scanner_daemon", "apps.hardware_daemon"):
        module = importlib.import_module(name)
        assert module is not None
