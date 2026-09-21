## 🛠️ The Working Method: NDI (Network Device Interface)

NDI sends high-quality, low-latency video over your local network. It's the standard for this kind of setup.

Here's exactly how to set it up:
- Install OBS + NDI Plugin on ALL Macs: You need OBS Studio and the DistroAV plugin (formerly OBS-NDI) installed on every Mac you want to capture and on the Mac running your main stream. You can install DistroAV via Homebrew (brew install distroav) or download the installer from the DistroAV GitHub releases page.
```
brew install distroav
```
- Set Up the Source Macs: On the Mac(s) you want to capture, open OBS. Add a "macOS Screen Capture" source for its own display. Then, go to Tools > DistroAV NDI® Settings, check "Main Output," and give it a recognizable name (e.g., "Mac-2-Reference").

- Set Up the Main Streaming Mac: On the Mac that will run the final stream, open OBS. Add a new source and select NDI Source. Your other Mac's screen should appear in the dropdown list. Add it, and you can now resize and position it next to your own display capture.

## Quick recap of your live-streaming path:

- Install on every Mac: OBS Studio + DistroAV (NDI plugin)
- On Mac 2 and Mac 3: Add a Screen Capture source, enable NDI output (Tools > DistroAV NDI Settings)
- On Mac 1: Add an NDI Source for each → arrange side by side → stream
- Wire everything to Gigabit Ethernet — this is the make-or-break detail
- Fallback if NDI misbehaves: HDMI capture cards (watch for HDCP on Macs)

## A few extras worth knowing down the line:
- If you want to record the three-up view rather than stream, OBS's local recording does the same job—no extra setup.
- The Logitech Flow setup you already have is perfect for this: your MX Master 3 and MX Keys Mini can hop to whichever Mac you're actively driving, so you don't need a KVM to control all three.
- For the Wiimote + IR sensor bar work, keep the two IR bar locations in mind when you're testing on Mac 3—the desk bar for editor work, the TV bar for gameplay testing on the VT30.
