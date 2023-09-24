package CsPTools;

# 25.5.2011: adjusted find_code_string to handle new format for 
# CODING strings output by corpussearch

use Exporter;
@ISA = ('Exporter');
@EXPORT_OK = ('request','read_file','get_outdir','r_file_test', 
	      'get_codesfile', 'id_opt_c', 'get_known_codes', 
	      'find_code_string', 'is_known_code', 'determine_code_type', 
	      'get_cspt_version');

my $version = "0.3.1";

# state after putting stuff in from codefinder, late Jan. 05

sub get_cspt_version {
    return $version;
}

##### 
# ha!  this is the way to get to the command-line options of the
# calling script.  duh.  they're just variables in the script's
# package, which should be main, so they should be referable as
# $main::opt_x, with x being the flag letter.  of course, this
# requires the assumption that these functions will only be called by
# packages called main, maybe not such a good idea.  the commented
# part directly below is a way to get at the values that's fully
# flexible, if a bit complicated.  hmm.  have to think about which way
# is preferable.

#    $caller = caller();
#    $ret_val = ${"${caller}::opt_c"};

sub id_opt_c {
    return $main::opt_c;
}

#####
# request subroutine for getting user input 1st arg is string to ask
# for, return value is input, so get it by assigning value of request
# to a variable.

sub request { # $requeststring
    print STDOUT "Please enter $_[0]\n";
    chomp (my $response = <STDIN>);
    $response;
}
#
#####

#####
# subroutine &read_input_file.  this just opens an input file, reads
# its lines into @inputlines, and then passes that back to the calling
# context.

sub read_file {
    my $file = $_[0];
    $file = &r_file_test($file);
    open INPUT, "<$file" || die "Could not open INPUT: $!\n";
    my @lines = <INPUT>;
    close INPUT or warn "Error closing file $file: $!\n";
    return @lines;
}
#
#####

#####
# subroutine &get_outdir.  determines directory for output files.
# this can be called with an argument, potentially containing a
# directory name.  it checks to see if it was given such an argument,
# and if not it queries the user.  either way, it then checks to make
# sure the directory exists and is writeable.  if not, it prompts the
# user for new input.  the point of allowing a directory name
# specified as an argument is to handle things like directories
# specified with command-line flags.  i.e. the code calling this sub
# could be something like:

# $outdir = &get_outdir($opt_d);

# which would mean that this subroutine would in effect check whether
# a directory was specified on the command line, and if not would
# query the user for it.

sub get_outdir {
    my $outdir;
    unless ($outdir = $_[0]) { # check for argument first
	$outdir = &request("output directory"); # get it with request
    }
    until (-d $outdir) {
	print "The directory you named: $outdir, ";
	print "does not exist or is not a directory.\n";
	print "Please enter a new directory, or type q to quit.\n";
	chomp ($outdir = <STDIN>);
	exit if $outdir eq "q";
	until (-w $outdir) {
	    print "The directory you named: $outdir, is not writeable.\n";
	    print "Please enter a new directory, or type q to quit.\n";
	    chomp ($outdir = <STDIN>);
	    exit if $outdir eq "q";
	}
    }
    return $outdir;
}

#####
# file_test subroutine takes two arguments, a potential filename and a
# string describing the file type (e.g. query or input).  it makes
# sure the file exists and is readable, prompting the user for input
# if it is not.  if the potential filename is actually a directory, it
# prints an appropriate response and aborts.  it returns the
# (potentially modified) filename to the calling context.

sub r_file_test { # $filename, $filetype
    my $filename = $_[0];    
    if (-d $filename) { # first make sure it's not a directory name
	print "integratecodes: The $_[1] file you named:\n"; 
	print "\t$filename\nappears to be a directory.\n";  
	die "Did you forget something?\nAborting...\n"; # warn and abort
    }
    until (-r $filename) {  # make sure it exists and is readable
	print "The $_[1] file you name:\n";
	print "\t$filename\ndoes not exist or is not readable.\n";
	print "Please re-enter $_[1] file name, or type \"q\" to quit.\n";
	chomp ($filename = <STDIN>);
	if ($filename eq "q") {
	    exit;                
	}
    }
    $filename;
}
#
#####


#####
# the $dir business in these guys is for flexibility, in particular so
# that the search for a file name codes or whatever can be done in a
# directory specified within the calling script or whatever.  if no
# directory argument is passed in, the current directory is used, and
# there's no harm.

sub get_codesfile {
    my ($codesfile, $dir);
    $dir = "." unless $dir = $_[0];
    if ($codesfile = $main::opt_c) { # is there a -c from calling script?
	if (! -r $codesfile) {  # make sure the file is readable 
	    print "Specified codes file $codesfile does not exist ", 
	    "or is not readable: aborting\n";
	    exit;
	}
    }
    elsif (-r "$dir/codes") { # check for file named codes in current dir
	$codesfile = "$dir/codes";
    }
    else {               # if neither of those works
	$codesfile = ""; # there is no codesfile
    }
    return $codesfile;
}

sub get_known_codes {
    my ($codesfile, $dir);
    $dir = "." unless $dir = $_[0];
    if ($codesfile = &get_codesfile($dir)) {
	open(CODESFILE, "<$codesfile") || die "cannot open $codesfile: $!";
	while (<CODESFILE>) {           # get list of codes and store them
	    chomp;                     # in $incodes (=input codes)
	    push (@codes,$_);        
	}
	close(CODESFILE) or warn "Error closing file $codesfile: $!\n";
	return @codes;
    }
}


sub find_code_string {
    my $code;
    my $line = $_[0];
    if ($line =~ /\(.*? \(.*?CODING.*? (.+?)\)/o) { # changed 25.5.2011
        $code =$1;
	if ($line =~ /^\s*[^\(]+:/) { # added 26.5.2011
	  return 0;
	}
        return $code;
    }
}

sub is_known_code {
    my $code = shift @_;
    my @incodes = @_;
    foreach my $incode (@incodes) { # go through known codes             
        if ($code eq $incode) { # find matches                               
            return "Known"; # skip to next input code                      
        }
    }
    return "";
}

# as of 3.2.2005, codestrings with % anywhere are machine codes, not
# just at the beginning.  this is to allow better handling of
# multicolumn codes.

sub determine_code_type {
    my $code = shift @_;
    my @incodes = @_;
    if ($code =~ /%/) { # codes containing % count as                
        return "Machine";
    }
    elsif ($code =~ /\?/) { # codes containing a ? count as              
        return "Question";
    }
    else { # 2 if the coding string is neither of these, then:                 
        if (@incodes) { # if a list of known codes was supplied       
            if (&is_known_code($code,@incodes)) {
                return "Known";
            }
        }
        return "Unknown";
    }
}
