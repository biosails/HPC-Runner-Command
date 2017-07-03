package HPC::Runner::Command::stats::Logger::JSON::JSONOutput;

use Moose::Role;
use namespace::autoclean;
use JSON;

has 'json_data' => (
    is      => 'rw',
    isa     => 'ArrayRef',
    default => sub { return [] }
);

1;
