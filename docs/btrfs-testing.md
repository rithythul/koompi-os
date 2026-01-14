# Btrfs Setup Testing Guide

## Prerequisites
- QEMU/VirtualBox virtual machine
- Empty virtual disk (20GB+ recommended)
- KOOMPI OS ISO or Arch Linux ISO with custom scripts

## Test 1: Manual Btrfs Setup Verification

### Step 1: Create Test VM
```bash
# Using QEMU
qemu-img create -f qcow2 koompi-test.qcow2 20G

qemu-system-x86_64 \
  -enable-kvm \
  -m 2048 \
  -smp 2 \
  -drive file=koompi-test.qcow2,if=virtio \
  -cdrom archlinux.iso \
  -boot d
```

### Step 2: Boot into Live Environment
1. Boot from ISO
2. Connect to network: `iwctl` or `dhcpcd`
3. Copy koompi-setup-btrfs script to `/usr/local/bin/`
4. Make it executable: `chmod +x /usr/local/bin/koompi-setup-btrfs`

### Step 3: Run Btrfs Setup
```bash
# WARNING: This will destroy all data on /dev/vda
koompi-setup-btrfs /dev/vda

# Type 'YES' when prompted
```

**Expected Output:**
```
[HH:MM:SS] Partitioning /dev/vda...
[HH:MM:SS] Partitions created successfully
[HH:MM:SS] Formatting EFI partition...
[HH:MM:SS] Formatting Btrfs partition...
[HH:MM:SS] Partitions formatted successfully
[HH:MM:SS] Creating Btrfs subvolumes...
[HH:MM:SS] Subvolumes created successfully
[HH:MM:SS] Mounting subvolumes...
[HH:MM:SS] All subvolumes mounted
[HH:MM:SS] Generating /etc/fstab...
[HH:MM:SS] fstab generated at /mnt/etc/fstab

Btrfs Setup Complete!
```

### Step 4: Verify Partition Layout
```bash
lsblk
```

**Expected:**
```
NAME        SIZE  TYPE PART
vda          20G  disk
├─vda1      512M  part      # EFI
└─vda2     19.5G  part      # Btrfs
```

### Step 5: Verify Subvolume Structure
```bash
btrfs subvolume list /mnt
```

**Expected:**
```
ID 256 gen 7 top level 5 path @
ID 257 gen 7 top level 5 path @home
ID 258 gen 7 top level 5 path @var
ID 259 gen 7 top level 5 path .snapshots
```

### Step 6: Verify Mount Points
```bash
mount | grep /mnt
```

**Expected:**
```
/dev/vda2 on /mnt type btrfs (rw,noatime,compress=zstd:1,space_cache=v2,discard=async,subvol=/@)
/dev/vda2 on /mnt/home type btrfs (rw,noatime,compress=zstd:1,space_cache=v2,discard=async,subvol=/@home)
/dev/vda2 on /mnt/var type btrfs (rw,noatime,compress=zstd:1,space_cache=v2,discard=async,subvol=/@var)
/dev/vda2 on /mnt/.snapshots type btrfs (rw,noatime,compress=zstd:1,space_cache=v2,discard=async,subvol=/.snapshots)
/dev/vda1 on /mnt/boot type vfat (rw,noatime)
```

### Step 7: Verify Mount Options
```bash
cat /mnt/etc/fstab
```

**Expected:**
- Btrfs subvolumes mounted with zstd compression
- noatime option enabled
- space_cache=v2
- discard=async (for SSD)
- Commented overlay line for /etc

### Step 8: Verify Overlay Directory Structure
```bash
ls -la /mnt/var/lib/overlay/etc/
```

**Expected:**
```
drwxr-xr-x upper
drwxr-xr-x work
```

## Test 2: Read-Only Root Mount

### After Base Installation
1. Install base system:
```bash
pacstrap /mnt base linux-lts linux-firmware btrfs-progs
```

2. Generate fstab:
```bash
genfstab -U /mnt >> /mnt/etc/fstab
```

3. Set root to read-only:
```bash
koompi-setup-btrfs --set-readonly /mnt/etc/fstab
```

4. Verify fstab changes:
```bash
cat /mnt/etc/fstab | grep "subvol=@"
```

**Expected:**
```
UUID=... / btrfs defaults,noatime,compress=zstd:1,space_cache=v2,discard=async,subvol=@,ro 0 0
```

5. Reboot and test:
```bash
# Try to create file in root
touch /test.txt
# Should fail with "Read-only file system"

# Try to create file in /etc (overlay should work)
touch /etc/test.txt
# Should succeed

# Verify overlay is working
mount | grep overlay
# Should show overlay mount for /etc
```

## Test 3: Snapshot Creation

### Create Test Snapshot
```bash
# Copy koompi-snapshot script to system
cp /path/to/koompi-snapshot /usr/local/bin/
chmod +x /usr/local/bin/koompi-snapshot

# Create snapshot
koompi-snapshot create "test-manual" Manual "Testing snapshot system"
```

**Expected:**
```
[HH:MM:SS] Creating snapshot: test-manual (type: Manual)
[HH:MM:SS] Snapshot created successfully: YYYYMMDD-HHMMSS
YYYYMMDD-HHMMSS
```

### Verify Snapshot
```bash
koompi-snapshot list
```

**Expected:**
```
Available snapshots:

ID                   NAME                           TYPE            CREATED
==================== ============================== ============== ====================
YYYYMMDD-HHMMSS     test-manual                    Manual         YYYY-MM-DDTHH:MM:SSZ
```

### Check Snapshot Directory
```bash
ls -la /.snapshots/
```

**Expected:**
```
drwxr-xr-x YYYYMMDD-HHMMSS
```

### Verify Snapshot Content
```bash
ls -la /.snapshots/YYYYMMDD-HHMMSS/
```

**Expected:**
- Full system snapshot (/, /bin, /etc, /usr, etc.)
- metadata.json file with snapshot info

## Test 4: Rollback Test

### Modify System
```bash
# Create a test file
echo "before rollback" > /var/test.txt

# Create snapshot
SNAPSHOT_ID=$(koompi-snapshot create "before-test" Manual "Before test modification")
echo "Snapshot ID: $SNAPSHOT_ID"

# Modify the file
echo "after modification" > /var/test.txt
cat /var/test.txt  # Should show "after modification"
```

### Perform Rollback
```bash
koompi-snapshot rollback $SNAPSHOT_ID
# Answer 'y' to confirmation

# Reboot
reboot
```

### After Reboot - Verify Restoration
```bash
cat /var/test.txt
# Should show "before rollback"
```

## Test 5: Compression Verification

### Check Compression Ratio
```bash
# Install some large files
pacman -S firefox libreoffice

# Check compression stats
sudo compsize /
```

**Expected:**
- Compression ratio should be ~30-50% for typical Arch install
- Larger savings on text-heavy directories (/usr/share/doc, /var/log)

## Test 6: Performance Testing

### Sequential Write
```bash
dd if=/dev/zero of=/var/testfile bs=1M count=1024 conv=fdatasync
```

### Sequential Read
```bash
dd if=/var/testfile of=/dev/null bs=1M
```

### Random I/O (requires fio)
```bash
fio --name=random-rw --ioengine=libaio --rw=randrw --bs=4k --numjobs=4 --size=1G --runtime=60 --direct=1 --directory=/var
```

## Observations to Document

### ✅ Checklist
- [ ] Partitions created correctly (EFI + Btrfs)
- [ ] All subvolumes present (@, @home, @var, .snapshots)
- [ ] Mount options include compression
- [ ] fstab generated correctly
- [ ] Overlay directories created in /var/lib/overlay/etc
- [ ] Read-only root mount works
- [ ] /etc overlay allows config changes
- [ ] Snapshots can be created
- [ ] Snapshots appear in /.snapshots/
- [ ] Rollback functionality works
- [ ] System boots after rollback
- [ ] Compression is active and effective

### Performance Notes
- Boot time: _____ seconds
- Snapshot creation time (full system): _____ seconds
- Rollback preparation time: _____ seconds
- Compression ratio: _____ %
- Disk usage (base system): _____ GB

### Issues Encountered
Document any issues here:

1. _____________________
2. _____________________
3. _____________________

### Additional Notes
_____________________
_____________________
_____________________

## Success Criteria

✅ **All tests pass if:**
1. Disk is correctly partitioned (EFI + Btrfs)
2. All 4 subvolumes are created
3. Mount options include zstd compression
4. Root filesystem can be mounted read-only
5. /etc overlay works on read-only root
6. Snapshots can be created manually
7. Snapshots are listed correctly
8. Rollback restores system state
9. System boots successfully after rollback
10. No data corruption or filesystem errors

## Troubleshooting

### Issue: "Read-only file system" when creating overlay
**Solution:** Ensure /var/lib/overlay/etc/{upper,work} directories exist and are writable

### Issue: Snapshot creation fails
**Solution:** Check /.snapshots directory exists and has correct permissions

### Issue: Rollback doesn't work
**Solution:** Verify grub-btrfs is installed and GRUB config is regenerated

### Issue: Poor compression ratio
**Solution:** Check mount options include compress=zstd, verify with `mount | grep btrfs`

## Next Steps After Testing

1. Document all observations
2. Fix any issues found
3. Integrate into installer (koompi-install)
4. Create automated tests
5. Add to CI/CD pipeline
