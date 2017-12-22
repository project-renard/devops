package EUMMnosearch;

package main;
# only run when we call the Makefile.PL script
if( $0 eq "Makefile.PL"  ) {
	require ExtUtils::MakeMaker;

	my $i = ExtUtils::MakeMaker->can("import");
	no warnings "redefine";
	*ExtUtils::MakeMaker::import = sub {
		&$i;
		#my $targ = caller;
		my $targ = "main";
		my $wm = $targ->can("WriteMakefile");
		*{"${targ}::WriteMakefile"} = sub {
			my %args = @_;
			# Only apply :nosearch after lib linker directory
			# for entire mingw64 system. This way XS modules
			# that depend on other XS modules can compile
			# statically using .a files.
			#
			# The pattern needs to be case-insensitive because
			# Windows is case-insensitive.
			chomp(my $lib_path = `cygpath -m /mingw64/lib`);
			$args{LIBS} =~ s,^(.*?)(\Q-L$lib_path\E\s),$1 :nosearch $2,i;

			# Special case for expat (XML::Parser::Expat) because
			# it does not use either of
			#
			#   - -L<libpath>
			#   - pkg-config --libs expat
			$args{LIBS} =~ s,(\Q-lexpat\E),:nosearch $1,;
			print "LIBS: $args{LIBS}\n";
			$wm->(%args);
		};
	};

        do "Makefile.PL" or die "Hack failed: $@";

        # we can exit now that we are done
        exit 0;
}

1;
