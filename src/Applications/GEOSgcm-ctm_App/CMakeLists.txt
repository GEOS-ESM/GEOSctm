ecbuild_add_executable (
  TARGET GEOSgcm-ctm.x
  SOURCES GEOSgcm-ctm.F90 Driver.F90 Mediator.F90 Mediator_Interpolator.F90
  LIBS gftl-shared GEOSctm_GridComp GEOSgcm_GridComp
  )  
