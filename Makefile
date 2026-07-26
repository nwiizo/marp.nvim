.PHONY: all lint format check test integration help

# Default target
all: check

# Run both linter and formatter check
check: lint format-check

# Run luacheck
lint:
	@echo "Running luacheck..."
	@luacheck lua/ plugin/ tests/ minimal_init.lua || (echo "Luacheck found issues" && exit 1)

# Format code with stylua
format:
	@echo "Formatting Lua files with stylua..."
	@stylua lua/ plugin/ tests/ minimal_init.lua --glob '**/*.lua'

# Check formatting without modifying files
format-check:
	@echo "Checking Lua formatting..."
	@stylua --check lua/ plugin/ tests/ minimal_init.lua --glob '**/*.lua' || (echo "Code is not formatted. Run 'make format' to fix." && exit 1)

# Run tests
test:
	@echo "Running tests..."
	@nvim --headless -u NONE --cmd "set runtimepath+=$(CURDIR)" \
		-c "luafile tests/marp_cli_spec.lua" -c "qa!"

# Run integration tests against an installed Marp CLI
integration:
	@echo "Running Marp integration tests..."
	@nvim --headless -u NONE --cmd "set runtimepath+=$(CURDIR)" \
		-c "luafile tests/marp_integration.lua" -c "qa!"

# Help
help:
	@echo "Available targets:"
	@echo "  make check        - Run linting and format checking"
	@echo "  make lint         - Run luacheck"
	@echo "  make format       - Format code with stylua"
	@echo "  make format-check - Check code formatting"
	@echo "  make test         - Run tests"
	@echo "  make integration  - Run tests against an installed Marp CLI"
	@echo "  make help         - Show this help message"
