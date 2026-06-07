//! snapper.zig — @baseline lookup + rollback mechanics for koompi-restore.
//!
//! VERIFIED against snapper(8) (man.archlinux.org) + the Arch/openSUSE Snapper
//! docs (2026):
//!   * `snapper -c root rollback N` creates a read-only snapshot of the running
//!     system, then a NEW read-write snapshot whose source is N, and sets THAT as
//!     the btrfs DEFAULT subvolume. It takes effect on the next reboot.
//!   * Rollback touches ONLY the root config's subvolume (@). `@home` is a
//!     separate subvolume mounted independently, so it is left untouched — that
//!     is precisely the "System Restore keeps /home" guarantee.
//!   * The @baseline snapshot (created `--type single` with NO cleanup algorithm)
//!     is never auto-pruned and is NOT consumed by rollback → reusable forever.
//!   * `-p/--print-number` makes rollback print the new RW snapshot's number.
//!
//! ⚠️ PRECONDITION — TWO legs, both must hold, or rollback SILENTLY no-ops:
//! `snapper rollback` only changes what BOOTS by flipping the btrfs DEFAULT
//! subvolume. Anything that hard-codes the root subvol overrides that flip:
//!   (a) fstab — `subvol=@`/`subvolid=` on the `/` entry. post_install.sh's
//!       fix_root_subvol_mount() strips it. [closed]
//!   (b) GRUB — grub-mkconfig's 10_linux usually writes `rootflags=subvol=@` on
//!       the kernel line, which boots @ explicitly no matter the default subvol.
//!       fstab-unpin alone does NOT close this. [OPEN — see fix_root_subvol_mount
//!       TODO; verify at VM-test by grepping /boot/grub/grub.cfg for rootflags=]
//! reset.zig's ensureRootUnpinned() checks leg (a) only — leg (b) needs a real
//! install to observe.
//!
//! ⚠️ SCAFFOLD — UNTESTED (needs a real btrfs+snapper install). Zig 0.16
//! conventions: `io` is threaded through to proc.runCapture.

const std = @import("std");
const Io = std.Io;
const proc = @import("proc.zig");

pub const Error = error{ BaselineNotFound, BadSnapperOutput };

/// The snapper config that tracks `/` (created by post_install.sh setup_snapper).
pub const CONFIG = "root";

/// Find the @baseline snapshot's number by its userdata marker `baseline=yes`.
///
/// We request CSV with a `|` column separator (NOT snapper's default comma): the
/// baseline userdata is literally `important=yes,baseline=yes`, which CONTAINS a
/// comma, so a comma-separated parse would split mid-field (and under RFC-4180
/// CSV the field would be quoted — fiddly). `|` never appears in the data, so
/// each row is a clean `number|userdata` split on the first `|`. We avoid
/// `--jsonout` deliberately: snapper's JSON serialization of `userdata` (object
/// vs string) was UNVERIFIED at write time.
///   snapper -c root --csvout --separator '|' --no-headers list \
///     --columns number,userdata
pub fn findBaseline(io: Io, alloc: std.mem.Allocator) !u32 {
    const out = try proc.runCapture(io, alloc, &.{
        "snapper",         "-c",          CONFIG,
        "--csvout",        "--separator", "|",
        "--no-headers",    "list",        "--columns",
        "number,userdata",
    });
    defer alloc.free(out);

    var lines = std.mem.tokenizeScalar(u8, out, '\n');
    while (lines.next()) |line| {
        const bar = std.mem.indexOfScalar(u8, line, '|') orelse continue;
        const userdata = line[bar + 1 ..];
        if (std.mem.indexOf(u8, userdata, "baseline=yes") == null) continue;
        const number_str = std.mem.trim(u8, line[0..bar], " \t\r");
        return std.fmt.parseInt(u32, number_str, 10) catch Error.BadSnapperOutput;
    }
    return Error.BaselineNotFound;
}

/// Roll the root subvolume back to snapshot `number`. Effective after reboot.
/// Returns the number of the new read-write snapshot snapper creates (via
/// `--print-number`), useful for a log / audit trail.
pub fn rollback(io: Io, alloc: std.mem.Allocator, number: u32) !u32 {
    var buf: [16]u8 = undefined;
    const n = std.fmt.bufPrint(&buf, "{d}", .{number}) catch return Error.BadSnapperOutput;
    const out = try proc.runCapture(io, alloc, &.{
        "snapper", "-c", CONFIG, "rollback", "--print-number", n,
    });
    defer alloc.free(out);
    const trimmed = std.mem.trim(u8, out, " \t\r\n");
    return std.fmt.parseInt(u32, trimmed, 10) catch Error.BadSnapperOutput;
}
