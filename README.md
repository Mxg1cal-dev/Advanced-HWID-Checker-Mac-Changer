# HWID Checker GUI

A Windows 10/11 desktop tool for reading and comparing your PC's hardware/system identifiers (HWIDs) — SMBIOS UUID, disk serials, MAC addresses, TPM info, and more — with a dark-themed GUI, scan history, and side-by-side comparison between scans.

Made by **Mxg1cal**.

> ⚠️ This tool only **reads** identifiers that Windows already exposes through its own APIs. It does not modify, hide, or fake any hardware ID. The one exception is the optional MAC address changer, which uses Windows' own built-in, driver-supported "Network Address" adapter property — the same setting available in Device Manager.

---

## Features

- **Full HWID scan** — SMBIOS/system UUID, BIOS and motherboard serials, CPU ID, RAM module serials, disk and volume serials, network adapter MACs and IP info, GPU/monitor/sound device IDs, TPM and Secure Boot status, battery info, and detailed Windows version info.
- **Category filter** — check only the categories you want scanned/shown/saved; leave none checked to include everything.
- **Color-coded output** — each device category is shown in its own color so results are easy to scan visually.
- **Scan history** — every saved report appears in a list; double-click to open it in Notepad.
- **Compare scans** — pick an old report and compare it against your current hardware. Differences are shown color-coded (new / changed / missing). Network adapter, disk, and RAM ordering is stabilized so the comparison doesn't produce false positives from Windows re-ordering devices between boots, and rotating IPv6 privacy addresses are excluded automatically.
- **Choose where reports are saved**, or disable saving entirely and just view results on screen.
- **Delete old reports** directly from the GUI (with a confirmation prompt).
- **Optional public IP lookup** — off by default; only contacts `api.ipify.org` if you tick the box.
- **MAC address changer** — set a custom MAC via Windows' supported adapter property, or reset back to the factory MAC. Useful for testing router/DHCP/MAC-filtering behavior.
- **Logged-in accounts check** — shows your current Windows user, Steam account names (from Steam's own local login list), running/not-running status for common game clients (Discord, Epic, Battle.net, etc.), and the *names* of entries in Windows Credential Manager. **No passwords, tokens, or session data are ever read** — see "Privacy & Safety" below.

---

## Requirements

- Windows 10 or 11
- PowerShell (built in, no installation needed)
- Administrator rights (the app will prompt for elevation automatically — some values like TPM info and certain disk serials require it)

---

## How to run

1. Download `HWID_GUI.ps1` and `Run_HWID_GUI.bat` and keep them in the **same folder**.
2. Double-click `Run_HWID_GUI.bat`.
3. Approve the admin prompt (UAC).
4. The GUI opens. Use **Run New Check** to scan, **Compare Selected vs Current** to diff against a past report, and the category list to control what's included.

### Windows SmartScreen / Defender warning

Because this script isn't digitally signed, Windows may show a SmartScreen warning ("Windows protected your PC") the first time you run it. This is normal for any unsigned `.ps1`/`.bat` tool, not a sign of a problem. If you want to inspect the code first, it's plain PowerShell — open `HWID_GUI.ps1` in Notepad or any text/code editor to read exactly what it does before running it.

---

## Privacy & safety notes

- All hardware data is read locally and **only saved where you choose** — nothing is sent anywhere, except the optional public IP lookup (off by default, and only talks to `api.ipify.org`).
- The "Logged-in Accounts" feature deliberately avoids anything that resembles credential or session-token extraction:
  - Steam account names come from Steam's own `loginusers.vdf`, a plaintext file Steam itself writes for its login screen — not a secret.
  - Discord, Epic, Battle.net, Origin, Riot, and Spotify are only checked for whether their process is **currently running** — their actual session/login data is never read.
  - Windows Credential Manager entries are listed by **name only** (via `cmdkey /list`); no passwords or secrets are ever retrieved.
- Report files are plain text. Since they contain hardware identifiers, treat them like any other system info file — don't post them publicly if you'd rather keep that information private.

---

## License

This project is licensed under the [MIT License](LICENSE) — free to use, modify, and distribute, with attribution.

---

## Disclaimer

This tool is provided as-is for informational and diagnostic purposes (testing hardware, troubleshooting, comparing system state before/after changes, network configuration testing, etc.). You're responsible for how you use it. The author is not responsible for misuse.
