#!/usr/bin/perl

# scbuildjudge - builds the scjudgepage.conf file using showcase.
# 06/11/10 lms   modified buildjudge.pl of 6/10/10 for Showcase
#
# 02/17/11 lms   note:  haven't really tested with judge_active below....
#                My work on Showcase has been put on hold...
#
# 07/14/11 lms   getting back to work on this...
#                All Select stmts need WITH(NOLOCK).
#				 Use UCN for hash (not LegagcyCaseNumber).
# 08/08/11 lms   getting WG and WP back into the list...

use ICMS;
use Showcase qw (
    $ACTIVE
);
use strict;

dbconnect("showcase-rpt");

# To be clear, showcase CourtType is banner cdbcase_cort_code...
# Was originally getting info from the vJudge table for the same case number,
# but the Active flag wasn't working right (IMHO!)....was using the Active='Y' option..
#
# So, it looks like it's more accurate to do it this way...
#
# (bugbug - i think we're missing divisions WG ad WP - and not sure why... they're there in Showcase as open cases...
#
#  IF I LEAVE OUT and j.Division_Active='Yes' , I GET THE DIVISIONS WG AND WP!
#  (leaving it out, for now!)

my $query = qq {
    select
	c.UCN,
	c.DivisionID,
	c.CourtType,
	j.Judge_LN,
	j.Judge_FN,
	j.Judge_MN
    from
	vCase c,
	vDivision_Judge j with(nolock)
    where
	c.DivisionID=j.DivisionID
	and c.CaseStatus in $ACTIVE
	and c.CourtType != 'ML'
	and j.Judge_Active = 'Yes'
    order by
	c.CaseNumber desc 
};

my %divassign=sqllookup($query);
dbdisconnect();

# temp file
writehash("/usr/local/icms/etc/scjdivassignhash.txt",\%divassign);

my %judgelist;

foreach my $case (sort keys %divassign) {
    my($div,$code,$last,$first,$middle)=split '~',$divassign{$case};
	if($last eq 'BRUSTARES KEYSER') { $last='KEYSER'; $middle='BRUSTARES' };
    if ($code=~/MO|CO|CT/) { $code="MM"; }
    # for our purposes all the MM types treated the same
    if ($judgelist{$div}) {
       if( grep{/$code/} values %judgelist)
       {
          my $i++;
       }
       else
       {
          $judgelist{$div}.=",$code";
       }
    }
    else {
       $judgelist{$div}="$last, $first $middle~$code";
    }
}

# temp file
writehash("/usr/local/icms/etc/scjudgelisthash.txt",\%judgelist);

my @judgeconf;
foreach my $div (sort keys %judgelist) {
    my($name,$casetype)=split '~',$judgelist{$div};
    push @judgeconf,"$name~$div~$casetype\n";
}

#force the new mental health division CFMH into file
push @judgeconf,"MARX, JUDGE KRISTA ~CFMH~CF\n";

#force the unified family court divisions UFCL, UFCT, UFJM
push @judgeconf,"Unified Family Court ~UFCL~DR\n";
push @judgeconf,"Unified Family Court ~UFCT~DR\n";
push @judgeconf,"Unified Family Court ~UFJM~DR\n";


@judgeconf=sort(@judgeconf);
open OUTFILE,">/usr/local/icms/etc/scjudgepage.conf";
print OUTFILE @judgeconf;
close OUTFILE;
