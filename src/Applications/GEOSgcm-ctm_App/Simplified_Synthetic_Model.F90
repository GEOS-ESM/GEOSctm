module Simplified_Synthetic_Model
   use ESMF
   use NUOPC
   use NUOPC_Model, &
      model_routine_SS           => SetServices, &
      model_label_advance        => label_advance, &
      model_label_dataInitialize => label_dataInitialize

   implicit none
   private

   contains
      subroutine SetServices(model, rc)
         type(ESMF_GridComp)  :: model
         integer, intent(out) :: rc

         rc = ESMF_SUCCESS

         ! the NUOPC model component will register the generic methods
         call NUOPC_CompDerive(model, model_routine_SS, rc=rc)
         if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
               line=__LINE__, file=__FILE__)) return ! bail out

         ! set entry point for initializing the model
         call ESMF_GridCompSetEntryPoint(model, ESMF_METHOD_INITIALIZE, &
               userRoutine=initialize_model, phase=0, rc=rc)
         if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
               line=__LINE__, file=__FILE__)) return ! bail out

         ! set entry point for advertising fields
         call NUOPC_CompSetEntryPoint(model, ESMF_METHOD_INITIALIZE, &
               phaseLabelList=["IPDv05p1"], userRoutine=advertise_fields, rc=rc)
         if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
               line=__LINE__, file=__FILE__)) return ! bail out

         ! set entry point for realizing fields
         call NUOPC_CompSetEntryPoint(model, ESMF_METHOD_INITIALIZE, &
               phaseLabelList=["IPDv05p4"], userRoutine=realize_fields, rc=rc)
         if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
               line=__LINE__, file=__FILE__)) return ! bail out

         ! attach the initialize method
         call NUOPC_CompSpecialize(model, specLabel=model_label_dataInitialize, &
               specRoutine=initialize_data, rc=rc)
         if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
               line=__LINE__, file=__FILE__)) return ! bail out

         ! attach the model advance method
         call NUOPC_CompSpecialize(model, specLabel=model_label_advance, &
               specRoutine=model_advance, rc=rc)
         if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
               line=__LINE__, file=__FILE__)) return ! bail out

      end subroutine SetServices

      subroutine initialize_model(model, import_state, export_state, clock, rc)
         type(ESMF_GridComp)  :: model
         type(ESMF_State)     :: import_state, export_state
         type(ESMF_Clock)     :: clock
         integer, intent(out) :: rc

         ! initialize the model here

      end subroutine initialize_model

      subroutine advertise_fields(model, import_state, export_state, clock, rc)
         type(ESMF_GridComp)  :: model
         type(ESMF_State)     :: import_state, export_state
         type(ESMF_Clock)     :: clock
         integer, intent(out) :: rc

         rc = ESMF_SUCCESS

         ! Needed to advertise the import and export fields of the model.
         ! There are no import/export fields for this model so it is blank.

      end subroutine advertise_fields

      subroutine realize_fields(model, import_state, export_state, clock, rc)
         type(ESMF_GridComp)  :: model
         type(ESMF_State)     :: import_state, export_state
         type(ESMF_Clock)     :: clock
         integer, intent(out) :: rc

         rc = ESMF_SUCCESS

         ! Needed to create/fill the model's import and export fields.
         ! There are no import/export fields for this model so it is blank.

      end subroutine realize_fields

      subroutine initialize_data(model, rc)
         type(ESMF_GridComp)  :: model
         integer, intent(out) :: rc

         rc = ESMF_SUCCESS

         ! this is needed to state that initial conditions have been set

         call NUOPC_CompAttributeSet(model, name="InitializeDataComplete", &
               value="true", rc=rc)
         if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
               line=__LINE__, file=__FILE__)) return ! bail out

      end subroutine initialize_data

      subroutine model_advance(model, rc)
         type(ESMF_GridComp)  :: model
         integer, intent(out) :: rc

         type(ESMF_State) :: import_state, export_state
         type(ESMF_Clock) :: clock

         rc = ESMF_SUCCESS

         ! query the component for its clock and import/export states
         call NUOPC_ModelGet(model, modelClock=clock, importState=import_state, &
               exportState=export_state, rc=rc)
         if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
               line=__LINE__, file=__FILE__)) return ! bail out

         ! PLACE MODEL ADVANCE ONE STEP HERE
         ! MODEL ADVANCES: currTime -> currTime + timeStep

         ! print current time
         call ESMF_ClockPrint(clock, options="currTime", &
               preString="------> Advancing model from: ", rc=rc)
         if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
               line=__LINE__, file=__FILE__)) return ! bail out
         call ESMF_ClockPrint(clock, options="stopTime", &
               preString="--------------------------------> to: ", rc=rc)
         if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
               line=__LINE__, file=__FILE__)) return ! bail out

      end subroutine model_advance
end module Simplified_Synthetic_Model
