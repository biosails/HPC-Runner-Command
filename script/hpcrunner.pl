#!perl

use strict;
use warnings FATAL => 'all';
use utf8;

package Main;

use HPC::Runner::Command;

HPC::Runner::Command->new_with_command()->execute();
