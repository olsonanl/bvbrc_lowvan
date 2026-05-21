#
# Annotate a viral genome using LowVan
#
# This is a wrapper to call the component scripts that make up the LowVan service.
#

use strict;
use Data::Dumper;
use Getopt::Long::Descriptive;
use IPC::Run qw(run start finish);

my ($opt, $usage) = describe_options("%c %o [< in] [> out]",
				     ["in|i=s", "Input GTO"],
				     ["out|o=s", "Output GTO"],
				     ["prefix=s" => "Output file prefix", { default => "Viral_Anno"}],
				     ["remove-existing" => "Remove existing CDS, mat_peptide, and RNA features if run is successful"],
				     ["max-contig-length=i" => "Max contig length, default is 30000", { default => 30000 }],
				     ["min-contig-length=i", => "Min contig length, default is 1000", { default => 1000 }],

				     ["variant-cov=i"              => "Overall Minimum BLASTn percent query coverage (D = 95)", { default => 95 }],
				     ["variant-id=i"               => "Overall Minimum BLASTn percent identity  (D = 95)", { default => 95 }],

				     ["transcript-cov=i"              => "Minimum BLASTn percent query coverage (D = 95)", { default => 95 }],
				     ["transcript-id=i"               => "Minimum BLASTn percent identity  (D = 95)", { default => 95 }],
				     ["transcript-gaps=i"             => "Maximum number of allowable gaps (D = 2)", { default => 2 }],
				     ["transcript-e_val=f"            => "Maximum BLASTn evalue for considering any HSP (D = 0.5)", { default => 0.5 }],
				     ["transcript-lower_pid=i"        => "Lower percent identity threshold for a feature call without transcript editing correction (D = 80)", {default => 80}],
				     ["transcript-lower_pcov=i"       => "Lower percent query coverage for for a feature call without transcript editing correction (D = 80)", {default => 80}],

				     ["ambiguous=f"   => "Fraction of ambiguous bases, (Default = 0.01)", { default => 0.01 }],
				     
				     ["parallel=i", "Number of threads to use", { default => 1 }],
				     ["help|h", "Print this help message"]);


print($usage->text), exit 0 if $opt->help;

my @stage_params;

#
# Log versions
#
for my $tool (qw(annotate_by_viral_pssm-GTO.pl get_splice_variant_features.pl get_transcript_edited_features.pl viral_genome_quality.pl))
{
    system($tool, "--version");
}

#
# Stage 1
#

my $params = ["annotate_by_viral_pssm-GTO.pl"];
if ($opt->in)
{
    push(@$params, "--in", $opt->in);
}

push(@$params, "--remove-existing") if $opt->remove_existing;
push(@$params,
     "--prefix", $opt->prefix,
     "--threads", $opt->parallel,
     "--max", $opt->max_contig_length,
     "--min", $opt->min_contig_length);
push(@stage_params, $params);

#
# Stage 2
#

$params = ["get_splice_variant_features.pl"];
push(@$params,
     "--cov", $opt->variant_cov,
     "--id", $opt->variant_id,
     "--threads", $opt->parallel);
push(@stage_params, $params);

#
# Stage 3
#

$params = ["get_transcript_edited_features.pl"];
push(@$params,
     "--cov", $opt->transcript_cov,
     "--id", $opt->transcript_id,
     "--gaps", $opt->transcript_id,
     "--e_val", $opt->transcript_id,
     "--lower_pid", $opt->transcript_lower_pid,
     "--lower_pcov", $opt->transcript_lower_pcov,
     "--threads", $opt->parallel);
push(@stage_params, $params);

#
# Stage 4
#

$params = ["viral_genome_quality.pl"];
	   
if ($opt->out)
{
    push(@$params, "--out", $opt->out);
}
push(@$params,
     "--prefix", $opt->prefix,
     "--ambiguous", $opt->ambiguous);
push(@stage_params, $params);

#
# And construct pipeline.
# 

my @pipeline;

my @pipeline = intersperse("|", $opt->prefix, @stage_params);
print "Running: " .  Dumper(@pipeline);

my $h = start(@pipeline);
my $ok = $h->finish();

if (!$ok)
{
    warn "Pipeline failure:\n";
    for my $i (0..$#stage_params)
    {
	warn "Stage $i: rc=" . $h->result($i) . ": @{$stage_params[$i]}\n";
    }
    exit 1;
}
			  



  


sub intersperse {
    my ($sep, $prefix, @list) = @_;
    return unless @list;
    my @out;
    my $cur = shift @list;
    push(@out, $cur);
    (my $prog = $cur->[0]) =~ s/\.pl$//;
    push(@out, "2>", "$prefix.stderr.$prog");
    
    for my $item (@list) {
	push(@out, $sep, $item);
	(my $prog = $item->[0]) =~ s/\.pl$//;
	push(@out, "2>", "$prefix.stderr.$prog");
    }
    return @out;
}
