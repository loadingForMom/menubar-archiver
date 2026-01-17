# SilentArchive

This workspace contains a silent macOS archiver with a Finder Quick Action and a shared core Swift package.

## Targets

- **ArchiverAgent**: AppKit agent that runs without Dock/Cmd+Tab presence, shows a temporary menu-bar status item only while archiving, and quits when idle.
- **ArchiverQuickAction**: Finder Quick Action (Action Extension) that creates jobs and triggers the agent.
- **SharedCore**: Swift package containing job models, job storage, and ZIPFoundation archiving utilities.

## How it works

1. In Finder, select files or folders.
2. Use **Quick Actions → Create Archive**.
3. The extension stores a job JSON at:
   `~/Library/Group Containers/group.com.example.silentarchive/jobs/<uuid>.json`
4. The agent is invoked via `archiver://run?job=<uuid>` and runs the job silently.
5. Double-clicking a `.zip` (or using **Open With → SilentArchive**) enqueues an extract job that unpacks to a folder next to the archive.

## Notes

- The agent is configured with `LSUIElement=YES` and does not display windows or notifications.
- The menu-bar item appears only during work (progress + cancel), shows a brief ✓/×/! status on completion, then disappears.
- The archive is saved next to the selected items (or the first item’s parent) using `Archive.zip`, `Archive 2.zip`, etc.

## Running

1. Open `ArchiverWorkspace.xcworkspace` in Xcode.
2. Configure the App Group identifier `group.com.example.silentarchive` in both targets.
3. Build and run **ArchiverAgent** once to register the URL scheme.
4. Build the **ArchiverQuickAction** target to install the Finder action.
5. To debug locally, run **ArchiverAgent** with `--test <path>` to enqueue a test archive job, or `--test <path> --extract` to test extraction.

Finder path: **right click → Quick Actions → Create Archive**.

## Enabling the Finder Quick Action

1. Open **System Settings → Privacy & Security → Extensions → Finder Extensions**.
2. Enable **Create Archive**.
3. In Finder, select one or more items and use **Quick Actions → Create Archive**.
