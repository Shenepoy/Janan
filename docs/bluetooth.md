# Bluetooth devices

Turn on Bluetooth input in **Settings → Bluetooth**, then add a meter or scale from **Settings → Bluetooth devices**. You can pull a reading while adding an entry, or sync saved devices when the app opens.

Weight features must be on for scales (**Settings → Features**). The first scale reading turns them on if they were off.

There is no warranty on this list. Devices are reported by users or tested here. If yours works and is missing, add it.

---

## Blood pressure meters

Any meter that implements the Bluetooth [Blood Pressure Service (`0x1810`)](https://www.bluetooth.com/specifications/specs/blood-pressure-service-1-1-1/) and [Blood Pressure Measurement (`0x2A35`)](https://www.bluetooth.com/specifications/assigned-numbers/) can work. Some brands use their own protocol (Yonker, Microlife).

| Device | Bluetooth name | Protocol | Tested | Notes |
|--------|----------------|:--------:|:------:|-------|
| HealthForYou by Silvercrest (SBM 69) | SBM69 | GATT | ✅ | Reads multiple stored readings |
| Omron X4 Smart | X4 Smart | GATT | ✅ | Deletes readings after transfer |
| Omron X2 Smart+ | X2 Smart+ | GATT | ✅ | |
| Omron Bronze BP5150 | BLESmart_(long id) | GATT | ✅ | |
| Beurer BM59 | BM 59 | GATT | ✅ | Reads multiple |
| Beurer BM85 | Beurer BM85 | GATT | ✅ | Reads multiple |
| Yonker YK-IBPA1 | | Yonker | ✅ | Connect after the measurement |
| Yonker YK-BPW5 | | Yonker | ? | |
| Yongrow YK-IBPA1 | | Yonker | ? | |
| METIKO MT-YK-BPA1 | | Yonker | ? | |
| Microlife BP3GY1-2N | BP3GY1-2N | Microlife | ? | Downloads all stored readings |

The standard GATT profile applies swapped-field and hidden-user-ID decoding
only to BM85, backed by recorded packets. BM48 and ELITE900 remain recognized
names but use standard decoding; their decoding has not been verified here
with device captures. Recognition alone is not a compatibility test.

### How meters send data

Meters differ in when they talk and what they send.

1. Right after a measurement
   1. All readings in memory
   2. Only the latest reading
2. A separate download mode
   1. Wipes the meter after a successful transfer
   2. Leaves the meter’s memory as-is

> [!CAUTION]
> Case 2.i is not well supported. Do not use it unless you are fine losing readings that are still only on the meter.

In **Settings → Bluetooth devices** you can import the last reading or all stored readings, trust the meter’s clock, and sync saved devices on launch.

---

## Scales

Scales are optional. Enable weight features, save the scale, then weigh and sync (or add from the Weight tab). Stay on the scale until the reading settles so impedance can arrive; an early disconnect can save weight only.

Fill **Settings → Features → Body profile** (height, birth year, sex) if you want estimated body composition. Numbers are calculated in the app and can differ from the vendor’s app.

| Device | Bluetooth name | Protocol | Tested | Notes |
|--------|----------------|:--------:|:------:|-------|
| Eufy Smart Scale P1 / C1 / A1 | eufy T9147, T9146, T9120 | Eufy P1 | ✅ T9147 | Weight plus optional impedance. Body composition when a profile is set. |
| Eufy Smart Scale P2 / P2 Pro / P3 | T9130, T9140, T9148, T9149, T9150 | Encrypted | ❌ | Not supported. The app recognizes them and stops with an error. |

### Eufy P1

The P1 family (C1 / P1 / A1, model numbers T9146, T9147, T9120) talks over an unencrypted `fff0` service. This fork reads the settled weight and, when the scale sends it, foot-to-foot impedance.

Open the weight detail screen to see BMI and, with a body profile, fat %, muscle, bone, water, lean mass, and BMR. Athlete mode on the profile changes the estimate.

P2, P2 Pro, and P3 use an encrypted handshake that is not implemented.

---

## Specifications

Useful if you are adding a device.

- [Blood Pressure Service](https://www.bluetooth.com/specifications/specs/blood-pressure-service-1-1-1/)
- [Assigned numbers](https://www.bluetooth.com/specifications/assigned-numbers/) (service and characteristic UUIDs)
- [GATT Specification Supplement](https://www.bluetooth.com/specifications/gss/)
- [Current Time Service](https://www.bluetooth.com/specifications/specs/current-time-service-1-1/)

| Family | How it is recognized |
|--------|----------------------|
| GATT blood pressure | Service `1810`, characteristic `2A35` |
| Yonker / Yongrow / METIKO | Vendor service `cdeacd80-…` |
| Microlife | Service `fff0` (`fff1` notify, `fff2` write) |
| Eufy P1 | Service `fff0`, notify `fff4`, no `fff2` |
| Eufy P2 (unsupported) | `fff4` plus `fff2` |
