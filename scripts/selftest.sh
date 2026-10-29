B=/home/mathaudit/bin; id; date -Is
echo "## landrun: write outside allowed"; $B/landrun --best-effort --ro / --rw /dev -ldd -add-exec -- /bin/sh -c 'echo x > /home/mathaudit/aud/lr_test' ; echo rc=$?
mkdir -p /tmp/lrok_$$; echo "## landrun: write inside --rwx"; $B/landrun --best-effort --ro / --rw /dev --rwx /tmp/lrok_$$ -ldd -add-exec -- /bin/sh -c "echo x > /tmp/lrok_$$/f"; echo rc=$?
echo "## landrun: tcp connect"; $B/landrun --best-effort --ro / --rw /dev -ldd -add-exec -- /usr/bin/curl -sS -m 5 https://github.com -o /dev/null; echo rc=$?
echo "## restrict-af-unix"; $B/restrict-af-unix python3 -c '
import socket
try: socket.socket(socket.AF_UNIX); print("AF_UNIX ALLOWED (unexpected)")
except OSError as e: print("AF_UNIX blocked:", e)'
$B/restrict-af-unix grep -E "Seccomp|NoNewPrivs" /proc/self/status
echo "## creds reachability"; ls /workspace /home/box /root 2>&1
