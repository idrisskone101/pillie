# Pillie iOS agent API. Wrappers keep the pinned simulator and /tmp DerivedData.
# Prefer these targets over raw xcodebuild. See .agents/skills/pillie-ios.

ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
SCRIPTS := $(ROOT)/Pillie/scripts
SCREENSHOT ?= /tmp/sim_screenshot.png
SCREENSHOT_1X ?= /tmp/sim_screenshot_1x.png
SCALE ?= 33.33%
TESTS ?=
BRANCH ?=

ifeq ($(shell command -v xcodebuildmcp >/dev/null 2>&1 && echo yes),yes)
BUILD_CMD := $(SCRIPTS)/mcp-build-and-run.sh
TEST_CMD := $(SCRIPTS)/mcp-test-focused.sh
else
BUILD_CMD := $(SCRIPTS)/build-and-run.sh
TEST_CMD := $(SCRIPTS)/test-focused.sh
endif

.DEFAULT_GOAL := help

CMD ?=
REF ?=
KEEP ?= 1
SKIP_BUILD ?= 0
CAPTURE_ONLY ?= 0
FORCE_BUILD ?= 0

WORKLOAD ?= all

.PHONY: help diagnose build run build-and-run test screenshot console \
	worktree agent-verify udid qa measure-frames \
	ns-mac-status ns-mac-start ns-mac-stop ns-mac-sync ns-mac-diagnose \
	ns-mac-exec ns-mac-verify ns-mac-screenshot ns-mac-qa ns-mac-check-sync \
	ns-mac-ensure-tools ensure-qa-tools

help:
	@printf "%s\n" \
		"Targets:" \
		"  make diagnose                 Toolchain, simulator, DerivedData" \
		"  make build                    Compile only" \
		"  make run                      Install + headless launch" \
		"  make build-and-run            Build, install, headless launch" \
		"  make test TESTS=Class         Focused XCTest class or method" \
		"  make screenshot               1x screenshot for visual QA" \
		"  make console                  Blocking app console" \
		"  make worktree BRANCH=codex/x  Feature worktree from this checkout" \
		"  make agent-verify             Build; test too if TESTS is set" \
		"  make qa                       Boot, build-and-run, wait, 1x PNG, axe" \
		"  make measure-frames           Scripted frame probe JSON (WORKLOAD=all)" \
		"  make udid                     Print the resolved iPhone 17 Pro UDID" \
		"  make ns-mac-status            Namespace Mac Devbox status" \
		"  make ns-mac-qa                Golden path: sync, boot, run, 1x PNG, axe" \
		"  make ns-mac-verify CMD='make x' Custom remote job; no CMD runs qa" \
		"  make ns-mac-screenshot         Same as ns-mac-qa" \
		"  make ns-mac-check-sync        Fail if HEAD is dirty or unpushed" \
		"  make ns-mac-start             Start the on-demand Namespace Mac" \
		"  make ns-mac-stop              Stop the Namespace Mac (user-gated)" \
		"  make ns-mac-sync              Checkout this SHA on the Mac" \
		"  make ns-mac-diagnose          Remote uname / Xcode / repo check" \
		"  make ns-mac-exec CMD='make x' Run a command on the Namespace Mac" \
		"  make ensure-qa-tools          Install axe and ImageMagick if missing" \
		"  make ns-mac-ensure-tools      Same, on the Namespace Mac"

diagnose:
	@$(SCRIPTS)/diagnose.sh

udid:
	@$(SCRIPTS)/diagnose.sh --udid

build:
	@$(BUILD_CMD) --build-only

run:
	@$(SCRIPTS)/build-and-run.sh --run-only

build-and-run:
	@$(BUILD_CMD)

test:
	@if [ -z "$(TESTS)" ]; then \
		echo "Pass TESTS=ClassName (or Class/method). Full-suite test is refused." >&2; \
		exit 64; \
	fi
	@$(TEST_CMD) $(TESTS)

screenshot:
	@SCREENSHOT="$(SCREENSHOT)" SCREENSHOT_1X="$(SCREENSHOT_1X)" SCALE="$(SCALE)" \
		$(SCRIPTS)/sim-qa.sh --capture-only

qa:
	@SCREENSHOT="$(SCREENSHOT)" SCREENSHOT_1X="$(SCREENSHOT_1X)" SCALE="$(SCALE)" \
		$(SCRIPTS)/sim-qa.sh

measure-frames:
	@WORKLOAD="$(WORKLOAD)" $(SCRIPTS)/measure-frames.sh "$(WORKLOAD)"

console:
	@$(SCRIPTS)/build-and-run.sh --run-only --console

worktree:
	@if [ -z "$(BRANCH)" ]; then \
		echo "Pass BRANCH=codex/<slug> or BRANCH=feature/<slug>." >&2; \
		exit 64; \
	fi
	@$(SCRIPTS)/create-worktree.sh "$(BRANCH)"

agent-verify: build
	@if [ -n "$(TESTS)" ]; then $(MAKE) test TESTS="$(TESTS)"; fi

ns-mac-status:
	@$(SCRIPTS)/namespace-mac.sh status

ns-mac-start:
	@$(SCRIPTS)/namespace-mac.sh start

ns-mac-stop:
	@$(SCRIPTS)/namespace-mac.sh stop

ns-mac-sync:
	@KEEP="$(KEEP)" $(SCRIPTS)/namespace-mac.sh sync "$(REF)"

ns-mac-check-sync:
	@$(SCRIPTS)/namespace-mac.sh check-sync "$(REF)"

ns-mac-diagnose:
	@KEEP="$(KEEP)" $(SCRIPTS)/namespace-mac.sh diagnose

ensure-qa-tools:
	@$(SCRIPTS)/ensure-qa-tools.sh

ns-mac-ensure-tools:
	@KEEP="$(KEEP)" REF="$(REF)" $(SCRIPTS)/namespace-mac.sh ensure-tools

ns-mac-exec:
	@if [ -z "$(CMD)" ]; then \
		echo "Pass CMD='make build' (or another remote command)." >&2; \
		exit 64; \
	fi
	@KEEP="$(KEEP)" $(SCRIPTS)/namespace-mac.sh exec -- /bin/bash -lc "$(CMD)"

ns-mac-qa:
	@KEEP="$(KEEP)" REF="$(REF)" SKIP_BUILD="$(SKIP_BUILD)" \
		CAPTURE_ONLY="$(CAPTURE_ONLY)" FORCE_BUILD="$(FORCE_BUILD)" \
		$(SCRIPTS)/namespace-mac.sh qa

ns-mac-verify:
	@if [ -z "$(CMD)" ]; then \
		KEEP="$(KEEP)" REF="$(REF)" SKIP_BUILD="$(SKIP_BUILD)" \
			CAPTURE_ONLY="$(CAPTURE_ONLY)" FORCE_BUILD="$(FORCE_BUILD)" \
			$(SCRIPTS)/namespace-mac.sh qa; \
	else \
		KEEP="$(KEEP)" REF="$(REF)" $(SCRIPTS)/namespace-mac.sh verify -- /bin/bash -lc "$(CMD)"; \
	fi

ns-mac-screenshot:
	@KEEP="$(KEEP)" REF="$(REF)" SKIP_BUILD="$(SKIP_BUILD)" \
		CAPTURE_ONLY="$(CAPTURE_ONLY)" FORCE_BUILD="$(FORCE_BUILD)" \
		$(SCRIPTS)/namespace-mac.sh qa
