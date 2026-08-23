---
name: add-bareos-version
description: Add a new Bareos version directory (Dockerfile + docker-entrypoint.sh) for a given component and flavor (alpine|ubuntu). Use when the user asks to add support for Bareos N-ubuntu or N-alpine, or fill missing version/flavor combos. Also use when the user types "add Bareos 22 ubuntu" or "generate missing Bareos versions".
allowed-tools: [Read, Write, Edit, Glob, Grep, Bash]
---

# add-bareos-version skill

Generates missing Bareos Docker image directories.

## Upstream source table

See `references/upstream-sources.md` for the authoritative mapping of Bareos version → Alpine tag and Ubuntu repo URL. **Verify this table before generating** — do not assume; run the probe commands in that file if unsure.

## Workflow

### 1. Resolve inputs

Accept: a list of `{component, version, flavor}` tuples. Examples:

- "Add 22-ubuntu for all standard components" → four tuples: director-pgsql, storage, client, webui, each with version=22, flavor=ubuntu
- "Generate client/23-alpine" → one tuple

**Standard components** = director-pgsql, storage, client, webui. The api component uses a pip-pinned pattern; handle it separately only if explicitly requested.

### 2. Look up upstream source

From `references/upstream-sources.md`:

- If the version has no upstream source for the requested flavor → stop and tell the user what's missing.
- If the source is marked `current/` → note that the image will install whatever Bareos is current (as of the build date, not the directory name).

### 3. Find the reference template

Find the nearest existing directory with the **same component** and **same flavor**:

- Same component, closest version, same flavor (e.g. for client/22-ubuntu, reference is client/21-ubuntu)
- Read its `Dockerfile` and `docker-entrypoint.sh` in full — use these as the basis for the new files

### 4. Generate the Dockerfile and entrypoint

Write the new `Dockerfile` and `docker-entrypoint.sh` directly, adapting the reference template with:

- The target directory name (e.g. `client/22-ubuntu`)
- The FROM change: e.g. `FROM ubuntu:jammy` (Ubuntu 22.04)
- The BAREOS_KEY and BAREOS_REPO values from the upstream sources table
- Any differences in how the gpg key is handled between v21 and v22+ style (see below)

### 5. Write files

```bash
mkdir -p <component>/<version>-<flavor>
# Write Dockerfile
# Write docker-entrypoint.sh
chmod +x <component>/<version>-<flavor>/docker-entrypoint.sh
```

### 6. Validate one representative build

Run `docker build --check` (or `docker build --platform linux/amd64 --no-cache -t test-bareos:local .`) from inside the new directory. If it fails, fix the Dockerfile/entrypoint directly and rebuild.

Do not attempt to build all generated dirs in one pass — do one, verify, then continue.

### 7. Report

State what was generated, which tuples were skipped (upstream not found), whether the test build passed.

## Ubuntu key handling difference

- v20–21 (old style): `curl -Ls $BAREOS_KEY -o /tmp/bareos.key` then `apt-key add /tmp/bareos.key`
- v22+ (new style): `curl -Ls $BAREOS_KEY | gpg --dearmor -o /usr/share/keyrings/bareos.gpg` then `[signed-by=/usr/share/keyrings/bareos.gpg]` in sources.list

When generating v22-ubuntu, ensure the reference (v21-ubuntu old style) is adapted to the new gpg style shown in v24-ubuntu.
