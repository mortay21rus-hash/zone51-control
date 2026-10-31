# Protocol evidence

Reference implementation: `Zone51 Keyboards Beta.exe`, with the Zone 51 Garnet configuration.

- Installer SHA-256: `b9dfec519961ba953e3c544ece1123b2b908eba806bafe220e25919e2cb062bb`.
- Extracted `OemDrv.exe` SHA-256: `09970d63ab6aa00d6485ba00f4fc3f8637af6713901cfacd790b8f32d3d61f53`.
- `Dev/kb/Garnet/KB.ini`: VID `258a`, PID `010c`, `Fw=24`, Garnet selector `Psd=3,0,0,0,1,d`. Physical key rectangles, Windows virtual codes and lighting capabilities follow this configuration. Proprietary executables and images are not distributed in this project.
- `OemDrv.exe` (image base 0x400000) routine `0x4893c0`: 520-byte feature transfers. Firmware type 24 uses report ID 6. Header contains command, reserved bytes, page count/index, little-endian data length.
- Read configuration `0x84`, write configuration `0x04`, 128 bytes. Read color palette `0x8a`, write palette `0x0a`, 512 bytes. Only these four commands exist in the implementation.
- Routine `0x48b5f0`: preset/custom selector at config 9, effect at 10. Effect entries begin at config `0x3a` and occupy two bytes in the Garnet INI's declared order. High nibble is speed, low nibble color selection. The INI enumerates brightness/speed as `0,1,2,3,4`.
- The original Garnet config read from hardware ends with `5a a5`; reads from other blocks or missing this marker are rejected. The exact 520-byte interface descriptor is bundled and compared before opening the device.
- Color slots occupy 21 bytes per effect ID. Slot 0 is user RGB, 1–6 are fixed colors, 7 selects multicolor in configuration. Read hardware palette verified these positions. Modes without custom-color capability do not receive palette edits.

Other primary references consulted for comparison, not used to select a driver by VID/PID alone:

- [Apple IOHIDFamily source](https://github.com/apple-oss-distributions/IOHIDFamily/blob/main/IOHIDLib/IOHIDDeviceClass.m) explains why opening this HID device is blocked by TCC without input monitoring permission.
- [Apple TN2450](https://developer.apple.com/library/archive/technotes/tn2450/) describes system key remapping. Actual installed `hidutil property --help` confirms supported matching fields.
- [hidapi macOS implementation](https://github.com/libusb/hidapi/blob/master/mac/hid.c) was consulted for nonzero report-ID buffer conventions.
- [DeetsRGB protocol notes](https://github.com/deets-137/DeetsRGB/blob/main/docs/protocol.md) provide useful family-level comparisons. Its effect offset omissions and brightness range are not assumed for this Garnet.

No firmware, ISP, bootloader, keymap-flash, macro-flash, factory-reset or guessed vendor commands are sent. Lighting changes preserve every configuration byte except preset selector, active effect and the selected effect's two settings bytes. Restore preserves current non-lighting configuration fields.
