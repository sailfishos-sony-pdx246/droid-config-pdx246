# Feel free to disable non-critical HA parts during devel by commenting lines out
# Generated in hadk by executing: rpm/dhd/helpers/add_new_device.sh

# SPDX-FileCopyrightText: Jolla Ltd.
# SPDX-FileCopyrightText: Johannes Meyer zum Alten Borgloh
# SPDX-License-Identifier: GPL-2.0-only
#
# Generated with DEVICE=pdx246 from droid-configs-device/patterns/templates/
# patterns-sailfish-device-configuration-@DEVICE@.inc (mer-hybris/droid-hal-configs
# 1dae7f2), then edited for pdx246; NOTES.md lists every change with evidence.
# This file is included by the spec: no percent sign in comments.

%package -n patterns-sailfish-device-configuration-pdx246
Summary: Jolla Configuration pdx246
Requires: patterns-sailfish-device-configuration-common-pdx246
Requires: patterns-sailfish-device-adaptation-pdx246

# For devices with cellular modem. Those without one, please comment out:
Requires: patterns-sailfish-cellular-apps

# Early stages of porting benefit from these:
Requires: patterns-sailfish-device-tools

Requires: sailfish-content-graphics-z%{icon_res}

# For multi-SIM devices: pdx246 runs dsds (persist.radio.multisim.config) with
# IRadio on slot1 and slot2. Whether slot 2 is a physical SIM on every variant
# is still open (NOTES.md TODO).
Requires: jolla-settings-networking-multisim

# Flashlight (flash LED: leds-qpnp-flash-v2)
Requires: jolla-settings-system-flashlight

# For devices which support NFC
Requires: jolla-settings-system-nfc
Requires: nfcd-dbuslog-plugin
Requires: nfcd-mce-plugin

# Introduced starting Sailfish OS 2.0.4.x:
# 3rd party accounts like Twitter, VK, cloud services, etc
Requires: jolla-settings-accounts-extensions-3rd-party-all

# Introduced starting Sailfish OS 2.1.1.26
# Required for Jolla Store Access
Requires: patterns-sailfish-consumer-generic

# For Mozilla location services (online)
Requires: geoclue-provider-mlsdb

# Devices with 2G or more memory should also include this booster
# to improve camera startup times and the like (pdx246: 8 GB)
Requires: mapplauncherd-booster-silica-qt5-media

%description -n patterns-sailfish-device-configuration-pdx246
Pattern with packages for pdx246 configurations

%files -n patterns-sailfish-device-configuration-pdx246
