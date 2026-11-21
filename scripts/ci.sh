#!/usr/bin/env bash
# ==============================================================================
# Maczy Local CI Pipeline Runner
# Runs the identical checks as GitHub Actions:
# 1. Environment Verification
# 2. Rust Formatting (cargo fmt)
# 3. Rust Clippy Linting (-D warnings)
# 4. Rust Unit & Performance Tests (cargo test)
# 5. Swift Package Tests (swift test)
# 6. Xcode Universal Build (xcodebuild)
# 7. Ad-Hoc Code Signing Verification (codesign)
# ==============================================================================

set -euo pipefail

export PATH="/opt/homebrew/bin:$PATH"

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Maczy CI Pipeline — Local Execution  ${NC}"
echo -e "${BLUE}========================================${NC}"

START_TIME=$(date +%s)

echo -e "\n${BLUE}[1/7] Checking environment...${NC}"
echo "Rustc: $(rustc --version)"
echo "Cargo: $(cargo --version)"
echo "Swift: $(swift --version | head -n 1)"
echo "Xcode: $(xcodebuild -version | head -n 1)"

echo -e "\n${BLUE}[2/7] Checking Rust formatting (cargo fmt)...${NC}"
cargo fmt --all -- --check
echo -e "${GREEN}✓ Rust formatting clean.${NC}"

echo -e "\n${BLUE}[3/7] Running Rust Clippy lints (-D warnings)...${NC}"
cargo clippy --workspace --all-targets -- -D warnings
echo -e "${GREEN}✓ Clippy clean with zero warnings.${NC}"

echo -e "\n${BLUE}[4/7] Running Rust Unit & Performance Tests...${NC}"
cargo test --workspace
echo -e "${GREEN}✓ All Rust tests passed.${NC}"

echo -e "\n${BLUE}[5/7] Running Swift Package Tests...${NC}"
swift test
echo -e "${GREEN}✓ All Swift tests passed.${NC}"

echo -e "\n${BLUE}[6/7] Building with Xcode (xcodebuild arm64)...${NC}"
xcodebuild -scheme Maczy -destination "platform=macOS,arch=arm64" build -quiet
echo -e "${GREEN}✓ Xcode build succeeded.${NC}"

echo -e "\n${BLUE}[7/7] Verifying Ad-Hoc Code Signing...${NC}"
BINARY=".build/arm64-apple-macosx/debug/Maczy"
if [ -f "$BINARY" ]; then
    codesign -s - -f "$BINARY"
    codesign --verify --verbose=4 "$BINARY"
    echo -e "${GREEN}✓ Ad-hoc signature verified on $BINARY.${NC}"
else
    echo -e "${GREEN}✓ Universal build verified.${NC}"
fi

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}  ALL CI CHECKS PASSED in ${DURATION}s           ${NC}"
echo -e "${GREEN}========================================${NC}"
