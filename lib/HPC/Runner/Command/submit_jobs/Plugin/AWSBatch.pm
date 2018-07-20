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
use Number::Bytes::Human qw(format_bytes parse_bytes);
use Memoize;

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

has 'hpcrunner_s3_logs' => (
    is            => 'rw',
    isa           => 'Str',
    lazy          => 1,
    documentation => 'HPCRunner will sync its job files to and from AWS.'
        . ' It stores the s3 bucket as the environmental variable.'
        . ' In the template file the command '
        . 'aws s3 sync $HPCRUNNER_S3_LOGS $HPCRUNNER_LOCAL_LOGS',
    default       => sub {
        my $self = shift;
        return 's3://' . $self->s3_hpcrunner;
    },
);

has 'hpcrunner_local_logs' => (
    is            => 'rw',
    isa           => 'Str',
    lazy          => 1,
    documentation => 'HPCRunner will sync its job files to and from AWS.'
        . ' It stores the s3 bucket as the environmental variable.'
        . ' In the template file the command '
        . 'aws s3 sync $HPCRUNNER_S3_LOGS $HPCRUNNER_LOCAL_LOGS',
    default       => '',
);

has 'hpcrunner_s3_job_file' => (
    is            => 'rw',
    lazy          => 1,
    documentation => 'Once the HPCRUNNER_S3_LOGS are synced to HPCRUNNER_LOCAL_LOGS, execute the job file',
    default       => sub {
        my $self = shift;
        return path($self->slurmfile)->relative;
    },
);

has 'submit_command' => (
    is      => 'rw',
    isa     => 'Str',
    default => 'aws batch submit-job --cli-input-json',
);

has 'registered_job_defs' => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub {return {}}
);

has 'registered_queue_defs' => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub {return {}}
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

=head3 job_def_object

TODO add in a job def!!

=cut

has 'job_def_object' => (
    is      => 'rw',
    lazy    => 1,
    isa     => 'HashRef',
    default => sub {
        my $self = shift;
        return {
            jobDefinitionName        => '',
            type                     => 'container',
            containerProperties      => {
                image   => $self->jobs->{$self->current_job}->container || $self->container,
                vcpus   => 1,
                memory  => 50,
                command => [
                    "echo", "hello", "world",
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
    lazy    => 1,
    default => sub {
        my $self = shift;
        return
            {
                "jobName"            => "",
                "jobQueue"           => "",
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
            "Submitted job " . $self->slurmfile . "\n\tWith AWS jobid $jobid");
    }

    return $jobid;
}

=head3 check_memory

AWS expects memory to be in megabytes
If memory is specified in human readable format, parse to megabytes
If only numbers are given don't touch

=cut

memoize('check_memory');
sub check_memory {
    my $memory = shift;
    if ($memory !~ m/[a-zA-Z]/) {
        return $memory;
    }
    my $size;
    try {
        my $bytes = parse_bytes($memory);
        my $human = Number::Bytes::Human->new(bs => $bytes, round_style => 'round');
        $size = $human->format(10240000);
        $size =~ s/M//g;
    }
    catch {
        ##Return the memory and let AWS catch the error
        return $memory;
    }
    return $size;
}


sub register_job_def {
    my $self = shift;

    return if $self->check_if_job_def_exists;

    my $job = $self->current_job;
    $self->job_def_object->{containerProperties}->{image} = $self->jobs->{$self->current_job}->container || $self->container;

    my $json = JSON->new->allow_nonref->allow_blessed->convert_blessed;
    my $json_string = $json->encode($self->job_def_object->{containerProperties});

    my $register_job_cmd = "aws batch register-job-definition --job-definition-name $job --type container --container-properties \'$json_string\'";
    $self->app_log->info($register_job_cmd);
    my ($exitcode, $stdout, $stderr) =
        $self->submit_to_scheduler($register_job_cmd);
    if ($exitcode == -1 || $exitcode == 0) {
        $self->app_log->info('Successfully registered job def ' . $job);
        $self->registered_job_defs->{$self->current_job} = 1;
    }
    else {
        $self->app_log->fatal("We were not able to register your job with AWS.");
        $self->app_log->fatal("Exit code $exitcode");
        $self->app_log->warn("STDERR: " . $stderr) if $stderr;
        $self->app_log->warn("STDOUT: " . $stdout) if $stdout;
    }
}

=head3 check_if_job_def_exists

Ensure the jobdef exists and has the correct container

TODO - This does not ensure whether or not the user can submit these jobs

=cut

sub check_if_job_def_exists {
    my $self = shift;
    my $get_job_if_exists = "aws batch describe-job-definitions --max-results 1000 --job-definition-name " . $self->current_job . " --status ACTIVE";
    my ($job_response, $job_definitions);
    my ($exitcode, $stdout, $stderr) =
        $self->submit_to_scheduler($get_job_if_exists);
    if ($exitcode == -1 || $exitcode == 0) {
        try {
            $job_response = decode_json $stdout;
        }
        catch {
            $self->app_log->fatal("Exit code $exitcode");
            $self->app_log->warn("STDERR: " . $stderr) if $stderr;
            $self->app_log->warn("STDOUT: " . $stdout) if $stdout;
        };
    }
    else {
        $self->app_log->fatal("Was not able to check for an existing job. Please ensure you have the correct AWS credentials, and try again.");
        $self->app_log->fatal("Exit code $exitcode");
        $self->app_log->warn("STDERR: " . $stderr) if $stderr;
        $self->app_log->warn("STDOUT: " . $stdout) if $stdout;
    }

    if (exists $job_response->{jobDefinitions}) {
        $job_definitions = $job_response->{jobDefinitions};
        return 0 unless scalar @{$job_definitions};
        foreach my $job_def (@{$job_definitions}) {
            if (exists $job_def->{image}) {
                if ($job_def->{image} eq $self->jobs->{$self->current_job}->container) {
                    $self->registered_job_defs->{$self->current_job} = 1;
                    return 1;
                }
            }
        }
    }
    $self->registered_job_defs->{$self->current_job} = 0;
    return 0;
}

=head3 before process_template

Before writing out the template write out the AWS cli configuration

=cut

before 'process_template' => sub {
    my $self = shift;
    my $counter = shift;
    my $command = shift;
    my $ok = shift;
    my $array_str = shift;

    if(! exists $self->registered_job_defs->{$self->current_job} ){
        $self->app_log->info("Checking to see if ".$self->current_job." exists");
        $self->register_job_def;
    }

    my $relative = $self->outdir->parent->relative;
    my $dirname = $self->outdir->relative->parent->basename;
    my $aws_sync = 'hpcrunner_fetch_and_run.sh s3://' . $self->s3_hpcrunner . '/' . $dirname . ' ' . path($self->slurmfile)->relative;

    $self->hpcrunner_s3_logs('s3://' . $self->s3_hpcrunner . '/' . $dirname);
    $self->hpcrunner_local_logs('hpc-runner/' . $dirname);
    $self->hpcrunner_s3_job_file(path($self->slurmfile)->relative);

    my @aws_sync = split(' ', $aws_sync);

    my $jobname = $self->resolve_project($counter);
    my $command_array = \@aws_sync;

    my $batch_indexes = $self->jobs->{$self->current_job}->batch_indexes->[$self->batch_counter - 1];
    my $batch_index_start = $batch_indexes->{batch_index_start};
    my $batch_index_end = $batch_indexes->{batch_index_end};
    my $array_size = $batch_index_end - $batch_index_start + 1;
    $self->app_log->info("ArraySize: ".$array_size);
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

    ##For references of array job def please see
    ## https://docs.aws.amazon.com/batch/latest/userguide/array_jobs.html
    ## Memory definition should be in MB, but I like human readable formats
    ## So convert it here
    my $mem = check_memory($self->jobs->{$self->current_job}->{mem});
    $self->submit_job_obj->{containerOverrides}->{command} = $command_array;
    $self->submit_job_obj->{containerOverrides}->{memory} = int($mem);
    $self->submit_job_obj->{containerOverrides}->{vcpus} = int($self->jobs->{$self->current_job}->{cpus_per_task});
    $self->submit_job_obj->{jobName} = $jobname;
    $self->submit_job_obj->{jobDefinition} = $self->current_job;
    $self->submit_job_obj->{jobQueue} = $self->jobs->{$self->current_job}->partition;
    $self->submit_job_obj->{arrayProperties}->{size} = int($array_size);

    ## TODO Add Deps in here, batching algorithm needs to be reworked
    #If batch_tags are equal they can be N_N deps
    $self->check_for_N_N;

    ## TODO Write check to ensure that the environmental keys exist
    ##  TODO Or that they can be read in from the ~/.aws.config files
    #    my $relative = $self->outdir->parent->relative;
    #    my $dirname = $self->outdir->relative->parent->basename;
    #    my $aws_sync = 'hpcrunner_fetch_and_run.sh s3://' . $self->s3_hpcrunner . '/' . $dirname . ' ' . path($self->slurmfile)->relative;
    my $keys_list = [
        {
            name  => 'HPCRUNNER_S3_LOGS',
            value => $self->hpcrunner_s3_logs,
        },
        {
            name  => 'HPCRUNNER_LOCAL_LOGS',
            value => $self->hpcrunner_local_logs,
        },
        {
            name  => 'HPCRUNNER_JOB_FILE',
            value => path($self->slurmfile)->relative,
        },
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

=head3 check_for_N_N

WIP - Check if array job has N_N task dependencies

=cut
sub check_for_N_N {
    my $self = shift;

    if ($self->has_scheduler_ids) {
        $self->submit_job_obj->{dependsOn} = [];
        foreach my $id (@{$self->scheduler_ids}) {
            push(@{$self->submit_job_obj->{dependsOn}}, { 'jobId' => $id });
        }
    }
}

=head3 process_submit_command

=cut

sub process_submit_command {
    my $self = shift;
    my $counter = shift;

    my $command = "";

    ##TODO Discuss changing the log name to just the jobname
    my $logname = $self->create_log_name($counter);
    $self->jobs->{ $self->current_job }->add_lognames($logname);

    #    $command = "sleep 20\n";
    if ($self->has_custom_command) {
        $command .= $self->custom_command . " \\\n";
    }
    else {
        $command .= "hpcrunner.pl " . $self->subcommand . " \\\n";
    }

    $command .= "\t--project " . $self->project . " \\\n" if $self->has_project;

    my $batch_indexes = $self->jobs->{$self->current_job}->batch_indexes->[$self->batch_counter - 1];
    my $batch_index_start = $batch_indexes->{batch_index_start};

    my $log = "";
    if ($self->no_log_json) {
        $log = "\t--no_log_json \\\n";
    }

    ## Batch_index_start is a change from other schedulers
    ## With SLURM and co
    ## job001 tasks=1-10 would be array elements 1-10
    ## If it was submitted into two batches
    ## job001 tasks=1-5 would have array elements 1-5
    ## job001 tasks=6-10 would have array elements 6-10
    ## With AWS each batch starts as 0
    $command .=
        "\t--infile "
            . path($self->cmdfile)->relative . " \\\n"
            . "\t--basedir "
            . path($self->basedir)->relative . " \\\n"
            . "\t--commands "
            . $self->jobs->{ $self->current_job }->commands_per_node . " \\\n"
            . "\t--batch_index_start "
            . $batch_index_start . " \\\n"
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
    $command .= "aws s3 sync \$HPCRUNNER_LOCAL_LOGS \$HPCRUNNER_S3_LOGS\n\n";
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

before 'execute' => sub {
    my $self = shift;
    push(@{$self->job_plugins}, 'AWSBatch');
};

1;
