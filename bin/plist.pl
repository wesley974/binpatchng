#!/usr/bin/perl
# Copyright (c) 2007-2012 m:tier
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

use strict;

use Fcntl ':mode';
use File::Basename;

my $plist_file= $ARGV[0];
my $wrkdir= $ARGV[1];
my @parents;

open(PLIST,"<$plist_file") or die "Failed to open plist '$plist_file' in read-only mode.\n$!\n";

while(<PLIST>) {

	my $owner_marker= 0;
	my $group_marker= 0;
	my $mode_marker= 0;

	chomp;

	if($_ =~ /^@/) {
		print "$_\n";
		next;
	}

	my $filename = $wrkdir ."/". $_;

	my @filestat= stat($filename);
	my $mode = $filestat[2];
	if (($mode & 07777) != 0000) {
		my $is_setuid =  $mode & S_ISUID;
		my $is_setgid =  $mode & S_ISGID;
		my $is_groupw =  $mode & S_IWGRP;

		my $owner=	getpwuid($filestat[4]);
		my $group=  getgrgid($filestat[5]);

		if($owner ne "root" && $owner ne "bin") {
			print "\@owner $owner\n";
			$owner_marker= 1;
		}

		if($group ne "bin" && $group ne "wheel") {
			if($is_setuid || $is_setgid || $is_groupw) {
				print "\@group $group\n";
				$group_marker= 1;
			}
		}

		if($is_setuid || $is_setgid) {
			printf "\@mode %04o\n", $mode & 07777;
			$mode_marker= 1;
		}
	}

	# Tag and print the parent directory, except for root nodes.
	if (!grep(/^$_$/, @parents)) {
		push(@parents, $_);
		print dirname($_) . "/\n" unless dirname($_) eq '.';
	}

	# Explicitly mark directories as such, but ignore './'
	# as it will lead to double entries.
	if ($mode & S_IFDIR) {
		print "$_/\n"; #   unless $_ eq '.';
	} else {
		print "$_\n";
	}

	if($mode_marker == 1) {
		print "\@mode\n";
	}

	if($group_marker == 1) {
		print "\@group\n";
	}

	if($owner_marker == 1) {
		print "\@owner\n";
	}

}

close(PLIST);
