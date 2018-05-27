use strict;
use warnings;
package HPC::Runner::Command::submit_jobs::Plugin::AWSBatch;

use Moose::Role;
use namespace::autoclean;

use Data::Dumper;
use IPC::Cmd qw[can_run];
use Cwd;
use Log::Log4perl;
use File::Temp qw/tempfile/;
use JSON;
use File::Slurp;
use Try::Tiny;
use Path::Tiny;

with 'HPC::Runner::Command::submit_jobs::Utils::Scheduler::UseArrays';
with 'HPC::Runner::Command::submit_jobs::Plugin::Role::Log';

=head1 HPC::Runner::Command::submit_jobs::Plugin::AWSBatch

AWS Batch is a little different from the other job schedulers

1. Create compute environment - so far this must be done in the AWS console, since it has to do with billing
2. Create a job queue - this is jobname_cpus_X_mem_Y
3. Create a job definition - this is simply the hpcrunner execute_job command with the appropriate flags
4. Submit the job


From the AWS CLI Docs - https://docs.aws.amazon.com/cli/latest/reference/batch/index.html

Create the job queue definition file

    {
      "jobQueueName": "LowPriority",
      "state": "ENABLED",
      "priority": 10,
      "computeEnvironmentOrder": [
        {
          "order": 1,
          "computeEnvironment": "MY_COMPUTE_ENVIRONMENT"
        }
      ]
    }

Submit it using the CLI

    aws batch create-job-queue --cli-input-json file://<path_to_json_file>/LowPriority.json

Register a job definition

    aws batch register-job-definition \
        --job-definition-name sleep30 --type container \
        --container-properties '{ "image": "busybox", "vcpus": 1, "memory": 128, "command": [ "sleep", "30"]}'

Submit a job using the job definition

    aws batch submit-job --job-name example --job-queue HighPriority  --job-definition sleep30

To create a job with parameters (like for hpcrunner)

    "command": [ "ffmpeg", "-i", "Ref::inputfile", "-c", "Ref::codec", "-o", "Ref::outputfile" ]

Then in the job submission submit as:

    "parameters" : {"codec" : "mp4"}

=cut

=head3 s3_hpcrunner
HPCRunner needs an s3 bucket to upload its data files to
=cut

has 's3_hpcrunner' => (
    is      => 'rw',
    isa     => 'Str',
    default => 'hpcrunner-bucket'
);

has 'submit_command' => (
    is      => 'rw',
    isa     => 'Str',
    default => 'aws batch submit-job --cli-input-json',
);

has 'template_file' => (
    is            => 'rw',
    isa           => 'Str',
    lazy          => 1,
    default       => sub {
        my $self = shift;

        my ($fh, $filename) = tempfile();

        my $tt = <<EOF;
#!/usr/bin/env bash

set -x -e

echo "HELLO FROM HPCRUNNER"

[% IF MODULES %]
module load [% MODULES %]
[% END %]

[% IF job.has_conda_env %]
source activate [% job.conda_env %]
[% END %]

[% COMMAND %]

EOF

        print $fh $tt;
        return $filename;
    },
    predicate     => 'has_template_file',
    clearer       => 'clear_template_file',
    documentation =>
        q{Path to Scheduler template file if you do not wish to use the default.}
);

=head3 compute_env
AWS requires a configured compute_env. This can be setup through the command line or console, but since it has to do with billing it is not set by default
=cut

has 'compute_env' => (
    is => 'rw',
);

=head3 container
Docker container to run commands against
For simple unix commands just use the busybox container
For anything more complex use BioStacks or user supplied definition
=cut

has 'container' => (
    is      => 'rw',
    isa     => 'Str',
    default => 'biocontainers/perl-hpc-runner-command'
);

=head3 mounts
Mounts between the host filesystem and the docker container
Default is just to mount the whole cwd
=cut
has 'mounts' => (
    is  => 'rw',
    isa => 'ArrayRef'
);

=head3 job_def_object

TODO add in a job def!!

=cut

has 'job_def_object' => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub {
        return {
            jobDefinitionName        => '',
            type                     => 'container',
            parameters               => {
                infile            => '',
                basedir           => '',
                data_dir          => '',
                process_table     => '',
                logname           => '',
                commands          => 1,
                batch_index_start => '',
                procs             => 1,
                metastr           => '',
            },
            containerProperties      => {
                image   => 'biocontainers/perl-hpc-runner-command',
                vcpus   => 1,
                memory  => 0,
                command => [
                    'hpcrunner.pl', 'execute_job',
                    '--infile', 'Ref::infile',
                    '--basedir', 'Ref::basedir',
                    '--data_dir', 'Ref::data_dir',
                    '--process_table', 'Ref::process_table',
                    '--logname', 'Ref::logname',
                    '--commands', 'Ref::commands',
                    '--batch_index_start', 'Ref::batch_index_start',
                    '--procs', 'Ref::procs',
                    '--metastr', 'Ref::metastr',
                    '--project', 'Ref::project'
                ]
            },
            mountPoints              => {
                containerPath => '/',
                readOnly      => 'false',
                sourceVolume  => '/'
            },
            "readonlyRootFilesystem" => 'false',
        }
    }
);

has 'submit_job_obj' => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub {
        return
            {
                "jobName"            => "",
                "jobQueue"           => "LowPriority",
                "jobDefinition"      => "",
                "parameters"         => {
                },
                "containerOverrides" => {
                    "vcpus"   => 1,
                    "memory"  => 128,
                    "command" => [
                        ""
                    ],
                },
            }
    }
);

has 'aws_access_key_id' => (
    is       => 'rw',
    required => 1,
    default  => sub {
        return $ENV{'AWS_ACCESS_KEY_ID'}
    }
);

has 'aws_secret_access_key' => (
    is       => 'rw',
    required => 1,
    default  => sub {
        return $ENV{'AWS_SECRET_ACCESS_KEY'}
    }
);

sub submit_jobs {
    my $self = shift;

    my $relative = $self->outdir->parent->relative;
    my $dirname = $self->outdir->relative->parent->basename;

    my $file = $self->slurmfile;
    $file =~ s/\.sh$/\.json/;

    my ($exitcode, $stdout, $stderr) =
        $self->submit_to_scheduler(
            'aws s3 sync  ' . $relative . ' s3://' . $self->s3_hpcrunner . '/' . $dirname);

    $self->app_log->info('Uploading files...');
    $self->app_log->info($relative);
    $self->app_log->info($dirname);
    $self->app_log->info($stdout) if $stdout;
    $self->app_log->info($stderr) if $stderr;

    $self->app_log->fatal('Submitting with command:');
    $self->app_log->fatal($self->submit_command . " file://" . $file);
    ($exitcode, $stdout, $stderr) =
        $self->submit_to_scheduler(
            $self->submit_command . " file://" . $file);
    sleep(5);

    my $job_response;
    my $jobid;
    if ($exitcode == -1 || $exitcode == 0) {
        try {
            $job_response = decode_json $stdout;
            $jobid = $job_response->{jobId};
        }
        catch {
            $self->app_log->fatal("Exit code $exitcode");
            $self->app_log->warn("STDERR: " . $stderr) if $stderr;
            $self->app_log->warn("STDOUT: " . $stdout) if $stdout;
        };
    }
    else {
        $self->app_log->fatal("Job was not submitted successfully");
        $self->app_log->fatal("Exit code $exitcode");
        $self->app_log->warn("STDERR: " . $stderr) if $stderr;
        $self->app_log->warn("STDOUT: " . $stdout) if $stdout;
    }

    #When submitting job arrays the array will be 1234[].hpc.nyu.edu

    if (!$jobid) {
        $self->job_failure;
    }
    else {
        $self->app_log->debug(
            "Submited job " . $self->slurmfile . "\n\tWith AWS jobid $jobid");
    }

    return $jobid;
}

=head3 before process_template

Before writing out the template write out the AWS cli configuration

=cut

before 'process_template' => sub {
    my $self = shift;
    my $counter = shift;

    my $relative = $self->outdir->parent->relative;
    my $dirname = $self->outdir->relative->parent->basename;
    ##TODO Put this into hpcrunner
    my $aws_sync = 'fetch_and_run.sh s3://' . $self->s3_hpcrunner . '/' . $dirname . ' ' . path($self->slurmfile)->relative;
    my @aws_sync = split(' ', $aws_sync);
    use Data::Dumper;
    print Dumper \@aws_sync;

    my $jobname = $self->resolve_project($counter);
    my $command_array = \@aws_sync;

    my $array_size = $self->current_batch->{cmd_count};
    $array_size = int($array_size);
    ##This is a hack, because AWS will only allow for arrays to be >=2
    try {
        #I don't know why this gets stored as a string
        if (int($array_size) == 1) {
            $array_size = 2;
        }
        if ($array_size eq '1') {
            $array_size = 2;
        }
    }
    catch {
        if ($array_size eq '1') {
            $array_size = 2;
        }
    };

    $self->update_job_scheduler_deps_by_task;

    $self->submit_job_obj->{containerOverrides}->{command} = $command_array;
    $self->submit_job_obj->{containerOverrides}->{memory} = int($self->jobs->{$self->current_job}->{mem});
    $self->submit_job_obj->{containerOverrides}->{vcpus} = int($self->jobs->{$self->current_job}->{cpus_per_task});
    $self->submit_job_obj->{jobName} = $jobname;
    $self->submit_job_obj->{jobDefinition} = 'sleep30';
    $self->submit_job_obj->{arrayProperties}->{size} = int($array_size);
    #TODO Add Deps in here
    #If batch_tags are equal they can be N_N deps

    #TODO Write check to ensure that the environmental keys exist
    #TODO Or that they can be read in from the ~/.aws.config files
    my $keys_list = [
        {
            name  => 'AWS_ACCESS_KEY_ID',
            value => $self->aws_access_key_id,
        },
        {
            name  => 'AWS_SECRET_ACCESS_KEY',
            value => $self->aws_secret_access_key,
        }
    ];
    if (exists $self->submit_job_obj->{containerOverrides}->{environment}) {
        foreach my $env_key (@{$keys_list}) {
            push(@{$self->submit_job_obj->{containerOverrides}->{environment}}, $env_key);
        }
    }
    else {
        $self->submit_job_obj->{containerOverrides}->{environment} = $keys_list;
    }

    my $json = JSON->new->allow_nonref->allow_blessed->convert_blessed;
    my $json_string = $json->pretty->encode($self->submit_job_obj);

    my $file = $self->slurmfile;
    $file =~ s/\.sh$/\.json/;
    $self->log->info('Writing aws cli');
    $self->log->info($file);
    write_file($file, $json_string);
};

=head3 process_submit_command

=cut

sub process_submit_command {
    my $self = shift;
    my $counter = shift;

    my $command = "";

    ##TODO Discuss changing the log name to just the jobname
    my $logname = $self->create_log_name($counter);
    $self->jobs->{ $self->current_job }->add_lognames($logname);

    $command = "sleep 20\n";
    if ($self->has_custom_command) {
        $command .= $self->custom_command . " \\\n";
    }
    else {
        $command .= "hpcrunner.pl " . $self->subcommand . " \\\n";
    }

    $command .= "\t--project " . $self->project . " \\\n" if $self->has_project;

    my $batch_index_start = $self->gen_batch_index_str;

    my $log = "";
    if ($self->no_log_json) {
        $log = "\t--no_log_json \\\n";
    }

    $command .=
        "\t--infile "
            . path($self->cmdfile)->relative . " \\\n"
            . "\t--basedir "
            . path($self->basedir)->relative . " \\\n"
            . "\t--commands "
            . $self->jobs->{ $self->current_job }->commands_per_node . " \\\n"
            . "\t--batch_index_start "
            . $self->gen_batch_index_str . " \\\n"
            . "\t--procs "
            . $self->jobs->{ $self->current_job }->procs . " \\\n"
            . "\t--logname "
            . $logname . " \\\n"
            . $log
            . "\t--data_dir "
            . path($self->data_dir)->relative . " \\\n"
            . "\t--process_table "
            . path($self->process_table)->relative;

    #TODO Update metastring to give array index
    my $metastr =
        $self->job_stats->create_meta_str($counter, $self->batch_counter,
            $self->current_job, $self->use_batches,
            $self->jobs->{ $self->current_job });

    $command .= " \\\n\t" if $metastr;
    $command .= $metastr if $metastr;

    my $pluginstr = $self->create_plugin_str;
    $command .= $pluginstr if $pluginstr;

    my $version_str = $self->create_version_str;
    $command .= $version_str if $version_str;
    $command .= "\n\n";
    return $command;
}

=head3 process_template

=cut

sub process_template {
    my $self = shift;
    my $counter = shift;
    my $command = shift;
    my $ok = shift;
    my $array_str = shift;

    my $jobname = $self->resolve_project($counter);

    $self->template->process(
        $self->jobs->{$self->current_job}->template_file,
        {
            JOBNAME   => $jobname,
            USER      => $self->user,
            COMMAND   => $command,
            ARRAY_STR => $array_str,
            AFTEROK   => $ok,
            MODULES   => $self->jobs->{ $self->current_job }->join_modules(' '),
            OUT       => $self->logdir
                . "/$counter" . "_"
                . $self->current_job . ".log",
            job       => $self->jobs->{ $self->current_job },
        },
        $self->slurmfile
    ) || die $self->template->error;

    chmod 0777, $self->slurmfile;

    my $scheduler_id;
    try {
        $scheduler_id = $self->submit_jobs;
    };

    if (defined $scheduler_id) {
        $self->jobs->{ $self->current_job }->add_scheduler_ids($scheduler_id);
    }
    else {
        $self->jobs->{ $self->current_job }->add_scheduler_ids('000xxx');
    }
}

=head3 update_job_deps

This is not used here - instead the deps are calculated per dep
For AWS array size has to be at least 2

=cut

sub update_job_deps {
    my $self = shift;
    return;
}

sub update_job_scheduler_deps_by_task {
    my $self = shift;

    $self->app_log->info(
        'Calculating task dependencies for AWS. This may take some time.');

    $self->jobs->{ $self->current_job }->add_scheduler_ids('NOT_SUBMITTED_YET');
    $self->batch_scheduler_ids_by_task;
    pop @{$self->jobs->{$self->current_job}->scheduler_ids};

    print Dumper($self->array_deps);
    $self->update_job_deps;
}

before 'execute' => sub {
    my $self = shift;
#    $self->use_batches(1);
    $self->max_array_size(1000);
};

1;
