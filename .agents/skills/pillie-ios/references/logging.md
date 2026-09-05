# Logging

Use these when the thing under inspection is stdout or OSLog, not for routine verify.

- Blocking console (waits until the app exits): `make console`
- Capture to a file:

```bash
UDID=$(make -s udid)
xcrun simctl launch --terminate-running-process --console "$UDID" com.idrisskone.pillie > /tmp/pillie_console.log 2>&1
```

- Filtered OSLog:

```bash
UDID=$(make -s udid)
xcrun simctl spawn "$UDID" log stream \
  --predicate 'subsystem == "com.idrisskone.pillie"' \
  --level debug
```

`make console` and `simctl launch --console` block. Headless `make run` / `make build-and-run` return after the PID.
