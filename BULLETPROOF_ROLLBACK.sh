#!/bin/bash
# Bulletproof Rollback Script for Jarvis
# Creates comprehensive backups before ChatGPT integration
# Run this BEFORE making any changes

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

BACKUP_DIR="$HOME/.openclaw_backup_$(date +%Y%m%d_%H%M%S)"
RESTORE_SCRIPT="$BACKUP_DIR/RESTORE.sh"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  JARVIS BULLETPROOF BACKUP${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${GREEN}Backup directory:${NC} $BACKUP_DIR"
echo ""

# Create backup directory
mkdir -p "$BACKUP_DIR"

echo -e "${BLUE}[1/8] Backing up OpenClaw configuration...${NC}"
if [ -f ~/.openclaw/openclaw.json ]; then
    cp ~/.openclaw/openclaw.json "$BACKUP_DIR/"
    echo -e "${GREEN}✓${NC} openclaw.json backed up"
else
    echo -e "${YELLOW}⚠${NC} openclaw.json not found (may not exist yet)"
fi

echo ""
echo -e "${BLUE}[2/8] Backing up workspace files...${NC}"
if [ -d ~/.openclaw/workspace ]; then
    # Backup critical workspace files
    mkdir -p "$BACKUP_DIR/workspace"
    for file in SOUL.md MEMORY.md USER.md HEARTBEAT.md TOOLS.md; do
        if [ -f ~/.openclaw/workspace/$file ]; then
            cp ~/.openclaw/workspace/$file "$BACKUP_DIR/workspace/"
            echo -e "${GREEN}✓${NC} $file backed up"
        else
            echo -e "${YELLOW}⚠${NC} $file not found"
        fi
    done

    # Backup entire memory directory
    if [ -d ~/.openclaw/workspace/memory ]; then
        cp -r ~/.openclaw/workspace/memory "$BACKUP_DIR/workspace/"
        echo -e "${GREEN}✓${NC} Memory directory backed up"
    fi

    # Backup scripts directory
    if [ -d ~/.openclaw/workspace/scripts ]; then
        cp -r ~/.openclaw/workspace/scripts "$BACKUP_DIR/workspace/"
        echo -e "${GREEN}✓${NC} Scripts directory backed up"
    fi
else
    echo -e "${YELLOW}⚠${NC} Workspace directory not found"
fi

echo ""
echo -e "${BLUE}[3/8] Backing up credentials...${NC}"
if [ -d ~/.openclaw/credentials ]; then
    cp -r ~/.openclaw/credentials "$BACKUP_DIR/"
    echo -e "${GREEN}✓${NC} Credentials backed up"
else
    echo -e "${YELLOW}⚠${NC} No credentials directory found"
fi

echo ""
echo -e "${BLUE}[4/8] Backing up agent configurations...${NC}"
if [ -d ~/.openclaw/agents ]; then
    cp -r ~/.openclaw/agents "$BACKUP_DIR/"
    echo -e "${GREEN}✓${NC} Agent configs backed up"
fi

echo ""
echo -e "${BLUE}[5/8] Backing up cron jobs...${NC}"
crontab -l > "$BACKUP_DIR/crontab_backup.txt" 2>/dev/null || echo -e "${YELLOW}⚠${NC} No crontab found"
if [ -f "$BACKUP_DIR/crontab_backup.txt" ]; then
    echo -e "${GREEN}✓${NC} Crontab backed up"
fi

echo ""
echo -e "${BLUE}[6/8] Backing up environment variables...${NC}"
if [ -f ~/.openclaw/.env ]; then
    cp ~/.openclaw/.env "$BACKUP_DIR/"
    echo -e "${GREEN}✓${NC} .env file backed up"
fi

echo ""
echo -e "${BLUE}[7/8] Creating system state snapshot...${NC}"
cat > "$BACKUP_DIR/system_state.txt" << EOF
Backup Created: $(date)
Hostname: $(hostname)
User: $(whoami)
OpenClaw Version: $(openclaw --version 2>/dev/null || echo "Unknown")
Python Version: $(python3 --version 2>/dev/null || echo "Unknown")
Shell: $SHELL

OpenClaw Status:
$(openclaw status 2>/dev/null || echo "Unable to get status")

Installed Skills:
$(clawhub list 2>/dev/null || echo "Unable to list skills")

Gateway Status:
$(lsof -i :18789 2>/dev/null | grep LISTEN || echo "Gateway not running")
EOF
echo -e "${GREEN}✓${NC} System state captured"

echo ""
echo -e "${BLUE}[8/8] Creating restore script...${NC}"

cat > "$RESTORE_SCRIPT" << 'RESTORE_EOF'
#!/bin/bash
# RESTORE SCRIPT - Returns Jarvis to pre-ChatGPT integration state
# Generated automatically during backup

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

BACKUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${RED}========================================${NC}"
echo -e "${RED}  JARVIS RESTORE FROM BACKUP${NC}"
echo -e "${RED}========================================${NC}"
echo ""
echo -e "${YELLOW}This will restore Jarvis to its pre-integration state.${NC}"
echo -e "${YELLOW}Backup location: $BACKUP_DIR${NC}"
echo ""
read -p "Are you sure you want to continue? (yes/no): " -r
echo

if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Restore cancelled."
    exit 1
fi

echo ""
echo -e "${BLUE}Starting restore...${NC}"
echo ""

# Stop OpenClaw
echo -e "${BLUE}[1/7] Stopping OpenClaw...${NC}"
openclaw stop 2>/dev/null || echo -e "${YELLOW}OpenClaw not running${NC}"
sleep 2

# Restore configuration
echo -e "${BLUE}[2/7] Restoring openclaw.json...${NC}"
if [ -f "$BACKUP_DIR/openclaw.json" ]; then
    cp "$BACKUP_DIR/openclaw.json" ~/.openclaw/
    echo -e "${GREEN}✓${NC} Configuration restored"
else
    echo -e "${RED}✗${NC} No backup found for openclaw.json"
fi

# Restore workspace files
echo -e "${BLUE}[3/7] Restoring workspace files...${NC}"
if [ -d "$BACKUP_DIR/workspace" ]; then
    cp -r "$BACKUP_DIR/workspace/"* ~/.openclaw/workspace/
    echo -e "${GREEN}✓${NC} Workspace restored"
else
    echo -e "${RED}✗${NC} No workspace backup found"
fi

# Restore credentials
echo -e "${BLUE}[4/7] Restoring credentials...${NC}"
if [ -d "$BACKUP_DIR/credentials" ]; then
    cp -r "$BACKUP_DIR/credentials" ~/.openclaw/
    echo -e "${GREEN}✓${NC} Credentials restored"
fi

# Restore agent configs
echo -e "${BLUE}[5/7] Restoring agent configurations...${NC}"
if [ -d "$BACKUP_DIR/agents" ]; then
    cp -r "$BACKUP_DIR/agents" ~/.openclaw/
    echo -e "${GREEN}✓${NC} Agent configs restored"
fi

# Restore crontab
echo -e "${BLUE}[6/7] Restoring crontab...${NC}"
if [ -f "$BACKUP_DIR/crontab_backup.txt" ]; then
    crontab "$BACKUP_DIR/crontab_backup.txt"
    echo -e "${GREEN}✓${NC} Crontab restored"
fi

# Clean up ChatGPT integration files
echo -e "${BLUE}[7/7] Removing ChatGPT integration files...${NC}"
if [ -d ~/.openclaw/integrations/chatgpt ]; then
    rm -rf ~/.openclaw/integrations/chatgpt
    echo -e "${GREEN}✓${NC} ChatGPT integration removed"
fi

# Restart OpenClaw
echo ""
echo -e "${BLUE}Restarting OpenClaw...${NC}"
openclaw restart

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  RESTORE COMPLETE${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${GREEN}Jarvis has been restored to its pre-integration state.${NC}"
echo ""
echo -e "System state before integration:"
cat "$BACKUP_DIR/system_state.txt"
echo ""
echo -e "${BLUE}Backup preserved at:${NC} $BACKUP_DIR"
echo -e "${YELLOW}Keep this backup until you're confident the integration is stable.${NC}"
echo ""
RESTORE_EOF

chmod +x "$RESTORE_SCRIPT"
echo -e "${GREEN}✓${NC} Restore script created: $RESTORE_SCRIPT"

# Calculate backup size
BACKUP_SIZE=$(du -sh "$BACKUP_DIR" | cut -f1)

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  BACKUP COMPLETE${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${BLUE}Backup location:${NC} $BACKUP_DIR"
echo -e "${BLUE}Backup size:${NC} $BACKUP_SIZE"
echo -e "${BLUE}Restore script:${NC} $RESTORE_SCRIPT"
echo ""
echo -e "${GREEN}Files backed up:${NC}"
ls -lh "$BACKUP_DIR" | grep -v "^total" | awk '{print "  " $9 " (" $5 ")"}'
echo ""
echo -e "${YELLOW}IMPORTANT:${NC}"
echo -e "1. Keep this backup until ChatGPT integration is stable"
echo -e "2. To restore, run: ${GREEN}$RESTORE_SCRIPT${NC}"
echo -e "3. Test the restore process before making changes:"
echo -e "   ${BLUE}# Dry run test${NC}"
echo -e "   ${GREEN}bash -n $RESTORE_SCRIPT${NC}"
echo ""
echo -e "${GREEN}You're now safe to proceed with the integration! 🦞${NC}"
echo ""
