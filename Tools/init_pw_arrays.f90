!
! Copyright (C) 2015-2024 M. Govoni
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
SUBROUTINE init_pw_arrays(ncalbec)
  !-----------------------------------------------------------------------
  !
  USE control_flags,          ONLY : gamma_only
  USE scf,                    ONLY : v,vltot,vrs,kedtau
  USE io_files,               ONLY : iunres,tmp_dir,restart_dir
  USE xc_lib,                 ONLY : xclib_dft_is
  USE dfunct,                 ONLY : newd
  USE fft_base,               ONLY : dfftp
  USE mp,                     ONLY : mp_bcast,mp_barrier
  USE mp_global,              ONLY : inter_image_comm,my_image_id
  USE mp_world,               ONLY : world_comm
  USE wavefunctions,          ONLY : evc
  USE klist,                  ONLY : nks
  USE becmod,                 ONLY : becp,allocate_bec_type_acc
  USE uspp,                   ONLY : nkb
  USE noncollin_module,       ONLY : npol
  USE buffers,                ONLY : open_buffer,close_buffer,save_buffer
  USE westcom,                ONLY : n_exx_lowrank,iuwfc,lrwfc
  USE gvecs,                  ONLY : doublegrid
  USE pw_restart_new,         ONLY : read_collected_wfc
  USE lsda_mod,               ONLY : nspin
  USE wvfct,                  ONLY : nbnd,npwx
  !
  IMPLICIT NONE
  !
  ! I/O
  !
  INTEGER,INTENT(IN) :: ncalbec
  !
  ! Workspace
  !
  INTEGER :: ik
  LOGICAL :: exst
  LOGICAL :: exst_mem
  LOGICAL :: l_open_buffer
  !
  CALL start_clock('init_pw_ar')
  !
  ! Sum self-consistent part (vr) and local part (vltot) of potential
  !
  CALL hinit0()
  !
  CALL set_vrs(vrs,vltot,v%of_r,kedtau,v%kin_r,dfftp%nnr,nspin,doublegrid)
  !
  CALL allocate_bec_type_acc(nkb,ncalbec,becp)
  !
  CALL newd
  !
  iunres = 88
  !
  ! Here we should check if lrwfc overflows
  !
  lrwfc = nbnd*npwx*npol
  !
  IF((.NOT. gamma_only) .OR. nks > 1 .OR. (xclib_dft_is('hybrid') .AND. n_exx_lowrank < 1)) THEN
     l_open_buffer = .TRUE.
  ELSE
     l_open_buffer = .FALSE.
  ENDIF
  !
  IF(my_image_id == 0) THEN
     IF(l_open_buffer) THEN
        CALL open_buffer(iuwfc,'wfc',lrwfc,1,exst_mem,exst,tmp_dir)
        DO ik = 1,nks
           CALL read_collected_wfc(restart_dir(),ik,evc)
           CALL save_buffer(evc,lrwfc,iuwfc,ik)
        ENDDO
        CALL close_buffer(iuwfc,'KEEP')
     ELSE
        CALL read_collected_wfc(restart_dir(),1,evc)
     ENDIF
  ENDIF
  !
  CALL mp_bcast(evc,0,inter_image_comm)
  !
  ! Must make sure wfc files have been written before exx_go
  !
  CALL mp_barrier(world_comm)
  !
  CALL exx_go()
  !
  IF(my_image_id == 0) THEN
     IF(l_open_buffer) CALL open_buffer(iuwfc,'wfc',lrwfc,1,exst_mem,exst,tmp_dir)
  ENDIF
  !
  CALL stop_clock('init_pw_ar')
  !
END SUBROUTINE
