# Pillie iOS agent API. Wrappers keep the pinned simulator and /tmp DerivedData.
# Prefer these targets over raw xcodebuild. See .agents/skills/pillie-ios.

ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
SCRIPTS := $(ROOT)/Pillie/scripts
UDID ?= $(PILLIE_SIMULATOR_UDID)
ifeq ($(UDID),)
UDID := 124DC75F-0771-4C81-841D-F13655138260
endif
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

.PHONY: help diagnose build run build-and-run test screenshot console \
	worktree agent-verify udid

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
		"  make udid                     Print the pinned simulator UDID"

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
	xcrun simctl io "$(UDID)" screenshot "$(SCREENSHOT)"
	magick "$(SCREENSHOT)" -resize "$(SCALE)" "$(SCREENSHOT_1X)"
	@echo "Wrote $(SCREENSHOT_1X)"

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
