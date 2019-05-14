#!/usr/bin/perl
# find it here: https://metacpan.org/pod/Spreadsheet::XLSX
#
($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =  localtime(time);
$now=sprintf("%02d%02d%04d%02d%02d",$mday,($mon+1),($year+1900),$hour,$min);
#
use Spreadsheet::XLSX;
$MYFILE=$ARGV[0];
my $excel = Spreadsheet::XLSX -> new ($MYFILE, $converter);
#
# what comes now is really quick & dirty sorry feel free to improve 
#
#------------------------------------------------------------------
# open the excel and look for the correctly named tabs in the sheet
$PlanningData="Variable Snippets";
$StaticData="Static Snippets";
#-------------------------------------------------------------------
my $PARNAME=();my $PARVALU=();my $PSET=();my @PARAMS=(); my @LINES;
my @SNIPPETLIST=(); my @ENTRY=(); my @STATICENTRY=();
#
foreach $sheet (@{$excel -> {Worksheet}}) {
  $SheetName = $sheet->{Name};
#--------------------------------------------------------------------
# This section stamps the XML SNippets out of a $STAMPFILE
#
# 1) find the worksheet with the parameters first
  if ( $SheetName eq $PlanningData ) {
    printf("Parsing sheet: $SheetName\n");
    $sheet -> {MaxCol} ||= $sheet -> {MinCol};
    $MCsheet = $sheet -> {MaxCol};
    for ( $col=2; $col <= $MCsheet; $col+=2) {
      $sheet -> {MaxRow} ||= $sheet -> {MinRow};
      $cell = $sheet -> {Cells} [1] [$col];
      print "\nChecking column $col of $MCsheet ...";
# 2) if a yes column in the DO-XML line
      if ($cell) {
        $DOXML = $cell -> {Val};
        $DOXML =~ s/[\r\n]//g;
        $DOXML =~ s/^\s+//;
        $DOXML =~ s/\s+$//;
        if ( $DOXML eq "yes" ) {
          print " doing XML!\n";
# 3) read first 2 lines below yes with XML stampfile and X-Path
          $STAMPFILE = $sheet -> {Cells} [2] [$col] -> {Val};
          $STAMPFILE =~ s/[\r\n]//g;
          $STAMPFILE =~ s/^\s+//;
          $STAMPFILE =~ s/\s+$//;
          ($XML,$DU) = $STAMPFILE =~ /(.*)_(.?)/;
          $XMLFILE="$XML.$now.xml";
          $XPATH = $sheet -> {Cells} [3] [$col] -> {Val};
          $XPATH =~ s/[\r\n]//g;
          $XPATH =~ s/^\s+//;
          $XPATH =~ s/\s+$//;
          print "\n XML Template : $STAMPFILE";
          print "\n XPATH        : $XPATH";
          print "\n Outputfile   : $XMLFILE\n" ;
          push (@SNIPPETLIST, $XML);
          $ENTRY{$XML}=$XPATH;
          open (XMLFL,">$XMLFILE")||die "cannot open XML File for output\n";
          XMLFL->autoflush(1);
# 4) now read all lines below as 2 col blocks of parametername - parametervalue
          foreach $row (4 ..  $sheet -> {MaxRow}) {
            $CellNAME = $sheet -> {Cells} [$row] [$col];
            $CellVALU = $sheet -> {Cells} [$row] [$col+1];
            if ( ( $CellNAME ) && ( $CellVALU ) ) {
              $PARNAME = $sheet -> {Cells} [$row] [$col] -> {Val};
              push (@PARAMS, $PARNAME );
              $PARVALU = $sheet -> {Cells} [$row] [$col+1] -> {Val};
              $PSET{$PARNAME}=$PARVALU;
            } else {
#------------------------------------------------------------------------------------
# 5) and flush output blockwise
#
              open(STMPF,"<./$STAMPFILE")||die "cannot open XML Stamp-File for input\n";
#
              @LINES = <STMPF> ; @NEWFILE = ();
                foreach $PAR ( @PARAMS ) {
                    $DUMMY=quotemeta $PAR;
#                    print "$DUMMY \- $PSET{$PAR} \n";
                    foreach $line ( @LINES ) {
                      $line =~ s/$DUMMY/$PSET{$PAR}/g;
                      push ( @NEWFILE, $line)
                    }
                    @LINES = @NEWFILE; @NEWFILE=();
                }
                if ( @PARAMS ) {
                  foreach $modlin ( @LINES) {
                    print XMLFL $modlin ;
                }}
              @LINES=();$PARNAME=();$PARVALU=();@PSET=();
              @PARAMS=();close STMPF;
            }
#-----------------------------------------------------------------------------------------
          }
        }
        close XMLFL;
      }
    }
  }
#------------------------------------------------------------------------------------------
# This section reads the static XML-snippets that will be added at the End
# of the yaml file and without any edit or changes
#
    if ( $SheetName eq $StaticData ) {
      printf("\nParsing sheet: $SheetName\n");
# 6) keep it simple and do not allow freeform in the sheet
#    HENCE "name:" must be column b and three values beside and below are
#    automatically taken to complete the parameter set
      $sheet -> {MaxCol} ||= $sheet -> {MinCol};
      $sheet -> {MaxRow} ||= $sheet -> {MinRow};
      $MCsheet = $sheet -> {MaxCol};
      $RCsheet = $sheet -> {MaxRow};

      for ( $col=1; $col <= $MCsheet ; $col+=1) {
        for ( $row=1; $row <= $RCsheet ; $row+=1 ) {
          $cell = $sheet -> {Cells} [$row] [$col];
          if ($cell) {
            $HIT = $cell -> {Val};
            $HIT =~ s/[\r\n]//g; $HIT =~ s/\s+$//; $HIT =~ s/^\s+//;
            if ( $HIT eq "name:" ) {
              $ncell = $sheet -> {Cells} [$row] [$col+1];
              $pcell = $sheet -> {Cells} [$row+1] [$col+1];
              $fcell = $sheet -> {Cells} [$row+2] [$col+1];
              if ( ( $ncell ) && ( $fcell ) && ( $pcell) ) {
                $NEWENTRY=();
                $XNAME = $ncell -> {Val}; $XNAME =~ s/[\r\n]//g; $XNAME =~ s/\s+$//; $XNAME =~ s/^\s+//;
                $XPATH = $pcell -> {Val}; $XPATH =~ s/[\r\n]//g; $XPATH =~ s/\s+$//; $XPATH =~ s/^\s+//;
                $XFILE = $fcell -> {Val}; $XFILE =~ s/[\r\n]//g; $XFILE =~ s/\s+$//; $XFILE =~ s/^\s+//;
                $NEWENTRY = " - name: $XNAME\n   xpath: $XPATH\n   file: $XFILE\n\n";
                push ( @STATICENTRY, $NEWENTRY);
                $row=$row+2;
              }
            }
          }
        }
      }
    }
}
#--------------------------------------------------------------------
# This section builds the meta-cnc.yaml
#
# 1) Keep this part interactive for now:
  print "\n\n Following parameters are needed for the presentation of your YAML file";
  print "as a PanHandler Skillet collection \n";
  print "\n\n\t Enter a one-word label (will be visible in PanHandler as headline of";
  print "\n\t the box that is representing the Skillet)";
  print "\n\t label [CR]:"; $LABEL=<STDIN>;
    $LABEL =~ s/[\r\n]//g; $LABEL =~ s/^\s+//; $LABEL =~ s/\s+$//;
  print "\n\n\t Enter a description for the label (will be visible in PanHandler";
  print "\n\t as text inside the box that is representing the Skillet)";
  print "\n\t description [CR]:"; $DESCRIPTION=<STDIN>;
    chomp($DESCRIPTION);
  print "\n\n\t Enter a name for the collection (can have blankspace, will be visible in";
  print "\n\t PanHandler as name for the Skillet Collection.) It is not stupid to use ";
  print "\n\t the same name for Skillet Collection and Repository.";
  print "\n\t skillet collection [CR]:"; $COLLECTION=<STDIN>;
    chomp($COLLECTION);
#
# 2) Now Create the meta-cnc.yaml file based on this info
#    All is thrown into the same directory along with the XML files
# ---------------------------------------------------------------------
  $YAMLFILE="./.meta-cnc.yaml";
  open (MCNC,">$YAMLFILE")||die "cannot open meta-cnc File $YAMFILE\n";
  MCNC->autoflush(1);

  print MCNC <<EOYAML
# ---------------------------------------------------------------------
# NOTE: This file has been automatically generated with SkilletStamper
# to get the complete information and doc on what is done here go to
# 'https://github.com/PaloAltoNetworks/panhandler/blob/develop/docs/metadata_configuration.rst'
#
# ---------------------------------------------------------------------
# skillet preamble information used by panhandler
# unique snippet name
name: SkilletStamper_$now
# label used for menu selection
label: $LABEL
description: $DESCRIPTION
type: panos
extends:
labels:
  collection:
    - $COLLECTION
# end of preamble section
# ---------------------------------------------------------------------
# variables section
# SkilletStamper is to avoid exhaustive variables sections and produce hardcoded
# XML snippets instead based on an excel sheet. You can however use variables here
# and edit/change the values in PanHandler as you are used to. Mind, that for this
# case you have to ensure that your variables are inside the XML snippets
variables:
#
# ---------------------------------------------------------------------
# snippets section
# ---------------------------------------------------------------------
# snippets used for api configuration including xpath and element as file name
# files will load in the order listed
snippets:
#
EOYAML
;
  foreach $snip ( @SNIPPETLIST ) {
    print MCNC " - name: $snip\n";
    print MCNC "   xpath: $ENTRY{$snip}\n";
    print MCNC "   file: $snip.$now.xml\n";
    print MCNC "\n";
  }
  $snip=();
  print MCNC "#---------------------------------------------------------------------\n";
  print MCNC "# Static Section from seconf Worksheet (no variables at all)\n";
  print MCNC "#---------------------------------------------------------------------\n";
  foreach $snip ( @STATICENTRY ) {
    print MCNC $snip ;
  }
print "\n";
