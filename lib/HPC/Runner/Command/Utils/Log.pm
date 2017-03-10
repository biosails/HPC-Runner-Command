package HPC::Runner::Command::Utils::Log;

use Log::Log4perl qw(:easy);
use Data::Dumper;
use IPC::Open3;
use IO::Select;
use Symbol;
use DateTime;
use DateTime::Format::Duration;
use Cwd;
use File::Path qw(make_path);
use File::Spec;

use MooseX::App::Role;
use MooseX::Types::Path::Tiny qw/Path Paths AbsPath AbsFile/;

with 'HPC::Runner::Command::Utils::Base';

=head1 HPC::Runner::Command::Utils::Log

Class for all logging attributes

=head2 Command Line Options


=head3 logdir

Pattern to use to write out logs directory. Defaults to outdir/prunner_current_date_time/log1 .. log2 .. log3.

=cut

option 'logdir' => (
    is       => 'rw',
    isa      => AbsPath,
    coerce   => 1,
    lazy     => 1,
    required => 1,
    default  => \&set_logdir,
    documentation =>
q{Directory where logfiles are written. Defaults to current_working_directory/prunner_current_date_time/log1 .. log2 .. log3'},
    trigger => \&_make_the_dirs,
);

=head3 show_process_id

Show process_id in each log file. This is useful for aggregating logs

=cut

option 'show_processid' => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0,
    documentation =>
q{Show the process ID per logging message. This is useful when aggregating logs.}
);

=head3 process_table

We also want to write all cmds and exit codes to a table

=cut

option 'process_table' => (
    isa     => 'Str',
    is      => 'rw',
    lazy    => 1,
    handles => {
        add_process_table     => 'append',
        prepend_process_table => 'prepend',
        clear_process_table   => 'clear',
    },
    default => sub {
        my $self          = shift;
        my $process_table = $self->logdir . "/001-task_table.md";

        open( my $pidtablefh, ">>" . $process_table )
          or die $self->app_log->fatal("Couldn't open process file $!\n");

        print $pidtablefh
"||Version|| Scheduler Id || Jobname || Task Tags || ProcessID || ExitCode || Duration ||\n";
        close($pidtablefh);
        return $process_table;
    },
    lazy => 1,
);

=head3 tags

Submission tags

=cut

option 'tags' => (
    is            => 'rw',
    isa           => 'ArrayRef',
    documentation => 'Tags for the whole submission',
    default       => sub { return [] },
    cmd_split     => qr/,/,
    required      => 0,
);

=head3 metastr

JSON string passed from HPC::Runner::App::Scheduler. It describes the total number of jobs, processes, and job batches.

=cut

option 'metastr' => (
    is            => 'rw',
    isa           => 'Str',
    documentation => q{Meta str passed from HPC::Runner::Command::Scheduler},
    required      => 0,
);

option 'logname' => (
    isa      => 'Str',
    is       => 'rw',
    default  => 'hpcrunner_logs',
    required => 0,
);

=head2 Internal Attributes

You shouldn't be calling these directly.

=cut

has 'dt' => (
    is      => 'rw',
    isa     => 'DateTime',
    default => sub { return DateTime->now( time_zone => 'local' ); },
    lazy    => 1,
);

#TODO Change to submit_log and execute_log

##Application log
has 'app_log' => (
    is      => 'rw',
    default => sub {
        my $self = shift;

        Log::Log4perl->init( \ <<'EOT');
  log4perl.category = DEBUG, Screen
  log4perl.appender.Screen = \
      Log::Log4perl::Appender::ScreenColoredLevels
  log4perl.appender.Screen.layout = \
      Log::Log4perl::Layout::PatternLayout
  log4perl.appender.Screen.layout.ConversionPattern = \
      [%d] %m %n
EOT
        return get_logger();
      }

);

##Submit Log
has 'log' => (
    is      => 'rw',
    default => sub { my $self = shift; return $self->init_log },
    lazy    => 1
);

# ##Command Log
# has 'command_log' => ( is => 'rw', );

has 'logfile' => (
    traits  => ['String'],
    is      => 'rw',
    default => \&set_logfile,
    handles => {
        append_logfile  => 'append',
        prepend_logfile => 'prepend',
        clear_logfile   => 'clear',
    }
);

# #TODO This should be changed to execute_jobs Logging
# #We also have task_tags as an ArrayRef for JobDeps
#
# has 'task_tags' => (
#     traits  => ['Hash'],
#     is      => 'rw',
#     isa     => 'HashRef',
#     default => sub { {} },
#     handles => {
#         set_task_tag     => 'set',
#         get_task_tag     => 'get',
#         has_no_task_tags => 'is_empty',
#         num_task_tags    => 'count',
#         delete_task_tag  => 'delete',
#         task_tag_pairs   => 'kv',
#     },
# );
#
# #TODO This should be changed to execute_jobs Logging
# #We also have task_tags as an ArrayRef for JobDeps
#
# has 'task_deps' => (
#     traits  => ['Hash'],
#     is      => 'rw',
#     isa     => 'HashRef',
#     default => sub { {} },
#     handles => {
#         set_task_dep     => 'set',
#         get_task_dep     => 'get',
#         has_no_task_deps => 'is_empty',
#         num_task_deps    => 'count',
#         delete_task_dep  => 'delete',
#         task_dep_pairs   => 'kv',
#     },
# );

# =head3 table_data
#
# Each time we make an update to the table throw it in here
#
# =cut
#
# has 'table_data' => (
#     traits  => ['Hash'],
#     is      => 'rw',
#     isa     => 'HashRef',
#     default => sub { {} },
#     handles => {
#         set_table_data    => 'set',
#         get_table_data    => 'get',
#         delete_table_data => 'delete',
#         has_no_table_data => 'is_empty',
#         num_table_data    => 'count',
#         table_data_pairs  => 'kv',
#         clear_table_data  => 'clear',
#     },
# );

=head2 Subroutines

=head3 set_logdir

Set the log directory

=cut

sub set_logdir {
    my $self = shift;

    my $logdir;

    if ( $self->has_version ) {
        if ( $self->has_project ) {

            $logdir =
                "hpc-runner/"
              . $self->version . "/"
              . $self->project . "/logs" . "/"
              . $self->set_logfile . "-"
              . $self->logname;
        }
        else {
            $logdir =
                "hpc-runner/"
              . $self->version . "/logs" . "/"
              . $self->set_logfile . "-"
              . $self->logname;
        }
    }
    else {
        if ( $self->has_project ) {

            $logdir =
                "hpc-runner/"
              . $self->project
              . "/logs/"
              . $self->set_logfile . "-"
              . $self->logname;
        }
        else {

            $logdir =
              "hpc-runner/logs/" . $self->set_logfile . "-" . $self->logname;
        }
    }

    $logdir =~ s/\.log$//;
    $self->_make_the_dirs($logdir);

    return $logdir;
}

=head3 set_logfile

Set logfile

=cut

sub set_logfile {
    my $self = shift;

    my $tt = DateTime->now( time_zone => 'local' )->ymd();
    return "$tt";
}

=head3 init_log

Initialize Log4perl log

=cut

sub init_log {
    my $self = shift;

    Log::Log4perl->easy_init(
        {
            level  => $TRACE,
            utf8   => 1,
            mode   => 'append',
            file   => ">>" . $self->logdir . "/" . $self->logfile,
            layout => '%d: %p %m%n '
        }
    );

    my $log = get_logger();
    return $log;
}

sub log_main_messages {
    my ( $self, $level, $message ) = @_;

    return unless $message;
    $level = 'info' unless $level;
    $self->log->$level($message);
}
# #TODO Move this to App/execute_job/Log ... something to mark that this logs the
# #individual processes that are executed
#
# =head3 _log_commands
#
# Log the commands run them. Cat stdout/err with IO::Select so we hopefully don't break things.
#
# This example was just about 100% from the following perlmonks discussions.
#
# http://www.perlmonks.org/?node_id=151886
#
# You can use the script at the top to test the runner. Just download it, make it executable, and put it in the infile as
#
# perl command.pl 1
# perl command.pl 2
# #so on and so forth
#
# =cut
#
# #TODO move to execute_jobs
#
# sub _log_commands {
#     my ( $self, $pid ) = @_;
#
#     my $dt1 = DateTime->now( time_zone => 'local' );
#
#     $DB::single = 2;
#
#     my ( $cmdpid, $exitcode ) = $self->log_job;
#
#     my $ymd = $dt1->ymd();
#     my $hms = $dt1->hms();
#
#     #TODO Make table data its own class and return it
#     $self->clear_table_data;
#     $self->set_table_data( cmdpid     => $cmdpid );
#     $self->set_table_data( start_time => "$ymd $hms" );
#
#     my $meta = $self->pop_note_meta;
#     $self->set_task_tag( $cmdpid => $meta ) if $meta;
#
#     $self->log_cmd_messages( "info",
#         "Finishing job " . $self->counter . " with ExitCode $exitcode",
#         $cmdpid );
#
#     my $dt2      = DateTime->now();
#     my $duration = $dt2 - $dt1;
#     my $format   = DateTime::Format::Duration->new( pattern =>
#           '%Y years, %m months, %e days, %H hours, %M minutes, %S seconds' );
#
#     $self->log_cmd_messages( "info",
#         "Total execution time " . $format->format_duration($duration),
#         $cmdpid );
#
#     $self->log_table( $cmdpid, $exitcode, $format->format_duration($duration) );
#
#     return $exitcode;
# }
#
# =head3 name_log
#
# Default is dt, jobname, counter
#
# =cut
#
# #TODO move to execute_jobs
#
# sub name_log {
#     my $self   = shift;
#     my $cmdpid = shift;
#
#     my $counter = $self->counter;
#
#     $self->logfile( $self->set_logfile );
#     $counter = sprintf( "%03d", $counter );
#     $self->append_logfile( "-CMD_" . $counter . "-$cmdpid.md" );
#
#     $self->set_task_tag( "$counter" => $cmdpid );
# }
#
# #TODO move to execute_jobs
#
# sub log_table {
#     my $self     = shift;
#     my $cmdpid   = shift;
#     my $exitcode = shift;
#     my $duration = shift;
#
#     my $dt1 = DateTime->now( time_zone => 'local' );
#     my $ymd = $dt1->ymd();
#     my $hms = $dt1->hms();
#
#     $self->set_table_data( exit_time => "$ymd $hms" );
#     $self->set_table_data( exitcode  => $exitcode );
#     $self->set_table_data( duration  => $duration );
#
#     my $version = $self->version || "0.0";
#     my $task_tags = "";
#
#     my $logfile = $self->logdir . "/" . $self->logfile;
#
#     open( my $pidtablefh, ">>" . $self->process_table )
#       or die $self->app_log->fatal("Couldn't open process file $!\n");
#
#     #or die print "Couldn't open process file $!\n";
#
#     if ( $self->can('task_tags') ) {
#         my $aref = $self->get_task_tag($cmdpid) || [];
#         $task_tags = join( ", ", @{$aref} ) || "";
#
#         $self->set_table_data( task_tags => $task_tags );
#     }
#
#     if ( $self->can('version') && $self->has_version ) {
#         $version = $self->version;
#         $self->set_table_data( version => $version );
#     }
#
#     if ( $self->can('job_scheduler_id') && $self->can('jobname') ) {
#         my $schedulerid = $self->job_scheduler_id || '';
#
#         if ( $self->can('task_id') ) {
#             $schedulerid = $schedulerid . '_' . $self->task_id;
#         }
#
#         my $jobname = $self->jobname || '';
#         print $pidtablefh <<EOF;
# |$version|$schedulerid|$jobname|$task_tags|$cmdpid|$exitcode|$duration|
# EOF
#
#         $self->set_table_data( schedulerid => $schedulerid );
#         $self->set_table_data( jobname     => $jobname );
#     }
#     else {
#         print $pidtablefh <<EOF;
# |$cmdpid|$exitcode|$duration|
# EOF
#     }
# }

# #TODO move to execute_jobs
#
# sub log_cmd_messages {
#     my ( $self, $level, $message, $cmdpid ) = @_;
#
#     return unless $message;
#     return unless $level;
#
#     if ( $self->show_processid && $cmdpid ) {
#         $self->command_log->$level("PID: $cmdpid\t$message");
#     }
#     else {
#         $self->command_log->$level($message);
#     }
# }

# sub log_main_messages {
#     my ( $self, $level, $message ) = @_;
#
#     return unless $message;
#     $level = 'info' unless $level;
#     $self->log->$level($message);
# }

# #TODO move to execute_jobs
# sub log_job {
#     my $self = shift;
#
#     #Start running job
#     my ( $infh, $outfh, $errfh );
#     $errfh = gensym();    # if you uncomment this line, $errfh will
#     my $cmdpid;
#     eval { $cmdpid = open3( $infh, $outfh, $errfh, $self->cmd ); };
#
#     if ($@) {
#         die $self->app_log->fatal(
#             "There was an error running the command $@\n");
#     }
#
#     if ( !$cmdpid ) {
#         $self->app_log->fatal(
# "There is no process id please contact your administrator with the full command\n"
#         );
#         die;
#     }
#
#     $infh->autoflush();
#
#     my $scheduler_id = $self->job_scheduler_id;
#     if($self->can('task_id')){
#       $scheduler_id = $scheduler_id . '_'.$self->task_id;
#     }
#
#     if($scheduler_id){
#       $self->name_log("SID_".$scheduler_id);
#     }
#     else{
#       $self->name_log("PID_".$cmdpid);
#     }
#
#     $self->command_log( $self->init_log );
#
#     $DB::single = 2;
#
#     $self->log_cmd_messages( "info",
#         "Starting Job:\n\tJobID:\t" . $scheduler_id . " \n\tCmdPID:\t" . $cmdpid . "\n\n\n",
#         $cmdpid );
#
#     #TODO counter is not terribly applicable with task ids
#     $self->log_cmd_messages( "info",
#         "Starting execution: " . $self->counter . "\n\nCOMMAND:\n" . $self->cmd . "\n\n\n",
#         $cmdpid );
#
#     $DB::single = 2;
#
#     my $sel = new IO::Select;    # create a select object
#     $sel->add( $outfh, $errfh ); # and add the fhs
#
#     while ( my @ready = $sel->can_read ) {
#         foreach my $fh (@ready) {    # loop through them
#             my $line;
#
#             # read up to 4096 bytes from this fh.
#             my $len = sysread $fh, $line, 4096;
#             if ( not defined $len ) {
#
#                 # There was an error reading
#                 $self->log_cmd_messages( "fatal", "Error from child: $!",
#                     $cmdpid );
#             }
#             elsif ( $len == 0 ) {
#
#                 # Finished reading from this FH because we read
#                 # 0 bytes.  Remove this handle from $sel.
#                 $sel->remove($fh);
#                 next;
#             }
#             else {    # we read data alright
#                 if ( $fh == $outfh ) {
#                     $self->log_cmd_messages( "info", $line, $cmdpid );
#                 }
#                 elsif ( $fh == $errfh ) {
#                     $self->log_cmd_messages( "error", $line, $cmdpid );
#                 }
#                 else {
#                     $self->log_cmd_messages( 'fatal', "Shouldn't be here!\n" );
#                 }
#             }
#         }
#     }
#
#     waitpid( $cmdpid, 1 );
#     my $exitcode = $?;
#
#     return ( $cmdpid, $exitcode );
# }

# sub pop_note_meta {
#     my $self = shift;
#
#     my $lines = $self->cmd;
#     return unless $lines;
#     my @lines = split( "\n", $lines );
#     my @ts = ();
#
#     foreach my $line (@lines) {
#         next unless $line;
#         next unless $line =~ m/^#TASK/;
#
#         my ( @match, $t1, $t2 );
#         @match = $line =~ m/TASK (\w+)=(.+)$/;
#         ( $t1, $t2 ) = ( $match[0], $match[1] );
#
#         $DB::single = 2;
#         if ($t1) {
#             if ( $t1 eq "tags" ) {
#                 my @tmp = split( ",", $t2 );
#                 map { push( @ts, $_ ) } @tmp;
#             }
#             elsif ( $t1 eq "deps" ) {
#                 my @tmp = split( ",", $t2 );
#                 map { push( @ts, $_ ) } @tmp;
#             }
#             else {
#                 #We should give a warning here
#                 $self->$t1($t2);
#                 $self->log_main_messages( 'debug',
#                         "Command:\n\t"
#                       . $self->cmd
#                       . "\nHas invalid #TASK attribute. Should be #TASK tags=thing1,thing2 or #TASK deps=thing1,thing2"
#                 );
#             }
#         }
#     }
#     return \@ts;
# }

1;
