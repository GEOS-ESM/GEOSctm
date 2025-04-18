#!/bin/csh -f

#######################################################################
#                     Batch Parameters for Run Job
#######################################################################

#@BATCH_TIME@RUN_T
#@RUN_P
#@BATCH_JOBNAME@RUN_N
#@RUN_Q
#@BATCH_GROUP
#@BATCH_JOINOUTERR
#@BATCH_NAME -o ctm_run.o@RSTDATE

#######################################################################
#                         System Settings
#######################################################################

umask 022

limit stacksize unlimited


#######################################################################
#                CTM-specific Configuration Settings
#######################################################################

setenv doIdealizedPT @doIdealizedPT
setenv doGEOSCHEMCHEM @doGEOSCHEMCHEM

#######################################################################
#           Architecture Specific Environment Variables
#######################################################################

setenv ARCH `uname`

setenv SITE             @SITE
setenv GEOSDIR          @GEOSDIR
setenv GEOSBIN          @GEOSBIN
setenv GEOSETC          @GEOSETC
setenv GEOSUTIL         @GEOSSRC

source $GEOSBIN/g5_modules
setenv @LD_LIBRARY_PATH_CMD ${LD_LIBRARY_PATH}:${GEOSDIR}/lib
# We only add BASEDIR to the @LD_LIBRARY_PATH_CMD if BASEDIR is defined (i.e., not running with Spack)
if ( $?BASEDIR ) then
    setenv @LD_LIBRARY_PATH_CMD ${@LD_LIBRARY_PATH_CMD}:${BASEDIR}/${ARCH}/lib
endif

setenv RUN_CMD "@RUN_CMD"

setenv CTMVER   @CTMVER
echo   VERSION: $CTMVER

#######################################################################
#             Experiment Specific Environment Variables
#######################################################################


setenv  EXPID   @EXPID
setenv  EXPDIR  @EXPDIR
setenv  HOMDIR  @HOMDIR

setenv  RSTDATE @RSTDATE
setenv  GCMEMIP FALSE

#######################################################################
#                 Create Experiment Sub-Directories
#######################################################################

if (! -e $EXPDIR/restarts   ) mkdir -p $EXPDIR/restarts
if (! -e $EXPDIR/holding    ) mkdir -p $EXPDIR/holding
if (! -e $EXPDIR/archive    ) mkdir -p $EXPDIR/archive
if (! -e $EXPDIR/post       ) mkdir -p $EXPDIR/post
if (! -e $EXPDIR/plot       ) mkdir -p $EXPDIR/plot

if( $GCMEMIP == TRUE ) then
    if (! -e $EXPDIR/restarts/$RSTDATE ) mkdir -p $EXPDIR/restarts/$RSTDATE
    setenv  SCRDIR  $EXPDIR/scratch.$RSTDATE
else
    setenv  SCRDIR  $EXPDIR/scratch
endif

if (! -e $SCRDIR ) mkdir -p $SCRDIR

#######################################################################
#                   Set Experiment Run Parameters
#######################################################################

set         NX = `grep    "^ *NX:" $HOMDIR/GEOSCTM.rc | cut -d':' -f2`
set         NY = `grep    "^ *NY:" $HOMDIR/GEOSCTM.rc | cut -d':' -f2`
set GEOSCTM_IM = `grep GEOSctm_IM: $HOMDIR/GEOSCTM.rc | cut -d':' -f2`
set GEOSCTM_JM = `grep GEOSctm_JM: $HOMDIR/GEOSCTM.rc | cut -d':' -f2`
set GEOSCTM_LM = `grep GEOSctm_LM: $HOMDIR/GEOSCTM.rc | cut -d':' -f2`
set    OGCM_IM = `grep    OGCM_IM: $HOMDIR/GEOSCTM.rc | cut -d':' -f2`
set    OGCM_JM = `grep    OGCM_JM: $HOMDIR/GEOSCTM.rc | cut -d':' -f2`

# Calculate number of cores/nodes for IOSERVER
# --------------------------------------------

set USE_IOSERVER      = @USE_IOSERVER
set NUM_OSERVER_NODES = `grep '^\s*IOSERVER_NODES:'  $HOMDIR/GEOSCTM.rc | cut -d: -f2`
set NUM_BACKEND_PES   = `grep '^\s*NUM_BACKEND_PES:' $HOMDIR/GEOSCTM.rc | cut -d: -f2`

# Check for Over-Specification of CPU Resources
# ---------------------------------------------
if ($?SLURM_NTASKS) then
   set  NCPUS = $SLURM_NTASKS
else if ($?PBS_NODEFILE) then
   set  NCPUS = `cat $PBS_NODEFILE | wc -l`
else
   set  NCPUS = NULL
endif

@ MODEL_NPES = $NX * $NY

set NCPUS_PER_NODE = @NCPUS_PER_NODE
set NUM_MODEL_NODES=`echo "scale=6;($MODEL_NPES / $NCPUS_PER_NODE)" | bc | awk 'function ceil(x, y){y=int(x); return(x>y?y+1:y)} {print ceil($1)}'`

if ( $NCPUS != NULL ) then

   if ( $USE_IOSERVER == 1 ) then

      @ TOTAL_NODES = $NUM_MODEL_NODES + $NUM_OSERVER_NODES
      @ TOTAL_PES = $TOTAL_NODES * $NCPUS_PER_NODE

      if( $TOTAL_PES > $NCPUS ) then
         echo "CPU Resources are Over-Specified"
         echo "--------------------------------"
         echo "Allotted  NCPUs: $NCPUS"
         echo "Requested NCPUs: $TOTAL_PES"
         echo ""
         echo "Specified NX: $NX"
         echo "Specified NY: $NY"
         echo ""
         echo "Specified model nodes: $NUM_MODEL_NODES"
         echo "Specified oserver nodes: $NUM_OSERVER_NODES"
         echo "Specified cores per node: $NCPUS_PER_NODE"
         exit
      endif

   else

      @ TOTAL_PES = $MODEL_NPES

      if( $TOTAL_PES > $NCPUS ) then
         echo "CPU Resources are Over-Specified"
         echo "--------------------------------"
         echo "Allotted  NCPUs: $NCPUS"
         echo "Requested NCPUs: $TOTAL_PES"
         echo ""
         echo "Specified NX: $NX"
         echo "Specified NY: $NY"
         echo ""
         echo "Specified model nodes: $NUM_MODEL_NODES"
         echo "Specified cores per node: $NCPUS_PER_NODE"
         exit
      endif

   endif

else
   # This is for the desktop path

   @ TOTAL_PES = $MODEL_NPES

endif

goto SKIP_EMIP
#######################################################################
#                       GCMEMIP Setup
#######################################################################

if( $GCMEMIP == TRUE & ! -e $EXPDIR/restarts/$RSTDATE/cap_restart ) then

cd $EXPDIR/restarts/$RSTDATE

cp $HOMDIR/CAP.rc CAP.rc.orig
awk '{$1=$1};1' < CAP.rc.orig > CAP.rc

set year  = `echo $RSTDATE | cut -d_ -f1 | cut -b1-4`
set month = `echo $RSTDATE | cut -d_ -f1 | cut -b5-6`

@EMIP_OLDLAND# Copy MERRA-2 Restarts
@EMIP_OLDLAND# ---------------------
@EMIP_NEWLAND# Copy Jason-3_4 REPLAY MERRA-2 NewLand Restarts
@EMIP_NEWLAND# ----------------------------------------------
cp /discover/nobackup/projects/gmao/g6dev/ltakacs/@EMIP_MERRA2/restarts/AMIP/M${month}/restarts.${year}${month}.tar .
tar xf  restarts.${year}${month}.tar
/bin/rm restarts.${year}${month}.tar
@EMIP_OLDLAND/bin/rm MERRA2*bin


@EMIP_OLDLAND# Regrid MERRA-2 Restarts
@EMIP_OLDLAND# -----------------------
@EMIP_NEWLAND# Regrid Jason-3_4 REPLAY MERRA-2 NewLand Restarts
@EMIP_NEWLAND# ------------------------------------------------
set RSTID = `/bin/ls *catch* | cut -d. -f1`
set day   = `/bin/ls *catch* | cut -d. -f3 | awk 'match($0,/[0-9]{8}/) {print substr($0,RSTART+6,2)}'`
$GEOSBIN/remap_restarts.py command_line -np -ymdh ${year}${month}${day}21 -grout C${AGCM_IM} -levsout ${AGCM_LM} -out_dir . -rst_dir . -expid $RSTID -bcvin @EMIP_BCS_IN -oceanin 1440x720 -nobkg -lbl -nolcv -bcvout @LSMBCS -rs 3 -oceanout @OCEANOUT -in_bc_base @BC_BASE -out_bc_base @BC_BASE
@EMIP_OLDLAND/bin/rm $RSTID.*.bin

     set IMC = $AGCM_IM
if(     $IMC < 10 ) then
     set IMC = 000$IMC
else if($IMC < 100) then
     set IMC = 00$IMC
else if($IMC < 1000) then
     set IMC = 0$IMC
endif

set  chk_type = `/usr/bin/file -Lb --mime-type C${AGCM_IM}[cef]_${RSTID}.*catch*`
if( "$chk_type" =~ "application/octet-stream" ) set ext = bin
if( "$chk_type" =~ "application/x-hdf"        ) set ext = nc4

$GEOSBIN/stripname C${AGCM_IM}@OCEANOUT_${RSTID}.
$GEOSBIN/stripname .${year}${month}${day}_21z.$ext.@LSMBCS.@ATMOStag_@OCEANtag
@EMIP_OLDLAND/bin/mv gocart_internal_rst gocart_internal_rst.merra2
@EMIP_OLDLAND$GEOSBIN/gogo.x -s $RSTID.Chem_Registry.rc.${year}${month}${day}_21z -t $EXPDIR/RC/Chem_Registry.rc -i gocart_internal_rst.merra2 -o gocart_internal_rst -r C${AGCM_IM} -l ${AGCM_LM}


# Create CAP.rc and cap_restart
# -----------------------------
set   nymd = ${year}${month}${day}
set   nhms = 210000
echo $nymd $nhms > cap_restart

set curmonth = $month
      @ count = 0
while( $count < 4 )
       set date  = `$GEOSBIN/tick $nymd $nhms 86400`
       set nymd  =  $date[1]
       set nhms  =  $date[2]
       set year  = `echo $nymd | cut -c1-4`
       set month = `echo $nymd | cut -c5-6`
       if( $curmonth != $month ) then
        set curmonth  = $month
             @ count  = $count + 1
       endif
end
set oldstring =  `grep '^\s*END_DATE:' CAP.rc`
set newstring =  "END_DATE: ${year}${month}01 210000"
/bin/mv CAP.rc CAP.tmp
cat CAP.tmp | sed -e "s?$oldstring?$newstring?g" > CAP.rc
/bin/rm CAP.tmp

endif
SKIP_EMIP:

set GIGATRAJ  = `grep '^\s*GIGATRAJ_PARCELS_FILE:'     GEOSCTM.rc | cut -d: -f2`

#######################################################################
#   Move to Scratch Directory and Copy RC Files from Home Directory
#######################################################################

cd $SCRDIR
/bin/rm -rf *
cp -f  $EXPDIR/RC/* .
cp     $EXPDIR/cap_restart .
cp     $EXPDIR/linkbcs .
if ($GIGATRAJ != "") then
   cp   $EXPDIR/$GIGATRAJ .
endif
cp -f  $HOMDIR/*.rc .
cp -f  $HOMDIR/*.nml .
cp -f  $HOMDIR/*.yaml .
cp -f  $HOMDIR/*.tmpl .
cp     $GEOSBIN/bundleParser.py .

cp -f  $HOMDIR/RC.ww3/mod_def.* .
cp -f  $HOMDIR/RC.ww3/ww3*.nml .

cat fvcore_layout.rc >> input.nml
if (-z input.nml) then
   echo "try cat for input.nml again"
   cat fvcore_layout.rc >> input.nml
endif
if (-z input.nml) then
   echo "input.nml is zero-length"
   exit 0
endif

#######################################################################
# Until GOCART2G stops referring to AGCM.rc :
#######################################################################
ln -s GEOSCTM.rc AGCM.rc

#######################################################################
# Until ChemEnv accounts for Imports that CTM does not have :
#######################################################################

### rc
set NULL_CAPE  = "CAPE             '1'            N   Y   -                        none    none  UNUSED            /dev/null"
set NULL_INHB  = "INHB             '1'            N   Y   -                        none    none  UNUSED            /dev/null"
set NULL_ZLFC  = "ZLFC             '1'            N   Y   -                        none    none  UNUSED            /dev/null"

# Add the lines to this file, after the line that includes 'MCOR'
set file = ChemEnv_ExtData.rc

/bin/mv $file TempFile
cat           TempFile | sed -e "/MCOR/a $NULL_CAPE" > $file
/bin/mv $file TempFile
cat           TempFile | sed -e "/MCOR/a $NULL_INHB" > $file
/bin/mv $file TempFile
cat           TempFile | sed -e "/MCOR/a $NULL_ZLFC" > $file
/bin/rm TempFile

### yaml
set NULL_CAPE  = "\ \ CAPE:"
set NULL_INHB  = "\ \ INHB:"
set NULL_ZLFC  = "\ \ ZLFC:"
set NULL_NULL  = "\ \ \ \ collection: /dev/null"

# Add the lines to this file, after the line that includes 'Exports'
set file = ChemEnv_ExtData.yaml

/bin/mv $file TempFile
cat           TempFile | sed -e "/Exports/a $NULL_NULL" > $file
/bin/mv $file TempFile
cat           TempFile | sed -e "/Exports/a $NULL_CAPE" > $file
/bin/mv $file TempFile
cat           TempFile | sed -e "/Exports/a $NULL_NULL" > $file
/bin/mv $file TempFile
cat           TempFile | sed -e "/Exports/a $NULL_INHB" > $file
/bin/mv $file TempFile
cat           TempFile | sed -e "/Exports/a $NULL_NULL" > $file
/bin/mv $file TempFile
cat           TempFile | sed -e "/Exports/a $NULL_ZLFC" > $file
/bin/rm TempFile

#######################################################################
# Until GMI accounts for Imports that CTM does not have :
#######################################################################

### rc
set NULL_RI    = "RI               '1'            N   Y   -                        none    none  UNUSED            /dev/null"
set NULL_RL    = "RL               '1'            N   Y   -                        none    none  UNUSED            /dev/null"

# Add the lines to this file, after the line that includes 'ACET_FIXED'
set file = GMI_ExtData.rc

/bin/mv $file TempFile
cat           TempFile | sed -e "/ACET_FIXED/a $NULL_RI" > $file
/bin/mv $file TempFile
cat           TempFile | sed -e "/ACET_FIXED/a $NULL_RL" > $file
/bin/rm TempFile

### yaml
set NULL_RI    = "\ \ RI: { collection: /dev/null }"
set NULL_RL    = "\ \ RL: { collection: /dev/null }"

# Add the lines to this file, after the line that includes 'Exports'
set file = GMI_ExtData.yaml

/bin/mv $file TempFile
cat           TempFile | sed -e "/Exports/a $NULL_RI"   > $file
/bin/mv $file TempFile
cat           TempFile | sed -e "/Exports/a $NULL_RL"   > $file
/bin/rm TempFile

# Driving datasets
setenv DRIVING_DATASETS @DRIVING_DATASETS

if ( ${DRIVING_DATASETS} == F515_516 || ${DRIVING_DATASETS} == F5131 ) then
                             /bin/cp     $EXPDIR/FP_ExtData.rc.tmpl .
else
                             /bin/cp     $EXPDIR/${DRIVING_DATASETS}_ExtData.rc.tmpl .
endif

if( $GCMEMIP == TRUE ) then
    cp -f  $EXPDIR/restarts/$RSTDATE/cap_restart .
    cp -f  $EXPDIR/restarts/$RSTDATE/CAP.rc .
endif

set END_DATE  = `grep '^\s*END_DATE:'     CAP.rc | cut -d: -f2`
set NUM_SGMT  = `grep '^\s*NUM_SGMT:'     CAP.rc | cut -d: -f2`
set FSEGMENT  = `grep '^\s*FCST_SEGMENT:' CAP.rc | cut -d: -f2`
set USE_SHMEM = `grep '^\s*USE_SHMEM:'    CAP.rc | cut -d: -f2`

#######################################################################
#                  Rename GEOS-Chem RC files
#######################################################################

if( ${doGEOSCHEMCHEM} == YES) then

  set GEOSCHEM_RCS = ( brc.dat chemga.dat dust.dat FJX_j2j.dat FJX_spec.dat h2so4.dat jv_spec_mie.dat org.dat so4.dat soot.dat ssa.dat ssc.dat input.geos )
  foreach FILE ( ${GEOSCHEM_RCS} )
    /bin/mv ${FILE}.rc ${FILE}
  end

endif

#######################################################################
#              Create HISTORY Collection Directories
#######################################################################

set collections = ''
foreach line ("`cat HISTORY.rc`")
   set firstword  = `echo $line | awk '{print $1}'`
   set firstchar  = `echo $firstword | cut -c1`
   set secondword = `echo $line | awk '{print $2}'`

   if ( $firstword == "::" ) goto done

   if ( $firstchar != "#" ) then
      set collection  = `echo $firstword | sed -e "s/'//g"`
      set collections = `echo $collections $collection`
      if ( $secondword == :: ) goto done
   endif

   if ( $firstword == COLLECTIONS: ) then
      set collections = `echo $secondword | sed -e "s/'//g"`
   endif
end

done:
   foreach collection ( $collections )
      if (! -e $EXPDIR/$collection )         mkdir $EXPDIR/$collection
      if (! -e $EXPDIR/holding/$collection ) mkdir $EXPDIR/holding/$collection
   end

#######################################################################
#                        Link Boundary Datasets
#######################################################################
setenv BCSDIR    @BCSDIR

#this is hard-wired for NAS for now - should make it more general
setenv BCTAG `basename $BCSDIR`
setenv EMISSIONS @EMISSIONS
chmod +x linkbcs

#######################################################################
#                  Setup executable
#######################################################################


 echo "Copying $EXPDIR/GEOSctm.x to $SCRDIR"
 echo ""
 /bin/cp $EXPDIR/GEOSctm.x $SCRDIR/GEOSctm.x
 setenv CTMEXE $SCRDIR/GEOSctm.x

#######################################################################
#                         Get RESTARTS
#######################################################################

set rst_files      = `grep "RESTART_FILE"    GEOSCTM.rc | grep -v VEGDYN | grep -v "#" | cut -d ":" -f1 | cut -d "_" -f1-2`
set rst_file_names = `grep "RESTART_FILE"    GEOSCTM.rc | grep -v VEGDYN | grep -v "#" | cut -d ":" -f2`

set chk_files      = `grep "CHECKPOINT_FILE" GEOSCTM.rc | grep -v "#" | cut -d ":" -f1 | cut -d "_" -f1-2`
set chk_file_names = `grep "CHECKPOINT_FILE" GEOSCTM.rc | grep -v "#" | cut -d ":" -f2`

set monthly_chk_names = `cat $EXPDIR/HISTORY.rc | grep -v '^[\t ]*#' | sed -n 's/\([^\t ]\+\).monthly:[\t ]*1.*/\1/p' | sed 's/$/_rst/' `

set tile_rsts = (catch catchcn route lake landice openwater saltwater seaicethermo)

# check if it resarts by face
# ----------------------------------
set rst_by_face = NO
if( $GCMEMIP == TRUE ) then
   if(-e $EXPDIR/restarts/$RSTDATE/fvcore_internal_rst & -e $EXPDIR/restarts/$RSTDATE/fvcore_internal_face_1_rst) then
     echo "grid-based internal_rst and internal_face_x_rst should not co-exist"
     echo "please remove all *internal_rst except these tile-based restarts :"
     foreach rst ( $tile_rsts )
        echo ${rst}_internal_rst
     end
     exit
   endif
   if(-e $EXPDIR/restarts/$RSTDATE/fvcore_internal_face_1_rst) then
     set rst_by_face = YES
   endif
else
   if(-e $EXPDIR/fvcore_internal_rst & -e $EXPDIR/fvcore_internal_face_1_rst) then
     echo "grid-based internal_rst and internal_face_x_rst should not co-exist"
     echo "please remove all *internal_rst except these tile-based restarts :"
     foreach rst ( $tile_rsts )
        echo ${rst}_internal_rst
     end
     exit
   endif
   if(-e $EXPDIR/fvcore_internal_face_1_rst) then
     set rst_by_face = YES
   endif
endif

set Rbyface = `grep READ_RESTART_BY_FACE: GEOSCTM.rc | grep -v "#" |  cut -d ":" -f2`
if ($rst_by_face == NO) then
  if ($Rbyface == YES)  then
     sed -i '/READ_RESTART_BY_FACE:/c\READ_RESTART_BY_FACE: NO' GEOSCTM.rc
  endif
else
  # make sure num_readers is multiple of 6
  @ num_readers = `grep NUM_READERS: GEOSCTM.rc | grep -v "#" |  cut -d ":" -f2`
  @ remainer = $num_readers % 6
  if ($remainer != 0) then
     sed -i '/NUM_READERS:/c\NUM_READERS: 6' GEOSCTM.rc
  endif

  if ($Rbyface != YES)  then
     sed -i '/READ_RESTART_BY_FACE:/c\READ_RESTART_BY_FACE: YES' GEOSCTM.rc
  endif
endif

set Wbyface = `grep WRITE_RESTART_BY_FACE: GEOSCTM.rc | grep -v "#" |  cut -d ":" -f2`
if ($Wbyface == YES)  then
  # make sure num_readers is multiple of 6
  @ num_writers = `grep NUM_WRITERS: GEOSCTM.rc | grep -v "#" |  cut -d ":" -f2`
  @ remainer = $num_writers % 6
  if ($remainer != 0) then
     sed -i '/NUM_WRITERS:/c\NUM_WRITERS: 6' GEOSCTM.rc
  endif
endif
# Remove possible bootstrap parameters (+/-)
# ------------------------------------------
set dummy = `echo $rst_file_names`
set rst_file_names = ''
foreach rst ( $dummy )
  set length  = `echo $rst | awk '{print length($0)}'`
  set    bit  = `echo $rst | cut -c1`
  if(  "$bit" == "+" | \
       "$bit" == "-" ) set rst = `echo $rst | cut -c2-$length`
  set is_tile_rst = FALSE
  if ($rst_by_face == YES) then
     foreach tile_rst ($tile_rsts)
       if ( $rst =~ *$tile_rst* ) then
         set is_tile_rst = TRUE
         break
       endif
     end
  endif
  if ($is_tile_rst == FALSE & $rst_by_face == YES) then
    set part1 = `echo $rst:q | sed 's/_rst/ /g'`
      foreach n (1 2 3 4 5 6)
         set rst = ${part1}_face_${n}_rst
         set rst_file_names = `echo $rst_file_names $rst`
      end
  else
    set rst_file_names = `echo $rst_file_names $rst`
  endif
end

# WGCM runtime parameters
# -----------------------
set USE_WAVES = `grep '^\s*USE_WAVES:' GEOSCTM.rc| cut -d: -f2`
set wavemodel = `cat WGCM.rc | grep "wave_model:" | cut -d "#" -f1 | cut -d ":" -f 2 | sed 's/\s//g'`
if ( $USE_WAVES != 0 && $wavemodel == "WW3" ) then
  set wavewatch = 1
else
  set wavewatch = 0
endif
echo WAVE MODEL info: wavewatch is $wavewatch

# Copy Restarts to Scratch Directory
# ----------------------------------
if( $GCMEMIP == TRUE ) then
    foreach rst ( $rst_file_names $monthly_chk_names )
      if(-e $EXPDIR/restarts/$RSTDATE/$rst ) cp $EXPDIR/restarts/$RSTDATE/$rst . &
    end
else
    foreach rst ( $rst_file_names $monthly_chk_names )
      if(-e $EXPDIR/$rst ) cp $EXPDIR/$rst . &
    end

    # WW3 restart file
    if( $wavewatch ) then
        set rst_ww3 = "restart.ww3"
        if(-e $EXPDIR/${rst_ww3} ) /bin/cp $EXPDIR/${rst_ww3} . &
    endif
endif
wait

# Get proper ridge scheme GWD internal restart
# --------------------------------------------
if ( $rst_by_face == YES ) then
  echo "WARNING: The generated gwd_internal_face_x_rst are used"
  #foreach n (1 2 3 4 5 6)
    #/bin/rm gwd_internal_face_${n}_rst
    #/bin/cp @GWDRSDIR/gwd_internal_c${GEOSCTM_IM}_face_${n} gwd_internal_face_${n}_rst
  #end
else
# /bin/rm gwd_internal_rst
# /bin/cp @GWDRSDIR/gwd_internal_c${GEOSCTM_IM} gwd_internal_rst
endif

# Copy and Tar Initial Restarts to Restarts Directory
# ---------------------------------------------------
set edate = e`cat cap_restart | cut -c1-8`_`cat cap_restart | cut -c10-11`z
set numrs = `/bin/ls -1 ${EXPDIR}/restarts/*${edate}* | wc -l`
if($numrs == 0) then
   foreach rst ( $rst_file_names )
      if( -e $rst & ! -e ${EXPDIR}/restarts/$EXPID.${rst}.${edate}.${CTMVER} ) then
            /bin/cp $rst ${EXPDIR}/restarts/$EXPID.${rst}.${edate}.${CTMVER} &
      endif
   end
   wait
   # WW3 restart file
   if( $wavewatch ) then
       set rst_ww3 = "restart.ww3"
       if( -e ${rst_ww3} ) cp ${rst_ww3}  ${EXPDIR}/restarts/$EXPID.${rst_ww3}.${edate}.${GCMVER}.${BCTAG}_${BCRSLV}
   endif
   cd $EXPDIR/restarts
      tar cf  restarts.${edate}.tar $EXPID.*.${edate}.${CTMVER}
     /bin/rm -rf `/bin/ls -d -1     $EXPID.*.${edate}.${CTMVER}`
   cd $SCRDIR
endif

# If any restart is binary, set NUM_READERS to 1 so that
# +-style bootstrapping of missing files can occur in
# MAPL. pbinary cannot do this, but pnc4 can.
# ------------------------------------------------------
set found_binary = 0

foreach rst ( $rst_file_names )
   if (-e $rst) then
      set rst_type = `/usr/bin/file -Lb --mime-type $rst`
      if ( $rst_type =~ "application/octet-stream" ) then
         set found_binary = 1
      endif
   endif
end

if ($found_binary == 1) then
   /bin/mv GEOSCTM.rc GEOSCTM.tmp
   cat GEOSCTM.tmp | sed -e "/^NUM_READERS/ s/\([0-9]\+\)/1/g" > GEOSCTM.rc
   /bin/rm GEOSCTM.tmp
endif


##################################################################
######
######         Perform multiple iterations of Model Run
######
##################################################################

@ counter    = 1
while ( $counter <= ${NUM_SGMT} )

/bin/rm -f  EGRESS

if( $GCMEMIP == TRUE ) then
    cp -f  $EXPDIR/restarts/$RSTDATE/CAP.rc .
else
    cp -f $HOMDIR/CAP.rc .
endif

/bin/mv CAP.rc CAP.rc.orig
awk '{$1=$1};1' < CAP.rc.orig > CAP.rc

# Set Time Variables for Current_(c), Ending_(e), and Segment_(s) dates
# ---------------------------------------------------------------------
set nymdc = `awk '{print $1}' cap_restart`
set nhmsc = `awk '{print $2}' cap_restart`
set nymde = `grep '^\s*END_DATE:' CAP.rc | cut -d: -f2 | awk '{print $1}'`
set nhmse = `grep '^\s*END_DATE:' CAP.rc | cut -d: -f2 | awk '{print $2}'`
set nymds = `grep '^\s*JOB_SGMT:' CAP.rc | cut -d: -f2 | awk '{print $1}'`
set nhmss = `grep '^\s*JOB_SGMT:' CAP.rc | cut -d: -f2 | awk '{print $2}'`

# Compute Time Variables at the Finish_(f) of current segment
# -----------------------------------------------------------
set nyear   = `echo $nymds | cut -c1-4`
set nmonth  = `echo $nymds | cut -c5-6`
set nday    = `echo $nymds | cut -c7-8`
set nhour   = `echo $nhmss | cut -c1-2`
set nminute = `echo $nhmss | cut -c3-4`
set nsec    = `echo $nhmss | cut -c5-6`
       @ dt = $nsec + 60 * $nminute + 3600 * $nhour + 86400 * $nday

set nymdf = $nymdc
set nhmsf = $nhmsc
set date  = `$GEOSBIN/tick $nymdf $nhmsf $dt`
set nymdf =  $date[1]
set nhmsf =  $date[2]
set year  = `echo $nymdf | cut -c1-4`
set month = `echo $nymdf | cut -c5-6`
set day   = `echo $nymdf | cut -c7-8`

     @  month = $month + $nmonth
while( $month > 12 )
     @  month = $month - 12
     @  year  = $year  + 1
end
     @  year  = $year  + $nyear
     @ nymdf  = $year * 10000 + $month * 100 + $day

if( $nymdf >  $nymde )    set nymdf = $nymde
if( $nymdf == $nymde )    then
    if( $nhmsf > $nhmse ) set nhmsf = $nhmse
endif

set yearc = `echo $nymdc | cut -c1-4`
set yearf = `echo $nymdf | cut -c1-4`

# For Non-Reynolds SST, Modify local CAP.rc Ending date if Finish time exceeds Current year boundary
# --------------------------------------------------------------------------------------------------
if( @OCEANtag != DE0360xPE0180 ) then
    if( $yearf > $yearc ) then
       @ yearf = $yearc + 1
       @ nymdf = $yearf * 10000 + 0101
        set oldstring = `grep '^\s*END_DATE:' CAP.rc`
        set newstring = "END_DATE: $nymdf $nhmsf"
        /bin/mv CAP.rc CAP.tmp
        cat CAP.tmp | sed -e "s?$oldstring?$newstring?g" > CAP.rc
    endif
endif

# Which ExtData are we using
set  EXTDATA2G_TRUE = `grep -i '^\s*USE_EXTDATA2G:\s*\.TRUE\.'    CAP.rc | wc -l`

# Select proper AMIP GOCART Emission RC Files
# -------------------------------------------
if( ${EMISSIONS} == AMIP_EMISSIONS ) then
    if( $EXTDATA2G_TRUE == 0 ) then
       set AMIP_Transition_Date = 20000301

       # Before 2000-03-01, we need to use AMIP.20C which has different
       # emissions (HFED instead of QFED) valid before 2000-03-01. Note
       # that if you make a change to anything in $EXPDIR/RC/AMIP or
       # $EXPDIR/RC/AMIP.20C, you might need to make a change in the other
       # directory to be consistent. Some files in AMIP.20C are symlinks to
       # that in AMIP but others are not.

       if( $nymdc < ${AMIP_Transition_Date} ) then
            set AMIP_EMISSIONS_DIRECTORY = $EXPDIR/RC/AMIP.20C
            if( $nymdf > ${AMIP_Transition_Date} ) then
             set nymdf = ${AMIP_Transition_Date}
             set oldstring = `grep '^\s*END_DATE:' CAP.rc`
             set newstring = "END_DATE: $nymdf $nhmsf"
             /bin/mv CAP.rc CAP.tmp
                        cat CAP.tmp | sed -e "s?$oldstring?$newstring?g" > CAP.rc
            endif
       else
            set AMIP_EMISSIONS_DIRECTORY = $EXPDIR/RC/AMIP
       endif
    else
       set AMIP_EMISSIONS_DIRECTORY = $EXPDIR/RC/AMIP
    endif

    if( $GEOSCTM_LM == 72 ) then
        cp ${AMIP_EMISSIONS_DIRECTORY}/*.rc .
        cp ${AMIP_EMISSIONS_DIRECTORY}/*.yaml .
    else
        set files = `/bin/ls -1 ${AMIP_EMISSIONS_DIRECTORY}/*.rc ${AMIP_EMISSIONS_DIRECTORY}/*.yaml`
        foreach file ($files)
          /bin/rm -f `basename $file`
          /bin/rm -f dummy
          cp $file dummy
          cat dummy | sed -e "s|/L72/|/L${GEOSCTM_LM}/|g" | sed -e "s|z72|z${GEOSCTM_LM}|g" > `basename $file`
        end
    endif

endif

# Set WW3 start date and time
# ---------------------------
if( $wavewatch ) then
    cp ww3_multi.nml ww3_multi.nml.orig
    awk '{$1=$1};1' < ww3_multi.nml.orig > ww3_multi.nml

    # set start date
    set oldstring =  `grep '^\s*DOMAIN%START' ww3_multi.nml`
    set newstring =  "DOMAIN%START = '${nymdc} ${nhmsc}'"

    /bin/mv ww3_multi.nml ww3_multi.nml.tmp
    cat ww3_multi.nml.tmp | sed -e "s?$oldstring?$newstring?g" > ww3_multi.nml
    /bin/rm ww3_multi.nml.tmp

    # set end date
    set oldstring =  `grep '^\s*DOMAIN%STOP' ww3_multi.nml`
    set newstring =  "DOMAIN%STOP = '${nymde} ${nhmse}'"

    /bin/mv ww3_multi.nml ww3_multi.nml.tmp
    cat ww3_multi.nml.tmp | sed -e "s?$oldstring?$newstring?g" > ww3_multi.nml
    /bin/rm ww3_multi.nml.tmp
endif

if( $GEOSCTM_LM  != 72 ) then
    set files = `/bin/ls  *.yaml`
    foreach file ($files)
      cp $file dummy
      cat dummy | sed -e "s|/L72/|/L${GEOSCTM_LM}/|g" | sed -e "s|z72|z${GEOSCTM_LM}|g" > $file
    end
endif

# Rename big ExtData files that are not needed
# --------------------------------------------
set            SC_TRUE = `grep -i '^\s*ENABLE_STRATCHEM:\s*\.TRUE\.'     GEOS_ChemGridComp.rc | wc -l`
if (          $SC_TRUE == 0 && -e StratChem_ExtData.rc          ) /bin/mv          StratChem_ExtData.rc          StratChem_ExtData.rc.NOT_USED
set           GMI_TRUE = `grep -i '^\s*ENABLE_GMICHEM:\s*\.TRUE\.'       GEOS_ChemGridComp.rc | wc -l`
if (         $GMI_TRUE == 0 && -e GMI_ExtData.rc                ) /bin/mv                GMI_ExtData.rc                GMI_ExtData.rc.NOT_USED
set           GCC_TRUE = `grep -i '^\s*ENABLE_GEOSCHEM:\s*\.TRUE\.'      GEOS_ChemGridComp.rc | wc -l`
if (         $GCC_TRUE == 0 && -e GEOSCHEMchem_ExtData.rc       ) /bin/mv       GEOSCHEMchem_ExtData.rc       GEOSCHEMchem_ExtData.rc.NOT_USED
set         CARMA_TRUE = `grep -i '^\s*ENABLE_CARMA:\s*\.TRUE\.'         GEOS_ChemGridComp.rc | wc -l`
if (       $CARMA_TRUE == 0 && -e CARMAchem_GridComp_ExtData.rc ) /bin/mv CARMAchem_GridComp_ExtData.rc CARMAchem_GridComp_ExtData.rc.NOT_USED
set           DNA_TRUE = `grep -i '^\s*ENABLE_DNA:\s*\.TRUE\.'           GEOS_ChemGridComp.rc | wc -l`
if (         $DNA_TRUE == 0 && -e DNA_ExtData.rc                ) /bin/mv                DNA_ExtData.rc                DNA_ExtData.rc.NOT_USED
set         ACHEM_TRUE = `grep -i '^\s*ENABLE_ACHEM:\s*\.TRUE\.'         GEOS_ChemGridComp.rc | wc -l`
if (       $ACHEM_TRUE == 0 && -e ACHEM_ExtData.rc              ) /bin/mv              ACHEM_ExtData.rc              ACHEM_ExtData.rc.NOT_USED
set   GOCART_DATA_TRUE = `grep -i "^ *ENABLE_GOCART_DATA *: *\.TRUE\."   GEOS_ChemGridComp.rc | wc -l`
if ( $GOCART_DATA_TRUE == 0 && -e GOCARTdata_ExtData.rc         ) /bin/mv         GOCARTdata_ExtData.rc         GOCARTdata_ExtData.rc.NOT_USED

# Alternate syntax:
#set EXT_FILE=StratChem_ExtData.rc
#if(`grep -i "^ *ENABLE_STRATCHEM *: *\.TRUE\."     GEOS_ChemGridComp.rc | wc -l`==0 && -e $EXT_FILE) /bin/mv $EXT_FILE $EXT_FILE.NOT_USED

if( ${doGEOSCHEMCHEM} == YES) then

# Rename ExtData file that conflicts w/ GEOS-Chem
# -----------------------------------------------
/bin/mv  HEMCOgocart_ExtData.rc  HEMCOgocart_ExtData.rc.NOT_USED

endif

goto SKIP_WSUB
# 1MOM and GFDL microphysics do not use WSUB_CLIM
# -------------------------------------------------
if ($EXTDATA2G_TRUE == 0 ) then
   @MP_TURN_OFF_WSUB_EXTDATA/bin/mv WSUB_ExtData.rc WSUB_ExtData.tmp
   @MP_TURN_OFF_WSUB_EXTDATAcat WSUB_ExtData.tmp | sed -e '/^WSUB_CLIM/ s#ExtData.*#/dev/null#' > WSUB_ExtData.rc
else
   @MP_TURN_OFF_WSUB_EXTDATA/bin/mv WSUB_ExtData.yaml WSUB_ExtData.tmp
   @MP_TURN_OFF_WSUB_EXTDATAcat WSUB_ExtData.tmp | sed -e '/collection:/ s#WSUB_SWclim.*#/dev/null#' > WSUB_ExtData.yaml
endif
@MP_TURN_OFF_WSUB_EXTDATA/bin/rm WSUB_ExtData.tmp
SKIP_WSUB:


# Select the proper ExtData resource file
# when MERRA2 datasets are selected.
#----------------------------------------
if( ${DRIVING_DATASETS} == MERRA2) then

    # Edit the CAP.rc file
    #---------------------
    /bin/mv CAP.rc CAP.tmp
    cat CAP.tmp | grep -v EXTDATA_CF  > CAP.rc
    rm -f CAP.tmp

    cp MERRA2_ExtData.rc.tmpl MERRA2_ExtData.rc
    cp MERRA2_ExtData.yaml.tmpl MERRA2_ExtData.yaml

    # Concatenate required ExtData files
    # ----------------------------------
    if( ${doIdealizedPT} == YES) then
      set EXTDATA_COMPLETE = ExtData.rc
      /bin/cp MERRA2_ExtData.rc $EXTDATA_COMPLETE
    else if (${doGEOSCHEMCHEM} == YES) then
      set EXTDATA_COMPLETE = ExtData.rc
      set EXTDATA_FILES = `/bin/ls -1 MERRA2_ExtData.rc GOCARTdata_ExtData.rc WSUB_ExtData.rc BC_GridComp_ExtData.rc CO_GridComp_ExtData.rc CO2_GridComp_ExtData.rc DU_GridComp_ExtData.rc NI_GridComp_ExtData.rc OC_GridComp_ExtData.rc SU_GridComp_ExtData.rc GEOSCHEMchem_ExtData.rc`
      cat ${EXTDATA_FILES} > $EXTDATA_COMPLETE

    #  sed -i 's/QFED\/NRT/QFED/' $EXTDATA_COMPLETE
    #  sed -i 's/v2.5r1_0.1_deg/v2.5r1\/0.1/' $EXTDATA_COMPLETE
    else
      if( $EXTDATA2G_TRUE == 0 ) then
        set EXTDATA_COMPLETE = ExtData.rc
        set EXTDATA_FILES = `/bin/ls -1 *_ExtData.rc`
        cat ${EXTDATA_FILES} > $EXTDATA_COMPLETE
      else
        # generate extdata.yaml:
        $GEOSBIN/construct_extdata_yaml_list.py GEOS_ChemGridComp.rc

        set EXTDATA_COMPLETE = ExtData.rc  # not really needed
        touch ExtData.rc
      endif
    endif

endif

# For MERRA1
#-----------
if( ${DRIVING_DATASETS} == MERRA1) then
    set startYear = `cat cap_restart | cut -c1-4`
    set oldstring = `cat CAP.rc | grep EXTDATA_CF:`
    set COMPNAME = `grep COMPNAME CAP.rc | awk '{print $2}'`

    if( $startYear >= 1979 && $startYear <= 1992 ) then
        set sYear  = 1979
        set MERRA1type = MERRA100
        set data_Transition_Date = 19930101
    else if( $startYear >= 1993 && $startYear <= 2000 ) then
        set sYear  = 1993
        set MERRA1type = MERRA200
        set data_Transition_Date = 20010101
    else if( $startYear >= 2001 ) then
        set sYear  = 2001
        set MERRA1type = MERRA300
        set data_Transition_Date = 20200101
    endif

    set newstring = "EXTDATA_CF: ${COMPNAME}_ExtData_${sYear}.rc"
    set EXTDATA_COMPLETE =       ${COMPNAME}_ExtData_${sYear}.rc

    set oldstr2 = `cat CAP.rc | grep USE_EXTDATA2G:`
    set newstr2 = "USE_EXTDATA2G: .FALSE."

    # Edit the CAP.rc file
    #---------------------
    /bin/mv CAP.rc CAP.tmp
    cat CAP.tmp | sed -e "s?$oldstring?$newstring?g" > CAP.rc
    /bin/mv CAP.rc CAP.tmp
    cat CAP.tmp | sed -e "s?$oldstr2?$newstr2?g"     > CAP.rc
    rm -f CAP.tmp

    # Transition into a new date range
    #----------------------------------
    if( $nymdf > ${data_Transition_Date} ) then
        set nymdf = ${data_Transition_Date}
        set oldstring = `cat CAP.rc | grep END_DATE:`
        set newstring = "END_DATE: $nymdf $nhmsf"
        /bin/mv CAP.rc CAP.tmp
        cat CAP.tmp | sed -e "s?$oldstring?$newstring?g" > CAP.rc
        rm -f CAP.tmp
    endif

    # Edit the ExtData.rc file
    #-------------------------
    set tFILE = tmpfile
    rm -f $tFILE
    cat MERRA1_ExtData.rc.tmpl > $tFILE
    set sFILE = sedfile
    rm -f $sFILE
cat << EOF > $sFILE 
s/@MERRA1type/$MERRA1type/g
EOF

    sed -f $sFILE $tFILE > MAPL_ExtData_${sYear}.rc
    chmod 755  MAPL_ExtData_${sYear}.rc
    rm -f $tFILE
    rm -f $sFILE

# Concatenate required ExtData files
# ----------------------------------
set EXTDATA_FILES = `/bin/ls -1 MAPL_ExtData_${sYear}.rc *_ExtData.rc`
cat ${EXTDATA_FILES} > ${COMPNAME}_ExtData_${sYear}.rc

endif

# For FPIT
#-----------
if( ${DRIVING_DATASETS} == FPIT) then
    set startYear = `cat cap_restart | cut -c1-4`
    set oldstring = `cat CAP.rc | grep EXTDATA_CF:`
    set COMPNAME = `grep COMPNAME CAP.rc | awk '{print $2}'`

    if( $startYear >= 1979 && $startYear <= 1992 ) then
        set sYear  = 1979
        set FPITtype = UNKNOWN
        set data_Transition_Date = 19930101
    else if( $startYear >= 1993 && $startYear <= 2000 ) then
        set sYear  = 1993
        set FPITtype = UNKNOWN
        set data_Transition_Date = 20010101
    else if( $startYear >= 2001 ) then
        set sYear  = 2001
        set FPITtype = d5124_fpit
        set data_Transition_Date = 20200101
    endif

    set newstring = "EXTDATA_CF: ${COMPNAME}_ExtData_${sYear}.rc"
    set EXTDATA_COMPLETE =       ${COMPNAME}_ExtData_${sYear}.rc

    set oldstr2 = `cat CAP.rc | grep USE_EXTDATA2G:`
    set newstr2 = "USE_EXTDATA2G: .FALSE."

    # Edit the CAP.rc file
    #---------------------
    /bin/mv CAP.rc CAP.tmp
    cat CAP.tmp | sed -e "s?$oldstring?$newstring?g" > CAP.rc
    /bin/mv CAP.rc CAP.tmp
    cat CAP.tmp | sed -e "s?$oldstr2?$newstr2?g"     > CAP.rc
    rm -f CAP.tmp

    # Transition into a new date range
    #----------------------------------
    if( $nymdf > ${data_Transition_Date} ) then
        set nymdf = ${data_Transition_Date}
        set oldstring = `cat CAP.rc | grep END_DATE:`
        set newstring = "END_DATE: $nymdf $nhmsf"
        /bin/mv CAP.rc CAP.tmp
        cat CAP.tmp | sed -e "s?$oldstring?$newstring?g" > CAP.rc
        rm -f CAP.tmp
    endif

    # Edit the ExtData.rc file
    #-------------------------
    set tFILE = tmpfile
    rm -f $tFILE
    cat FPIT_ExtData.rc.tmpl > $tFILE
    set sFILE = sedfile
    rm -f $sFILE
cat << EOF > $sFILE 
s/@FPITtype/$FPITtype/g
EOF

    sed -f $sFILE $tFILE > MAPL_ExtData_${sYear}.rc
    chmod 755  MAPL_ExtData_${sYear}.rc
    rm -f $tFILE
    rm -f $sFILE

# Concatenate required ExtData files
# ----------------------------------
set EXTDATA_FILES = `/bin/ls -1 MAPL_ExtData_${sYear}.rc *_ExtData.rc`
cat ${EXTDATA_FILES} > ${COMPNAME}_ExtData_${sYear}.rc

endif

#-------------
# For F515_516
#-------------
if( ${DRIVING_DATASETS} == F515_516) then
    set startYear = `cat cap_restart | cut -c1-4`
    set oldstring = `cat CAP.rc | grep EXTDATA_CF:`
    set COMPNAME = `grep COMPNAME CAP.rc | awk '{print $2}'`

    if( $startYear >= 1979 && $startYear <= 1992 ) then
        set sYear  = 1979
        set FPtype = UNKNOWN
        set FPver  = UNKNOWN
        set FPmod  = UNKNOWN
        set data_Transition_Date = 19930101
    else if( $startYear >= 1993 && $startYear <= 2016 ) then
        set sYear  = 1993
        set FPtype = f515_fpp
        set FPver  = 5_15
        set FPmod  = 5.15
        set data_Transition_Date = 20170101
    else if( $startYear >= 2017 ) then
        set sYear  = 2017
        set FPtype = f516_fp
        set FPver  = 5_16
        set FPmod  = 5.16
        set data_Transition_Date = 20200101
    endif

    set newstring = "EXTDATA_CF: ${COMPNAME}_ExtData_${sYear}.rc"
    set EXTDATA_COMPLETE =       ${COMPNAME}_ExtData_${sYear}.rc

    set oldstr2 = `cat CAP.rc | grep USE_EXTDATA2G:`
    set newstr2 = "USE_EXTDATA2G: .FALSE."

    # Edit the CAP.rc file
    #---------------------
    /bin/mv CAP.rc CAP.tmp
    cat CAP.tmp | sed -e "s?$oldstring?$newstring?g" > CAP.rc
    /bin/mv CAP.rc CAP.tmp
    cat CAP.tmp | sed -e "s?$oldstr2?$newstr2?g"     > CAP.rc
    rm -f CAP.tmp

    # Transition into a new date range
    #----------------------------------
    if( $nymdf > ${data_Transition_Date} ) then
        set nymdf = ${data_Transition_Date}
        set oldstring = `cat CAP.rc | grep END_DATE:`
        set newstring = "END_DATE: $nymdf $nhmsf"
        /bin/mv CAP.rc CAP.tmp
        cat CAP.tmp | sed -e "s?$oldstring?$newstring?g" > CAP.rc
        rm -f CAP.tmp
    endif

    # Edit the ExtData.rc file
    #-------------------------
    set tFILE = tmpfile
    rm -f $tFILE
    cat FP_ExtData.rc.tmpl > $tFILE
    set sFILE = sedfile
    rm -f $sFILE
cat << EOF > $sFILE 
s/@FPtype/$FPtype/g
s/@FPver/$FPver/g
s/@FPmod/$FPmod/g
EOF

    sed -f $sFILE $tFILE > MAPL_ExtData_${sYear}.rc
    chmod 755  MAPL_ExtData_${sYear}.rc
    rm -f $tFILE
    rm -f $sFILE



# Concatenate required ExtData files
# ----------------------------------
set EXTDATA_FILES = `/bin/ls -1 MAPL_ExtData_${sYear}.rc *_ExtData.rc`
cat ${EXTDATA_FILES} > ${COMPNAME}_ExtData_${sYear}.rc

endif

#-------------
# For F5131
#-------------
if( ${DRIVING_DATASETS} == F5131) then
    set startYear = `cat cap_restart | cut -c1-4`
    set oldstring = `cat CAP.rc | grep EXTDATA_CF:`
    set COMPNAME = `grep COMPNAME CAP.rc | awk '{print $2}'`

    if( $startYear >= 1979 && $startYear <= 1992 ) then
        set sYear  = 1979
        set FPtype = UNKNOWN
        set FPver  = UNKNOWN
        set FPmod  = UNKNOWN
        set data_Transition_Date = 19930101
    else if( $startYear >= 1993 && $startYear <= 2000 ) then
        set sYear  = 1993
        set FPtype = UNKNOWN
        set FPver  = UNKNOWN
        set FPmod  = UNKNOWN
        set data_Transition_Date = 20010101
    else if( $startYear >= 2001 ) then
        set sYear  = 2001
        set FPtype = e5131_fp
        set FPver  = 5_13_1
        set FPmod  = 5.13.1
        set data_Transition_Date = 20200101
    endif

    set newstring = "EXTDATA_CF: ${COMPNAME}_ExtData_${sYear}.rc"
    set EXTDATA_COMPLETE =       ${COMPNAME}_ExtData_${sYear}.rc

    set oldstr2 = `cat CAP.rc | grep USE_EXTDATA2G:`
    set newstr2 = "USE_EXTDATA2G: .FALSE."

    # Edit the CAP.rc file
    #---------------------
    /bin/mv CAP.rc CAP.tmp
    cat CAP.tmp | sed -e "s?$oldstring?$newstring?g" > CAP.rc
    /bin/mv CAP.rc CAP.tmp
    cat CAP.tmp | sed -e "s?$oldstr2?$newstr2?g"     > CAP.rc
    rm -f CAP.tmp

    # Transition into a new date range
    #----------------------------------
    if( $nymdf > ${data_Transition_Date} ) then
        set nymdf = ${data_Transition_Date}
        set oldstring = `cat CAP.rc | grep END_DATE:`
        set newstring = "END_DATE: $nymdf $nhmsf"
        /bin/mv CAP.rc CAP.tmp
        cat CAP.tmp | sed -e "s?$oldstring?$newstring?g" > CAP.rc
        rm -f CAP.tmp
    endif

    # Edit the ExtData.rc file
    #-------------------------
    set tFILE = tmpfile
    rm -f $tFILE
    cat FP_ExtData.rc.tmpl > $tFILE
    set sFILE = sedfile
    rm -f $sFILE
cat << EOF > $sFILE 
s/@FPtype/$FPtype/g
s/@FPver/$FPver/g
s/@FPmod/$FPmod/g
EOF

    sed -f $sFILE $tFILE > MAPL_ExtData_${sYear}.rc
    chmod 755  MAPL_ExtData_${sYear}.rc
    rm -f $tFILE
    rm -f $sFILE

# Concatenate required ExtData files
# ----------------------------------
set EXTDATA_FILES = `/bin/ls -1 MAPL_ExtData_${sYear}.rc *_ExtData.rc`
cat ${EXTDATA_FILES} > ${COMPNAME}_ExtData_${sYear}.rc

endif

goto SKIP_GCM_EXTDATA_LINES
# Generate the complete ExtData.rc
# --------------------------------
if(-e ExtData.rc )    /bin/rm -f   ExtData.rc
set  extdata_files = `/bin/ls -1 *_ExtData.rc`

# Switch to MODIS v6.1 data after Nov 2021
if( $EXTDATA2G_TRUE == 0 ) then
   set MODIS_Transition_Date = 20211101
   if ( ${EMISSIONS} == OPS_EMISSIONS && ${MODIS_Transition_Date} <= $nymdc ) then
       cat $extdata_files | sed 's|\(qfed2.emis_.*\).006.|\1.061.|g' > ExtData.rc
   else
   cat $extdata_files > ExtData.rc
   endif
endif

if( $EXTDATA2G_TRUE == 1 ) then

  $GEOSBIN/construct_extdata_yaml_list.py GEOS_ChemGridComp.rc
  touch ExtData.rc

endif

# Move GOCART to use RRTMGP Bands
# -------------------------------
# UNCOMMENT THE LINES BELOW IF RUNNING RRTMGP
#
#set instance_files = `/bin/ls -1 *_instance*.rc`
#foreach instance ($instance_files)
#   /bin/mv $instance $instance.tmp
#   cat $instance.tmp | sed -e '/RRTMG/ s#RRTMG#RRTMGP#' > $instance
#   /bin/rm $instance.tmp
#end
SKIP_GCM_EXTDATA_LINES:

# Link Boundary Conditions for Appropriate Date
# ---------------------------------------------
setenv YEAR $yearc
./linkbcs

goto SKIP_WATER
if (! -e tile.bin) then
$GEOSBIN/binarytile.x tile.data tile.bin
endif

# If running in dual ocean mode, link sst and fraci data here
#set yy  = `cat cap_restart | cut -c1-4`
#echo $yy
#ln -sf $SSTDIR/dataoceanfile_MERRA2_SST.${OGCM_IM}x${OGCM_JM}.${yy}.data sst.data
#ln -sf $SSTDIR/dataoceanfile_MERRA2_ICE.${OGCM_IM}x${OGCM_JM}.${yy}.data fraci.data

#######################################################################
#                Split Saltwater Restart if detected
#######################################################################

if ( (-e $SCRDIR/openwater_internal_rst) && (-e $SCRDIR/seaicethermo_internal_rst)) then
  echo "Saltwater internal state is already split, good to go!"
else
 if ( ( ( -e $SCRDIR/saltwater_internal_rst ) || ( -e $EXPDIR/saltwater_internal_rst) ) && ( $counter == 1 ) ) then

   echo "Found Saltwater internal state. Splitting..."

   # If saltwater_internal_rst is in EXPDIR move to SCRDIR
   # -----------------------------------------------------
   if ( -e $EXPDIR/saltwater_internal_rst ) /bin/cp $EXPDIR/saltwater_internal_rst $SCRDIR

   # The splitter script requires an OutData directory
   # -------------------------------------------------
   if (! -d OutData ) mkdir -p OutData

   # Run the script
   # --------------
   @SINGULARITY_BUILD $RUN_CMD 1 $SINGULARITY_RUN $GEOSBIN/SaltIntSplitter tile.data $SCRDIR/saltwater_internal_rst
   @NATIVE_BUILD $RUN_CMD 1 $GEOSBIN/SaltIntSplitter tile.data $SCRDIR/saltwater_internal_rst

   # Move restarts
   # -------------
   /bin/mv OutData/openwater_internal_rst OutData/seaicethermo_internal_rst .

   # Remove OutData
   # --------------
   /bin/rmdir OutData

   # Make decorated copies for restarts tarball
   # ------------------------------------------
   cp openwater_internal_rst    $EXPID.openwater_internal_rst.${edate}.${GCMVER}.${BCTAG}_${BCRSLV}
   cp seaicethermo_internal_rst $EXPID.seaicethermo_internal_rst.${edate}.${GCMVER}.${BCTAG}_${BCRSLV}

   # Inject decorated copies into restarts tarball
   # ---------------------------------------------
   tar rf $EXPDIR/restarts/restarts.${edate}.tar $EXPID.*.${edate}.${GCMVER}.${BCTAG}_${BCRSLV}

   # Remove the decorated restarts
   # -----------------------------
   /bin/rm $EXPID.*.${edate}.${GCMVER}.${BCTAG}_${BCRSLV}

   # Remove the saltwater internal restart
   # -------------------------------------
   /bin/rm $SCRDIR/saltwater_internal_rst
 else
   echo "Neither saltwater_internal_rst, nor openwater_internal_rst and seaicethermo_internal_rst were found. Abort!"
   exit 6
 endif
endif

# Test Openwater Restart for Number of tiles correctness
# ------------------------------------------------------

if ( -x $GEOSBIN/rs_numtiles.x ) then

   set N_OPENW_TILES_EXPECTED = `grep '^\s*0' tile.data | wc -l`
   @SINGULARITY_BUILD set N_OPENW_TILES_FOUND = `$RUN_CMD 1 $SINGULARITY_RUN $GEOSBIN/rs_numtiles.x openwater_internal_rst | grep Total | awk '{print $NF}'`
   @NATIVE_BUILD set N_OPENW_TILES_FOUND = `$RUN_CMD 1 $GEOSBIN/rs_numtiles.x openwater_internal_rst | grep Total | awk '{print $NF}'`

   if ( $N_OPENW_TILES_EXPECTED != $N_OPENW_TILES_FOUND ) then
      echo "Error! Found $N_OPENW_TILES_FOUND tiles in openwater. Expect to find $N_OPENW_TILES_EXPECTED tiles."
      echo "Your restarts are probably for a different ocean."
      exit 7
   endif

endif
SKIP_WATER:

# don't read NRT QFED data
if( $EXTDATA2G_TRUE == 0 ) then
  sed -i 's/QFED\/NRT/QFED/'             $EXTDATA_COMPLETE
  sed -i 's/v2.5r1_0.1_deg/v2.5r1\/0.1/' $EXTDATA_COMPLETE
else
# set YAML_FILES = `grep " - " extdata.yaml | awk '{print $2}'`
# foreach i ( $YAML_FILES )
#   sed -i 's/QFED\/NRT/QFED/'             $i
#   sed -i 's/v2.5r1_0.1_deg/v2.5r1\/0.1/' $i
# end
endif

# Check for MERRA2OX Consistency
# ------------------------------

# The MERRA2OX pchem file is only valid until 201706, so this is a first
# attempt at a check to make sure you aren't using it and are past the date

# Check for MERRA2OX by looking at GEOSCTM.rc
set PCHEM_CLIM_YEARS = `awk '/pchem_clim_years/ {print $2}' GEOSCTM.rc`

# If it is 39, we are using MERRA2OX
if ( $PCHEM_CLIM_YEARS == 39 ) then

   # Grab the date from cap_restart
   set YEARMON = `cat cap_restart | cut -c1-6`

   # Set a magic date
   set MERRA2OX_END_DATE = "201706"

   # String comparison seems to work here...
   if ( $YEARMON > $MERRA2OX_END_DATE ) then
      echo "You seem to be using MERRA2OX pchem species file, but your simulation date [${YEARMON}] is after 201706. This file is only valid until this time."
      exit 2
   endif
endif

# Environment variables for MPI, etc
# ----------------------------------

@SETENVS

@MPT_SHEPHERD

# Run bundleParser.py
#---------------------
python3 bundleParser.py

goto SKIP_REPLAY
# If REPLAY, link necessary forcing files
# ---------------------------------------
set  REPLAY_MODE = `grep '^\s*REPLAY_MODE:' AGCM.rc | cut -d: -f2`
if( $REPLAY_MODE == 'Exact' | $REPLAY_MODE == 'Regular' ) then

     set ANA_EXPID    = `grep '^\s*REPLAY_ANA_EXPID:'    AGCM.rc | cut -d: -f2`
     set ANA_LOCATION = `grep '^\s*REPLAY_ANA_LOCATION:' AGCM.rc | cut -d: -f2`

     set REPLAY_FILE        = `grep '^\s*REPLAY_FILE:'   AGCM.rc | cut -d: -f2`
     set REPLAY_FILE09      = `grep '^\s*REPLAY_FILE09:' AGCM.rc | cut -d: -f2`
     set REPLAY_FILE_TYPE   = `echo $REPLAY_FILE           | cut -d"/" -f1 | grep -v %`
     set REPLAY_FILE09_TYPE = `echo $REPLAY_FILE09         | cut -d"/" -f1 | grep -v %`

     # Modify GAAS_GridComp_ExtData and Link REPLAY files
     # ---------------------------------------------
     /bin/mv -f GAAS_GridComp_ExtData.yaml GAAS_GridComp_ExtData.yaml.tmpl
     cat GAAS_GridComp_ExtData.yaml.tmpl | sed -e "s?das.aod_?chem/Y%y4/M%m2/${ANA_EXPID}.aod_?g" > GAAS_GridComp_ExtData.yaml

     /bin/mv -f GAAS_GridComp_ExtData.rc GAAS_GridComp_ExtData.rc.tmpl
     cat GAAS_GridComp_ExtData.rc.tmpl | sed -e "s?das.aod_?chem/Y%y4/M%m2/${ANA_EXPID}.aod_?g" > GAAS_GridComp_ExtData.rc

     /bin/ln -sf ${ANA_LOCATION}/chem .
     /bin/ln -sf ${ANA_LOCATION}/${REPLAY_FILE_TYPE} .
     /bin/ln -sf ${ANA_LOCATION}/${REPLAY_FILE09_TYPE} .

endif
SKIP_REPLAY:

# Establish safe default number of OpenMP threads
# -----------------------------------------------

# Set OMP_NUM_THREADS
# -------------------
setenv OMP_NUM_THREADS 1

# Run GEOSctm.x
# -------------
if( $USE_SHMEM == 1 ) $GEOSBIN/RmShmKeys_sshmpi.csh >& /dev/null

if( $USE_IOSERVER == 1 ) then
   set IOSERVER_OPTIONS = "--npes_model $MODEL_NPES --nodes_output_server $NUM_OSERVER_NODES"
   set IOSERVER_EXTRA   = "--oserver_type multigroup --npes_backend_pernode $NUM_BACKEND_PES"
else
   set IOSERVER_OPTIONS = ""
   set IOSERVER_EXTRA   = ""
endif

  $RUN_CMD $TOTAL_PES $CTMEXE $IOSERVER_OPTIONS $IOSERVER_EXTRA --logging_config 'logging.yaml' --esmf_logtype multi

if( $USE_SHMEM == 1 ) $GEOSBIN/RmShmKeys_sshmpi.csh >& /dev/null

if( -e EGRESS ) then
   set rc = 0
else
   set rc = -1
endif
echo GEOSctm Run Status: $rc

if ( $rc != 0 ) then
   echo 'CTM error: exit'
   exit
endif
 
#######################################################################
#   Rename Final Checkpoints => Restarts for Next Segment and Archive
#        Note: cap_restart contains the current NYMD and NHMS
#######################################################################

set edate  = e`cat cap_restart | cut -c1-8`_`cat cap_restart | cut -c10-11`z

set numrst = `echo $rst_files | wc -w`
set numchk = `echo $chk_files | wc -w`

@ n = 1
@ z = $numrst + 1
while ( $n <= $numchk )
   if ( -e $chk_file_names[$n] ) then
       @ m = 1
       while ( $m <= $numrst )
       if(    $chk_files[$n] == $rst_files[$m] || \
            \#$chk_files[$n] == $rst_files[$m]    ) then

            set   chk_type = `/usr/bin/file -Lb --mime-type $chk_file_names[$n]`
            if ( $chk_type =~ "application/octet-stream" ) then
                  set ext  = bin
            else
                  set ext  = nc4
            endif

           /bin/mv $chk_file_names[$n] $rst_file_names[$m]
           /bin/cp $rst_file_names[$m] ${EXPDIR}/restarts/$EXPID.${rst_file_names[$m]}.${edate}.${CTMVER}.$ext &
           @ m = $numrst + 999
       else
           @ m = $m + 1
       endif
       end
       wait
       if( $m == $z ) then
           echo "Warning!!  Could not find CHECKPOINT/RESTART match for:  " $chk_files[$n]
           exit
       endif
   endif
@ n = $n + 1
end


# TAR ARCHIVED RESTARTS
# ---------------------
cd $EXPDIR/restarts
if( $FSEGMENT == 00000000 ) then
        tar cf  restarts.${edate}.tar                      $EXPID.*.${edate}.${CTMVER}.*
        if ( $status == 0 ) /bin/rm -rf `/bin/ls -d -1     $EXPID.*.${edate}.${CTMVER}.*`
endif

#######################################################################
#               Move HISTORY Files to Holding Directory
#######################################################################

# Check for files waiting in /holding    I THINK THIS WAS TO AVOID PPROC 2x AT ONCE
# -----------------------------------
set     waiting_files = `/bin/ls -1 $EXPDIR/holding/*/*nc4`
set num_waiting_files = $#waiting_files

# Move current files to /holding
# ------------------------------
cd $SCRDIR
foreach collection ( $collections )
   /bin/mv `/bin/ls -1 *.${collection}.*` $EXPDIR/holding/$collection
end

#######################################################################
#                Submit Post-Processing (if necessary)
#######################################################################

if( $num_waiting_files == 0 ) then

cd   $EXPDIR/post
/bin/rm -f sedfile
cat >      sedfile << EOF
s/@POST_O/ctm_post.${edate}/g
s/@COLLECTION/ALL/g
s/-rec_plt @YYYYMM//
EOF
sed -f sedfile ctm_post.j > ctm_post.jtmp
chmod 755  ctm_post.jtmp
 qsub      ctm_post.jtmp
/bin/rm -f ctm_post.jtmp
/bin/rm -f sedfile
cd   $SCRDIR

endif

#######################################################################
#                         Update Iteration Counter
#######################################################################

set enddate = `echo  $END_DATE | cut -c1-8`
set capdate = `cat cap_restart | cut -c1-8`

if ( $capdate < $enddate ) then
@ counter = $counter    + 1
else
@ counter = ${NUM_SGMT} + 1
endif

end   # end of segment loop; remain in $SCRDIR

#######################################################################
#                              Re-Submit Job
#######################################################################

if( $GCMEMIP == TRUE ) then
     foreach rst ( `/bin/ls -1 *_rst` )
        /bin/rm -f $EXPDIR/restarts/$RSTDATE/$rst
     end
        /bin/rm -f $EXPDIR/restarts/$RSTDATE/cap_restart
     foreach rst ( `/bin/ls -1 *_rst` )
       cp $rst $EXPDIR/restarts/$RSTDATE/$rst &
     end
     wait
     cp cap_restart $EXPDIR/restarts/$RSTDATE/cap_restart
else
     foreach rst ( `/bin/ls -1 *_rst` )
        /bin/rm -f $EXPDIR/$rst
     end
        /bin/rm -f $EXPDIR/cap_restart
     foreach rst ( `/bin/ls -1 *_rst` )
       cp $rst $EXPDIR/$rst &
     end
     wait
     cp cap_restart $EXPDIR/cap_restart

     if( $wavewatch ) then
        set rst_ww3 = "restart.ww3"
        /bin/rm -f $EXPDIR/$rst_ww3
        cp $rst_ww3 $EXPDIR/$rst_ww3 &
        wait
     endif
endif


if ( $rc == 0 ) then
      cd  $HOMDIR
      if ( $GCMEMIP == TRUE ) then
          if( $capdate < $enddate ) @BATCH_CMD $HOMDIR/ctm_run.j$RSTDATE
      else
          if( $capdate < $enddate ) @BATCH_CMD $HOMDIR/ctm_run.j
      endif
endif
