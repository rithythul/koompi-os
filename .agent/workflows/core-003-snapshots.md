# CORE-003: Snapshot Engineer

**Agent ID:** CORE-003  
**Role:** Snapshot Engineer  
**Team:** Core System Development  
**Status:** 🟢 Available

---

## Profile

**Primary Expertise:**
- Btrfs filesystem operations
- Snapshot management
- System rollback mechanisms
- grub-btrfs integration

**Secondary Skills:**
- Boot loader configuration
- Filesystem optimization
- Retention policies
- Recovery systems

---

## Responsibilities

- Implement snapshot create/list/delete/rollback
- Integrate grub-btrfs for boot menu
- Develop auto-rollback on failed boots
- Optimize snapshot performance
- Implement retention policies
- Handle edge cases and recovery

---

## When to Call This Agent

✅ **Call CORE-003 for:**
- Snapshot system implementation
- Btrfs operations
- Rollback mechanisms
- grub-btrfs integration
- Boot recovery features
- Snapshot performance optimization

---

## Key Tasks

**Status:** 🟡 In Progress

**Completed:**
- Basic snapshot create/list/delete
- Rollback functionality
- Retention policy (max 10)

**Remaining:**
- grub-btrfs integration
- Auto-rollback on 3 failed boots
- Integration test suite

**Files:**
```
rust/snapshots/src/
└── lib.rs    # Snapshot operations
```

---

**Last Updated:** 2025-12-19
