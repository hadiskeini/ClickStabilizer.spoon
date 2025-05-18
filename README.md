# ClickStabilizer Spoon for Hammerspoon

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/badge/version-1.0-blue.svg)](https://github.com/<YOUR_GITHUB_USERNAME>/ClickStabilizer.spoon) <!-- Replace with your actual repo link -->

Prevent accidental mouse cursor movement immediately after clicking.

## What it Does

Do you ever find your mouse cursor drifting slightly *just after* you click, especially with sensitive trackpads or if you have a slight tremor? ClickStabilizer helps by briefly "locking" your cursor's position for a configurable duration (default: 120ms) after a click event from a *specific* pointing device. This ensures that any minor, unintentional movements made while releasing the click don't register, leading to more precise interactions.

## Features

*   **Click Lock:** Temporarily freezes the mouse cursor at the point of a click.
*   **Device Specific:** Intelligently targets only the specified pointing device (e.g., your trackpad, not an external mouse, or vice-versa).
*   **Configurable Lock Duration:** Adjust how long the cursor stays locked after a click.
*   **Easy Device Identification:** A simple command helps you identify and set the correct event flags for your target device.
*   **Persistent Settings:** Your device configuration and lock duration are saved and reloaded automatically.
*   **Lightweight:** Minimal impact on system performance.

## Installation

1.  **Download:**
    *   Download the `ClickStabilizer.spoon.zip` file from the [Releases page](https://github.com/<YOUR_GITHUB_USERNAME>/ClickStabilizer.spoon/releases). <!-- Replace with your actual repo link -->
    *   OR, clone this repository: `git clone https://github.com/<YOUR_GITHUB_USERNAME>/ClickStabilizer.spoon.git` <!-- Replace with your actual repo link -->

2.  **Install the Spoon:**
    *   Unzip the downloaded file (if you downloaded the zip).
    *   Move the `ClickStabilizer.spoon` directory to `~/.hammerspoon/Spoons/`. If the `Spoons` directory doesn't exist, create it.

3.  **Load the Spoon in Hammerspoon:**
    Add the following lines to your `~/.hammerspoon/init.lua` file:

    ```lua
    cs = hs.loadSpoon("ClickStabilizer")
    cs:start()
    ```

4.  **Reload Hammerspoon:**
    Reload your Hammerspoon configuration (usually from the Hammerspoon menu bar icon: "Reload Config").

## Configuration and Usage

Once installed and loaded, ClickStabilizer needs to know which pointing device it should monitor.

### 1. Identify Your Pointing Device (Crucial First Step!)

The Spoon needs to identify the unique event flags associated with the pointing device you want to stabilize (e.g., your laptop's trackpad).

1.  Open the Hammerspoon Console (Hammerspoon menu bar icon -> Console).
2.  Type the following command and press Enter:
    ```lua
    cs:setDevice()
    ```
3.  The console will prompt you: `Let’s identify your pointing device!` and `Click your pointing device once...`
4.  Now, perform a single click using the device you want to stabilize (e.g., tap your tablet pen).
5.  If successful, you'll see a message like: `✅ Great! ClickStabilizer is now functional!`
    The detected device flags will be automatically saved.

    If it says `I couldn’t detect a code. Try clicking again.`, simply try clicking again with the target device.

### 2. Adjust Lock Duration (Optional)

The default lock duration is 120 milliseconds. If you want to change this:

1.  Open the Hammerspoon Console.
2.  Type the following command, replacing `150` with your desired duration in milliseconds, and press Enter:
    ```lua
    cs:setLock(150) -- Sets lock duration to 150ms
    ```
3.  You'll see a confirmation: `✅ When you click, your cursor position is now locked for 150 ms.`

This setting is also saved automatically.

### Available Commands

You can run these commands in the Hammerspoon Console:

*   `cs:start()`
    *   Starts the ClickStabilizer. This is usually called in your `init.lua`.
    *   Initializes and activates the event tap.
*   `cs:stop()`
    *   Stops the ClickStabilizer.
*   `cs:setDevice()`
    *   Initiates the process to detect and save the event flags for your target pointing device. **This is the most important setup step.**
*   `cs:setLock(milliseconds)`
    *   Sets the duration (in milliseconds) for which the cursor will be locked after a click.
    *   Example: `cs:setLock(100)` sets the lock to 100ms.
*   `cs:setEventFlags(flag)`
    *   Manually sets the event flags for the device. This is an advanced option if `cs:setDevice()` doesn't work or if you know the flags already.
    *   The `flag` is usually a hexadecimal number (e.g., `0x20000100`).
    *   Example: `cs:setEventFlags(0x20000100)`
*   `cs:resetDefaults()`
    *   Resets all settings (device flags and lock duration) to their default values.
    *   Default event flags: `0x20000100` (may work for some built-in trackpads)
    *   Default lock duration: `120` ms

## How It Works

ClickStabilizer listens for mouse down events (`leftMouseDown`). When a click occurs from the configured device:
1.  It records the cursor's current position.
2.  It starts a timer for the specified `lockMs` duration.
3.  During this lock period, any mouse movement events (`mouseMoved`, `leftMouseDragged`, etc.) *from the same device* are intercepted, and the cursor is immediately moved back to its recorded start position.
4.  Once the timer expires, the lock is released, and normal mouse movement resumes.

This effectively "swallows" any small jitters or drags that happen immediately after a click on the target device.


## Contributing

Contributions, issues, and feature requests are welcome! Please feel free to fork the repository and submit a pull request.