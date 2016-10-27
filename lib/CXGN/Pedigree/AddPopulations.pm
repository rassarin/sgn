package CXGN::Pedigree::AddPopulations;

=head1 NAME

CXGN::Pedigree::AddPopulations - a module to add populations.

=head1 USAGE

 my $population_add = CXGN::Pedigree::AddPopulations->new({ schema => $schema, name => $name, members =>  \@members} );
 $population_add->add_population();

=head1 DESCRIPTION

=head1 AUTHORS

Bryan Ellerbrock (bje24@cornell.edu)

=cut

use Moose;
use MooseX::FollowPBP;
use Moose::Util::TypeConstraints;
use Try::Tiny;


has 'schema' => (
		 is       => 'rw',
		 isa      => 'DBIx::Class::Schema',
		 predicate => 'has_schema',
		 required => 1,
		);
has 'name' => (isa => 'Str', is => 'rw', predicate => 'has_name', required => 1,);
has 'members' => (isa =>'ArrayRef[Str]', is => 'rw', predicate => 'has_members', required => 1,);

sub add_population {
	my $self = shift;
	my $schema = $self->get_schema();
	my $population_name = $self->get_name();
	my @members = @{$self->get_members()};
	my $error;

	my $cvterm_rs = $schema->resultset("Cv::Cvterm");
	my $population_cvterm_id = $cvterm_rs->search({name => 'population'})->first()->cvterm_id();
	my $member_of_cvterm_id = $cvterm_rs->search({name => 'member_of'})->first()->cvterm_id();

	# create population stock entry
	try {
	my $pop_rs = $schema->resultset("Stock::Stock")->create(
{
		name => $population_name,
		uniquename => $population_name,
		type_id => $population_cvterm_id,
});

	 # generate population connections to the members
	foreach my $m (@members) {
my $m_row = $schema->resultset("Stock::Stock")->find({ uniquename => $m });
my $connection = $schema->resultset("Stock::StockRelationship")->create(
		{
	subject_id => $m_row->stock_id,
	object_id => $pop_rs->stock_id,
	type_id => $member_of_cvterm_id,
		});
	}
}
catch {
	$error =  $_;
};
if ($error) {
	print STDERR "Error creating population $population_name: $error\n";
	return 0;
} else {
	print STDERR "population $population_name added successfully\n";
	return { success => 1 };
}
}

#######
1;
#######