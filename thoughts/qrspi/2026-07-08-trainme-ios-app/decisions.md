# Resolved PRD Decisions (from owner, 2026-07-08)

These resolve the open decisions in PRD §12. Later phases (Design, Structure, Plan)
must treat these as settled.

1. **Template versioning (PRD §4.2): keep it simple.** No special versioning design.
   Sessions keep the workout-instance copy made at scheduling time; editing a template
   affects only sessions created after the edit. No "apply change to N upcoming
   sessions" prompt.

2. **Expanded client fields (PRD §4.4): adopt.** Client record includes primary goal,
   injuries/limitations (surfaced at session time), and free-form notes, in addition
   to name + phone.

3. **Recurring sessions (PRD §5.4): YES — v1 scope** (e.g. "every Tue/Thu at 7am").
   **Double-booking detection/warning: NO — out of scope.**

4. **iOS system calendar sync (PRD §5.4): YES — in scope** (one-way push of sessions
   via EventKit), **plus "export to Gmail."**
   - Working interpretation: EventKit writes to whichever calendar account is
     configured on the device — including a Google/Gmail account — which covers
     Google Calendar; and export/share flows (reports, data export) go through the
     share sheet, where Gmail is an available target.
   - If the owner instead means a direct Google Calendar API integration, that
     contradicts the local-only/no-account constraint — confirm in the Design phase.
