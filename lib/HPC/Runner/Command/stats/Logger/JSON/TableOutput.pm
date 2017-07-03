package HPC::Runner::Command::stats::Logger::JSON::TableOutput;

use Moose::Role;
use namespace::autoclean;

use Text::ASCIITable;

## TODO This one is mostly the same
sub build_table {
    my $self = shift;
    my $res  = shift;

    my $start_time = $res->{submission_time} || '';
    my $project    = $res->{project}    || '';
    my $id         = $res->{uuid}       || '';
    my $header     = "Time: " . $start_time;
    $header .= " Project: " . $project;
    $header .= "\nSubmissionID: " . $id;
    my $table = Text::ASCIITable->new( { headingText => $header } );

    return $table;
}

sub iter_jobs_summary {
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


1;
