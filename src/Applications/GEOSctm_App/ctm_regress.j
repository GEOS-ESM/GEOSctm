#!/bin/csh -f

###
###  This script was never converted over for CTM
###  IS IT NEEDED?
###

#######################################################################
#                     Batch Parameters for Regress Job
#######################################################################

#PBS -l walltime=@RUN_T
#@RUN_P
#PBS -N @REGRESS_N
#@RUN_Q
#@BATCH_GROUP

#######################################################################
#                  System Environment Variables
#######################################################################

umask 022

limit stacksize unlimited

@SETENVS

@GPUSTART

#######################################################################
#           Architecture Specific Environment Variables
#######################################################################

setenv ARCH `uname`

setenv SITE             @SITE
setenv GEOSBIN          @GEOSBIN
setenv RUN_CMD         "@RUN_CMD"

source $GEOSBIN/g5_modules
setenv LD_LIBRARY_PATH ${LD_LIBRARY_PATH}:${BASEDIR}/${ARCH}/lib

#######################################################################
#             Experiment Specific Environment Variables
#######################################################################

setenv    EXPID   @EXPID
setenv    EXPDIR  @EXPDIR
setenv    HOMDIR  @HOMDIR
setenv    SCRDIR  $EXPDIR/scratch

#######################################################################
#                 Create Clean Regress Sub-Directory
#######################################################################

mkdir -p                    $EXPDIR/regress
cd                          $EXPDIR/regress
/bin/rm -rf `/bin/ls | grep -v  ctm_regress.j | grep -v slurm`

# Copy RC Files from Home Directory
# ---------------------------------
cd $HOMDIR
    set files = `ls -1 *.rc`
    foreach file ($files)
            set fname = `echo $file | cut -d "." -f1`
           /bin/cp $fname.rc $EXPDIR/regress
    end
cd $EXPDIR/regress

/bin/ln -s $EXPDIR/RC/*.rc  $EXPDIR/regress
/bin/cp $EXPDIR/GEOSctm.x   $EXPDIR/regress
/bin/cp $EXPDIR/linkbcs     $EXPDIR/regress

cat fvcore_layout.rc >> input.nml

if(-e ExtData.rc )    /bin/rm -f   ExtData.rc
set  extdata_files = `/bin/ls -1 *_ExtData.rc`
cat $extdata_files > ExtData.rc 

# Define Atmospheric Resolution
# -----------------------------
set IM = `grep  AGCM_IM: $HOMDIR/AGCM.rc | cut -d':' -f2`
set JM = `grep  AGCM_JM: $HOMDIR/AGCM.rc | cut -d':' -f2`

@    IM6 = 6 * $IM
if( $IM6 == $JM ) then
   set CUBE = TRUE
else
   set CUBE = FALSE
endif

# Create Restart List
# -------------------
set rst_types = `cat AGCM.rc | grep "RESTART_FILE"    | cut -d ":" -f1 | cut -d "_" -f1-2`
set chk_types = `cat AGCM.rc | grep "CHECKPOINT_FILE" | cut -d ":" -f1 | cut -d "_" -f1-2`
set rst_files = `cat AGCM.rc | grep "RESTART_FILE"    | cut -d ":" -f2`
set chk_files = `cat AGCM.rc | grep "CHECKPOINT_FILE" | cut -d ":" -f2`

# Remove possible bootstrap parameters (+/-)
# ------------------------------------------
set dummy = `echo $rst_files`
set rst_files = ''
foreach rst ( $dummy )
  set length  = `echo $rst | awk '{print length($0)}'`
  set    bit  = `echo $rst | cut -c1`
  if(  "$bit" == "+" | \
       "$bit" == "-" ) set rst = `echo $rst | cut -c2-$length`
  set rst_files = `echo $rst_files $rst`
end

# Copy Restarts to Regress directory
# ----------------------------------
foreach rst ( $rst_files )
       /bin/cp $EXPDIR/$rst $EXPDIR/regress
end
/bin/cp $EXPDIR/cap_restart $EXPDIR/regress

#######################################################################
#                 Create Simple History for Efficiency 
#######################################################################

set         FILE = HISTORY.rc0
/bin/rm -f $FILE
cat << _EOF_ > $FILE

EXPID:  ${EXPID}
EXPDSC: ${EXPID}_Regression_Test

COLLECTIONS:
           ::
_EOF_

##################################################################
######
######               Create Regression Test Script
######
##################################################################


# Create Strip Script
# -------------------
set      FILE = strip
/bin/rm $FILE
cat << EOF > $FILE
#!/bin/ksh
/bin/mv \$1 \$1.tmp
touch   \$1
while read line
do
echo \$line >> \$1
done < \$1.tmp
exit
EOF
chmod +x $FILE


# Create Checkpoint File List that is currently EXEMPT from reproducibility test
# -----------------------------------------------------------------------------
set EXEMPT_files = `echo SOLAR_INTERNAL_CHECKPOINT_FILE \
                         SURFACE_IMPORT_CHECKPOINT_FILE `

set EXEMPT_chk = ""
foreach file ( ${EXEMPT_files} )
    set file = `cat AGCM.rc | grep "$file" | cut -d ":" -f2`
    set EXEMPT_chk = `echo ${EXEMPT_chk} $file`
end

# Get Current Date and Time from CAP Restart
# ------------------------------------------
set date = `cat cap_restart`
set nymd0 = $date[1]
set nhms0 = $date[2]

##################################################################
######
######               Perform Regression Test # 1
######                (1-Day Using NX:NY Layout)
######
##################################################################

set test_duration = 240000

/bin/cp     CAP.rc      CAP.rc.orig
/bin/cp    AGCM.rc     AGCM.rc.orig
/bin/cp HISTORY.rc0 HISTORY.rc

set           NX0 = `grep "^ *NX:" AGCM.rc.orig | cut -d':' -f2`
set           NY0 = `grep "^ *NY:" AGCM.rc.orig | cut -d':' -f2`

@ NPES0 = $NX0 * $NY0


./strip CAP.rc
set oldstring =  `cat CAP.rc | grep JOB_SGMT:`
set newstring =  "JOB_SGMT: 00000000 ${test_duration}"
/bin/mv CAP.rc CAP.tmp
cat CAP.tmp | sed -e "s?$oldstring?$newstring?g" > CAP.rc

setenv YEAR `cat cap_restart | cut -c1-4`
./linkbcs
if(! -e tile.bin) $GEOSBIN/binarytile.x tile.data tile.bin

set NX = `grep "^ *NX": AGCM.rc | cut -d':' -f2`
set NY = `grep "^ *NY": AGCM.rc | cut -d':' -f2`
@ NPES = $NX * $NY
$RUN_CMD $NPES ./GEOSctm.x
                                                                                                                      

set date = `cat cap_restart`
set nymde = $date[1]
set nhmse = $date[2]

foreach   chk ( $chk_files )
 /bin/mv $chk  ${chk}.${nymde}_${nhmse}.1
end

##################################################################
######
######               Perform Regression Test # 2
######
##################################################################

set test_duration = 210000

if( $CUBE == TRUE ) then
    @ test_NX = $NPES0 / 6
    @ test_NP = $IM / $test_NX
  if($test_NP < 4 ) then
    @ test_NX = $IM / 4 # To ensure enough gridpoints for HALO
  endif
  set test_NY = 6
else
  set test_NX = $NY0
  set test_NY = $NX0
endif

/bin/rm              cap_restart
echo $nymd0 $nhms0 > cap_restart

/bin/cp     CAP.rc.orig  CAP.rc
/bin/cp    AGCM.rc.orig AGCM.rc
/bin/cp HISTORY.rc0  HISTORY.rc

./strip CAP.rc
set oldstring =  `cat CAP.rc | grep JOB_SGMT:`
set newstring =  "JOB_SGMT: 00000000 ${test_duration}"
/bin/mv CAP.rc CAP.tmp
cat CAP.tmp | sed -e "s?$oldstring?$newstring?g" > CAP.rc

./strip AGCM.rc
set oldstring =  `cat AGCM.rc | grep "^ *NX:"`
set newstring =  "NX: ${test_NX}"
/bin/mv AGCM.rc AGCM.tmp
cat AGCM.tmp | sed -e "s?$oldstring?$newstring?g" > AGCM.rc
set oldstring =  `cat AGCM.rc | grep "^ *NY:"`
set newstring =  "NY: ${test_NY}"
/bin/mv AGCM.rc AGCM.tmp
cat AGCM.tmp | sed -e "s?$oldstring?$newstring?g" > AGCM.rc

setenv YEAR `cat cap_restart | cut -c1-4`
./linkbcs
set NX = `grep "^ *NX": AGCM.rc | cut -d':' -f2`
set NY = `grep "^ *NY": AGCM.rc | cut -d':' -f2`
@ NPES = $NX * $NY
$RUN_CMD $NPES ./GEOSctm.x

foreach rst ( $rst_files )
  /bin/rm -f  $rst
end
set numrst = `echo $rst_types | wc -w`
set numchk = `echo $chk_types | wc -w`

@ n = 1
@ z = $numrst + 1
while ( $n <= $numchk )
       @ m = 1
       while ( $m <= $numrst )
       if(  $chk_types[$n] == $rst_types[$m] || \
          \#$chk_types[$n] == $rst_types[$m] ) then
           /bin/mv $chk_files[$n] $rst_files[$m]
           @ m = $numrst + 999
       else
           @ m = $m + 1
       endif
       end
       if( $m == $z ) then
           echo "Warning!!  Could not find CHECKPOINT/RESTART match for:  " $chk_types[$n]
           exit
       endif
@ n = $n + 1
end

##################################################################
######
######               Perform Regression Test # 3
######
##################################################################

set test_duration = 030000

if( $CUBE == TRUE ) then
  set test_NX = 1
  set test_NY = 6
  set test_Cores = 6
else
  set test_NX = 1
  set test_NY = 2
  set test_Cores = 2
endif

./strip CAP.rc
set oldstring =  `cat CAP.rc | grep JOB_SGMT:`
set newstring =  "JOB_SGMT: 00000000 ${test_duration}"
/bin/mv CAP.rc CAP.tmp
cat CAP.tmp | sed -e "s?$oldstring?$newstring?g" > CAP.rc

./strip AGCM.rc
set oldstring =  `cat AGCM.rc | grep "^ *NX:"`
set newstring =  "NX: ${test_NX}"
/bin/mv AGCM.rc AGCM.tmp
cat AGCM.tmp | sed -e "s?$oldstring?$newstring?g" > AGCM.rc
set oldstring =  `cat AGCM.rc | grep "^ *NY:"`
set newstring =  "NY: ${test_NY}"
/bin/mv AGCM.rc AGCM.tmp
cat AGCM.tmp | sed -e "s?$oldstring?$newstring?g" > AGCM.rc

setenv YEAR `cat cap_restart | cut -c1-4`
./linkbcs
set NX = `grep "^ *NX": AGCM.rc | cut -d':' -f2`
set NY = `grep "^ *NY": AGCM.rc | cut -d':' -f2`
@ NPES = $NX * $NY
$RUN_CMD $NPES ./GEOSctm.x
                                                                                                                      
set date = `cat cap_restart`
set nymde = $date[1]
set nhmse = $date[2]

foreach   chk ( $chk_files )
 /bin/mv $chk  ${chk}.${nymde}_${nhmse}.2
end

#######################################################################
#                          Compare Restarts
#######################################################################

set CDO = `echo ${BASEDIR}/${ARCH}/bin/cdo -Q -s diffn`

if( -e regress_test ) /bin/rm regress_test

set pass = true
foreach chk ( $chk_files )
  set file1 = ${chk}.${nymde}_${nhmse}.1
  set file2 = ${chk}.${nymde}_${nhmse}.2
  if( -e $file1 && -e $file2 ) then
                               set check = true 
      foreach exempt (${EXEMPT_chk})
         if( $chk == $exempt ) set check = false
      end
      if( $check == true ) then
         echo Comparing ${chk}

# compare binary checkpoint files
         cmp $file1 $file2
         if( $status == 0 ) then
             echo Success!
             echo " "
         else
             echo Failed!
             echo " "
             set pass = false
         endif

# compare NetCDF-4 checkpoint files
# 	 set NUMDIFF = `${CDO} $file1 $file2 | awk '{print $1}'`
# 	 if( "$NUMDIFF" == "" ) then
# 	     echo Success!
# 	     echo " "
# 	 else
# 	     echo Failed!
# 	     echo `${CDO} $file1 $file2`
# 	     echo " "
# 	     set pass = false
# 	 endif

      endif
  endif
end

@GPUEND

if( $pass == true ) then
     echo "<font color=green> PASS </font>"                > regress_test
else
     echo "<font color=red> <blink> FAIL </blink> </font>" > regress_test
endif