# Bulletproof Rollback: Quick Start Guide

**Run these commands on Jarvis's Mac BEFORE making any integration changes.**

---

## 🛡️ Step 1: Download & Run Backup Script

### From GitHub (Recommended)

```bash
# Clone the repo if you haven't already
cd ~
git clone git@github.com:richardpiasentintest-lgtm/jarvischatgpt.git
cd jarvischatgpt

# Copy backup script to home directory
cp BULLETPROOF_ROLLBACK.sh ~

# Make executable
chmod +x ~/BULLETPROOF_ROLLBACK.sh

# Run the backup
~/BULLETPROOF_ROLLBACK.sh
```

### Manual Creation (If needed)

If you don't have the script yet, create it:

```bash
# Download from the working folder or copy the script manually
# Then:
chmod +x ~/BULLETPROOF_ROLLBACK.sh
~/BULLETPROOF_ROLLBACK.sh
```

---

## 📋 What the Backup Captures

The script backs up:
- ✅ OpenClaw configuration (`openclaw.json`)
- ✅ All workspace files (SOUL.md, MEMORY.md, USER.md, HEARTBEAT.md)
- ✅ Complete memory directory (all daily logs)
- ✅ All scripts in workspace/scripts
- ✅ Credentials and API keys
- ✅ Agent configurations
- ✅ Crontab (scheduled tasks)
- ✅ Environment variables
- ✅ System state snapshot

**Backup location:** `~/.openclaw_backup_YYYYMMDD_HHMMSS/`

---

## 🔄 Step 2: Test the Restore Script

**CRITICAL:** Test that restore works BEFORE making changes!

```bash
# Find your backup directory
BACKUP_DIR=$(ls -td ~/.openclaw_backup_* | head -1)
echo "Latest backup: $BACKUP_DIR"

# Test the restore script syntax (doesn't actually restore)
bash -n "$BACKUP_DIR/RESTORE.sh"

# If no errors, the script is valid
echo "Restore script validated ✓"
```

---

## 🚨 Step 3: Emergency Restore Process

If anything goes wrong with the ChatGPT integration:

### Quick Restore (One Command)

```bash
# Find latest backup
BACKUP_DIR=$(ls -td ~/.openclaw_backup_* | head -1)

# Run restore script
"$BACKUP_DIR/RESTORE.sh"

# Follow prompts (type "yes" to confirm)
```

### Manual Restore (If script fails)

```bash
# 1. Stop OpenClaw
openclaw stop

# 2. Find your backup
BACKUP_DIR=$(ls -td ~/.openclaw_backup_* | head -1)
echo "Using backup: $BACKUP_DIR"

# 3. Restore configuration
cp "$BACKUP_DIR/openclaw.json" ~/.openclaw/

# 4. Restore workspace
cp -r "$BACKUP_DIR/workspace/"* ~/.openclaw/workspace/

# 5. Restore credentials
cp -r "$BACKUP_DIR/credentials" ~/.openclaw/

# 6. Remove ChatGPT integration
rm -rf ~/.openclaw/integrations/chatgpt

# 7. Restart
openclaw restart

# 8. Verify
openclaw status
```

---

## 📊 Verification Commands

After restore, verify everything works:

```bash
# Check OpenClaw status
openclaw status

# Verify configuration
cat ~/.openclaw/openclaw.json | jq '.agents.defaults.model'

# Check workspace files
ls -lh ~/.openclaw/workspace/{SOUL,MEMORY,USER,HEARTBEAT}.md

# Test Jarvis
# Send a test message and verify personality is intact
```

---

## 🎯 Pre-Flight Checklist

Before proceeding with ChatGPT integration:

- [ ] Backup script executed successfully
- [ ] Backup directory created (`~/.openclaw_backup_*`)
- [ ] Restore script validated (`bash -n RESTORE.sh` passed)
- [ ] Verified backup contains all critical files
- [ ] Tested one manual file restore to confirm process works
- [ ] Documented backup location in safe place

---

## 📁 Backup Management

### List All Backups

```bash
ls -lhd ~/.openclaw_backup_*
```

### View Backup Contents

```bash
BACKUP_DIR=$(ls -td ~/.openclaw_backup_* | head -1)
tree "$BACKUP_DIR"
# Or without tree:
find "$BACKUP_DIR" -type f
```

### Clean Up Old Backups (After Integration is Stable)

```bash
# Keep only the 3 most recent backups
cd ~
ls -td .openclaw_backup_* | tail -n +4 | xargs rm -rf

# Or remove a specific backup
rm -rf ~/.openclaw_backup_20260211_120000
```

---

## 🔐 Backup Security

Your backup contains sensitive data:

```bash
# Verify backup permissions (should be private)
ls -ld ~/.openclaw_backup_*
# Should show: drwx------  (700)

# If not, fix permissions:
chmod 700 ~/.openclaw_backup_*
chmod 600 ~/.openclaw_backup_*/*
```

---

## 💾 Additional Safety: Create Archive

For extra safety, create a compressed archive:

```bash
# Create dated archive
BACKUP_DIR=$(ls -td ~/.openclaw_backup_* | head -1)
tar -czf ~/Desktop/jarvis_backup_$(date +%Y%m%d).tar.gz "$BACKUP_DIR"

# Verify archive
tar -tzf ~/Desktop/jarvis_backup_$(date +%Y%m%d).tar.gz | head -20

echo "Archive created on Desktop ✓"
```

Store this archive somewhere safe (external drive, encrypted cloud storage).

---

## 🧪 Testing Restore (Dry Run)

To test restore without actually changing anything:

```bash
# Create a test environment
mkdir -p ~/jarvis_restore_test/.openclaw

# Copy current state to test location
cp -r ~/.openclaw ~/jarvis_restore_test/

# Modify the restore script to use test location
# Then run it to verify the process works
# (Advanced users only)
```

---

## 🆘 Emergency Contact Sheet

If restore fails and you need help:

1. **Don't panic** - your data is backed up
2. **Stop OpenClaw:** `openclaw stop`
3. **Check backup integrity:** Verify files exist in backup dir
4. **Manual restore:** Follow "Manual Restore" steps above
5. **Check logs:** `tail -50 ~/.openclaw/logs/*.log`
6. **Restart fresh:** `openclaw restart`

---

## ✅ Success Criteria

Restore is successful when:

- ✅ OpenClaw starts without errors (`openclaw status` shows running)
- ✅ Jarvis responds with correct personality (test with WhatsApp message)
- ✅ All workspace files are present (SOUL.md, MEMORY.md, etc.)
- ✅ Memory files are accessible
- ✅ Scheduled tasks work (crontab -l shows jobs)
- ✅ No ChatGPT integration files remain

---

## 🎓 Best Practices

1. **Always backup before major changes**
2. **Test restore process at least once**
3. **Keep backups until integration is stable (1-2 weeks)**
4. **Document any manual configuration changes**
5. **Create archive for long-term storage**
6. **Label backups with purpose** (e.g., rename to include "pre_chatgpt")

---

## Quick Reference Commands

```bash
# Create backup
~/BULLETPROOF_ROLLBACK.sh

# Find latest backup
ls -td ~/.openclaw_backup_* | head -1

# Restore from latest
$(ls -td ~/.openclaw_backup_* | head -1)/RESTORE.sh

# Verify OpenClaw after restore
openclaw status && echo "✓ Running"

# Check personality
cat ~/.openclaw/workspace/SOUL.md
```

---

**You're now protected! Proceed with confidence. 🦞**
