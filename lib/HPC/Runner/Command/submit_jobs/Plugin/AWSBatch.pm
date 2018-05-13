use strict;
use warnings;
package HPC::Runner::Command::submit_jobs::Plugin::AWSBatch;

use Moose::Role;
use namespace::autoclean;

use Data::Dumper;
use IPC::Cmd qw[can_run];
use Log::Log4perl;
use File::Temp qw/tempfile/;

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

has 'array_size' => (
    is      => 'rw',
    default => 1,
);

=head3 s3_hpcrunner
HPCRunner needs an s3 bucket to upload its data files to
=cut
has 's3_hpcrunner' => (
    is      => 'rw',
    isa     => 'Str',
    default => 'hpcrunner-bucket'
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
    default => 'busybox'
);

=head3 mounts
Mounts between the host filesystem and the docker container
Default is just to mount the whole cwd
=cut
has 'mounts' => (
    is  => 'rw',
    isa => 'ArrayRef'
);

=head2 hpcrunner_job_def

hpcrunner.pl execute_job has the following parameters;

infile
basedir
commands
batch_index_start
procs
logname
data_dir
process_table
metastr

    cd /home/jillian/Dropbox/projects/HPC-Runner-Libs/New/test
    hpcrunner.pl execute_job \
            --infile /home/jillian/Dropbox/projects/HPC-Runner-Libs/New/test/hpc-runner/2017-11-29T13-21-26/scratch/000_job001.in \
            --basedir /home/jillian/Dropbox/projects/HPC-Runner-Libs/New/test/hpc-runner/2017-11-29T13-21-26 \
            --commands 1 \
            --batch_index_start 1 \
            --procs 1 \
            --logname 001_job001 \
            --data_dir /home/jillian/Dropbox/projects/HPC-Runner-Libs/New/test/hpc-runner/2017-11-29T13-21-26/logs/000_hpcrunner_logs/stats \
            --process_table /home/jillian/Dropbox/projects/HPC-Runner-Libs/New/test/hpc-runner/2017-11-29T13-21-26/logs/000_hpcrunner_logs/001-task_table.md \
            --metastr '{"job_cmd_start":"0","jobname":"job001","total_batches":9,"task_index_end":4,"total_jobs":3,"job_counter":"001","batch":"001","commands":1,"task_index_start":"0","array_end":"5","job_tasks":"5","array_start":"1","total_processes":16}'
=cut

has 'hpcrunner_job_def' => (
    is => 'rw',
);

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
                image   => 'busybox',
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
                containerPath => '`pwd`',
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
                "jobQueue"           => "",
                "arrayProperties"    => {
                    "size" => 0
                },
                "dependsOn"          => [
                    {
                        "jobId" => "",
                        "type"  => "N_TO_N"
                    }
                ],
                "jobDefinition"      => "",
                "parameters"         => {
                    "KeyName" => ""
                },
                "containerOverrides" => {
                    "vcpus"   => 0,
                    "memory"  => 0,
                    "command" => [
                        ""
                    ],
                },
                "retryStrategy"      => {
                    "attempts" => 0
                },
                "timeout"            => {
                    "attemptDurationSeconds" => 0
                }
            }
    }
);

sub submit_jobs {
    my $self = shift;

    my ($exitcode, $stdout, $stderr) =
        $self->submit_to_scheduler(
            $self->submit_command . " " . $self->slurmfile);
    sleep(5);

    if ($exitcode != 0) {
        $self->log->fatal("Job was not submitted successfully");
        $self->log->warn("STDERR: " . $stderr) if $stderr;
        $self->log->warn("STDOUT: " . $stdout) if $stdout;
    }

    my $jobid = $stdout;

    #When submitting job arrays the array will be 1234[].hpc.nyu.edu

    if (!$jobid) {
        $self->job_failure;
    }
    else {
        $self->log->debug(
            "Submited job " . $self->slurmfile . "\n\tWith PBS jobid $jobid");
    }

    return $jobid;
}

=head3 process_submit_command

Overrides the process_subbmit_command from the
HPC::Runner::Command::submit_jobs::Utils::Scheduler::Submit package

=cut

sub process_submit_command {
    my $self = shift;
    my $counter = shift;

    my $command = "";
    my $command_array = [];

    my $logname = $self->create_log_name($counter);
    $self->jobs->{ $self->current_job }->add_lognames($logname);

    $command .= "hpcrunner.pl " . $self->subcommand . " \\\n";
    $command_array = [ "hpcrunner.pl", $self->subcommand ];

    $command .= "\t--project " . $self->project . " \\\n" if $self->has_project;
    push(@{$command_array}, '--project') if $self->has_project;
    push(@{$command_array}, $self->project) if $self->has_project;

    my $log = "";
    if ($self->no_log_json) {
        $log = "\t--no_log_json \\\n";
        push(@{$command_array}, '--no_log_json');
    }

    $command .=
        "\t--infile "
            . $self->cmdfile . " \\\n"
            . "\t--basedir "
            . $self->basedir . " \\\n"
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
            . $self->data_dir . " \\\n"
            . "\t--process_table "
            . $self->process_table;
    push(@{$command_array},
        ('--infile', $self->cmdfile,
            '--basedir', $self->basedir,
            '--commands', $self->jobs->{$self->current_job}->commands_per_node,
            '--batch_index_start', $self->gen_batch_index_str,
            '--procs', $self->jobs->{$self->current_job}->procs,
            '--logname', $logname,
            '--data_dir', $self->data_dir,
            '--process_table', $self->process_table,
        ));

    #TODO Update metastring to give array index
    my $metastr =
        $self->job_stats->create_meta_str($counter, $self->batch_counter,
            $self->current_job, $self->use_batches,
            $self->jobs->{ $self->current_job });

    $command .= " \\\n\t" if $metastr;
    $command .= $metastr if $metastr;
    push(@{$command_array}, $metastr) if $metastr;

    ##TODO Add in plugin str
    my $pluginstr = $self->create_plugin_str;
    $command .= $pluginstr if $pluginstr;
    push(@{$command_array}, $pluginstr) if $pluginstr;

    my $version_str = $self->create_version_str;
    $command .= $version_str if $version_str;
    push(@{$command_array}, $version_str) if $version_str;

    $self->submit_job_obj->{containerOverrides}->{commands} = $command_array;
    $command .= "\n\n";
    return $command;
}

=head3 update_job_deps

For AWS we submit the array_size as 1 (for now), so this is not needed

=cut

sub update_job_deps {
    my $self = shift;
    return;
}


1;
