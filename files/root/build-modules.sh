#!/bin/bash
set -e
echo "-- Setting MAKES=$PMAKES"
echo "MAKES=$PMAKES" > /etc/lunar/local/optimizations.GNU_MAKE
cp -rv /zlocal/* /var/lib/lunar/moonbase/zlocal/

lin moonbase

for module in $(lsh sort_by_dependency $(lvu section zlocal)); do
  if [ "$module" == "iptables" ]; then
    lrm $module
  fi
  lin -c $module || exit 1
  echo ""
  echo "# Installed files for $module"
  echo ""
  PAGER="cat" lvu install $module
  echo ""
done
