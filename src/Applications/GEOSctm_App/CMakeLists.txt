ecbuild_add_executable (
  TARGET GEOSctm.x
  SOURCES GEOSctm.F90
  LIBS GEOSctm_GridComp
  )  

set (CMAKE_Fortran_FLAGS_RELEASE "${GEOS_Fortran_FLAGS_VECT}")

#link_directories (${MKL_LIBRARIES})
target_link_libraries (GEOSctm.x ${OpenMP_Fortran_LIBRARIES})
set_target_properties(GEOSctm.x PROPERTIES LINK_FLAGS "${OpenMP_Fortran_FLAGS}")
target_include_directories (GEOSctm.x PUBLIC ${INC_ESMF})

file (GLOB templates CONFIGURE_DEPENDS *.tmpl)

set (programs
   ctm_run.j
   ctm_regress.j
   ctm_post.j
   ctm_archive.j
   ctm_convert.j
   ctm_quickplot.csh
   ctm_moveplot.j
   )

install (
   FILES ${templates}
   DESTINATION etc
   )

install (
   PROGRAMS ${programs}
   DESTINATION bin
   )

install (
   FILES fvcore_layout.rc logging.yaml
   DESTINATION etc
   )
   
if(HYDROSTATIC)
   set(CFG_HYDROSTATIC TRUE)
else()
   set(CFG_HYDROSTATIC FALSE)
endif()

set (setup_scripts
   ctm_setup
   )

foreach (file ${setup_scripts})
   configure_file(${file} ${file} @ONLY)
   install(PROGRAMS ${CMAKE_CURRENT_BINARY_DIR}/${file} DESTINATION bin)
endforeach ()


configure_file(.GEOSCTM_VERSION .GEOSCTM_VERSION @ONLY)
install(PROGRAMS ${CMAKE_CURRENT_BINARY_DIR}/.GEOSCTM_VERSION DESTINATION etc)
