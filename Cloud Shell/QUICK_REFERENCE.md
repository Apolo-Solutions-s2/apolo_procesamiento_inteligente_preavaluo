# Cloud Shell Quick Reference

## 🚀 After Code Changes (ONE COMMAND!)

```bash
cd ~/apolo_procesamiento_inteligente_preavaluo/Cloud\ Shell && chmod +x update_code.sh && ./update_code.sh
```

This single command will:
- Navigate to the correct directory
- Set permissions
- Pull latest code from GitHub
- Discard local Cloud Shell changes
- Redeploy the service
- Show you the results

---

## 📋 Common Commands

### Initial Setup
```bash
cd ~/apolo_procesamiento_inteligente_preavaluo/Cloud\ Shell
chmod +x *.sh
./deploy.sh
```

### Update After Code Changes
```bash
cd ~/apolo_procesamiento_inteligente_preavaluo/Cloud\ Shell
./update_code.sh
```

### Run Tests
```bash
cd ~/apolo_procesamiento_inteligente_preavaluo/Cloud\ Shell
./test_uuid_processing.sh
```

### View Logs
```bash
gcloud run services logs tail apolo-procesamiento-inteligente --region=us-south1
```

### Check Service Status
```bash
gcloud run services describe apolo-procesamiento-inteligente --region=us-south1
```

---

## 🔧 Troubleshooting

### Git merge conflicts when pulling
```bash
# This happens when you have local changes in Cloud Shell
cd ~/apolo_procesamiento_inteligente_preavaluo
git stash                    # Save local changes
git pull origin main         # Pull latest
# Or discard local changes:
git reset --hard origin/main # Discard local changes and use GitHub version
```

### Permission denied when running scripts
```bash
cd ~/apolo_procesamiento_inteligente_preavaluo/Cloud\ Shell
chmod +x *.sh               # Set execute permissions
./deploy.sh                 # Now you can run
```

### Deployment fails during Cloud Run build
```bash
# Resume from where it stopped
./deploy.sh --resume
```

### Service exists but env vars are wrong
```bash
# Update just the environment variables
./update_env_vars.sh --auto
```

---

## 📊 Check What's Deployed

### Current Git Commit
```bash
cd ~/apolo_procesamiento_inteligente_preavaluo
git log -1 --oneline
```

### Service URL
```bash
gcloud run services describe apolo-procesamiento-inteligente \
  --region=us-south1 \
  --format="value(status.url)"
```

### Environment Variables
```bash
gcloud run services describe apolo-procesamiento-inteligente \
  --region=us-south1 \
  --format="yaml(spec.template.spec.containers[0].env)"
```

---

## 🧪 Test Specific UUID

```bash
# Upload test files
UUID=$(cat /proc/sys/kernel/random/uuid)
gsutil cp test-file.pdf gs://apolo-preavaluos-pdf-dev/$UUID/
echo "" | gsutil cp - gs://apolo-preavaluos-pdf-dev/$UUID/is_ready

# Check output
gsutil ls gs://apolo-preavaluos-pdf-dev/$UUID/

# View logs for that UUID
gcloud logging read "jsonPayload.folder_uuid=\"$UUID\"" --limit=20
```