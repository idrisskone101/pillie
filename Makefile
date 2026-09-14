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
KEEP ?=

.PHONY: help diagnose build run build-and-run test screenshot console \
	worktree agent-verify udid \
	ns-mac-status ns-mac-start ns-mac-stop ns-mac-sync ns-mac-diagnose \
	ns-mac-exec ns-mac-verify

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
		"  make udid                     Print the resolved iPhone 17 Pro UDID" \
		"  make ns-mac-status            Namespace Mac Devbox status" \
		"  make ns-mac-verify CMD='make x' Start, sync, run, stop (preferred)" \
		"  make ns-mac-start             Start the on-demand Namespace Mac" \
		"  make ns-mac-stop              Stop the Namespace Mac" \
		"  make ns-mac-sync              Checkout this SHA on the Mac" \
		"  make ns-mac-diagnose          Remote uname / Xcode / repo check" \
		"  make ns-mac-exec CMD='make x' Run a command on the Namespace Mac"

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
	@udid="$$($(SCRIPTS)/diagnose.sh --udid)"; \
	xcrun simctl io "$$udid" screenshot "$(SCREENSHOT)"; \
	magick "$(SCREENSHOT)" -resize "$(SCALE)" "$(SCREENSHOT_1X)"; \
	echo "Wrote $(SCREENSHOT_1X)"

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

ns-mac-diagnose:
	@KEEP="$(KEEP)" $(SCRIPTS)/namespace-mac.sh diagnose

ns-mac-exec:
	@if [ -z "$(CMD)" ]; then \
		echo "Pass CMD='make build' (or another remote command)." >&2; \
		exit 64; \
	fi
	@KEEP="$(KEEP)" $(SCRIPTS)/namespace-mac.sh exec -- /bin/bash -lc "$(CMD)"

ns-mac-verify:
	@if [ -z "$(CMD)" ]; then \
		echo "Pass CMD='make build' (or another remote command)." >&2; \
		exit 64; \
	fi
	@KEEP="$(KEEP)" REF="$(REF)" $(SCRIPTS)/namespace-mac.sh verify -- /bin/bash -lc "$(CMD)"
