#! /usr/bin/perl
use warnings;

# Chimera-score.pl by Kipp Akers
# usage: chimera-score.pl star_output_dir filter_script.pl

$dir=$ARGV[0];
$sam = $dir . "Chimeric.out.sam";
$junctions = $dir . "Chimeric.out.junction";
$readcount=0;
$junctionline=0;
#print "$junctions\n $sam\n";
open (JUNCTIONS, "< $junctions") or die $!;
	@chimeric_out_junctions=<JUNCTIONS>;
close JUNCTIONS or die $!;

$tempfile=$dir;
$tempfile =~ s/\/$//;
$tempfile =~ s/.*\///;
$uniqID = $tempfile; 
$tempfile = $tempfile . ".temp";
open (TEMPOUT, ">$tempfile") or die $!; 

open (SAM, "< $sam") or die $!;
	while (<SAM>) { #go through each line of the junctions file
		next if ($_ =~ m/^@/);
		$readcount++;
		if ($readcount == 1) {
			@samsplit = split(/\s+/, $_);
			$name=$samsplit[0];
			$hitindex=$samsplit[12];
			@scoresplit=split(/:/, $samsplit[13]);
			$score = $scoresplit[2];
			#print "assigned $name and $score\n";
			next;
		}
		@samsplit = split(/\s+/, $_);
		#split the line
		#0:name #12:hit index #13:alignment score
		if ($samsplit[0] ~~ $name ) {#ID match
			if ($samsplit[12] ~~ $hitindex ) {#hitindexmatch
				next;
			}
			else {#different hitindex
				@scoresplit=split(/:/, $samsplit[13]); #the column has format AS:i:100 
				$score += $scoresplit[2];
				$hitindex = $samsplit[12];
			}
			#print "updated $score for $name (idmatch)\n";
		}
		else { #new ID
			#print "main script $name and $score on line $readcount\n";
			&junc_filter($name, $score);
			#print "$name\t$score\n";
			$name = $samsplit[0];
			$hitindex=$samsplit[12];
			@scoresplit=split(/:/, $samsplit[13]);
			$score=$scoresplit[2];
			#print "assigned $name and $score (else)\n";
		}
	}
&junc_filter($name, $score);
#print "$name\t$score\n";
#now the filtered circs are in the temp file. 
close TEMPOUT;
# sort the tempfile and pipe it into filter circs. 
my $cmd1 = 'sort -k1,1 -k2,2n -k5,5n -k6,6 ';
$cmd1 = $cmd1 . $tempfile ; 
my $cmd2 = $ARGV[1] . " " . $uniqID ;
system("$cmd1 | $cmd2 "); 
$remove_temp='rm ' . $tempfile ; 
system("$remove_temp") ;

sub junc_filter
{	
	#print "first argument was $_[0] and the second was $_[1]\n";
	@split = split(/\s+/, $chimeric_out_junctions[$junctionline]); #0: chromosome of donor 1: first base of the intron of the donor 2: strand of the donor 3: chromosome of the acceptor4: first base of the intron of the acceptor5: strand of the acceptor 
	#6: junction type: -1=junction is between the mates, 1=GT/AG, 2=CT/AC 7: repeat length to the left of the junction 8: repeat length to the right of the junction 9/10/11/12/13 readname/1stbase/cigar/1stbase/cigar
	if ( $split[9] ne $_[0] ) {
		die "out of order chimeric files, $split[9] does not match $_[0] at line $junctionline.  please check inputs\n";
	}
	if ($split[6] >= 0 &&
		$split[0] ne "MT" &&
		$split[0] ne "chrM" &&
                $split[0] eq $split[3] &&
                $split[2] eq $split[5] &&
		$split[7] <= 5 && $split[8] <= 5 &&
                (($split[2] eq "-" && $split[4] > $split[1] && $split[4]-$split[1] < 100000) || ($split[2] eq "+" && $split[1]>$split[4] && $split[1]-$split[4]<100000)) ) {
                        #if junction spanning read && chimeric segs on same chrom && same strand && ( neg || pos strand && donor and acceptor are within 100kb)
			chomp $chimeric_out_junctions[$junctionline];
			if ($split[2] eq "+") {
	                        print TEMPOUT "$split[0]\t$split[1]\t$split[2]\t$split[3]\t$split[4]\t$split[5]\t$split[6]\t$split[7]\t$split[8]\t$_[1]\n"; #print the junctions.out line + the score
        		}
			else {
	                        print TEMPOUT "$split[0]\t$split[4]\t$split[2]\t$split[3]\t$split[1]\t$split[5]\t$split[6]\t$split[7]\t$split[8]\t$_[1]\n"; #print the junctions.out line + the score
			}
	
        }
	$junctionline++;
}
