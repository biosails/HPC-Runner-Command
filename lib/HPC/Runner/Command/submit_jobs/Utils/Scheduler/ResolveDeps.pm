package HPC::Runner::Command::submit_jobs::Utils::Scheduler::ResolveDeps;
use 5.010;

use Moose::Role;
use List::MoreUtils qw(natatime);
use Storable qw(dclone);
use Data::Dumper;
use Algorithm::Dependency::Source::HoA;
use Algorithm::Dependency::Ordered;
use HPC::Runner::Command::submit_jobs::Utils::Scheduler::Batch;
use POSIX;
use String::Approx qw(amatch);
use Text::ANSITable;
use Text::ASCIITable;

=head1 HPC::Runner::Command::submit_jobs::Utils::Scheduler::ResolveDeps;

Once we have parsed the input file parse each job_type for job_batches

=head2 Attributes

=cut

=head3 schedule

Schedule our jobs

=cut

has 'schedule' => (
    traits  => ['Array'],
    is      => 'rw',
    isa     => 'ArrayRef',
    default => sub { [] },
    handles => {
        all_schedules    => 'elements',
        add_schedule     => 'push',
        has_schedules    => 'count',
        clear_schedule   => 'clear',
        has_no_schedules => 'is_empty',
    },
);

=head2 Subroutines

=cut

#Just putting this here
#scontrol update job=9314_2 Dependency=afterok:9320_1

=head3 schedule_jobs

Use Algorithm::Dependency to schedule the jobs

=cut

sub schedule_jobs {
    my $self = shift;

    my $source =
      Algorithm::Dependency::Source::HoA->new( $self->graph_job_deps );

    my $dep = Algorithm::Dependency::Ordered->new(
        source   => $source,
        selected => []
    );

    $self->schedule( $dep->schedule_all );

}

=head3 sanity_check_schedule

Run a sanity check on the schedule. All the job deps should have existing job names

=cut

sub sanity_check_schedule {
    my $self = shift;

    $DB::single = 2;

    my @jobnames = keys %{ $self->graph_job_deps };
    @jobnames = sort(@jobnames);
    my $search   = 1;
    my $t = Text::ASCIITable->new();

    my $x = 0;

    my @rows = ();

    #Search the dependencies for matching jobs
    foreach my $job (@jobnames)   {
        my $row = [];
        my $ref = $self->graph_job_deps->{$job};
        push(@$row, $job);

        my $y = 0;
        foreach my $r (@$ref) {

            if ( !exists $self->graph_job_deps->{$r} ) {
                $ref->[$y] = "**$r**";
                my $depstring = join(", ", @{$ref});
                push(@$row, $depstring);

                $self->app_log->fatal("Job dep $r is not in joblist.");
                $search = 0;

                my @matches = amatch( $r, @jobnames );
                if (@matches) {
                    push(@$row, join(", ", @matches));
                    $self->app_log->warn( "Did you mean ( "
                          . join( ", ", @matches )
                          . "  ) instead of $r?" );
                }
                else {
                    $self->app_log->fatal(
                        "No potential matches were found for dependency $r");
                }
            }
            else{
                my $depstring = join(", ", @{$ref});
                push(@$row, $depstring);
            }

            $y++;
        }
        push(@rows, $row);
        $x++;
    }

    #Format the table
    if ( !$search ) {
      $t->setCols(["JobName", "Deps", "Suggested"]);
      map { $t->addRow($_) } @rows;
      $self->app_log->fatal(
      'There were one or more problems with your job schedule.');
      $self->app_log->warn("Here is your tabular schedule (this is not necessary the submission order)");
    }
    else{
      $t->setCols(["JobName", "Deps"]);
      map { $t->addRow($_) } @rows;
      $self->app_log->info("Here is your tabular schedule");
    }

    say $t;

    return $search;
}

=head3 chunk_commands

Chunk commands per job into batches

=cut

sub chunk_commands {
      my $self = shift;

      $DB::single = 2;
      $self->reset_cmd_counter;
      $self->reset_batch_counter;

      return if $self->has_no_schedules;

      $self->clear_scheduler_ids();

      foreach my $job ( $self->all_schedules ) {

          $self->current_job($job);

          next unless $self->jobs->{ $self->current_job };

          $self->reset_cmd_counter;

          my $commands_per_node =
            $self->jobs->{ $self->current_job }->commands_per_node;

          my @cmds = @{ $self->jobs->{ $self->current_job }->cmds };

          $self->jobs->{ $self->current_job }->{batch_index_start} =
            $self->batch_counter;

          if ( !$self->jobs->{ $self->current_job }->can('count_cmds') ) {
              warn
"You seem to be mixing and matching job dependency declaration types! Here there be dragons! We are dying now.\n";
              exit 1;
          }
          next unless $self->jobs->{ $self->current_job }->count_cmds;

          my $iter = natatime $commands_per_node, @cmds;

          $self->assign_batches($iter);
          $self->assign_batch_stats;

          $self->jobs->{ $self->current_job }->{batch_index_end} =
            $self->batch_counter - 1;
          $self->inc_job_counter;

          my $batch_index_start =
            $self->jobs->{ $self->current_job }->{batch_index_start};
          my $batch_index_end =
               $self->jobs->{ $self->current_job }->{batch_index_end}
            || $self->jobs->{ $self->current_job }->{batch_index_start};

          $DB::single = 2;

          if ( !$self->use_batches ) {

              my $number_of_batches =
                $self->resolve_max_array_size( $commands_per_node,
                  scalar @cmds );

              $self->jobs->{ $self->current_job }->{num_job_arrays} =
                $number_of_batches;

              $self->return_ranges( $batch_index_start, $batch_index_end,
                  $number_of_batches );

              #print "Resolving max array\n"
              #. Dumper( $self->jobs->{ $self->current_job } );
          }
          else {
              $DB::single = 2;
              $self->jobs->{ $self->current_job }->{batch_indexes} = [
                  {
                      batch_index_start => $batch_index_start,
                      batch_index_end   => $batch_index_end
                  }
              ];
          }

      }

      $self->reset_job_counter;
      $self->reset_cmd_counter;
      $self->reset_batch_counter;
}

=head3 resolve_max_array_size

Arrays should not be greater than the max_array_size variable

If it is they need to be chunked up into various arrays

=cut

sub resolve_max_array_size {
      my $self              = shift;
      my $number_of_batches = shift;
      my $cmd_size          = shift;

      #TODO There must be a better way of doing this
      if ( ( $cmd_size / $number_of_batches ) <= ( $self->max_array_size + 1 ) )
      {
          return $number_of_batches;
      }

      $number_of_batches = $cmd_size / ( $self->max_array_size + 1 );

      return POSIX::ceil($number_of_batches);
}

sub return_ranges {
      my $self        = shift;
      my $batch_start = shift;
      my $batch_end   = shift;

      #walk is the ret value from resolve_max_array_size
      my $walk = shift;

      my $new_array;
      if ( $walk == 1 ) {
          $new_array = {
              'batch_index_start' => $batch_start,
              'batch_index_end'   => $batch_end
          };
          $self->jobs->{ $self->current_job }->add_batch_indexes($new_array);
          return;
      }

      my $x = $batch_start;

      my $array_ref = [];
      while ( $x <= $batch_end ) {
          my $t_batch_end = $x + $self->max_array_size - 1;
          if ( $t_batch_end < $batch_end ) {
              $new_array = {
                  'batch_index_start' => $x,
                  'batch_index_end'   => $t_batch_end,
              };
          }
          else {
              $new_array = {
                  'batch_index_start' => $x,
                  'batch_index_end'   => $batch_end,
              };
          }
          $x += $self->max_array_size;
          $self->jobs->{ $self->current_job }->add_batch_indexes($new_array);
      }

      return;
}

=head3 assign_batch_stats

Iterate through the batches to assign stats (number of batches per job, number of tasks per command, etc)

=cut

sub assign_batch_stats {
      my $self = shift;

      foreach my $batch ( @{ $self->jobs->{ $self->current_job }->batches } ) {

          $self->current_batch($batch);
          $self->inc_cmd_counter( $batch->{cmd_count} );

          $self->job_stats->collect_stats( $self->batch_counter,
              $self->cmd_counter, $self->current_job );

          $self->inc_batch_counter;
          $self->reset_cmd_counter;
      }
}

=head3 assign_batches

Each jobtype has one or more batches
iterate over the the batches to get some data and assign s

=cut

sub assign_batches {
      my $self = shift;
      my $iter = shift;

      my $x = 0;
      while ( my @vals = $iter->() ) {

          my $batch_cmds = dclone( \@vals );
          my ( $batch_tags, $batch_deps ) =
            $self->assign_batch_tags($batch_cmds);

          #TODO a batch should be its own class!
          my $batch_ref =
            HPC::Runner::Command::submit_jobs::Utils::Scheduler::Batch->new(
              cmds       => $batch_cmds,
              batch_tags => $batch_tags,
              batch_deps => $batch_deps,
              job        => $self->current_job,
            );

          $self->jobs->{ $self->current_job }->add_batches($batch_ref);
          $self->jobs->{ $self->current_job }->submit_by_tags(1)
            if @{$batch_tags};

          $self->process_batch_deps($batch_ref);

          $x++;
      }

      $self->jobs->{ $self->current_job }->{batch_count} = $x;

}

=head3 assign_batch_tags

Parse the #TASK lines to get batch_tags

=cut

sub assign_batch_tags {
      my $self       = shift;
      my $batch_cmds = shift;

      my @batch_tags = ();
      my @batch_deps = ();

      foreach my $lines ( @{$batch_cmds} ) {

          my @lines = split( "\n", $lines );

          foreach my $line (@lines) {

              chomp($line);

              #TODO Change this to TASK
              next unless $line =~ m/^#TASK/;

              #TODO task_tags and task_deps
              my ( $t1, $t2 ) = $self->parse_meta($line);

              next unless $t2;
              my @tags = split( ",", $t2 );

              if ( $t1 eq 'tags' ) {
                  foreach my $tag (@tags) {
                      next unless $tag;
                      push( @batch_tags, $tag );
                  }
              }
              elsif ( $t1 eq 'deps' ) {
                  foreach my $dep (@tags) {
                      next unless $dep;
                      push( @batch_deps, $dep );
                  }
              }

          }
      }

      return \@batch_tags, \@batch_deps;
}

=head3 process_batch_deps

If a job has one or more job tags it may be possible to fine tune dependencies

#HPC jobname=job01
#HPC commands_per_node=1
#TASK tags=Sample1
gzip Sample1
#TASK tags=Sample2
gzip Sample2

#HPC jobname=job02
#HPC jobdeps=job01
#HPC commands_per_node=1
#TASK tags=Sample1
fastqc Sample1
#TASK tags=Sample2
fastqc Sample2

job01 - Sample1 would be submitted as schedulerid 1234
job01 - Sample2 would be submitted as schedulerid 1235

job02 - Sample1 would be submitted as schedulerid 1236 - with dep on 1234 (with no job tags this would be 1234, 1235)
job02 - Sample2 would be submitted as schedulerid 1237 - with dep on 1235 (with no job tags this would be 1234, 1235)

=cut

sub process_batch_deps {
      my $self  = shift;
      my $batch = shift;

      my $tags;

      return unless $self->jobs->{ $self->current_job }->submit_by_tags;
      return unless $self->jobs->{ $self->current_job }->has_deps;

      if ( $batch->has_batch_deps ) {
          $tags = $batch->batch_deps;
      }
      else {
          $tags = $batch->batch_tags;
      }

      my $scheduler_index =
        $self->search_batches( $self->jobs->{ $self->current_job }->deps,
          $tags );

      $batch->scheduler_index($scheduler_index);
}

=head3 search_batches

search the batches for a particular scheduler id
#TODO Will have to add functionality for arrays

=cut

sub search_batches {
      my $self     = shift;
      my $job_deps = shift;
      my $tags     = shift;

      my $scheduler_ref = {};

      foreach my $dep ( @{$job_deps} ) {

          my @scheduler_index = ();
          next unless $self->jobs->{$dep}->submit_by_tags;

          my $dep_batches = $self->jobs->{$dep}->batches;

          my $x = 0;
          foreach my $dep_batch ( @{$dep_batches} ) {

              #Changing this to return the index
              ##TODO UPDATE THIS FOR MULTIPLE BATCHES WITHIN ARRAY
              push( @scheduler_index, $x )
                if $self->search_tags( $dep_batch->batch_tags, $tags );

              $x++;
          }

          $scheduler_ref->{$dep} = \@scheduler_index;
      }

      return $scheduler_ref;
}

=head3 search_tags

Check for matching tags. We match against any

job02 depends on job01

job01 batch01 has tags Sample1,Sample2
job01 batch02 has tags Sample3

job02 batch01 has tags Sample1

job02 batch01 depends upon job01 batch01 - because it has an overlap
But not job01 batch02

=cut

sub search_tags {
      my $self        = shift;
      my $batch_tags  = shift;
      my $search_tags = shift;

      foreach my $batch_tag ( @{$batch_tags} ) {
          foreach my $search_tag ( @{$search_tags} ) {
              if ( "$search_tag" eq "$batch_tag" ) {
                  return 1;
              }
          }
      }

      return 0;
}

1;
