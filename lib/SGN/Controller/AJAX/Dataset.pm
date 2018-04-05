
package SGN::Controller::AJAX::Dataset;

use Moose;

BEGIN { extends 'Catalyst::Controller::REST' }

use Data::Dumper;
use JSON::Any;
use CXGN::Dataset;
use CXGN::Genotype::Search;


__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
    );

sub store_dataset :Path('/ajax/dataset/save') Args(0) {
    my $self = shift;
    my $c = shift;

    my $user;
    if (!$c->user()) {
	$c->stash->{rest} = { error => "Login required to perform requested action." };
	return;
    }
    else {
	if (! ($c->user->check_roles('submitter') || $c->user->check_roles('curator'))) {
	    $c->stash->{rest} = { error => "Insufficient privileges to perform requested action." };
	    return;
	}
    }

    my %data;

    my $dataset_name = $c->req->param("name");
    my $dataset_description = $c->req->param("description");

    my $people_schema =  $c->dbic_schema("CXGN::People::Schema");
    if (CXGN::Dataset->exists_dataset_name($people_schema, $dataset_name)) {
	$c->stash->{rest} = { error => "The dataset with name $dataset_name already exists. Please chose another name." };
	return;
    }

    my $user_id = $c->user()->get_object()->get_sp_person_id();

    my $dataset = CXGN::Dataset->new( {
	schema => $c->dbic_schema("Bio::Chado::Schema"),
	people_schema => $people_schema,
				      });

    $dataset->sp_person_id($user_id);
    $dataset->name($dataset_name);
    $dataset->description($dataset_description);

    foreach my $type (qw | trials accessions years locations plots traits breeding_programs genotyping_protocols trial_types trial_designs category_order |) {
	print STDERR "Storing data: $type. $data{$type}\n";

	my $json = $c->req->param($type);
	if ($json) {
	    my $obj = JSON::Any->jsonToObj($json);
	    $dataset->$type($obj);
	}
    }

    $dataset->store();

    $c->stash->{rest} = { message => "Stored Dataset Successfully!" };
}

sub get_datasets_by_user :Path('/ajax/dataset/by_user') Args(0) {
    my $self = shift;
    my $c = shift;

    my $user = $c->user();
    if (!$user) {
	$c->stash->{rest} = { error => "No logged in user to display dataset information for." };
	return;
    }

    my $datasets = CXGN::Dataset->get_datasets_by_user(
	$c->dbic_schema("CXGN::People::Schema"),
	$user->get_object()->get_sp_person_id()
	);

    $c->stash->{rest} = $datasets;
}

sub get_dataset :Path('/ajax/dataset/get') Args(1) {
    my $self = shift;
    my $c = shift;
    my $dataset_id = shift;

    my $dataset = CXGN::Dataset->new(
	{
	    schema => $c->dbic_schema("Bio::Chado::Schema"),
	    people_schema => $c->dbic_schema("CXGN::People::Schema"),
	    sp_dataset_id=> $dataset_id,
	});

    my $dataset_data = $dataset->get_dataset_data();

    $c->stash->{rest} = { dataset => $dataset_data };
}

sub delete_dataset :Path('/ajax/dataset/delete') Args(1) {
    my $self = shift;
    my $c = shift;
    my $dataset_id = shift;

    if (!$c->user()) {
	$c->stash->{rest} = { error => "Deleting datasets requires login" };
	return;
    }

    my $logged_in_user = $c->user()->get_object()->get_sp_person_id();

    my $dataset = CXGN::Dataset->new(
	{
	    schema => $c->dbic_schema("Bio::Chado::Schema"),
	    people_schema => $c->dbic_schema("CXGN::People::Schema"),
	    sp_dataset_id=> $dataset_id,
	});

    print STDERR "Dataset owner: ".$dataset->sp_person_id.", logged in: $logged_in_user\n";
    if ($dataset->sp_person_id() != $logged_in_user) {
	$c->stash->{rest} = { error => "Only the owner can delete a dataset" };
	return;
    }

    my $error = $dataset->delete();

    if ($error) {
	$c->stash->{rest} = { error => $error };
    }
    else {
	$c->stash->{rest} = { success => 1 };
    }
}

sub get_dataset_genotypes :Path('/ajax/dataset/get_genotypes') :Args(0){
    my $self = shift;
    my $c = shift;
    my $dataset_id = $c->req->param("dataset_id");
    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado");

    my $dataset = CXGN::Dataset->new(

        schema => $c->dbic_schema("Bio::Chado::Schema"),
        people_schema => $c->dbic_schema("CXGN::People::Schema"),
        sp_dataset_id=> $dataset_id,
    );

    my $dataset_data = $dataset->get_dataset_data();
    print STDERR "DATASET =" .Dumper($dataset_data). "\n";

    my %data = %{$dataset_data};

    my @genotype_accessions = $data{'categories'}{'accessions'};
    my $genotype_protocol = $data{'categories'}{'genotyping_protocols'};

    print STDERR "ACCESSIONS =" .Dumper(@genotype_accessions). "\n";
    print STDERR "PROTOCOL =" .Dumper($genotype_protocol). "\n";

    my $genotypes_search = CXGN::Genotype::Search->new({
        bcs_schema=>$schema,
        accession_list=>\@genotype_accessions,
        protocol_id=>$genotype_protocol
    });
    my $genotypes = $genotypes_search->get_genotype_info();

    print STDERR "GENOTYPES =" .Dumper($genotypes). "\n";





    $c->stash->{rest} = { dataset => $dataset_data };
}

1;