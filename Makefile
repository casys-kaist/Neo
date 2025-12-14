# Default: do nothing
.DEFAULT_GOAL := nop
nop:
	@:

# Detect if running on Orin device
MODEL_FILE := /proc/device-tree/model
IS_ORIN := $(shell sh -c 'grep -qi "Orin" $(MODEL_FILE) 2>/dev/null && echo 1 || echo 0')

ifeq ($(IS_ORIN),1)
format:
	@echo "Orin device detected; running formatting in Orin environment"
	ruff check --fix --select=I001
	ruff format
	git ls-files '*.c' '*.cpp' '*.cc' '*.cu' '*.h' '*.hh' '*.hpp' | xargs clang-format -i
	git ls-files '*.sh' | xargs shfmt -w -i 4
	git ls-files '*.yaml' '*.yml' | xargs yamlfmt -formatter indent=2,indentless_arrays=true,retain_line_breaks_single=true,trim_trailing_whitespace=true
else
format:
	@echo "RTX device detected; running formatting in RTX environment"
	ruff check --fix --select=I001
	ruff format
	git ls-files '*.c' '*.cpp' '*.cc' '*.cu' '*.h' '*.hh' '*.hpp' | xargs clang-format -i
	git ls-files '*.sh' | xargs shfmt -w -i 4
	git ls-files '*.yaml' '*.yml' | xargs yamlfmt -formatter indent=2,indentless_arrays=true,retain_line_breaks_single=true,trim_trailing_whitespace=true
endif
