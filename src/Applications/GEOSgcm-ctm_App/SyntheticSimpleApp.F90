program prototype
   use ESMF
   use NUOPC
   use synthetic_simple_driver, only: driverSS => SetServices
   use iso_fortran_env, only: int64
   use MAPL_Profiler, only: get_global_time_profiler, BaseProfiler, TimeProfiler 

   implicit none
   include "mpif.h"

   integer :: rc, urc, rank, file_unit
   integer(int64) :: t0, t1, count_rate
   real :: elapsed_time
   type(ESMF_GridComp)     :: esmComp
   class (BaseProfiler), pointer :: t_p

   call mpi_init(rc)

   call mpi_comm_rank(MPI_COMM_WORLD, rank, rc)

   if (rank == 0) then
      call system_clock(t0)
   end if

   t_p => get_global_time_profiler()
   t_p = TimeProfiler('All', comm_world = MPI_COMM_WORLD)
   call t_p%start()

   ! Initialize ESMF

   call ESMF_Initialize(logkindflag=ESMF_LOGKIND_MULTI, rc=rc)
   if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
         line=__LINE__, &
         file=__FILE__)) &
         call ESMF_Finalize(endflag=ESMF_END_ABORT)

   call ESMF_LogWrite("esmApp STARTING", ESMF_LOGMSG_INFO, rc=rc)
   if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
         line=__LINE__, &
         file=__FILE__)) &
         call ESMF_Finalize(endflag=ESMF_END_ABORT)

   ! Create the earth system Component
   esmComp = ESMF_GridCompCreate(name="esm", rc=rc)
   if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
         line=__LINE__, &
         file=__FILE__)) &
         call ESMF_Finalize(endflag=ESMF_END_ABORT)

   ! SetServices for the earth system Component
   call ESMF_GridCompSetServices(esmComp, driverSS, userRc=urc, rc=rc)
   if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
         line=__LINE__, &
         file=__FILE__)) &
         call ESMF_Finalize(endflag=ESMF_END_ABORT)
   if (ESMF_LogFoundError(rcToCheck=urc, msg=ESMF_LOGERR_PASSTHRU, &
         line=__LINE__, &
         file=__FILE__)) &
         call ESMF_Finalize(endflag=ESMF_END_ABORT)

!!$   ! Set Profiling Attribute
!!$   call NUOPC_CompAttributeSet(esmComp, name="Profiling", value="0", rc=rc)
!!$   if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
!!$         line=__LINE__, &
!!$         file=__FILE__)) &
!!$         call ESMF_Finalize(endflag=ESMF_END_ABORT)
!!$
   ! Call Initialize for the earth system Component
   call ESMF_GridCompInitialize(esmComp, userRc=urc, rc=rc)
   if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
         line=__LINE__, &
         file=__FILE__)) &
         call ESMF_Finalize(endflag=ESMF_END_ABORT)
   if (ESMF_LogFoundError(rcToCheck=urc, msg=ESMF_LOGERR_PASSTHRU, &
         line=__LINE__, &
         file=__FILE__)) &
         call ESMF_Finalize(endflag=ESMF_END_ABORT)

   ! Call Run  for earth the system Component
   call ESMF_GridCompRun(esmComp, userRc=urc, rc=rc)
   if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
         line=__LINE__, &
         file=__FILE__)) &
         call ESMF_Finalize(endflag=ESMF_END_ABORT)
   if (ESMF_LogFoundError(rcToCheck=urc, msg=ESMF_LOGERR_PASSTHRU, &
         line=__LINE__, &
         file=__FILE__)) &
         call ESMF_Finalize(endflag=ESMF_END_ABORT)

   if (rank == 0) then
      call system_clock(t1, count_rate)
      open(newunit = file_unit, file = "elapsed_time.txt", &
            status = "replace", action = "write")
         elapsed_time = (t1 - t0) / real(count_rate)
         write(file_unit, '(f0.0)') elapsed_time
         close(file_unit)
   end if

   ! Call Finalize for the earth system Component
   call ESMF_GridCompFinalize(esmComp, userRc=urc, rc=rc)
   if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
         line=__LINE__, &
         file=__FILE__)) &
         call ESMF_Finalize(endflag=ESMF_END_ABORT)
   if (ESMF_LogFoundError(rcToCheck=urc, msg=ESMF_LOGERR_PASSTHRU, &
         line=__LINE__, &
         file=__FILE__)) &
         call ESMF_Finalize(endflag=ESMF_END_ABORT)

   ! Destroy the earth system Component
   call ESMF_GridCompDestroy(esmComp, rc=rc)
   if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
         line=__LINE__, &
         file=__FILE__)) &
         call ESMF_Finalize(endflag=ESMF_END_ABORT)

   CALL MPI_Comm_set_errhandler(MPI_COMM_WORLD,MPI_ERRORS_RETURN,rc)
   call ESMF_LogWrite("esmApp FINISHED", ESMF_LOGMSG_INFO, rc=rc)
   if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
         line=__LINE__, &
         file=__FILE__)) &
         call ESMF_Finalize(endflag=ESMF_END_ABORT)

   ! Finalize ESMF
   call ESMF_Finalize()

   call t_p%stop()

end program prototype
