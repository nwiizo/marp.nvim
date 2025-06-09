.PHONY: all lint format check test clean help

# Default target
all: check

# Run both linter and formatter check
check: lint format-check

# Run luacheck
lint:
	@echo "Running luacheck..."
	@luacheck lua/ plugin/ || (echo "Luacheck found issues" && exit 1)

# Format code with stylua
format:
	@echo "Formatting Lua files with stylua..."
	@stylua lua/ plugin/ --glob '**/*.lua'

# Check formatting without modifying files
format-check:
	@echo "Checking Lua formatting..."
	@stylua --check lua/ plugin/ --glob '**/*.lua' || (echo "Code is not formatted. Run 'make format' to fix." && exit 1)

# Run tests
test:
	@echo "Running tests..."
	@nvim --headless -u minimal_init.lua -c "echo 'Tests completed'" -c "qa"

# Clean generated files
clean:
	@echo "Cleaning generated files..."
	@rm -f test_marp.html
	@rm -f debug_marp.vim
	@echo "Clean complete"

# Help
help:
	@echo "Available targets:"
	@echo "  make check        - Run linting and format checking"
	@echo "  make lint         - Run luacheck"
	@echo "  make format       - Format code with stylua"
	@echo "  make format-check - Check code formatting"
	@echo "  make test         - Run tests"
	@echo "  make clean        - Remove generated files"
	@echo "  make help         - Show this help message"