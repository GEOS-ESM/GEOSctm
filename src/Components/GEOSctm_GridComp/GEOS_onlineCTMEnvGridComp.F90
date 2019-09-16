#include "MAPL_Generic.h"
!-------------------------------------------------------------------------
!         NASA/GSFC, Software Systems Support Office, Code 610.3         !
!-------------------------------------------------------------------------
!BOP
!
! !MODULE: GEOS_ctmEnvGridComp -- Prepares derived variables for GEOSctm
!
! !INTERFACE:
!
module GEOS_onlineCTMEnvGridComp
  !
  ! !USES:
  use ESMF
  use MAPL_Mod
  use FV_StateMod, only : calcCourantNumberMassFlux => fv_computeMassFluxes
  use m_set_eta,  only : set_eta

  implicit none
  private

  ! !PUBLIC MEMBER FUNCTIONS:

  public SetServices

  !
  ! !DESCRIPTION:
  ! This GC is used to derive variables needed by the CTM GC children.
  !
  ! !AUTHORS:
  ! Jules.Kouatchou-1@nasa.gov
  !
  !EOP
  !-------------------------------------------------------------------------
  integer,  parameter :: r8     = 8
  integer,  parameter :: r4     = 4

  INTEGER, PARAMETER :: sp = SELECTED_REAL_KIND(6,30)
  INTEGER, PARAMETER :: dp = SELECTED_REAL_KIND(14,300)
  INTEGER, PARAMETER :: qp = SELECTED_REAL_KIND(18,400)

  real(r8), parameter :: RADIUS = MAPL_RADIUS
  real(r8), parameter :: PI     = MAPL_PI_R8
  real(r8), parameter :: D0_0   = 0.0_r8
  real(r8), parameter :: D0_5   = 0.5_r8
  real(r8), parameter :: D1_0   = 1.0_r8
  real(r8), parameter :: GPKG   = 1000.0d0
  real(r8), parameter :: MWTAIR =   28.96d0
  real(r8), parameter :: SecondsPerMinute = 60.0d0

  logical             :: enable_pTracers     = .FALSE.
  logical             :: output_forcingData  = .FALSE.
  character(len=ESMF_MAXSTR) :: metType ! MERRA2 or MERRA1 or FPIT or FP

  logical :: online_ctm = .false.
  !-------------------------------------------------------------------------
CONTAINS
  !-------------------------------------------------------------------------
  !BOP
  !
  ! !IROUTINE: SetServices -- Sets ESMF services for this component
  !
  ! !INTERFACE:
  !
  subroutine SetServices ( GC, RC )
    !
    ! !INPUT/OUTPUT PARAMETERS:
    type(ESMF_GridComp), intent(INOUT) :: GC  ! gridded component
    !
    ! !OUTPUT PARAMETERS:
    integer, intent(OUT)               :: RC  ! return code
    !
    ! !DESCRIPTION:  
    !   The SetServices for the CTM Der GC needs to register its
    !   Initialize and Run.  It uses the MAPL\_Generic construct for defining 
    !   state specs. 
    !
    !EOP
    !-------------------------------------------------------------------------
    !BOC
    !
    ! !LOCAL VARIABLES:
    integer                    :: STATUS
    type (ESMF_Config)         :: CF
    type (ESMF_Config)         :: configFile
    character(len=ESMF_MAXSTR) :: COMP_NAME
    CHARACTER(LEN=ESMF_MAXSTR) :: rcfilen = 'CTM_GridComp.rc'
    character(len=ESMF_MAXSTR) :: IAm = 'SetServices'

    ! Get my name and set-up traceback handle
    ! ---------------------------------------
    call ESMF_GridCompGet( GC, NAME=COMP_NAME, CONFIG=CF, RC=STATUS )
    VERIFY_(STATUS)
    Iam = trim(COMP_NAME) // TRIM(Iam)

    ! Register services for this component
    ! ------------------------------------
    call MAPL_GridCompSetEntryPoint ( GC, ESMF_METHOD_INITIALIZE, Initialize, __RC__ )
    call MAPL_GridCompSetEntryPoint ( GC, ESMF_METHOD_RUN,  Run,        __RC__ )

    configFile = ESMF_ConfigCreate(rc=STATUS )
    VERIFY_(STATUS)

    call ESMF_ConfigLoadFile(configFile, TRIM(rcfilen), rc=STATUS )
    VERIFY_(STATUS)

    call ESMF_ConfigGetAttribute(configFile, enable_pTracers,        &
         Default  = .FALSE.,                       &
         Label    = "ENABLE_pTracers:",     __RC__ )

    call ESMF_ConfigGetAttribute(configFile, output_forcingData,     &
         Default  = .FALSE.,                       &
         Label    = "output_forcingData:",  __RC__ )

    ! Type of meteological fields (MERRA2 or MERRA1 or FPIT or FP)
    call ESMF_ConfigGetAttribute(configFile, metType,             &
         Default  = 'MERRA2',           &
         Label    = "metType:",  __RC__ )


    IF ((TRIM(metType) == "F515_516") .OR. &
         (TRIM(metType) == "F5131")) metType = "FP"

    ! !IMPORT STATE:
    !------------------------------------------
    ! If we want vertical remapping must add PS
    !------------------------------------------
    call MAPL_AddImportSpec(GC,                              &
         SHORT_NAME        = 'PS',                           &
         LONG_NAME         = 'surface_pressure',             &
         UNITS             = 'Pa',                           &
         DIMS              = MAPL_DimsHorzOnly,              &
         VLOCATION         = MAPL_VLocationNone,    __RC__)

    call MAPL_AddImportSpec(GC,                              &
         SHORT_NAME        = 'AREA',                         &
         LONG_NAME         = 'agrid_cell_area',              &
         UNITS             = 'm+2',                          &
         DIMS              = MAPL_DimsHorzOnly,              &
         VLOCATION         = MAPL_VLocationNone,    RC=STATUS)
    VERIFY_(STATUS)

    call MAPL_AddImportSpec(GC,                                    &
         SHORT_NAME = 'Q',                                         &
         LONG_NAME  = 'specific_humidity',                         &
         UNITS      = 'kg kg-1',                                   &
         DIMS       = MAPL_DimsHorzVert,                           &
         VLOCATION  = MAPL_VLocationCenter,             RC=STATUS  )
    VERIFY_(STATUS)


    ! Online ctm can get these values directly from the advcore rather than computing them
    call MAPL_AddImportSpec ( gc,                              &
         SHORT_NAME = 'CX',                                        &
         LONG_NAME  = 'eastward_accumulated_courant_number',       &
         UNITS      = '1',                                         &
         PRECISION  = ESMF_KIND_R8,                                &
         DIMS       = MAPL_DimsHorzVert,                           &
         VLOCATION  = MAPL_VLocationCenter,             RC=STATUS  )
    VERIFY_(STATUS)

    call MAPL_AddImportSpec ( gc,                                  &
         SHORT_NAME = 'CY',                                        &
         LONG_NAME  = 'northward_accumulated_courant_number',      &
         UNITS      = '1',                                         &
         PRECISION  = ESMF_KIND_R8,                                &
         DIMS       = MAPL_DimsHorzVert,                           &
         VLOCATION  = MAPL_VLocationCenter,             RC=STATUS  )
    VERIFY_(STATUS)

    call MAPL_AddImportSpec ( gc,                                  &
         SHORT_NAME = 'MFX',                                       &
         LONG_NAME  = 'pressure_weighted_accumulated_eastward_mass_flux', &
         UNITS      = 'Pa m+2 s-1',                                &
         PRECISION  = ESMF_KIND_R8,                                &
         DIMS       = MAPL_DimsHorzVert,                           &
         VLOCATION  = MAPL_VLocationCenter,             RC=STATUS  )
    VERIFY_(STATUS)

    call MAPL_AddImportSpec ( gc,                                  &
         SHORT_NAME = 'MFY',                                       &
         LONG_NAME  = 'pressure_weighted_accumulated_northward_mass_flux', &
         UNITS      = 'Pa m+2 s-1',                                &
         PRECISION  = ESMF_KIND_R8,                                &
         DIMS       = MAPL_DimsHorzVert,                           &
         VLOCATION  = MAPL_VLocationCenter,             RC=STATUS  )
    VERIFY_(STATUS)

    call MAPL_AddImportSpec ( gc,                                  &
         SHORT_NAME = 'PLE0',                                      &
         LONG_NAME  = 'pressure_at_layer_edges_before_advection',  &
         UNITS      = 'Pa',                                        &
         PRECISION  = ESMF_KIND_R8,                                &
         DIMS       = MAPL_DimsHorzVert,                           &
         VLOCATION  = MAPL_VLocationEdge,             RC=STATUS  )
    VERIFY_(STATUS)

    call MAPL_AddImportSpec ( gc,                                  &
         SHORT_NAME = 'PLE1',                                      &
         LONG_NAME  = 'pressure_at_layer_edges_after_advection',   &
         UNITS      = 'Pa',                                        &
         PRECISION  = ESMF_KIND_R8,                                &
         DIMS       = MAPL_DimsHorzVert,                           &
         VLOCATION  = MAPL_VLocationEdge,             RC=STATUS  )
    VERIFY_(STATUS)

    IF ( (TRIM(metType) == 'MERRA2') .OR.  &
         (TRIM(metType) == 'FPIT')   .OR.  &
         (TRIM(metType) == 'FP')    ) THEN
       call MAPL_AddImportSpec(GC,                                    &
            SHORT_NAME         = 'ZLE',                               &
            LONG_NAME          = 'geopotential_height',               &
            UNITS              = 'm',                                 &
            DIMS               = MAPL_DimsHorzVert,                   &
            VLOCATION          = MAPL_VLocationEdge,       RC=STATUS  )
       VERIFY_(STATUS)
    END IF

    ! Only doing the Imports if we are not doing Idealized Passive Tracer
    !----------------------------------------------------------
    IF (.NOT. enable_pTracers) THEN
       IF (output_forcingData) THEN
       ENDIF
    END IF


    call MAPL_AddImportSpec ( gc,                                  &
         SHORT_NAME = 'TH',                                        &
         LONG_NAME  = 'potential_temperature',                     &
         UNITS      = 'K',                                         &
         DIMS       = MAPL_DimsHorzVert,                           &
         VLOCATION  = MAPL_VLocationCenter,             RC=STATUS  )
    VERIFY_(STATUS)

    call MAPL_AddImportSpec(GC, &
         SHORT_NAME         = 'LWI',  &
         LONG_NAME          = 'land-ocean-ice_mask',  &
         UNITS              = '1', &
         DIMS               = MAPL_DimsHorzOnly,    &
         VLOCATION          = MAPL_VLocationNone,    &
         RC=STATUS  )
    VERIFY_(STATUS)


    IF ( TRIM(metType) == 'MERRA1' ) THEN
       call MAPL_AddImportSpec(GC, &
            SHORT_NAME         = 'RH2',  &
            LONG_NAME          = 'relative_humidity_after_moist',  &
            UNITS              = '1', &
            DIMS               = MAPL_DimsHorzVert,    &
            VLOCATION          = MAPL_VLocationCenter,    &
            RC=STATUS  )
       VERIFY_(STATUS)
    END IF


    ! Exports if not doing Passive Tracer experiment
    !-----------------------------------------------
    IF (.NOT. enable_pTracers) THEN
       call MAPL_AddImportSpec(GC,                                 &
            SHORT_NAME= 'ITY',                                     &
            LONG_NAME = 'vegetation_type',                         &
            UNITS     = '1',                                       &
            DIMS      = MAPL_DimsHorzOnly,                         &
            VLOCATION = MAPL_VLocationNone,             RC=STATUS  )
       VERIFY_(STATUS)

       call MAPL_AddImportSpec(GC,                                 &
            SHORT_NAME='BYNCY',                                    &
            LONG_NAME ='buoyancy_of surface_parcel',               &
            UNITS     ='m s-2',                                    &
            DIMS      = MAPL_DimsHorzVert,                         &
            VLOCATION = MAPL_VLocationCenter,           RC=STATUS  )
       VERIFY_(STATUS)

       call MAPL_AddImportSpec ( gc,                                  &
            SHORT_NAME = 'CNV_QC',                                    &
            LONG_NAME  = 'grid_mean_convective_condensate',           &
            UNITS      = 'kg kg-1',                                   &
            DIMS       = MAPL_DimsHorzVert,                           &
            VLOCATION  = MAPL_VLocationCenter,             RC=STATUS  )
       VERIFY_(STATUS)

       call MAPL_AddImportSpec ( gc,                                  &
            SHORT_NAME = 'QCTOT',                                     &
            LONG_NAME  = 'mass_fraction_of_total_cloud_water',        &
            UNITS      = 'kg kg-1',                                   &
            DIMS       = MAPL_DimsHorzVert,                           &
            VLOCATION  = MAPL_VLocationCenter,             RC=STATUS  )
       VERIFY_(STATUS)

       call MAPL_AddImportSpec(GC,                                    &
            SHORT_NAME         = 'LFR',                                 &
            LONG_NAME          = 'lightning_flash_rate',                &
            UNITS              = 'km-2 s-1',                            &
            DIMS               = MAPL_DimsHorzOnly,                     &
            VLOCATION          = MAPL_VLocationNone,                    &
            RC=STATUS  )
       VERIFY_(STATUS)

       call MAPL_AddImportSpec(GC,                           &
            SHORT_NAME = 'QLCN',                              &
            LONG_NAME  = 'mass_fraction_of_convective_cloud_liquid_water', &
            UNITS      = 'kg kg-1',                           &
            DIMS       = MAPL_DimsHorzVert,                   &
            VLOCATION  = MAPL_VLocationCenter,  __RC__)

       call MAPL_AddImportSpec(GC,                           &
            SHORT_NAME = 'QICN',                              &
            LONG_NAME  = 'mass_fraction_of_convective_cloud_ice_water', &
            UNITS      = 'kg kg-1',                           &
            DIMS       = MAPL_DimsHorzVert,                   &
            VLOCATION  = MAPL_VLocationCenter, __RC__)

       call MAPL_AddImportSpec ( gc,                                                          &
            SHORT_NAME         = 'TROPP_BLENDED',                                             &
            LONG_NAME          = 'tropopause_pressure_based_on_blended_estimate',             &
            UNITS              = 'Pa',                                                        &
            DIMS               = MAPL_DimsHorzOnly,                                           &
            VLOCATION          = MAPL_VLocationNone,                                RC=STATUS )
       _VERIFY(STATUS)

       !---------------------------------------------------------
       ! Variables to export if output_forcingData is set to TRUE
       !---------------------------------------------------------
       IF (output_forcingData) THEN
       ENDIF ! output_forcingData
    END IF





    call MAPL_AddExportSpec ( gc,                                  &
         SHORT_NAME = 'CXr8',                                      &
         LONG_NAME  = 'eastward_accumulated_courant_number',       &
         UNITS      = '',                                          &
         PRECISION  = ESMF_KIND_R8,                                &
         DIMS       = MAPL_DimsHorzVert,                           &
         VLOCATION  = MAPL_VLocationCenter,             RC=STATUS  )
    VERIFY_(STATUS)

    call MAPL_AddExportSpec ( gc,                                  &
         SHORT_NAME = 'CYr8',                                      &
         LONG_NAME  = 'northward_accumulated_courant_number',      &
         UNITS      = '',                                          &
         PRECISION  = ESMF_KIND_R8,                                &
         DIMS       = MAPL_DimsHorzVert,                           &
         VLOCATION  = MAPL_VLocationCenter,             RC=STATUS  )
    VERIFY_(STATUS)

    call MAPL_AddExportSpec ( gc,                                  &
         SHORT_NAME = 'MFXr8',                                     &
         LONG_NAME  = 'pressure_weighted_accumulated_eastward_mass_flux', &
         UNITS      = 'Pa m+2 s-1',                                &
         PRECISION  = ESMF_KIND_R8,                                &
         DIMS       = MAPL_DimsHorzVert,                           &
         VLOCATION  = MAPL_VLocationCenter,             RC=STATUS  )
    VERIFY_(STATUS)

    call MAPL_AddExportSpec ( gc,                                  &
         SHORT_NAME = 'MFYr8',                                     &
         LONG_NAME  = 'pressure_weighted_accumulated_northward_mass_flux', &
         UNITS      = 'Pa m+2 s-1',                                &
         PRECISION  = ESMF_KIND_R8,                                &
         DIMS       = MAPL_DimsHorzVert,                           &
         VLOCATION  = MAPL_VLocationCenter,             RC=STATUS  )
    VERIFY_(STATUS)

    call MAPL_AddExportSpec ( gc,                                  &
         SHORT_NAME = 'PLE1r8',                                    &
         LONG_NAME  = 'pressure_at_layer_edges_after_advection',   &
         UNITS      = 'Pa',                                        &
         PRECISION  = ESMF_KIND_R8,                                &
         DIMS       = MAPL_DimsHorzVert,                           &
         VLOCATION  = MAPL_VLocationEdge,             RC=STATUS  )
    VERIFY_(STATUS)

    call MAPL_AddExportSpec ( gc,                                  &
         SHORT_NAME = 'PLE0r8',                                    &
         LONG_NAME  = 'pressure_at_layer_edges_before_advection',  &
         UNITS      = 'Pa',                                        &
         PRECISION  = ESMF_KIND_R8,                                &
         DIMS       = MAPL_DimsHorzVert,                           &
         VLOCATION  = MAPL_VLocationEdge,             RC=STATUS  )
    VERIFY_(STATUS)

    call MAPL_AddExportSpec ( gc,                                  &
         SHORT_NAME = 'PLE',                                       &
         LONG_NAME  = 'pressure_at_layer_edges',                   &
         UNITS      = 'Pa',                                        &
         DIMS       = MAPL_DimsHorzVert,                           &
         VLOCATION  = MAPL_VLocationEdge,             RC=STATUS  )
    VERIFY_(STATUS)

    call MAPL_AddExportSpec ( gc,                                  &
         SHORT_NAME = 'TH',                                        &
         LONG_NAME  = 'potential_temperature',                     &
         UNITS      = 'K',                                         &
         DIMS       = MAPL_DimsHorzVert,                           &
         VLOCATION  = MAPL_VLocationCenter,             RC=STATUS  )
    VERIFY_(STATUS)

    call MAPL_AddExportSpec(GC,                               &
         SHORT_NAME         = 'AIRDENS',                      &
         LONG_NAME          = 'air_density',                  &
         UNITS              = 'kg m-3',                       &
         DIMS               = MAPL_DimsHorzVert,              &
         VLOCATION          = MAPL_VLocationCenter,  RC=STATUS)
    VERIFY_(STATUS)

    call MAPL_AddExportSpec(GC, &
         SHORT_NAME         = 'LWI',  &
         LONG_NAME          = 'land-ocean-ice_mask',  &
         UNITS              = '1', &
         DIMS               = MAPL_DimsHorzOnly,    &
         VLOCATION          = MAPL_VLocationNone,    &
         RC=STATUS  )
    VERIFY_(STATUS)

    call MAPL_AddExportSpec(GC,                               &
         SHORT_NAME         = 'MASS',                         &
         LONG_NAME          = 'total_mass',                   &
         UNITS              = 'kg',                           &
         DIMS               = MAPL_DimsHorzVert,              &
         VLOCATION          = MAPL_VLocationCenter,  RC=STATUS)
    VERIFY_(STATUS)

    IF ( TRIM(metType) == 'MERRA1' ) THEN
       call MAPL_AddExportSpec(GC, &
            SHORT_NAME         = 'RH2',  &
            LONG_NAME          = 'relative_humidity_after_moist',  &
            UNITS              = '1', &
            DIMS               = MAPL_DimsHorzVert,    &
            VLOCATION          = MAPL_VLocationCenter,    &
            RC=STATUS  )
       VERIFY_(STATUS)
    END IF

    call MAPL_AddExportSpec(GC,                                    &
         SHORT_NAME         = 'ZLE',                               &
         LONG_NAME          = 'geopotential_height',               &
         UNITS              = 'm',                                 &
         DIMS               = MAPL_DimsHorzVert,                   &
         VLOCATION          = MAPL_VLocationEdge,       RC=STATUS  )
    VERIFY_(STATUS)

    ! Exports if not doing Passive Tracer experiment
    !-----------------------------------------------
    IF (.NOT. enable_pTracers) THEN
       call MAPL_AddExportSpec(GC,                                 &
            SHORT_NAME= 'ITY',                                     &
            LONG_NAME = 'vegetation_type',                         &
            UNITS     = '1',                                       &
            DIMS      = MAPL_DimsHorzOnly,                         &
            VLOCATION = MAPL_VLocationNone,             RC=STATUS  )
       VERIFY_(STATUS)

       call MAPL_AddExportSpec(GC,                                 &
            SHORT_NAME='BYNCY',                                    &
            LONG_NAME ='buoyancy_of surface_parcel',               &
            UNITS     ='m s-2',                                    &
            DIMS      = MAPL_DimsHorzVert,                         &
            VLOCATION = MAPL_VLocationCenter,           RC=STATUS  )
       VERIFY_(STATUS)

       call MAPL_AddExportSpec ( gc,                                  &
            SHORT_NAME = 'CNV_QC',                                    &
            LONG_NAME  = 'grid_mean_convective_condensate',           &
            UNITS      = 'kg kg-1',                                   &
            DIMS       = MAPL_DimsHorzVert,                           &
            VLOCATION  = MAPL_VLocationCenter,             RC=STATUS  )
       VERIFY_(STATUS)

       call MAPL_AddExportSpec ( gc,                                  &
            SHORT_NAME = 'QCTOT',                                     &
            LONG_NAME  = 'mass_fraction_of_total_cloud_water',        &
            UNITS      = 'kg kg-1',                                   &
            DIMS       = MAPL_DimsHorzVert,                           &
            VLOCATION  = MAPL_VLocationCenter,             RC=STATUS  )
       VERIFY_(STATUS)

       call MAPL_AddExportSpec(GC,                                    &
            SHORT_NAME         = 'LFR',                                 &
            LONG_NAME          = 'lightning_flash_rate',                &
            UNITS              = 'km-2 s-1',                            &
            DIMS               = MAPL_DimsHorzOnly,                     &
            VLOCATION          = MAPL_VLocationNone,                    &
            RC=STATUS  )
       VERIFY_(STATUS)

       call MAPL_AddExportSpec(GC,                           &
            SHORT_NAME = 'QLCN',                              &
            LONG_NAME  = 'mass_fraction_of_convective_cloud_liquid_water', &
            UNITS      = 'kg kg-1',                           &
            DIMS       = MAPL_DimsHorzVert,                   &
            VLOCATION  = MAPL_VLocationCenter,  __RC__)

       call MAPL_AddExportSpec(GC,                           &
            SHORT_NAME = 'QICN',                              &
            LONG_NAME  = 'mass_fraction_of_convective_cloud_ice_water', &
            UNITS      = 'kg kg-1',                           &
            DIMS       = MAPL_DimsHorzVert,                   &
            VLOCATION  = MAPL_VLocationCenter, __RC__)

       call MAPL_AddExportSpec ( gc,                                                          &
            SHORT_NAME         = 'TROPP',                                                     &
            LONG_NAME          = 'tropopause_pressure_based_on_blended_estimate',             &
            UNITS              = 'Pa',                                                        &
            DIMS               = MAPL_DimsHorzOnly,                                           &
            VLOCATION          = MAPL_VLocationNone,                                RC=STATUS )
       _VERIFY(STATUS)

       !---------------------------------------------------------
       ! Variables to export if output_forcingData is set to TRUE
       !---------------------------------------------------------
       IF (output_forcingData) THEN
       ENDIF ! output_forcingData
    END IF


    ! Set the Profiling timers
    !-------------------------
    call MAPL_TimerAdd(GC,    name="INITIALIZE"  ,RC=STATUS)
    VERIFY_(STATUS)
    call MAPL_TimerAdd(GC,    name="RUN"         ,RC=STATUS)
    VERIFY_(STATUS)

    ! Create children's gridded components and invoke their SetServices
    ! -----------------------------------------------------------------
    call MAPL_GenericSetServices    ( GC, RC=STATUS )
    VERIFY_(STATUS)

    RETURN_(ESMF_SUCCESS)

  end subroutine SetServices

  subroutine Initialize ( GC, IMPORT, EXPORT, CLOCK, RC )

    type(ESMF_GridComp), intent(inout) :: GC     ! Gridded component 
    type(ESMF_State),    intent(inout) :: IMPORT ! Import state
    type(ESMF_State),    intent(inout) :: EXPORT ! Export state
    type(ESMF_Clock),    intent(inout) :: CLOCK  ! The clock

    integer, optional,   intent(  out) :: RC     ! Error code

    __Iam__('Initialize')
    character(len=ESMF_MAXSTR)    :: COMP_NAME
    type(ESMF_Grid)               :: esmfGrid
    type (ESMF_VM)                :: VM
    integer                       :: im, jm, km
    type(MAPL_MetaComp), pointer  :: ggState      ! GEOS Generic State
    type (ESMF_Config)            :: CF
    integer                       :: dims(3)

    !  Get my name and set-up traceback handle
    !  ---------------------------------------
    call ESMF_GridCompGet( GC, NAME=COMP_NAME, CONFIG=CF, VM=VM, RC=STATUS )
    VERIFY_(STATUS)
    Iam = TRIM(COMP_NAME)//"::Initialize"

    !  Initialize GEOS Generic
    !  ------------------------
    call MAPL_GenericInitialize ( gc, IMPORT, EXPORT, clock,  RC=STATUS )
    VERIFY_(STATUS)

    !  Get my internal MAPL_Generic state
    !  -----------------------------------
    call MAPL_GetObjectFromGC ( GC, ggState, RC=STATUS)
    VERIFY_(STATUS)

    call MAPL_TimerOn(ggSTATE,"TOTAL")
    call MAPL_TimerOn(ggSTATE,"INITIALIZE")

    ! Get the grid related information
    !---------------------------------
    call ESMF_GridCompGet ( GC, GRID=esmfGrid, rc=STATUS)
    VERIFY_(STATUS)

    call MAPL_GridGet ( esmfGrid, globalCellCountPerDim=dims, RC=STATUS)
    VERIFY_(STATUS)

    im = dims(1)
    jm = dims(2)
    km = dims(3)

    call MAPL_TimerOff(ggSTATE,"INITIALIZE")
    call MAPL_TimerOff(ggSTATE,"TOTAL")

    RETURN_(ESMF_SUCCESS)

  end subroutine Initialize


  subroutine Run ( GC, IMPORT, EXPORT, CLOCK, RC )
    !
    ! !INPUT/OUTPUT PARAMETERS:
    type(ESMF_GridComp), intent(inout) :: GC     ! Gridded component 
    type(ESMF_State),    intent(inout) :: IMPORT ! Import state
    type(ESMF_State),    intent(inout) :: EXPORT ! Export state
    type(ESMF_Clock),    intent(inout) :: CLOCK  ! The clock
    !
    ! !OUTPUT PARAMETERS:
    integer, optional,   intent(  out) :: RC     ! Error code

    character(len=ESMF_MAXSTR)      :: IAm = "Run"
    integer                         :: STATUS
    character(len=ESMF_MAXSTR)      :: COMP_NAME
    type (MAPL_MetaComp), pointer   :: ggState
    type (ESMF_Grid)                :: esmfGrid

    real(r8), pointer, dimension(:,:,:) ::     mfx => null()
    real(r8), pointer, dimension(:,:,:) ::     mfy => null()
    real(r8), pointer, dimension(:,:,:) ::     MFXr8 => null()
    real(r8), pointer, dimension(:,:,:) ::     MFYr8 => null()

    real(r8), pointer, dimension(:,:,:) ::      cx => null()
    real(r8), pointer, dimension(:,:,:) ::      cy => null()
    real(r8), pointer, dimension(:,:,:) ::      CXr8 => null()
    real(r8), pointer, dimension(:,:,:) ::      CYr8 => null()

    real(r8), pointer, dimension(:,:,:) :: ple0r8_in => null()
    real(r8), pointer, dimension(:,:,:) :: ple1r8_in => null()
    real(r8), pointer, dimension(:,:,:) :: PLE0r8 => null()
    real(r8), pointer, dimension(:,:,:) :: PLE1r8 => null()
    real,     pointer, dimension(:,:,:) :: PLE => null()

    real, pointer, dimension(:,:)   ::  cellArea => null()

    real, pointer, dimension(:,:,:) :: ZLE => null()
    real, pointer, dimension(:,:,:) :: ZLE_in => null()

    real, pointer, dimension(:,:,:) :: RH2 => null()

    real, pointer, dimension(:,:,:) :: QICN => null()
    real, pointer, dimension(:,:,:) :: QICN_in => null()
    
    real, pointer, dimension(:,:,:) :: QLCN => null()
    real, pointer, dimension(:,:,:) :: QLCN_in => null()

    real, pointer, dimension(:,:,:) :: QCTOT => null()
    real, pointer, dimension(:,:,:) :: QCTOT_in => null()

    real, pointer, dimension(:,:) :: LWI => null()
    real, pointer, dimension(:,:) :: LWI_in => null()

    real, pointer, dimension(:,:,:) :: TH => null()
    real, pointer, dimension(:,:,:) :: TH_in => null()

    real, pointer, dimension(:,:,:) :: airdens => null()

    real, pointer, dimension(:,:,:) :: cnv_qc => null()
    real, pointer, dimension(:,:,:) :: cnv_qc_in => null()

    real, pointer, dimension(:,:,:) :: byncy => null()
    real, pointer, dimension(:,:,:) :: byncy_in => null()

    real, pointer, dimension(:,:) :: lfr => null()
    real, pointer, dimension(:,:) :: lfr_in => null()

    real, pointer, dimension(:,:) :: ITY => null()
    real, pointer, dimension(:,:) :: ITY_in => null()

    real, pointer, dimension(:,:,:) :: MASS => null()
    real, pointer, dimension(:,:,:) :: q => null()

    real, pointer, dimension(:,:) :: tropp_in => null(), tropp => null()

    integer :: k, lm
    real(r8) :: DT

    ! Get the target components name and set-up traceback handle.
    ! -----------------------------------------------------------
    call ESMF_GridCompGet ( GC, name=COMP_NAME, Grid=esmfGrid, RC=STATUS )
    VERIFY_(STATUS)
    Iam = trim(COMP_NAME) // TRIM(Iam)

    ! Get my internal MAPL_Generic state
    !-----------------------------------
    call MAPL_GetObjectFromGC ( GC, ggState, __RC__ )

    call MAPL_TimerOn(ggState,"TOTAL")
    call MAPL_TimerOn(ggState,"RUN")

    !-----------------------------
    ! Required Imports and Exports
    !-----------------------------

    call MAPL_GetPointer ( IMPORT, cellArea,  'AREA', __RC__ )

    call MAPL_GetPointer(import, mfx, "MFX", __RC__)
    call MAPL_GetPointer(import, mfy, "MFY", __RC__)
    call MAPL_GetPointer(import, cx, "CX", __RC__)
    call MAPL_GetPointer(import, cy, "CY", __RC__)
    call MAPL_GetPointer(import, ple0r8_in, "PLE0", __RC__)
    call MAPL_GetPointer(import, ple1r8_in, "PLE1", __RC__)


    call MAPL_GetPointer ( EXPORT,     PLE,    'PLE', __RC__ )
    call MAPL_GetPointer ( EXPORT,  PLE0r8, 'PLE0r8', __RC__ )
    call MAPL_GetPointer ( EXPORT,  PLE1r8, 'PLE1r8', __RC__ )
    call MAPL_GetPointer ( EXPORT,   MFXr8,  'MFXr8', __RC__ )
    call MAPL_GetPointer ( EXPORT,   MFYr8,  'MFYr8', __RC__ )
    call MAPL_GetPointer ( EXPORT,    CXr8,   'CXr8', __RC__ )
    call MAPL_GetPointer ( EXPORT,    CYr8,   'CYr8', __RC__ )

    mfxr8 = mfx
    mfyr8 = mfy
    cxr8 = cx
    cyr8 = cy
    ple = ple0r8_in
    ple0r8 = ple0r8_in
    ple1r8 = ple1r8_in

    call MAPL_GetPointer(import, LWI_in, 'LWI', alloc = .true., __RC__)
    call MAPL_GetPointer(EXPORT, LWI, 'LWI', alloc = .true., __RC__)
    lwi = lwi_in

    IF ( (TRIM(metType) == 'MERRA2') .OR.  &
         (TRIM(metType) == 'FPIT')   .OR.  &
         (TRIM(metType) == 'FP')    ) THEN
       call MAPL_GetPointer(IMPORT, ZLE_in, 'ZLE', __RC__ )
       call MAPL_GetPointer(EXPORT, ZLE, 'ZLE', ALLOC = .true., __RC__ )
       zle = zle_in

    ELSEIF ( TRIM(metType) == 'MERRA1') THEN

       call MAPL_GetPointer ( EXPORT,    RH2,    'RH2', ALLOC=.TRUE., __RC__ )
       call MAPL_GetPointer ( EXPORT,    ZLE,    'ZLE', ALLOC=.TRUE., __RC__ )

       !call compute_ZLE_RH2 (ZLE, RH2, TH, Q, PLE, ie-is+1, je-js+1, LM)
    END IF

    call MAPL_GetPointer(import, TH_in, "TH", __RC__)
    call MAPL_GetPointer ( EXPORT, TH, 'TH', ALLOC=.TRUE., __RC__  )
    TH = th_in

    call MAPL_GetPointer(import, q, "Q", __RC__)   
    
    
    call MAPL_GetPointer(EXPORT, AIRDENS, 'AIRDENS', ALLOC=.TRUE., __RC__)
    call airdens_(airdens, ple, th, q)

    call MAPL_GetPointer ( EXPORT, MASS, 'MASS', ALLOC=.TRUE., __RC__ )

    lm = size(TH, 3)
    do k = 1, lm
       mass(:,:,k) = airdens(:,:,k) * cellarea(:,:) * (zle(:,:,k-1) - zle(:,:,k))
    end do

    if (.not. enable_ptracers) then
       
       call MAPL_GetPointer(import, QICN_in, 'QICN', __RC__)
       call MAPL_GetPointer(EXPORT, QICN, 'QICN', ALLOC=.TRUE., __RC__)
       qicn = qicn_in
       
       call MAPL_GetPointer(import, QLCN_in, 'QLCN', __RC__)           
       call MAPL_GetPointer(EXPORT, QLCN, 'QLCN', ALLOC=.TRUE., __RC__)
       qlcn = qlcn_in

       call MAPL_GetPointer(import, qctot_in, 'QCTOT', __RC__)  
       call MAPL_GetPointer(EXPORT, QCTOT, 'QCTOT', ALLOC=.TRUE., __RC__)
       qctot = qctot_in

       call MAPL_GetPointer(import, cnv_qc_in, 'CNV_QC', __RC__)
       call MAPL_GetPointer(EXPORT, CNV_QC, 'CNV_QC', ALLOC=.TRUE., __RC__)
       cnv_qc = cnv_qc_in

       call MAPL_GetPointer(import, ity_in, 'ITY', __RC__)
       call MAPL_GetPointer(EXPORT, ITY, 'ITY', ALLOC=.TRUE., __RC__)
       ITY = ity_in

       call MAPL_GetPointer(import, lfr_in, 'LFR', __RC__)
       call MAPL_GetPointer(EXPORT, LFR, 'LFR', ALLOC=.TRUE.,  __RC__)
       lfr = lfr_in
       
       call MAPL_GetPointer(import, byncy_in, 'BYNCY', __RC__)
       call MAPL_GetPointer(EXPORT, BYNCY, 'BYNCY', ALLOC=.TRUE., __RC__)
       byncy = byncy_in

       call MAPL_GetPointer(import, tropp_in, 'TROPP_BLENDED', __RC__)
       call MAPL_GetPointer(export, tropp, 'TROPP', __RC__)
       tropp = tropp_in

       if (output_forcingdata) then
       end if

    end if

    call MAPL_TimerOff(ggState,"RUN")
    call MAPL_TimerOff(ggState,"TOTAL")

    ! All Done
    ! --------
    RETURN_(ESMF_SUCCESS)

  end subroutine Run


  subroutine airdens_ (AIRDENS, PLE, TH, Q)
    real,    intent(in) :: PLE(:,:,:)   ! pressure edges
    real,    intent(in) :: TH(:,:,:)      ! (dry) potential temperature
    real,    intent(in) :: Q(:,:,:)       ! apecific humidity

    real,    intent(out) :: AIRDENS(:,:,:)    ! air density [kg/m3]

    integer :: k, lm
    real :: eps
    integer :: STATUS
    character(len=ESMF_MAXSTR)      :: IAm = "airdens_"
    real, allocatable :: npk(:,:,:) ! normalized pk = (PLE/p0)^kappa

    allocate(npk, mold = ple, stat=STATUS) ! work space

    eps = MAPL_RVAP / MAPL_RGAS - 1.0
    npk = (PLE/MAPL_P00)**MAPL_KAPPA

    lm = size(TH, 3)

    do k = 1, lm
       AIRDENS(:,:,k) =       ( PLE(:,:,k+1) - PLE(:,:,k) ) /      &
            ( MAPL_CP * ( TH(:,:,k)*(1. + eps*Q(:,:,k) ) ) &
            * ( npk(:,:,k+1) - npk(:,:,k) ) )
    end do

  end subroutine airdens_

  !-----------------------------------------------------------------------
  !BOP
  !
  subroutine compute_ZLE_RH2 (ZLE, RH2, TH, Q, PLE, IM, JM, LM)

    use GEOS_UtilsMod

    integer,                     intent(in)  :: IM,JM,LM
    real, dimension(IM,JM,LM),   intent(in)  :: TH  ! potential temperature
    real, dimension(IM,JM,LM),   intent(in)  :: Q   ! specific humidity
    real, dimension(IM,JM,0:LM), intent(in)  :: PLE   ! pressure
    real, dimension(IM,JM,LM),   intent(out) :: RH2   ! relative humidity
    real, dimension(IM,JM,0:LM), intent(out) :: ZLE   ! geopotential height
    !EOP
    !-----------------------------------------------------------------------
    !BOC
    integer                         :: L
    real,    dimension(IM,JM,  LM)  :: PLO, PK
    real,    dimension(IM,JM,  LM)  :: ZLO
    real,    dimension(IM,JM,0:LM)  :: CNV_PLE
    real,    dimension(IM,JM,0:LM)  :: PKE

    CNV_PLE  = PLE*.01
    PLO      = 0.5*(CNV_PLE(:,:,0:LM-1) +  CNV_PLE(:,:,1:LM  ) )
    PKE      = (CNV_PLE/1000.)**(MAPL_RGAS/MAPL_CP)
    PK       = (PLO/1000.)**(MAPL_RGAS/MAPL_CP)

    ZLE(:,:,LM) = 0.0
    do L=LM,1,-1
       ZLE(:,:,L-1) = TH (:,:,L) * (1.+MAPL_VIREPS*Q(:,:,L))
       ZLO(:,:,L  ) = ZLE(:,:,L) + (MAPL_CP/MAPL_GRAV)*( PKE(:,:,L)-PK (:,:,L  ) ) * ZLE(:,:,L-1)
       ZLE(:,:,L-1) = ZLO(:,:,L) + (MAPL_CP/MAPL_GRAV)*( PK (:,:,L)-PKE(:,:,L-1) ) * ZLE(:,:,L-1)
    end do

    RH2     = max(MIN( Q/GEOS_QSAT (TH*PK, PLO) , 1.02 ),0.0)

    return

  end subroutine compute_ZLE_RH2
  !EOC
  !-----------------------------------------------------------------------
end module GEOS_onlineCTMEnvGridComp
