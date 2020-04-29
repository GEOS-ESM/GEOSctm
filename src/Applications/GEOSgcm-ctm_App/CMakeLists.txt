ecbuild_add_executable (
  TARGET GEOSgcm-ctm.x
  SOURCES GEOSgcm-ctm.F90 Driver.F90 Mediator.F90 Mediator_Interpolator.F90
  LIBS gftl-shared GEOSctm_GridComp GEOSgcm_GridComp
  )  
ecbuild_add_executable (
  TARGET SyntheticApp.x
  SOURCES SyntheticApp.F90 Synthetic_Driver.F90 Mediator.F90 Mediator_Interpolator.F90 Provider_GridComp.F90 Reciever_GridComp.F90
  LIBS gftl-shared MAPL
  )  
ecbuild_add_executable (
  TARGET SyntheticSimpleApp.x
  SOURCES SyntheticSimpleApp.F90 Synthetic_Simple_Driver.F90 Provider_GridComp.F90
  LIBS gftl-shared MAPL
  )  
