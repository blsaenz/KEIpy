module macmods_kinds_mod

  use kei_kinds, only: i4, r4, r8, log_kind

  implicit none

  public

  integer(i4), parameter :: d8 = r8  ! legacy alias (8-byte real) for macmods utilities

end module macmods_kinds_mod
