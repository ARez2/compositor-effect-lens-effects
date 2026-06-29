#!/bin/bash

cp -r ./addons/ /tmp/addons/

ls /tmp/addons

cp ./README.md /tmp/addons/lens_effects/README.md
cp ./LICENSE /tmp/addons/lens_effects/LICENSE

# FS = file sync = basically overwrite old zip instead of update
(cd /tmp/ && zip -FSr ~/Downloads/lens-effects-release addons)
rm -r /tmp/addons
