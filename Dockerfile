FROM lunar-linux:ci-lunar
MAINTAINER Stefan Wold <ratler@lunar-linux.org>

ENV PMAKES 30
ENV SHELL=/bin/bash
ENV USER=root

COPY files/ /

# Some sane defaults
RUN lunar set ACCEPTED_LICENSES all && \
    lunar set ARCHIVE off && \
    lunar set AUTOFIX on && \
    lunar set KEEP_SOURCE off && \
    lunar set ZLOCAL_OVERRIDES on && \
    lunar set COLOR off && \
    lunar set COMPRESS_METHOD bz2 && \
    lunar set SAFE_OPTIMIZATIONS on && \
    lunar set BOOTLOADER none && \
    lunar set PROMPT_DELAY 0 && \
    lunar set KEEP_OBSOLETE_LIBS off

# Fix perms
RUN chmod +x /root/build-modules.sh

# Compile some stuff that we need (and fix depends before build)
RUN cat /tmp/depends >> /var/state/lunar/depends && \
    cat /tmp/depends.backup >> /var/state/lunar/depends.backup && \
    echo "MAKES=$PMAKES" > /etc/lunar/local/optimizations.GNU_MAKE && \
    bash /tmp/install.sh && \
    rm -f /tmp/install.sh
