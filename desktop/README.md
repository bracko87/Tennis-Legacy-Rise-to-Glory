# Tennis Legacy desktop preview

This is a **test build** of the existing online multiplayer Tennis Legacy game. It opens the live website in a desktop app window. It is not offline single-player. All players share the same servers, accounts, tournaments and seasons as browser players.

## Test package builds
The \`.github/workflows/tennis-desktop-installers.yml\` GitHub Actions workflow builds:
- **Windows x64** — \`TennisLegacy-Setup-0.1.1-x64.exe\` (NSIS installer).
- **Linux x64** — \`TennisLegacy-0.1.1-x64.AppImage\`.

Open **Actions → Tennis Legacy desktop test installers → latest run**, then download the Windows and Linux artifacts. Each artifact ZIP contains the installer.

## Local use
\`\`\`shell
cd desktop
npm install
npm run check
npm start
\`\`\`

Windows packaging: \`npm run dist:win\`. Linux packaging: \`npm run dist:linux\`.

## Before public distribution
- Test signup/login, redirect and email links, Premium status, payment flow, and external links on real Windows and Linux machines.
- These preview builds are **unsigned**; Windows SmartScreen may warn, and AppImage may require a supported FUSE setup.
- Add a branded icon and code signing, checksum publication, permanent hosting and download analytics.
- The web game can be updated without rebuilding this desktop wrapper; changes to the wrapper require a new desktop release.
- No Steam or production publishing is performed by this workflow.

## Game icon

The Windows installer, EXE, desktop shortcut and Linux AppImage use the same
blue tennis-ball image supplied by the game creator. The icon is generated
from \`desktop/assets/tennis-ball-original.webp.b64\` (a downsampled copy
of the original supplied picture, not newly generated artwork).

To regenerate locally, install Python 3 and Pillow 11.3.0 and run:

\`\`\`shell
python desktop/scripts/generate_icons.py
python desktop/scripts/generate_icons.py --verify
\`\`\`

Electron Builder reads \`desktop/build/icon.ico\` for Windows and
\`desktop/build/icon.png\` for Linux.
