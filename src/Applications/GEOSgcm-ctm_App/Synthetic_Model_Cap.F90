module simple_synthetic_model_cap
   use ESMF
   use NUOPC
   use NUOPC_Model, &
      model_routine_SS => SetServices, &
      model_label_advance => label_advance

   implicit none
   private

   public :: SetServices

   subroutine SetServices(model, rc)
      type(ESMF_GridComp)  :: model
      integer, intent(out) :: rc

      rc = ESMF_SUCCESS

      ! the NUOPC model component will register the generic methods
      call NUOPC_CompDerive(model, model_routine_SS, rc=rc)
      if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
            line=__LINE__, file=__FILE__)) return  ! bail out

      ! set entry point for methods that require specific implementation
      call NUOPC_CompSetEntryPoint(model, ESMF_METHOD_INITIALIZE, &
            phaseLabelList=(/"IPDv05p1"/), userRoutine=AdvertiseFields, rc=rc)
      if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
            line=__LINE__, file=__FILE__)) return  ! bail out
      call NUOPC_CompSetEntryPoint(model, ESMF_METHOD_INITIALIZE, &
            phaseLabelList=(/"IPDv05p4"/), userRoutine=RealizeFields, rc=rc)
      if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
            line=__LINE__, file=__FILE__)) return  ! bail out

      ! attach specializing method(s)
      call NUOPC_CompSpecialize(model, specLabel=model_label_Advance, &
            specRoutine=ModelAdvance, rc=rc)
      if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
            line=__LINE__, file=__FILE__))  return  ! bail out

   end subroutine SetServices


   subroutine AdvertiseFields(model, importState, exportState, clock, rc)
      type(ESMF_GridComp)  :: model
      type(ESMF_State)     :: importState, exportState
      type(ESMF_Clock)     :: clock
      integer, intent(out) :: rc

      rc = ESMF_SUCCESS

      ! Eventually, you will advertise your model's import and
      ! export fields in this phase.  For now, however, call
      ! your model's initialization routine(s).

      ! call my_model_init()

   end subroutine AdvertiseFields


   subroutine RealizeFields(model, importState, exportState, clock, rc)
      type(ESMF_GridComp)  :: model
      type(ESMF_State)     :: importState, exportState
      type(ESMF_Clock)     :: clock
      integer, intent(out) :: rc

      rc = ESMF_SUCCESS

      ! Eventually, you will realize your model's fields here,
      ! but leave empty for now.

   end subroutine RealizeFields

   subroutine ModelAdvance(model, rc)
      type(ESMF_GridComp)  :: model
      integer, intent(out) :: rc

      ! local variables
      type(ESMF_Clock)              :: clock
      type(ESMF_State)              :: importState, exportState

      rc = ESMF_SUCCESS

      ! query the Component for its clock, importState and exportState
      call NUOPC_ModelGet(model, modelClock=clock, importState=importState, &
            exportState=exportState, rc=rc)
      if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
            line=__LINE__, file=__FILE__)) return  ! bail out

      ! HERE THE MODEL ADVANCES: currTime -> currTime + timeStep

      ! Because of the way that the internal Clock was set by default,
      ! its timeStep is equal to the parent timeStep. As a consequence the
      ! currTime + timeStep is equal to the stopTime of the internal Clock
      ! for this call of the ModelAdvance() routine.

      call ESMF_ClockPrint(clock, options="currTime", &
            preString="------>Advancing MODEL from: ", rc=rc)
      if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
            line=__LINE__, file=__FILE__)) return  ! bail out

      call ESMF_ClockPrint(clock, options="stopTime", &
            preString="--------------------------------> to: ", rc=rc)
      if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
            line=__LINE__, file=__FILE__)) return ! bail out

      ! Call your model's timestep routine here

      ! call my_model_update()

   end subroutine ModelAdvance

end module simple_synthetic_model_cap
