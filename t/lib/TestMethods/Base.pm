package TestMethods::Base;

use strict;
use warnings;

use Test::Class::Moose;
use FindBin qw($Bin);
use File::Path qw(make_path remove_tree);
use IPC::Cmd qw[can_run];

sub make_test_dir{

    my $test_dir;

    my @chars = ('a'..'z', 'A'..'Z', 0..9);
    my $string = join '', map { @chars[rand @chars]  } 1 .. 8;

    if(exists $ENV{'TMP'}){
        $test_dir = $ENV{TMP}."/hpcrunner/$string";
    }
    else{
        $test_dir = "/tmp/hpcrunner/$string";
    }

    remove_tree($test_dir);
    make_path($test_dir);
    make_path("$test_dir/script");

    chdir($test_dir);

    if(can_run('git') && !-d $test_dir."/.git"){
        system('git init');
    }

    return $test_dir;
}

sub test_shutdown {

    chdir("$Bin");

    if ( exists $ENV{'TMP'} ) {
        remove_tree( $ENV{TMP} . "/hpcrunner" );
    }
    else {
        remove_tree("/tmp/hpcrunner");
    }
}

sub print_diff {
    my $got    = shift;
    my $expect = shift;

    use Text::Diff;

    my $diff = diff \$got, \$expect;
    diag("Diff is\n\n$diff\n\n");

    my $fh;
    open( $fh, ">got.diff" ) or die print "Couldn't open $!\n";
    print $fh $got;
    close($fh);

    open( $fh, ">expect.diff" ) or die print "Couldn't open $!\n";
    print $fh $expect;
    close($fh);

    open( $fh, ">diff.diff" ) or die print "Couldn't open $!\n";
    print $fh $diff;
    close($fh);

    ok(1);
}

1;
