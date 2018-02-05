
# Enforce the presence of the GIT repository
#
# We depend on our submodules, so we have to prevent attempts to
# compile without it being present.
ifeq ($(wildcard .git),)
    $(error YOU HAVE TO USE GIT TO DOWNLOAD THIS REPOSITORY. ABORTING.)
endif


#  explicity set default build target
all: 

# Parsing
# --------------------------------------------------------------------
# assume 1st argument passed is the main target, the
# rest are arguments to pass to the makefile generated
# by cmake in the subdirectory
FIRST_ARG := $(firstword $(MAKECMDGOALS))
ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
j ?= 4

NINJA_BIN := ninja
ifndef NO_NINJA_BUILD
	NINJA_BUILD := $(shell $(NINJA_BIN) --version 2>/dev/null)

	ifndef NINJA_BUILD
		NINJA_BIN := ninja-build
		NINJA_BUILD := $(shell $(NINJA_BIN) --version 2>/dev/null)
	endif
endif

ifdef NINJA_BUILD
	PX4_CMAKE_GENERATOR := Ninja
	PX4_MAKE := $(NINJA_BIN)

	ifdef VERBOSE
		PX4_MAKE_ARGS := -v
	else
		PX4_MAKE_ARGS :=
	endif
else
	ifdef SYSTEMROOT
		# Windows
		PX4_CMAKE_GENERATOR := "MSYS\ Makefiles"
	else
		PX4_CMAKE_GENERATOR := "Unix\ Makefiles"
	endif
	PX4_MAKE = $(MAKE)
	PX4_MAKE_ARGS = -j$(j) --no-print-directory
endif

SRC_DIR := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

# Functions
# --------------------------------------------------------------------
# describe how to build a cmake config
define cmake-build
+@$(eval BUILD_DIR = $(SRC_DIR)/build/$@$(BUILD_DIR_SUFFIX))
+@if [ $(PX4_CMAKE_GENERATOR) = "Ninja" ] && [ -e $(BUILD_DIR)/Makefile ]; then rm -rf $(BUILD_DIR); fi
+@if [ ! -e $(BUILD_DIR)/CMakeCache.txt ]; then mkdir -p $(BUILD_DIR) && cd $(BUILD_DIR) && cmake $(2) -G"$(PX4_CMAKE_GENERATOR)" $(CMAKE_ARGS) || (rm -rf $(BUILD_DIR)); fi
+@(cd $(BUILD_DIR) && $(PX4_MAKE) $(PX4_MAKE_ARGS) $(ARGS))
endef



all:
	$(call cmake-build,$@,$(SRC_DIR))


# Astyle
# --------------------------------------------------------------------
.PHONY: check_format format

check_format:
	$(call colorecho,"Checking formatting with astyle")
	@$(SRC_DIR)/Tools/astyle/check_code_style_all.sh
	@cd $(SRC_DIR) && git diff --check

format:
	$(call colorecho,"Formatting with astyle")
	@$(SRC_DIR)/Tools/astyle/check_code_style_all.sh --fix

# Testing
# --------------------------------------------------------------------
.PHONY: tests tests_coverage

tests:

tests_coverage:

scan-build:
	@export CCC_CC=clang
	@export CCC_CXX=clang++
	@rm -rf $(SRC_DIR)/build/posix_sitl_default-scan-build
	@rm -rf $(SRC_DIR)/build/scan-build/report_latest
	@mkdir -p $(SRC_DIR)/build/posix_sitl_default-scan-build
	@cd $(SRC_DIR)/build/posix_sitl_default-scan-build && scan-build cmake $(SRC_DIR) -GNinja -DCONFIG=posix_sitl_default
	@scan-build -o $(SRC_DIR)/build/scan-build cmake --build $(SRC_DIR)/build/posix_sitl_default-scan-build
	@find $(SRC_DIR)/build/scan-build -maxdepth 1 -mindepth 1 -type d -exec cp -r "{}" $(SRC_DIR)/build/scan-build/report_latest \;

clang-tidy: posix_sitl_default-clang
	@cd $(SRC_DIR)/build/posix_sitl_default-clang && $(SRC_DIR)/Tools/run-clang-tidy.py -header-filter=".*\.hpp" -j$(j) -p .

# to automatically fix a single check at a time, eg modernize-redundant-void-arg
#  % run-clang-tidy-4.0.py -fix -j4 -checks=-\*,modernize-redundant-void-arg -p .
clang-tidy-fix: posix_sitl_default-clang
	@cd $(SRC_DIR)/build/posix_sitl_default-clang && $(SRC_DIR)/Tools/run-clang-tidy.py -header-filter=".*\.hpp" -j$(j) -fix -p .

# modified version of run-clang-tidy.py to return error codes and only output relevant results
clang-tidy-quiet: posix_sitl_default-clang
	@cd $(SRC_DIR)/build/posix_sitl_default-clang && $(SRC_DIR)/Tools/run-clang-tidy.py -header-filter=".*\.hpp" -j$(j) -p .

# TODO: Fix cppcheck errors then try --enable=warning,performance,portability,style,unusedFunction or --enable=all
cppcheck: posix_sitl_default
	@mkdir -p $(SRC_DIR)/build/cppcheck
	@cppcheck -i$(SRC_DIR)/src/examples --enable=performance --std=c++11 --std=c99 --std=posix --project=$(SRC_DIR)/build/posix_sitl_default/compile_commands.json --xml-version=2 2> $(SRC_DIR)/build/cppcheck/cppcheck-result.xml > /dev/null
	@cppcheck-htmlreport --source-encoding=ascii --file=$(SRC_DIR)/build/cppcheck/cppcheck-result.xml --report-dir=$(SRC_DIR)/build/cppcheck --source-dir=$(SRC_DIR)/src/

# Cleanup
# --------------------------------------------------------------------
.PHONY: clean submodulesclean submodulesupdate distclean

clean:
	@rm -rf $(SRC_DIR)/build

submodulesclean:
	@git submodule foreach --quiet --recursive git clean -ff -x -d
	@git submodule update --quiet --init --recursive --force || true
	@git submodule sync --recursive
	@git submodule update --init --recursive --force

submodulesupdate:
	@git submodule update --quiet --init --recursive || true
	@git submodule sync --recursive
	@git submodule update --init --recursive

distclean:
	@git submodule deinit -f .
	@git clean -ff -x -d -e ".project" -e ".cproject" -e ".idea" -e ".settings" -e ".vscode"

