.PHONY: help venv install install-hooks lint format typecheck test check clean

PYTHON ?= python3
VENV   ?= .venv
PIP    := $(VENV)/bin/pip
PY     := $(VENV)/bin/python

help: ## Show this help.
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

venv: $(VENV)/bin/activate ## Create a local virtualenv.

$(VENV)/bin/activate:
	$(PYTHON) -m venv $(VENV)
	$(PIP) install --upgrade pip

install: venv ## Install project with dev dependencies into .venv.
	$(PIP) install -e ".[dev]"

install-hooks: install ## Install pre-commit git hooks.
	$(VENV)/bin/pre-commit install

lint: ## Run ruff lint checks.
	$(VENV)/bin/ruff check .

format: ## Auto-format code (ruff --fix + black).
	$(VENV)/bin/ruff check --fix .
	$(VENV)/bin/black .

typecheck: ## Run mypy strict type checks.
	$(VENV)/bin/mypy .

test: ## Run pytest.
	$(VENV)/bin/pytest

check: lint typecheck test ## Run lint + typecheck + tests (what CI runs).

clean: ## Remove caches and venv.
	rm -rf $(VENV) .pytest_cache .mypy_cache .ruff_cache
	find . -type d -name __pycache__ -exec rm -rf {} +
