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
our $RENARD_DEVOPS_HOOK_PRE_PERL = '';
our $RENARD_DEVOPS_HOOK_PRE_PERL_RAN = 0;

package Renard::Devops::Dictionary {
	our @devops_script_perl_deps = qw(Module::CPANfile YAML::Tiny);

	our $repeat_count = 1;

	our $filter_grep = ''
		. q| -e '^Possibly harmless'|
		. q| -e '^Attempt to reload.*aborted'|
		. q| -e 'BEGIN failed--compilation aborted'|
		. q| -e '^Can.*t locate.*in \@INC'|
		. q| -e '^Compilation failed in require'|;

	our $INSTALL_CMD_VIA_CPANM = <<EOF;
	cpanm --notest .;
EOF

	our $INSTALL_VIA_CPANM = <<EOF;
	n=0;
	until [ \$n -ge $repeat_count ]; do
		cpanm --notest --installdeps .
		n=\$((n+1));
	done;
EOF

	our $INSTALL_CMD_VIA_DZIL = <<EOF;
	export DZIL=\$(which dzil);

	n=0;
	until [ \$n -ge $repeat_count ]; do
		perl \$DZIL build --in build-dir;
		cpanm --notest ./build-dir && break;
	done;
EOF

	our $INSTALL_VIA_DZIL = <<EOF;
	export DZIL=\$(which dzil);

	n=0;
	until [ \$n -ge $repeat_count ]; do
		perl \$DZIL authordeps | xargs cpanm -n && break;
		echo '=== authordeps missing ==='
		perl \$DZIL authordeps --missing
		echo '=========================='
		n=\$((n+1));
	done

	n=0;
	until [ \$n -ge $repeat_count ]; do
		perl \$DZIL listdeps | grep -v $filter_grep
		perl \$DZIL listdeps | grep -v $filter_grep | cpanm -n && break;
		n=\$((n+1));
	done
EOF
}


sub add_to_shell_script {
	my ($cmd) = @_;
	$shell_script_commands .= "$cmd\n";
}

sub get_system {
	my $system;

	if( Renard::Devops::Conditional::is_under_travis_ci() ) {
		if ( Renard::Devops::Conditional::is_under_travis_ci_osx() ) {
			say STDERR "Running under Travis CI osx";
			$system = 'Renard::Devops::Env::MacOS::Homebrew';
		} elsif( Renard::Devops::Conditional::is_under_travis_ci_linux() ) {
			say STDERR "Running under Travis CI linux";
			$system = 'Renard::Devops::Env::Linux::Debian';
		}
	} elsif( Renard::Devops::Conditional::is_under_appveyor_ci() ) {
		say STDERR "Running under Appveyor";
		$system = 'Renard::Devops::Env::MSWin::MSYS2';
	}

	return $system;
}

sub get_devops_branch {
	unless( -d $devops_dir ) {
		say STDERR "Cloning from devops [branch: $ENV{DEVOPS_BRANCH}]";
		clone_repo('https://github.com/project-renard/devops.git', $ENV{DEVOPS_BRANCH} // 'master' );
	}
}

sub main {
	my $mode;
	if( @ARGV == 0 ) {
		$mode = 'auto';
	} elsif( $ARGV[0] eq 'install' ) {
		$mode = 'install';
	} elsif( $ARGV[0] eq 'install-perl-dep' ) {
		$mode = 'install-perl-dep';
	} elsif( $ARGV[0] eq 'test' ) {
		$mode = 'test';
	} elsif( $ARGV[0] eq 'vagrant' ) {
		$mode = 'vagrant';
	} else {
		die "Unknown mode";
	}

	my $current_repo = Renard::Devops::Repo->new(
		path => File::Spec->rel2abs('.'),
		main_repo => ( $mode ne 'install-perl-dep' ) , );

	$RENARD_DEVOPS_HOOK_PRE_PERL = $ENV{RENARD_DEVOPS_HOOK_PRE_PERL};
	if( $RENARD_DEVOPS_HOOK_PRE_PERL && $RENARD_DEVOPS_HOOK_PRE_PERL !~ /;\s*$/ ) {
		$RENARD_DEVOPS_HOOK_PRE_PERL .= ';';
	}

	my $system = get_system();
	if( $mode eq 'auto' || $mode eq 'install' ) {
		get_devops_branch();
		stage_before_install($system, $current_repo);
		stage_install($system, $current_repo);

		say STDERR "Shell commands:\n===========\n$shell_script_commands\n===========";

		say "#START\n".$shell_script_commands."\n#END";
	} elsif( $mode eq 'test' ) {
		stage_test($system, $current_repo);
	} elsif( $mode eq 'install-perl-dep' ) {
		$system->repo_install_perl_dep($current_repo);
	} elsif( $mode eq 'vagrant' ) {
		$ENV{UNDER_VAGRANT} = 1;
		$system = 'Renard::Devops::Env::Vagrant';

		$system->run;
	}
}

sub stage_before_install {
	my ($system, $current_repo) = @_;

	get_aux_repo($current_repo);
	main::add_to_shell_script( <<'EOF' );
		export RENARD_TEST_DATA_PATH='external/project-renard/test-data';
		export RENARD_SCRIPT_BASE='external/project-renard/devops/script';
EOF

	$system->pre_native;
	$system->pre_perl;
}

sub stage_install {
	my ($system, $current_repo) = @_;

	my $deps = $current_repo->cpanfile_git_data;
	my @values = values %$deps;
	for my $repos (@values) {
		my $path = clone_repo( $repos->{git}, $repos->{branch} );
		my $repo = Renard::Devops::Repo->new( path => $path );

		stage_install($system, $repo);
	}

	$system->repo_install_native($current_repo);
	$system->repo_install_perl($current_repo);
}

sub clone_repo {
	my ($url, $branch) = @_;
	$branch = 'master' unless $branch;

	say STDERR "Cloning $url @ [branch: $branch]";
	my ($parts) = $url =~ m,^https?://[^/]+/(.+?)(?:\.git)?$,;
	my $path = File::Spec->catfile('external', split(m|/|, $parts));

	unless( -d $path ) {
		system(qw(git clone),
			qw(-b), $branch,
			$url,
			$path) == 0
		or die "Could not clone $url @ $branch";
	} else {
		chomp(my $branch_on_disk = `cd $path && git rev-parse --abbrev-ref HEAD`);
		if( $branch_on_disk eq $branch ) {
			say STDERR "Not cloning $url : already have branch $branch";
		} else {
			say STDERR "Not cloning $url : wanted $branch but $branch_on_disk is cloned";
		}
	}

	return $path;
}

sub stage_test {
	my ($system, $current_repo) = @_;

	$system->repo_test($current_repo);
}

sub get_aux_repo {
	my ($current_repo) = @_;

	for my $repo (qw(devops test-data)) {
		unless( -d "external/project-renard/$repo" ) {
			say STDERR "Cloning $repo";
			clone_repo("https://github.com/project-renard/$repo.git");
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
			export PKG_CONFIG_PATH='$ENV{PKG_CONFIG_PATH}';
EOF
	}

	sub pre_perl {
		system(qw(brew install cpanm)) == 0
			or die "Could not install cpanm";

		say STDERR "Create a local::lib";
		system(q(cpanm --local-lib=~/perl5 local::lib));
		push @INC, "$ENV{HOME}/perl5/lib/perl5";
		require local::lib;
		local::lib->setup_env_hash_for("$ENV{HOME}/perl5");
		system(qw(cpanm), @Renard::Devops::Dictionary::devops_script_perl_deps);
		main::add_to_shell_script(<<'EOF');
			eval $(perl -I ~/perl5/lib/perl5/ -Mlocal::lib);
			export ARCHFLAGS='-arch x86_64';
EOF
	}

	sub repo_install_native {
		my ($system, $repo) = @_;

		my $deps = $repo->homebrew_get_packages;
		say STDERR "Installing repo native deps";
		system( qq{brew install @$deps} );
	}

	sub repo_install_perl {
		my ($system, $repo) = @_;

		# Override the rest of the default Perl Travis-CI commands because we are done.
		# Default for install: cpanm --quiet --installdeps --notest .
		# Default for script: make test (no M::B or EUMM)
		my $dist_ini = File::Spec->catfile($repo->path, 'dist.ini');
		my $helper_script = File::Spec->catfile($devops_dir, qw(script helper.pl));

		if( $RENARD_DEVOPS_HOOK_PRE_PERL &&  ! $RENARD_DEVOPS_HOOK_PRE_PERL_RAN ) {
			main::add_to_shell_script($RENARD_DEVOPS_HOOK_PRE_PERL);
			$RENARD_DEVOPS_HOOK_PRE_PERL_RAN = 1;
		}

		if( $repo->main_repo ) {
			main::add_to_shell_script( <<EOF );
			function cpanm {
				eval \$(perl -I ~/perl5/lib/perl5/ -Mlocal::lib);
				if [ -r $dist_ini ]; then
					command cpanm -n Moose~2.2005 Dist::Zilla;
					dzil authordeps | command cpanm -n;
					command cpanm -n Function::Parameters;
					dzil listdeps | grep -v @{[ $Renard::Devops::Dictionary::filter_grep ]} | command cpanm -n;
				else
					echo 'Installing deps';
					command cpanm -n Function::Parameters;
					command cpanm --notest --installdeps .;
				fi;
			};

			function make {
				export TEST_JOBS=4;
				if [ "\$#" == 1 ] && [ "\$1" == "test" ]; then
					prove -j\${TEST_JOBS} -lvr t;
				fi;
			};
EOF
		} else {
			my $helper_script = File::Spec->rel2abs(File::Spec->catfile($devops_dir, qw(script helper.pl)));
			my $repo_path = $repo->path;
			main::add_to_shell_script( <<EOF );
				( cd $repo_path; perl $helper_script install-perl-dep );
EOF
		}
	}

	sub repo_install_perl_dep {
		my ($system, $repo) = @_;

		my $dist_ini = File::Spec->catfile($repo->path, 'dist.ini');
		my $repo_path = $repo->path;
		if( -r $dist_ini ) {
			# Need to also install Moose so that we have the latest
			# that can be used with Module::Runtime >= 0.014
			system(q|cpanm -n Moose~2.2005 Dist::Zilla|);
			system( "cd $repo_path; " . $Renard::Devops::Dictionary::INSTALL_VIA_DZIL
				. ( ! $repo->main_repo ? $Renard::Devops::DictionaryINSTALL_CMD_VIA_DZIL : '' )  );
		} else {
			system( "cd $repo_path; " . $Renard::Devops::Dictionary::INSTALL_VIA_CPANM
				. ( ! $repo->main_repo ? $Renard::Devops::Dictionary::INSTALL_CMD_VIA_CPANM : '' )  );
		}
	}

	sub repo_test {
		my ($system, $repo) = @_;

		if( Renard::Devops::Conditional::is_under_travis_ci_osx() ) {
			# automatic `make test`
			return;
		}
	}
};

package Renard::Devops::Env::Linux::Debian {
	use Env qw(@PATH);

	sub pre_native {
		if( Renard::Devops::Conditional::is_under_travis_ci_linux() ) {
			# start xvfb (for headless env)
			# give xvfb some time to start
			main::add_to_shell_script( <<'EOF' );
				export DISPLAY=:99.0;
				sh -e /etc/init.d/xvfb start;
				sleep 3;
EOF
		}
	}

	sub pre_perl {
		if( Renard::Devops::Conditional::is_under_travis_ci_linux() ) {
			system(q(curl -L http://cpanmin.us | perl - --self-upgrade));
			push @PATH, "$ENV{HOME}/perl5/bin";
			system(q(cpanm --local-lib=~/perl5 local::lib));
			push @INC, "$ENV{HOME}/perl5/lib/perl5";
			require local::lib;
			local::lib->setup_env_hash_for("$ENV{HOME}/perl5");
			system(qw(cpanm), @Renard::Devops::Dictionary::devops_script_perl_deps);
			# Perl will be set up by Travis Perl helpers
			main::add_to_shell_script( <<'EOF' );
				eval $(perl -I ~/perl5/lib/perl5/ -Mlocal::lib);
				eval $(curl https://travis-perl.github.io/init) --auto;
EOF
			return;
		}
	}

	sub repo_install_native {
		my ($system, $repo) = @_;

		if( Renard::Devops::Conditional::is_under_travis_ci_linux() ) {
			# Repo native dependencies will be installed by Travis CI
			return;
		}
	}

	sub repo_install_perl {
		my ($system, $repo) = @_;

		if( $RENARD_DEVOPS_HOOK_PRE_PERL &&  ! $RENARD_DEVOPS_HOOK_PRE_PERL_RAN ) {
			main::add_to_shell_script($RENARD_DEVOPS_HOOK_PRE_PERL);
			$RENARD_DEVOPS_HOOK_PRE_PERL_RAN = 1;
		}

		# NOTE: we only run coverage on Linux.
		if( $repo->main_repo ) {
			main::add_to_shell_script( <<'EOF' );
			if [ -n "$COVERAGE" ] && [ "$COVERAGE" != "0" ]; then
				echo "Make B::Deparse use Data::Dumper";
				FULL_RENARD_SCRIPT_BASE=$(cd $RENARD_SCRIPT_BASE && pwd);
				export PERL5LIB="${PERL5LIB}${PERL5LIB:+:}""$FULL_RENARD_SCRIPT_BASE/general";
				export HARNESS_PERL_SWITCHES="${HARNESS_PERL_SWITCHES}${HARNESS_PERL_SWITCHES:+ }""-MDeparseDumper";
				echo PERL5LIB="$PERL5LIB";
				echo HARNESS_PERL_SWITCHES="$HARNESS_PERL_SWITCHES";
			fi;
EOF
		} else {
			my $helper_script = File::Spec->rel2abs(File::Spec->catfile($devops_dir, qw(script helper.pl)));
			my $repo_path = $repo->path;
			main::add_to_shell_script( <<EOF );
				( cd $repo_path; perl $helper_script install-perl-dep );
EOF
		}
	}

	sub repo_install_perl_dep {
		my ($system, $repo) = @_;

		my $dist_ini = File::Spec->catfile($repo->path, 'dist.ini');
		my $repo_path = $repo->path;
		if( -r $dist_ini ) {
			system(q|cpanm -n Dist::Zilla|);
			system( "cd $repo_path; " . $Renard::Devops::Dictionary::INSTALL_VIA_DZIL
				. ( ! $repo->main_repo ? $Renard::Devops::DictionaryINSTALL_CMD_VIA_DZIL : '' )  );
		} else {
			system( "cd $repo_path; " . $Renard::Devops::Dictionary::INSTALL_VIA_CPANM
				. ( ! $repo->main_repo ? $Renard::Devops::Dictionary::INSTALL_CMD_VIA_CPANM : '' )  );
		}
	}


	sub repo_test {
		my ($system, $repo) = @_;

		if( Renard::Devops::Conditional::is_under_travis_ci_linux() ) {
			# automatic `make test`
			return;
		}
	}
}

package Renard::Devops::Env::MSWin::MSYS2 {
	sub run_under_mingw {
		my ($cmd) = @_;
		my $msystem_lc = lc $ENV{MSYSTEM};
		local $ENV{PATH} = "C:\\$ENV{MSYS2_DIR}\\$msystem_lc\\bin;C:\\$ENV{MSYS2_DIR}\\usr\\bin;$ENV{PATH}";
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

		system(q{cpan App::cpanminus});
		say STDERR 'Installing devops script deps for the system Perl';
		system(qw(cpanm), @Renard::Devops::Dictionary::devops_script_perl_deps);

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
			perl -V;
			pl2bat `which pl2bat`;
			yes | cpan App::cpanminus;
			cpanm --notest ExtUtils::MakeMaker Module::Build;
			cpanm --notest @{[ @Renard::Devops::Dictionary::devops_script_perl_deps ]};
EOF
	}

	sub repo_install_native {
		my ($system, $repo) = @_;

		# Native deps
		my $deps = $repo->msys2_mingw64_get_packages;

		run_under_mingw( <<"EOF" );
			xargs pacman -S --needed --noconfirm @$deps;
EOF
	}

	sub pre_install_dzil {
		run_under_mingw( _install_env() . <<EOF );
			pacman -S --needed --noconfirm mingw-w64-x86_64-openssl
			cpanm -n Term::ReadKey --build-args=RM=echo;
			cpanm Win32::Process

			n=0;
			until [ \$n -ge $Renard::Devops::Dictionary::repeat_count ]; do
				cpanm -n Dist::Zilla && break;
				n=\$((n+1));
			done

			export DZIL=\$(which dzil);
			sed -i 's,/usr/bin/perl,'\$(which perl), \$DZIL
EOF
	}

	sub _install_env {
		return <<EOF;
			. \$APPVEYOR_BUILD_FOLDER/$devops_dir/script/mswin/EUMMnosearch.sh;
			export MAKEFLAGS='-j4 -P4';
EOF
	}

	sub repo_install_via_dzil {
		my ($system, $repo) = @_;
		$system->pre_install_dzil;
		my $repo_path = $system->get_repo_path_cygwin($repo);
		run_under_mingw( "cd $repo_path; " . _install_env() . $Renard::Devops::Dictionary::INSTALL_VIA_DZIL
			. ( ! $repo->main_repo ? $Renard::Devops::Dictionary::INSTALL_CMD_VIA_DZIL : '' )  );
	}

	sub repo_install_via_cpanm {
		my ($system, $repo) = @_;
		my $repo_path = $system->get_repo_path_cygwin($repo);
		run_under_mingw( "cd $repo_path; " . _install_env() . $Renard::Devops::Dictionary::INSTALL_VIA_CPANM
			. ( ! $repo->main_repo ? $Renard::Devops::Dictionary::INSTALL_CMD_VIA_CPANM : '' )  );
	}

	sub repo_install_perl {
		my ($system, $repo) = @_;

		if( $RENARD_DEVOPS_HOOK_PRE_PERL &&  ! $RENARD_DEVOPS_HOOK_PRE_PERL_RAN ) {
			run_under_mingw($RENARD_DEVOPS_HOOK_PRE_PERL);
			$RENARD_DEVOPS_HOOK_PRE_PERL_RAN = 1;
		}

		my $dist_ini = File::Spec->catfile($repo->path, 'dist.ini');
		if( -r $dist_ini ) {
			$system->repo_install_via_dzil($repo);
		} else {
			$system->repo_install_via_cpanm($repo);
		}
	}



	sub get_repo_path_cygwin {
		my ($system, $repo) = @_;
		my $repo_path_orig = $repo->path;
		chomp(my $repo_path = `cygpath -u $repo_path_orig`);

		$repo_path;
	}

	sub repo_test {
		my ($system, $repo) = @_;

		my $repo_path = $system->get_repo_path_cygwin($repo);
		my $ret = run_under_mingw( <<EOF );
			cd $repo_path;

			export TEST_JOBS=4;
			. external/project-renard/devops/ENV.sh;
			prove -j\${TEST_JOBS} -lvr t;
EOF
		exit 1 if $ret != 0;
	}
}

package Renard::Devops::Repo {
	sub new {
		my ($class, %opt) = @_;

		my $data = {};

		$data->{_path} = $opt{path} if exists $opt{path};

		die "Path $data->{_path} is not readable directory"
			unless -d $data->{_path} and -r $data->{_path};

		# need to indicate if this is the main repo
		$data->{_main_repo} = $opt{main_repo} // 0;

		return bless $data, $class;
	}
	sub path { $_[0]->{_path} }
	sub main_repo { $_[0]->{_main_repo} }

	sub cpanfile_git_data {
		my ($self) = @_;

		eval  {
			require Module::CPANfile;
		} or die "Could not load Module::CPANfile";

		my $data = {};
		my $cpanfile_git_path = File::Spec->catfile($self->path, qw(maint cpanfile-git));
		if ( -r $cpanfile_git_path  ) {
			my $m = Module::CPANfile->load($cpanfile_git_path);
			$data = +{ map { $_->requirement->name => $_->requirement->options }
				@{ $m->{_prereqs}->{prereqs} } }
		}

		return $data;
	}

	sub devops_config_path {
		File::Spec->catfile( $_[0]->path, qw(maint devops.yml) );
	}

	sub devops_data {
		my ($self) = @_;

		eval{
			require YAML::Tiny;
		} or die "Could not load YAML::Tiny";

		YAML::Tiny::LoadFile( $self->devops_config_path );
	}

	sub slurp_package_list_file {
		my ($self, $file) = @_;

		return [] unless -r $file;

		open my $fh, '<', $file or die;
		local $/ = undef;
		my $data = <$fh>;
		close $fh;
		$data =~ s/#.*//;

		my $package_list = [ split /\s+/, $data ];;
	}

	sub debian_get_packages {
		my ($self) = @_;

		my $data = [];
		if( -r $self->devops_config_path ) {
			push @$data, @{ $self->devops_data->{native}{debian}{packages} };
		} elsif( -r $self->debian_packages_path ) {
			push @$data, @{ $self->slurp_package_list_file( $self->debian_packages_path ) };
		}

		return $data;
	}

	sub homebrew_get_packages {
		my ($self) = @_;

		my $data = [];
		if( -r $self->devops_config_path ) {
			push @$data, @{ $self->devops_data->{native}{'macos-homebrew'}{packages} };
		} elsif( -r $self->homebrew_packages_path ) {
			push @$data, @{ $self->slurp_package_list_file( $self->homebrew_packages_path ) };
		}

		return $data;
	}

	sub msys2_mingw64_get_packages {
		my ($self) = @_;

		my $data = [];
		if( -r $self->devops_config_path ) {
			push @$data, @{ $self->devops_data->{native}{'msys2-mingw64'}{packages} };
		} elsif( -r $self->msys2_mingw64_packages_path ) {
			push @$data, @{ $self->slurp_package_list_file( $self->msys2_mingw64_packages_path ) };
		}

		return $data;
	}

	sub debian_packages_path {
		File::Spec->catfile( $_[0]->path, qw(maint packages-debian) );
	}

	sub homebrew_packages_path {
		File::Spec->catfile( $_[0]->path, qw(maint packages-homebrew));
	}

	sub msys2_mingw64_packages_path {
		File::Spec->catfile( $_[0]->path, qw(maint packages-msys2-mingw64));
	}
};
