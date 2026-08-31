# SPIRIT phone CM5 kernel / device-tree remaining work

This is the hardware-enablement map for `spirit-phone-cm5`. It is **honest:
untested on SPIRIT hardware**. Nodes in the overlay are `status = "disabled"`
until carrier pinmux is known.

Parent tracker: [SPIRIT-org/meta-spirit#3](https://github.com/SPIRIT-org/meta-spirit/issues/3).

Sources used (read-only):

- This layer: `recipes-kernel/linux/`
- Hardware: [SPIRIT-org/SPIRIT](https://github.com/SPIRIT-org/SPIRIT) `EDA-kicad/`
  (GSM-GPS, audio, power, camera, screen)
- Kernel: [raspberrypi/linux `rpi-6.12.y`](https://github.com/raspberrypi/linux/tree/rpi-6.12.y)

**Rule:** if the schematic does not clearly document a BCM2712 GPIO number,
the DT uses a TODO comment rather than a guessed `gpios = <...>`. Net names
(e.g. `AUDIO_SCL`, `USB_DP`) are recorded for the person who maps the CM5
connector.

## What landed in this BSP increment

| Piece | Path | Status |
| --- | --- | --- |
| Board DTS | `recipes-kernel/linux/files/spirit-phone-cm5/bcm2712-spirit-phone-cm5.dts` | Includes RPi 5 board file + overlay |
| Overlay | `.../spirit-phone-cm5.dtsi` | Disabled placeholders for #4-#8 |
| Kernel fragment | `.../spirit-phone-cm5.cfg` | `=m` for USB modem + audio codecs |
| Recipe | `linux-raspberrypi_%.bbappend` | SRC_URI for DTS + `.cfg` |
| dtc CI | `.github/workflows/dtc.yml` | Addresses #11 |

## Issue map (#4-#9)

### #4 TPS650250 / TPS65023-family PMIC

- **DT:** `spirit_pmic` `compatible = "ti,tps65023"; status = "disabled"`.
- **Do not fake a tps650250 driver.** No binding exists in mainline,
  raspberrypi/linux 6.12, or TI's tree. Closest upstream is the tps65020/21/23
  family (`Documentation/devicetree/bindings/regulator/tps65023.txt`).
- **Schematic note:** `EDA-kicad/power.kicad_sch` currently instantiates
  **TPS65023BRSBR** (that family), while issue #4 names **TPS650250RHBR**.
  Part choice vs. issue text is TBD.
- **TODO:** I2C bus, `reg` (example binding uses `0x48`), INT_N / HOT_RESET_N
  BCM2712 GPIOs. `CONFIG_REGULATOR_TPS65023` left unset until that is known.

### #5 BQ25792 charger (`ti,bq25792`)

- **DT:** `bq25792` `compatible = "ti,bq25792"; status = "disabled"`.
- Binding: `Documentation/devicetree/bindings/mfd/ti,bq25703a.yaml`
  (`reg` is const `0x6b`).
- Schematic: I2C SCL/SDA, `~{INT}`, `~{CE}` ("connect CE to any remaining CM
  GPIO"). **No BCM2712 GPIO numbers.**
- **Kernel 6.12:** `CONFIG_REGULATOR_BQ25792` / `CONFIG_CHARGER_BQ257XX` /
  `CONFIG_MFD_BQ257XX` **do not exist** on `rpi-6.12.y`. They landed in
  mainline ~6.18. The fragment documents the future symbols; it does not set
  them. DT is still added so a later kernel can bind.
- **TODO:** I2C parent, INT GPIO, CE GPIO, `monitored-battery`,
  `power-supplies`, input-current-limit. Then backport or bump kernel.

### #6 TLV320AIC3204 (`ti,tlv320aic32x4`)

- **DT:** `tlv320aic3204` `compatible = "ti,tlv320aic32x4"; status = "disabled"`.
- Binding exists (`ti,tlv320aic32x4.yaml`). Datasheet I2C default is `0x18`
  (confirm ADDR pins before enabling).
- Nets: `AUDIO_SCL`, `AUDIO_SDA`, `AUDIO_MCLK`, `AUDIO_BCLK_I2S`,
  `AUDIO_WCLK_I2S`, `AUDIO_SOUND_DATA`, `AUDIO_RESET`. MFP5 is "any remaining
  gpio". **No BCM2712 GPIO numbers.**
- **Kernel 6.12:** `CONFIG_SND_SOC_TLV320AIC32X4_I2C=m` (selects
  `CONFIG_SND_SOC_TLV320AIC32X4`). `CONFIG_SND_SOC_TLV320AIC3X` is a different
  family and is **not** enabled.
- **TODO:** I2C bus + `reg`, MCLK clock phandle, reset GPIO, simple-audio-card
  / audio-graph card linking BCM2712 I2S to this codec. Supplies
  (`iov-supply`, `ldoin-supply` or av/dv).

### #7 SPH0645LM4H-B digital mic

- **DT:** `sph0645_dmic` `compatible = "invensense,ics43432"; status = "disabled"`.
- **No SPH0645-specific binding.** The part is an I2S MEMS mic with no control
  bus; `invensense,ics43432` is the upstream compatible
  (`invensense,ics43432.yaml`). Community RPi overlay
  (AntarcticBear/sph0645lm4h-rpi) is not upstream.
- Nets: `AUDIO_BCLK_I2S`, `AUDIO_WCLK_I2S`, `AUDIO_MIC_DATA`. SELECT is wired
  left-channel. **No BCM2712 GPIO numbers.**
- **Kernel 6.12:** `CONFIG_SND_SOC_ICS43432=m`.
- **TODO:** I2S pinmux + machine DAI link. May share BCLK/WCLK with the
  AIC3204 once both are enabled.

### #8 EG25-G USB modem (one modem)

- **DT:** `eg25_usb_modem` `compatible = "usb2c7c,0125"; status = "disabled"`.
- **USB, not a custom bus.** Expected interface:
  - VID:PID `2c7c:0125` (EG25-G / EC25 family)
  - Pins on GSM-GPS sheet: `USB_DP`, `USB_DM`, `USB_VBUS`, `USB_BOOT`
  - Host: `option` -> `/dev/ttyUSB*` (AT), `qmi_wwan` -> `wwan` / `cdc-wdm` (QMI)
- Target SKU: **EG25GGB-256-SGNS** (maintainer). Schematic still names
  EG25GGC-128-SGNS; USB identity is the same.
- Optional `PWRKEY`, `RESET_N`, `W_DISABLE#` have **no BCM2712 GPIO** in the
  schematic.
- **Kernel 6.12:** `CONFIG_USB_SERIAL_OPTION=m`, `CONFIG_USB_NET_QMI_WWAN=m`.
- **TODO:** which CM5 USB port/hub; optional power-key GPIO; ModemManager /
  ofono in userland (out of scope for this BSP increment). Enumeration can
  work with DT still disabled once USB host is up.

### #9 EC25 (unused / DNP)

- Hardware / symbol library still has **EC25VFA-512-STD**.
- Maintainer wants **EG25GGB-256-SGNS only**.
- **No EC25 DT node.** Dual LTE is documented as unused/DNP in the overlay
  comment and here. Do not enable a second modem.

## Pinmux TODOs (unknown BCM2712 GPIOs)

Leave these unset until the CM5 connector map is written down from the
carrier (not guessed):

| Function | Schematic net(s) | DT property needed |
| --- | --- | --- |
| Codec/charger/PMIC I2C | `AUDIO_SCL`/`AUDIO_SDA`; BQ25792 SCL/SDA; PMIC SCLK/SDAT | I2C controller phandle + `reg` |
| Codec I2S | `AUDIO_BCLK_I2S`, `AUDIO_WCLK_I2S`, `AUDIO_SOUND_DATA` | I2S pinmux + DAI link |
| Mic I2S | `AUDIO_BCLK_I2S`, `AUDIO_WCLK_I2S`, `AUDIO_MIC_DATA` | I2S pinmux + DAI link |
| Codec MCLK | `AUDIO_MCLK` | `clocks` / `clock-names = "mclk"` |
| Codec reset | `AUDIO_RESET` | `reset-gpios` |
| Charger INT / CE | `~{INT}`, `~{CE}` | `interrupts`, enable GPIO |
| EG25 USB | `USB_DP`/`USB_DM`/`USB_VBUS` | USB host port |
| EG25 extras | `PWRKEY`, `RESET_N`, `W_DISABLE#` | optional GPIOs |
| PMIC extras | `INT_N`, `HOT_RESET_N` | optional GPIOs |

Camera and screen sheets were not given kernel fragments in this increment
(not in #4-#9).

## dtc CI (issue #11)

- Workflow: [`.github/workflows/dtc.yml`](.github/workflows/dtc.yml)
- Script: [`scripts/check-dts.sh`](scripts/check-dts.sh)
- Runs `dtc -I dts -o /dev/null` on `bcm2712-spirit-phone-cm5.dts` (after `cpp`)
  and on the DTSI as a wrapped fragment.
- **Include limitation:** the board DTS `#include "bcm2712-rpi-5-b.dts"` lives
  in raspberrypi/linux, not this layer. CI uses
  [`.github/dtc-stubs/bcm2712-rpi-5-b.dts`](.github/dtc-stubs/bcm2712-rpi-5-b.dts)
  so SPIRIT overlay syntax is still checked. Full compile with RPi includes is
  the Yocto `linux-raspberrypi` build (not run in this CI; needs 50-100 GB).
- A repo `pre-commit` hook was requested on #11 but is not added here.

## Kernel fragment caveats

`linux-raspberrypi` applies `*.cfg` from `SRC_URI` as a merge fragment.
Unknown `CONFIG_*` symbols can fail the kernel config step, so BQ25792
symbols are commented until the kernel version provides them.

Local check (no Yocto):

```sh
sudo apt-get install device-tree-compiler
bash scripts/check-dts.sh
```
