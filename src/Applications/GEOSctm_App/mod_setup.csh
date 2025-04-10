#!/bin/csh -f

# This script modifies ctm_setup to make it look more like gcm_setup
# so it's easier to compare when editing

if ($1 == "BEGIN") then

# For easier comparison with gcm_setup:
sed -i -e "s/GEOSCTM_IM/AGCM_IM/g"                          ctm_setup
sed -i -e "s/GEOSCTM_JM/AGCM_JM/g"                          ctm_setup
sed -i -e "s/GEOSCTM_LM/AGCM_LM/g"                          ctm_setup
sed -i -e "s/CTMSETUP/GCMSETUP/g"                           ctm_setup
sed -i -e "s/ctm_setup/gcm_setup/g"                         ctm_setup
sed -i -e "s/GEOSctm/GEOSgcm/g"                             ctm_setup
sed -i -e "s/GEOSCTM_VERSION/AGCM_VERSION/g"                ctm_setup
sed -i -e "s/GEOSCTM_NF/AGCM_NF/g"                          ctm_setup
sed -i -e "s/GEOSCTM_GRIDNAME/AGCM_GRIDNAME/g"              ctm_setup
sed -i -e "s/CTMTAG/GEOSTAG/g"                              ctm_setup
sed -i -e "s/FORCECTM/FORCEGCM/g"                           ctm_setup
sed -i -e "s/ctm_run.j/gcm_run.j/g"                         ctm_setup
sed -i -e "s/ctm_post.j/gcm_post.j/g"                       ctm_setup
sed -i -e "s/ctm_plot.tmpl/gcm_plot.tmpl/g"                 ctm_setup
sed -i -e "s/ctm_moveplot.j/gcm_moveplot.j/g"               ctm_setup
sed -i -e "s/ctm_archive.j/gcm_archive.j/g"                 ctm_setup
sed -i -e "s/ctm_regress.j/gcm_regress.j/g"                 ctm_setup
sed -i -e "s/ctm_forecast.j/gcm_forecast.j/g"               ctm_setup
sed -i -e "s/ctm_plot.j/gcm_plot.j/g"                       ctm_setup
sed -i -e "s/CTMVER/GCMVER/g"                               ctm_setup

endif

if ($1 == "END") then

sed -i -e "s/AGCM_IM/GEOSCTM_IM/g"                          ctm_setup
sed -i -e "s/AGCM_JM/GEOSCTM_JM/g"                          ctm_setup
sed -i -e "s/AGCM_LM/GEOSCTM_LM/g"                          ctm_setup
sed -i -e "s/GCMSETUP/CTMSETUP/g"                           ctm_setup
sed -i -e "s/gcm_setup/ctm_setup/g"                         ctm_setup
sed -i -e "s/GEOSgcm.x/GEOSctm.x/g"                         ctm_setup
sed -i -e "s/AGCM_VERSION/GEOSCTM_VERSION/g"                ctm_setup
sed -i -e "s/AGCM_NF/GEOSCTM_NF/g"                          ctm_setup
sed -i -e "s/AGCM_GRIDNAME/GEOSCTM_GRIDNAME/g"              ctm_setup
sed -i -e "s/GEOSTAG/CTMTAG/g"                              ctm_setup
sed -i -e "s/FORCEGCM/FORCECTM/g"                           ctm_setup
sed -i -e "s/gcm_run.j/ctm_run.j/g"                         ctm_setup
sed -i -e "s/gcm_post.j/ctm_post.j/g"                       ctm_setup
sed -i -e "s/gcm_plot.tmpl/ctm_plot.tmpl/g"                 ctm_setup
sed -i -e "s/gcm_moveplot.j/ctm_moveplot.j/g"               ctm_setup
sed -i -e "s/gcm_archive.j/ctm_archive.j/g"                 ctm_setup
sed -i -e "s/gcm_regress.j/ctm_regress.j/g"                 ctm_setup
sed -i -e "s/gcm_forecast.j/ctm_forecast.j/g"               ctm_setup
sed -i -e "s/gcm_plot.j/ctm_plot.j/g"                       ctm_setup
sed -i -e "s/GCMVER/CTMVER/g"                               ctm_setup

endif
