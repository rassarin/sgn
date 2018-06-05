package CXGN::Phenotypes::Search::MaterializedView;

=head1 NAME

CXGN::Phenotypes::Search::MaterializedView - an object factory to handle searching phenotypes across database. Called from CXGN::Phenotypes::SearchFactory. Processes phenotype search against materialized views.

=head1 USAGE

my $phenotypes_search = CXGN::Phenotypes::SearchFactory->instantiate(
    'MaterializedView',    #can be either 'MaterializedView', or 'Native'
    {
        bcs_schema=>$schema,
        data_level=>$data_level,
        trait_list=>$trait_list,
        trial_list=>$trial_list,
        year_list=>$year_list,
        location_list=>$location_list,
        accession_list=>$accession_list,
        plot_list=>$plot_list,
        plant_list=>$plant_list,
        include_timestamp=>$include_timestamp,
        trait_contains=>$trait_contains,
        phenotype_min_value=>$phenotype_min_value,
        phenotype_max_value=>$phenotype_max_value,
        limit=>$limit,
        offset=>$offset
    }
);
my @data = $phenotypes_search->search();

=head1 DESCRIPTION


=head1 AUTHORS


=cut

use strict;
use warnings;
use Moose;
use Try::Tiny;
use Data::Dumper;
use SGN::Model::Cvterm;
use CXGN::Stock::StockLookup;
use CXGN::Calendar;

has 'bcs_schema' => ( isa => 'Bio::Chado::Schema',
    is => 'rw',
    required => 1,
);

#(plot, plant, or all)
has 'data_level' => (
    isa => 'Str|Undef',
    is => 'ro',
);

has 'trial_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'rw',
);

has 'trait_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'rw',
);

has 'accession_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'rw',
);

has 'plot_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'rw',
);

has 'plant_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'rw',
);

has 'location_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'rw',
);

has 'year_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'rw',
);

has 'include_timestamp' => (
    isa => 'Bool|Undef',
    is => 'ro',
    default => 0
);

has 'trait_contains' => (
    isa => 'ArrayRef[Str]|Undef',
    is => 'rw'
);

has 'phenotype_min_value' => (
    isa => 'Str|Undef',
    is => 'rw'
);

has 'phenotype_max_value' => (
    isa => 'Str|Undef',
    is => 'rw'
);

has 'limit' => (
    isa => 'Int|Undef',
    is => 'rw'
);

has 'offset' => (
    isa => 'Int|Undef',
    is => 'rw'
);

sub search {
    my $self = shift;
    my $schema = $self->bcs_schema();
    print STDERR "Search Start:".localtime."\n";
    my $rep_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'replicate', 'stock_property')->cvterm_id();
    my $block_number_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'block', 'stock_property')->cvterm_id();
    my $plot_number_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot number', 'stock_property')->cvterm_id();
    my $row_number_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'row_number', 'stock_property')->cvterm_id();
    my $col_number_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'col_number', 'stock_property')->cvterm_id();
    my $is_a_control_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'is a control', 'stock_property')->cvterm_id();
    my $plant_number_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plant_index_number', 'stock_property')->cvterm_id();
    my $year_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'project year', 'project_property')->cvterm_id();
    my $design_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'design', 'project_property')->cvterm_id();
    my $breeding_program_rel_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'breeding_program_trial_relationship', 'project_relationship')->cvterm_id();
    my $planting_date_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'project_planting_date', 'project_property')->cvterm_id();
    my $havest_date_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'project_harvest_date', 'project_property')->cvterm_id();
    my $plot_width_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot_width', 'project_property')->cvterm_id();
    my $plot_length_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot_length', 'project_property')->cvterm_id();
    my $field_size_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'field_size', 'project_property')->cvterm_id();
    my $field_trial_is_planned_to_be_genotyped_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'field_trial_is_planned_to_be_genotyped', 'project_property')->cvterm_id();
    my $field_trial_is_planned_to_cross_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'field_trial_is_planned_to_cross', 'project_property')->cvterm_id();
    my $plot_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot', 'stock_type')->cvterm_id();
    my $plant_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plant', 'stock_type')->cvterm_id();
    my $accession_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
    my $include_timestamp = $self->include_timestamp;
    my $numeric_regex = '^[0-9]+([,.][0-9]+)?$';

    my $stock_lookup = CXGN::Stock::StockLookup->new({ schema => $schema} );
    my %synonym_hash_lookup = %{$stock_lookup->get_synonym_hash_lookup()};

    my %columns = (
      accession_id=> 'accession_id',
      observationunit_stock_id=> 'stock.stock_id',
      trial_id=> 'trial_id',
      trait_id=> 'trait_id',
      location_id=> 'location_id',
      year_id=> 'year_id',
      trait_name=> 'traits.trait_name',
      phenotype_value=> 'phenotype.value',
      trial_name=> 'trials.trial_name',
      observationunit_uniquename=> 'stock.uniquename',
      accession_name=> 'accessions.accession_name',
      location_name=> 'locations.location_name',
      trial_design=> 'trial_designs.trial_design_name',
      observationunit_type=> "observationunit_type.name",
      from_clause=> " FROM materialized_phenoview
          LEFT JOIN traits USING(trait_id)
          LEFT JOIN trials USING(trial_id)
          JOIN project ON(trial_id = project.project_id)
          LEFT JOIN stock USING(stock_id)
          JOIN stock_relationship ON (stock.stock_id=subject_id)
          JOIN cvterm as observationunit_type ON (observationunit_type.cvterm_id = stock.type_id)
          LEFT JOIN accessions USING(accession_id)
          LEFT JOIN locations USING(location_id)
          LEFT JOIN trial_designsXtrials USING(trial_id)
          LEFT JOIN trial_designs USING(trial_design_id)
          LEFT JOIN stockprop AS rep ON (stock.stock_id=rep.stock_id AND rep.type_id = $rep_type_id)
          LEFT JOIN stockprop AS block_number ON (stock.stock_id=block_number.stock_id AND block_number.type_id = $block_number_type_id)
          LEFT JOIN stockprop AS plot_number ON (stock.stock_id=plot_number.stock_id AND plot_number.type_id = $plot_number_type_id)
          LEFT JOIN stockprop AS row_number ON (stock.stock_id=row_number.stock_id AND row_number.type_id = $row_number_type_id)
          LEFT JOIN stockprop AS col_number ON (stock.stock_id=col_number.stock_id AND col_number.type_id = $col_number_type_id)
          LEFT JOIN stockprop AS is_a_control ON (stock.stock_id=is_a_control.stock_id AND is_a_control.type_id = $is_a_control_type_id)
          LEFT JOIN stockprop AS plant_number ON (stock.stock_id=plant_number.stock_id AND plant_number.type_id = $plant_number_type_id)
          LEFT JOIN projectprop as planting_date ON (project.project_id=planting_date.project_id AND planting_date.type_id = $planting_date_type_id)
          LEFT JOIN projectprop as harvest_date ON (project.project_id=harvest_date.project_id AND harvest_date.type_id = $havest_date_type_id)
          LEFT JOIN projectprop AS plot_width ON (project.project_id=plot_width.project_id AND plot_width.type_id = $plot_width_type_id)
          LEFT JOIN projectprop AS plot_length ON (project.project_id=plot_length.project_id AND plot_length.type_id = $plot_length_type_id)
          LEFT JOIN projectprop AS field_size ON (project.project_id=field_size.project_id AND field_size.type_id = $field_size_type_id)
          LEFT JOIN projectprop AS field_trial_is_planned_to_be_genotyped ON (project.project_id=field_trial_is_planned_to_be_genotyped.project_id AND field_trial_is_planned_to_be_genotyped.type_id = $field_trial_is_planned_to_be_genotyped_type_id)
          LEFT JOIN projectprop AS field_trial_is_planned_to_cross ON (project.project_id=field_trial_is_planned_to_cross.project_id AND field_trial_is_planned_to_cross.type_id = $field_trial_is_planned_to_cross_type_id)
          JOIN project_relationship ON (trial_id=project_relationship.subject_project_id AND project_relationship.type_id = $breeding_program_rel_type_id)
          JOIN project as breeding_program on (breeding_program.project_id=project_relationship.object_project_id)
          JOIN phenotype USING(phenotype_id)",
    );

    my $select_clause = "SELECT ".$columns{'observationunit_stock_id'}.", ".$columns{'observationunit_uniquename'}.", ".$columns{'observationunit_type'}.", ".$columns{'accession_name'}.", ".$columns{'accession_id'}.", ".$columns{'trial_id'}.", ".$columns{'trial_name'}.", project.description, plot_width.value, plot_length.value, field_size.value, field_trial_is_planned_to_be_genotyped.value, field_trial_is_planned_to_cross.value, breeding_program.project_id, breeding_program.name, breeding_program.description, ".$columns{'year_id'}.", ".$columns{'trial_design'}.", ".$columns{'location_name'}.", ".$columns{'location_id'}.", planting_date.value, harvest_date.value, ".$columns{'trait_id'}.", ".$columns{'trait_name'}.", ".$columns{'phenotype_value'}.", phenotype.uniquename, phenotype.phenotype_id, count(phenotype.phenotype_id) OVER() AS full_count, rep.value, block_number.value, plot_number.value, is_a_control.value, row_number.value, col_number.value, plant_number.value";

    my $group_by = " GROUP BY (".$columns{'observationunit_stock_id'}.", ".$columns{'observationunit_uniquename'}.", ".$columns{'observationunit_type'}.", ".$columns{'accession_name'}.", ".$columns{'accession_id'}.", ".$columns{'trial_id'}.", ".$columns{'trial_name'}.", project.description, plot_width.value, plot_length.value, field_size.value, field_trial_is_planned_to_be_genotyped.value, field_trial_is_planned_to_cross.value, breeding_program.project_id, breeding_program.name, breeding_program.description, ".$columns{'year_id'}.", ".$columns{'trial_design'}.", ".$columns{'location_name'}.", ".$columns{'location_id'}.", planting_date.value, harvest_date.value, ".$columns{'trait_id'}.", ".$columns{'trait_name'}.", ".$columns{'phenotype_value'}.", phenotype.uniquename, phenotype.phenotype_id, rep.value, block_number.value, plot_number.value, is_a_control.value, row_number.value, col_number.value, plant_number.value)";

    my $from_clause = $columns{'from_clause'};

    my $order_clause = " ORDER BY 6, 2, 27 DESC";

    my @where_clause;

    if ($self->accession_list && scalar(@{$self->accession_list})>0) {
        my $accession_sql = _sql_from_arrayref($self->accession_list);
        push @where_clause, $columns{'accession_id'}." in ($accession_sql)";
    }

    if (($self->plot_list && scalar(@{$self->plot_list})>0) && ($self->plant_list && scalar(@{$self->plant_list})>0)) {
        my $plot_and_plant_sql = _sql_from_arrayref($self->plot_list) .",". _sql_from_arrayref($self->plant_list);
        push @where_clause, $columns{'observationunit_stock_id'}." in ($plot_and_plant_sql)";
    } elsif ($self->plot_list && scalar(@{$self->plot_list})>0) {
        my $plot_sql = _sql_from_arrayref($self->plot_list);
        push @where_clause, $columns{'observationunit_stock_id'}." in ($plot_sql)";
    } elsif ($self->plant_list && scalar(@{$self->plant_list})>0) {
        my $plant_sql = _sql_from_arrayref($self->plant_list);
        push @where_clause, $columns{'observationunit_stock_id'}." in ($plant_sql)";
    }

    if ($self->trial_list && scalar(@{$self->trial_list})>0) {
        my $trial_sql = _sql_from_arrayref($self->trial_list);
        push @where_clause, $columns{'trial_id'}." in ($trial_sql)";
    }
    if ($self->trait_list && scalar(@{$self->trait_list})>0) {
        my $trait_sql = _sql_from_arrayref($self->trait_list);
        push @where_clause, $columns{'trait_id'}." in ($trait_sql)";
    }
    if ($self->location_list && scalar(@{$self->location_list})>0) {
        my $location_sql = _sql_from_arrayref($self->location_list);
        push @where_clause, $columns{'location_id'}." in ($location_sql)";
    }
    if ($self->year_list && scalar(@{$self->year_list})>0) {
        my $arrayref = $self->year_list;
        my $sql = join ("','" , @$arrayref);
        my $year_sql = "'" . $sql . "'";
        push @where_clause, $columns{'year_id'}." in ($year_sql)";
    }
    if ($self->trait_contains && scalar(@{$self->trait_contains})>0) {
        foreach (@{$self->trait_contains}) {
            push @where_clause, $columns{'trait_name'}." like '%".lc($_)."%'";
        }
    }
    if ($self->phenotype_min_value && !$self->phenotype_max_value) {
        push @where_clause, $columns{'phenotype_value'}."::real >= ".$self->phenotype_min_value;
        push @where_clause, $columns{'phenotype_value'}."~\'$numeric_regex\'";
    }
    if ($self->phenotype_max_value && !$self->phenotype_min_value) {
        push @where_clause, $columns{'phenotype_value'}."::real <= ".$self->phenotype_max_value;
        push @where_clause, $columns{'phenotype_value'}."~\'$numeric_regex\'";
    }
    if ($self->phenotype_max_value && $self->phenotype_min_value) {
        push @where_clause, $columns{'phenotype_value'}."::real BETWEEN ".$self->phenotype_min_value." AND ".$self->phenotype_max_value;
        push @where_clause, $columns{'phenotype_value'}."~\'$numeric_regex\'";
    }

    my $where_clause = '';
    if (scalar(@where_clause) > 0){
        $where_clause = " WHERE " . (join (" AND " , @where_clause));
    }

    my $offset_clause = '';
    my $limit_clause = '';
    if ($self->limit){
        $limit_clause = " LIMIT ".$self->limit;
    }
    if ($self->offset){
        $offset_clause = " OFFSET ".$self->offset;
    }

    my  $q = $select_clause . $from_clause . $where_clause . $group_by . $order_clause . $limit_clause . $offset_clause;

    print STDERR "QUERY: $q\n\n";

    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute();
    my @result;

    my $calendar_funcs = CXGN::Calendar->new({});

    while (my ($observationunit_stock_id, $observationunit_uniquename, $observationunit_type_name, $accession_uniquename, $accession_stock_id, $project_project_id, $project_name, $project_description, $plot_width, $plot_length, $field_size, $field_trial_is_planned_to_be_genotyped, $field_trial_is_planned_to_cross, $breeding_program_project_id, $breeding_program_name, $breeding_program_description, $year, $design, $location_name, $location_id, $planting_date, $harvest_date, $trait_id, $trait_name, $phenotype_value, $phenotype_uniquename, $phenotype_id, $full_count, $rep_select, $block_number_select, $plot_number_select, $is_a_control_select, $row_number_select, $col_number_select, $plant_number) = $h->fetchrow_array()) {
        my $timestamp_value;
        my $operator_value;
        if ($include_timestamp) {
            my ($p1, $p2) = split /date: /, $phenotype_uniquename;
            my ($timestamp, $operator_value) = split /  operator = /, $p2;
            if( $timestamp =~ m/(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})(\S)(\d{4})/) {
                $timestamp_value = $timestamp;
            }
        }
        my $synonyms = $synonym_hash_lookup{$accession_uniquename};
        my $harvest_date_value = $calendar_funcs->display_start_date($harvest_date);
        my $planting_date_value = $calendar_funcs->display_start_date($planting_date);
        push @result, {
            obsunit_stock_id => $observationunit_stock_id,
            obsunit_uniquename => $observationunit_uniquename,
            obsunit_type_name => $observationunit_type_name,
            accession_uniquename => $accession_uniquename,
            accession_stock_id => $accession_stock_id,
            synonyms => $synonyms,
            trial_id => $project_project_id,
            trial_name => $project_name,
            trial_description => $project_description,
            plot_width => $plot_width,
            plot_length => $plot_length,
            field_size => $field_size,
            field_trial_is_planned_to_be_genotyped => $field_trial_is_planned_to_be_genotyped,
            field_trial_is_planned_to_cross => $field_trial_is_planned_to_cross,
            breeding_program_id => $breeding_program_project_id,
            breeding_program_name => $breeding_program_name,
            breeding_program_description => $breeding_program_description,
            year => $year,
            design => $design,
            location_name => $location_name,
            location_id => $location_id,
            planting_date => $planting_date_value,
            harvest_date => $harvest_date_value,
            trait_id => $trait_id,
            trait_name => $trait_name,
            phenotype_value => $phenotype_value,
            phenotype_uniquename => $phenotype_uniquename,
            phenotype_id => $phenotype_id,
            timestamp => $timestamp_value,
            operator => $operator_value,
            full_count => $full_count,
            rep => $rep_select,
            block => $block_number_select,
            plot_number => $plot_number_select,
            is_a_control => $is_a_control_select,
            row_number => $row_number_select,
            col_number => $col_number_select,
            plant_number => $plant_number
        };
    }

    print STDERR "Search End:".localtime."\n";
    return \@result;
}

sub _sql_from_arrayref {
    my $arrayref = shift;
    my $sql = join ("," , @$arrayref);
    return $sql;
}

1;
