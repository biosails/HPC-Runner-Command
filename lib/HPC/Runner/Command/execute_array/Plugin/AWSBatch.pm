use strict;
use warnings;
package HPC::Runner::Command::execute_array::Plugin::AWSBatch;

use Moose::Role;
use namespace::autoclean;

=head3 parse_file_mce

This is for AWS Batch
For AWS Batch each array starts at 0
The other schedulers start at their actual task index

=cut

before 'parse_file_mce' => sub {
    my $self = shift;
    if ($self->can('task_id') && $self->can('batch_index_start') && defined $ENV{'AWS_BATCH_JOB_ARRAY_INDEX'}) {
        # Damn read commands are 0 indexed WHY DO I DO THIS TO MYSELF
        my $read_command = $self->task_id + $self->batch_index_start - 1;
        $self->read_command($read_command);
    }
    else {
        print 'You are using the AWSBatch job execution plugin,'
            . ' but you have not defined either batch_index_start'
            . ' or the environmental variable AWS_BATCH_JOB_ARRAY_INDEX';
        print "\n";
        exit 1;
    }
};

1;
