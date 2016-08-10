package HPC::Runner::App::Scheduler::JobStats;

#use Moose::Role;
use Moose;
use Data::Dumper;

=head1 HPC::Runner::App::Scheduler::JobStats

=head2 Attributes

Package Attributes

=cut

=head3 job_stats

HashRef of job stats - total jobs submitted, total processes, etc

=cut

has 'total_processes' => (
    traits  => ['Number'],
    is      => 'rw',
    isa     => 'Num',
    default => 0,
    handles => {
        set_total_processes => 'set',
        add_total_processes => 'add',
    },
);

has 'tally_commands' => (
    traits  => ['Number'],
    is      => 'rw',
    isa     => 'Num',
    default => 1,
    handles => { add_tally_commands => 'add', },
);

has 'total_batches' => (
    traits  => ['Number'],
    is      => 'rw',
    isa     => 'Num',
    default => 0,
    handles => {
        set_total_batches => 'set',
        add_total_batches => 'add',
    },
);

has batches => (
    traits  => ['Hash'],
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { {} },
    handles => {
        set_batches     => 'set',
        defined_batches => 'defined',

        #keys_batches     => 'keys',
        #exists_batches  => 'exists',
        #get_batches     => 'get',
        #has_no_batches  => 'is_empty',
        #num_batches     => 'count',
        #delete_batches  => 'delete',
        #pairs_batches   => 'kv',
    },
);

has jobnames => (
    traits  => ['Hash'],
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { {} },
    handles => {
        keys_jobnames    => 'keys',
        defined_jobnames => 'defined',
        set_jobnames     => 'set',
        exists_jobnames  => 'exists',

        #get_jobnames     => 'get',
        #has_no_jobnames  => 'is_empty',
        #num_jobnames     => 'count',
        #delete_jobnames  => 'delete',
        #pairs_jobnames   => 'kv',
    },
);

=head2 Subroutines


=head3 create_meta_str

=cut

sub create_meta_str {
    my $self          = shift;
    my $counter       = shift;
    my $batch_counter = shift;
    my $current_job   = shift;

    my $batchname = $counter . "_" . $current_job;

    my $batch = $self->{batches}->{$batchname};
    $batch->{total_processes} = $self->total_processes;
    $batch->{total_batches}   = $self->total_batches;
    $batch->{batch_index}     = $batch_counter . "/" . $self->total_batches;

    ## This is wrong
    my $ptally_commands = $self->tally_commands;
    my $tally_count = $self->tally_commands + ( $batch->{commands} - 1 );
    $batch->{tally_commands}
        = $ptally_commands . "-"
        . $tally_count . "/"
        . $self->total_processes;

    $self->add_tally_commands( $batch->{commands} );

    my $json      = JSON->new->allow_nonref;
    my $json_text = $json->encode($batch);

    $batch->{meta_str} = $json_text;
    $DB::single = 2;
    $DB::single = 2;
    $json_text  = "--metastr \'$json_text\'";
    return $json_text;
}

=head3 collect_stats

Collect job stats

=cut

sub collect_stats {
    my $self          = shift;
    my $batch_counter = shift;
    my $cmd_counter   = shift;
    my $current_job   = shift;

    $batch_counter = sprintf( "%03d", $batch_counter );

    $self->add_total_processes($cmd_counter);

    my $command_count = ( $self->total_processes - $cmd_counter ) + 1;

    $self->set_batches(
        $batch_counter . "_"
            . $current_job => {
            commands => $cmd_counter,
            jobname  => $current_job,
            batch    => $batch_counter,
            }
    );

    my $jobhref = {};
    $jobhref->{$current_job} = [];

    if ( $self->exists_jobnames($current_job) ) {
        my $tarray = $self->jobnames->{$current_job};
        push( @{$tarray}, $batch_counter . "_" . $current_job );
    }
    else {
        $self->set_jobnames(
            $current_job => [ $batch_counter . "_" . $current_job ] );
    }

    $self->add_total_batches(1);
}

=head3 do_stats

Do some stats on our job stats
Foreach job name get the number of batches, and have a put that in batches->batch->job_batches

=cut

sub do_stats {
    my $self = shift;

    my @jobs = $self->keys_jobnames;

    foreach my $batch ( $self->keys_batches ) {
        my $href        = $self->batches->{$batch};
        my $jobname     = $href->{jobname};
        my @job_batches = @{ $self->jobnames->{$jobname} };

        my $index = firstidx { $_ eq $batch } @job_batches;
        $index += 1;

        my $lenjobs = $#job_batches + 1;
        $self->batches->{$batch}->{job_batches} = $index . "/" . $lenjobs;

        print "Job batches are "
            . $self->batches->{$batch}->{job_batches} . "\n";

        #$href->{total_processes} = $self->total_processes;
        #$href->{total_batches}   = $self->total_batches;

        #$href->{batch_count} = $href->{batch} . "/" . $self->total_batches;

        $self->batches->{total_processes} = $self->total_processes;
        $self->batches->{total_batches}   = $self->total_batches;

        $self->batches->{batch_count}
            = $href->{batch} . "/" . $self->total_batches;

    }
}

1;
