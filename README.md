# OSTree + Composefs Security Demo

This demo shows the progression of security models for filesystem deployments using OSTree, from fully mutable regular checkouts to cryptographically verified immutable composefs mounts.

## What This Demo Shows

Three security levels:
1. **Regular OSTree checkout** - Fully mutable, no security protection
2. **OSTree with fs-verity** - Content integrity protection (but metadata and structure can still change)
3. **OSTree with composefs** - Complete immutability with cryptographic verification

## Prerequisites

- Automotive Image Builder (aib)
- QEMU runtime (air)

## Building the VM Image

```bash
./build.sh
```

This will create `developer.x86_64.img` (or `developer.aarch64.img` on ARM systems).

## Running the VM

```bash
air --nographics developer.x86_64.img
```

### Login Credentials

- **Root**: username `root`, password `password`
- **Guest**: username `guest`, password `password`

⚠️ **Note**: These are weak default passwords for demo purposes only!

## Running the Demo

Once logged into the VM:

```bash
ostree-composefs-demo
```

The demo will walk through each security model interactively. Press ENTER at each pause point to continue.

After the demo, you can see/show the content of the composefs file via the command:

```bash
composefs-info dump checkout-composefs-staging/metadata.cfs
```

### What the Demo Tests

For each security model, the demo attempts to:
- Modify file content
- Change file permissions (chmod)
- Add new files
- Delete existing files

Watch how each security model responds differently to these attempts.

## Demo Structure

- **Step 1-3**: Setup - Creates OSTree repo and commits sample files
- **Demo 1**: Regular checkout shows everything is mutable
- **Demo 2**: fs-verity shows content protection (but metadata/structure changes allowed)
- **Demo 3**: composefs shows complete immutability

## Files in This Repo

- `ostree-composefs-demo.sh` - The demo script
- `developer.aib.yml` - Image configuration for Automotive Image Builder
- `build.sh` - Script to build the VM image

## Cleanup

The demo script automatically cleans up temporary files. If you need to manually clean up:

```bash
rm -rf demo-repo checkout-* staging objects.cfs
```
