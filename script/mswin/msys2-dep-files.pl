#!/usr/bin/perl

use Modern::Perl;
use Path::Tiny;
use Capture::Tiny qw(capture_stdout);
use YAML::XS qw(DumpFile);

sub main {
	my $package_list_file = shift @ARGV or die "Need to pass path to package list";
	$package_list_file = path( $package_list_file );

	my @packages = $package_list_file->lines_utf8({ chomp => 1 });
	my $package_deps = {};
	my $package_deps_graphviz = {};
	my $package_set = {};

	for my $package (@packages) {
		my ($linear_stdout, $linear_exit) = capture_stdout {
			system( qw(pactree -l), $package );
		};
		my $dep_packages = [ split /\n/, $linear_stdout ];
		$package_deps->{ $package } = $dep_packages;
		for my $dep_package (@$dep_packages) {
			$package_set->{ $dep_package } = 1;
		}

		my ($graphviz_stdout, $graphviz_exit) = capture_stdout {
			system( qw(pactree -g), $package );
		};
		$package_deps_graphviz->{ $package } = $graphviz_stdout;
	}

	my $package_files = {};
	for my $package (keys %$package_set) {
		my ($stdout, $exit) = capture_stdout {
			system( qw(pacman -Ql), $package );
		};
		my @files = map { s/^[\w-]+\s+//r } split /\n/, $stdout;

		$package_files->{ $package } = \@files;
	}

	my $output = {
		linear => $package_deps,
		graphviz => $package_deps_graphviz,
		files => $package_files,
	};
	DumpFile( "msys2-dep-files.yml", $output );

}

main;
