FROM lunar-linux:ci-lunar
LABEL org.opencontainers.image.authors="Stefan Wold <ratler@lunar-linux.org>"

ENV PMAKES 5
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

# Always return true when kernel_option_present is called in CI
RUN echo "function kernel_option_present () { return 0; }" >> /etc/lunar/local/config

# Fix perms
RUN chmod +x /root/build-modules.sh

# Compile some stuff that we need (and fix depends before build)
RUN cat /tmp/depends >> /var/state/lunar/depends && \
    cat /tmp/depends.backup >> /var/state/lunar/depends.backup && \
    echo "MAKES=$PMAKES" > /etc/lunar/local/optimizations.GNU_MAKE && \
    bash /tmp/install.sh && \
    rm -f /tmp/install.sh
