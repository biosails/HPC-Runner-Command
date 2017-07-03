package HPC::Runner::Command::stats::Logger::JSON::Summary::JSONOutput;

use Moose::Role;
use namespace::autoclean;
use JSON;

with 'HPC::Runner::Command::stats::Logger::JSON::JSONOutput';

##These should be roles
sub iter_jobs_summary {
    my $self       = shift;
    my $submission = shift;
    my $jobref     = shift;

    my $submission_id = $submission->{uuid};
    my $start_time = $submission->{submission_time} || '';
    my $project    = $submission->{project}    || '';

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
    $submission_obj->{$submission_id}->{jobs} = $summary;
    $submission_obj->{$submission_id}->{project} = $project;
    $submission_obj->{$submission_id}->{submission_time} = $start_time;
    push( @{ $self->json_data }, $submission_obj );
}

after 'iter_submissions' => sub {
    my $self = shift;
    my $json = encode_json( $self->json_data );
    print $json;
    print "\n";
};

1;
