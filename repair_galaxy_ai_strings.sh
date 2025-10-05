#!/data/data/com.termux/files/usr/bin/bash

echo "[+] Starting Galaxy AI string repair..."

# Step 1: Find all XML files mentioning Galaxy AI
for f in $(grep -rl 'Galaxy AI' ~/nowbrief_injector/base/res/); do
  echo "[*] Repairing: $f"

  # Step 2: Backup original file
  cp "$f" "$f.bak"

  # Step 3: Fix unterminated quotes
  sed -i 's/="\([^"]*\)$/="\1"/' "$f"

  # Step 4: Escape ampersands (only if not already escaped)
  sed -i 's/&\([^a-zA-Z#]\)/\&amp;\1/g' "$f"

  # Step 5: Remove double quotes if accidentally duplicated
  sed -i 's/""/"/g' "$f"

  # Step 6: Run your XML balancer if available
  if [ -f ~/xmlbalance.sh ]; then
    bash ~/xmlbalance.sh "$f"
  fi
done

echo "[+] Repair complete. Validating..."

# Step 7: Validate all patched files
for f in $(grep -rl 'Galaxy AI' ~/nowbrief_injector/base/res/); do
  xmllint --noout "$f" || echo "[!] Malformed: $f"
done

echo "[✓] All Galaxy AI strings patched. Ready to rebuild."
