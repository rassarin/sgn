
package SGN::Controller::BreedersToolbox::Trial;

use Moose;

use File::Basename;
use File::Slurp qw | read_file |;
use URI::FromHash 'uri';

use CXGN::Trial::TrialLayout;
use CXGN::BreedersToolbox::Projects;
use SGN::View::Trial qw/design_layout_view design_info_view trial_detail_design_view/;
use CXGN::Trial::Download;

BEGIN { extends 'Catalyst::Controller'; }


sub trial_init : Chained('/') PathPart('breeders/trial') CaptureArgs(1) { 
    my $self = shift;
    my $c = shift;
    my $trial_id = shift;

    print STDERR "TRIAL INIT...".localtime()."\n";


    $c->stash->{trial_id} = $trial_id;
    print STDERR "TRIAL ID = $trial_id\n";
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    $c->stash->{schema} = $schema;
    my $trial;
    eval { 
	$trial = CXGN::Trial->new( { bcs_schema => $schema, trial_id => $trial_id });
    };
    if ($@) { 
	$c->stash->{template} = 'system_message.txt';
	$c->stash->{message} = "The requested trial ($trial_id) does not exist";
	return;
    }
    $c->stash->{trial} = $trial;    
    
    print STDERR "Check2: ".localtime()."\n";
}

sub old_trial_url : Path('/breeders_toolbox/trial') Args(1) { 
    my $self = shift;
    my $c = shift;
    my @args = @_;
    $c->res->redirect('/breeders/trial/'.$args[0]);
}

sub trial_info : Chained('trial_init') PathPart('') Args(0) { 
    my $self = shift;
    my $c = shift;
    print STDERR "Check3: ".localtime()."\n";
    my $format = $c->req->param("format");

    my $user = $c->user();
    if (!$user) { 
	$c->res->redirect( uri( path => '/solpeople/login.pl', query => { goto_url => $c->req->uri->path_query } ) );
	return;
    }

    $c->stash->{user_can_modify} = ($user->check_roles("submitter") || $user->check_roles("curator")) ;
    
    my $start_time = time();
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $trial = $c->stash->{trial};
    my $trial_layout = CXGN::Trial::TrialLayout->new( { schema => $schema, trial_id => $c->stash->{trial_id} });
    my $program_object = CXGN::BreedersToolbox::Projects->new( { schema => $schema });
    if (!$program_object->trial_exists($c->stash->{trial_id})) { 
	$c->stash->{message} = "The requested trial does not exist or has been deleted.";
	$c->stash->{template} = 'generic_message.mas';
	return;
    }
	
    my $plot_names_ref = $trial_layout->get_plot_names();
    my $plot_dimensions = $trial_layout->get_plot_dimensions();

    my @plot_names;
    if ($plot_names_ref) {
      @plot_names = @{$trial_layout->get_plot_names()};
    }

    my %design;
    my $design_ref;
    $design_ref = $trial_layout->get_design();
    if ($design_ref) {
      %design = %{$design_ref};
    }

    my $block_numbers = $trial_layout->get_block_numbers();
    my $number_of_blocks;
    if ($block_numbers) {
      $number_of_blocks = scalar(@{$block_numbers});
    }
    $c->stash->{number_of_blocks} = $number_of_blocks;

    my $replicate_numbers = $trial_layout->get_replicate_numbers();
    my $number_of_replicates;
    if ($replicate_numbers) {
      $number_of_replicates = scalar(@{$replicate_numbers});
    }

    $c->stash->{number_of_replicates} = $number_of_replicates;

    $c->stash->{trial_name} = $trial->get_name();

    $c->stash->{trial_type} = $trial->get_project_type();

    $c->stash->{planting_date} = $trial->get_planting_date();

    $c->stash->{harvest_date} = $trial->get_harvest_date();

    my $design_type = $trial_layout->get_design_type();
    $c->stash->{design_type} = $design_type;

    $c->stash->{accession_names} = $trial_layout->get_accession_names();

    $c->stash->{control_names} = $trial_layout->get_control_names();

    $c->stash->{plot_names} = $plot_names_ref;

    $c->stash->{trial_description} = $trial->get_description();

    $c->stash->{design} = \%design;

    $c->stash->{design_layout_view} = trial_detail_design_view(\%design);

    $c->stash->{plot_length} = $plot_dimensions->[0];

    $c->stash->{plot_width} = $plot_dimensions->[1];

    $c->stash->{plant_per_plot} = $plot_dimensions->[2];

    $c->stash->{location_data} = [ $trial->get_location()->[0], $trial->get_location()->[1] ];

    $c->stash->{breeding_program} = $program_object->get_breeding_programs_by_trial($c->stash->{trial_id});

    $c->stash->{year} = $trial->get_year();

    $c->stash->{plot_data} = [];

    $c->stash->{trial_id} = $c->stash->{trial_id};
    
    $c->stash->{traits_assayed} = $c->stash->{trial}->get_traits_assayed();

    if ($design_type eq "genotyping_plate") { 
	if ($format eq "as_table") { 
	    $c->stash->{template} = '/breeders_toolbox/genotyping_trials/format/as_table.mas';
	}
	else { 
	    $c->stash->{template} = '/breeders_toolbox/genotyping_trials/detail.mas';
	}
	
    }
    else { 
	$c->stash->{template} = '/breeders_toolbox/trial.mas';
    }
    
    print STDERR "check 6: ".(time()-$start_time)."\n";
    
}


sub trait_info :Path('/breeders/trial') Args(3) {
    my ($self, $c, $trial_id, $trait_txt, $trait_id) = @_;

    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
   
    my $trial_name = $schema->resultset("Project::Project")
        ->search( {'me.project_id' => $trial_id})
        ->single
        ->name;
  
    $c->stash->{trial_name} = $trial_name;

    my $trait_name = $schema->resultset("Cv::Cvterm")
        ->search({'me.cvterm_id' => $trait_id})
        ->single
        ->name;
    
    $c->stash->{trial_id}   = $trial_id;
    $c->stash->{trial_name} = $trial_name;
    
    $c->stash->{trait_id}   = $trait_id;
    $c->stash->{trait_name} = $trait_name;
      
    $c->stash->{template}   = '/breeders_toolbox/trial_trait.mas';
}


sub trial_tree : Path('/breeders/trialtree') Args(0) { 
    my $self = shift;
    my $c = shift;

    
    $c->stash->{template} = '/breeders_toolbox/trialtree.mas';

}

sub trial_download : Chained('trial_init') PathPart('download') Args(1) { 
    my $self = shift;
    my $c = shift;
    my $what = shift;

    my $user = $c->user();
    if (!$user) { 
	$c->res->redirect( uri( path => '/solpeople/login.pl', query => { goto_url => $c->req->uri->path_query } ) );
	return;
    }

    my $format = $c->req->param("format") || "xls";
    my $trait_list = $c->req->param("trait_list") || "";

    my @trait_list;
    if ($trait_list) { 
	@trait_list = @{_parse_list_from_json($trait_list)};
    }
    
    my $plugin = "";
    if ( ($format eq "xls") && ($what eq "layout")) { 
	$plugin = "TrialLayoutExcel";
    }
    if (($format eq "csv") && ($what eq "layout")) { 
	$plugin = "TrialLayoutCSV";
    }
    if (($format eq "xls") && ($what =~ /phenotype/)) { 
	$plugin = "TrialPhenotypeExcel";
    }
    if (($format eq "csv") && ($what =~ /phenotype/)) { 
	$plugin = "TrialPhenotypeCSV";
    }
    if (($format eq "xls") && ($what eq "basic_trial_excel")) { 
	$plugin = "BasicExcel";
    }
    
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $trial_layout = CXGN::Trial::TrialLayout->new({schema => $schema, trial_id => $c->stash->{trial_id} });
    my $trial_name = $trial_layout->get_trial_name();
    my $trial_id = $trial_layout->get_trial_id();
    my $dir = $c->tempfiles_subdir('download');
    my $temp_file_name = $trial_id . "_" . "$what" . "XXXX";
    my $rel_file = $c->tempfile( TEMPLATE => "download/$temp_file_name");
    $rel_file = $rel_file . ".$format";
    my $tempfile = $c->config->{basepath}."/".$rel_file;

    print STDERR "TEMPFILE : $tempfile\n";

    my $download = CXGN::Trial::Download->new( 
	{ 
	    bcs_schema => $c->stash->{schema},
	    trial_id => $c->stash->{trial_id},
	    trait_list => \@trait_list,
	    filename => $tempfile,
	    format => $plugin,
      });

      my $error = $download->download();

      my $file_name = $trial_id . "_" . "$what" . ".$format";
     $c->res->content_type('Application/'.$format);    
     $c->res->header('Content-Disposition', qq[attachment; filename="$file_name"]);   

    my $output = read_file($tempfile);

    $c->res->body($output);

}

sub _parse_list_from_json {
    my $list_json = shift;
    my $json = new JSON;
    if ($list_json) {
	my $decoded_list = $json->allow_nonref->utf8->relaxed->escape_slash->loose->allow_singlequote->allow_barekey->decode($list_json);
	#my $decoded_list = decode_json($list_json);
	my @array_of_list_items = @{$decoded_list};
	return \@array_of_list_items;
    }
    else {
	return;
    }
}


1;
