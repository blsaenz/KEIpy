! Central numeric and logical kinds for KEI / sia2 / macmods.
module kei_kinds

  use, intrinsic :: iso_fortran_env, only: int32, real32, real64

  implicit none

  public

  integer, parameter :: i4 = int32
  integer, parameter :: r4 = real32
  integer, parameter :: r8 = real64
  integer, parameter :: log_kind = kind(.true.)

end module kei_kinds
