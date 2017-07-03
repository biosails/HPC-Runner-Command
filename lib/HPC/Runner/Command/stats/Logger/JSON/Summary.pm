use strict;
use warnings;

package HPC::Runner::Command::stats::Logger::JSON::Summary;
use Moose::Role;

use Data::Dumper;
use Log::Log4perl qw(:easy);
use JSON;
use Text::ASCIITable;

##These are likely the same across Logging Plugins

sub iter_jobs_summary {
    my $self       = shift;
    my $submission = shift;
    my $jobref     = shift;

    if($self->json){
      $self->iter_jobs_summary_json($submission, $jobref);
    }
    else{
      $self->iter_jobs_summary_table($submission, $jobref);
    }
}

##These should be roles
sub iter_jobs_summary_json {
    my $self = shift;
    my $submission = shift;
    my $jobref     = shift;

    my $submission_id = $submission->{uuid};

    my $summary = {};
    foreach my $job ( @{$jobref} ) {
        my $jobname = $job->{job};
        if ( $self->jobname ) {
            next unless $self->jobname eq $jobname;
        }
        my $total_tasks = $job->{total_tasks};

        $self->iter_tasks_summary( $submission_id, $jobname );
        $self->task_data->{$jobname}->{total} = $total_tasks;

        $summary->{$jobname} = {};

        $summary->{$jobname}->{complete} =
          $self->task_data->{$jobname}->{complete};
        $summary->{$jobname}->{running} =
          $self->task_data->{$jobname}->{running};
        $summary->{$jobname}->{success} =
          $self->task_data->{$jobname}->{success};
        $summary->{$jobname}->{fail}  = $self->task_data->{$jobname}->{fail};
        $summary->{$jobname}->{total} = $self->task_data->{$jobname}->{total};

        $self->task_data( {} );
    }

    my $submission_obj = {};
    $submission_obj->{$submission_id} = $summary;
    push(@{$self->json_summary}, $submission_obj);
}

sub iter_jobs_summary_table {
    my $self       = shift;
    my $submission = shift;
    my $jobref     = shift;

    my $submission_id = $submission->{uuid};
    my $table         = $self->build_table($submission);
    $table->setCols(
        [ 'JobName', 'Complete', 'Running', 'Success', 'Fail', 'Total' ] );

    foreach my $job ( @{$jobref} ) {
        my $jobname = $job->{job};
        if ( $self->jobname ) {
            next unless $self->jobname eq $jobname;
        }
        my $total_tasks = $job->{total_tasks};

        $self->iter_tasks_summary( $submission_id, $jobname );
        $self->task_data->{$jobname}->{total} = $total_tasks;

        $table->addRow(
            [
                $jobname,
                $self->task_data->{$jobname}->{complete},
                $self->task_data->{$jobname}->{running},
                $self->task_data->{$jobname}->{success},
                $self->task_data->{$jobname}->{fail},
                $self->task_data->{$jobname}->{total},
            ]
        );
        $self->task_data( {} );
    }

    print $table;
    print "\n";
}

##This is probably mostly the same across plugins
sub iter_tasks_summary {
    my $self          = shift;
    my $submission_id = shift;
    my $jobname       = shift;

    my $running = $self->count_running_tasks( $submission_id, $jobname );
    my $success = $self->count_successful_tasks( $submission_id, $jobname );
    my $fail = $self->count_failed_tasks( $submission_id, $jobname );
    my $complete = $success + $fail;

    $self->task_data->{$jobname} = {
        complete => $complete,
        success  => $success,
        fail     => $fail,
        running  => $running
    };
}

###These are logging platform specific

sub count_running_tasks {
    my $self          = shift;
    my $submission_id = shift;
    my $jobname       = shift;

    my $basename = $self->data_tar->basename('.tar.gz');
    my $running_file =
      File::Spec->catdir( $basename, $jobname, 'running.json' );

    if ( $self->archive->contains_file($running_file) ) {
        my $running_json = $self->archive->get_content($running_file);
        ##TODO Add in some error checking
        my $running = decode_json($running_json);
        my @keys    = keys %{$running};
        return scalar @keys;
    }
    else {
        return 0;
    }
}

sub count_successful_tasks {
    my $self          = shift;
    my $submission_id = shift;
    my $jobname       = shift;

    return $self->search_complete( $jobname, 1 );
}

sub count_failed_tasks {
    my $self          = shift;
    my $submission_id = shift;
    my $jobname       = shift;

    return $self->search_complete( $jobname, 0 );
}

sub search_complete {
    my $self    = shift;
    my $jobname = shift;
    my $success = shift;

    my $basename = $self->data_tar->basename('.tar.gz');
    my $complete_file =
      File::Spec->catdir( $basename, $jobname, 'complete.json' );

    if ( $self->archive->contains_file($complete_file) ) {
        my $complete_json = $self->archive->get_content($complete_file);
        ##TODO Add in some error checking
        my $complete = decode_json($complete_json);
        return $self->look_for_exit_code( $complete, $success );
    }
    else {
        return 0;
    }

}

sub look_for_exit_code {
    my $self     = shift;
    my $complete = shift;
    my $success  = shift;

    my $task_count = 0;
    foreach my $task ( keys %{$complete} ) {
        my $task_data = $complete->{$task};

        if ( $success && $task_data->{exit_code} == 0 ) {
            $task_count++;
        }
        elsif ( !$success && $task_data->{exit_code} != 0 ) {
            $task_count++;
        }
    }

    return $task_count;
}

1;
