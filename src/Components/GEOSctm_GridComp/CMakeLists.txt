esma_set_this ()

set (alldirs
  CTMconvection_GridComp
  CTMdiffusion_GridComp
  CTMpTracers_GridComp
  )

set (FV_PRECISION R8)
esma_add_library (${this}
  SRCS GEOS_ctmEnvGridComp.F90 GEOS_ctmGridCompMod.F90 GEOS_onlineCTMEnvGridComp.F90
  SUBCOMPONENTS ${alldirs}
  SUBDIR @GEOSgcm_GridComp
  DEPENDENCIES FVdycoreCubed_GridComp MAPL_Base)
