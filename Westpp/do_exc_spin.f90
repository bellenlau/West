!
! Copyright (C) 2015-2023 M. Govoni
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
SUBROUTINE do_exc_spin()
  !
  USE io_global,             ONLY : stdout
  USE kinds,                 ONLY : DP
  USE io_push,               ONLY : io_push_title
  USE bar,                   ONLY : bar_type,start_bar_type,update_bar_type,stop_bar_type
  USE pwcom,                 ONLY : npw,npwx,ngk,wg,nspin
  USE control_flags,         ONLY : gamma_only
  USE gvect,                 ONLY : gstart
  USE mp,                    ONLY : mp_sum,mp_bcast
  USE mp_global,             ONLY : my_image_id,inter_image_comm,intra_bgrp_comm
  USE buffers,               ONLY : get_buffer
  USE westcom,               ONLY : iuwfc,lrwfc,nbndval0x,nbnd_occ,dvg_exc,ev,&
                                  & westpp_n_liouville_to_use,westpp_l_spin_flip,logfile
  USE mp_world,              ONLY : mpime,root
  USE plep_db,               ONLY : plep_db_read
  USE distribution_center,   ONLY : pert,kpt_pool,band_group
  USE class_idistribute,     ONLY : idistribute
  USE types_bz_grid,         ONLY : k_grid
  USE json_module,           ONLY : json_file
  USE wvfct,                 ONLY : nbnd
#if defined(__CUDA)
  USE wavefunctions_gpum,    ONLY : using_evc,using_evc_d,evc_work=>evc_d
  USE wavefunctions,         ONLY : evc_host=>evc
  USE west_gpu,              ONLY : allocate_gpu,deallocate_gpu
#else
  USE wavefunctions,         ONLY : evc_work=>evc
#endif
  !
  IMPLICIT NONE
  !
  ! ... LOCAL variables
  !
  INTEGER :: iexc,lexc,ig,ibnd1,ibnd2,ibnd3,iunit
  INTEGER :: barra_load
  INTEGER :: nbndx_occ
  CHARACTER(5) :: label_exc
  REAL(DP) :: reduce,s2,ds2,ss,norm_u,norm_d,n_alpha,n_beta
  LOGICAL :: flip_up
  REAL(DP), ALLOCATABLE :: om(:,:),collect_ds2(:),dvgdvg_uu(:,:),dvgdvg_dd(:,:),&
                         & dvgdvg_ud(:,:), dvgevc_ud(:,:), dvgevc_du(:,:)
  COMPLEX(DP), ALLOCATABLE :: evc_copy(:,:)
  TYPE(bar_type) :: barra
  TYPE(json_file) :: json
  !
  ! CHECK IF nspin = 2
  !
  IF(nspin /= 2) CALL errore('westpp', '<S^2> can only be computed for systems with nspin = 2', 1)
  !
  IF(mpime == root) THEN
     CALL json%initialize()
     CALL json%load(filename=TRIM(logfile))
  ENDIF
  !
  ! COMPUTE <S^2> FOR THE GROUND STATE
  !
  ALLOCATE(om(nbnd, nbnd))
  om(:,:) = 0._DP
  !
  ALLOCATE(evc_copy(npwx, nbnd))
  evc_copy(:,:) = (0._DP, 0._DP)
  !
#if defined(__CUDA)
  IF(my_image_id == 0) CALL get_buffer(evc_host,lrwfc,iuwfc,1)
  CALL mp_bcast(evc_host,0,inter_image_comm)
#else
  IF(my_image_id == 0) CALL get_buffer(evc_work,lrwfc,iuwfc,1)
  CALL mp_bcast(evc_work,0,inter_image_comm)
#endif
  !
  npw = ngk(1)
  !
  DO ibnd1 = 1,nbnd
     DO ig = 1, npw
        evc_copy(ig,ibnd1) = evc_work(ig,ibnd1)
     ENDDO
  ENDDO
  !
#if defined(__CUDA)
  IF(my_image_id == 0) CALL get_buffer(evc_host,lrwfc,iuwfc,2)
  CALL mp_bcast(evc_host,0,inter_image_comm)
#else
  IF(my_image_id == 0) CALL get_buffer(evc_work,lrwfc,iuwfc,2)
  CALL mp_bcast(evc_work,0,inter_image_comm)
#endif
  !
  DO ibnd1 = 1,nbnd
     DO ibnd2 = 1,nbnd
        !
        IF (gamma_only) THEN
           !
           reduce = 0._DP
           !$acc loop reduction(+:reduce)
           DO ig = 1, npw
              reduce = reduce + 2._DP * REAL(evc_copy(ig,ibnd1),KIND=DP) * REAL(evc_work(ig,ibnd2),KIND=DP) &
                     &        + 2._DP * AIMAG(evc_copy(ig,ibnd1)) * AIMAG(evc_work(ig,ibnd2))
           ENDDO
           !
           IF (gstart==2) THEN
              reduce = reduce - REAL(evc_copy(1,ibnd1),KIND=DP) * REAL(evc_work(1,ibnd2),KIND=DP)
           ENDIF
           !
           om(ibnd1, ibnd2) = reduce
           !
        ELSE
           CALL errore('do_exc_spin', 'gamma_only is required', 1)
        ENDIF
        !
     ENDDO
  ENDDO
  !
  CALL mp_sum(om, intra_bgrp_comm)
  !
  n_alpha = SUM(wg(:,1))
  n_beta = SUM(wg(:,2))
  !
  WRITE(stdout, "(   /, 5x, ' Ground State n_alpha : ', f12.6, '     n_beta', f12.6)") n_alpha, n_beta
  !
  s2 = (n_alpha - n_beta) * (n_alpha - n_beta + 2._DP) / 4._DP + n_beta
  !s2 = (nbnd_occ(1) - nbnd_occ(2)) * (nbnd_occ(1) - nbnd_occ(2) + 2._DP) / 4._DP + nbnd_occ(2)
  !
  DO ibnd1 = 1,nbnd
     DO ibnd2 = 1,nbnd
        s2 = s2 - om(ibnd1, ibnd2)**2 * wg(ibnd1, 1) * wg(ibnd2, 2)
     ENDDO
  ENDDO
  !
  WRITE(stdout, "(   /, 5x, ' Ground State <S^2> : ', f12.6)") s2
  !
  IF(mpime == root) THEN
     CALL json%add('output.ground_state.spin_square',s2)
  ENDIF
  !
  IF(westpp_n_liouville_to_use > 0) THEN
     !
     ALLOCATE(collect_ds2(westpp_n_liouville_to_use))
     !
     ! COMPUTE \Delta <S^2> FOR THE EXCITED STATES
     !
     ! ... DISTRIBUTE
     !
     pert = idistribute()
     CALL pert%init(westpp_n_liouville_to_use,'i','nvec',.TRUE.)
     kpt_pool = idistribute()
     CALL kpt_pool%init(k_grid%nps,'p','kpt',.FALSE.)
     band_group = idistribute()
     CALL band_group%init(nbndval0x,'b','nbndval',.FALSE.)
     !
     ! READ EIGENVALUES AND VECTORS FROM OUTPUT
     !
     CALL plep_db_read(westpp_n_liouville_to_use)
     !
#if defined(__CUDA)
     CALL allocate_gpu()
#endif
     !
     CALL io_push_title('BSE/TDDFT Excited State Spin (M)ultiplicity')
     !
     nbndx_occ = MAXVAL(nbnd_occ)
     !
     ALLOCATE(dvgdvg_uu(nbndx_occ, nbndx_occ))
     ALLOCATE(dvgdvg_ud(nbndx_occ, nbndx_occ))
     ALLOCATE(dvgdvg_dd(nbndx_occ, nbndx_occ))
     ALLOCATE(dvgevc_ud(nbndx_occ, nbndx_occ))
     ALLOCATE(dvgevc_du(nbndx_occ, nbndx_occ))
     !
     dvgdvg_uu(:,:) = 0._DP
     dvgdvg_ud(:,:) = 0._DP
     dvgdvg_dd(:,:) = 0._DP
     dvgevc_ud(:,:) = 0._DP
     dvgevc_du(:,:) = 0._DP
     !
     !barra_load = 0
     !DO lexc = 1,pert%nloc
     !   iexc = pert%l2g(lexc)
     !   IF(iexc < westpp_range(1) .OR. iexc > westpp_range(2)) CYCLE
     !   barra_load = barra_load+1
     !ENDDO
     !
     !CALL start_bar_type(barra,'westpp',barra_load*k_grid%nps*SUM(nbnd_occ))
     !
     DO lexc = 1,pert%nloc
        !
        ! local -> global
        !
        iexc = pert%l2g(lexc)
        !
        npw = ngk(1)
        !
        IF(.NOT. westpp_l_spin_flip) THEN
           !
           ! Spin-conserve case
           ! compute matrix elements
           ! Part 1: up-up
           !
           DO ibnd1 = 1, nbnd_occ(1)
              DO ibnd2 = 1, nbnd_occ(1)
                 IF (gamma_only) THEN
                    !
                    reduce = 0._DP
                    !$acc loop reduction(+:reduce)
                    DO ig = 1, npw
                       reduce = reduce + 2._DP * REAL(dvg_exc(ig,ibnd1,1,lexc),KIND=DP) * REAL(dvg_exc(ig,ibnd2,1,lexc),KIND=DP) &
                       &               + 2._DP * AIMAG(dvg_exc(ig,ibnd1,1,lexc)) * AIMAG(dvg_exc(ig,ibnd2,1,lexc))
                    ENDDO
                    !
                    IF (gstart==2) THEN
                       reduce = reduce - REAL(dvg_exc(1,ibnd1,1,lexc),KIND=DP) * REAL(dvg_exc(1,ibnd2,1,lexc),KIND=DP)
                    ENDIF
                    !
                    dvgdvg_uu(ibnd1,ibnd2) = reduce
                    !
                 ELSE
                    CALL errore('do_exc_spin', 'gamma_only is required', 1)
                 ENDIF
                 !
              ENDDO
           ENDDO
           !
           CALL mp_sum(dvgdvg_uu, intra_bgrp_comm)
           !
           ! Part 2: down-down
           !
           DO ibnd1 = 1, nbnd_occ(2)
              DO ibnd2 = 1, nbnd_occ(2)
                 IF (gamma_only) THEN
                    !
                    reduce = 0._DP
                    !$acc loop reduction(+:reduce)
                    DO ig = 1, npw
                       reduce = reduce + 2._DP * REAL(dvg_exc(ig,ibnd1,2,lexc),KIND=DP) * REAL(dvg_exc(ig,ibnd2,2,lexc),KIND=DP) &
                       &               + 2._DP * AIMAG(dvg_exc(ig,ibnd1,2,lexc)) * AIMAG(dvg_exc(ig,ibnd2,2,lexc))
                    ENDDO
                    !
                    IF (gstart==2) THEN
                       reduce = reduce - REAL(dvg_exc(1,ibnd1,2,lexc),KIND=DP) * REAL(dvg_exc(1,ibnd2,2,lexc),KIND=DP)
                    ENDIF
                    !
                    dvgdvg_dd(ibnd1,ibnd2) = reduce
                    !
                 ELSE
                    CALL errore('do_exc_spin', 'gamma_only is required', 1)
                 ENDIF
                 !
              ENDDO
           ENDDO
           !
           CALL mp_sum(dvgdvg_dd, intra_bgrp_comm)
           !
           ! Part 3: up-down
           !
           DO ibnd1 = 1, nbnd_occ(1)
              DO ibnd2 = 1, nbnd_occ(2)
                 IF (gamma_only) THEN
                    !
                    reduce = 0._DP
                    !$acc loop reduction(+:reduce)
                    DO ig = 1, npw
                       reduce = reduce + 2._DP * REAL(dvg_exc(ig,ibnd1,1,lexc),KIND=DP) * REAL(dvg_exc(ig,ibnd2,2,lexc),KIND=DP) &
                       &               + 2._DP * AIMAG(dvg_exc(ig,ibnd1,1,lexc)) * AIMAG(dvg_exc(ig,ibnd2,2,lexc))
                    ENDDO
                    !
                    IF (gstart==2) THEN
                       reduce = reduce - REAL(dvg_exc(1,ibnd1,1,lexc),KIND=DP) * REAL(dvg_exc(1,ibnd2,2,lexc),KIND=DP)
                    ENDIF
                    !
                    dvgdvg_ud(ibnd1,ibnd2) = reduce
                    !
                    !
                    reduce = 0._DP
                    !$acc loop reduction(+:reduce)
                    DO ig = 1, npw
                       reduce = reduce + 2._DP * REAL(dvg_exc(ig,ibnd1,1,lexc),KIND=DP) * REAL(evc_work(ig,ibnd2),KIND=DP) &
                       &               + 2._DP * AIMAG(dvg_exc(ig,ibnd1,1,lexc)) * AIMAG(evc_work(ig,ibnd2))
                    ENDDO
                    !
                    IF (gstart==2) THEN
                       reduce = reduce - REAL(dvg_exc(1,ibnd1,1,lexc),KIND=DP) * REAL(evc_work(1,ibnd2),KIND=DP)
                    ENDIF
                    !
                    dvgevc_ud(ibnd1,ibnd2) = reduce
                    !
                    !
                    reduce = 0._DP
                    !$acc loop reduction(+:reduce)
                    DO ig = 1, npw
                       reduce = reduce + 2._DP * REAL(dvg_exc(ig,ibnd2,2,lexc),KIND=DP) * REAL(evc_copy(ig,ibnd1),KIND=DP) &
                       &               + 2._DP * AIMAG(dvg_exc(ig,ibnd2,2,lexc)) * AIMAG(evc_copy(ig,ibnd1))
                    ENDDO
                    !
                    IF (gstart==2) THEN
                       reduce = reduce - REAL(dvg_exc(1,ibnd2,2,lexc),KIND=DP) * REAL(evc_copy(1,ibnd1),KIND=DP)
                    ENDIF
                    !
                    dvgevc_du(ibnd2,ibnd1) = reduce
                    !
                 ELSE
                    CALL errore('do_exc_spin', 'gamma_only is required', 1)
                 ENDIF
                 !
              ENDDO
           ENDDO
           !
           CALL mp_sum(dvgdvg_ud, intra_bgrp_comm)
           CALL mp_sum(dvgevc_ud, intra_bgrp_comm)
           CALL mp_sum(dvgevc_du, intra_bgrp_comm)
           !
           ds2 = 0._DP
           !
           DO ibnd1 = 1, nbnd_occ(1)
              DO ibnd2 = 1, nbnd_occ(2)
                 !
                 ds2 = ds2 - dvgevc_ud(ibnd1, ibnd2)**2 - dvgevc_du(ibnd2, ibnd1)**2 &
                     & - 2._DP * dvgdvg_ud(ibnd1, ibnd2) * om(ibnd1, ibnd2)
                 !
                 DO ibnd3 = 1, nbnd_occ(1)
                    !
                    ds2 = ds2 + dvgdvg_uu(ibnd1, ibnd3) * om(ibnd1, ibnd2) * om(ibnd3, ibnd2)
                    !
                 ENDDO
                 !
                 DO ibnd3 = 1, nbnd_occ(2)
                    !
                    ds2 = ds2 + dvgdvg_dd(ibnd2, ibnd3) * om(ibnd1, ibnd2) * om(ibnd1, ibnd3)
                    !
                 ENDDO
                 !
              ENDDO
           ENDDO
           !
        ELSE
           !
           ! spin-flip case
           ! compute matrix elements
           ! Part 1: up-up
           !
           DO ibnd1 = 1, nbnd_occ(2)
              DO ibnd2 = 1, nbnd_occ(2)
                 IF (gamma_only) THEN
                    !
                    reduce = 0._DP
                    !$acc loop reduction(+:reduce)
                    DO ig = 1, npw
                       reduce = reduce + 2._DP * REAL(dvg_exc(ig,ibnd1,1,lexc),KIND=DP) * REAL(dvg_exc(ig,ibnd2,1,lexc),KIND=DP) &
                       &               + 2._DP * AIMAG(dvg_exc(ig,ibnd1,1,lexc)) * AIMAG(dvg_exc(ig,ibnd2,1,lexc))
                    ENDDO
                    !
                    IF (gstart==2) THEN
                       reduce = reduce - REAL(dvg_exc(1,ibnd1,1,lexc),KIND=DP) * REAL(dvg_exc(1,ibnd2,1,lexc),KIND=DP)
                    ENDIF
                    !
                    dvgdvg_uu(ibnd1,ibnd2) = reduce
                    !
                 ELSE
                    CALL errore('do_exc_spin', 'gamma_only is required', 1)
                 ENDIF
                 !
              ENDDO
           ENDDO
           !
           CALL mp_sum(dvgdvg_uu, intra_bgrp_comm)
           !
           ! Part 2: down-down
           !
           DO ibnd1 = 1, nbnd_occ(1)
              DO ibnd2 = 1, nbnd_occ(1)
                 IF (gamma_only) THEN
                    !
                    reduce = 0._DP
                    !$acc loop reduction(+:reduce)
                    DO ig = 1, npw
                       reduce = reduce + 2._DP * REAL(dvg_exc(ig,ibnd1,2,lexc),KIND=DP) * REAL(dvg_exc(ig,ibnd2,2,lexc),KIND=DP) &
                       &               + 2._DP * AIMAG(dvg_exc(ig,ibnd1,2,lexc)) * AIMAG(dvg_exc(ig,ibnd2,2,lexc))
                    ENDDO
                    !
                    IF (gstart==2) THEN
                       reduce = reduce - REAL(dvg_exc(1,ibnd1,2,lexc),KIND=DP) * REAL(dvg_exc(1,ibnd2,2,lexc),KIND=DP)
                    ENDIF
                    !
                    dvgdvg_dd(ibnd1,ibnd2) = reduce
                    !
                 ELSE
                    CALL errore('do_exc_spin', 'gamma_only is required', 1)
                 ENDIF
                 !
              ENDDO
           ENDDO
           !
           CALL mp_sum(dvgdvg_dd, intra_bgrp_comm)
           !
           ! Part 3: up-down
           !
           DO ibnd1 = 1, nbnd_occ(2)
              DO ibnd2 = 1, nbnd_occ(2)
                 IF (gamma_only) THEN
                    !
                    reduce = 0._DP
                    !$acc loop reduction(+:reduce)
                    DO ig = 1, npw
                       reduce = reduce + 2._DP * REAL(dvg_exc(ig,ibnd1,1,lexc),KIND=DP) * REAL(evc_work(ig,ibnd2),KIND=DP) &
                       &               + 2._DP * AIMAG(dvg_exc(ig,ibnd1,1,lexc)) * AIMAG(evc_work(ig,ibnd2))
                    ENDDO
                    !
                    IF (gstart==2) THEN
                       reduce = reduce - REAL(dvg_exc(1,ibnd1,1,lexc),KIND=DP) * REAL(evc_work(1,ibnd2),KIND=DP)
                    ENDIF
                    !
                    dvgevc_ud(ibnd1,ibnd2) = reduce
                    !
                 ELSE
                    CALL errore('do_exc_spin', 'gamma_only is required', 1)
                 ENDIF
                 !
              ENDDO
           ENDDO
           !
           CALL mp_sum(dvgevc_ud, intra_bgrp_comm)
           !
           ! Part 4: down-up
           !
           DO ibnd1 = 1, nbnd_occ(1)
              DO ibnd2 = 1, nbnd_occ(1)
                 IF (gamma_only) THEN
                    !
                    reduce = 0._DP
                    !$acc loop reduction(+:reduce)
                    DO ig = 1, npw
                       reduce = reduce + 2._DP * REAL(dvg_exc(ig,ibnd1,2,lexc),KIND=DP) * REAL(evc_copy(ig,ibnd2),KIND=DP) &
                       &               + 2._DP * AIMAG(dvg_exc(ig,ibnd1,2,lexc)) * AIMAG(evc_copy(ig,ibnd2))
                    ENDDO
                    !
                    IF (gstart==2) THEN
                       reduce = reduce - REAL(dvg_exc(1,ibnd1,2,lexc),KIND=DP) * REAL(evc_copy(1,ibnd2),KIND=DP)
                    ENDIF
                    !
                    dvgevc_du(ibnd1,ibnd2) = reduce
                    !
                 ELSE
                    CALL errore('do_exc_spin', 'gamma_only is required', 1)
                 ENDIF
                 !
              ENDDO
           ENDDO
           !
           CALL mp_sum(dvgevc_du, intra_bgrp_comm)
           !
           ! decide whether flip up of flip down by computing the norm of dvg_u and dvg_d
           !
           norm_u = 0._DP
           norm_d = 0._DP
           !
           DO ibnd1 = 1, nbnd_occ(2)
              norm_u = norm_u + dvgdvg_uu(ibnd1, ibnd1)
           ENDDO
           !
           DO ibnd1 = 1, nbnd_occ(1)
              norm_d = norm_d + dvgdvg_dd(ibnd1, ibnd1)
           ENDDO
           !
           IF(ABS(norm_u - 1._DP) < 0.01_DP) flip_up = .TRUE.
           IF(ABS(norm_d - 1._DP) < 0.01_DP) flip_up = .FALSE.
           !
           ds2 = 0._DP
           !
           IF(flip_up) THEN
              !
              DO ibnd1 = 1,nbnd_occ(2)
                 DO ibnd2 = 1,nbnd_occ(2)
                    !
                    ds2 = ds2 - dvgevc_ud(ibnd1, ibnd2)**2 + dvgevc_ud(ibnd1, ibnd1) * dvgevc_ud(ibnd2, ibnd2)
                    !
                    DO ibnd3 = 1, nbnd_occ(1)
                       ds2 = ds2 + dvgdvg_uu(ibnd1, ibnd2) * om(ibnd3, ibnd1) * om(ibnd3, ibnd2)
                    ENDDO
                    !
                 ENDDO
              ENDDO
              !
           ELSE
              !
              DO ibnd1 = 1, nbnd_occ(1)
                 DO ibnd2 = 1, nbnd_occ(1)
                    !
                    ds2 = ds2 - dvgevc_du(ibnd1, ibnd2)**2 + dvgevc_du(ibnd1, ibnd1) * dvgevc_du(ibnd2, ibnd2)
                    !
                    DO ibnd3 = 1, nbnd_occ(2)
                       ds2 = ds2 + dvgdvg_dd(ibnd1, ibnd2) * om(ibnd1, ibnd3) * om(ibnd2, ibnd3)
                    ENDDO
                    !
                 ENDDO
              ENDDO
              !
           ENDIF
           !
           ss = (-1._DP + SQRT(1._DP + 4._DP * s2)) / 2
           !
           IF(nbnd_occ(1) >= nbnd_occ(2)) THEN
              !
              IF(flip_up) THEN
                 ds2 = ds2 + 2._DP * ss + 1._DP
              ELSE
                 ds2 = ds2 - 2._DP * ss + 1._DP
              ENDIF
              !
           ELSE
              !
              IF(flip_up) THEN
                 ds2 = ds2 - 2._DP * ss + 1._DP
              ELSE
                 ds2 = ds2 + 2._DP * ss + 1._DP
              ENDIF
              !
           ENDIF
           !
        ENDIF
        !
        collect_ds2(iexc) = ds2
        !
     ENDDO
     !
     CALL mp_sum(collect_ds2,inter_image_comm)
     !
     DEALLOCATE(dvgdvg_uu)
     DEALLOCATE(dvgdvg_ud)
     DEALLOCATE(dvgdvg_dd)
     DEALLOCATE(dvgevc_ud)
     DEALLOCATE(dvgevc_du)
     !
     DO iexc=1,westpp_n_liouville_to_use
        !
        WRITE(stdout, &
        & "(   /, 5x, ' # Exciton : | ', i12,' |','   ','spin flip : | ', L3)") iexc, westpp_l_spin_flip
        !
        IF(westpp_l_spin_flip) THEN
           !
           WRITE(stdout, &
           & "(   /, 5x, '    nbnd_1 : | ', i12, ' |','      ', 'nbnd_2 : | ', i12, ' |','   ', 'flip up : | ', L3)") &
           nbnd_occ(1), nbnd_occ(2), flip_up
           !
        ENDIF
        !
        WRITE(stdout, &
        & "(   /, 5x, ' Ex Energy : | ', f12.6,' |','      ','D<S^2> : | ', f12.6)") &
        ev(iexc), collect_ds2(iexc)
        !
     ENDDO
     !
     WRITE(stdout,*)
     !
     ! ... Write the results in the json file
     !
     IF(mpime == root) THEN
        !
        DO iexc = 1,westpp_n_liouville_to_use
           !
           WRITE(label_exc,'(I5.5)') iexc
           !
           CALL json%add('output.E'//label_exc//'.delta_spin_square',collect_ds2(iexc))
           !
        ENDDO
        !
     ENDIF
     !
     DEALLOCATE(collect_ds2)
     !
  ENDIF
  !
  DEALLOCATE(om)
  DEALLOCATE(evc_copy)
  !
#if defined(__CUDA)
  CALL deallocate_gpu()
#endif
  !
  IF(mpime == root) THEN
     OPEN(NEWUNIT=iunit,FILE=TRIM(logfile))
     CALL json%print(iunit)
     CLOSE(iunit)
     CALL json%destroy()
  ENDIF
  !
END SUBROUTINE
