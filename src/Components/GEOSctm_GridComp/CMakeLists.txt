esma_set_this ()

ecbuild_declare_project()

set (alldirs
  GEOSchem_GridComp
  FVdycoreCubed_GridComp
  CTMconvection_GridComp
  CTMdiffusion_GridComp
  CTMpTracers_GridComp
  )

set (FV_PRECISION R8)
esma_add_library (${this}
  SRCS GEOS_ctmEnvGridComp.F90 GEOS_ctmHistGridComp.F90 GEOS_ctmGridCompMod.F90
  SUBCOMPONENTS ${alldirs}
  DEPENDENCIES FVdycoreCubed_GridComp MAPL)

ecbuild_install_project(NAME GEOSctm_GridComp)
