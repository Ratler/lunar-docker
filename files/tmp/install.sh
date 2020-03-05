#!/bin/bash

set -e

echo "-- Starting module installs"
lin moonbase
lin lunar
lin -c python-setuptools
lin -c meson
lunar renew
lin -c XOrg7
lin -c mesa-lib
lin -c git
lin -c gtk+-3
lin -c rustc

echo -e "-- End module installs\n-- Cleaning up..."
rm -rf /tmp/* /var/spool/lunar/*
echo "done."
