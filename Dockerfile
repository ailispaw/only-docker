FROM ubuntu:14.10
RUN apt-get update
RUN apt-get install -y bc
RUN apt-get build-dep -y --no-install-recommends iptables
# This causes iptables to fail to compile... don't know why yet
RUN apt-get purge -y libnfnetlink-dev

# Build static iptables
COPY iptables-1.4.21.tar.bz2 /usr/src/
RUN cd /usr/src && \
    tar xjf iptables-1.4.21.tar.bz2 && \
    cd iptables-1.4.21 && \
    ./configure --enable-static --disable-shared && \
    make -j4 LDFLAGS="-all-static"

# Build kernel
ENV KERNEL_VERSION 3.18.7
COPY linux-$KERNEL_VERSION.tar.xz /usr/src/
RUN cd /usr/src && \
    tar xJf linux-$KERNEL_VERSION.tar.xz
COPY assets/kernel_config /usr/src/linux-$KERNEL_VERSION/.config
RUN cd /usr/src/linux-$KERNEL_VERSION && \
    make oldconfig
RUN apt-get install -y bc
RUN cd /usr/src/linux-$KERNEL_VERSION && \
    make -j4 bzImage
RUN cd /usr/src/linux-$KERNEL_VERSION && \
    make -j4 modules
RUN mkdir -p /usr/src/root && \
    cd /usr/src/linux-$KERNEL_VERSION && \
    make INSTALL_MOD_PATH=/usr/src/root modules_install firmware_install

# Taken from boot2docker
# Remove useless kernel modules, based on unclejack/debian2docker
RUN cd /usr/src/root/lib/modules && \
    rm -rf ./*/kernel/sound/* && \
    rm -rf ./*/kernel/drivers/gpu/* && \
    rm -rf ./*/kernel/drivers/infiniband/* && \
    rm -rf ./*/kernel/drivers/isdn/* && \
    rm -rf ./*/kernel/drivers/media/* && \
    rm -rf ./*/kernel/drivers/staging/lustre/* && \
    rm -rf ./*/kernel/drivers/staging/comedi/* && \
    rm -rf ./*/kernel/fs/ocfs2/* && \
    rm -rf ./*/kernel/net/bluetooth/* && \
    rm -rf ./*/kernel/net/mac80211/* && \
    rm -rf ./*/kernel/net/wireless/*

# Install cross-compiler
COPY cross-compiler-x86_64.tar.bz2 /usr/src/
RUN cd /usr/src && tar xjf cross-compiler-x86_64.tar.bz2

# Build static busybox
ENV BUSYBOX_VERSION 1.23.1
COPY busybox-$BUSYBOX_VERSION.tar.bz2 /usr/src/
RUN cd /usr/src && \
    tar xjf busybox-$BUSYBOX_VERSION.tar.bz2 && \
    cd busybox-$BUSYBOX_VERSION && \
    export PATH=$PATH:/usr/src/cross-compiler-x86_64/bin && \
    make defconfig && \
    sed -e 's/.*FEATURE_PREFER_APPLETS.*/CONFIG_FEATURE_PREFER_APPLETS=y/' -i .config  && \
    sed -e 's/.*FEATURE_SH_STANDALONE.*/CONFIG_FEATURE_SH_STANDALONE=y/' -i .config  && \
    sed -e 's/.*FEATURE_TOUCH_NODEREF=y/# CONFIG_FEATURE_TOUCH_NODEREF is not set/' -i .config && \
    LDFLAGS="--static" make CROSS_COMPILE=x86_64- busybox

# Build static dropbear
ENV DROPBEAR_VERSION 2015.67
COPY dropbear-$DROPBEAR_VERSION.tar.bz2 /usr/src/
RUN cd /usr/src && \
    tar xjf dropbear-$DROPBEAR_VERSION.tar.bz2 && \
    cd dropbear-$DROPBEAR_VERSION && \
    export PATH=$PATH:/usr/src/cross-compiler-x86_64/bin && \
    export CC=x86_64-gcc && \
    ./configure --disable-zlib --host=x86_64 && \
    make PROGRAMS="dropbear dbclient dropbearkey dropbearconvert scp" MULTI=1 STATIC=1

# Install docker
ENV DOCKER_VERSION 1.5.0
RUN apt-get install -y ca-certificates
COPY docker-$DOCKER_VERSION.tgz /usr/src/
RUN mkdir -p /usr/src/root/bin && \
    tar xvzf /usr/src/docker-$DOCKER_VERSION.tgz --strip-components=3 -C /usr/src/root/bin

# Create dhcp image
RUN /usr/src/root/bin/docker -s vfs -d --bridge none & \
    sleep 1 && \
    /usr/src/root/bin/docker pull busybox && \
    /usr/src/root/bin/docker run --name export busybox false ; \
    /usr/src/root/bin/docker export export > /usr/src/root/.dhcp.tar

# Install isolinux
RUN apt-get install -y \
    isolinux \
    xorriso

# Start assembling root
ENV ONLY_DOCKER_VERSION 0.6.0
RUN mkdir -p /usr/src/root/etc
COPY assets/os-release /usr/src/root/etc/
RUN sed -e "s/%ONLY_DOCKER_VERSION%/$ONLY_DOCKER_VERSION/" -i /usr/src/root/etc/os-release && \
    sed -e "s/%BUSYBOX_VERSION%/$BUSYBOX_VERSION/" -i /usr/src/root/etc/os-release
COPY assets/init /usr/src/root/
COPY assets/console-container.sh /usr/src/root/bin/
RUN cd /usr/src/root/bin && \
    cp /usr/src/busybox-$BUSYBOX_VERSION/busybox . && \
    chmod u+s busybox && \
    ./busybox --list | ./busybox xargs -n1 ./busybox ln -s busybox && \
    cp /usr/src/iptables-1.4.21/iptables/xtables-multi iptables && \
    strip --strip-all iptables && \
    cp /usr/src/dropbear-$DROPBEAR_VERSION/dropbearmulti . && \
    for i in dropbear dbclient dropbearkey dropbearconvert scp; do \
        ln -s dropbearmulti $i; \
    done && \
    cd .. && \
    mkdir -p ./etc/ssl/certs && \
    cp /etc/ssl/certs/ca-certificates.crt ./etc/ssl/certs && \
    ln -s bin sbin
RUN mkdir -p /usr/src/only-docker/boot && \
    cd /usr/src/root && \
    find | cpio -H newc -o | lzma -c > ../only-docker/boot/initrd && \
    cp /usr/src/linux-$KERNEL_VERSION/arch/x86_64/boot/bzImage ../only-docker/boot/vmlinuz
RUN mkdir -p /usr/src/only-docker/boot/isolinux && \
    cp /usr/lib/ISOLINUX/isolinux.bin /usr/src/only-docker/boot/isolinux && \
    cp /usr/lib/syslinux/modules/bios/ldlinux.c32 /usr/src/only-docker/boot/isolinux
COPY assets/isolinux.cfg /usr/src/only-docker/boot/isolinux/
# Copied from boot2docker, thanks.
RUN cd /usr/src/only-docker && \
    xorriso \
        -publisher "Rancher Labs, Inc." \
        -as mkisofs \
        -l -J -R -V "ONLY_DOCKER" \
        -no-emul-boot -boot-load-size 4 -boot-info-table \
        -b boot/isolinux/isolinux.bin -c boot/isolinux/boot.cat \
        -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
        -o /only-docker.iso $(pwd)

CMD ["cat", "only-docker.iso"]
