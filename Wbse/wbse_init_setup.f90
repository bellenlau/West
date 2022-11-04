!
! Copyright (C) 2015-2022 M. Govoni
! This file is distributed under the terms of the
! GNU General Public License. See the file `License'
! in the root directory of the present distribution,
! or http://www.gnu.org/copyleft/gpl.txt .
!
! This file is part of WEST.
!
! Contributors to this file:
! Marco Govoni
!
!-----------------------------------------------------------------------
SUBROUTINE wbse_init_setup(code)
  !-----------------------------------------------------------------------
  !
  USE westcom,          ONLY : localization,l_use_localise_repr,l_use_bisection_thr,&
                             & l_use_ecutrho,nbnd_occ,wbse_save_dir,wbse_init_save_dir
  USE kinds,            ONLY : DP
  USE types_coulomb,    ONLY : pot3D
  !
  IMPLICIT NONE
  !
  CHARACTER(LEN=9), INTENT(IN):: code
  COMPLEX(DP), EXTERNAL :: get_alpha_pv
  !
  CALL do_setup()
  !
  SELECT CASE(TRIM(localization))
  CASE('N','n')
     l_use_localise_repr = .FALSE.
     l_use_bisection_thr = .FALSE.
  CASE('B','b')
     l_use_localise_repr = .TRUE.
     l_use_bisection_thr = .TRUE.
  END SELECT
  !
  l_use_ecutrho = .FALSE.
  !
  CALL set_npwq()
  !
  CALL pot3D%init('Rho',.FALSE.,'gb')
  !
  CALL set_nbndocc()
  !
  CALL my_mkdir(wbse_init_save_dir)
  !
END SUBROUTINE
