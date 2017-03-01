# run : cd /etc/signify && signify -G -p stable.pub -s stable.sec && cd -
PKG_SIGN_STRING=-s signify -s /etc/signify/stable.sec

OSREV=5.9
KERNEL=GENERIC.MP GENERIC
PARALLEL_BUILD=yes

MAINTAINER="Wesley MOUEDINE ASSABY <milo974@gmail.com>"

# List of patches for userland/X11
PATCH_COMMON=001_sshd 005_crypto 006_smtpd 009_crypto 010_libexpat 011_crypto 012_crypto 021_relayd 024_perl 025_relayd 027_libssl 028_libssl 029_xorg_libs 030_ssh_kexinit 031_smtpd 032_libssl 033_libcrypto 034_httpd

# List of kernel patches
PATCH_KERNEL=002_in6bind 003_pledge 004_mbuf 007_uvideo 008_bnx 013_splice 014_unp 015_dirent 016_mmap 017_arp 018_timeout 019_kevent 020_amap 022_sysctl 023_uvmisavail 026_wsfont

# Define type of rollback support ('all' or 'kernel'), set to 'none' to disable.
ROLLBACK=all

#===========================================================================
# The patch targets start here.
#
# Care should be taken for writing valid rules for make.
# The instructions must be taken from the top of each patch file, with some
# rewrites:
#
# - Paths relative to src/ must be made relative to ${WRKSRC}/
# - make targets must be changed for their counterparts provided by binpatch:
#	make obj:		${_obj}
#	make cleandir:		${_cleandir}
#	make depend:		${_depend}
#	make install:		${_install}
#	make && make install:	${_build}
#
#	make -f Makefile.bsd-wrapper obj:		${_obj_wrp}
#	make -f Makefile.bsd-wrapper cleandir:		${_cleandir_wrp}
#	make -f Makefile.bsd-wrapper depend:		${_depend_wrp}
#	make -f Makefile.bsd-wrapper && \
#		make -f Makefile.bsd-wrapper install:	${_build_wrp}
#	make -f Makefile.bsd-wrapper install:		${_install_wrp}
#
#

001_sshd:
	cd ${WRKSRC}/usr.bin/ssh &&  ${_obj} && ${_depend} && ${_build}

002_in6bind: _kernel

003_pledge: _kernel

004_mbuf: _kernel

005_crypto:
	cd ${WRKSRC}/lib/libcrypto &&  ${_obj} && ${_depend} && ${_build}

006_smtpd:
	cd ${WRKSRC}/usr.sbin/smtpd &&  ${_obj} && ${_depend} && ${_build}

007_uvideo: _kernel

008_bnx: _kernel

009_crypto:
	cd ${WRKSRC}/lib/libcrypto &&  ${_obj} && ${_depend} && ${_build}

010_libexpat:
	cd ${WRKSRC}/lib/libexpat &&  ${_obj} && ${_depend} && ${_build}

011_crypto:
	cd ${WRKSRC}/lib/libcrypto &&  ${_obj} && ${_depend} && ${_build}

012_crypto:
	cd ${WRKSRC}/lib/libcrypto &&  ${_obj} && ${_depend} && ${_build}

013_splice: _kernel

014_unp: _kernel

015_dirent: _kernel

016_mmap: _kernel

017_arp: _kernel

018_timeout: _kernel

019_kevent: _kernel

020_amap: _kernel

021_relayd:
	cd ${WRKSRC}/usr.sbin/relayd &&  ${_obj} && ${_depend} && ${_build}

022_sysctl: _kernel

023_uvmisavail: _kernel

024_perl:
	cd ${WRKSRC}/gnu/usr.bin/perl && ${_obj_wrp} && ${_depend_wrp} && ${_build_wrp}

025_relayd:
	cd ${WRKSRC}/usr.sbin/relayd &&  ${_obj} && ${_depend} && ${_build}	

026_wsfont: _kernel

027_libssl:
	cd ${WRKSRC}/lib/libssl && ${_obj} && ${_depend} && ${_build}

028_libssl:
	cd ${WRKSRC}/lib/libssl && ${_obj} && ${_depend} && ${_build}

029_xorg_libs:
	cd ${WRKSRC}/xenocara/lib && ${_obj} && ${_build}

030_ssh_kexinit:
	cd ${WRKSRC}/usr.bin/ssh &&  ${_obj} && ${_depend} && ${_build}

031_smtpd:
	cd ${WRKSRC}/usr.sbin/smtpd &&  ${_obj} && ${_depend} && ${_build}	

032_libssl:
	cd ${WRKSRC}/lib/libssl && ${_obj} && ${_depend} && ${_build}

033_libcrypto:
	cd ${WRKSRC}/lib/libcrypto &&  ${_obj} && ${_depend} && ${_build}	

034_httpd:
	cd ${WRKSRC}/usr.sbin/httpd && ${_obj} && ${_depend} && ${_build}

.include "mk/bsd.binpatch.mk"
