#include "MAPL_Generic.h"

module synthetic_simple_driver
   use ESMF
   use NUOPC
   use NUOPC_Driver, &
      driver_routine_SS             => SetServices, &
      driver_label_SetModelServices => label_SetModelServices, &
      driver_label_SetRunSequence   => label_SetRunSequence

   use MAPL
   use MAPL_NUOPCWrapperMod, only: wrapper_ss => SetServices, init_wrapper
   ! use NUOPC_Connector, only: cplSS => cplSS => SetServices

   use Provider_GridCompMod, only: provider_set_services => SetServices

   use gFTL_StringVector

   implicit none
   private
   public SetServices

contains
   subroutine SetServices(driver, rc)
      type(ESMF_GridComp)  :: driver
      integer, intent(out) :: rc

      type(ESMF_Config)          :: config
      type(StringVector)         :: agcm_exports
      type(StringVectorIterator) :: iter

      rc = ESMF_SUCCESS

      print*,__FILE__,__LINE__
      ! NUOPC_Driver registers the generic methods
      call NUOPC_CompDerive(driver, driver_routine_SS, rc=rc)
      if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
            line=__LINE__, &
            file=__FILE__)) &
            return  ! bail out

      print*,__FILE__,__LINE__
      ! attach specializing method(s)
      call NUOPC_CompSpecialize(driver, specLabel=driver_label_SetModelServices, &
            specRoutine=SetModelServices, rc=rc)
      print*,__FILE__,__LINE__
      if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
            line=__LINE__, &
            file=__FILE__)) &
            return  ! bail out

      print*,__FILE__,__LINE__
      call NUOPC_CompSpecialize(driver, specLabel=driver_label_SetRunSequence, &
            specRoutine=SetRunSequence, rc=rc)
      if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
            line=__LINE__, &
            file=__FILE__)) &
            return  ! bail out

      print*,__FILE__,__LINE__
      ! set NUOPC configuration file
      config = ESMF_ConfigCreate(rc=rc)
      if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
            line=__LINE__, &
            file=__FILE__)) &
            return  ! bail out

      print*,__FILE__,__LINE__
      call ESMF_ConfigLoadFile(config, "NUOPC_run_config.txt", rc=rc)
      if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
            line=__LINE__, &
            file=__FILE__)) &
            return  ! bail out
      call ESMF_GridCompSet(driver, config=config, rc=rc)
      if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
            line=__LINE__, &
            file=__FILE__)) &
            return  ! bail out

      print*,__FILE__,__LINE__

   end subroutine SetServices

   subroutine SetModelServices(driver, rc)
      type(ESMF_GridComp)  :: driver
      integer, intent(out) :: rc

      type(ESMF_GridComp) :: comp
      type(ESMF_VM)       :: vm
      type(ESMF_Config)   :: config

      integer              :: i, n_pes
      integer, allocatable :: petlist(:)

      rc = ESMF_SUCCESS

      call set_clock(driver)

      ! Read GridComp configuration
      call ESMF_GridCompGet(driver, vm = vm, config = config, rc = rc)
      if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
            line=__LINE__, file=__FILE__)) return
      call ESMF_VMGet(vm, petCount = n_pes, rc = rc)
      if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
            line=__LINE__, file=__FILE__)) return

      allocate(petlist(n_pes))
      petlist = [0]

      ! Create the MAPL grid_comp
      print*,__FILE__,__LINE__,'petlist=[',petlist,']'
      call NUOPC_DriverAddComp(driver, "agcm", wrapper_ss, comp = comp, &
            petlist = petlist, rc = rc)
      print*,__FILE__,__LINE__
      if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
            line=__LINE__, file=__FILE__)) return
      print*,__FILE__,__LINE__
      call init_wrapper(wrapper_gc = comp, name = "agcm", &
            cap_rc_file = "AGCM_CAP.rc", root_set_services =provider_set_services, rc = rc)
      print*,__FILE__,__LINE__
      if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
            line=__LINE__, file=__FILE__)) return
      print*,__FILE__,__LINE__

   end subroutine SetModelServices

   subroutine set_clock(driver)
      type(ESMF_GridComp), intent(inout) :: driver

      type(ESMF_Time)         :: startTime
      type(ESMF_Time)         :: stopTime
      type(ESMF_TimeInterval) :: timeStep
      type(ESMF_Clock)        :: internalClock
      type(ESMF_Config)       :: config

      integer :: start_date_and_time(2), end_date_and_time(2), dt, file_unit, yy, mm, dd, h, m, s, rc

      ! Read the start time
      open(newunit = file_unit, file = "cap_restart", form = 'formatted', &
            status = 'old', action = 'read')
      read(file_unit, *) start_date_and_time
      close(file_unit)

      ! Set the start time
      call UnpackDateTime(start_date_and_time, yy, mm, dd, h, m, s)
      call ESMF_TimeSet(startTime, yy=yy, mm=mm, dd=dd, h=h, m=m, s=s, &
            calkindflag=ESMF_CALKIND_GREGORIAN, rc=rc)
      if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
            line=__LINE__, file=__FILE__)) return

      ! Read the end time
      call ESMF_GridCompGet(driver, config = config, rc = rc)
      if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
            line=__LINE__, file=__FILE__)) return
      call ESMF_ConfigGetAttribute(config, end_date_and_time(1), label = "end_date:", rc = rc)
      if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
            line=__LINE__, file=__FILE__)) return
      call ESMF_ConfigGetAttribute(config, end_date_and_time(2), label = "end_time:", rc = rc)
      if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
            line=__LINE__, file=__FILE__)) return

      ! Set the end time
      call UnpackDateTime(end_date_and_time, yy, mm, dd, h, m, s)
      call ESMF_TimeSet(stopTime, yy=yy, mm=mm, dd=dd, h=h, m=m, s=s, &
            calkindflag=ESMF_CALKIND_GREGORIAN, rc=rc)
      if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
            line=__LINE__, file=__FILE__)) return

      ! Read the interpolation time interval
      call ESMF_ConfigGetAttribute(config, dt, label = "interpolation_dt:", rc = rc)
      if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
            line=__LINE__, file=__FILE__)) return

      ! Create the driver clock
      call ESMF_TimeIntervalSet(timeStep, s=dt, rc=rc)
      if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
            line=__LINE__, file=__FILE__)) return

      internalClock = ESMF_ClockCreate(name="Driver Clock", timeStep = timeStep, &
            startTime=startTime, stopTime=stopTime, rc=rc)
      if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
            line=__LINE__, file=__FILE__)) return

      ! set the driver clock
      call ESMF_GridCompSet(driver, clock=internalClock, rc=rc)
      if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
            line=__LINE__, file=__FILE__)) return

   contains

      subroutine UnpackDateTime(DATETIME, YY, MM, DD, H, M, S)
         integer, intent(IN)  :: DATETIME(:)
         integer, intent(OUT) :: YY, MM, DD, H, M, S

         YY =     datetime(1)/10000
         MM = mod(datetime(1),10000)/100
         DD = mod(datetime(1),100)
         H  =     datetime(2)/10000
         M  = mod(datetime(2),10000)/100
         S  = mod(datetime(2),100)
         return
      end subroutine UnpackDateTime

   end subroutine set_clock

   subroutine SetRunSequence(driver, rc)
      type(ESMF_GridComp)  :: driver
      integer, intent(out) :: rc

      type(ESMF_Time)               :: startTime
      type(ESMF_Time)               :: stopTime
      type(ESMF_TimeInterval)       :: timeStep
      type(ESMF_Config)             :: config
      type(NUOPC_FreeFormat)        :: run_sequence_ff

      rc = ESMF_SUCCESS

      call ESMF_GridCompGet(driver, config=config, rc=rc)
      if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
            line=__LINE__, file=__FILE__)) return  ! bail out

      ! read the run sequence
      run_sequence_ff = NUOPC_FreeFormatCreate(config, label="run_sequence::", rc=rc)
      if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
            line=__LINE__, file=__FILE__)) return  ! bail out

      ! ingest FreeFormat run sequence
      call NUOPC_DriverIngestRunSequence(driver, run_sequence_ff, rc=rc)
      if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
            line=__LINE__, file=__FILE__)) return  ! bail out

      ! deallocate the read run sequence
      call NUOPC_FreeFormatDestroy(run_sequence_ff, rc=rc)
      if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
            line=__LINE__, file=__FILE__)) return  ! bail out

  end subroutine SetRunSequence

end module synthetic_simple_driver
