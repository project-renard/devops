#!/usr/bin/env perl
# ABSTRACT: Helper for development

use FindBin;
use lib "$FindBin::Bin/../lib";

use strict;
use warnings;

use feature qw(say);
use Getopt::Long;
use File::Spec;
#use autodie;

package Renard::Devops::Conditional {
	sub is_under_travis_ci { exists $ENV{TRAVIS_OS_NAME} && $ENV{TRAVIS_OS_NAME} }
	sub is_under_travis_ci_osx { $ENV{TRAVIS_OS_NAME} eq 'osx' }
	sub is_under_travis_ci_linux { $ENV{TRAVIS_OS_NAME} eq 'linux' }
	sub is_under_appveyor_ci { exists $ENV{APPVEYOR_BUILD_FOLDER} && $ENV{APPVEYOR_BUILD_FOLDER} }
	sub is_under_vagrant { exists $ENV{UNDER_VAGRANT} && $ENV{UNDER_VAGRANT} }
	sub is_under_debian { -f '/etc/debian_version' }
}

our $shell_script_commands = '';
our $devops_dir = 'external/project-renard/devops';

sub add_to_shell_script {
	my ($cmd) = @_;
	$shell_script_commands .= "$cmd\n";
}

sub main {
	my $mode;
	my $system;

	if( @ARGV == 0 || $ARGV[0] eq 'install' || $ARGV[0] eq 'test' ) {
		$mode = 'auto';
	} elsif( $ARGV[0] eq 'vagrant' ) {
		$mode = 'vagrant';
	} else {
		die "Unknown mode";
	}

	if( $mode eq 'auto' ) {
		unless( exists $ENV{DEVOPS_BRANCH} && $ENV{DEVOPS_BRANCH} ) {
			$ENV{DEVOPS_BRANCH} = 'master';
		}
		unless( -d $devops_dir ) {
			say STDERR "Cloning from devops [branch: $ENV{DEVOPS_BRANCH}]";
			system(
				qw(git clone),
				qw(-b), $ENV{DEVOPS_BRANCH},
				qw(https://github.com/project-renard/devops.git), $devops_dir,
			) == 0 or die "Could not clone devops directory: $!";
		}
		if( Renard::Devops::Conditional::is_under_travis_ci() ) {
			if ( Renard::Devops::Conditional::is_under_travis_ci_osx() ) {
				say STDERR "Running under Travis CI osx";
				$system = 'Renard::Devops::Env::MacOS::Homebrew';
			} elsif( Renard::Devops::Conditional::is_under_travis_ci_linux() ) {
				say STDERR "Running under Travis CI linux";
				$system = 'Renard::Devops::Env::Linux::Debian';
			}

			stage_before_install($system);
			stage_install($system);
		} elsif( Renard::Devops::Conditional::is_under_appveyor_ci() ) {
			$system = 'Renard::Devops::Env::MSWin::MSYS2';
			if( $ARGV[0] eq 'install' ) {
				say STDERR "Running under Appveyor install";

				stage_before_install($system);
				stage_install($system);

			} elsif( $ARGV[0] eq 'test' ) {
				say STDERR "Running under Appveyor test";

				stage_test($system);
			}
		}

		say STDERR "Shell commands:\n===========\n$shell_script_commands\n===========";

		say "#START\n".$shell_script_commands."\n#END";
	} elsif( $mode eq 'vagrant' ) {
		$ENV{UNDER_VAGRANT} = 1;
		$system = 'Renard::Devops::Env::Vagrant';

		$system->run;
	}
}

sub stage_before_install {
	my ($system) = @_;

	get_aux_repo();
	main::add_to_shell_script( <<'EOF' );
		export RENARD_TEST_DATA_PATH="external/project-renard/test-data";
		export RENARD_SCRIPT_BASE="external/project-renard/devops/script";
EOF

	$system->pre_native;
	$system->pre_perl;
}

sub stage_install {
	my ($system) = @_;

	$system->repo_install_native;
	$system->repo_install_perl;
}

sub stage_test {
	my ($system) = @_;

	$system->repo_test;
}

sub get_aux_repo {
	for my $repo (qw(devops test-data)) {
		unless( -d "external/project-renard/$repo" ) {
			say STDERR "Cloning $repo";
			system(qw(git clone),
				"https://github.com/project-renard/$repo.git",
				"external/project-renard/$repo") == 0
			or die "Could not clone $repo";
		}
	}
}

main;


#####

package Renard::Devops::Env::Vagrant {
	sub pipe_to_bash {
		my ($cmd) = @_;
		open( my $fh, '|bash');
		$fh->autoflush(1);
		say $fh "$cmd";
	}

	sub run {
		my ($system) = @_;
		$system->pre_native;
		$system->pre_perl;
		#$system->repo_install_native;
		$system->repo_install_perl;
	}

	sub pre_native {
		pipe_to_bash( <<'END' );
sudo apt-get -y update
sudo apt-get -y upgrade
sudo apt-get -y install build-essential vim curl wget libgirepository1.0-dev libgdl-3-5 gobject-introspection libgtk-3-dev
sudo apt-get -y install gir1.2-gdl-3 libpoppler-glib-dev poppler-utils mupdf-tools git libglib-object-introspection-perl
sudo apt-get -y install --no-install-recommends glade
sudo apt-get -y install libssl-dev

echo "Adding the ENV settings"
cat <<'EOF' >> $HOME/.bashrc.project-renard
for ENV_PATH in ~/project-renard/devops/ENV.sh ~/project-renard/devops/devops/ENV.sh; do
	if [ -f $ENV_PATH ]; then
		. $ENV_PATH
	fi
done
EOF
echo "source ~/.bashrc.project-renard" >> $HOME/.bashrc

END
	}

	sub pre_perl {
		pipe_to_bash( <<'END' );
curl -L http://install.perlbrew.pl | bash
echo "source ~/perl5/perlbrew/etc/bashrc" >> ~/.bashrc
source ~/perl5/perlbrew/etc/bashrc
perlbrew install perl-5.20.3
perlbrew install-cpanm
perlbrew switch perl-5.20.3
END
	}

	sub repo_install_perl {
		pipe_to_bash( <<'END' );
source ~/perl5/perlbrew/etc/bashrc
source ~/.bashrc.project-renard

cd $(_repo_dir curie)

# do not run tests because these may fail when not in interactive shell
cpanm --notest Term::ReadKey

cpanm --installdeps .
cpanm Dist::Zilla
END
	}
}


package Renard::Devops::Env::MacOS::Homebrew {
	use Env qw(@PKG_CONFIG_PATH);

	sub pre_native {
		my ($self) = @_;
		say STDERR "Updating homebrew";
		system(qw(brew update));

		# Set up for X11 support
		say STDERR "Installing xquartz homebrew cask for X11 support";
		system(qw(brew tap Caskroom/cask));
		system(qw(brew install Caskroom/cask/xquartz));

		# Set up for libffi linking
		unshift @PKG_CONFIG_PATH, '/usr/local/opt/libffi/lib/pkgconfig';
		main::add_to_shell_script( <<EOF );
			export PKG_CONFIG_PATH="$ENV{PKG_CONFIG_PATH}";
EOF
	}

	sub pre_perl {
		system(qw(brew install cpanm)) == 0
			or die "Could not install cpanm";

		# Create a local::lib
		system(qw(cpanm --local-lib=~/perl5 local::lib));
		main::add_to_shell_script(<<'EOF');
			eval $(perl -I ~/perl5/lib/perl5/ -Mlocal::lib);
EOF
	}

	sub repo_install_native {
		main::add_to_shell_script( <<'EOF' );
		( sed 's/#.*//' < homebrew-packages | xargs brew install );
EOF
	}

	sub repo_install_perl {
		# Override the rest of the default Perl Travis-CI commands because we are done.
		# Default for install: cpanm --quiet --installdeps --notest .
		# Default for script: make test (no M::B or EUMM)
		main::add_to_shell_script( <<'EOF' );
		export ARCHFLAGS="-arch x86_64";
		function cpanm {
			eval $(perl -I ~/perl5/lib/perl5/ -Mlocal::lib);
			echo "Installing Moose (required for Function::Parameters)";
			command cpanm -n Moose --verbose;
			echo "Installing deps";
			command cpanm --notest --installdeps .;
			echo "Installing Alien::MuPDF";
			command cpanm -n Alien::MuPDF --verbose;
		};

		function make {
			export TEST_JOBS=4;
			if [ "$#" == 1 ] && [ "$1" == "test" ]; then
				prove -j${TEST_JOBS} -lvr t;
			fi;
		};
EOF
	}

	sub repo_test {
		if( Renard::Devops::Conditional::is_under_travis_ci_osx() ) {
			# automatic `make test`
			return;
		}
	}
};

package Renard::Devops::Env::Linux::Debian {
	sub pre_native {
		if( Renard::Devops::Conditional::is_under_travis_ci_linux() ) {
			# start xvfb (for headless env)
			# give xvfb some time to start
			main::add_to_shell_script( <<'EOF' );
				export DISPLAY=:99.0;
				sh -e /etc/init.d/xvfb start || return $?;
				sleep 3
EOF
		}
	}

	sub pre_perl {
		if( Renard::Devops::Conditional::is_under_travis_ci_linux() ) {
			# Perl will be set up by Travis Perl helpers
			return;
		}
	}

	sub repo_install_native {
		if( Renard::Devops::Conditional::is_under_travis_ci_linux() ) {
			# Repo native dependencies will be installed by Travis CI
			return;
		}
	}

	sub repo_install_perl {
		# NOTE: we only run coverage on Linux.
		main::add_to_shell_script( <<'EOF' );
		cpanm --local-lib=~/perl5 local::lib && eval $(perl -I ~/perl5/lib/perl5/ -Mlocal::lib);
		eval $(curl https://travis-perl.github.io/init) --auto;

		if [ -n "$COVERAGE" ] && [ "$COVERAGE" != "0" ]; then
			echo "Make B::Deparse use Data::Dumper";
			FULL_RENARD_SCRIPT_BASE=$(cd $RENARD_SCRIPT_BASE && pwd);
			export PERL5LIB="${PERL5LIB}${PERL5LIB:+:}""$FULL_RENARD_SCRIPT_BASE/general";
			export HARNESS_PERL_SWITCHES="${HARNESS_PERL_SWITCHES}${HARNESS_PERL_SWITCHES:+ }""-MDeparseDumper";
			echo PERL5LIB="$PERL5LIB";
			echo HARNESS_PERL_SWITCHES="$HARNESS_PERL_SWITCHES";
		fi;
EOF
	}

	sub repo_test {
		if( Renard::Devops::Conditional::is_under_travis_ci_linux() ) {
			# automatic `make test`
			return;
		}
	}
}

package Renard::Devops::Env::MSWin::MSYS2 {
	sub run_under_mingw {
		my ($cmd) = @_;
		local $ENV{PATH} = "C:\\$ENV{MSYS2_DIR}\\$ENV{MSYSTEM}\\bin;C:\\$ENV{MSYS2_DIR}\\usr\\bin;$ENV{PATH}";
		return system( qw(bash -c), $cmd);
	}

	sub pre_native {

#echo Compiler: %COMPILER%
#echo Architecture: %MSYS2_ARCH%
#echo Platform: %PLATFORM%
#echo MSYS2 directory: %MSYS2_DIR%
#echo MSYS2 system: %MSYSTEM%
#echo Bits: %BIT%

#REM Create a writeable TMPDIR
#mkdir %APPVEYOR_BUILD_FOLDER%\tmp
#set TMPDIR=%APPVEYOR_BUILD_FOLDER%\tmp

#IF %COMPILER%==msys2 (
  #@echo on
  #SET "PATH=C:\%MSYS2_DIR%\%MSYSTEM%\bin;C:\%MSYS2_DIR%\usr\bin;%PATH%"

		# Appveyor under MSYS2/MinGW64
		run_under_mingw( <<EOF );
			pacman -S --needed --noconfirm pacman-mirrors;
			pacman -S --needed --noconfirm git;
EOF

		# Update
		run_under_mingw( <<EOF );
			pacman -Syu --noconfirm;
EOF

		# build tools
		run_under_mingw( <<'EOF' );
			pacman -S --needed --noconfirm mingw-w64-x86_64-toolchain autoconf automake libtool make patch mingw-w64-x86_64-libtool
EOF

		# There is not a corresponding cc for the mingw64 gcc. So we copy it in place.
		run_under_mingw( <<'EOF' );
		cp -pv /mingw64/bin/gcc /mingw64/bin/cc
EOF
	}

	sub pre_perl {
		run_under_mingw( <<EOF );
			pacman -S --needed --noconfirm mingw-w64-x86_64-perl;
			pl2bat `which pl2bat`;
			yes | cpan App::cpanminus;
			cpanm --notest ExtUtils::MakeMaker Module::Build;
EOF
	}

	sub repo_install_native {
		# Native deps
		run_under_mingw( <<'EOF' );
			xargs pacman -S --needed --noconfirm < $APPVEYOR_BUILD_FOLDER/msys2-mingw64-packages
EOF
	}

	sub repo_install_perl {
		run_under_mingw( <<EOF );
			. $devops_dir/script/mswin/EUMMnosearch.sh
			export MAKEFLAGS='-j4 -P4'

			# Install via cpanfile
			cpanm --notest --installdeps .
EOF
	}

	sub repo_test {
		my $ret = run_under_mingw( <<'EOF' );
			cd $APPVEYOR_BUILD_FOLDER;

			export TEST_JOBS=4;
			. external/project-renard/devops/ENV.sh;
			prove -j${TEST_JOBS} -lvr t;
EOF
		exit 1 if $ret != 0;
	}
}

package Renard::Devops::Repo {

};
