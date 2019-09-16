#!/bin/csh -fv

#######################################################################
#                     Batch Parameters for Run Job
#######################################################################

#SBATCH --job-name=gcm-ctm-interp
#SBATCH --ntasks=1708
#SBATCH --constraint=hasw
#SBATCH -A s1873

#######################################################################
#                  System Environment Variables
#######################################################################

umask 022

limit stacksize unlimited

setenv I_MPI_DAPL_UD enable

#######################################################################
# Configuration Settings
#######################################################################

setenv doIdealizedPT NO
setenv doGEOSCHEMCHEM NO

#######################################################################
#           Architecture Specific Environment Variables
#######################################################################

setenv ARCH `uname`

setenv SITE             NCCS
setenv GEOSDIR          /discover/nobackup/kgerheis/develop/GEOSsystem 
setenv GEOSBIN          /discover/nobackup/kgerheis/develop/GEOSsystem/Linux/bin 
setenv RUN_CMD         "mpirun -np "
setenv CTMVER           Icarus-1_0_p2_CTM-r7
setenv GCMVER           Icarus-3_4_ESMF7

module purge
source $GEOSBIN/g5_modules
module list
module load tool/tview-2018.0.5
setenv LD_LIBRARY_PATH ${LD_LIBRARY_PATH}:${BASEDIR}/${ARCH}/lib

##CHange thisssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssss
#######################################################################
#             Experiment Specific Environment Variables
#######################################################################

setenv    EXPID   gcm-ctm_test
setenv    EXPDIR  /discover/nobackup/kgerheis/experiments/gcm-ctm_test
setenv    HOMDIR  /discover/nobackup/kgerheis/experiments/gcm-ctm_test
setenv    SCRDIR  $EXPDIR/scratch

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
if (! -e $SCRDIR            ) mkdir -p $SCRDIR


#######################################################################
#                   Set Experiment Run Parameters
#######################################################################

set     CTM_NX = `grep         NX: $HOMDIR/GEOSCTM.rc | cut -d':' -f2`
set     CTM_NY = `grep         NY: $HOMDIR/GEOSCTM.rc | cut -d':' -f2`
set GEOSCTM_IM = `grep GEOSCTM_IM: $HOMDIR/GEOSCTM.rc | cut -d':' -f2`
set GEOSCTM_JM = `grep GEOSCTM_JM: $HOMDIR/GEOSCTM.rc | cut -d':' -f2`
set GEOSCTM_LM = `grep         LM: $HOMDIR/GEOSCTM.rc | cut -d':' -f2`
set    OGCM_IM = `grep    OGCM_IM: $HOMDIR/GEOSCTM.rc | cut -d':' -f2`
set    OGCM_JM = `grep    OGCM_JM: $HOMDIR/GEOSCTM.rc | cut -d':' -f2`

set   END_DATE = `grep   END_DATE: $HOMDIR/CAP.rc | cut -d':' -f2`
set   NUM_SGMT = `grep   NUM_SGMT: $HOMDIR/CAP.rc | cut -d':' -f2`
set  USE_SHMEM = `grep  USE_SHMEM: $HOMDIR/CAP.rc | cut -d':' -f2`



set  AGCM_NX  = `grep      "^ *NX:" $HOMDIR/AGCM.rc | cut -d':' -f2`
set  AGCM_NY  = `grep      "^ *NY:" $HOMDIR/AGCM.rc | cut -d':' -f2`
set  AGCM_IM  = `grep      AGCM_IM: $HOMDIR/AGCM.rc | cut -d':' -f2`
set  AGCM_JM  = `grep      AGCM_JM: $HOMDIR/AGCM.rc | cut -d':' -f2`
set  AGCM_LM  = `grep      AGCM_LM: $HOMDIR/AGCM.rc | cut -d':' -f2`
set  OGCM_IM  = `grep      OGCM_IM: $HOMDIR/AGCM.rc | cut -d':' -f2`
set  OGCM_JM  = `grep      OGCM_JM: $HOMDIR/AGCM.rc | cut -d':' -f2`

# # Check for Over-Specification of CPU Resources
# # ---------------------------------------------
#   if ($?PBS_NODEFILE) then
#      set  NCPUS = `cat $PBS_NODEFILE | wc -l`
#      @    NPES  = $AGCM_NX * $AGCM_NY
#         if( $NPES > $NCPUS ) then
#              echo "CPU Resources are Over-Specified"
#              echo "--------------------------------"
#              echo "Allotted NCPUs: $NCPUS"
#              echo "Specified  NX : $NX"
#              echo "Specified  NY : $NY"
#              exit
#         endif
#      endif
#   endif





#######################################################################
#   Move to Scratch Directory and Copy RC Files from Home Directory
#######################################################################

cd $EXPDIR

# Driving datasets
setenv DRIVING_DATASETS MERRA2

cd $SCRDIR
/bin/rm -rf *
                             /bin/ln -sf $EXPDIR/RC/* .
                             /bin/cp     $EXPDIR/cap_restart .
if ( ${DRIVING_DATASETS} == F515_516 || ${DRIVING_DATASETS} == F5131 ) then
                             /bin/cp     $EXPDIR/FP_ExtData.rc.tmpl .
else
                             /bin/cp     $EXPDIR/${DRIVING_DATASETS}_ExtData.rc.tmpl .
endif
                             /bin/cp -f  $HOMDIR/*.rc .

			     cat fvcore_layout.rc >> input.nml

set END_DATE  = `grep     END_DATE:  CAP.rc | cut -d':' -f2`
set NUM_SGMT  = `grep     NUM_SGMT:  CAP.rc | cut -d':' -f2`
set FSEGMENT  = `grep FCST_SEGMENT:  CAP.rc | cut -d':' -f2`
set USE_SHMEM = `grep    USE_SHMEM:  CAP.rc | cut -d':' -f2`


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
#         Create Strip Utility to Remove Multiple Blank Spaces
#######################################################################

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




#######################################################################
#              Create HISTORY Collection Directories
#######################################################################

set ctm_collections = ''
foreach line ("`cat CTM_HISTORY.rc`")
   set firstword  = `echo $line | awk '{print $1}'`
   set firstchar  = `echo $firstword | cut -c1`
   set secondword = `echo $line | awk '{print $2}'`

   if ( $firstword == "::" ) goto ctm_done

   if ( $firstchar != "#" ) then
      set collection  = `echo $firstword | sed -e "s/'//g"`
      set ctm_collections = `echo $ctm_collections $collection`
      if ( $secondword == :: ) goto ctm_done
   endif

   if ( $firstword == COLLECTIONS: ) then
      set ctm_collections = `echo $secondword | sed -e "s/'//g"`
   endif
end

ctm_done:
   foreach collection ( $ctm_collections )
      if (! -e $EXPDIR/$collection )         mkdir $EXPDIR/$collection
      if (! -e $EXPDIR/holding/$collection ) mkdir $EXPDIR/holding/$collection
   end



set agcm_collections = ''
foreach line ("`cat AGCM_HISTORY.rc`")
   set firstword  = `echo $line | awk '{print $1}'`
   set firstchar  = `echo $firstword | cut -c1`
   set secondword = `echo $line | awk '{print $2}'`

   if ( $firstword == "::" ) goto agcm_done

   if ( $firstchar != "#" ) then
      set collection  = `echo $firstword | sed -e "s/'//g"`
      set agcm_collections = `echo $agcm_collections $collection`
      if ( $secondword == :: ) goto agcm_done
   endif

   if ( $firstword == COLLECTIONS: ) then
      set agcm_collections = `echo $secondword | sed -e "s/'//g"`
   endif
end

agcm_done:
   foreach collection ( $agcm_collections )
      if (! -e $EXPDIR/$collection )         mkdir $EXPDIR/$collection
      if (! -e $EXPDIR/holding/$collection ) mkdir $EXPDIR/holding/$collection
   end


#######################################################################
#                        Link Boundary Datasets
#######################################################################

# setenv BCSDIR    /discover/nobackup/ltakacs/bcs/Icarus/Icarus_Reynolds
# setenv SSTDIR    /discover/nobackup/projects/gmao/share/dao_ops/fvInput/g5gcm/bcs/realtime/SST/360x180
# setenv CHMDIR    /discover/nobackup/projects/gmao/share/dao_ops/fvInput_nc3
# setenv BCRSLV    CF0090x6C_DE0360xPE0180
# setenv DATELINE  DC
# setenv EMISSIONS g5chem

setenv BCSDIR    /discover/nobackup/ltakacs/bcs/Icarus/Icarus_MERRA-2
setenv SSTDIR    /discover/nobackup/projects/gmao/share/dao_ops/fvInput/g5gcm/bcs/SST/1440x720
setenv CHMDIR    /discover/nobackup/projects/gmao/share/dao_ops/fvInput_nc3
setenv BCRSLV    CF0720x6C_DE1440xPE0720
setenv DATELINE  DC
setenv EMISSIONS MERRA2

setenv BCTAG `basename $BCSDIR`

set             FILE = linkbcs
/bin/rm -f     $FILE
cat << _EOF_ > $FILE
#!/bin/csh -f

/bin/mkdir -p            ExtData
/bin/ln    -sf $CHMDIR/* ExtData


/bin/ln -sf $BCSDIR/$BCRSLV/${BCRSLV}-Pfafstetter.til  tile.data
if(     -e  $BCSDIR/$BCRSLV/${BCRSLV}-Pfafstetter.TIL) then
/bin/ln -sf $BCSDIR/$BCRSLV/${BCRSLV}-Pfafstetter.TIL  tile.bin
endif

# CMIP-5 Ozone Data (228-Years)
# -----------------------------
#bin/ln -sf $BCSDIR/Shared/pchem.species.CMIP-5.1870-2097.z_91x72.nc4 species.data

# MERRA-2 Ozone Data (39-Years)
# -----------------------------
/bin/ln -sf $BCSDIR/Shared/pchem.species.CMIP-5.MERRA2OX.197902-201706.z_91x72.nc4 species.data

/bin/ln -sf $BCSDIR/Shared/*bin .
/bin/ln -sf $BCSDIR/Shared/*c2l*.nc4 .

/bin/ln -sf $BCSDIR/$BCRSLV/visdf_${AGCM_IM}x${AGCM_JM}.dat visdf.dat
/bin/ln -sf $BCSDIR/$BCRSLV/nirdf_${AGCM_IM}x${AGCM_JM}.dat nirdf.dat
/bin/ln -sf $BCSDIR/$BCRSLV/vegdyn_${AGCM_IM}x${AGCM_JM}.dat vegdyn.data
/bin/ln -sf $BCSDIR/$BCRSLV/lai_clim_${AGCM_IM}x${AGCM_JM}.data lai.data
/bin/ln -sf $BCSDIR/$BCRSLV/green_clim_${AGCM_IM}x${AGCM_JM}.data green.data
/bin/ln -sf $BCSDIR/$BCRSLV/ndvi_clim_${AGCM_IM}x${AGCM_JM}.data ndvi.data
/bin/ln -sf $BCSDIR/$BCRSLV/topo_DYN_ave_${AGCM_IM}x${AGCM_JM}.data topo_dynave.data
/bin/ln -sf $BCSDIR/$BCRSLV/topo_GWD_var_${AGCM_IM}x${AGCM_JM}.data topo_gwdvar.data
/bin/ln -sf $BCSDIR/$BCRSLV/topo_TRB_var_${AGCM_IM}x${AGCM_JM}.data topo_trbvar.data

if(     -e  $BCSDIR/$BCRSLV/Gnomonic_$BCRSLV.dat ) then
/bin/ln -sf $BCSDIR/$BCRSLV/Gnomonic_$BCRSLV.dat .
endif


_EOF_

# echo "/bin/ln -sf $SSTDIR"'/dataoceanfile_MERRA_sst_1971-current.360x180.LE   sst.data' >> $FILE
# echo "/bin/ln -sf $SSTDIR"'/dataoceanfile_MERRA_fraci_1971-current.360x180.LE fraci.data' >> $FILE
# echo "/bin/ln -sf $SSTDIR"'/SEAWIFS_KPAR_mon_clim.360x180 SEAWIFS_KPAR_mon_clim.data' >> $FILE

echo "/bin/ln -sf $SSTDIR"'/dataoceanfile_MERRA2_SST.1440x720.$YEAR.data   sst.data' >> $FILE
echo "/bin/ln -sf $SSTDIR"'/dataoceanfile_MERRA2_ICE.1440x720.$YEAR.data fraci.data' >> $FILE
echo "/bin/ln -sf $SSTDIR"'/SEAWIFS_KPAR_mon_clim.1440x720 SEAWIFS_KPAR_mon_clim.data' >> $FILE

chmod +x linkbcs
/bin/cp  linkbcs $EXPDIR


#######################################################################
#          Get C2L History weights/index file for Cubed-Sphere
#######################################################################

set AGCM_C_NPX = `echo $AGCM_IM | awk '{printf "%5.5i", $1}'`
set AGCM_C_NPY = `echo $AGCM_JM | awk '{printf "%5.5i", $1}'`
set AGCM_H_NPX = `echo 180 | awk '{printf "%5.5i", $1}'`
set AGCM_H_NPY = `echo 91 | awk '{printf "%5.5i", $1}'`

set agcm_c2l_file = "${AGCM_C_NPX}x${AGCM_C_NPY}_c2l_${AGCM_H_NPX}x${AGCM_H_NPY}.bin"

if (-e $BCSDIR/$BCRSLV/${agcm_c2l_file}) /bin/ln -s $BCSDIR/$BCRSLV/${agcm_c2l_file} .


set CTM_C_NPX = `echo $GEOSCTM_IM | awk '{printf "%5.5i", $1}'`
set CTM_C_NPY = `echo $GEOSCTM_JM | awk '{printf "%5.5i", $1}'`
set CTM_H_NPX = `echo 96 | awk '{printf "%5.5i", $1}'`
set CTM_H_NPY = `echo 49 | awk '{printf "%5.5i", $1}'`

set ctm_c2l_file = "${CTM_C_NPX}x${CTM_C_NPY}_c2l_${CTM_H_NPX}x${CTM_H_NPY}.bin"



#######################################################################
#                    Get Executable and RESTARTS 
#######################################################################

/bin/cp $EXPDIR/GEOSgcm-ctm.x .

set agcm_rst_files      = `cat AGCM.rc | grep "RESTART_FILE"    | grep -v VEGDYN | grep -v "#" | cut -d ":" -f1 | cut -d "_" -f1-2`
set agcm_rst_file_names = `cat AGCM.rc | grep "RESTART_FILE"    | grep -v VEGDYN | grep -v "#" | cut -d ":" -f2`

set agcm_chk_files      = `cat AGCM.rc | grep "CHECKPOINT_FILE" | grep -v "#" | cut -d ":" -f1 | cut -d "_" -f1-2`
set agcm_chk_file_names = `cat AGCM.rc | grep "CHECKPOINT_FILE" | grep -v "#" | cut -d ":" -f2`

# Remove possible bootstrap parameters (+/-)
# ------------------------------------------
set agcm_dummy = `echo $agcm_rst_file_names`
set agcm_rst_file_names = ''
foreach rst ( $agcm_dummy )
    echo $rst
  set length  = `echo $rst | awk '{print length($0)}'`
  set    bit  = `echo $rst | cut -c1`
  if(  "$bit" == "+" | \
       "$bit" == "-" ) set rst = `echo $rst | cut -c2-$length`
  set agcm_rst_file_names = `echo $agcm_rst_file_names $rst`
end

# Copy Restarts to Scratch Directory
# ----------------------------------
if( $GCMEMIP == TRUE ) then
    foreach rst ( $agcm_rst_file_names )
      if(-e $EXPDIR/restarts/$RSTDATE/$rst ) /bin/cp $EXPDIR/restarts/$RSTDATE/$rst . &
    end
else
    foreach rst ( $agcm_rst_file_names )
      echo $rst
      if(-e $EXPDIR/$rst ) /bin/ln -s  $EXPDIR/$rst . &
    end
endif
wait


# Copy and Tar Initial Restarts to Restarts Directory
# ---------------------------------------------------
# set edate = e`cat cap_restart | cut -c1-8`_`cat cap_restart | cut -c10-11`z
# set agcm_numrs = `/bin/ls -1 ${EXPDIR}/restarts/*${edate}* | wc -l`
# if($agcm_numrs == 1) then
#    foreach rst ( $agcm_rst_file_names )
#       if( -e $rst & ! -e ${EXPDIR}/restarts/$EXPID.${rst}.${edate}.${GCMVER}.${BCTAG}_${BCRSLV} ) then
#             /bin/cp $rst ${EXPDIR}/restarts/$EXPID.${rst}.${edate}.${GCMVER}.${BCTAG}_${BCRSLV} &
#       endif
#    end
#    wait
#    cd $EXPDIR/restarts
#       tar cf  restarts.${edate}.tar $EXPID.*.${edate}.${GCMVER}.${BCTAG}_${BCRSLV}
#      /bin/rm -rf `/bin/ls -d -1     $EXPID.*.${edate}.${GCMVER}.${BCTAG}_${BCRSLV}`
#    cd $SCRDIR
# endif

# If any restart is binary, set NUM_READERS to 1 so that
# +-style bootstrapping of missing files can occur in 
# MAPL. pbinary cannot do this, but pnc4 can.
# ------------------------------------------------------
set found_binary = 0

foreach rst ( $agcm_rst_file_names )
   if (-e $rst) then
      set rst_type = `/usr/bin/file -Lb --mime-type $rst`
      if ( $rst_type =~ "application/octet-stream" ) then
         set found_binary = 1
      endif
   endif
end

if ($found_binary == 1) then
   /bin/mv AGCM.rc AGCM.tmp
   cat AGCM.tmp | sed -e "/^NUM_READERS/ s/\([0-9]\+\)/1/g" > AGCM.rc
   /bin/rm AGCM.tmp
endif




set ctm_rst_files      = `cat GEOSCTM.rc | grep "RESTART_FILE"    | cut -d ":" -f1 | cut -d "_" -f1-2`
set ctm_chk_files      = `cat GEOSCTM.rc | grep "CHECKPOINT_FILE" | cut -d ":" -f1 | cut -d "_" -f1-2`
set ctm_rst_file_names = `cat GEOSCTM.rc | grep "RESTART_FILE"    | cut -d ":" -f2`
set ctm_chk_file_names = `cat GEOSCTM.rc | grep "CHECKPOINT_FILE" | cut -d ":" -f2`

# Remove possible bootstrap parameters (+/-)
# ------------------------------------------
set ctm_dummy = `echo $ctm_rst_file_names`
set ctm_rst_file_names = ''
foreach rst ( $ctm_dummy )
  set length  = `echo $rst | awk '{print length($0)}'`
  set    bit  = `echo $rst | cut -c1`
  if(  "$bit" == "+" | \
       "$bit" == "-" ) set rst = `echo $rst | cut -c2-$length`
  set ctm_rst_file_names = `echo $ctm_rst_file_names $rst`
end

# Copy Restarts to Scratch Directory
# ----------------------------------
foreach rst ( $ctm_rst_file_names )
  if(-e $EXPDIR/$rst ) /bin/cp $EXPDIR/$rst . &
end
wait

# Copy and Tar Initial Restarts to Restarts Directory
# ---------------------------------------------------
set edate = e`cat cap_restart | cut -c1-8`_`cat cap_restart | cut -c10-11`z
set ctm_numrs = `/bin/ls -1 ${EXPDIR}/restarts/*${edate}* | wc -l`
if($ctm_numrs == 0) then
   foreach rst ( $ctm_rst_file_names )
      if( -e $rst & ! -e ${EXPDIR}/restarts/$EXPID.${rst}.${edate}.${CTMVER} ) then
            /bin/cp $rst ${EXPDIR}/restarts/$EXPID.${rst}.${edate}.${CTMVER} &
      endif
   end
   wait
   cd $EXPDIR/restarts
      tar cf  restarts.${edate}.tar $EXPID.*.${edate}.${CTMVER}
     /bin/rm -rf `/bin/ls -d -1     $EXPID.*.${edate}.${CTMVER}`
   cd $SCRDIR
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
    /bin/cp -f  $EXPDIR/restarts/$RSTDATE/CAP.rc .
else
    /bin/cp -f $HOMDIR/CAP.rc .
endif

./strip CAP.rc

# Set Time Variables for Current_(c), Ending_(e), and Segment_(s) dates 
# ---------------------------------------------------------------------
set nymdc = `cat cap_restart | cut -c1-8`
set nhmsc = `cat cap_restart | cut -c10-15`
set nymde = `cat CAP.rc | grep END_DATE:     | cut -d: -f2 | cut -c2-9`
set nhmse = `cat CAP.rc | grep END_DATE:     | cut -d: -f2 | cut -c11-16`
set nymds = `cat CAP.rc | grep JOB_SGMT:     | cut -d: -f2 | cut -c2-9`
set nhmss = `cat CAP.rc | grep JOB_SGMT:     | cut -d: -f2 | cut -c11-16`

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
if( DE0360xPE0180 != DE0360xPE0180 ) then
    if( $yearf > $yearc ) then
       @ yearf = $yearc + 1
       @ nymdf = $yearf * 10000 + 0101
        set oldstring = `cat CAP.rc | grep END_DATE:`
        set newstring = "END_DATE: $nymdf $nhmsf"
        /bin/mv CAP.rc CAP.tmp
        cat CAP.tmp | sed -e "s?$oldstring?$newstring?g" > CAP.rc
    endif
endif

# Select proper MERRA-2 GOCART Emission RC Files
# (NOTE: MERRA2-DD has same transition date)
# ----------------------------------------------
if( ${EMISSIONS} == MERRA2 | \
    ${EMISSIONS} == MERRA2-DD ) then
    set MERRA2_Transition_Date = 20000401

    if( $nymdc < ${MERRA2_Transition_Date} ) then
         set MERRA2_EMISSIONS_DIRECTORY = $GEOSDIR/$ARCH/etc/$EMISSIONS/19600101-20000331
         if( $nymdf > ${MERRA2_Transition_Date} ) then
          set nymdf = ${MERRA2_Transition_Date}
          set oldstring = `cat CAP.rc | grep END_DATE:`
          set newstring = "END_DATE: $nymdf $nhmsf"
          /bin/mv CAP.rc CAP.tmp
                     cat CAP.tmp | sed -e "s?$oldstring?$newstring?g" > CAP.rc
         endif
    else
         set MERRA2_EMISSIONS_DIRECTORY = $GEOSDIR/$ARCH/etc/$EMISSIONS/20000401-present
    endif

    if( $AGCM_LM == 72 ) then
        /bin/cp --remove-destination ${MERRA2_EMISSIONS_DIRECTORY}/*.rc .
    else
        set files =      `/bin/ls -1 ${MERRA2_EMISSIONS_DIRECTORY}/*.rc`
        foreach file ($files)
          /bin/rm -f   `basename $file`
          /bin/rm -f    dummy
          /bin/cp $file dummy
              cat       dummy | sed -e "s|/L72/|/L${AGCM_LM}/|g" | sed -e "s|z72|z${AGCM_LM}|g" > `basename $file`
        end
    endif

endif


# Select the proper ExtData resource file
# when MERRA2 datasets are selected.
#----------------------------------------
if( ${DRIVING_DATASETS} == MERRA2) then
    set startYear = `cat cap_restart | cut -c1-4`
    set oldstring = `cat CTM_CAP.rc | grep EXTDATA_CF:`
    set COMPNAME = `grep COMPNAME CTM_CAP.rc | awk '{print $2}'`

    if( $startYear > 1979 && $startYear < 1992 ) then
        set sYear  = 1980
        set sMonth = jan79
        set MERRA2type = MERRA2_100
        set data_Transition_Date = 19920101
    else if( $startYear > 1991 && $startYear < 2000 ) then
        set sYear  = 1992
        set sMonth = jan91
        set MERRA2type = MERRA2_200
        set data_Transition_Date = 20000101
    else if( $startYear > 1999 && $startYear < 2010 ) then
        set sYear  = 2000
        set sMonth = jan00
        set MERRA2type = MERRA2_300
        set data_Transition_Date = 20100101
    else if( $startYear > 2009 ) then
        set sYear  = 2010
        set sMonth = jan10
        set MERRA2type = MERRA2_400
        set data_Transition_Date = 20200101
    endif

    set newstring = "EXTDATA_CF: ${COMPNAME}_ExtData_${sYear}.rc"

    # Edit the CAP.rc file
    #---------------------
    /bin/mv CTM_CAP.rc CTM_CAP.tmp
    cat CTM_CAP.tmp | sed -e "s?$oldstring?$newstring?g" > CTM_CAP.rc
    rm -f CTM_CAP.tmp

    # Transition into a new decade
    #-----------------------------
    if( $nymdf > ${data_Transition_Date} ) then
        set nymdf = ${data_Transition_Date}
        set oldstring = `cat CAP.rc | grep END_DATE:`
        set newstring = "END_DATE: $nymdf $nhmsf"
        /bin/mv CTM_CAP.rc CTM_CAP.tmp
        cat CTM_CAP.tmp | sed -e "s?$oldstring?$newstring?g" > CTM_CAP.rc
        rm -f CTM_CAP.tmp
    endif

    # Edit the ExtData.rc file
    #-------------------------
    set tFILE = tmpfile
    rm -f $tFILE
    cat MERRA2_ExtData.rc.tmpl > $tFILE
    set sFILE = sedfile
    rm -f $sFILE
cat << EOF > $sFILE 
s/@sMonth/$sMonth/g
s/@MERRA2type/$MERRA2type/g
EOF

    sed -f $sFILE $tFILE > MAPL_ExtData_${sYear}.rc
    chmod 755  MAPL_ExtData_${sYear}.rc
    rm -f $tFILE
    rm -f $sFILE

# Concatenate required ExtData files
# ----------------------------------
if( ${doIdealizedPT} == YES) then
  cp MAPL_ExtData_${sYear}.rc ${COMPNAME}_ExtData_${sYear}.rc
else if (${doGEOSCHEMCHEM} == YES) then
  set EXTDATA_FILES = `/bin/ls -1 MAPL_ExtData_${sYear}.rc GOCARTdata_ExtData.rc WSUB_ExtData.rc BC_GridComp_ExtData.rc CO_GridComp_ExtData.rc CO2_GridComp_ExtData.rc DU_GridComp_ExtData.rc NI_GridComp_ExtData.rc OC_GridComp_ExtData.rc SU_GridComp_ExtData.rc GEOSCHEMchem_ExtData.rc`
  cat ${EXTDATA_FILES} > ${COMPNAME}_ExtData_${sYear}.rc

#  sed -i 's/QFED\/NRT/QFED/' ${COMPNAME}_ExtData_${sYear}.rc
#  sed -i 's/v2.5r1_0.1_deg/v2.5r1\/0.1/' ${COMPNAME}_ExtData_${sYear}.rc
else
  set EXTDATA_FILES = `/bin/ls -1 MAPL_ExtData_${sYear}.rc *_ExtData.rc`
  cat ${EXTDATA_FILES} > ${COMPNAME}_ExtData_${sYear}.rc
endif

endif


# if(-e ExtData.rc )    /bin/rm -f   ExtData.rc
# set  extdata_files = `/bin/ls -1 *_ExtData.rc`
# cat $extdata_files > ExtData.rc

# Link Boundary Conditions for Appropriate Date
# ---------------------------------------------
setenv YEAR $yearc
./linkbcs

if (! -e tile.bin) then
$RUN_CMD 1 $GEOSBIN/binarytile.x tile.data tile.bin
endif

#######################################################################
#                Split Saltwater Restart if detected
#######################################################################

if ( -e $EXPDIR/saltwater_internal_rst ) then

   # The splitter script requires an OutData directory
   # -------------------------------------------------
   if (! -d OutData ) mkdir -p OutData

   # Run the script
   # --------------
   $RUN_CMD 1 $GEOSBIN/SaltIntSplitter tile.data $EXPDIR/saltwater_internal_rst

   # Move restarts
   # -------------
   /bin/mv OutData/openwater_internal_rst OutData/seaicethermo_internal_rst .

   # Remove OutData
   # --------------
   /bin/rmdir OutData

   # Make decorated copies for restarts tarball
   # ------------------------------------------
   /bin/cp openwater_internal_rst    $EXPID.openwater_internal_rst.${edate}.${GCMVER}.${BCTAG}_${BCRSLV}
   /bin/cp seaicethermo_internal_rst $EXPID.seaicethermo_internal_rst.${edate}.${GCMVER}.${BCTAG}_${BCRSLV}

   # Inject decorated copies into restarts tarball
   # ---------------------------------------------
   tar rf $EXPDIR/restarts/restarts.${edate}.tar $EXPID.*.${edate}.${GCMVER}.${BCTAG}_${BCRSLV}

   # Remove the decorated restarts
   # -----------------------------
   /bin/rm $EXPID.*.${edate}.${GCMVER}.${BCTAG}_${BCRSLV}

endif


if ( -x $GEOSBIN/rs_numtiles.x ) then

   set N_SALT_TILES_EXPECTED = `grep '^ *0' tile.data | wc -l`
   set N_SALT_TILES_FOUND = `$RUN_CMD 1 $GEOSBIN/rs_numtiles.x openwater_internal_rst | grep Total | awk '{print $3}'`
         
   if ( $N_SALT_TILES_EXPECTED != $N_SALT_TILES_FOUND ) then
      echo "Error! Found $N_SALT_TILES_FOUND tiles in saltwater. Expect to find $N_SALT_TILES_EXPECTED tiles."
      echo "Your restarts are probably for a different ocean."
      exit 7
   endif    

endif


set NAS_BATCH = FALSE
if ($SITE == NAS) then
   if ($PBS_ENVIRONMENT == PBS_BATCH) then
      set NAS_BATCH = TRUE
   endif
endif

/bin/cp $EXPDIR/NUOPC_run_config.txt .
/bin/ln -s $EXPDIR/mediator_import_rst .

# Run GEOSgcm.x
# -------------
if( $USE_SHMEM == 1 ) $GEOSBIN/RmShmKeys_sshmpi.csh
@  NPES = ($AGCM_NX * $AGCM_NY) + ($CTM_NX * $CTM_NY)
if( $NAS_BATCH == TRUE ) then
   $RUN_CMD $NPES ./GEOSgcm.x >& $HOMDIR/gcm_run.$PBS_JOBID.$nymdc.out
else
   #totalview ./GEOSgcm-ctm.x
   $RUN_CMD $NPES ./GEOSgcm-ctm.x
endif
if( $USE_SHMEM == 1 ) $GEOSBIN/RmShmKeys_sshmpi.csh


if( -e EGRESS ) then
   set rc = 0
else
   set rc = -1
endif
echo GEOSgcm Run Status: $rc
exit
