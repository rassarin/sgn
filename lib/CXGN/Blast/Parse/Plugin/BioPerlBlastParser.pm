
package CXGN::Blast::Parse::Plugin::BioPerlBlastParser;

use Moose;

use English;
use HTML::Entities;
use List::MoreUtils 'minmax';
use Bio::SeqIO;
use Bio::SearchIO;
use Bio::SearchIO::Writer::HTMLResultWriter;
use CXGN::Tools::Identifiers;

use constant MAX_FORMATTABLE_REPORT_FILE_SIZE => 2_000_000;

sub name { 
    return "bioperl";
}

sub parse { 
    my $self = shift;
    my $raw_report_file = shift;
    my $bdb = shift;

    # check if $raw_report_file exists
    unless (-e $raw_report_file) {
        my $error = "BLAST results are automatically deleted after 7 days. You may need to run your BLAST again. "
            . "If you feel you received this message in error, please <a href='/contact/form'>contact us</a>.";
	return { file => '',
		 error => $error,
	};
    }
    
    
    #don't do any formatting on report files that are huge
    return $raw_report_file if -s $raw_report_file > MAX_FORMATTABLE_REPORT_FILE_SIZE;

    my $formatted_report_file = $raw_report_file.".formatted.html";
    
    #for smaller reports, HTML format them
    my %bioperl_formats = ( 0 => 'blast', #< only do for regular output,
                            #not the tabular and xml, even
                            #though bioperl can parse
                            #these.  if people choose
                            #these, they probably don't
                            #want bioperl to munge it.
	);

    
    sub linkit {
        my $bdb = shift;
        my $s = shift;
	
        $s =~ s/^lcl\|//;
        my $url = $bdb->lookup_url || CXGN::Tools::Identifiers::identifier_url($s);
        return qq { <a class="blast_match_ident" href="$url">$s</a> };
    }
    
    my $in = Bio::SearchIO->new(-format => 'blast', -file   => "< $raw_report_file")
	or die "$! opening $raw_report_file for reading";
    my $writer = $self->make_bioperl_result_writer( $bdb->blast_db_id() );
    my $out = Bio::SearchIO->new( -writer => $writer,
				  -file   => "> $formatted_report_file",
	);
    $out->write_result($in->next_result);
    
    open my $raw,$raw_report_file
	or die "$! opening $raw_report_file for reading";
    open my $fmt,'>',$formatted_report_file
	or die "$! opening $formatted_report_file for writing";
    
    print $fmt qq|<pre>|;
    while (my $line = <$raw>) {
	$line = encode_entities($line);
	$line =~ s/(?<=Query[=:]\s)(\S+)/linkit($bdb,$MATCH)/eg;
	print $fmt $line;
    }
    print $fmt qq|</pre>\n|;
    
    return $formatted_report_file;
}

sub make_bioperl_result_writer {
    my $self = shift;
    my $db_id = shift;

    my $writer = Bio::SearchIO::Writer::HTMLResultWriter->new;
    
    $writer->id_parser( sub {
	my ($idline) = @_;
	my ($ident,$acc) = Bio::SearchIO::Writer::HTMLResultWriter::default_id_parser($idline);
	
	# The default implementation checks for NCBI-style identifiers in the given string ('gi|12345|AA54321').
	# For these IDs, it extracts the GI and accession and
	# returns a two-element list of strings (GI, acc).
	
	return ($ident,$acc) if $acc;
	return CXGN::Tools::Identifiers::clean_identifier($ident) || $ident;
    });
    
    my $hit_link = sub {
	my ($self, $hit, $result) = @_;
	
	my $id = $hit->name;
	
	#see if we can link it as a CXGN identifier.  Otherwise,
	#use the default bioperl link generat	
	my $identifier_url = CXGN::Tools::Identifiers::identifier_url( $id );
	my $js_identifier_url = $identifier_url ? "'$identifier_url'" : 'null';
		
	my $region_string = $id.':'.join('..', minmax map { $_->start('subject'), $_->end('subject') } $hit->hsps );
	
	my $coords_string =
	    "hilite_coords="
	    .join( ',',
		   map $_->start('subject').'-'.$_->end('subject'),
		   $hit->hsps,
	    );
	
	my $match_seq_url = "show_match_seq.pl?blast_db_id=$db_id;id=$id;$coords_string";
	
	my $no_js_url = $identifier_url || $match_seq_url;
	
	return qq{ <a class="blast_match_ident" href="$no_js_url" onclick="return resolve_blast_ident( '$id', '$region_string', '$match_seq_url', $js_identifier_url )">$id</a> };
	
    };
    $writer->hit_link_desc(  $hit_link );
    $writer->hit_link_align( $hit_link );
    $writer->start_report(sub {''});
    $writer->end_report(sub {''});
    return $writer;
}

1;
