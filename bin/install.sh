#!/bin/sh
# Copyright (c) 2007-2014 m:tier
#
# Permission to use, copy, modify, and distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

ARCH=`uname -m`
OSREV=`uname -r`

# Arguments:
# $1 - modus operandi (install || rollback)
# $2 - ${PATCH}
# $3 - /${STAGEDIR}
# $4 - rollback enabled? (none || all || kernel)

# check wether we run a kernel update
KERNEL_CHECK=`/usr/bin/grep bsd $3/$OSREV-$2/PLIST | /usr/bin/xargs -r /usr/bin/basename`

# Do a quick check for valid rollback modes, fallback to kernel-only.
rollback_mode=$4
echo $rollback_mode | egrep -vw -E '(none|all|kernel)' > /dev/null
if [ $? -ne 1 ]; then
	echo "Invalid or no rollback mode passed to $0!"
	echo "Assuming rollback only for kernels."
	rollback_mode="kernel"
fi

if [ "$1" = "install" ]; then
	# If no rollback is enabled, skip this block, otherwise enter it.
	if [ ! "$rollback_mode" == "none" ]; then

		# Only create a rollback package if we always want it, or we want it of
		# kernels and we're dealing with a kernel now.
		if [ "$rollback_mode" == "kernel" -a "$KERNEL_CHECK" -o "$rollback_mode" == "all" ]; then
			(cd / && (while read line; do [ -e "$line" -a -f "$line" ] && echo $line; done < $3/$OSREV-$2/PLIST) | \
				xargs tar czf $3/binpatch-$OSREV-$ARCH-$2-rollback.tgz >/dev/null)

			if [ $? -ne 0 ]; then
				echo "Errors while creating rollback package!"
				echo "Depending on your installation these errors can be ignored"
			fi
		fi

		# Always go into this block if we're dealing with kernels, since:
		# all > kernel > none
		if [ ! -z "$KERNEL_CHECK" ]; then
			# check boot.conf
			KERNEL="/bsd"
			if [ -f /etc/boot.conf ]; then
				KERNEL=`/usr/bin/grep "bsd" /etc/boot.conf | \
					/usr/bin/awk -F " " '{print $2}'`
				if [ -z "$KERNEL" ]; then
					KERNEL="/bsd"
				fi
			fi
			if [ -e "$KERNEL" ]; then
				/bin/cp -p $KERNEL $KERNEL.rollback
			fi
		fi
	fi

	# fix permissions
	mtree -qdef /etc/mtree/4.4BSD.dist -p $3/$OSREV-$2/fake -U >/dev/null

	# remove empty dirs created by mtree(8)
	(cd $3/$OSREV-$2/fake && find . -type d -empty | xargs rmdir -p 2>/dev/null)

	(cd $3/$OSREV-$2/fake && tar cf - .) | tar -xpf - -C /

	if [ ! -z "$KERNEL_CHECK" ]; then
		ncpu=$(sysctl -n hw.ncpufound)
		if [ ${ncpu} -gt 1 ]; then
			echo "Multiprocessor machine; using bsd.mp instead of bsd."
			cp -p /bsd /bsd.sp
			cp -p /bsd.mp /bsd
		fi
	fi

	if [ $? -ne 0 ]; then
		echo "Errors while installing new files!"
		exit 1
	fi
fi

if [ "$1" = "rollback" -a "$rollback_mode" != "none" ]; then
	ROLLBACK_PKG=$3/binpatch-$OSREV-$ARCH-$2-rollback.tgz

	if [ ! -f $ROLLBACK_PKG ]; then
		echo "Rollback package does not exist!"
	fi

	/bin/mkdir -p $3/$OSREV-$2r && \
		/bin/tar xzfp $ROLLBACK_PKG -C $3/$OSREV-$2r/

	if [ $? -ne 0 ]; then
		echo "Errors while preparing install of rollback package!"
		exit 1
	fi

	if [ ! -z "$KERNEL_CHECK" ]; then
		KERNEL="/bsd"
		if [ -f /etc/boot.conf ]; then
			KERNEL=`/usr/bin/grep "bsd" /etc/boot.conf | \
				/usr/bin/awk -F " " '{print $2}'`
			if [ -z "$KERNEL" ]; then
				KERNEL="/bsd"
			fi
		fi
		if [ -e "$KERNEL.rollback" ]; then
			/bin/rm /$KERNEL.rollback
		fi
	fi

	# fix permissions
	mtree -qdef /etc/mtree/4.4BSD.dist -p $3/$OSREV-$2r -U >/dev/null

	# remove empty dirs created by mtree(8)
	(cd $3/$OSREV-$2r && find . -type d -empty | xargs rmdir -p 2>/dev/null)

	(cd $3/$OSREV-$2r && /bin/rm -f "+CONTENTS" "+DESC" && /bin/tar cf - .) | /bin/tar xpf - -C /

	if [ $? -ne 0 ]; then
		echo "Errors while installing new files!"
		exit 1
	fi

	# Remove rollback stagingarea (and package)
	/bin/rm -rf $3/$OSREV-$2r $ROLLBACK_PKG
fi
