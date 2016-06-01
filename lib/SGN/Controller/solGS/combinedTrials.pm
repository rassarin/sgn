package SGN::Controller::solGS::combinedTrials;

use Moose;
use namespace::autoclean;

use String::CRC;
use URI::FromHash 'uri';
use File::Path qw / mkpath  /;
use File::Spec::Functions qw / catfile catdir/;
use File::Temp qw / tempfile tempdir /;
use File::Slurp qw /write_file read_file :edit prepend_file/;
use File::Copy;
use File::Basename;
use Cache::File;
use Try::Tiny;
use List::MoreUtils qw /uniq/;
use Scalar::Util qw /weaken reftype/;
use Array::Utils qw(:all);
use CXGN::Tools::Run;
use JSON;


BEGIN { extends 'Catalyst::Controller' }


sub get_combined_pops_id :Path('/solgs/get/combined/populations/id') Args() {
    my ($self, $c) = @_;

    my $ids = $c->req->param('trials');
    my @pops_ids = split(/,/, $ids);
   
    my $combo_pops_id;
    my $ret->{status} = 0;

    if (@pops_ids > 1) 
    {
	$c->stash->{pops_ids_list} = \@pops_ids;
	$self->create_combined_pops_id($c);
	my $combo_pops_id = $c->stash->{combo_pops_id};
	$ret->{combo_pops_id} = $combo_pops_id;
	$ret->{status} = 1;
	
	my $entry = "\n" . $combo_pops_id . "\t" . $ids;
        $c->controller("solGS::solGS")->catalogue_combined_pops($c, $entry);
    }

    $ret = to_json($ret);
    
    $c->res->content_type('application/json');
    $c->res->body($ret);

}


sub prepare_data_for_trials :Path('/solgs/retrieve/populations/data') Args() {
    my ($self, $c) = @_;
   
    my $ids     = $c->req->param('trials');
    my @pops_ids = split(/,/, $ids);
 
    my $combo_pops_id;
    my $ret->{status} = 0;

    my $solgs_controller = $c->controller('solGS::solGS');
    my $not_matching_pops;
    my @g_files;
    
    if (scalar(@pops_ids) > 1)
    {  
	$c->stash->{pops_ids_list} = \@pops_ids;
	$self->create_combined_pops_id($c);
	my $combo_pops_id = $c->stash->{combo_pops_id};
	
        my $entry = "\n" . $combo_pops_id . "\t" . $ids;
        $solgs_controller->catalogue_combined_pops($c, $entry);
	
	$self->prepare_multi_pops_data($c);

        my $geno_files = $c->stash->{multi_pops_geno_files};
        @g_files = split(/\t/, $geno_files);

        $solgs_controller->compare_genotyping_platforms($c, \@g_files);
        $not_matching_pops =  $c->stash->{pops_with_no_genotype_match};
     
        if (!$not_matching_pops) 
        {	   	   
            $self->save_common_traits_acronyms($c);
        }
        else 
        {
            $ret->{not_matching_pops} = $not_matching_pops;
        }

        $ret->{combined_pops_id} = $combo_pops_id;
    }
    else 
    {
        my $pop_id = $pops_ids[0];
        
        $c->stash->{pop_id} = $pop_id;
        $solgs_controller->phenotype_file($c);
        $solgs_controller->genotype_file($c);
        
        $ret->{redirect_url} = "/solgs/population/$pop_id";
    }
      
    $ret = to_json($ret);
    
    $c->res->content_type('application/json');
    $c->res->body($ret);
   
}


sub combined_trials_page :Path('/solgs/populations/combined') Args(1) {
    my ($self, $c, $combo_pops_id) = @_;

    $c->stash->{pop_id} = $combo_pops_id;
    $c->stash->{combo_pops_id} = $combo_pops_id;
    
    $self->save_common_traits_acronyms($c);

    my $solgs_controller = $c->controller('solGS::solGS');
    
    $solgs_controller->get_all_traits($c);
    $solgs_controller->select_traits($c);
    $solgs_controller->get_acronym_pairs($c);
  
    $self->combined_trials_desc($c);
  
    $c->stash->{template} = $solgs_controller->template('/population/combined/combined.mas');
    
}


sub model_combined_trials_trait :Path('/solgs/model/combined/trials') Args(3) {
    my ($self, $c, $combo_pops_id, $trait_txt, $trait_id) = @_;

    $c->stash->{combo_pops_id} = $combo_pops_id;
    $c->stash->{trait_id}      = $trait_id;
    
    $self->combine_trait_data($c); 
    $self->build_model_combined_trials_trait($c);
    
    $c->controller('solGS::solGS')->gebv_kinship_file($c);    
    my $gebv_file = $c->stash->{gebv_kinship_file};
   
    if ( -s $gebv_file ) 
    {
        $c->res->redirect("/solgs/model/combined/populations/$combo_pops_id/trait/$trait_id");
        $c->detach();
    }           

}


sub models_combined_trials :Path('/solgs/models/combined/trials') Args(1) {
    my ($self, $c, $combo_pops_id) = @_;
  
    $c->stash->{combo_pops_id} = $combo_pops_id;
    $c->stash->{model_id} = $combo_pops_id;
    $c->stash->{pop_id} = $combo_pops_id;
    $c->stash->{data_set_type} = 'combined populations';
    
    my @traits_ids = $c->req->param('trait_id');
    my @traits_pages;
  
    my $solgs_controller = $c->controller('solGS::solGS');

    if (!@traits_ids) {
    
        $solgs_controller->analyzed_traits($c);
	my @analyzed_traits  = @{ $c->stash->{analyzed_traits} };

	foreach my $tr (@analyzed_traits)
	{	 
	    my $acronym_pairs = $solgs_controller->get_acronym_pairs($c);
	    my $trait_name;
	    if ($acronym_pairs)
	    {
		foreach my $r (@$acronym_pairs) 
		{
		    if ($r->[0] eq $tr) 
		    {
			$trait_name = $r->[1];
			$trait_name =~ s/\n//g;
			$c->stash->{trait_name} = $trait_name;
			$c->stash->{trait_abbr} = $r->[0];   
		    }
		}
	    }
         
	    my $trait_id   = $c->model('solGS::solGS')->get_trait_id($trait_name);
	    my $trait_abbr = $c->stash->{trait_abbr}; 

	    $solgs_controller->get_model_accuracy_value($c, $combo_pops_id, $trait_abbr);
	    my $accuracy_value = $c->stash->{accuracy_value};
	
	    $c->controller("solGS::Heritability")->get_heritability($c);
	    my $heritability = $c->stash->{heritability};
	    
	    push @traits_pages, 
	    [ qq | <a href="/solgs/model/combined/populations/$combo_pops_id/trait/$trait_id" onclick="solGS.waitPage()">$trait_abbr</a>|, $accuracy_value, $heritability];
	}
    }  
    elsif (scalar(@traits_ids) == 1) 
    {
        my $trait_id = $traits_ids[0];
        $c->res->redirect("/solgs/model/combined/trials/$combo_pops_id/trait/$trait_id");
        $c->detach();
    }
    elsif (scalar(@traits_ids) > 1) 
    {
        foreach my $trait_id (@traits_ids) 
        {
            $c->stash->{trait_id} = $trait_id;
            $solgs_controller->get_trait_name($c, $trait_id);
            my $tr_abbr = $c->stash->{trait_abbr};
	    
	    $self->combine_trait_data($c);  
            $self->build_model_combined_trials_trait($c);
          
            $solgs_controller->get_model_accuracy_value($c, $combo_pops_id, $tr_abbr);
            my $accuracy_value = $c->stash->{accuracy_value};
     
	    $c->controller("solGS::Heritability")->get_heritability($c);
	    my $heritability = $c->stash->{heritability};

            push @traits_pages, 
            [ qq | <a href="/solgs/model/combined/populations/$combo_pops_id/trait/$trait_id" onclick="solGS.waitPage()">$tr_abbr</a>|, $accuracy_value, $heritability];
	    
        }
    }  
  
    $solgs_controller->analyzed_traits($c);
    my $analyzed_traits = $c->stash->{analyzed_traits};
   
    $c->stash->{trait_pages} = \@traits_pages;
    $c->stash->{template}    = $solgs_controller->template('/population/combined/multiple_traits_output.mas');
       
    $self->combined_trials_desc($c);
        
    my $project_name = $c->stash->{project_name};
    my $project_desc = $c->stash->{project_desc};
        
    my @model_desc = ([qq | <a href="/solgs/populations/combined/$combo_pops_id">$project_name</a> |, $project_desc, \@traits_pages]);
    $c->stash->{model_data} = \@model_desc;
    $c->stash->{pop_id} = $combo_pops_id;
    $solgs_controller->get_acronym_pairs($c);  

}


sub selection_combined_pops_trait :Path('/solgs/selection/') Args(6) {
    my ($self, $c, $selection_pop_id, 
        $model_key, $combined_key, $model_id, 
        $trait_key, $trait_id) = @_;

    $c->stash->{combo_pops_id}        = $model_id;
    $c->stash->{trait_id}             = $trait_id;
    $c->stash->{prediction_pop_id}    = $selection_pop_id;
    $c->stash->{data_set_type}        = 'combined populations';
    $c->stash->{combined_populations} = 1;
        
    $c->controller('solGS::solGS')->get_trait_details($c, $trait_id);

    my $page = $c->req->referer();

    if ($page =~ /solgs\/model\/combined\/populations/ || $page =~ /solgs\/models\/combined\/trials/)
    { 
	$self->get_combined_pops_arrayref($c);   
	$c->stash->{trait_combo_pops} = $c->stash->{arrayref_combined_pops_ids};  
    } 
       
    $self->combined_trials_desc($c);      
  
    my $pop_rs = $c->model("solGS::solGS")->project_details($selection_pop_id);    
    
    while (my $pop_row = $pop_rs->next) 
    {      
	$c->stash->{prediction_pop_name} = $pop_row->name;    
    }
   
    my $identifier    = $model_id . '_' . $selection_pop_id;
    $c->controller('solGS::solGS')->prediction_pop_gebvs_file($c, $identifier, $trait_id);
    my $gebvs_file = $c->stash->{prediction_pop_gebvs_file};
    
    $c->controller('solGS::solGS')->top_blups($c, $gebvs_file);
 
    $c->stash->{blups_download_url} = qq | <a href="/solgs/download/prediction/model/$model_id/prediction/$selection_pop_id/$trait_id">Download all GEBVs</a>|; 

    $c->stash->{template} = $c->controller('solGS::solGS')->template('/selection/combined/selection_trait.mas');
} 


sub build_model_combined_trials_trait {
    my ($self, $c) = @_;
  
    my $solgs_controller = $c->controller('solGS::solGS');
    $c->stash->{data_set_type} = 'combined populations';
  
    $solgs_controller->gebv_kinship_file($c);
    my $gebv_file = $c->stash->{gebv_kinship_file};

    unless  ( -s $gebv_file ) 
    {   
        my $combined_pops_pheno_file = $c->stash->{trait_combined_pheno_file};
        my $combined_pops_geno_file  = $c->stash->{trait_combined_geno_file};
        	 
	$c->stash->{pop_id} = $c->stash->{combo_pops_id};	    
	$solgs_controller->get_rrblup_output($c);
    }
}


sub combine_trait_data {
    my ($self, $c) = @_;

    my $combo_pops_id = $c->stash->{combo_pops_id};
    my $trait_id      = $c->stash->{trait_id};
  
    my $solgs_controller = $c->controller('solGS::solGS');
    $solgs_controller->get_trait_details($c, $trait_id);
 
    $solgs_controller->cache_combined_pops_data($c);

    my $combined_pops_pheno_file = $c->stash->{trait_combined_pheno_file};
    my $combined_pops_geno_file  = $c->stash->{trait_combined_geno_file};
  
    my $geno_cnt  = (split(/\s+/, qx / wc -l $combined_pops_geno_file /))[0];
    my $pheno_cnt = (split(/\s+/, qx / wc -l $combined_pops_pheno_file /))[0];

    unless ( $geno_cnt > 10  && $pheno_cnt > 10 ) 
    {   	
	$self->get_combined_pops_arrayref($c);
	my $combined_pops_list = $c->stash->{arrayref_combined_pops_ids};
	$c->stash->{trait_combine_populations} = $combined_pops_list;

	$self->prepare_multi_pops_data($c);
	
	my $background_job = $c->stash->{background_job};
	my $prerequisite_jobs = $c->stash->{prerequisite_jobs};
	
	if ($background_job) 
	{	    
	    if ($prerequisite_jobs =~ /^:+$/) 
	    { 
		$prerequisite_jobs = undef;
	    }

	    if ($prerequisite_jobs) 
	    {
		$c->stash->{dependency}      =  $prerequisite_jobs;
		$c->stash->{dependency_type} = 'download_data';
	    }
	}	

	$solgs_controller->r_combine_populations($c);         
    }
                       
}


sub combine_data_build_model {
    my ($self, $c) = @_;

    my $trait_id = $c->stash->{trait_id};
    $c->controller('solGS::solGS')->get_trait_details($c, $trait_id);
	
    $self->combine_trait_data($c); 
  
    my $combine_job_id = $c->stash->{combine_pops_job_id};
   
    if ($combine_job_id) 
    {
	$c->stash->{dependency} = "'" . $combine_job_id . "'";
	
	if (!$c->stash->{dependency_type}) 
	{
	    $c->stash->{dependency_type} = 'combine_populations';
	}
    }
      
    $self->build_model_combined_trials_trait($c);
	
}


sub combined_trials_desc {
    my ($self, $c) = @_;
    
    my $combo_pops_id = $c->stash->{combo_pops_id};
        
    $self->get_combined_pops_arrayref($c);
    my $combined_pops_list = $c->stash->{arrayref_combined_pops_ids};
    
    my $solgs_controller = $c->controller('solGS::solGS');
          
    my $desc = 'This training population is a combination of ';
    
    my $projects_owners;
    my $s_pop_id;

    foreach my $pop_id (@$combined_pops_list)
    {  
        my $pr_rs = $c->model('solGS::solGS')->project_details($pop_id);

        while (my $row = $pr_rs->next)
        {
         
            my $pr_id   = $row->id;
            my $pr_name = $row->name;
            $desc .= qq | <a href="/solgs/population/$pr_id">$pr_name</a>|; 
            $desc .= $pop_id == $combined_pops_list->[-1] ? '.' : ' and ';
        } 

        $solgs_controller->get_project_owners($c, $_);
        my $project_owners = $c->stash->{project_owners};

        unless (!$project_owners)
        {
             $projects_owners.= $projects_owners ? ', ' . $project_owners : $project_owners;
        }
	
	$s_pop_id = $pop_id;
	$s_pop_id =~ s/\s+//;
    }
   
    my $dir = $c->{stash}->{solgs_cache_dir};

    my $geno_exp  = "genotype_data_${s_pop_id}.txt"; 
    my $geno_file = $solgs_controller->grep_file($dir, $geno_exp);  
   
    my @geno_lines = read_file($geno_file);
    my $markers_no = scalar(split ('\t', $geno_lines[0])) - 1;

    my $trait_exp        = "traits_acronym_pop_${combo_pops_id}";
    my $traits_list_file = $solgs_controller->grep_file($dir, $trait_exp);  

    my @traits_list = read_file($traits_list_file);
    my $traits_no   = scalar(@traits_list) - 1;

    my $training_pop = "Training population $combo_pops_id";
    
    my $protocol = $c->config->{default_genotyping_protocol};
    $protocol = 'N/A' if !$protocol;

    $c->stash(stocks_no    => scalar(@geno_lines) - 1,
	      markers_no   => $markers_no,
              traits_no    => $traits_no,
              project_desc => $desc,
              project_name => $training_pop,
              owner        => $projects_owners,
	      protocol     => $protocol,
        );

}


sub find_common_traits {
    my ($self, $c) = @_;
    
    my $combo_pops_id = $c->stash->{combo_pops_id};
   
    $self->get_combined_pops_arrayref($c);
    my $combined_pops_list = $c->stash->{arrayref_combined_pops_ids};

    my $solgs_controller = $c->controller('solGS::solGS');
    
    my @common_traits;  
    foreach my $pop_id (@$combined_pops_list)
    {  
	$c->stash->{pop_id} = $pop_id;

	$solgs_controller->get_single_trial_traits($c);
	$solgs_controller->traits_list_file($c);
	my $traits_list_file = $c->stash->{traits_list_file};

	my $traits = read_file($traits_list_file);
        my @trial_traits = split(/\t/, $traits);
       
        if (@common_traits)        
        {
            @common_traits = intersect(@common_traits, @trial_traits);
        }
        else 
        {    
            @common_traits = @trial_traits;
        }
    }
   
    $c->stash->{common_traits} = \@common_traits;
}


sub save_common_traits_acronyms {
    my ($self, $c) = @_;
    
     my $combo_pops_id = $c->stash->{combo_pops_id};
    
    # $self->get_combined_pops_arrayref($c);
    # my $combined_pops_list = $c->stash->{arrayref_combined_pops_ids};
    
    # my $solgs_controller = $c->controller('solGS::solGS');
   
    # $solgs_controller->multi_pops_pheno_files($c, $combined_pops_list);
    # my $all_pheno_files = $c->stash->{multi_pops_pheno_files};        
    # my @all_pheno_files = split(/\t/, $all_pheno_files);
    
    #$self->find_common_traits($c, \@all_pheno_files);
    $self->find_common_traits($c);
    my $common_traits = $c->stash->{common_traits};
       
    $c->stash->{pop_id} = $combo_pops_id;
    $c->controller('solGS::solGS')->traits_list_file($c);
    my $traits_file = $c->stash->{traits_list_file};
    write_file($traits_file, join("\t", @$common_traits)) if $traits_file;
  
}


sub get_combined_pops_arrayref {
   my ($self, $c) = @_;
   
   my $combo_pops_id = $c->stash->{combo_pops_id};

   $c->controller('solGS::solGS')->get_combined_pops_list($c, $combo_pops_id);
   my $pops_list = $c->stash->{combined_pops_list};
  
   $c->stash->{arrayref_combined_pops_ids} = $pops_list;

}


sub prepare_multi_pops_data {
   my ($self, $c) = @_;
   
   $self->get_combined_pops_arrayref($c);
   my $combined_pops_list = $c->stash->{arrayref_combined_pops_ids};

   my $solgs_controller = $c->controller('solGS::solGS');
  
   $solgs_controller->multi_pops_phenotype_data($c, $combined_pops_list);
   $solgs_controller->multi_pops_genotype_data($c, $combined_pops_list);
   $solgs_controller->multi_pops_geno_files($c, $combined_pops_list);
   $solgs_controller->multi_pops_pheno_files($c, $combined_pops_list);

   my @all_jobs = (@{$c->stash->{multi_pops_pheno_jobs_ids}}, 
		   @{$c->stash->{multi_pops_geno_jobs_ids}});
   
   my $prerequisite_jobs;

   if (@all_jobs && scalar(@all_jobs) > 1) 
   {
       $prerequisite_jobs = join(':', @all_jobs);
       
   } 
   else 
   {
       if (@all_jobs && scalar(@all_jobs) == 1) { $prerequisite_jobs = $all_jobs[0];}
   }

   if ($prerequisite_jobs =~ /^:+$/) {$prerequisite_jobs = undef;}
  
   $c->stash->{prerequisite_jobs} = $prerequisite_jobs;

}


sub create_combined_pops_id {    
    my ($self, $c) = @_;
    
    $c->stash->{combo_pops_id} = crc(join('', @{$c->stash->{pops_ids_list}}));

}


sub begin : Private {
    my ($self, $c) = @_;

    $c->controller("solGS::solGS")->get_solgs_dirs($c);
  
}


#####
1;
#####
