# KOOMPI OS Security Recommendations

To harden KOOMPI OS for education and enterprise use, I recommend implementing the following security layers.

## 1. Network Security (Firewall)
**Recommendation:** Add `ufw` (Uncomplicated Firewall) or `nftables`.
*   **Why:** Even on a base system, closing unused ports is critical.
*   **Implementation:**
    *   Add `ufw` to `iso/packages.x86_64`.
    *   Enable `ufw.service` in `customize_airootfs.sh`.
    *   Default Configuration: `ufw default deny incoming`, `ufw default allow outgoing`.

## 2. Mandatory Access Control (MAC)
**Recommendation:** Enable `AppArmor`.
*   **Why:** Restricts what programs can do (file access, network) even if they run as root.
*   **Implementation:**
    *   Add `apparmor` to `iso/packages.x86_64`.
    *   Add `lsm=landlock,lockdown,yama,integrity,apparmor,bpf` to kernel parameters in GRUB/Syslinux.
    *   Enable `apparmor.service`.

## 3. Secure Boot Support
**Recommendation:** Include `sbctl`.
*   **Why:** Ensures the bootloader and kernel haven't been tampered with.
*   **Implementation:**
    *   Add `sbctl` to `iso/packages.x86_64`.
    *   (Note: Signing the ISO itself is complex, but providing the tool allows users to enroll their own keys).

## 4. Sandbox & Isolation
**Recommendation:** Enforce Flatpak sandboxing.
*   **Why:** Flatpaks (KDE, browser apps) are sandboxed by default.
*   **Implementation:**
    *   Ensure `flatpak` is installed (Already done).
    *   Consider adding `bubblewrap` or `firejail` for untrusted CLI tools.

## 5. Brute Force Protection
**Recommendation:** Add `fail2ban`.
*   **Why:** If SSH (`openssh`) is enabled, it will be targeted.
*   **Implementation:**
    *   Add `fail2ban` to `iso/packages.x86_64`.
    *   Enable `fail2ban.service`.

## 6. System Auditing
**Recommendation:** Add `audit`.
*   **Why:** Logs security-relevant events for post-incident analysis.
*   **Implementation:**
    *   Add `audit` to `iso/packages.x86_64`.
    *   Enable `auditd.service`.

## Suggested Action Plan for Claude Code
If you approve, we can ask Claude to:
1.  Add `ufw apparmor sbctl fail2ban audit` to the package list.
2.  Update bootloader configs to enable AppArmor kernel parameters.
3.  Update `customize_airootfs.sh` to enable these services by default.
