# Copyright (c) 2002-2007, Gerardo Santana Gomez Garrido <gerardo.santana@gmail.com>
# Copyright (c) 2007-2014, m:tier
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 3. The name of the author may not be used to endorse or promote products
#    derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR `AS IS'' AND ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT,
# INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
# STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
# ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

# ================================================================ VARIABLES
# Architecture we are building on/for
ARCH=${MACHINE_ARCH}
KERNEL_ARCH!=machine

SUFFIX=.tgz

# You'll need to copy your kernel configuration file into
# ${WRKDIR}/sys/arch/${ARCH}/conf/ if you want to compile it.
# Defaults to GENERIC kernel
KERNEL?=GENERIC

# The directory where the OpenBSD installation files
# and source are stored
DIST_DIR?=${.CURDIR}/distfiles/${OSREV}/

# Where patches are stored
PATCHDIR?=${.CURDIR}/patches

# Stagingarea
STAGEDIR=var/db/binpatch

# The OpenBSD installation files should be in a subdirectory.
# Defaults to $ARCH
DISTSUBDIR?=${ARCH}

# Wether to fetch signed patches
PATCH_SIGNED?=".sig"

# FETCH program
FETCH_CMD?= /usr/bin/ftp -Vm

# The OpenBSD Master Site
MASTER_SITE_OPENBSD?=http://ftp.fr.openbsd.org/
MASTER_SITE_DIST_SUBDIR?=/pub/OpenBSD/
MASTER_SITE_SUBDIR?=${MASTER_SITE_DIST_SUBDIR}/patches/${OSREV}

SETS=base comp game man xbase xfont xserv xshare

# Used for building set names
_OSREV=${OSREV:S/.//g}

# Stem doesn't change between different patches
STEM=binpatch${_OSREV}-${ARCH}

# The working directories. All of them will be created, and removed.
WRKDIR?=${.CURDIR}/work-${STEM}
WRKSRC?=${WRKDIR}/src
WRKXSRC?=${WRKSRC}/xenocara
BP_WRKOBJ?=${WRKDIR}/obj
BP_WRKXOBJ?=${WRKDIR}/xobj
WRKINST?=${WRKDIR}/work
WRKFAKE?=${WRKDIR}/fake
PACKAGEDIR?=${.CURDIR}/packages
PKGDIR?=${.CURDIR}/pkg

# toggle X11SRC to extract xenocara source as well
X11SRC?=YES
# XENOCARA patches need to be flagged
X11?=NO

# Variables needed for making the sources (after patching)
DESTDIR:=${WRKINST}
LDFLAGS+=-L${DESTDIR}/usr/lib/
.if "${X11}" == "YES"
LDFLAGS+=-L${DESTDIR}/usr/X11R6/lib/
.endif
MAKE_ENV:= env DESTDIR=${DESTDIR} BSDSRCDIR=${WRKSRC} BSDOBJDIR=${BP_WRKOBJ} XSRCDIR=${WRKXSRC} XOBJDIR=${BP_WRKXOBJ} LDFLAGS="${LDFLAGS}" INSTALL_COPY=-C

# Signing variables for gzsign
SIGNKEY?=YES
.if defined(SIGNPASS) && exists(${SIGNPASS})
SIGNCMD := -f ${SIGNPASS} ${SIGNKEY}
.else
SIGNCMD := ${SIGNKEY}
.endif

# Signing variables for openssl smime (needs OpenBSD > 4.5),
# or signify(1) (OpenBSD >= 5.5)
PKG_SIGN_STRING?=

# Default to non-parallel builds (i.e. a single job)
PARALLEL_BUILD?=no
_PARALLEL_JOBS!=sysctl -n hw.ncpu

.if ${PARALLEL_BUILD:L} == "no"
_j =
.else
.  if ${PARALLEL_BUILD:L} == "yes"
PARALLEL_JOBS ?= ${_PARALLEL_JOBS}
_j = -j${PARALLEL_JOBS}
.  endif
.endif

# ============================================== SPECIAL TARGETS & SHORTCUTS
# Subroutine to include for building a kernel patch
_kernel: .USE
.for _kern in ${KERNEL}
	cd ${WRKSRC}/sys/arch/${KERNEL_ARCH}/conf && \
	config ./${_kern} && \
	cd ../compile/${_kern} && \
	${MAKE_ENV} make ${_j} && \
	if [ ${_kern} = "GENERIC" ]; then \
	cp -p bsd ${WRKINST}; \
	elif [ ${_kern} = "GENERIC.MP" ]; then \
	cp -p bsd ${WRKINST}/bsd.mp; \
	else \
	cp -p bsd ${WRKINST}/bsd; \
	fi
.endfor

_x11: .USE
	cd ${WRKXSRC} && \
	${MAKE_ENV} make bootstrap && \
	${MAKE_ENV} make obj && \
	${MAKE_ENV} make ${_j} build;

# bin, sbin and libc are not patches, and not always needed. They are here
# to serve as a source for a patch target if its instructions includes, for
# example: "And then rebuild and install libc"

bin:
	cd ${WRKSRC}/bin && (${_obj}; ${_cleandir}; ${_depend} && ${_build})

sbin:
	cd ${WRKSRC}/sbin && (${_obj}; ${_cleandir}; ${_depend} && ${_build})

libc:
	cd ${WRKSRC}/lib/libc && \
	(${_obj}; ${_cleandir}; ${_depend} && ${_build})

# Shortcuts
_obj=${MAKE_ENV} make ${_j} obj
_cleandir=${MAKE_ENV} make cleandir
_depend=${MAKE_ENV} make ${_j} depend
_build=${MAKE_ENV} make ${_j} && ${_install}
_install=${MAKE_ENV} make ${_j} install
_includes=${MAKE_ENV} make includes

_obj_wrp=${MAKE_ENV} make ${_j} -f Makefile.bsd-wrapper obj
_cleandir_wrp=${MAKE_ENV} make -f Makefile.bsd-wrapper cleandir
_depend_wrp=${MAKE_ENV} make ${_j} -f Makefile.bsd-wrapper depend
_build_wrp=${MAKE_ENV} make ${_j} -f Makefile.bsd-wrapper && ${_install_wrp}
_install_wrp=${MAKE_ENV} make ${_j} -f Makefile.bsd-wrapper install

# ================================================================== COOKIES
COOKIE:=${WRKDIR}/.cookie
INIT_COOKIE:=${WRKINST}/.init-done
EXTRACT_COOKIE:=${WRKDIR}/.extract-done
FETCH_COOKIE:=${DIST_DIR}/${KERNEL_ARCH}/.fetch-done

PATCH_FILES=
PATCH_COOKIES=
BUILD_COOKIES=

# ============================================== PATCHING & BUILDING TARGETS
# Create targets and define variables only for our ${ARCH}
PATCH_LIST:=${PATCH_COMMON} ${PATCH_KERNEL}

.for _patch in ${PATCH_KERNEL}
.if "${_patch:C/_.*//}" == "${PATCH}"
PATCH_IS_KERNEL=yes
.  endif
.endfor

.if "${PATCH_IS_KERNEL}" == "yes"
# Handle kernel patches differently since they may have a different component name, but they
# produce the same file.
.  for _k in ${PATCH_KERNEL}
.    if "${_k:Mextra*}"
_k=${_k:C/extra//:C/_.*//}
.    endif

component=kernel
PATCHES_BY_COMPONENT-${component}+=${_k}
.  endfor

.else
# Use a naming scheme that doesn't involve flavors anymore since that prohibits the use of
# binpatches that are updateable. So binpatches are now named with the component and a version
# that matches the patch number. Like: binpatch-5.2-amd64-ksh-001.
.for _p in ${PATCH_COMMON}
.  if "${_p:C/_.*//}" == "${PATCH}"
component=${_p:C/.*_//}
.  endif
.endfor

# PATCHES_BY_COMPONENT includes *all* the patches, not only up to ${PATCH}.
# This is intentional as one is always supposed to rollout the latest version anyway.
.for _c in ${PATCH_COMMON}
.  if "${_c:Mextra*}"
_c=${_c:C/extra//:C/_.*//}
.  endif

.  if "${_c:C/.*_//}" == "${component}"
PATCHES_BY_COMPONENT-${component}+=${_c}
.  endif
.endfor

.endif

# The version calculated based on the number of patches that have lead up it.
VERSION != printf "%d.0" `echo ${PATCHES_BY_COMPONENT-${component}} | wc -w`

REVISION != echo ${PKG_ARGS_${PATCH}} | sed -e 's/-DREVISION=/p/'

FULLPKGNAME?=${STEM}-${component}-${VERSION}${REVISION}

# Only applicable to our current patch.
.for _patch in ${PATCH_LIST}
.  if "${_patch:C/_.*//}" == "${PATCH}"
  # _number holds the patch number
_number:=${_patch:C/_.*//}

dummy:=${PATCH_${ARCH:U}:M${_patch}*}
.    if !empty(dummy)
_file  :=${ARCH}/${_patch}.patch
.    else
_file :=common/${_patch}.patch
.    endif
.  endif
.endfor

.for _patch in ${PATCH_LIST}
_number:=${_patch:C/_.*//}

# List of patch files
PATCH_FILE_${_number}:= ${PATCHDIR}/${_file}
PATCH_FILES:= ${PATCH_FILES} ${PATCH_FILE_${_number}}

# Fetches the patch file
${PATCH_FILE_${_number}}:
	@echo ">> ${.TARGET:T} doesn't seem to exist on this system."
	@mkdir -p ${.TARGET:H}
	@cd  ${.TARGET:H} && \
	for site in ${MASTER_SITE_OPENBSD}; do \
	echo ">> Attempting to fetch ${.TARGET}${PATCH_SIGNED} from $${site}/${MASTER_SITE_SUBDIR}/"; \
	if ${FETCH_CMD} $${site}/${MASTER_SITE_SUBDIR}/${.TARGET:S@${PATCHDIR}/@@}${PATCH_SIGNED}; then \
		if signify -Vep /etc/signify/openbsd-${_OSREV}-base.pub -x ${.TARGET:T}${PATCH_SIGNED} -m ${.TARGET:T}; then \
			exit 0; \
		fi; \
	fi; \
	done; exit 1

PATCH_COOKIE_${_number}:=${WRKDIR}/.${_patch}-applied

# Patches the source tree
${PATCH_COOKIE_${_number}}: ${PATCH_FILE_${_number}}
	@if [ "${X11}" == "YES" ]; then \
		cd ${WRKXSRC}; \
	else \
		cd ${WRKSRC}; \
	fi; \
	patch -p0 < ${PATCH_FILE_${.TARGET:E:C/_.*//}}
	@touch -f ${.TARGET}

COOKIE_${_number}:=${WRKDIR}/.${_patch}-build-start

BUILD_COOKIE_${_number}:=${WRKDIR}/.${_patch}-built

# Builds the patch applied
${BUILD_COOKIE_${_number}}:
	@touch -f ${COOKIE_${.TARGET:E:C/_.*//}}
	@env PATCH="${PATCH}" ${MAKE_ENV} make ${.TARGET:E:C/-built//}
	@touch -f ${.TARGET}
.endfor

.for _p in ${PATCH}
PATCH_COOKIES	+= ${PATCH_COOKIE_${_p}}
BUILD_COOKIES	+= ${BUILD_COOKIE_${_p}}
.endfor

# ============================================================= MAIN TARGETS
# Do all the fetching of files needed by init and extract
fetch: ${FETCH_COOKIE}

${FETCH_COOKIE}:
	@echo "===>  Fetching sources and sets"

	@if [ ! -d ${DIST_DIR} ]; then \
		mkdir -p ${DIST_DIR}/${KERNEL_ARCH}; \
	fi

	@if [ ! -f ${DIST_DIR}/src.tar.gz ]; then \
		cd ${DIST_DIR} && ${FETCH_CMD} ${MASTER_SITE_OPENBSD}/${MASTER_SITE_DIST_SUBDIR}/${OSREV}/src.tar.gz ;\
	fi

	@if [ ! -f ${DIST_DIR}/sys.tar.gz ]; then \
		cd ${DIST_DIR} && ${FETCH_CMD} ${MASTER_SITE_OPENBSD}/${MASTER_SITE_DIST_SUBDIR}/${OSREV}/sys.tar.gz ;\
	fi

.if "${X11SRC}" == "YES"
	@if [ ! -f ${DIST_DIR}/xenocara.tar.gz ]; then \
		cd ${DIST_DIR} && ${FETCH_CMD} ${MASTER_SITE_OPENBSD}/${MASTER_SITE_DIST_SUBDIR}/${OSREV}/xenocara.tar.gz;\
	fi
.endif

.for _pkg in ${SETS}
	@if [ ! -f ${DIST_DIR}/${KERNEL_ARCH}/${_pkg}${_OSREV}.tgz ]; then \
		cd ${DIST_DIR}/${KERNEL_ARCH}/ && ${FETCH_CMD} ${MASTER_SITE_OPENBSD}/${MASTER_SITE_DIST_SUBDIR}/${OSREV}/${KERNEL_ARCH}/${_pkg}${_OSREV}.tgz ;\
	fi
.endfor

	@if [ ! -f ${DIST_DIR}/${KERNEL_ARCH}/bsd ]; then \
		cd ${DIST_DIR}/${KERNEL_ARCH}/ && ${FETCH_CMD} ${MASTER_SITE_OPENBSD}/${MASTER_SITE_DIST_SUBDIR}/${OSREV}/${KERNEL_ARCH}/bsd ;\
	fi
	@touch -f ${.TARGET}


# Extracts sources
extract: fetch ${EXTRACT_COOKIE}

${EXTRACT_COOKIE}:
	@echo "===>  Removing stale files"
	@rm -rf ${BP_WRKOBJ} ${WRKSRC}
	@mkdir -p ${BP_WRKOBJ} ${WRKSRC}

	@echo "===>  Extracting sources"
	@echo "==>   src.tar.gz"
	@tar xzpf ${DIST_DIR}/src.tar.gz -C ${WRKSRC}
	@echo "==>   sys.tar.gz"
	@tar xzpf ${DIST_DIR}/sys.tar.gz -C ${WRKSRC}

.if "${X11SRC}" == "YES"
	@rm -rf ${BP_WRKXOBJ}
	@mkdir -p ${BP_WRKXOBJ} ${WRKXSRC}
	@echo "==>   xenocara.tar.gz"
	@tar xzpf ${DIST_DIR}/xenocara.tar.gz -C ${WRKSRC}
.endif
	@touch -f ${.TARGET}

# Extracts the OpenBSD installation files
init: extract ${INIT_COOKIE}

${INIT_COOKIE}:
	@echo "===>  Creating fake install tree"
	@rm -rf ${WRKINST}
	@mkdir -p ${WRKINST}
	@mkdir -p ${DIST_DIR}/${KERNEL_ARCH}
	@echo "==>   Extracting base sets"
	@echo -n "=> "
.for _pkg in ${SETS}
	@echo -n "${_pkg} "
	@tar xzpf ${DIST_DIR}/${KERNEL_ARCH}/${_pkg}${_OSREV}.tgz -C ${WRKINST}
.endfor
	@echo ""
	@cp -p ${DIST_DIR}/${KERNEL_ARCH}/bsd ${WRKINST}
	@touch -f ${.TARGET}

# Applies patches and checks for rollback
patch: init ${PATCH_COOKIES}
	@if [ -z "${ROLLBACK}" -o "${ROLLBACK}" != "all" -a "${ROLLBACK}" != "kernel" -a "${ROLLBACK}" != "none" ]; then \
		echo "===>  Error, no (valid) rollback mode defined!"; \
		echo "      Set ROLLBACK to either of the following: none, kernel, all."; \
		exit 1; \
	fi

# The cookie for detecting a change in the timestamp
${COOKIE}!
	@touch -f ${.TARGET}

# Builds the patch applied
build: init patch ${COOKIE} ${BUILD_COOKIES}

PATCH_SRC=find ${PATCHDIR} -name ${PATCH}\*.patch -print
PATCH_NAME=basename $$(eval ${PATCH_SRC}) .patch

STAGINGAREA=${STAGEDIR}/${OSREV}-${PATCH}

# Packages the modified files
# To build the @pkgpath list of patches to replace, take the expanded variable
# (based on the current PATCH and strip the list again to only the patch versions
# of what's being replaced.
plist: build
	@echo "===>   Finding changed binaries and building PLIST"
	@mkdir -p ${PKGDIR}
	@echo "@comment patch for $$(eval ${PATCH_NAME})" > ${PKGDIR}/PLIST
	@echo "@option always-update" >> ${PKGDIR}/PLIST
	@echo "Binary patch for ${component}" > ${PKGDIR}/COMMENT
	@echo "Patch(es) included in this package:\n" > ${PKGDIR}/DESCR
	@for p in ${PATCHES_BY_COMPONENT-${component}}; do echo \\t$$p.patch >> ${PKGDIR}/DESCR; done
	@cd ${WRKINST} && \
	find . -newer ${COOKIE_${PATCH}} -a ! -newer ${BUILD_COOKIE_${PATCH}} \
		${FIND_OPTS_${PATCH}} >> ${PKGDIR}/PLIST
	@mkdir -p ${WRKFAKE}/${STAGINGAREA}/patches/
	@for p in ${PATCHES_BY_COMPONENT-${component}}; do \
		if [ -r ${PATCHDIR}/${ARCH:L}/$$p.patch ]; then \
			cp ${PATCHDIR}/${ARCH:L}/$$p.patch ${WRKFAKE}/${STAGINGAREA}/patches/; \
		else \
			cp ${PATCHDIR}/common/$$p.patch ${WRKFAKE}/${STAGINGAREA}/patches/; \
		fi; \
	done
	@mkdir -p ${WRKFAKE}/${STAGINGAREA}/fake
	@perl -pi -ne 's,^\.\n,,g' ${PKGDIR}/PLIST
	@perl ${.CURDIR}/bin/plist.pl ${PKGDIR}/PLIST > ${WRKFAKE}/${STAGINGAREA}/PLIST
	@cp ${.CURDIR}/bin/install.sh ${WRKFAKE}/${STAGINGAREA}/
	@echo "@unexec /${STAGINGAREA}/install.sh rollback ${PATCH} /${STAGEDIR} ${ROLLBACK}" >> \
				${PKGDIR}/PLIST
	@echo "${STAGINGAREA}/PLIST" >> ${PKGDIR}/PLIST
	@echo "${STAGINGAREA}/install.sh" >> ${PKGDIR}/PLIST
	@echo "@exec /${STAGINGAREA}/install.sh install ${PATCH} /${STAGEDIR} ${ROLLBACK}" >> \
				${PKGDIR}/PLIST
	@perl ${.CURDIR}/bin/plist.pl ${PKGDIR}/PLIST ${WRKINST} > \
			${PKGDIR}/PLIST.new
	@mv ${PKGDIR}/PLIST.new ${PKGDIR}/PLIST
	@echo "${STAGINGAREA}/patches/" >> ${PKGDIR}/PLIST
	@for p in ${PATCHES_BY_COMPONENT-${component}}; do echo ${STAGINGAREA}/patches/$$p.patch >> ${PKGDIR}/PLIST; done
	@echo "${STAGINGAREA}/fake/" >> ${PKGDIR}/PLIST
	@echo "${STAGINGAREA}/" >> ${PKGDIR}/PLIST

package: plist
	@mkdir -p ${PACKAGEDIR}
	@echo "===>  Building package for ${FULLPKGNAME} in ${PACKAGEDIR}";
	@grep -v -E '^@|/$$' ${WRKFAKE}/${STAGINGAREA}/PLIST | \
	(cd ${WRKINST} && xargs tar cpf -) | \
	tar xpf - -C ${WRKFAKE}/${STAGINGAREA}/fake
	@chown -R ${BINOWN}:${BINGRP} ${WRKFAKE}/${STAGINGAREA}
	@sed -e 's;\./;${STAGINGAREA}/fake/;' ${PKGDIR}/PLIST > \
		${PKGDIR}/PLIST.pkg
	@pkg_create -A ${ARCH} -B ${WRKFAKE} -p / \
		${PKG_SIGN_STRING} \
		-D COMMENT="Binary Patch for $$(eval ${PATCH_NAME})" \
		-D MAINTAINER=${MAINTAINER:Q} \
		-D FULLPKGPATH="/binpatch/${_OSREV}/${component}" \
		-D CDROM="yes" \
		-D FTP="yes" \
		${PKG_ARGS_${PATCH}} \
		-d ${PKGDIR}/DESCR \
		-f ${PKGDIR}/PLIST.pkg ${PACKAGEDIR}/${FULLPKGNAME}${SUFFIX}
	@rm -fr ${PKGDIR}

sign: package
	@if [ "${SIGNKEY}" != "NO" ]; then \
	    if [ ! -f "${SIGNKEY}" ]; then \
	        echo "+-------------------------"; \
	        echo "|"; \
	        echo "| Key file (${SIGNKEY}) not found."; \
	        echo "| Package will not be signed."; \
	        echo "|"; \
	        echo "+-------------------------"; \
	    else \
	        echo "===>  Signing package with ${SIGNKEY}"; \
	        gzsig sign ${SIGNCMD} ${PACKAGEDIR}/${FULLPKGNAME}${SUFFIX}; \
	        if [ -f "${SIGNKEY}.pub" ]; then \
	          echo "===>  Verifying package with ${SIGNKEY}.pub"; \
	          gzsig verify ${SIGNKEY}.pub ${PACKAGEDIR}/${FULLPKGNAME}${SUFFIX};\
	        fi; \
	    fi; \
	fi
	@echo "+-------------------------"
	@echo "|"
	@echo "| The binary patch package has been created in"
	@echo "| ${PACKAGEDIR}"
	@echo "|"
	@echo "| To install it run make install or:"
	@echo "|"
	@echo "| # cd ${PACKAGEDIR}"
	@echo "| # pkg_add ${FULLPKGNAME}${SUFFIX}"
	@echo "|"
	@echo "+-------------------------"

# Installs the binary patch
install: package
	@echo "===>  Installing ${FULLPKGNAME}"
	@pkg_add ${PACKAGEDIR}/${FULLPKGNAME}${SUFFIX}

# Cleans the working directory
clean:
	@echo "===>  Cleaning working directory"
	@rm -rf ${WRKDIR}

# Removes the directories and cookie created by extract
clean-extract:
	@echo "===>  Cleaning building directory"
	@rm -rf ${WRKSRC} ${BP_WRKOBJ} ${BP_WRKXOBJ} ${EXTRACT_COOKIE}

# Removes fake directory
clean-init:
	@echo "===> Cleaning 'fake' directory"
	@rm -rf ${WRKINST}

# Remove packages directory
clean-packages:
	@echo "===> Cleaning packages directory"
	@rm -fr ${PACKAGEDIR}

# Remove patches directory
clean-patches:
	@echo "===> Cleaning patches directory"
	@rm -fr ${PATCHDIR}

# Remove distfiles directory
clean-distfiles:
	@echo "===> Cleaning distfiles/${OSREV} directory"
	@rm -fr ${DIST_DIR}

# Return to a pristine state
distclean: clean clean-packages clean-patches clean-distfiles

.if defined(show)
.MAIN: show
show:
.	for _s in ${show}
		@echo ${${_s}:Q}
.	endfor
.else
.MAIN: build
.endif

.include <bsd.own.mk>
