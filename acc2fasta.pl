#!/usr/bin/perl
use strict;
use warnings;

##############################################################################
#
# File   :  	acc2fasta.pl
# History:  	2013-05-12 (DRL) first implementation
#
##############################################################################
#
#  Perl script that takes in a list of accession numbers and fetches the fasta
#  files (with sanitised headers) from genbank
#
##############################################################################

=head1 

acc2fasta.pl - convert a bunch of accession numbers into a bunch of sequences

=head1 SYNOPSIS

B<acc2fasta.pl> [B<-q>] <acc_file> [B<-l>] <list_file> [B<-d>] <num> [B<-fw>] 

=head1 DESCRIPTION

B<acc2fasta.pl> takes a file of accession numbers, either in CSV (Filemaker export)
of TXT (one accession per line), and fetches the respective sequence with a cleaned 
header. 
If the input_file is in CSV (, a filter can be applied by providing a list of 

=head1 OPTIONS

=over 4

=item B<-q>uery
    
CSV or TXT file of accession numbers.

=item B<-l>ist

List of identifiers (e.g. 'seq1A') in TXT format (i.e Windows Text format when exporting from excel) that limits the ACC to be parsed from CSV.

=item B<-d>esc

Maximum length (e.g. '50') of sequence descriptions (headers) in the output fasta file.

=item B<-f>ull_desc

Write full sequence descriptions (headers) in the output fasta file (overwrites [-desc]).

=item B<-w>hitespaces

Words in sequence descriptions (headers) in the output fasta file are separated by spaces (Default is underscore '_').

=back

=head1 DIAGNOSTICS

=over 4

=back

=head1 AUTHOR

Dominik R. Laetsch, dominik.laetsch@gmail.com

=cut

##############################################################################
#
#   								START
# ----------------------------------------------------------------------------
# Dependencies
# ----------------------------------------------------------------------------
use Getopt::Long qw(:config pass_through no_ignore_case);
use Pod::Usage;
use Term::ANSIColor;
use POSIX;
# ============================================================================
#
#
# ----------------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------------
my ($query_file, $list_file, $maximum_length_of_header, $list_switch, $full_header_switch, $spaces) = ("","",50, 0, 0, 0);
my ($help, $man) = ("",""); 
my (%hash_of_acc);
# ============================================================================

# ----------------------------------------------------------------------------
# Get options
# ----------------------------------------------------------------------------
my @parameters=("-query","-desc","-full_desc","-whitespaces","-list","-help","-man"); #&VALIDATE_ARGS uses this for validation of parameters
GetOptions (
	"query:s" => \$query_file,
	"desc:i" => \$maximum_length_of_header, # default = 50
	"full_desc!" => \$full_header_switch, # default = 0
	"whitespaces!" => \$spaces, # default = 0
	"list:s" => \$list_file,
  	"help" => \$help,
  	"man" => \$man,
) or pod2usage(2);
pod2usage(1) if $help;
pod2usage(-verbose => 2) if ($man);
# ============================================================================

# ----------------------------------------------------------------------------
# Parsing and sanitising user input
# ----------------------------------------------------------------------------
die pod2usage(2) unless (&VALIDATE_ARGS(\@ARGV, \@parameters));
die pod2usage(1) unless $query_file;
if ($query_file !~m/(.csv)$/i && $query_file !~m/(.txt)$/i){
	die "   [ERROR] - Please provide a CSV or TXT file of accession numbers \n";
}

if ($list_file ne ""){
	if (&CHECK_FILE($list_file)){
		$list_switch=1;
	}
}
# ============================================================================

# ----------------------------------------------------------------------------
# Welcome screen
# ----------------------------------------------------------------------------
print ("\n\t\t####################################################\n");
print ("\t\t###                                              ###\n");
print ("\t\t###           acc2fasta.pl Version 0.1           ###\n");
print ("\t\t###      (more under acc2fasta.pl -help -man)    ###\n");
print ("\t\t###                                              ###\n");
print ("\t\t####################################################\n");
print "\n";
# ============================================================================

# ----------------------------------------------------------------------------
# Finding out the filetype using the last three characters. 
#
# Hint: If one were to implement a new parsing subroutine onw would just write 
# the subroutine, call it in "Calling the parsing subroutines" and allow the 
# filetype in "Sanitising user input" to pass through.
# ----------------------------------------------------------------------------
my $file_type = uc(substr($query_file, -3));
# ============================================================================

# ----------------------------------------------------------------------------
# Calling the parsing subroutines
# ----------------------------------------------------------------------------

print strftime("[%H:%M:%S]",localtime)." - Opening ".$query_file."\n";
if ($file_type eq "TXT"){
	print strftime("[%H:%M:%S]",localtime)." - Parsing ".$file_type." file\n";
	%hash_of_acc = &PARSE_TXT($query_file);
}
elsif ($file_type eq "CSV"){
	if ($list_switch){
		print strftime("[%H:%M:%S]",localtime)." - Parsing ".$file_type." file\n";
		%hash_of_acc = &PARSE_CSV($query_file, $list_file, $list_switch);
	}
	else{
		print strftime("[%H:%M:%S]",localtime)." - Parsing ".$file_type." file\n";
		%hash_of_acc = &PARSE_CSV($query_file);
	}
}
# ============================================================================

# ----------------------------------------------------------------------------
# Print a log file with incidences of each ACC
# ----------------------------------------------------------------------------
print strftime("[%H:%M:%S]",localtime)." - Writing log-file with incidences of ACC to ".$query_file.".log \n";
open (LOG, ">".$query_file.".log") || print " [WARNING] - Could not be write to log file\n";
foreach my $acc (sort keys %hash_of_acc){
	print LOG $acc.",".$hash_of_acc{$acc};
	print LOG "\n";
}
close LOG;
# ============================================================================

# ----------------------------------------------------------------------------
# Fetch FASTA files, sanitation of header and print to file
# ----------------------------------------------------------------------------
if ($list_switch){
	open (OUT, ">".$query_file."_list.fas") || die "   [ERROR] - ".$query_file." could not be opened\n"; 
}
else {
	open (OUT, ">".$query_file.".fas") || die "   [ERROR] - ".$query_file." could not be opened\n"; 
}
foreach my $acc (sort keys %hash_of_acc){
	if ($hash_of_acc{$acc} != 0){
		my $fetch_start=time();
		my $fasta = &FETCH_ACC($acc);
		my @fasta = &SANITISE_DESC($fasta);
		print OUT ">".$acc;
		if ($spaces){
			print OUT " ";
		}
		else {
			print OUT "_";	
		}
		foreach (@fasta){
			print OUT $_."\n";
		} 
		print OUT "\n";
		print "\t [".&TIME_DIFFERENCE($fetch_start)."sec]\n";
	}
}
print strftime("[%H:%M:%S]",localtime)." - Wrote sequences to ".$query_file.".fas\n";
close OUT;
# ============================================================================

# ----------------------------------------------------------------------------
# The end.
# ----------------------------------------------------------------------------
print strftime("[%H:%M:%S]",localtime)." - Done \n";
# ============================================================================


# ============================================================================
# ############################################################################
# ============================================================================

# ============================================================================
# 									SUBROUTINES
# ============================================================================
# ----------------------------------------------------------------------------
# &VALIDATE_ARGS subroutine
# ----------------------------------------------------------------------------
sub VALIDATE_ARGS{
	my @arguments= @{$_[0]};
	my @parameters= @{$_[1]};
	my %parameters;
	my $return;
	foreach my $i (@parameters){
		$parameters{$i}='';

	}
	foreach my $argument (@arguments){
		$argument=lc($argument);
		unless (($argument =~ m/^-/ && defined $parameters{$argument}) || ($argument !~ m/^-/ && &CHECK_FILE($argument)) || ($argument !~ m/^-/ && $argument =~ /^[+-]?\d+$/)){
			return 0;
		}
	}
	return 1;
}
# ----------------------------------------------------------------------------
# &CHECK_FILE subroutine
# ----------------------------------------------------------------------------
sub CHECK_FILE{
	if (-e $_[0]) { #if exists return 1 else die
 		return 1;
 	}
 	else{
 		die "   [ERROR] - ".$_[0]." was not found\n"; 
 	}
} 
# ============================================================================

# ----------------------------------------------------------------------------
# &PARSE_TXT subroutine
# ----------------------------------------------------------------------------
sub PARSE_TXT{
	my %hash;
	open (IN_TXT, $_[0]) || die "   [ERROR] - ".$_[0]." could not be opened\n"; 
	if ($_[1]){
		print strftime("[%H:%M:%S]",localtime)." - Parsing list in ".$_[0]."\n";
		while (my $acc = <IN_TXT>){
		 	chomp($acc);
		 	$acc =~ s/\s*$//g; 
		 	$acc =~ s/\s/_/;
		 	$hash{$acc}=1;
		}
	}
	else{
		while (my $acc = <IN_TXT>){
			chomp ($acc);
			if ($acc =~ m/([A-Z]{1,2}\d{3,7})/){
				if (exists $hash{$1}) {
					$hash{$1}++;
				}
				else {
					$hash{$1} = 1;	
				}
			}
			else{
				print " [WARNING] - ".$acc." is not a valid ACC number\n";
			}
		}
	}
	close IN_TXT;
	return %hash;
}
# ============================================================================

# ----------------------------------------------------------------------------
# &PARSE_CSV subroutine (Filemaker export)
# ----------------------------------------------------------------------------
sub PARSE_CSV{
	my %hash_of_acc;
	my $identifier;
	my %hash_of_identifiers;
	open (IN_CSV, $_[0]) || die "   [ERROR] - ".$_[0]." could not be opened\n"; 
	while (my $line = <IN_CSV>){
		chomp ($line);
		$line =~ s/\s*$//g; 
		$line =~ s/\s/\_/g;									# This is a good way
		my @array= split "\"[,_]\"",$line;					# of parsing CSV files
		foreach my $acc (@array){							# 
			$acc =~ s/\"//g;  								# 
			if ($acc =~ m/([A-Z]{1,2}\d{3,7})/){			#
				push(@{$hash_of_identifiers{$identifier}},$1);
				if (exists $hash_of_acc{$1}) {
					$hash_of_acc{$1}++;
				}
				else {
					$hash_of_acc{$1} = 1;
				}
			}
			else{
				$identifier = $acc;
			}
		}
	}
	
	die "   [ERROR] - Please change the sequence identifiers, they look too much like ACC numbers.\n" if (&USER_HATES_MY_PARSING('CSV',\%hash_of_identifiers));
	
	### Put all ACC in %hash_of_acc to '0', only those ACC belonging to those identifiers listed in %hash_of_list are put to '1'
	if ($_[2]){
		my %hash_of_list= &PARSE_TXT($_[1], $_[2]);
		#initialise the hash with 0 (since occurrences are irrelevant if not from list)
		foreach my $acc_in_hash_of_acc (sort keys %hash_of_acc){
			$hash_of_acc{$acc_in_hash_of_acc}=0;	
		} 
		foreach my $identifier (sort keys %hash_of_identifiers){
			my @acc_of_identifier=@{$hash_of_identifiers{$identifier}};
			if (exists($hash_of_list{$identifier})){
				foreach my $acc_of_identifier (@acc_of_identifier){
					$hash_of_acc{$acc_of_identifier}=1;
				}
			}
		}
		die "   [ERROR] - Please take a look at ".$_[1].".Usual problems involve the end of the lines (spaces, newline-charcters)\n" if (&USER_HATES_MY_PARSING('TXT',\%hash_of_identifiers, \%hash_of_acc));
	}
	close IN_CSV;
	return %hash_of_acc;
}
# ============================================================================

# ----------------------------------------------------------------------------
# &FETCH_ACC subroutine
# ----------------------------------------------------------------------------
sub USER_HATES_MY_PARSING{
	my $parsed_file_type=$_[0];
	my (%parsed_csv, %parsed_txt);
	if ($parsed_file_type eq 'CSV'){
		my $parsed_csv_ref = $_[1];
		%parsed_csv=%$parsed_csv_ref;
		print strftime("[%H:%M:%S]",localtime)." - Printing identifiers and respective ACC numbers.\n";
	}
	elsif($parsed_file_type eq 'TXT'){
		my $parsed_csv_ref = $_[1];
		%parsed_csv=%$parsed_csv_ref;
		my $parsed_txt_ref = $_[2];
		%parsed_txt=%$parsed_txt_ref;
		print strftime("[%H:%M:%S]",localtime)." - Printing identifiers and whether they will be fetched.\n";
	}
	foreach my $parsed_identifier (sort keys %parsed_csv){
		print "[ OUTPUT ] - ";
		print color 'bold';
		print "$parsed_identifier\t";
		if ($parsed_file_type eq 'CSV'){
			print color 'reset';
			print " =>\t[ ";
			foreach my $parsed_acc (@{$parsed_csv{$parsed_identifier}}){
				print color 'white';
				print "$parsed_acc ";
			}
		}
		elsif($parsed_file_type eq 'TXT'){
			print color 'reset';
			print " =>\t[ ";
			foreach my $parsed_acc (@{$parsed_csv{$parsed_identifier}}){
				if ($parsed_txt{$parsed_acc} eq '0'){
					print color 'white';
					print "$parsed_acc ";
					print color 'reset';
				}
				elsif($parsed_txt{$parsed_acc} eq '1'){
					print color 'bold';
					print "$parsed_acc ";
					print color 'reset';
				} 
			}
		}
		print color 'reset';
		print "]\n";
	}	
	print color 'reset';
	print "[QUESTION] - Are you happy with the parsing results? [y,n] : ";
	my $answer_switch=0;
	my $user_parsing_answer;
	while ($answer_switch == 0){
		$user_parsing_answer=<>;
		chomp($user_parsing_answer);
		if ($user_parsing_answer =~ m/^y$|^n$/i){
			$answer_switch=1;
		}	
		else{
			print color 'bold';
			print "[QUESTION] - Are you happy with the parsing results? [y,n] : ";
			print color 'reset';
			}
	}
	if ($user_parsing_answer eq 'n'){
		return 1;
	}
	else{
		return 0;
	}
}


# ----------------------------------------------------------------------------
# &FETCH_ACC subroutine
# ----------------------------------------------------------------------------
sub FETCH_ACC{
	# Building query
	print strftime("[%H:%M:%S]",localtime)." - Fetching ".$_[0];
	my $curl_call="curl --silent \"http://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=nucleotide&id=".$_[0]."&rettype=fasta\"";
	my $fasta=`$curl_call 2>&1`;
	return $fasta;
}
# ----------------------------------------------------------------------------
# ============================================================================

# ----------------------------------------------------------------------------
# &TIME_DIFFERENCE
# ----------------------------------------------------------------------------
sub TIME_DIFFERENCE{
	# curl call
	my $start=$_[0];
	my $end=time();
	my $diff=$end-$start;
	return $diff;
}
# ============================================================================

# ----------------------------------------------------------------------------
# &SANITISE_DESC subroutine
# ----------------------------------------------------------------------------
sub SANITISE_DESC{
	my @fasta 	= split /\n/, $_[0];
	# header
	my $header 	= shift @fasta;
	### deleting gi, acc
	my @header=split('\|', $header);
	shift @header for 1..4;
	$header=join('', map { "$_" } @header);
	### leading whitespace
	$header =~ s/^\s+//;
	$header =~ s/[,.;:=()]//g;
	unless ($spaces){
		$header =~ s/\s/_/g;
	}
	### set string length to $maximum_length_of_header characters unless $full_header_switch=1
	unless ($full_header_switch){
		if (length($header) > $maximum_length_of_header ){
			$header = substr($header, 0, $maximum_length_of_header);
		}
	}
	# sequence
	unshift(@fasta, $header);
	return @fasta;
}
# ============================================================================