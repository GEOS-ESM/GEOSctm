esma_add_subdirectories (
  MAPL
  GMAO_Shared
  )

# Special case - FMS is built twice with two
# different precisions.
esma_add_subdirectory (FMS RENAME fms_r4)
esma_add_subdirectory (FMS RENAME fms_r8)
