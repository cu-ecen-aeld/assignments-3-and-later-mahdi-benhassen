#!/bin/bash
# Script outline to install and build kernel.
# Author: Siddhant Jajoo.

set -e
set -u

OUTDIR=/tmp/aeld
KERNEL_REPO=git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git
KERNEL_VERSION=v5.1.10
BUSYBOX_VERSION=1_33_1
FINDER_APP_DIR=$(realpath $(dirname $0))
ARCH=arm64
CROSS_COMPILE=aarch64-none-linux-gnu-

if [ $# -lt 1 ]
then
	echo "Using default directory ${OUTDIR} for output"
else
	OUTDIR=$1
	echo "Using passed directory ${OUTDIR} for output"
fi

mkdir -p ${OUTDIR}

cd "$OUTDIR"
if [ ! -d "${OUTDIR}/linux-stable" ]; then
    #Clone only if the repository does not exist.
	echo "CLONING GIT LINUX STABLE VERSION ${KERNEL_VERSION} IN ${OUTDIR}"
	git clone ${KERNEL_REPO} --depth 1 --single-branch --branch ${KERNEL_VERSION}
fi
if [ ! -e ${OUTDIR}/linux-stable/arch/${ARCH}/boot/Image ]; then
    cd linux-stable
    echo "Checking out version ${KERNEL_VERSION}"
    git checkout ${KERNEL_VERSION}
    # TODO: Add your kernel build steps here
    make ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE clean
    make ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE mrproper
    make ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE defconfig
    make -j4 ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE all
    make ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE modules
    make ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE dtbs
fi

echo "Adding the Image in outdir"
cp -a ${OUTDIR}/linux-stable/arch/${ARCH}/boot/Image ${OUTDIR}/

echo "Creating the staging directory for the root filesystem"
cd "$OUTDIR"
if [ -d "${OUTDIR}/rootfs" ]
then
	echo "Deleting rootfs directory at ${OUTDIR}/rootfs and starting over"
    sudo rm  -rf ${OUTDIR}/rootfs
fi

# TODO: Create necessary base directories
mkdir -p rootfs/ && cd rootfs/ 
mkdir -p bin dev etc home lib lib64 proc sbin sys tmp usr/bin usr/sbin usr/lib var/log


cd "$OUTDIR"
if [ ! -d "${OUTDIR}/busybox" ]
then
git clone git://busybox.net/busybox.git
    cd busybox
    git checkout ${BUSYBOX_VERSION}
    # TODO:  Configure busybox
else
    cd busybox
fi

# TODO: Make and install busybox
#if [ ! -e "${OUTDIR}/busybox/busybox" ]; then
make distclean
make defconfig
make ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE
make CONFIG_PREFIX=${OUTDIR}/rootfs ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE install
#fi

echo "Library dependencies"
${CROSS_COMPILE}readelf -a busybox | grep "program interpreter"
${CROSS_COMPILE}readelf -a busybox | grep "Shared library"

# TODO: Add library dependencies to rootfs
export SYSROOT=$(aarch64-none-linux-gnu-gcc -print-sysroot)
cp -a ${SYSROOT}/lib/ld-linux-aarch64.so.1 ${OUTDIR}/rootfs/lib
cp -a ${SYSROOT}/lib64/ld-2.31.so ${OUTDIR}/rootfs/lib64
cp -a ${SYSROOT}/lib64/libm.so.6 ${OUTDIR}/rootfs/lib64    
cp -a ${SYSROOT}/lib64/libm-2.31.so ${OUTDIR}/rootfs/lib64 
cp -a ${SYSROOT}/lib64/libc.so.6 ${OUTDIR}/rootfs/lib64 
cp -a ${SYSROOT}/lib64/libc-2.31.so ${OUTDIR}/rootfs/lib64 
cp -a ${SYSROOT}/lib64/libresolv.so.2 ${OUTDIR}/rootfs/lib64 
cp -a ${SYSROOT}/lib64/libresolv-2.31.so ${OUTDIR}/rootfs/lib64 


# TODO: Make device nodes
cd ${OUTDIR}/rootfs/
sudo mknod -m 666 dev/null c 1 3
sudo mknod -m 600 dev/console c 5 1


cd $FINDER_APP_DIR
# TODO: Clean and build the writer utility
make clean
make CROSS_COMPILE=${CROSS_COMPILE}gcc

# TODO: Copy the finder related scripts and executables to the /home directory
# on the target rootfs
cp -a writer writer.sh finder.sh finder-test.sh autorun-qemu.sh conf/ -t ${OUTDIR}/rootfs/home # -t targetDir/
cd ${OUTDIR}/rootfs/
# TODO: Chown the root directory
find . | cpio -H newc -ov --owner root:root > ../initramfs.cpio
# TODO: Create initramfs.cpio.gz
cd .. && gzip initramfs.cpio
