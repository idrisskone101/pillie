# Namespace Connect fallback

Use this only if `Pillie/scripts/namespace-mac.sh` is missing or broken. Prefer the script.

`NSC_TOKEN` is a raw bearer. Write `{"bearer_token":"<NSC_TOKEN>"}` to `NSC_TOKEN_FILE` and never print it.

Headers for every RPC:

```
Authorization: Bearer <token>
Content-Type: application/json
Connect-Protocol-Version: 1
```

Python `urllib` is blocked by Cloudflare (HTTP 1010). Use `curl`.

## DevBoxService

Base: `https://private-api.global.namespaceapis.com`

Service: `namespace.private.devbox.v1beta.DevBoxService`

| Method | Body |
| --- | --- |
| `List` | `{}` |
| `Fetch` | `{"name":"pillie-ios","includeSshCredentials":true,"returnActivatedInstance":true}` |
| `Update` | `{"name":"pillie-ios","instanceShape":{"os":"macos","machineArch":"arm64","virtualCpu":6,"memoryMegabytes":14336,"selectors":[{"name":"macos.version","value":"27.x"}]}}` |
| `Activate` | `{"name":"pillie-ios","includeSshCredentials":true,"waitForReadiness":true}` (15 min timeout) |
| `Stop` | `{"name":"pillie-ios"}` |

`Fetch` without a running instance has no `instanceId`. That is stopped, not missing. The Devbox record stays after Stop.

If `instanceShape.selectors` includes `macos.purpose=githubrunner`, `Update` the shape above **before** Activate. That image is a GitHub runner, not this Devbox.

Do not call `Expire`. Do not `Create` a second Devbox.

## ComputeService

Base: `https://us.compute.namespaceapis.com` (fall back to `private-api.global` then `private-api.iad`)

Service: `namespace.cloud.compute.v1beta.ComputeService`

| Method | Body |
| --- | --- |
| `DescribeInstance` | `{"instanceId":"<id>"}` |
| `GetSSHConfig` | `{"instanceId":"<id>"}` |

`GetSSHConfig` returns `username` (the instance id), `endpoint` (`ssh.iad4.namespace.so`), and `sshPrivateKey` (bytes / base64). Write the key mode `600` and SSH with:

```bash
ssh -i <key> -o IdentitiesOnly=yes -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  <instanceId>@ssh.iad4.namespace.so
```

Do not use `nsc ssh`, `nsc proxy`, or a `ProxyCommand` to `hsvc.unixsocket?name=agent`.

## Identity

- Name: `pillie-ios`
- Id: `2jr7kuslpli14`
- Site: `iad`
- Checkout: `/Users/runner/workspaces/pillie`
- Guest user: `runner`
- Labels when real: `nsc.purpose=devbox`, `devbox.id=2jr7kuslpli14`
- Gateway services: `ssh`, `vnc`
