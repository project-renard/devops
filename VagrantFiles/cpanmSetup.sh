source ~/perl5/perlbrew/etc/bashrc
perlbrew install perl-5.20.3
perlbrew install-cpanm
perlbrew switch perl-5.20.3
cd /home/vagrant/curie
cpanm --installdeps .
