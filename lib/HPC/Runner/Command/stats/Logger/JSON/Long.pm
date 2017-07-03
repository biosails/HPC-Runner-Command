use strict;
use warnings;

package HPC::Runner::Command::stats::Logger::JSON::Long;

use Moose::Role;
use Data::Dumper;
use JSON;
use Text::ASCIITable;

sub iter_jobs_long {
    my $self       = shift;
    my $submission = shift;
    my $jobref     = shift;

    my $submission_id = $submission->{uuid};
    my $table         = $self->build_table($submission);

    $table->setCols(
        [
            'Jobname',
            'TaskID',
            'Task Tags',
            'Start Time',
            'End Time',
            'Duration',
            'Exit Code'
        ]
    );

    foreach my $job ( @{$jobref} ) {
        my $jobname = $job->{job};

        if ( $self->jobname ) {
            next unless $self->jobname eq $jobname;
        }
        my $total_tasks = $job->{total_tasks};

        my $tasks = $self->get_tasks( $submission_id, $jobname );
        $self->iter_tasks_long( $jobname, $tasks, $table );

        $self->task_data( {} );
    }

    print $table;
    print "\n";
}

sub iter_tasks_long {
    my $self    = shift;
    my $jobname = shift;
    my $tasks   = shift;
    my $table   = shift;

    foreach my $task ( @{$tasks} ) {

        my $task_tags  = $task->{task_tags}  || '';
        my $start_time = $task->{start_time} || '';

        my $end_time = $task->{exit_time} || '';
        my $duration = $task->{duration}  || '';
        my $exit_code = $task->{exit_code};
        my $task_id = $task->{task_id} || '';

        if ( !defined $exit_code ) {
            $exit_code = '';
        }

        $table->addRow(
            [
                $jobname,  $task_id,  $task_tags, $start_time,
                $end_time, $duration, $exit_code,
            ]
        );

    }
}

sub get_tasks {
    my $self          = shift;
    my $submission_id = shift;
    my $jobname       = shift;

    ##Get the running tasks
    my $basename = $self->data_tar->basename('.tar.gz');
    my $running_file =
      File::Spec->catdir( $basename, $jobname, 'running.json' );

    my $running = {};
    if ( $self->archive->contains_file($running_file) ) {
        my $running_json = $self->archive->get_content($running_file);
        $running = decode_json($running_json);
    }

    my $complete = {};
    my $complete_file =
      File::Spec->catdir( $basename, $jobname, 'complete.json' );
    if ( $self->archive->contains_file($complete_file) ) {
        my $complete_json = $self->archive->get_content($complete_file);
        $complete = decode_json($complete_json);
    }

    my $total_tasks = [];
    foreach ( sort { $a <=> $b } keys(%{$running}) ) {
      push(@{$total_tasks}, $running->{$_});
    }
    foreach ( sort { $a <=> $b } keys(%{$complete}) ) {
      push(@{$total_tasks}, $complete->{$_});
    }
    return $total_tasks;
}

1;
