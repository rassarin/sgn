
=head1 NAME

SGN::Controller::AJAX::GenotypesVCFUpload - a REST controller class to provide the
backend for uploading genotype VCF files

=head1 DESCRIPTION

Uploading Genotype VCF

=head1 AUTHOR

=cut

package SGN::Controller::AJAX::GenotypesVCFUpload;

use Moose;
use Try::Tiny;
use DateTime;
use File::Slurp;
use File::Spec::Functions;
use File::Copy;
use Data::Dumper;
use CXGN::Phenotypes::ParseUpload;
use CXGN::Phenotypes::StorePhenotypes;
use List::MoreUtils qw /any /;
use CXGN::BreederSearch;
use CXGN::UploadFile;
use CXGN::Genotype::StoreVCFGenotypes;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );


sub upload_genotype_verify :  Path('/ajax/genotype/upload') : ActionClass('REST') { }
sub upload_genotype_verify_POST : Args(0) {
    my ($self, $c) = @_;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado");
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    my @error_status;
    my @success_status;

    print STDERR Dumper $c->req->params();

    my $user = $c->user();
    if (!$user) {
        $c->stash->{rest} = { error => 'Must be logged in to upload VCF genotypes!' };
        $c->detach();
    }

    my $user_type = $user->get_object->get_user_type();
    if ($user_type ne 'submitter' && $user_type ne 'curator') {
        $c->stash->{rest} = { error => 'Must have correct permissions to upload VCF genotypes! Please contact us.' };
        $c->detach();
    }

    my $user_id = $c->can('user_exists') ? $c->user->get_object->get_sp_person_id : $c->sp_person_id;

    my $upload = $c->req->upload('upload_genotype_vcf_file_input');
    my $upload_original_name = $upload->filename();
    my $upload_tempfile = $upload->tempname;
    my $subdirectory = "genotype_vcf_upload";
    my %phenotype_metadata;
    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();

    my $uploader = CXGN::UploadFile->new({
        tempfile => $upload_tempfile,
        subdirectory => $subdirectory,
        archive_path => $c->config->{archive_path},
        archive_filename => $upload_original_name,
        timestamp => $timestamp,
        user_id => $user_id,
        user_role => $user_type
    });
    my $archived_filename_with_path = $uploader->archive();
    my $md5 = $uploader->get_md5($archived_filename_with_path);
    if (!$archived_filename_with_path) {
        push @error_status, "Could not save file $upload_original_name in archive.";
        return (\@success_status, \@error_status);
    } else {
        push @success_status, "File $upload_original_name saved in archive.";
    }
    unlink $upload_tempfile;

    my $organism_species = $c->req->param('upload_genotypes_species_name_input');
    my $organism_genus_q = "SELECT genus FROM organism WHERE species = ?";
    my @found_genus;
    my $h = $schema->storage->dbh()->prepare($organism_genus_q);
    $h->execute($organism_species);
    while (my ($genus) = $h->fetchrow_array()){
        push @found_genus, $genus;
    }
    if (scalar(@found_genus) != 1){
        $c->stash->{rest} = { error => 'The organism species you provided is not in the database! Please contact us.' };
        $c->detach();
    }
    my $organism_genus = $found_genus[0];

    my $project_name = $c->req->param('upload_genotype_vcf_project_name');
    my $location_id = $c->req->param('upload_genotype_location_select');
    my $year = $c->req->param('upload_genotype_location_select');
    my $breeding_program_id = $c->req->param('upload_genotype_breeding_program_select');
    my $obs_type = $c->req->param('upload_genotype_vcf_observation_type');
    my $genotyping_facility = $c->req->param('upload_genotype_vcf_facility_select');
    my $description = $c->req->param('upload_genotype_vcf_project_description');
    my $protocol_name = $c->req->param('upload_genotype_vcf_protocol_name');
    my $contains_igd = $c->req->param('upload_genotype_vcf_include_igd_numbers');

    my $store_genotypes = CXGN::Genotype::StoreVCFGenotypes->new({
        bcs_schema=>$schema,
        metadata_schema=>$metadata_schema,
        phenome_schema=>$phenome_schema,
        vcf_input_file=>$archived_filename_with_path,
        observation_unit_type_name=>$obs_type,
        genotyping_facility=>$genotyping_facility,
        breeding_program_id=>$breeding_program_id,
        project_year=>$year,
        project_location_id=>$location_id,
        project_name=>$project_name,
        project_description=>$description,
        protocol_name=>$protocol_name,
        organism_genus=>$organism_genus,
        organism_species=>$organism_species,
        create_missing_observation_units_as_accessions=>0,
        igd_numbers_included=>$contains_igd
    });
    my $verified_errors = $store_genotypes->validate();
    my ($stored_genotype_error, $stored_genotype_success) = $store_genotypes->store();
}

1;
