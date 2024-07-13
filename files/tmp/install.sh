#!/bin/bash

set -e

echo "-- Starting module installs"
lin moonbase
lin lunar
lin -c python-setuptools
lin -c meson
lunar renew
lin -c gobject-introspection
lin -c gegl
lin -c libepoxy
lin -c mesa-lib
lin -c libepoxy
lin -c XOrg7
lin -c git
lin -c gtk+-3

echo -e "-- End module installs\n-- Cleaning up..."
rm -rf /tmp/* /var/spool/lunar/*
echo "done."
