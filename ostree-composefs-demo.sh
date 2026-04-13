#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to show and run commands
run() {
    echo -e "${CYAN}\$ $*${NC}"
    "$@"
}

# Function to pause for presenter
pause() {
    echo -e "\n${YELLOW}Press ENTER to continue...${NC}"
    read -r
}

echo -e "${BLUE}=== OSTree + fs-verity + composefs Security Demo ===${NC}\n"

# Cleanup function
cleanup() {
    echo -e "\n${YELLOW}Cleaning up...${NC}"
    umount checkout-composefs 2>/dev/null || true
    fusermount3 -u checkout-composefs 2>/dev/null || true
    fusermount -u checkout-composefs 2>/dev/null || true
    # Remove any chattr immutable flags
    if command -v chattr &> /dev/null; then
        chattr -i checkout-fsverity/* 2>/dev/null || true
        chattr -i checkout-fsverity/*/* 2>/dev/null || true
    fi
    rm -rf demo-repo staging checkout-* objects.cfs
}

# Cleanup any previous runs
cleanup

# Step 1: Create an OSTree repository
echo -e "${GREEN}Step 1: Creating OSTree repository${NC}"
run ostree --repo=demo-repo init --mode=bare-user
echo

# Step 2: Create some sample files
echo -e "${GREEN}Step 2: Creating sample files${NC}"
run mkdir -p staging
echo -e "${CYAN}\$ echo \"Hello from file1\" > staging/file1.txt${NC}"
echo "Hello from file1" > staging/file1.txt
echo -e "${CYAN}\$ echo \"Hello from file2\" > staging/file2.txt${NC}"
echo "Hello from file2" > staging/file2.txt
run mkdir -p staging/subdir
echo -e "${CYAN}\$ echo \"Hello from nested file\" > staging/subdir/nested.txt${NC}"
echo "Hello from nested file" > staging/subdir/nested.txt
run chmod 644 staging/*.txt staging/subdir/*.txt
run tree staging/
echo

# Step 3: Commit to OSTree
echo -e "${GREEN}Step 3: Committing to OSTree${NC}"
run ostree --repo=demo-repo commit \
    --branch=main \
    --subject="Initial commit" \
    staging/

COMMIT=$(ostree --repo=demo-repo rev-parse main)
echo -e "Commit hash: ${YELLOW}${COMMIT}${NC}\n"

pause
clear

# ============================================================================
# DEMO 1: Regular checkout (fully mutable)
# ============================================================================
echo -e "${BLUE}=== DEMO 1: Regular OSTree checkout (no security) ===${NC}"
run ostree --repo=demo-repo checkout main checkout-regular
echo

echo -e "${YELLOW}Original content:${NC}"
run cat checkout-regular/file1.txt
echo

echo -e "${YELLOW}Attempting to modify file1.txt...${NC}"
echo -e "${CYAN}\$ echo \"MODIFIED CONTENT\" > checkout-regular/file1.txt${NC}"
if echo "MODIFIED CONTENT" > checkout-regular/file1.txt; then
    echo -e "${RED}✓ SUCCESS: File was modified!${NC}"
    run cat checkout-regular/file1.txt
else
    echo -e "${GREEN}✗ FAILED: Could not modify${NC}"
fi
echo

echo -e "${YELLOW}Attempting to chmod file1.txt...${NC}"
if run chmod 777 checkout-regular/file1.txt; then
    echo -e "${RED}✓ SUCCESS: Permissions changed!${NC}"
    run ls -l checkout-regular/file1.txt
else
    echo -e "${GREEN}✗ FAILED: Could not chmod${NC}"
fi
echo

echo -e "${YELLOW}Attempting to add new file...${NC}"
echo -e "${CYAN}\$ echo \"new content\" > checkout-regular/newfile.txt${NC}"
if echo "new content" > checkout-regular/newfile.txt; then
    echo -e "${RED}✓ SUCCESS: New file added!${NC}"
    run ls -l checkout-regular/
    run cat checkout-regular/newfile.txt
else
    echo -e "${GREEN}✗ FAILED: Could not add file${NC}"
fi
echo

echo -e "${YELLOW}Attempting to remove file2.txt...${NC}"
if run rm checkout-regular/file2.txt 2>/dev/null; then
    echo -e "${RED}✓ SUCCESS: File was deleted!${NC}"
    run ls -l checkout-regular/
else
    echo -e "${GREEN}✗ FAILED: Could not delete file${NC}"
fi

echo -e "\n${RED}CONCLUSION: Regular checkout is fully mutable - NO SECURITY${NC}\n"

pause
clear

# ============================================================================
# DEMO 2: Checkout with fs-verity (content protection only)
# ============================================================================
echo -e "${BLUE}=== DEMO 2: OSTree checkout with fs-verity ===${NC}"
echo -e "${YELLOW}Checking out files and enabling fs-verity on them...${NC}"
run ostree --repo=demo-repo checkout --force-copy main checkout-fsverity
echo

# Enable fs-verity on the checked out files
echo -e "${YELLOW}Enabling fs-verity on files (requires root):${NC}"
if command -v fsverity &> /dev/null; then
    # fs-verity enable requires root privileges
    for file in checkout-fsverity/file1.txt checkout-fsverity/file2.txt checkout-fsverity/subdir/nested.txt; do
        echo -e "${CYAN}\$ sudo fsverity enable $file${NC}"
        if sudo fsverity enable "$file" 2>/dev/null; then
            echo -e "${GREEN}✓ Enabled fs-verity on $file${NC}"
        else
            echo -e "${YELLOW}⚠ Could not enable fs-verity (check kernel support)${NC}"
        fi
    done
    echo

    echo -e "${YELLOW}Checking fs-verity status:${NC}"
    run fsverity measure checkout-fsverity/file1.txt 2>/dev/null || echo -e "${YELLOW}fs-verity not active${NC}"
else
    echo -e "${YELLOW}⚠ fsverity command not installed${NC}"
    echo -e "${YELLOW}Install with: sudo dnf install fsverity-utils${NC}"
    echo -e "${YELLOW}Skipping fs-verity demo...${NC}"
fi
echo

echo -e "${YELLOW}Original content:${NC}"
run cat checkout-fsverity/file1.txt
echo

echo -e "${YELLOW}Attempting to modify file1.txt...${NC}"
echo -e "${CYAN}\$ echo \"MODIFIED CONTENT\" > checkout-fsverity/file1.txt${NC}"
if echo "MODIFIED CONTENT" > checkout-fsverity/file1.txt 2>/dev/null; then
    echo -e "${RED}✓ SUCCESS: File was modified! (fs-verity not active)${NC}"
    run cat checkout-fsverity/file1.txt
else
    echo -e "${GREEN}✗ FAILED: Cannot modify (fs-verity/immutable protection)${NC}"
fi
echo

echo -e "${YELLOW}Attempting to chmod file1.txt...${NC}"
if run chmod 777 checkout-fsverity/file1.txt 2>/dev/null; then
    echo -e "${RED}✓ SUCCESS: Permissions can still be changed!${NC}"
    run ls -l checkout-fsverity/file1.txt
    echo -e "${YELLOW}Note: fs-verity only protects content, not metadata${NC}"
else
    echo -e "${GREEN}✗ FAILED: Cannot chmod${NC}"
fi
echo

echo -e "${YELLOW}Attempting to add new file...${NC}"
echo -e "${CYAN}\$ echo \"new content\" > checkout-fsverity/newfile.txt${NC}"
if echo "new content" > checkout-fsverity/newfile.txt 2>/dev/null; then
    echo -e "${RED}✓ SUCCESS: New files can still be added!${NC}"
    run ls -l checkout-fsverity/
    echo -e "${YELLOW}Note: fs-verity only protects existing files${NC}"
else
    echo -e "${GREEN}✗ FAILED: Cannot add file${NC}"
fi
echo

echo -e "${YELLOW}Attempting to remove file2.txt...${NC}"
echo -e "${CYAN}\$ rm checkout-fsverity/file2.txt${NC}"
if rm checkout-fsverity/file2.txt 2>/dev/null; then
    echo -e "${RED}✓ SUCCESS: File was deleted!${NC}"
    run ls -l checkout-fsverity/
    echo -e "${YELLOW}Note: fs-verity doesn't prevent deletion${NC}"
else
    echo -e "${GREEN}✗ FAILED: Could not delete file${NC}"
fi

# Cleanup chattr if we used it
if command -v chattr &> /dev/null; then
    chattr -i checkout-fsverity/file1.txt 2>/dev/null || true
fi

echo -e "\n${YELLOW}CONCLUSION: fs-verity protects file CONTENT but allows chmod, add, and delete${NC}\n"

pause
clear

# ============================================================================
# DEMO 3: Composefs mount (immutable + fs-verity)
# ============================================================================
echo -e "${BLUE}=== DEMO 3: OSTree with composefs (full security) ===${NC}"

# Generate composefs metadata from ostree
echo -e "${YELLOW}Generating composefs metadata from ostree commit...${NC}"
mkdir -p checkout-composefs-staging
echo -e "${CYAN}\$ ostree --repo=demo-repo checkout --composefs main checkout-composefs-staging/metadata.cfs${NC}"
if ostree --repo=demo-repo checkout --composefs main checkout-composefs-staging/metadata.cfs 2>/dev/null; then
    echo -e "${GREEN}✓ Composefs metadata created${NC}"
    COMPOSEFS_FILE="checkout-composefs-staging/metadata.cfs"
    run ls -lh "$COMPOSEFS_FILE"
elif command -v mkcomposefs &> /dev/null; then
    # Fallback: create regular checkout and build composefs from it
    echo -e "${YELLOW}Using mkcomposefs to create image...${NC}"
    run ostree --repo=demo-repo checkout --force-copy main checkout-composefs-staging
    run mkcomposefs --digest-store=demo-repo/objects checkout-composefs-staging objects.cfs
    echo -e "${GREEN}✓ Composefs image created: objects.cfs${NC}"
    COMPOSEFS_FILE="objects.cfs"
else
    echo -e "${RED}✗ mkcomposefs not found${NC}"
    COMPOSEFS_FILE=""
fi
echo

if [ -n "$COMPOSEFS_FILE" ] && [ -f "$COMPOSEFS_FILE" ]; then

    # Mount it (no root needed with FUSE)
    mkdir -p checkout-composefs
    echo -e "${YELLOW}Mounting composefs image...${NC}"

    if run mount.composefs -o basedir=demo-repo/objects "$COMPOSEFS_FILE" checkout-composefs 2>/dev/null; then
        echo -e "${GREEN}✓ Composefs mounted successfully (via FUSE)${NC}"
        echo

        echo -e "${YELLOW}Checking mounted content:${NC}"
        run ls -la checkout-composefs/
        echo -e "${YELLOW}Note: ostree --composefs adds FHS directories (boot,etc,usr,var,sysroot) for system deployments${NC}"
        run cat checkout-composefs/file1.txt
        echo

        echo -e "${YELLOW}Checking mount options:${NC}"
        run mount | grep composefs
        echo

        echo -e "${YELLOW}Attempting to modify file1.txt...${NC}"
        echo -e "${CYAN}\$ echo \"MODIFIED\" > checkout-composefs/file1.txt${NC}"
        if echo "MODIFIED" > checkout-composefs/file1.txt 2>/dev/null; then
            echo -e "${RED}✓ SUCCESS: File was modified!${NC}"
        else
            echo -e "${GREEN}✗ FAILED: Cannot modify (read-only filesystem)${NC}"
        fi
        echo

        echo -e "${YELLOW}Attempting to chmod file1.txt...${NC}"
        echo -e "${CYAN}\$ chmod 777 checkout-composefs/file1.txt${NC}"
        if chmod 777 checkout-composefs/file1.txt 2>/dev/null; then
            echo -e "${RED}✓ SUCCESS: Changed permissions!${NC}"
        else
            echo -e "${GREEN}✗ FAILED: Cannot chmod (read-only filesystem)${NC}"
        fi
        echo

        echo -e "${YELLOW}Attempting to add new file...${NC}"
        echo -e "${CYAN}\$ echo \"new\" > checkout-composefs/newfile.txt${NC}"
        if echo "new" > checkout-composefs/newfile.txt 2>/dev/null; then
            echo -e "${RED}✓ SUCCESS: Added new file!${NC}"
        else
            echo -e "${GREEN}✗ FAILED: Cannot add files (read-only filesystem)${NC}"
        fi
        echo

        echo -e "${YELLOW}Attempting to remove file2.txt...${NC}"
        echo -e "${CYAN}\$ rm checkout-composefs/file2.txt${NC}"
        if rm checkout-composefs/file2.txt 2>/dev/null; then
            echo -e "${RED}✓ SUCCESS: File was deleted!${NC}"
        else
            echo -e "${GREEN}✗ FAILED: Cannot delete files (read-only filesystem)${NC}"
        fi

        echo -e "\n${GREEN}CONCLUSION: Composefs provides complete immutability - FULLY SECURE!${NC}"
        echo -e "${GREEN}The filesystem is read-only and tamperproof with cryptographic verification${NC}\n"

        # Unmount
        echo -e "${YELLOW}Unmounting...${NC}"
        run umount checkout-composefs
    else
        echo -e "${RED}✗ Failed to mount composefs${NC}"
        echo -e "${YELLOW}Trying with fusermount...${NC}"
        # Try FUSE3 mount as fallback
        if fusermount3 -u checkout-composefs 2>/dev/null || fusermount -u checkout-composefs 2>/dev/null; then
            echo -e "${YELLOW}(cleanup successful)${NC}"
        fi
        echo -e "${YELLOW}Your kernel: $(uname -r)${NC}"
        echo -e "${YELLOW}Note: You may need: sudo dnf install composefs${NC}"
    fi
else
    echo -e "${RED}✗ Could not create composefs image${NC}"
    echo -e "${YELLOW}Install with: sudo dnf install composefs${NC}"
fi

pause

echo -e "\n${BLUE}=== Demo Complete ===${NC}"
echo -e "${YELLOW}To cleanup, run: rm -rf demo-repo checkout-* staging objects.cfs${NC}"
