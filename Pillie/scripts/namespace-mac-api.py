#!/usr/bin/env python3
"""Connect JSON client for the pillie-ios Namespace Devbox.

The Cloud Agent NSC_TOKEN is a raw bearer (nsrt_…), not a JWT. The `devbox`
CLI cannot log in with it. Talk to DevBoxService and ComputeService directly.
Do not print the token or SSH private keys.
"""

from __future__ import annotations

import argparse
import base64
import json
import os
import subprocess
import sys
import tempfile
import time
from pathlib import Path

DEVBOX_NAME = os.environ.get("PILLIE_NS_DEVBOX_NAME", "pillie-ios")
DEVBOX_API = "https://private-api.global.namespaceapis.com"
DEVBOX_SERVICE = "namespace.private.devbox.v1beta.DevBoxService"
COMPUTE_SERVICE = "namespace.cloud.compute.v1beta.ComputeService"
COMMAND_SERVICE = "namespace.cloud.compute.v1beta.CommandService"
REMOTE_PATH = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
COMPUTE_ENDPOINTS = (
    "https://us.compute.namespaceapis.com",
    "https://private-api.global.namespaceapis.com",
    "https://private-api.iad.namespaceapis.com",
)
MACOS_SHAPE = {
    "os": "macos",
    "machineArch": "arm64",
    "virtualCpu": 6,
    "memoryMegabytes": 14336,
    "selectors": [{"name": "macos.version", "value": "27.x"}],
}
ACTIVATE_TIMEOUT = int(os.environ.get("PILLIE_NS_ACTIVATE_TIMEOUT", "900"))
SPEC_IDLE = os.environ.get("PILLIE_NS_DEVBOX_IDLE", "900s")
SSH_DIR = Path(os.environ.get("PILLIE_NS_SSH_DIR", os.path.expanduser("~/.namespace/ssh")))
SSH_HOST = os.environ.get("PILLIE_NS_SSH_HOST", "pillie-ios")


def normalize_idle(value: str) -> str:
    """Protobuf Duration for Update. `15m` is invalid; the platform minimum is 900s."""
    text = (value or "").strip()
    if text in {"15m", "900s", "900.0s"}:
        return "900s"
    return text or "900s"


def idle_matches_spec(live: str, spec: str = SPEC_IDLE) -> bool:
    return normalize_idle(live) == normalize_idle(spec)


def token_path() -> Path:
    return Path(os.environ.get("NSC_TOKEN_FILE") or os.path.expanduser("~/.config/ns/token.json"))


def bearer_token() -> str:
    path = token_path()
    if path.is_file():
        data = json.loads(path.read_text(encoding="utf-8"))
        token = data.get("bearer_token") or data.get("token")
        if token:
            return str(token)
    raw = os.environ.get("NSC_TOKEN") or os.environ.get("NAMESPACE_TOKEN") or ""
    if raw:
        return raw
    raise SystemExit(
        "error: missing NSC_TOKEN. Add the Cloud Agent secret, then run "
        "Pillie/scripts/namespace-mac.sh hydrate-auth"
    )


def curl_json(url: str, body: dict, timeout: int) -> tuple[int, dict | str]:
    token = bearer_token()
    payload = json.dumps(body).encode("utf-8")
    with tempfile.NamedTemporaryFile("w", encoding="utf-8", delete=False) as header:
        header.write(f"Authorization: Bearer {token}\n")
        header_path = header.name
    try:
        os.chmod(header_path, 0o600)
        proc = subprocess.run(
            [
                "curl",
                "-sS",
                "-X",
                "POST",
                url,
                "-H",
                f"@{header_path}",
                "-H",
                "Content-Type: application/json",
                "-H",
                "Connect-Protocol-Version: 1",
                "--max-time",
                str(timeout),
                "--data-binary",
                "@-",
                "-w",
                "\n%{http_code}",
            ],
            input=payload,
            capture_output=True,
        )
    finally:
        try:
            os.unlink(header_path)
        except OSError:
            pass
    if proc.returncode != 0:
        err = (proc.stderr or b"").decode("utf-8", "replace").strip()
        raise SystemExit(f"error: curl {url} failed: {err or proc.returncode}")
    raw = proc.stdout.decode("utf-8", "replace")
    if "\n" not in raw:
        raise SystemExit(f"error: empty response from {url}")
    body_text, status_s = raw.rsplit("\n", 1)
    status = int(status_s.strip() or "0")
    if not body_text:
        return status, {}
    try:
        return status, json.loads(body_text)
    except json.JSONDecodeError:
        return status, body_text


def require_ok(status: int, payload: dict | str, url: str) -> dict:
    if status >= 200 and status < 300 and isinstance(payload, dict):
        return payload
    snippet = payload if isinstance(payload, str) else json.dumps(payload)[:800]
    raise SystemExit(f"error: {url} HTTP {status}: {snippet}")


def devbox_rpc(method: str, body: dict, timeout: int = 60) -> dict:
    url = f"{DEVBOX_API}/{DEVBOX_SERVICE}/{method}"
    status, payload = curl_json(url, body, timeout)
    return require_ok(status, payload, url)


def compute_rpc(method: str, body: dict, timeout: int = 60) -> dict:
    last_error = ""
    for base in COMPUTE_ENDPOINTS:
        url = f"{base}/{COMPUTE_SERVICE}/{method}"
        status, payload = curl_json(url, body, timeout)
        if status >= 200 and status < 300 and isinstance(payload, dict):
            return payload
        last_error = f"{url} HTTP {status}: {payload if isinstance(payload, str) else json.dumps(payload)[:400]}"
    raise SystemExit(f"error: ComputeService.{method} failed. {last_error}")


def list_devboxes() -> list[dict]:
    payload = devbox_rpc("List", {})
    return payload.get("devboxes") or payload.get("devBoxes") or []


def fetch(name: str = DEVBOX_NAME, include_ssh: bool = False) -> dict:
    return devbox_rpc(
        "Fetch",
        {
            "name": name,
            "includeSshCredentials": include_ssh,
            "returnActivatedInstance": True,
        },
    )


def dump(payload: dict) -> None:
    json.dump(redact(payload), sys.stdout, indent=2)
    sys.stdout.write("\n")


def redact(value):
    if isinstance(value, dict):
        out = {}
        for key, item in value.items():
            if key.lower() in {"privatesshkey", "sshprivatekey", "private_ssh_key", "ssh_private_key"}:
                out[key] = "<redacted>"
            else:
                out[key] = redact(item)
        return out
    if isinstance(value, list):
        return [redact(item) for item in value]
    return value


def selectors_of(devbox: dict) -> list[dict]:
    shape = (devbox or {}).get("instanceShape") or {}
    return shape.get("selectors") or []


def has_githubrunner(devbox: dict) -> bool:
    for selector in selectors_of(devbox):
        name = str(selector.get("name") or "")
        value = str(selector.get("value") or "")
        if "githubrunner" in value or name == "macos.purpose":
            return True
    return False


def cmd_list(_args: argparse.Namespace) -> int:
    dump({"devboxes": list_devboxes()})
    return 0


def cmd_fetch(_args: argparse.Namespace) -> int:
    dump(fetch())
    return 0


def apply_idle(devbox: dict) -> dict:
    live = str(devbox.get("busyEnsureMinimumDuration") or "")
    want = normalize_idle(SPEC_IDLE)
    if idle_matches_spec(live, want):
        return devbox
    print(f"applying idle {want} (live {live or '?'})")
    updated = devbox_rpc(
        "Update",
        {"name": DEVBOX_NAME, "busyEnsureMinimumDuration": want},
    )
    return updated or devbox


def cmd_ensure(_args: argparse.Namespace) -> int:
    boxes = list_devboxes()
    names = [item.get("name") for item in boxes]
    extras = [
        item.get("name")
        for item in boxes
        if item.get("name") != DEVBOX_NAME
        and ((item.get("instanceShape") or {}).get("os") == "macos")
    ]
    if DEVBOX_NAME not in names:
        raise SystemExit(
            f"error: Devbox {DEVBOX_NAME} is missing ({names or 'none listed'}). "
            "Do not create another Mac. Personal workspaces are limited to one Devbox."
        )
    if extras:
        raise SystemExit(
            f"error: found other macOS Devboxes ({', '.join(extras)}). Keep exactly one: {DEVBOX_NAME}."
        )
    payload = fetch()
    devbox = payload.get("devbox") or {}
    if has_githubrunner(devbox):
        print(f"warn: {DEVBOX_NAME} has macos.purpose=githubrunner; updating to macos.version=27.x", file=sys.stderr)
        dump(devbox_rpc("Update", {"name": DEVBOX_NAME, "instanceShape": MACOS_SHAPE}))
        payload = fetch()
        devbox = payload.get("devbox") or {}
    devbox = apply_idle(devbox)
    payload = fetch()
    devbox = payload.get("devbox") or {}
    instance_id = payload.get("instanceId") or ""
    idle = devbox.get("busyEnsureMinimumDuration") or "?"
    print(f"ok: {DEVBOX_NAME} exists id={devbox.get('id')} instance={instance_id or 'stopped'} idle={idle}")
    return 0


def cmd_status(_args: argparse.Namespace) -> int:
    payload = fetch()
    devbox = payload.get("devbox") or {}
    shape = devbox.get("instanceShape") or {}
    selectors = [f"{s.get('name')}={s.get('value')}" for s in selectors_of(devbox)]
    instance_id = payload.get("instanceId") or ""
    print(f"name: {devbox.get('name')}")
    print(f"id: {devbox.get('id')}")
    print(f"site: {devbox.get('site')}")
    print(f"os: {shape.get('os')} {shape.get('machineArch')} {shape.get('virtualCpu')}vcpu {shape.get('memoryMegabytes')}MB")
    print(f"selectors: {', '.join(selectors) or '-'}")
    print(f"idle: {devbox.get('busyEnsureMinimumDuration') or '?'}")
    print(f"volume: {devbox.get('volumeSizeGb')} GiB")
    print(f"repo: {devbox.get('repository')}")
    print(f"user: {devbox.get('mainUser')}")
    print(f"workspace: {devbox.get('workspaceDir')}")
    print(f"instance: {instance_id or 'stopped'}")
    if has_githubrunner(devbox):
        print("warn: githubrunner selector is set; start will Update the shape first")
    return 0


def wait_for_instance(timeout: int) -> str:
    deadline = time.time() + timeout
    last = {}
    while time.time() < deadline:
        last = fetch()
        instance_id = last.get("instanceId") or ""
        if instance_id:
            return instance_id
        time.sleep(5)
    dump(last)
    raise SystemExit(f"error: {DEVBOX_NAME} did not return an instanceId within {timeout}s")


def cmd_activate(_args: argparse.Namespace) -> int:
    current = fetch()
    instance_id = current.get("instanceId") or ""
    if instance_id:
        print(f"ok: {DEVBOX_NAME} already running instance={instance_id}")
        return 0
    print(f"activating {DEVBOX_NAME} (wait up to {ACTIVATE_TIMEOUT}s)...")
    try:
        payload = devbox_rpc(
            "Activate",
            {
                "name": DEVBOX_NAME,
                "includeSshCredentials": True,
                "waitForReadiness": True,
            },
            timeout=ACTIVATE_TIMEOUT,
        )
        instance_id = payload.get("instanceId") or ""
    except SystemExit as err:
        print(f"warn: Activate RPC: {err}", file=sys.stderr)
        instance_id = ""
    if not instance_id:
        instance_id = wait_for_instance(ACTIVATE_TIMEOUT)
    print(f"ok: {DEVBOX_NAME} instance={instance_id}")
    return 0


def cmd_stop(_args: argparse.Namespace) -> int:
    payload = devbox_rpc("Stop", {"name": DEVBOX_NAME})
    instance_id = payload.get("instanceId") or ""
    print(f"ok: stopped {DEVBOX_NAME}" + (f" instance={instance_id}" if instance_id else ""))
    return 0


def decode_key(value) -> bytes:
    if value is None:
        return b""
    if isinstance(value, bytes):
        return value
    if isinstance(value, dict):
        # Connect JSON sometimes serializes bytes as { "0": 45, ... }
        try:
            return bytes(int(value[str(i)]) for i in range(len(value)))
        except (KeyError, ValueError, TypeError):
            return b""
    if isinstance(value, list):
        return bytes(int(item) for item in value)
    text = str(value)
    if "BEGIN" in text:
        return text.encode("utf-8")
    pad = "=" * (-len(text) % 4)
    try:
        return base64.b64decode(text + pad)
    except (ValueError, TypeError):
        return text.encode("utf-8")


def split_endpoint(endpoint: str) -> tuple[str, str]:
    host = endpoint or "ssh.iad4.namespace.so"
    port = "22"
    if "://" in host:
        host = host.split("://", 1)[1]
    if ":" in host:
        host, port = host.rsplit(":", 1)
    return host, port


def write_ssh_files(instance_id: str, endpoint: str, key: bytes) -> Path:
    if not key.strip():
        raise SystemExit("error: GetSSHConfig returned an empty private key")
    SSH_DIR.mkdir(parents=True, exist_ok=True)
    key_path = SSH_DIR / f"{SSH_HOST}.instance.key"
    config_path = SSH_DIR / f"{SSH_HOST}.config"
    key_path.write_bytes(key if key.endswith(b"\n") else key + b"\n")
    os.chmod(key_path, 0o600)
    host, port = split_endpoint(endpoint)
    config_path.write_text(
        "\n".join(
            [
                f"Host {SSH_HOST}",
                f"  HostName {host}",
                f"  Port {port}",
                f"  User {instance_id}",
                f"  IdentityFile {key_path}",
                "  IdentitiesOnly yes",
                "  StrictHostKeyChecking no",
                "  UserKnownHostsFile /dev/null",
                "  ServerAliveInterval 30",
                "  ServerAliveCountMax 10",
                f"  ControlMaster auto",
                f"  ControlPath {SSH_DIR}/{SSH_HOST}.ctl",
                "  ControlPersist 1800",
                "",
            ]
        ),
        encoding="utf-8",
    )
    os.chmod(config_path, 0o600)
    print(f"ok: wrote {config_path} user={instance_id} host={host}")
    return config_path


def cmd_write_ssh(_args: argparse.Namespace) -> int:
    payload = fetch()
    instance_id = payload.get("instanceId") or ""
    if not instance_id:
        raise SystemExit(f"error: {DEVBOX_NAME} is stopped; start it before writing SSH config")
    ssh = compute_rpc("GetSSHConfig", {"instanceId": instance_id})
    username = ssh.get("username") or instance_id
    write_ssh_files(username, ssh.get("endpoint") or "", decode_key(ssh.get("sshPrivateKey")))
    print(username)
    return 0


def cmd_instance(_args: argparse.Namespace) -> int:
    instance_id = fetch().get("instanceId") or ""
    if not instance_id:
        raise SystemExit("stopped")
    print(instance_id)
    return 0


def running_instance_id() -> str:
    instance_id = fetch().get("instanceId") or ""
    if not instance_id:
        raise SystemExit(f"error: {DEVBOX_NAME} is stopped; run activate first")
    return instance_id


def run_sync(
    instance_id: str, argv: list[str], timeout: int, cwd: str = "", env: dict[str, str] | None = None
) -> tuple[bytes, bytes, int]:
    command: dict = {"command": argv}
    if cwd:
        command["cwd"] = cwd
    # The command agent starts commands with an empty PATH.
    env = {"PATH": REMOTE_PATH, **(env or {})}
    command["envVars"] = [{"name": k, "value": v} for k, v in env.items()]
    payload = compute_command_rpc(
        "RunCommandSync", {"instanceId": instance_id, "command": command}, timeout=timeout
    )
    return (
        base64.b64decode(payload.get("stdout") or ""),
        base64.b64decode(payload.get("stderr") or ""),
        int(payload.get("exitCode") or 0),
    )


# RunCommandSync kills the command's process group when it returns, so a
# long job runs in its own session and is polled through its log file.
STREAM_LAUNCHER = """
import json, os, subprocess
waiter = '''
import json, os, subprocess
base = os.environ["NSX_BASE"]
with open(base + ".log", "wb") as log:
    rc = subprocess.call(json.loads(os.environ["NSX_ARGV"]), stdin=subprocess.DEVNULL, stdout=log, stderr=subprocess.STDOUT)
with open(base + ".rc.tmp", "w") as fh:
    fh.write(str(rc))
os.rename(base + ".rc.tmp", base + ".rc")
'''
subprocess.Popen(["/usr/bin/python3", "-c", waiter], start_new_session=True,
                 stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
"""

# Read .rc before the log: once .rc exists the log is complete.
STREAM_POLL = 'cat "$NSX_BASE.rc" >&2 2>/dev/null; tail -c +"$((NSX_OFFSET + 1))" "$NSX_BASE.log" 2>/dev/null; true'


def run_streamed(instance_id: str, argv: list[str], timeout: int, cwd: str, poll: float) -> int:
    base = f"/tmp/nsx-{int(time.time())}-{os.getpid()}"
    env = {"NSX_BASE": base, "NSX_ARGV": json.dumps(argv)}
    if cwd:
        env["NSX_ARGV"] = json.dumps(["/bin/bash", "-c", 'cd "$1" && shift && exec "$@"', "nsx", cwd, *argv])
    _, err, rc = run_sync(instance_id, ["/usr/bin/python3", "-c", STREAM_LAUNCHER], 60, env=env)
    if rc != 0:
        sys.stderr.buffer.write(err)
        raise SystemExit(f"error: could not start remote job (exit {rc})")
    offset = 0
    deadline = time.monotonic() + timeout
    while True:
        out, err, _ = run_sync(
            instance_id, ["/bin/bash", "-c", STREAM_POLL], 120,
            env={"NSX_BASE": base, "NSX_OFFSET": str(offset)},
        )
        if out:
            sys.stdout.buffer.write(out)
            sys.stdout.flush()
            offset += len(out)
        done = err.decode("utf-8", "replace").strip()
        if done:
            run_sync(instance_id, ["/bin/rm", "-f", f"{base}.log", f"{base}.rc"], 60)
            return int(done)
        if time.monotonic() > deadline:
            raise SystemExit(f"error: remote job still running after {timeout}s (log {base}.log)")
        time.sleep(poll)


def cmd_exec(args: argparse.Namespace) -> int:
    """Run argv in the macOS guest over HTTPS (CommandService.RunCommandSync).

    Cloud Agent sandboxes block outbound port 22, so this is the exec path
    when SSH cannot connect. Wrap shell syntax in `/bin/bash -lc '…'`.
    --stream runs the job detached and tails its output, for builds that
    outlive one RPC.
    """
    argv = args.argv[1:] if args.argv[:1] == ["--"] else args.argv
    if not argv:
        raise SystemExit("error: exec needs a command, e.g. exec -- /bin/bash -lc 'sw_vers'")
    instance_id = running_instance_id()
    if args.stream:
        return run_streamed(instance_id, argv, args.timeout, args.cwd, args.poll)
    out, err, rc = run_sync(instance_id, argv, args.timeout, cwd=args.cwd)
    sys.stdout.buffer.write(out)
    sys.stdout.flush()
    sys.stderr.buffer.write(err)
    sys.stderr.flush()
    return rc


def cmd_download(args: argparse.Namespace) -> int:
    out, err, rc = run_sync(running_instance_id(), ["/usr/bin/base64", "-i", args.remote], 300)
    if rc != 0:
        if args.optional:
            return 0
        sys.stderr.buffer.write(err)
        raise SystemExit(f"error: could not read {args.remote} on {DEVBOX_NAME}")
    dest = Path(args.local)
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_bytes(base64.b64decode(b"".join(out.split())))
    print(f"ok: {dest}")
    return 0


def compute_command_rpc(method: str, body: dict, timeout: int) -> dict:
    errors = []
    for base in COMPUTE_ENDPOINTS:
        url = f"{base}/{COMMAND_SERVICE}/{method}"
        status, payload = curl_json(url, body, timeout)
        if status >= 200 and status < 300 and isinstance(payload, dict):
            return payload
        snippet = payload if isinstance(payload, str) else json.dumps(payload)
        errors.append(f"{base} HTTP {status}: {' '.join(snippet.split())[:300]}")
    raise SystemExit(f"error: CommandService.{method} failed.\n  " + "\n  ".join(errors))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="cmd", required=True)
    sub.add_parser("list").set_defaults(func=cmd_list)
    sub.add_parser("fetch").set_defaults(func=cmd_fetch)
    sub.add_parser("ensure").set_defaults(func=cmd_ensure)
    sub.add_parser("status").set_defaults(func=cmd_status)
    sub.add_parser("activate").set_defaults(func=cmd_activate)
    sub.add_parser("stop").set_defaults(func=cmd_stop)
    sub.add_parser("write-ssh").set_defaults(func=cmd_write_ssh)
    sub.add_parser("instance").set_defaults(func=cmd_instance)
    exec_parser = sub.add_parser("exec", help="run a command on the Mac over HTTPS, no SSH")
    exec_parser.add_argument("--cwd", default="")
    exec_parser.add_argument("--timeout", type=int, default=600)
    exec_parser.add_argument("--stream", action="store_true", help="run detached and tail output")
    exec_parser.add_argument("--poll", type=float, default=5.0)
    exec_parser.add_argument("argv", nargs=argparse.REMAINDER)
    exec_parser.set_defaults(func=cmd_exec)
    download = sub.add_parser("download", help="copy a file from the Mac over HTTPS")
    download.add_argument("--optional", action="store_true", help="skip quietly if missing")
    download.add_argument("remote")
    download.add_argument("local")
    download.set_defaults(func=cmd_download)
    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        raise SystemExit(130)
