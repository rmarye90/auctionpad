.PHONY: help lint test check test-watch

help:
	@echo "Auctionpad Makefile"
	@echo ""
	@echo "Available targets:"
	@echo "  make test        - Run all tests"
	@echo "  make lint        - Run luacheck linter"
	@echo "  make check       - Run both linter and tests"
	@echo "  make test-watch  - Run tests in watch mode"
	@echo "  make help        - Show this help"

lint:
	@echo "Running luacheck..."
	@luacheck . --no-color

test:
	@echo "Running Auctionpad tests..."
	@busted --verbose

check: lint test
	@echo "✓ All checks passed!"

test-watch:
	@echo "Watching for changes..."
	@find . -name "*.lua" | entr -c make test
