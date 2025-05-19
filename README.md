# ClickStabilizer Spoon for Hammerspoon

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/badge/version-1.0.1-blue.svg)](https://github.com/hadiskeini/ClickStabilizer.spoon)

A [Hammerpoon](https://www.hammerspoon.org/) Spoon that prevents accidental mouse cursor movement immediately after clicking.

## What it Does

ClickStabilizer combats accidental cursor drags that happens when you just try to click. This is particularly useful for:

*   **Graphic Tablet Pens:** Stabilizes input when lifting the pen after a tap, preventing the cursor from shifting.
*   **Sensitive Trackpads/Mice:** Prevents jitters from overly responsive devices.
*   **Users with Tremors:** Helps compensate for minor involuntary hand movements that can shift the cursor post-click.

The Spoon works by briefly "locking" your cursor at its click position for a configurable duration (default: 100 ms). This stops accidental micro-drags or movements, ensuring your clicks are registered precisely where you intended.

> [!NOTE]  
> This Spoon can target the specific pointing device you choose—but it currently can’t tell one mouse or trackpad from another. It does, however, distinguish between graphic tablets and other devices. When you configure it for your tablet, mouse and trackpad input will remain unaffected.

## Installation

1.  **Download:**
    *   Download the `ClickStabilizer.spoon.zip` file from the [Releases page](https://github.com/hadiskeini/ClickStabilizer.spoon/releases).

2.  **Install the Spoon:**
    *   Unzip the downloaded file.
    *   Move the `ClickStabilizer.spoon` directory to `~/.hammerspoon/Spoons/`. If the `Spoons` directory doesn't exist, create it.

3.  **Load the Spoon in Hammerspoon:**
    Add the following lines to your `~/.hammerspoon/init.lua` file:

    ```lua
    cs = hs.loadSpoon("ClickStabilizer")
    cs:start()
    ```

4.  **Reload Hammerspoon:**
    Reload your Hammerspoon config.

## Configuration and Usage

Once installed and loaded, ClickStabilizer needs to know which pointing device it should monitor.

You can do this by opening the configuration menu from the menu bar icon and clicking "Identify Device".

## Available Commands in Hammerspoon Console

*   `cs:start()`
    *   Starts the ClickStabilizer. This is usually called in your `init.lua`.
    *   Initializes and activates the event tap.
*   `cs:stop()`
    *   Stops the ClickStabilizer.
*   `cs:setDevice()`
    *   Initiates the process to detect and save the event flags for your target pointing device. 
*   `cs:setLock(milliseconds)`
    *   Sets the duration (in milliseconds) for which the cursor will be locked after a click.
    *   Example: `cs:setLock(100)` sets the lock to 100ms.
*   `cs:setEventFlags(flag)`
    *   Manually sets the event flags for the device. This is an advanced option if `cs:setDevice()` doesn't work or if you know the flags already.
    *   The `flag` is usually a hexadecimal number (e.g., `0x20000100`).
    *   Example: `cs:setEventFlags(0x20000100)`
*   `cs:resetDefaults()`
    *   Resets all settings (device flags and lock duration) to their default values.
    *   Default event flags: `0x20000100` (corresponds to Wacom One CTC4110WL)
    *   Default lock duration: `100` ms

## Contributing

Contributions, issues, and feature requests are welcome! Please feel free to fork the repository and submit a pull request.
