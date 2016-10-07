#!perl
#===============================================================================
#
#         FILE: notebook.pl
#
#        USAGE: ./notebook.pl
#
#  DESCRIPTION:
#
#      OPTIONS: ---
# REQUIREMENTS: ---
#         BUGS: ---
#        NOTES: ---
#       AUTHOR: YOUR NAME (),
# ORGANIZATION:
#      VERSION: 1.0
#      CREATED: 06/29/2015 10:41:53 AM
#     REVISION: ---
#===============================================================================

use utf8;
package Main;

use HPC::Runner::Command;

HPC::Runner::Command->new_with_command()->execute();
