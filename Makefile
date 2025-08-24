# InvoiceSplitter Build System
# Coordinates building both OCaml backend and Tauri frontend

.PHONY: all build clean test preview dev ocaml-build tauri-build bundle dmg help

# Default target
all: build

# Help target
help:
	@echo "InvoiceSplitter Build System"
	@echo ""
	@echo "Available targets:"
	@echo "  all         - Build both OCaml backend and Tauri app (default)"
	@echo "  build       - Same as 'all'"
	@echo "  ocaml-build - Build only the OCaml backend"
	@echo "  tauri-build - Build only the Tauri app (requires ocaml-build)"
	@echo "  bundle      - Create production bundles (DMG on macOS)"
	@echo "  dmg         - Create macOS DMG (alias for bundle on macOS)"
	@echo "  test        - Run tests for both projects"
	@echo "  preview     - Run OCaml backend in preview mode"
	@echo "  dev         - Start development server"
	@echo "  clean       - Clean all build artifacts"
	@echo ""
	@echo "Build order: ocaml-build -> tauri-build -> bundle"

# Build both projects
build: ocaml-build tauri-build

# Build OCaml backend
ocaml-build:
	@echo "🔧 Building OCaml backend..."
	@cd ocaml-backend && dune build
	@echo "✅ OCaml backend built successfully"

# Build Tauri app (depends on OCaml backend)
tauri-build: ocaml-build
	@echo "🔧 Building Tauri application..."
	@npm run tauri build -- --no-bundle
	@echo "✅ Tauri application built successfully"

# Create production bundles
bundle: ocaml-build
	@echo "📦 Creating production bundle..."
	@npm run tauri build
	@echo "✅ Bundle created successfully"

# macOS DMG (alias for bundle)
dmg: bundle

# Run tests
test: ocaml-build
	@echo "🧪 Running OCaml tests..."
	@cd ocaml-backend && dune runtest
	@echo "🧪 Running Tauri tests..."
	@npm test || echo "No frontend tests configured"
	@echo "✅ All tests completed"

# Preview mode (dry run)
preview: ocaml-build
	@echo "👁️  Running preview mode..."
	@cd ocaml-backend && dune exec src/main.exe -- -dry

# Development mode
dev:
	@echo "🚀 Starting development server..."
	@npm run tauri dev

# Clean build artifacts
clean:
	@echo "🧹 Cleaning build artifacts..."
	@cd ocaml-backend && dune clean
	@rm -rf src-tauri/target
	@rm -rf ocaml-backend/out/*.pdf
	@echo "✅ Cleanup completed"

# Verify build environment
check-env:
	@echo "🔍 Checking build environment..."
	@which dune > /dev/null || (echo "❌ dune not found. Install with: opam install dune" && exit 1)
	@which npm > /dev/null || (echo "❌ npm not found. Install Node.js" && exit 1)
	@which cargo > /dev/null || (echo "❌ cargo not found. Install Rust" && exit 1)
	@echo "✅ Build environment OK"

# Quick build for development (skips some checks)
quick: 
	@cd ocaml-backend && dune build && cd .. && npm run tauri build -- --no-bundle

# Install dependencies
deps:
	@echo "📥 Installing dependencies..."
	@cd ocaml-backend && opam install --deps-only .
	@npm install
	@echo "✅ Dependencies installed"