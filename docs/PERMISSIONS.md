# Permissions

[← Back to README](../README.md)

- [What Pinpin needs and why](#what-pinpin-needs-and-why)
- [Granting permissions](#granting-permissions)
- [Troubleshooting](#troubleshooting)

## What Pinpin needs and why

| Permission | Required? | Used for |
| --- | --- | --- |
| **Screen Recording** | Yes | Drawing a live copy of each pinned window, and reading window titles for the window list |
| **Accessibility** | Recommended | Focusing the exact window you clicked, and un-minimizing windows you pin from the list |

Pinpin can't pin windows without Screen Recording. Without Accessibility, pinning still works, but clicking a pinned window can bring up the wrong window of that app.

Pinpin doesn't record, save, or send anything. Screen Recording only feeds the on-screen copy of pinned windows. Pinpin makes no network connections.

## Granting permissions

### First launch

The first time Pinpin opens, macOS asks for both permissions. Turn on **Pinpin** in each list in **System Settings → Privacy & Security**.

macOS only applies Screen Recording to apps launched after it was granted. Quit and reopen Pinpin after you turn it on.

### Later

Pinpin only asks on its own the first time. After that, each missing permission shows as a **Grant** banner in the dropdown. Click **Grant**:

1. If macOS already reports the permission as granted, nothing happens and the banner goes away.
2. Otherwise Pinpin asks whether the permission is already on in System Settings:
   - **Open System Settings** opens the right page, with Pinpin added to the list. Turn it on.
   - **It's Already On** handles the cases below.

Pinpin remembers each permission once it has seen it granted. After that, its banner stays hidden. Pinpin only asks again if a pin actually fails without the permission.

## Troubleshooting

### Screen Recording is on, but Pinpin says it's missing

macOS needs a relaunch to apply a new Screen Recording grant. Click **Grant**, then **It's Already On**, then **Relaunch**. Relaunching clears your pins.

### "macOS doesn't recognize this copy of Pinpin"

A permission entry can belong to a different copy of Pinpin, usually one signed differently. macOS then shows the toggle as on, but it doesn't apply to the copy you're running. To fix it:

1. Open **System Settings → Privacy & Security** and choose **Screen Recording** or **Accessibility**.
2. Select **Pinpin** and remove it with **–**.
3. Add it again with **+**, or relaunch Pinpin, and turn it on.

### Will I have to grant permissions again after updating?

No. Every release is signed with the same certificate, so macOS keeps your grants when you update.

If you build Pinpin yourself, run the signing setup in [Development](DEVELOPMENT.md#code-signing) once. Otherwise every build gets a new signature, and macOS asks again each time.
