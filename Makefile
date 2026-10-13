# Makefile - first-run setup and dev tasks for new-windows-setup.
#
# Recipes only call pwsh, so they behave the same under sh or cmd.exe.
# Installers (setup-windows.ps1 / setup-wsl.ps1) need Administrator and are
# never launched from here: `make setup` prints the commands instead.

PWSH ?= pwsh
# Extra wizard switches, e.g.:  make setup WIZARD_ARGS=-UseDefaults
WIZARD_ARGS ?=

.DEFAULT_GOAL := help
.PHONY: help setup config wizard lint test

help:
	@echo Targets:
	@echo   make setup   - copy missing config files, ask the setup questions, print next steps
	@echo   make config  - only copy missing config files from the example templates
	@echo   make wizard  - only ask the questions, config files are created if missing
	@echo   make lint    - PSScriptAnalyzer and shellcheck
	@echo   make test    - Pester and bash tests
	@echo Options: WIZARD_ARGS=-UseDefaults  runs setup without prompts

setup: wizard

config:
	$(PWSH) -NoProfile -File scripts/setup-wizard.ps1 -ConfigOnly

wizard:
	$(PWSH) -NoProfile -File scripts/setup-wizard.ps1 $(WIZARD_ARGS)

lint:
	$(PWSH) -NoProfile -File lint.ps1

test:
	$(PWSH) -NoProfile -File test.ps1
