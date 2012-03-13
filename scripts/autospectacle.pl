#!/usr/bin/perl -w

#      Copyright (C) 2010 Intel Corporation
#
#   
#   This program is free software: you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation, either version 3 of the License.
#   
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#   
#   You should have received a copy of the GNU General Public License
#   along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
#   As a special exception, you may create a larger work that contains
#   part or all of the autospectacle output and distribute that work
#   under terms of your choice.
#   Alternatively, if you modify or redistribute autospectacle itself, 
#   you may (at your option) remove this special exception.
#   
#   This special exception was modeled after the bison exception 
#   (as done by the Free Software Foundation in version 2.2 of Bison)
#


use File::Temp qw(tempdir);
use File::Path qw(mkpath rmtree); 
use File::Spec (); 


my $name = "";
my $version = "TO BE FILLED IN";
my $description = "";
my $summary = "";
my $url = "";
my $configure = "";
my $localename = "";
my @sources;
my @mainfiles;
my @patches;

my $printed_subpackages = 0;
my $fulldir = "";

my $builder = "";


my $oscmode = 0;

my @banned_pkgconfig;
my %failed_commands;
my %failed_libs;
my %failed_headers;



######################################################################
#
# License management
#
# We store the sha1sum of common COPYING files in an associative array
# %licenses. 
#
# For all matching sha1's in the tarbal, we then push the result
# in the @license array (which we'll dedupe at the time of printing).
# 

my %licenses;
my @license;

sub setup_licenses
{
	$licenses{"06877624ea5c77efe3b7e39b0f909eda6e25a4ec"} = "GPLv2";
	$licenses{"075d599585584bb0e4b526f5c40cb6b17e0da35a"} = "GPLv2";
	$licenses{"10782dd732f42f49918c839e8a5e2894c508b079"} = "GPLv2";
	$licenses{"2d29c273fda30310211bbf6a24127d589be09b6c"} = "GPLv2";
	$licenses{"4df5d4b947cf4e63e675729dd3f168ba844483c7"} = "LGPLv2.1";
	$licenses{"503df7650052cf38efde55e85f0fe363e59b9739"} = "GPLv2";
	$licenses{"5405311284eab5ab51113f87c9bfac435c695bb9"} = "GPLv2";
	$licenses{"5fb362ef1680e635fe5fb212b55eef4db9ead48f"} = "LGPLv2";
	$licenses{"68c94ffc34f8ad2d7bfae3f5a6b996409211c1b1"} = "GPLv2";
	$licenses{"66c77efd1cf9c70d4f982ea59487b2eeb6338e26"} = "LGPLv2.1";
	$licenses{"74a8a6531a42e124df07ab5599aad63870fa0bd4"} = "GPLv2";
	$licenses{"8088b44375ef05202c0fca4e9e82d47591563609"} = "LGPLv2.1";
	$licenses{"8624bcdae55baeef00cd11d5dfcfa60f68710a02"} = "GPLv3";
	$licenses{"8e57ffebd0ed4417edc22e3f404ea3664d7fed27"} = "MIT";
	$licenses{"99b5245b4714b9b89e7584bfc88da64e2d315b81"} = "BSD";
	$licenses{"aba8d76d0af67d57da3c3c321caa59f3d242386b"} = "MPLv1.1";
	$licenses{"bf50bac24e7ec325dbb09c6b6c4dcc88a7d79e8f"} = "LGPLv2";
	$licenses{"caeb68c46fa36651acf592771d09de7937926bb3"} = "LGPLv2.1";
	$licenses{"dfac199a7539a404407098a2541b9482279f690d"} = "GPLv2";
	$licenses{"e60c2e780886f95df9c9ee36992b8edabec00bcc"} = "LGPLv2.1";
	$licenses{"c931aad3017d975b7f20666cde0953234a9efde3"} = "GPLv2";
}

sub guess_license_from_file {
	my ($copying) = @_;

	if (!-e $copying)  {
		return;
	}

	my $sha1output = `sha1sum $copying`;
	$sha1output =~ /^([a-zA-Z0-9]*) /;
	my $sha1 = $1;

	chomp($sha1);

	#
	# if sha1 matches.. push there result
	#
	if (defined($licenses{$sha1})) {
		my $lic = $licenses{$sha1};
		push(@license, $lic);
	}
	
	#
	# We also must make sure that the COPYING/etc files
	# end up in the main package as %doc..
	#
	$copying =~ s/$fulldir//g;
	$copying =~ s/^\///g;
	$copying = "\"\%doc " . $copying ."\"";
	
	push(@mainfiles, $copying);
}

sub print_license
{
	my $count = @license;
	if ($count == 0) {
		print OUTFILE "License: TO BE FILLED IN\n";
		return;
	}

	# remove dupes
	undef %saw;
	@saw{@license} = ();
    	@out = sort keys %saw;

	print OUTFILE "License    : ";
	foreach (@out) {
		print OUTFILE "$_ ";
	}
	print OUTFILE "\n";
}

# end of license section
#
#######################################################################

######################################################################
#
# Package group management
#
# We set up an associative array of regexp patterns, where the content
# of the array is the name of the group.
#
# These are "strings of regexps", which means one needs to escape
# everything, and if you want the actual regexp to have a \,
# it needs to be a \\ in this string.

my %group_patterns;
my @groups;
my $group   = "TO_BE/FILLED_IN";

sub setup_group_rules
{
	$group_patterns{"^\\/usr\\/lib\\/.*so"} = "System/Libraries";
	$group_patterns{"^\\/lib\\/.*so"} = "System/Libraries";
	$group_patterns{"^\\/bin\\/.*"} = "Applications/System";
	$group_patterns{"^\\/sbin\\/.*"} = "Applications/System";
	$group_patterns{"^\\/usr\\/sbin\\/.*"} = "Applications/System";
}

sub guess_group_from_file
{
	my ($filename) = @_;	
	while (($key,$value) = each %group_patterns) {
		if ($filename =~ /$key/) {
			push(@groups, $value);
		}
	}
				
}

# end of group section
#
######################################################################


######################################################################
#
# Files and package section
#
# This section creates the %files section, but also decides which
# subpackages (devel and/or doc) we need to have.
#
# We start out with the @allfiles array, which will contain all the
# files installed by the %build phase of the package. The task is
# to sort these into @mainfiles, @develfiles and @docfiles.
# In addition, an attempt is made to compress the files list by
# replacing full filenames with "*" patterns.
#
# For this we use a set of regexps from the @files_match array,
# which are then used as index to three associative arrays:
# %files_target : numerical index for which package the regexp
#                 would place the file at hand.
#                  0 - main package
#                  1 - devel package
#                  2 - doc package
#                 99 - don't package this at all
#
# %files_from: regexp to match the file against for filename-wildcarding
# %files_to  : pattern to append to the ()'d part of %files_from to end up
#              with the filename-wildcard.
 
my @allfiles;
my @develfiles;
my @docfiles;


my @files_match;
my %files_target;
my %files_from;
my %files_to;

my $totaldocs = 0;


sub add_files_rule
{
	my ($match, $target, $from, $to) =@_;
	push(@files_match, $match);
	$files_target{"$match"} = $target;
	
	if (length($from) > 0) {
		$files_from{"$match"} = $from;
	}

	if (length($to) > 0) {
		$files_to{"$match"} = $to;
	}
}

sub setup_files_rules
{

#
# Files for the Main package
# 

	add_files_rule("^\\/usr\\/lib\\/[a-z0-9A-Z\\_\\-\\.]+\\.so\\.", 0, 
			"(\\/usr\\/lib\\/.*\\.so\\.).*", "\*");


	add_files_rule("^\\/usr\\/share\\/omf\\/", 0, 
			"(\\/usr\\/share\\/omf\\/.*?\\/).*", "\*");
			
#
# Files for the Devel subpackage
#
	add_files_rule("^\\/usr\\/share\\/gir-1\\.0\\/[a-z0-9A-Z\\_\\-\\.]+\\.gir\$", 1, 
			"(\\/usr\\/share\\/gir-1\\.0\/).*", "\*\.gir");
	add_files_rule("^\\/usr\\/lib\\/girepository-1\\.0\\/[a-z0-9A-Z\\_\\-\\.]+\\.typelib\$", 1, 
			"(\\/usr\\/lib\\/girepository-1\\.0\/).*", "\*\.typelib");
	add_files_rule("^\\/usr\\/include\\/[a-z0-9A-Z\\_\\-\\.]+\\.h\$", 1, 
			"(\\/usr\\/include\/).*", "\*\.h");
	add_files_rule("^\\/usr\\/include\\/[a-z0-9A-Z\\_\\-\\.]+\\/.*?\\.h\$", 1, 
			"(\\/usr\\/include\\/[a-z0-9A-Z\\_\\-\\.]+\\/.*?)[a-z0-9A-Z\\_\\-\\.]+\\.h", "\*\.h");
	add_files_rule("^\\/usr\\/lib\\/[a-z0-9A-Z\\_\\-\\.]+\\.so\$", 1, 
			"(\\/usr\\/lib\\/).*\\.so\$", "\*.so");
	add_files_rule("^\\/usr\\/lib\\/pkgconfig\\/[a-z0-9A-Z\\_\\-\\.\+]+\\.pc\$", 1, 
			"(\\/usr\\/lib\\/pkgconfig\\/).*\\.pc\$", "\*.pc");
	add_files_rule("^\\/usr\\/share\\/aclocal", 1, "", "");
	add_files_rule("^\\/usr\\/lib\\/qt4\\/mkspecs/", 1, "", "");




#
# Files for the documentation subpackage
#
	add_files_rule("^\\/usr\\/share\\/gtk\-doc\\/html\\/[a-z0-9A-Z\\_\\-\\.]+\\/.\*", 2, 
		       "(\\/usr\\/share\\/gtk\-doc\\/html\\/[a-z0-9A-Z\\_\\-\\.]+\\/).\*", "\*");
	add_files_rule("^\\/usr\\/share\\/doc\\/[a-zA-Z0-9\-]*", 2, 
                       "(\\/usr\\/share\\/doc\\/[a-zA-Z0-9\-]+\\/).*", "\*");
	add_files_rule("^\\/usr\\/share\\/man\\/man[0-9]\\/[a-zA-Z0-9\-]*", 2, 
                       "(\\/usr\\/share\\/man\\/man[0-9]\\/[a-zA-Z0-9\-]+\\/).*", "\*");
	add_files_rule("^\\/usr\\/share\\/gnome\\/help\\/", 2, 
			"(\\/usr\\/share\\/gnome\\/help\\/.*?\\/.*?\\/).*", "\*");
		       
		       
#
# Files to just not package at all (picked up by other things)
#		     
	add_files_rule("^\\/usr\\/share\\/locale", 99, "", "");
	# compiled python things will get auto cleaned by rpm
#	add_files_rule("\.pyo\$", 99, "", "");
#	add_files_rule("\.pyc\$", 99, "", "");

}

sub apply_files_rules
{
	my $filenumber = @allfiles;
	
	if ($filenumber == 0) {
		return;
	}
	
	while (@allfiles > 0) {
		my $filename = $allfiles[0];
		my $destname = $filename;
		my $handled = 0;
	
#
# while we're here, try to guess what group our package is
#	
		guess_group_from_file($filename);
	
		foreach (@files_match) {
			my $match = $_;
			
			if ($filename =~ /$match/) {				
#
# First try to see if we can turn the full filename into a
# wildcard based filename
#
				if (defined($files_from{$match}) && defined($files_to{$match})) {
					$from = $files_from{$match};
					$to = $files_to{$match};
					$destname =~ s/$from/$1$to/;
#					print "changing $filename to $destname\n";
				}

# devel package
				if ($files_target{$match} == 1) {
					$handled = 1;
					push(@develfiles, $destname);
				}
# doc rules.. also prepend %doc
				if ($files_target{$match} == 2) {
					$handled = 1;
					$destname = "\"%doc " . $destname . "\"";
					push(@docfiles, $destname);
					$totaldocs = $totaldocs + 1;
				}
# don't package
				if ($files_target{$match} == 99) {
					$handled = 1;
					if ($filename =~ /\/usr\/share\/locale\/.*?\/LC_MESSAGES\/(.*)\.mo/) {
						$localename = $1;
					}
				}
			}
		}
		

#
# if the destination name contains our package version,
# use %version instead for future maintenance
#
		$destname =~ s/$version/\%\{version\}/g;	
		if ($handled == 0) {
			push(@mainfiles, $destname);
		}	
		shift(@allfiles);
	}
	
#
# Now.. if we have less than 5 documentation files, just stick them in the main package
#

	$filenumber = @docfiles;
	
	if ($filenumber <= 5) {
		while (@docfiles > 0) {
			my $filename = $docfiles[0];
	
			push(@mainfiles, $filename);
			shift(@docfiles);
		}
	}
	
}

sub print_files
{
	my $count = @mainfiles;
	if ($count == 0) {
		return;
	}

	# remove dupes
	undef %saw;
	@saw{@mainfiles} = ();
    	@out = sort keys %saw;

	print OUTFILE "Files:\n";
	foreach (@out) {
		print OUTFILE "    - $_\n";
	}
}

sub print_devel
{
	my $count = @develfiles;
	if ($count == 0) {
		return;
	}
	print OUTFILE "SubPackages:\n";
	$printed_subpackages = 1;
	print OUTFILE "    - Name: devel\n";
	print OUTFILE "      Summary: Development components for the $name package\n";
	print OUTFILE "      Group: Development/Libraries\n";
	print OUTFILE "      Description:\n";
	print OUTFILE "         - Development files for the $name package\n";

	# remove dupes
	undef %saw;
	@saw{@develfiles} = ();
    	@out = sort keys %saw;

	print OUTFILE "      Files:\n";
	foreach (@out) {
		print OUTFILE "        - $_\n";
	}                
}

sub print_doc
{
	my $count = @docfiles;
	if ($count == 0) {
		return;
	}
	if ($printed_subpackages == 0) {
		print OUTFILE "SubPackages:\n";
		$printed_subpackages = 1;
	}
	print OUTFILE "    - Name: docs\n";
	print OUTFILE "      Summary: Documentation components for the $name package\n";
	print OUTFILE "      Group: Documentation\n";

	# remove dupes
	undef %saw;
	@saw{@docfiles} = ();
    	@out = sort keys %saw;

	print OUTFILE "      Files:\n";
	foreach (@out) {
		print OUTFILE "        - $_\n";
	}                
}


# end of %files section
#
######################################################################


######################################################################
#
# What we can learn from configure.ac/configure
#
# - pkgconfig requirements
# - regular build requirements
# - package name / version


sub setup_pkgconfig_ban
{
        push(@banned_pkgconfig, "^dnl\$");
        push(@banned_pkgconfig, "^hal\$"); # we don't have nor want HAL
        push(@banned_pkgconfig, "tslib-0.0"); # we don't want tslib-0.0 (legacy touchscreen interface)
        push(@banned_pkgconfig, "intel-gen4asm");
        push(@banned_pkgconfig, "^xp\$");  # xprint - deprecated and not in meego
        push(@banned_pkgconfig, "^directfb\$");  # we use X, not directfb
        push(@banned_pkgconfig, "^gtkmm-2.4\$");  # we use X, not directfb
        push(@banned_pkgconfig, "^evil\$");
        push(@banned_pkgconfig, "^directfb");
        push(@banned_pkgconfig, "^sdl ");
        
        
}

sub setup_failed_commands
{
        $failed_commands{"doxygen"} = "doxygen";        
        $failed_commands{"scrollkeeper-config"} = "rarian-compat";
        $failed_commands{"dot"} = "graphviz";
        $failed_commands{"flex"} = "flex";
        $failed_commands{"lex"} = "flex";
        $failed_commands{"freetype-config"} = "freetype-devel";
        $failed_commands{"makeinfo"} = "texinfo";
        $failed_commands{"desktop-file-install"} = "desktop-file-utils";
        $failed_commands{"deflateBound in -lz"} = "zlib-devel";
        $failed_commands{"gconftool-2"} = "GConf-dbus";
        $failed_commands{"jpeglib.h"} = "libjpeg-devel";
        $failed_commands{"expat.h"} = "expat-devel";
        $failed_commands{"bison"} = "bison";
        $failed_commands{"msgfmt"} = "gettext";
        $failed_commands{"curl-config"} = "libcurl-devel";
        $failed_commands{"doxygen"} = "doxygen";
        $failed_commands{"X"} = "pkgconfig(x11)";

        $failed_commands{"gawk"} = "gawk";
        $failed_commands{"xbkcomp"} = "xkbcomp";
        $failed_commands{"Vorbis"} = "libvorbis-devel";
        # checking Expat 1.95.x... no
        $failed_commands{"Expat 1.95.x"} = "expat-devel";
        $failed_commands{"xml2-config path"} =  "libxml2-devel";

        $failed_libs{"-lz"} = "zlib-devel";
        $failed_libs{"-lncursesw"} = "ncurses-devel";
        $failed_libs{"-ltiff"} = "libtiff-devel";
        $failed_libs{"-lasound"} = "alsa-lib-devel";
        $failed_libs{"Curses"} = "ncurses-devel";
        
        $failed_headers{"X11/extensions/randr.h"} = "xrandr";
        $failed_headers{"X11/Xlib.h"} = "x11";
        $failed_headers{"X11/extensions/XShm.h"} = "xext";
        $failed_headers{"X11/extensions/shape.h"} = "xext";
        $failed_headers{"ncurses.h"} = "ncursesw";
        $failed_headers{"curses.h"} = "ncursesw";
        $failed_headers{"pci/pci.h"} = "libpci";
        $failed_headers{"xf86.h"} = "xorg-server";
        $failed_headers{"sqlite.h"} = "sqlite3";
        
        $failed_headers{"X11/extensions/XIproto.h"} = "xi";
        $failed_headers{"QElapsedTimer"} = "";
}



my @package_configs;
my @buildreqs;
my $uses_configure = 0;


sub push_pkgconfig_buildreq
{
	my ($pr) = @_;

	$pr =~ s/\s+//g;
	
	# remove collateral ] ) etc damage in the string
	$pr =~ s/\"//g;
	$pr =~ s/\)//g;
	$pr =~ s/\]//g;
	$pr =~ s/\[//g;


	# first, undo the space packing

	$pr =~ s/\>\=/ \>\= /g;
	$pr =~ s/\<\=/ \<\= /g;

	$pr =~ s/\<1.1.1/  /g;
	
	# don't show configure variables, we can't deal with them
	if ($pr =~ /^\$/) {
		return;
	}
	if ($pr =~ /AC_SUBST/) {
		return;
	}
	
	
	

	# process banned pkgconfig options for things that we don't
	# have or don't want.
	
	
	# remore versions that are macros or strings, not numbers
	$pr =~ s/\s\>\= \$.*//g;

	$pr =~ s/\s\>\= [a-zA-Z]+.*//g;

	# don't show configure variables, we can't deal with them
	if ($pr =~ /\$/) {
		return;
	}

	foreach (@banned_pkgconfig) {
	        my $ban = $_;
	        if ($pr =~ /$ban/) {
	                return;
	        }
	}
	
	push(@package_configs, $pr);
}

#
# detect cases where we require both a generic pkgconfig, and a version specific
# case
#
sub uniquify_pkgconfig
{
        # first remove real dupes
        undef %saw;
        @saw{@package_configs} = ();
        @out = sort keys %saw;
        
        my $count = 0;
                                        
        while ($count < @out) {

                my $entry = $out[$count];
                
                foreach(@out) {
                        my $compare = $_;
                        if ($entry eq $compare) {
                                next;
                        }
                        
                        $compare =~ s/ \>\=.*//g;
                        if ($entry eq $compare) {
                                $out[$count] = "";
                        }
                }
                $count = $count + 1;
        }
        @package_configs = @out;
}


sub process_configure_ac
{
	my ($filename) = @_;
	my $line = "";
	my $depth = 0;
	my $keepgoing = 1;
	my $buffer = "";

	if (!-e $filename)  {
		return;
	}
	
	$uses_configure = 1;



	open(CONFIGURE, "$filename") || die "Couldn't open $filename\n";
        seek(CONFIGURE, 0,0) or die "seek : $!";	
	while ($keepgoing && !eof(CONFIGURE)) {
                $buffer = getc(CONFIGURE);
                
		if ($buffer eq "(") {
			$depth = $depth + 1;
		}
		if ($buffer eq ")" && $depth > 0) {
			$depth = $depth - 1;
		}
		
		if (!($buffer eq "\n")) {
			$line = $line . $buffer;
		}
		
		if (!($buffer eq "\n") || $depth > 0) {
			redo unless eof(CONFIGURE);
		}
		
		if ($line =~ /PKG_CHECK_MODULES\((.*)\)/) {
			my $match = $1;
			$match =~ s/\s+/ /g;
			$match =~ s/, /,/g;
			my @pkgs = split(/,/, $match);
			my $pkg;
			if (defined($pkgs[1])) {
				$pkg = $pkgs[1];
			} else {
				next;
			}
			if ($pkg =~ /\[(.*)\]/) {
				$pkg = $1;
			}

			$pkg =~ s/\s+/ /g;
			# deal with versioned pkgconfig's by removing the spaces around >= 's 
			$pkg =~ s/\>\=\s/\>\=/g;
			$pkg =~ s/\s\>\=/\>\=/g;
			$pkg =~ s/\=\s/\=/g;
			$pkg =~ s/\s\=/\=/g;
			$pkg =~ s/\<\=\s/\<\=/g;
			$pkg =~ s/\<\s/\</g;
			$pkg =~ s/\s\<\=/\<\=/g;
			$pkg =~ s/\s\</\</g;

			@words = split(/ /, $pkg);
			foreach(@words) {
				push_pkgconfig_buildreq($_);
			}
		}

		if ($line =~ /PKG_CHECK_EXISTS\((.*)\)/) {
			my $match = $1;
			$match =~ s/\s+/ /g;
			$match =~ s/, /,/g;
			my @pkgs = split(/,/, $match);
			my $pkg = $pkgs[0];
			if ($pkg =~ /\[(.*)\]/) {
				$pkg = $1;
			}

			$pkg =~ s/\s+/ /g;
			# deal with versioned pkgconfig's by removing the spaces around >= 's 
			$pkg =~ s/\>\=\s/\>\=/g;
			$pkg =~ s/\s\>\=/\>\=/g;
			$pkg =~ s/\<\=\s/\<\=/g;
			$pkg =~ s/\<\s/\</g;
			$pkg =~ s/\s\<\=/\<\=/g;
			$pkg =~ s/\s\</\</g;
			$pkg =~ s/\=\s/\=/g;
			$pkg =~ s/\s\=/\=/g;

			@words = split(/ /, $pkg);
			foreach(@words) {
				push_pkgconfig_buildreq($_);
			}
		}

		if ($line =~ /XDT_CHECK_PACKAGE\(.*?,.*?\[(.*?)\].*\)/) {
			my $pkg = $1;

			$pkg =~ s/\s+/ /g;
			# deal with versioned pkgconfig's by removing the spaces around >= 's 
			$pkg =~ s/\>\=\s/\>\=/g;
			$pkg =~ s/\s\>\=/\>\=/g;
			$pkg =~ s/\=\s/\=/g;
			$pkg =~ s/\s\=/\=/g;

			@words = split(/ /, $pkg);
			foreach(@words) {
				push_pkgconfig_buildreq($_);
			}
		}

		if ($line =~ /XDT_CHECK_OPTIONAL_PACKAGE\(.*?,.*?\[(.*?)\].*\)/) {
			my $pkg = $1;

			$pkg =~ s/\s+/ /g;
			# deal with versioned pkgconfig's by removing the spaces around >= 's 
			$pkg =~ s/\>\=\s/\>\=/g;
			$pkg =~ s/\s\>\=/\>\=/g;
			$pkg =~ s/\=\s/\=/g;
			$pkg =~ s/\s\=/\=/g;

			@words = split(/ /, $pkg);
			foreach(@words) {
				push_pkgconfig_buildreq($_);
			}
		}

		if ($line =~ /AC_CHECK_LIB\(\[expat\]/) {
			push(@buildreqs, "expat-devel");
		}
		if ($line =~ /AC_CHECK_FUNC\(\[tgetent\]/) {
			push(@buildreqs, "ncurses-devel");
		}
		if ($line =~ /_PROG_INTLTOOL/) {
			push(@buildreqs, "intltool");
		}
		if ($line =~ /GETTEXT_PACKAGE/) {
			push(@buildreqs, "gettext");
		}
		if ($line =~ /GTK_DOC_CHECK/) {
			push_pkgconfig_buildreq("gtk-doc");
		}
		if ($line =~ /GNOME_DOC_INIT/) {
			 push(@buildreqs, "gnome-doc-utils");
		}
		if ($line =~ /AM_GLIB_GNU_GETTEXT/) {
			push(@buildreqs, "gettext");
		}

		if ($line =~ /AC_INIT\((.*)\)/) {
			my $match = $1;
			$match =~ s/\s+/ /g;
			@acinit = split(/,/, $match);
#			$name = $acinit[0];
			
			if ($name =~ /\[(.*)\]/) {
#				$name = $1;
			}
			
			if (defined($acinit[3])) {
#				$name = $acinit[3];
				if ($name =~ /\[(.*)\]/) {
#					$name = $1;
				}
			}
			if (defined($acinit[1])) {
				my $ver = $acinit[1];
				$ver =~ s/\[//g;
				$ver =~ s/\]//g;
				if ($ver =~ /\$/){} else {
					$version = $ver;
					$version =~ s/\s+//g;
				}
			}
		}
		if ($line =~ /AM_INIT_AUTOMAKE\((.*)\)/) {
			my $match = $1;
			$match =~ s/\s+/ /g;
			@acinit = split(/,/, $match);
#			$name = $acinit[0];
			
			if ($name =~ /\[(.*)\]/) {
#				$name = $1;
			}
			
			if (defined($acinit[3])) {
#				$name = $acinit[3];
				if ($name =~ /\[(.*)\]/) {
#					$name = $1;
				}
			}
			if (defined($acinit[1])) {
				my $ver = $acinit[1];
				$ver =~ s/\[//g;
				$ver =~ s/\]//g;
				if ($ver =~ /\$/){} else {
					$version = $ver;
					$version =~ s/\s+//g;
				}
			}
		}
		
		$line = "";
	}
	close(CONFIGURE);
}

sub process_qmake_pro
{
	my ($filename) = @_;
	my $line = "";
	my $depth = 0;
	my $keepgoing = 1;
	my $buffer = "";
	my $prev_char = "";

	if (!-e $filename)  {
		return;
	}
	

	open(CONFIGURE, "$filename") || die "Couldn't open $filename\n";
        seek(CONFIGURE, 0,0) or die "seek : $!";	
	while ($keepgoing && !eof(CONFIGURE)) {
                $buffer = getc(CONFIGURE);
                
		if ($buffer eq "(") {
			$depth = $depth + 1;
		}
		if ($buffer eq ")" && $depth > 0) {
			$depth = $depth - 1;
		}
		
		if (!($buffer eq "\n")) {
			$line = $line . $buffer;
		}
		
		if (!($buffer eq "\n") || ($prev_char eq "\\") ) {
		        $prev_char = $buffer;
			redo unless eof(CONFIGURE);
		}
		$prev_char = " ";
		
		if ($line =~ /PKGCONFIG.*?\=(.*)/) {
		        my $l = $1;
		        my @pkgs;
		        
                        $l =~ s/\\//g;
                        $l =~ s/\s/ /g;
                        @pkgs = split(/ /, $l);
                        foreach (@pkgs) {
                                if (length($_)>1) {
                                        push_pkgconfig_buildreq($_);
                                }
                        }
		}

		$line = "";
	}
	close(CONFIGURE);
}

#
# We also check configure if it exists, it's nice for some things
# because various configure.ac macros have been expanded for us already.
#
sub process_configure
{
	my ($filename) = @_;
	my $line = "";
	my $depth = 0;
	my $keepgoing = 1;

	if (!-e $filename)  {
		return;
	}
	
	$uses_configure = 1;

	open(CONFIGURE, "$filename") || die "Couldn't open $filename\n";
        seek(CONFIGURE, 0,0) or die "seek : $!";	
	while ($keepgoing && !eof(CONFIGURE)) {
                $buffer = getc(CONFIGURE);
		
		if ($buffer eq "(") {
			$depth = $depth + 1;
		}
		if ($buffer eq ")" && $depth > 0) {
			$depth = $depth - 1;
		}
		
		if (!($buffer eq "\n")) {
			$line = $line . $buffer;
		}
		
		if (!($buffer eq "\n") || $depth > 0) {
			redo unless eof(CONFIGURE);
		}
		
		

		if ($line =~ /^PACKAGE_NAME=\'(.*?)\'/) {
			$name = $1;
		}
		if ($line =~ /^PACKAGE_TARNAME=\'(.*?)\'/) {
			$name = $1;
		}
		if ($line =~ /^PACKAGE_VERSION=\'(.*?)\'/) {
			$version = $1;
			$version =~ s/\s+//g;
		}
		if ($line =~ /^PACKAGE_URL=\'(.*?)\'/) {
			if (length($1) > 2) {
				$url = $1;
			}
		}
		

		$line = "";
	}
	close(CONFIGURE);
}

sub print_pkgconfig
{
	my $count = @package_configs;
	if ($count == 0) {
		return;
	}

	uniquify_pkgconfig();
	
	print OUTFILE "PkgConfigBR:\n";
	foreach (@out) {
		$line = $_;
		$line =~ s/^\s+//g;
		if (length($line) > 1) {
			print OUTFILE "    - $line\n";
		}
	}
}

sub print_buildreq
{
	my $count = @buildreqs;
	if ($count == 0) {
		return;
	}

	# remove dupes
	undef %saw;
	@saw{@buildreqs} = ();
    	@out = sort keys %saw;

	print OUTFILE "PkgBR:\n";
	foreach (@out) {
		print OUTFILE "    - $_\n";
	}
}


# end of configure section
#
######################################################################


######################################################################
#
# Guessing the Description and Summary for a package
#
# We'll look at various sources of information for this:
# - spec files in the package
# - debain files in the package
# - DOAP files in the package
# - pkgconfig files in the package
# - the README file in the package
# - freshmeat.net online
#

sub guess_description_from_spec {
	my ($specfile) = @_;

	my $state = 0;
	my $cummul = "";
	
	open(SPEC, $specfile);
	while (<SPEC>) {
		my $line = $_;
		if ($state == 1 && $line =~ /^\%/) {
			$state = 2;
		}
		if ($state == 1) {
			$cummul = $cummul . $line;
		}
		if ($state==0 && $line =~ /\%description/) {
			$state = 1;
		}

		if ($line =~ /Summary:\s*(.*)/ && length($summary) < 2) {
			$summary = $1;
		}
		if ($line =~ /URL:\s*(.*)/ && length($url) < 2) {
			$url = $1;
		}
	}
	close(SPEC);
	if (length($cummul) > 4) {
		$description = $cummul;
	}
}

#
# DOAP is a project to create an XML/RDF vocabulary to describe software projects, and in particular open source.
# so if someone ships a .doap file... we can learn from it.
#
sub guess_description_from_doap {
	my ($doapfile) = @_;

	open(DOAP, $doapfile);
	while (<DOAP>) {
		my $line = $_;
		# <shortdesc xml:lang="en">Virtual filesystem implementation for gio</shortdesc>
		if ($line =~ /\<shortdesc .*?\>(.*)\<\/shortdesc\>/) {
			$summary = $1;
		}
		if ($line =~ /\<homepage .*?resource=\"(.*)\"\s*\/>/) {
			$url = $1;
		}
	}
	close(DOAP);
}

#
# Debian control files have some interesting fields we can glean information
# from as well.
#
sub guess_description_from_debian_control {
	my ($file) = @_;

	my $state = 0;
	my $cummul = "";

	$file = $file . "/debian/control";
	
	open(FILE, $file) || return;
	while (<FILE>) {
		my $line = $_;
		if ($state == 1 && length($line) < 2) {
			$state = 2;
		}
		if ($state == 1) {
			$cummul = $cummul . $line;
		}
		if ($state==0 && $line =~ /\Description: (.*)/) {
			$state = 1;
			$cummul = $1;
		}

	}
	close(FILE);
	if (length($cummul) > 4) {
		$description = $cummul;
	}
}

#
# the pkgconfig files have often a one line description
# of the software... good for Summary
#
sub guess_description_from_pkgconfig {
	my ($file) = @_;

	open(FILE, $file);
	while (<FILE>) {
		my $line = $_;

		if ($line =~ /Description:\s*(.*)/ && length($summary) < 2) {
			$summary = $1;
		}
	}
	close(FILE);
}

#
# Freshmeat can provide us with a good one paragraph description
# of the software..
#
sub guess_description_from_freshmeat {
	my ($tarname) = @_;
	my $cummul = "";
	my $state = 0;
	open(HTML, "curl -s http://freshmeat.net/projects/$tarname |");
	while (<HTML>) {
		my $line = $_;

		if ($state == 1) {
			$cummul = $cummul . $line;
		}
		if ($state == 0 && $line =~ /\<div class\=\"project-detail\"\>/) {
			$state = 1;
		}
		if ($state == 1 && $line =~/\<\/p\>/) {
			$state = 2;
		}
	}
	close(HTML);
	$cummul =~ s/\<p\>//g;
	$cummul =~ s/\r//g;
	$cummul =~ s/\<\/p\>//g;
	$cummul =~ s/^\s*//g;
	if (length($cummul)>10) {
		$description = $cummul;
	}
}
#
# If all else fails, just take the first paragraph of the
# readme file
#
sub guess_description_from_readme {
	my ($file) = @_;

	my $state = 0;
	my $cummul = "";
	
	open(FILE, $file);
	while (<FILE>) {
		my $line = $_;
		if ($state == 1 && $line =~ /^\n/ && length($cummul) > 80) {
			$state = 2;
		}
		if ($state == 0 && length($line)>1) {
			$state = 1;
		}
		if ($state == 1) {
			$cummul = $cummul . $line;
		}
		if ($line =~ /(http\:\/\/.*$name.*\.org)/) {
			my $u = $1;
			if ($u =~ /bug/ || length($url) > 1) {
			} else {
				$url = $u;
			}
		}
	}
	close(FILE);
	if (length($cummul) > 4 && length($description)<3) {
		$description = $cummul;
	}
}

#
# Glue all the guesses together
#
sub guess_description {
	my ($directory) = @_;


	@files = <$directory/README*>;
	foreach (@files) {
		guess_description_from_readme($_);
	}

	if (length($name)>2) {
		guess_description_from_freshmeat($name);
	}

	@files = <$directory/*.spec*>;
	foreach (@files) {
		guess_description_from_spec($_);
	}

	guess_description_from_debian_control($directory);

	$name =~ s/ //g;
	@files = <$directory/$name.pc*>;
	foreach (@files) {
		guess_description_from_pkgconfig($_);
	}
	@files = <$directory/*.pc.*>;
	foreach (@files) {
		guess_description_from_pkgconfig($_);
	}
	@files = <$directory/*.pc>;
	foreach (@files) {
		guess_description_from_pkgconfig($_);
	}
	@files = <$directory/*.doap>;
	foreach (@files) {
		guess_description_from_doap($_);
	}

	if (length($summary) < 2) {
		$summary = $description;
		$summary =~ s/\n/ /g;
		$summary =~ s/\s+/ /g;
		if ($summary =~ /(.*?)\./) {
			$summary = $1;
		}
	}

}

# end of Description / Summary section
#
######################################################################



#
# Build the package, and wait for rpm to complain about unpackaged
# files.... which we then use as basis for our %files section
#
sub guess_files_from_rpmbuild {
	my $infiles = 0;
	open(OUTPUTF, "rpmbuild --nodeps --define \"\%_sourcedir $orgdir \" -ba $name.spec 2>&1 |");
	while (<OUTPUTF>) {
		my $line2 = $_;

		if ($infiles == 1 && $line2  =~ /RPM build errors/) {
		        $infiles = 2;
		}
		if ($infiles == 1 && $line2  =~ /^Building/) {
		        $infiles = 2;
		}
		
		if ($infiles == 1) {
			$line2 =~ s/\s*//g;
			push(@allfiles, $line2);
		}
		if ($line2 =~ /    Installed \(but unpackaged\) file\(s\) found\:/) {
			$infiles = 1;
		}
	}
	close(OUTPUTF);
	if (@allfiles == 0) {
		print "Build failed ... stopping here.\n";
		exit(0);
	}

}

sub guess_files_from_oscbuild {
	my $infiles = 0;
	my $restart = 0;	
	my $mustrestart = 0;
        my $rcount = 0;
        my $done_python = 0;
        
        system("osc addremove &> /dev/null");
	system("osc ci -m \"Initial import by autospectacle\" &> /dev/null");

retry: 
        if ($restart > 0) {
                write_yaml();
                print "Restarting the build\n";
        }
        $restart = 0;
        $infiles = 0;
        $mustrestart = 0;
	open(OUTPUTF, "osc build --no-verify $name.spec 2>&1 |");
	while (<OUTPUTF>) {
		my $line2 = $_;
		
#		print "line is $line2\n";
		if ($infiles == 1 && $line2  =~ /RPM build errors/) {
		        $infiles = 2;
		}
		if ($infiles == 1 && $line2  =~ /^Building/) {
		        $infiles = 2;
		}
		if ($infiles == 1) {
			$line2 =~ s/\s*//g;
			push(@allfiles, $line2);
		}
		if ($line2 =~ /No package \'(.*)\' found/) {
                        push_pkgconfig_buildreq("$1");       
                        $restart = $restart + 1;
                        print "    Adding pkgconfig($1) requirement\n";
		}
		if ($line2 =~ /Package requirements \((.*?)\) were not met/) {
		        $pkg = $1;
			# deal with versioned pkgconfig's by removing the spaces around >= 's 
			$pkg =~ s/\>\=\s/\>\=/g;
			$pkg =~ s/\s\>\=/\>\=/g;
			$pkg =~ s/\=\s/\=/g;
			$pkg =~ s/\s\=/\=/g;
		        my @req = split(/ /,$pkg);
                        foreach (@req) {
                                push_pkgconfig_buildreq("$_");       
                                
                                $restart = $restart + 1;
                                print "    Adding pkgconfig($_) requirement\n";
                        }
		}
		if ($line2 =~ /which: no qmake/) {
		        $restart += 1;
                        push_pkgconfig_buildreq("Qt");
                        print "    Adding Qt requirement\n";
		}
		if ($line2 =~ /Cannot find development files for any supported version of libnl/) {
		        $restart += 1;
                        push_pkgconfig_buildreq("libnl-1");
                        print "    Adding libnl requirement\n";
		}
		if ($line2 =~ /<http:\/\/www.cmake.org>/) {
		        $restart += 1;
                        push(@buildreqs, "cmake");
                        print "    Adding cmake requirement\n";
		}
		if ($line2 =~ /checking for (.*?)\.\.\. not_found/ || $line2 =~ /checking for (.*?)\.\.\. no/  || $line2 =~ /checking (.*?)\.\.\. no/) {
		        $pkg = $1;
                        while (($key,$value) = each %failed_commands) {
                                if ($pkg eq $key) {
                                        push(@buildreqs, $value);
                                        print "    Adding $value requirement\n";
                                        $restart += $restart + 1;
                                        $mustrestart = 1;
                                }
                        }
                        
		}

		if ($line2 =~ /checking for [a-zA-Z0-9\_]+ in (.*?)\.\.\. no/) {
		        $pkg = $1;
                        while (($key,$value) = each %failed_libs) {
                                if ($pkg eq $key) {
                                        push(@buildreqs, $value);
                                        print "    Adding $value requirement\n";
                                        $restart += $restart + 1;
                                        $mustrestart = 1;
                                }
                        }
                        
		}

		if ($line2 =~ /-- Could NOT find ([a-zA-Z0-9]+)/) {
		        $pkg = $1;
                        while (($key,$value) = each %failed_libs) {
                                if ($pkg eq $key) {
                                        push(@buildreqs, $value);
                                        print "    Adding $value requirement\n";
                                        $restart += $restart + 1;
                                        $mustrestart = 1;
                                }
                        }
                        
		}

		if ($line2 =~ /fatal error\: (.*)\: No such file or directory/) {
		        $pkg = $1;
                        while (($key,$value) = each %failed_headers) {
                                if ($pkg eq $key) {
                                        push_pkgconfig_buildreq($value);
                                        print "    Adding $value requirement\n";
                                        $restart += $restart + 1;
                                }
                        }
                        
		}
		if ($line2 =~ /checking for UDEV\.\.\. no/) {
		        print "    Adding pkgconfig(udev) requirement\n";
		        push_pkgconfig_buildreq("udev");
		}
		if ($line2 =~ /checking for Apache .* module support/) {
		        print "    Adding pkgconfig(httpd-devel) requirement\n";
		        push(@buildreqs, "httpd-devel");
		        if ($rcount < 3) {
		                $restart = $restart + 1;
		        }
		}
		if ($line2 =~ /([a-zA-Z0-9\-\_]*)\: command not found/i) {
		        my $cmd = $1;
		        my $found = 0;
		        
                        while (($key,$value) = each %failed_commands) {
                                if ($cmd eq $key) {
                                        push(@buildreqs, $value);
                                        print "    Adding $value requirement\n";
                                        $restart += $restart + 1;
                                        $mustrestart = 1;
                                        $found = 1;
                                }
                        }
                        
                        if ($found < 1) {
                                print "    Command $cmd not found!\n";
                        }
		}
		if ($line2 =~ /checking for.*in -ljpeg... no/) {
                        push(@buildreqs, "libjpeg-devel");
                        print "    Adding libjpeg-devel requirement\n";
                        $restart = $restart + 1;
		}
		if ($line2 =~ /fatal error\: zlib\.h\: No such file or directory/) {
                        push(@buildreqs, "zlib-devel");
                        print "    Adding zlib-devel requirement\n";
                        $restart = $restart + 1;
		}
		if ($line2 =~ /error\: xml2-config not found/) {
                        push_pkgconfig_buildreq("libxml-2.0");
                        print "    Adding libxml2-devel requirement\n";
                        $restart = $restart + 1;
		}
		if ($line2 =~ /checking \"location of ncurses\.h file\"/) {
                        push(@buildreqs, "ncurses-devel");
                        print "    Adding ncurses-devel requirement\n";
                        $restart = $restart + 1;
		}
		if (($line2 =~ / \/usr\/include\/python2\.6$/ || $line2 =~ / to compile python extensions/) && $done_python == 0) {
                        push(@buildreqs, "python-devel");
                        print "    Adding python-devel requirement\n";
                        $restart = $restart + 1;
                        $done_python = 1;
		}
		if ($line2 =~ /error: must install xorg-macros 1.6/) {
                        push_pkgconfig_buildreq("xorg-macros");
                        print "    Adding xorg-macros requirement\n";
                        $restart = $restart + 1;
		}
		if ($line2 =~ /installing .*?.gmo as [a-zA-Z0-9\-\.\/\_]+?\/([a-zA-Z0-9\-\_\.]+)\.mo$/) {
		        my $loc = $1;
		        if ($loc eq $localename) {} else {
		                print "    Changing localename from $localename to $loc\n";
        		        $localename = $loc;
                                $restart = $restart + 1;
                        }
		}
		
		if ($infiles == 0 && $line2 =~ /    Installed \(but unpackaged\) file\(s\) found\:/) {
			$infiles = 1;
		}
	}
	close(OUTPUTF);
	if (@allfiles == 0 || $mustrestart > 0) {
	        if ($restart >= 1) 
                {
                        $rcount = $rcount + 1;
                        if ($rcount < 10) {
        	                goto retry;
                        }
	        }
		print "Build failed ... stopping here.\n";
		exit(0);
	}

}

sub process_rpmlint {
	my $infiles = 0;
		

        if ($oscmode == 0) {
                return;
        }		

        print "Verifying package   ....\n";
        
        system("osc addremove &> /dev/null");
	system("osc ci -m \"Final import by autospectacle\" &> /dev/null");

	open(OUTPUTF, "osc build --no-verify $name.spec 2>&1 |");
	while (<OUTPUTF>) {
		my $line2 = $_;
		
#		print "line is $line2\n";
		if ($infiles == 1 && $line2  =~ /RPM build errors/) {
		        $infiles = 2;
		}
		if ($infiles == 1 && $line2  =~ /^Building/) {
		        $infiles = 2;
		}
		if ($infiles == 1) {
			$line2 =~ s/\s*//g;
			push(@allfiles, $line2);
		}
		if ($infiles == 0 && $line2 =~ /    Installed \(but unpackaged\) file\(s\) found\:/) {
			$infiles = 1;
		}
	}
	close(OUTPUTF);

}

sub guess_name_from_url {
	my ($bigurl) = @_;
	
	@spliturl = split(/\//, $bigurl);
	while (@spliturl > 1) {
		shift(@spliturl);
	}
	my $tarfile = $spliturl[0];
	
	if ($tarfile =~ /(.*?)\-([0-9\.\-\~]+)\.tar/) {
		$name = $1;
		$version = $2;
                $version =~ s/\-/\_/g;
	}
}

############################################################################
#
# Output functions
#

sub print_name_and_description
{
	my @lines;

	print OUTFILE "Name       : $name\n";
	print OUTFILE "Version    : $version\n";
	print OUTFILE "Release    : 1\n";
	
	# remove dupes
	undef %saw;
	@saw{@groups} = ();
    	@out = sort keys %saw;

    	if (@out == 1) {
		foreach (@out) {
			print OUTFILE "Group      : $_\n";
		}
	} else {
		print OUTFILE "Group      : $group\n";
	}
	# 
	# Work around spectacle bug
	$summary =~ s/\:\s/ /g;
	$summary =~ s/^([a-z])/\u$1/ig; 
	$summary =~ s/\@//g; 
	$summary = substr($summary, 0, 79);
	
	$summary =~ s/\.^//g;
	if (length($summary) < 1) {
	        $summary = "TO BE FILLED IN";
	}
	#
	print OUTFILE "Summary    : $summary\n";
	print OUTFILE "Description: |\n";

	$description =~ s/&quot;/\"/g;
	$description =~ s/\@//g; 
	@lines = split(/\n/, $description);
	foreach (@lines) {
		print OUTFILE "    $_\n";
	}
	if (length($url)>1) {
		print OUTFILE "URL        : $url\n";
	}

	# remove dupes
	undef %saw;
	@saw{@sources} = ();
    	@out = sort keys %saw;

	print OUTFILE "Sources    : \n";
	foreach (@out) {
		$source = $_;
		$source =~ s/$version/\%\{version\}/g;	

		print OUTFILE "    - $source\n";
	}
	
        if (@patches > 0) {
                print OUTFILE "Patches: \n";
                foreach (@patches) {
                        my $patch = $_;
        		print OUTFILE "    - $patch\n";
                }
        }
	
	print OUTFILE "\n";
	if (length($configure)>2) {
		print OUTFILE "Configure  : $configure\n";
	}
	if (length($localename) > 2) {
		print OUTFILE "LocaleName : $localename\n";
	}
	if (length($builder) > 2) {
	        print OUTFILE "Builder    : $builder\n";
	}
}

sub write_makefile
{
	open(MAKEFILE, ">Makefile");

	print MAKEFILE "PKG_NAME := $name\n";
	print MAKEFILE "SPECFILE = \$(addsuffix .spec, \$(PKG_NAME))\n";
	print MAKEFILE "YAMLFILE = \$(addsuffix .yaml, \$(PKG_NAME))\n";
	print MAKEFILE "\n";
	print MAKEFILE "include /usr/share/packaging-tools/Makefile.common\n";
	
	close(MAKEFILE);
}

sub write_changelog
{
	open(CHANGELOG, ">$name.changes");
	$date = ` date +"%a %b %d %Y"`;	
	chomp($date);
	print CHANGELOG "* $date - Autospectacle <autospectacle\@meego.com> - $version\n";
	print CHANGELOG "- Initial automated packaging\n";
	close(CHANGELOG);
}

sub write_yaml
{
	open(OUTFILE, ">$name.yaml");
	print_name_and_description();
	print_license();
	print_pkgconfig();
	print_buildreq();
	print_files();
	print_devel();
	print_doc();
	close(OUTFILE);

	write_makefile();
	write_changelog();

	system("rm $name.spec");
	system("specify &> /dev/null");
	if ($oscmode > 0) {
	        system("osc addremove");
        	system("osc ci -m \"Import by autospectacle\" &> /dev/null");
        }

}


############################################################################
#
# Main program 
#

if ( @ARGV < 1 ) {
    print "Usage: $0 <url-of-source-tarballs>\n";
    exit(1);
}

if (@ARGV > 1) {
        my $i = 1;
        while ($i < @ARGV) {
                my $patch = $ARGV[$i];
                print "Adding patch $patch\n";
                push(@patches, $patch);
                $i++;
        }
}

setup_licenses();
setup_files_rules();
setup_group_rules();
setup_pkgconfig_ban();
setup_failed_commands();

if (-e ".osc/_packages") {
 $oscmode = 1;
}

my $tmpdir = tempdir();

$dir = $ARGV[0];
guess_name_from_url($dir);
push(@sources, $dir);


#system("cd $tmpdir; curl -s -O $dir");
$orgdir = `pwd`;
chomp($orgdir);
print "Downloading package: $dir\n";
system("wget --quiet $dir");
print "Unpacking to       : $tmpdir\n";

my @tgzfiles = <$orgdir/*.tgz>;
foreach (@tgzfiles) {
        my $tgz = $_;
        my $tar = $tgz;
        $tar =~ s/tgz/tar\.gz/g;
        $dir =~ s/tgz/tar\.gz/g;
        system("mv $tgz $tar");
        guess_name_from_url($dir);
}


#
# I really really hate the fact that meego deleted the -a option from tar.
# this is a step backwards in time that is just silly.
#


system("cd $tmpdir; tar -jxf $orgdir/*\.tar\.bz2");
system("cd $tmpdir; tar -zxf $orgdir/*\.tar\.gz");
print "Parsing content    ....\n";
my @dirs = <$tmpdir/*>;
foreach (@dirs) {
	$dir = $_;
}

$fulldir = $dir;

if ( -e "$dir/autogen.sh" ) {
	$configure = "autogen";
	$uses_configure = 1;
}
if ( -e "$dir/BUILD-CMAKE" ) {
	$configure = "cmake";
	push(@buildreqs, "cmake");
	$uses_configure = 1;
}

if ( -e "$dir/configure" ) {
	$configure = "";
}

my @files = <$dir/configure.*>;

my $findoutput = `find $dir -name "configure.ac"`;
my @findlist = split(/\n/, $findoutput);
foreach (@findlist) {
	push(@files, $_);
}
foreach (@files) {
	process_configure_ac("$_");
}

$findoutput = `find $dir -name "*.pro"`;
@findlist = split(/\n/, $findoutput);
foreach (@findlist) {
	process_qmake_pro("$_");
}

if (-e "$dir/$name.pro") {
        $builder = "qmake";
        push_pkgconfig_buildreq("Qt");
}


#
# This is a good place to generate configure.in
#
if (length($configure) > 2) {
	if ($configure eq "autogen") {
		system("cd $dir ; ./autogen.sh &> /dev/null");
	}
}
@files = <$dir/configure>;
foreach (@files) {
	process_configure("$_");
}

if ($uses_configure == 0) {
	$configure = "none"; 
}

@files = <$dir/COPY*>;
foreach (@files) {
	guess_license_from_file("$_");
}

@files = <$dir/LICENSE*>;
foreach (@files) {
	guess_license_from_file("$_");
}


@files = <$dir/GPL*>;
foreach (@files) {
	guess_license_from_file("$_");
}


guess_description($dir);


#
# Output of the yaml file
#


if ($oscmode == 1) {
	print "Creating OBS project $name ...\n";
	system("osc mkpac $name &> /dev/null");
	system("mkdir $name &> /dev/null");
	chdir($name);
	system("mv ../$name*\.tar\.* .");
}

write_yaml();
print "Building package   ....\n";

if ($oscmode == 0) {
	guess_files_from_rpmbuild();
} else {
 	guess_files_from_oscbuild();
}

apply_files_rules();

$printed_subpackages = 0;
write_yaml();

process_rpmlint();

print "Spectacle creation complete.\n";
