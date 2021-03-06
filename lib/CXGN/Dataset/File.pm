
package CXGN::Dataset::File;

use Moose;
use File::Slurp qw | write_file |;
use JSON::Any;

extends 'CXGN::Dataset';

has 'file_name' => ( isa => 'Str',
		     is => 'rw',
		     default => '/tmp/dataset_file',
    );

override('retrieve_genotypes', 
	 sub { 
	     my $self = shift;
	     my $protocol_id = shift;
	     my $file = shift || $self->file_name()."_genotype.txt";
	     my $genotypes = $self->SUPER::retrieve_genotypes($protocol_id);
	     my $genotype_json = JSON::Any->encode($genotypes);
	     write_file($file, $genotype_json);
	     return $genotypes;
	 });

override('retrieve_phenotypes',
	 sub {
	     my $self = shift;
	     my $file = shift || $self->file_name()."_phenotype.txt";
	     my $phenotypes = $self->SUPER::retrieve_phenotypes();
	     my $phenotype_string = join "\n", @$phenotypes;
	     write_file($file, $phenotype_string);
	     return $phenotypes;
	 });

override('retrieve_accessions',
	 sub { 
	     my $self = shift;
	     my $file = shift || $self->file_name()."_accessions.txt";
	     my $accessions = $self->SUPER::retrieve_accessions();
	     my $accession_json = JSON::Any->encode($accessions);
	     write_file($file, $accession_json);
	     return $accessions;
	 });

override('retrieve_plots',
	 sub { 
	     my $self = shift;
	     my $file = shift || $self->file_name()."_plots.txt";
	     my $plots = $self->SUPER::retrieve_plots();
	     my $plot_json = JSON::Any->encode($plots);
	     write_file($file, $plot_json);
	     return $plots;
	 });

override('retrieve_trials',
	 sub { 
	     my $self = shift;
	     my $file = shift || $self->file_name()."_trials.txt";
	     my $trials = $self->SUPER::retrieve_trials();
	     my $trial_json = JSON::Any->encode($trials);
	     write_file($file, $trial_json);
	     return $trials;
	 });

override('retrieve_traits',
	 sub { 
	     my $self = shift;
	     my $file = shift || $self->file_name()."_traits.txt";
	     my $traits = $self->SUPER::retrieve_traits();
	     my $trait_json = JSON::Any->encode($traits);
	     write_file($file, $trait_json);
	     return $traits;
	 });

override('retrieve_years',
	 sub { 
	     my $self = shift;
	     my $file = shift || $self->file_name()."_years.txt";
	     my $years = $self->SUPER::retrieve_years();
	     my $year_json = JSON::Any->encode($years);
	     write_file($file, $year_json);
	     return $years;
	 });

1;
