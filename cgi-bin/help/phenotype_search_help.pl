#!/usr/bin/perl
use strict;
use CXGN::Page;
my $page=CXGN::Page->new('');
$page->header('SGN: Phenotype search help');

print <<EOHTML;

<p>
The <a href="/search/direct_search.pl?search=phenotypes">phenotype search</a> is a
tool for searching SGN's database for accessions from phenotyped populations. 
</p>

<img src="/documents/help/screenshots/pheno_search_help.png" alt="screenshot of phenotype search form" style="margin: auto; border: 1px solid black;" />

<h4>1. Keyword</h4>
<p>
Here a word or a string can be typed. Searches the database for individuals with the word/string in their 'phenotype description' field.
</p><p>

</p>

<h4>2. Population</h4>
<p>
Each individual accession in the database is associated to a population.
The phenotype search can be limited to only accessions from a specific population. 

Currently the following phenotyped populations are included in the searchable database:
<ul>
<li>M82 EMS mutant population</li>
<li>Fast-neutron M82 mutant population</li>
<li>TGRC monogenic mutant population</li>
<li>Eggplant EMS mutant population</li>
<li>TGRC monogenic mutant population</li
<li>F2 2000 mapping population</li>
<li>M82 x L.pennellii IL population</li>
</ul>

</p>


<h4>3. Accession</h4>
<p>
If you know the accession name of your individual, type it in. By default, the database will be searched for all individuals with an accession name that starts with what you type in.For example, if you type in "e000", your results might include e0001m1, e0001m2, e0002m1, etc.

The search is case-insensitive.
</p>




EOHTML
;

$page->footer();
