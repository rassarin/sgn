package CXGN::BrAPI::FileRequest;

=head1 NAME

CXGN::BrAPI::FileRequest - an object to handle creating and archiving files for BrAPI requests that store data .

=head1 SYNOPSIS

this module is used to create and archive files for BrAPI requests that store data. It stores the file on fileserver and saves the file to a user, allowing them to access it later on.

=head1 AUTHORS

=cut

use Moose;
use Data::Dumper;
use File::Spec::Functions;
use List::MoreUtils qw(uniq);
use DateTime;

has 'schema' => (
    isa => 'Bio::Chado::Schema',
    is => 'rw',
    required => 1,
);

has 'user_id' => (
    is => 'ro',
    isa => 'Int',
    required => 1,
);

has 'user_type' => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);

has 'format' => (
	isa => 'Str',
	is => 'rw',
	required => 1,
);

has 'archive_path' => (
    isa => "Str",
    is => 'rw',
    required => 1,
);

has 'data' => (
	isa => 'ArrayRef',
	is => 'rw',
	required => 1,
);

sub BUILD {
	my $self = shift;
	my $format = $self->format;
	if ($format ne 'observations'){
		die "format must be observations\n";
	}
}

sub get_path {
	my $self = shift;
	my $format = $self->format;
	if ($format eq 'observations'){
		return $self->observations;
	}
}

sub observations {
	my $self = shift;
    my $schema = $self->schema;
	my $data = $self->data;
    my $user_id = $self->user_id;
    my $user_type = $self->user_type;
    my $archive_path = $self->archive_path;

    my $subdirectory = "brapi_observations_upload";
    my $archive_filename = "observations.csv";

    if (!-d $archive_path) {
        mkdir $archive_path;
    }

    if (! -d catfile($archive_path, $user_id)) {
        mkdir (catfile($archive_path, $user_id));
    }

    if (! -d catfile($archive_path, $user_id,$subdirectory)) {
        mkdir (catfile($archive_path, $user_id, $subdirectory));
    }

    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();
    my $file_path =  catfile($archive_path, $user_id, $subdirectory,$timestamp."_".$archive_filename);

    my @data = @{$data};

	open(my $fh, ">", $file_path) or die "Couldn't open file $file_path: $!";
    print $fh '"observationDbId","observationUnitDbId","observationVariableDbId","value","observationTimeStamp","collector"'."\n";
		foreach my $plot (@data){
            print $fh "\"$plot->{'observationDbId'}\"," || "\"\",";
            print $fh "\"$plot->{'observationUnitDbId'}\",";
            print $fh "\"$plot->{'observationVariableDbId'}\",";
            print $fh "\"$plot->{'value'}\",";
            print $fh "\"$plot->{'observationTimeStamp'}\"," || "\"\",";
            print $fh "\"$plot->{'collector'}\"" || "\"\"";
            print $fh "\n";
		}
	close $fh;

	return $file_path;
}

1;
