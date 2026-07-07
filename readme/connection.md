# Connection Guide (Git Bash + Script)

This guide explains how to connect to the Raspberry Pi from Git Bash and how to verify the connection by running ls remotely.

## Prerequisites

- Git for Windows (Git Bash)
- OpenSSH client available
- sshpass available
- Password file exists at ../rpiai.password
- Script exists at ./connect-rpiai.sh

## 1. Check Missing Software

Run in Git Bash:

```bash
command -v ssh >/dev/null && echo "ssh: ok" || echo "ssh: missing"
command -v sshpass >/dev/null && echo "sshpass: ok" || echo "sshpass: missing"
```

If sshpass is missing on Windows, install from PowerShell:

```powershell
winget install --id xhcoding.sshpass-win32 -e --accept-package-agreements --accept-source-agreements
```

After installation, close and reopen Git Bash.

## 2. Validate Required Files

From repo root in Git Bash:

```bash
test -f ./connect-rpiai.sh && echo "script: ok" || echo "script: missing"
test -f ../rpiai.password && echo "password file: ok" || echo "password file: missing"
```

## 3. Test Remote Command (ls)

Run:

```bash
./connect-rpiai.sh pi rpiai.local "ls"
```

Expected result: you should see directory listing output from the Raspberry Pi.

If hostname does not resolve:

```bash
./connect-rpiai.sh pi 192.168.x.x "ls"
```

## 4. Open Interactive Shell

Run:

```bash
./connect-rpiai.sh pi rpiai.local
```

Expected result: prompt similar to pi@rpiai:~ $.
