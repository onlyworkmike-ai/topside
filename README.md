# Topside

A Dynamic Island for the Mac. At rest it is a small black notch-shaped pill at the top center of the
screen. Move the cursor to it and it grows into a panel. It also pops out by itself for volume and
brightness changes, plugging in the charger, and while music is playing.

## Run it

1. Install Xcode from the App Store, or just the command line tools: `xcode-select --install`
2. In Terminal, go to this folder and run:

   ```
   bash build.sh
   ```

3. The island appears at the top of your screen. The waveform icon in the menu bar has
   **Launch at Login** and **Quit**.

## What works

| Feature | How it works |
| --- | --- |
| Volume slider and pop-up | Real system volume (CoreAudio). Stays in sync with the keyboard keys, Control Center and AirPods. Tap the speaker icon to mute. |
| Brightness slider and pop-up | Real built-in display brightness. Uses a private Apple framework, so a macOS update could break it. |
| Charger pop-up | Shows when you plug in or unplug, with the battery %. |
| Music and Spotify | Title, artist, play/pause/next/previous. Album art for Spotify; Music shows a placeholder. |
| Clock and battery | In the expanded panel. |

## Things to know

- **First run:** macOS asks if Topside may control Music / Spotify. Click OK. If you clicked "Don't Allow",
  turn it on in System Settings > Privacy & Security > Automation.
- Rebuilding changes the app's signature, so macOS may ask for that permission again.
- The normal macOS volume and brightness pop-ups still appear too. macOS gives apps no clean way to hide them.
- The brightness pop-up only fires for big steps (the keyboard keys), so slow auto-brightness changes stay quiet.
- The pill sits where the menu bar is. The middle of the menu bar is usually empty, but if you have a lot of
  menu bar items on the left, the pill can cover part of them.
- This was written without being able to compile it. If `bash build.sh` shows errors, copy them and ask for a fix.
