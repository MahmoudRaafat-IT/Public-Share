What it does:
Allows multiple RDP sessions on Windows.

Firewall (don’t disable):
Add an inbound rule for TCP 3389 or allow RDP Wrapper through the firewall.

Prerequisites:

Windows admin rights

install.bat (installer)

RDPConf.exe (configuration tool)

Backup your current rdpwrap.ini

Step 1 — Install:

Run install.bat as Administrator.

(Right‑click → Run as administrator)

Step 2 — Check:

Run RDPConf.exe and check the status and version.

Look for “Listening” and “Fully supported” (or note the Windows build shown).

Step 3 — Replace ini (if needed):

If status shows unsupported, get the correct rdpwrap.ini for your Windows build.

Replace the file at:

C:\Program Files\RDP Wrapper\rdpwrap.ini


(Make a backup first; replace with elevated permissions.)

Step 4 — Restart:

Restart the computer to apply changes.

Step 5 — Verify (after reboot):

Run RDPConf.exe again and confirm “Listening” and “Fully supported”.

Quick tips:

Always run installer/tools as Admin.

Keep the original rdpwrap.ini backup.

Download .ini updates only from trusted sources.

Test on a non-production machine first.

If something goes wrong:

“Not listening” / “Unsupported”: update or replace rdpwrap.ini.

Only one session: check Remote Desktop Services and Group Policy settings.

Firewall issues: ensure inbound TCP 3389 rule exists.

Disclaimer:
Use at your own risk and follow your organization’s security policies.
