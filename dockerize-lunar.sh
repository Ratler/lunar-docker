help() {
  echo "foo"
}

chroot_run() {
  local RESULT
  # mount --bind /proc $TARGET/proc
  # mount --bind /dev $TARGET/dev
  # mount --bind /tmp $TARGET/tmp
  # mount --bind /sys $TARGET/sys
  # mount --bind /run $TARGET/run
  chroot $TARGET "$@"
  RESULT=$?
  # umount $TARGET/run
  # umount $TARGET/sys
  # umount $TARGET/tmp
  # umount $TARGET/dev
  # umount $TARGET/proc

  # debug the problem in case there is one
  if [ $RESULT == 1 ] ; then
    (
    echo ""
    echo "ERROR: An error occurred while executing a command. The command was:"
    echo "ERROR: \"$@\""
    echo "ERROR: "
    echo "ERROR: You should inspect any output above and retry the command with"
    echo "ERROR: different input or parameters. Please report the problem if"
    echo "ERROR: you think this error is displayed by mistake."
    echo ""
    echo "Press ENTER to continue"
    read JUNK
    ) >&2
  fi
  return $RESULT
}

transfer_package() {
  echo "Transfering $1..."
  cd $TARGET &&
  LINE=$(grep "^$1:" $PACKAGES_LIST)
  MOD=$(echo $LINE | cut -d: -f1)
  VER=$(echo $LINE | cut -d: -f4)
  #cp "$ROOTFS"/var/cache/lunar/$MOD-$VER-*.tar.xz $TARGET/var/cache/lunar/
  tar xJf "$ROOTFS"/var/cache/lunar/$MOD-$VER-*.tar.xz 2> /dev/null
  echo $LINE >> $TARGET/var/state/lunar/packages
  cp $TARGET/var/state/lunar/packages $TARGET/var/state/lunar/packages.backup
}


main() {
  local ISOMNT SQFSMNT PACKAGES_LIST MOONBASE_TAR

  cleanup() {
    cd /tmp
    for m in $ROOTFS $SQFSMNT $ISOMNT; do
      umount -f $m &> /dev/null
      rm -r "$m"
    done
    rm -rf "$TARGET"
  }

  trap "cleanup; exit 1" INT TERM KILL

  ISOMNT=$(mktemp -d /tmp/lunar-docker-iso.XXXXXX)
  SQFSMNT=$(mktemp -d /tmp/lunar-docker-sqfs.XXXXXX)
  export ROOTFS=$(mktemp -d /tmp/lunar-docker-rootfs.XXXXXX)
  export TARGET=${TARGET:-$(mktemp -d /tmp/lunar-docker.XXXXXX)}
  PACKAGES_LIST="$ROOTFS"/var/cache/lunar/packages
  MOONBASE_TAR="$ROOTFS"/usr/share/lunar-install/moonbase.tar.bz2


  if ! mount -o ro,loop $LUNAR_ISO $ISOMNT; then
    echo "Failed to mount ISO $LUNAR_ISO"
    exit 1
  else
    echo "Mounting $LUNAR_ISO at $ISOMNT"
  fi

  if ! mount -o ro,loop "$ISOMNT"/LiveOS/squashfs.img $SQFSMNT; then
    echo "Failed to mount $ISOMNT/LiveOS/squashfs.img, is this really a Lunar Linux ISO?"
    exit 1
  else
    echo "Mounting squashfs.img at $SQFSMNT"
  fi

  if ! mount -o ro,loop "$SQFSMNT"/LiveOS/rootfs.img $ROOTFS; then
    echo "Failed to mount $SQFSMNT/LiveOS/rootfs.img, is this really a Lunar Linux ISO?"
    exit 1
  else
    echo "Mounting rootfs.img at $ROOTFS"
  fi

  if [ -n "$STOP_ISO_TARGET" ]; then
    cd $ROOTFS
    bash
    exit 1
  fi

  cd $TARGET
  mkdir -p bin boot dev etc home lib mnt media
  mkdir -p proc root sbin srv tmp usr var opt
  mkdir -p sys
  if [ `arch` == "x86_64" ]; then
    ln -sf lib lib64
    ln -sf lib usr/lib64
  fi
  mkdir -p usr/{bin,games,include,lib,libexec,local,sbin,share,src}
  mkdir -p usr/share/{dict,doc,info,locale,man,misc,terminfo,zoneinfo}
  mkdir -p usr/share/man/man{1,2,3,4,5,6,7,8}
  ln -sf share/doc usr/doc
  ln -sf share/man usr/man
  ln -sf share/info usr/info
  mkdir -p etc/lunar/local/depends
  mkdir -p run/lock
  ln -sf ../run var/run
  ln -sf ../run/lock var/lock
  mkdir -p var/log/lunar/{install,md5sum,compile,queue}
  mkdir -p var/{cache,empty,lib,log,spool,state,tmp}
  mkdir -p var/{cache,lib,log,spool,state}/lunar
  mkdir -p var/state/discover
  mkdir -p var/spool/mail
  mkdir -p media/{cdrom0,cdrom1,floppy0,floppy1,mem0,mem1}
  chmod 0700 root
  chmod 1777 tmp var/tmp

  if [ -f "$ROOTFS"/var/cache/lunar/aaa_base.tar.xz ]; then
    tar xJf "$ROOTFS"/var/cache/lunar/aaa_base.tar.xz 2> /dev/null
  fi
  if [ -f "$ROOTFS"/var/cache/lunar/aaa_dev.tar.xz ]; then
    tar xJf "$ROOTFS"/var/cache/lunar/aaa_dev.tar.xz 2> /dev/null
  fi

  for LINE in $(cat $PACKAGES_LIST | grep -v -e '^lilo:' -e '^grub:' -e '^grub2:' -e '^linux:' -e '^linux-firmware') ; do
    MOD=$(echo $LINE | cut -d: -f1)
    VER=$(echo $LINE | cut -d: -f4)
    SIZ=$(echo $LINE | cut -d: -f5)
    transfer_package $MOD
  done

  DATE=$(date +%Y%m%d)

  (
    cd $TARGET/var/lib/lunar
    tar xjf $MOONBASE_TAR 2> /dev/null
    tar j --list -f $MOONBASE_TAR | sed 's:^:/var/lib/lunar/:g' > $TARGET/var/log/lunar/install/moonbase-$DATE
    mkdir -p moonbase/zlocal
  )
  echo "moonbase:$DATE:installed:$DATE:37000KB" >> $TARGET/var/state/lunar/packages
  cp $TARGET/var/state/lunar/packages $TARGET/var/state/lunar/packages.backup
  cp "$ROOTFS"/var/state/lunar/depends        $TARGET/var/state/lunar/
  cp "$ROOTFS"/var/state/lunar/depends.backup $TARGET/var/state/lunar/

  chroot_run lsh create_module_index
  chroot_run lsh create_depends_cache

  # more moonbase related stuff
  chroot_run lsh update_plugins

  # just to make sure
  chroot_run ldconfig

  # pass through some of the configuration at this point:
  chroot_run systemd-machine-id-setup 2> /dev/null
  echo -e "KEYMAP=$KEYMAP\nFONT=$CONSOLEFONT" > $TARGET/etc/vconsole.conf
  echo -e "LANG=${LANG:-en_US.utf8}\nLC_ALL=${LANG:-en_US.utf8}" > $TARGET/etc/locale.conf
  [ -z "$EDITOR" ] || echo "export EDITOR=\"$EDITOR\"" > $TARGET/etc/profile.d/editor.rc

  # some more missing files:
  cp "$ROOTFS"/etc/lsb-release $TARGET/etc/
  cp "$ROOTFS"/etc/os-release $TARGET/etc/
  cp "$ROOTFS"/etc/issue{,.net} $TARGET/etc/

  # Some sane defaults
  GCCVER=$(chroot_run lvu installed gcc | awk -F\. '{ print $1"_"$2 }')

  cat <<EOF> $TARGET/etc/lunar/local/config
  LUNAR_COMPILER="GCC_$GCCVER"
 LUNAR_ALIAS_SSL="openssl"
LUNAR_ALIAS_OSSL="openssl"
LUNAR_ALIAS_UDEV="systemd"
LUNAR_ALIAS_KMOD="kmod"
LUNAR_ALIAS_UDEV="systemd"
LUNAR_ALIAS_KERNEL_HEADERS="kernel-headers"
BOOTLOADER="none"
LUNAR_RESTART_SERVICES=off
EOF

  # Disable services (user can choose to enable them using services menu)
  rm -f $TARGET/etc/systemd/system/network.target.wants/wpa_supplicant.service
  rm -f $TARGET/etc/systemd/system/sockets.target.wants/sshd.socket

  # root user skel files
  find $TARGET/etc/skel ! -type d | xargs -i cp '{}' $TARGET/root

  # Create docker image based on $TARGET
  cd $TARGET
  . etc/lsb-release
  echo "Creating docker image..."
  tar -c . | docker import - lunar-linux:${DISTRIB_RELEASE%-*}
  if [ -n "$EXTRATAG" ]; then
    docker tag lunar-linux:${DISTRIB_RELEASE%-*} lunar-linux:$EXTRATAG
  fi
  docker images | grep ^lunar-linux

  echo -n "Cleaning up..."
  cleanup
  echo "done."
}

GETOPT_ARGS=$(getopt -q -n dockerize-lunar.sh -o "i:t:e:" -l "iso:,targetdir:,extratag:,stop-iso" -- "$@")

if [ -z "$?" ]; then
  help
  exit
else
  if [ "$UID" != "0" ]; then
    echo "User must have root privileges to run this script"
    exit 1
  fi

  eval set -- $GETOPT_ARGS

  while true; do
    case "$1" in
      -i|--iso) export LUNAR_ISO=$2; shift 2 ;;
      -t|--targetdir) export TARGET=$2; shift 2 ;;
      -e|--extratag) export EXTRATAG=$2; shift 2 ;;
      -h|--help) help; exit 1 ;;
      --stop-iso) export STOP_ISO_TARGET=1; shift 1 ;;
      --) shift; break ;;
      *) help; exit 1 ;;
    esac
  done

  if [ -z "$LUNAR_ISO" ]; then
    echo "arg -i|--iso is required"
    exit 1
  fi

  if [ ! -f "$LUNAR_ISO" ]; then
    echo "$LUNAR_ISO file not found"
    exit 1
  fi

  main $@
fi
