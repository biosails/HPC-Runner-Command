#!/usr/bin/env bash

if [[ $TRAVIS_OS_NAME = "linux" ]]
then
    tag=Linux
else
    tag=MacOSX
fi

# install conda
mkdir -p /anaconda
curl -O https://repo.continuum.io/miniconda/Miniconda3-$MINICONDA_VER-$tag-x86_64.sh
sudo bash Miniconda3-$MINICONDA_VER-$tag-x86_64.sh -b -p /anaconda
sudo chown -R $USER /anaconda
export PATH=/anaconda/bin:$PATH

conda config --add channels nyuad-cgsb && \
conda config --add channels conda-forge && \
conda config --add channels defaults && \
conda config --add channels r && \
conda config --add channels bioconda

conda install -y perl perl-app-cpanminus perl-moose perl-test-class-moose perl-path-tiny

#Install
# cpanm --notest Package::DeprecationManager
cpanm --notest --installdeps .
# cpanm --quiet --notest --skip-satisfied Dist::Milla
# cpan-install --notest Dist::Zilla::Plugin::AutoPrereqs
# cpan-install --coverage   # installs converage prereqs, if enabled

#Before Script
# coverage-setup

#Run tests
prove -l -v t/test_class_tests.t

#After success
# coverage-report
