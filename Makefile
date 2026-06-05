APP_NAME := AntigravityBar
APP_PROJECT := AntigravityBar.xcodeproj
APP_SCHEME := AntigravityBar
CONFIGURATION ?= Debug
AGENT_NAME ?= CODEX
DERIVED := build/DerivedData/$(AGENT_NAME)
LOG_DIR := build/logs/$(AGENT_NAME)
APP_PATH := $(DERIVED)/Build/Products/$(CONFIGURATION)/$(APP_SCHEME).app
DESTINATION := platform=macOS,arch=arm64

.PHONY: help generate build test run build-and-run agent-verify clean

help:
	@printf "%s\n" \
		"Targets:" \
		"  make generate       Generate Xcode project" \
		"  make build          Build the app" \
		"  make test           Run unit tests" \
		"  make run            Run built app" \
		"  make build-and-run  Build then run" \
		"  make agent-verify   Build and test" \
		"  make clean          Remove build output"

generate:
	@xcodegen generate

build: generate
	@mkdir -p "$(LOG_DIR)"
	@xcodebuild build \
		-project "$(APP_PROJECT)" \
		-scheme "$(APP_SCHEME)" \
		-configuration "$(CONFIGURATION)" \
		-destination '$(DESTINATION)' \
		-derivedDataPath "$(DERIVED)" \
		GCC_TREAT_WARNINGS_AS_ERRORS=YES \
		SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
		SWIFT_STRICT_CONCURRENCY=complete \
		| tee "$(LOG_DIR)/build.log"

test: generate
	@mkdir -p "$(LOG_DIR)"
	@xcodebuild test \
		-project "$(APP_PROJECT)" \
		-scheme "$(APP_SCHEME)" \
		-configuration "$(CONFIGURATION)" \
		-destination '$(DESTINATION)' \
		-derivedDataPath "$(DERIVED)" \
		GCC_TREAT_WARNINGS_AS_ERRORS=YES \
		SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
		SWIFT_STRICT_CONCURRENCY=complete \
		| tee "$(LOG_DIR)/test.log"

run:
	@script/build_and_run.sh --run-only

build-and-run:
	@script/build_and_run.sh

agent-verify: build test

clean:
	@rm -rf build
