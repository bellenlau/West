!
! Copyright (C) 2015-2021 M. Govoni
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
MODULE wfreq_db
  !----------------------------------------------------------------------------
  !
  USE kinds,     ONLY : DP
  !
  IMPLICIT NONE
  !
  !
  CONTAINS
    !
    !
    ! *****************************
    ! WFREQ WRITE
    ! *****************************
    !
    !------------------------------------------------------------------------
    SUBROUTINE wfreq_db_write( )
      !------------------------------------------------------------------------
      !
      USE mp,                   ONLY : mp_barrier
      USE mp_world,             ONLY : mpime,root,world_comm
      USE io_global,            ONLY : stdout
      USE westcom,              ONLY : wfreq_save_dir,qp_bands,n_bands,wfreq_calculation,n_spectralf,logfile,&
                                     & sigma_exx,sigma_vxcl,sigma_vxcnl,sigma_hf,sigma_z,sigma_eqplin,&
                                     & sigma_eqpsec,sigma_sc_eks,sigma_sc_eqplin,sigma_sc_eqpsec,sigma_diff,&
                                     & sigma_freq,sigma_spectralf,l_enable_off_diagonal,n_pairs,sigma_vxcl_full,&
                                     & sigma_vxcnl_full,sigma_exx_full,sigma_corr_full
      USE pwcom,                ONLY : et
      USE io_push,              ONLY : io_push_bar
      USE json_module,          ONLY : json_file
      USE constants,            ONLY : rytoev
      USE types_bz_grid,        ONLY : k_grid
      !
      IMPLICIT NONE
      !
      REAL(DP), EXTERNAL    :: GET_CLOCK
      REAL(DP) :: time_spent(2)
      CHARACTER(20),EXTERNAL :: human_readable_time
      INTEGER :: iks, ib
      CHARACTER(LEN=6) :: my_label_k, my_label_b
      !
      TYPE(json_file) :: json
      INTEGER :: iunit, i
      INTEGER,ALLOCATABLE :: ilist(:)
      LOGICAL :: l_generate_plot, l_optics
      !
      ! MPI BARRIER
      !
      CALL mp_barrier(world_comm)
      !
      ! TIMING
      !
      CALL start_clock('wfreq_db')
      time_spent(1)=get_clock('wfreq_db')
      !
      IF ( mpime == root ) THEN
         !
         CALL json%initialize()
         !
         CALL json%load(filename=TRIM(logfile))
         !
         l_generate_plot = .FALSE.
         l_optics = .FALSE.
         DO i = 1,9
            IF( wfreq_calculation(i:i) == 'P' ) l_generate_plot = .TRUE.
            IF( wfreq_calculation(i:i) == 'O' ) l_optics = .TRUE.
         ENDDO
         !
         ALLOCATE(ilist(n_bands))
         DO ib = 1,n_bands
            ilist(ib) = qp_bands(ib)
         ENDDO
         CALL json%add('output.Q.bandmap',ilist(1:n_bands))
         DEALLOCATE(ilist)
         IF( l_generate_plot ) CALL json%add('output.P.freqlist',sigma_freq(1:n_spectralf)*rytoev)
         !
         DO iks = 1, k_grid%nps
            !
            WRITE(my_label_k,'(i6.6)') iks
            !
            CALL json%add('output.Q.K'//TRIM(my_label_k)//'.sigmax', sigma_exx(1:n_bands,iks)*rytoev)
            CALL json%add('output.Q.K'//TRIM(my_label_k)//'.vxcl', sigma_vxcl(1:n_bands,iks)*rytoev)
            CALL json%add('output.Q.K'//TRIM(my_label_k)//'.vxcnl', sigma_vxcnl(1:n_bands,iks)*rytoev)
            CALL json%add('output.Q.K'//TRIM(my_label_k)//'.hf', sigma_hf(1:n_bands,iks)*rytoev)
            CALL json%add('output.Q.K'//TRIM(my_label_k)//'.z', sigma_z(1:n_bands,iks))
            CALL json%add('output.Q.K'//TRIM(my_label_k)//'.eks', et(1:n_bands,iks)*rytoev)
            CALL json%add('output.Q.K'//TRIM(my_label_k)//'.eqpLin', sigma_eqplin(1:n_bands,iks)*rytoev)
            CALL json%add('output.Q.K'//TRIM(my_label_k)//'.eqpSec', sigma_eqpsec(1:n_bands,iks)*rytoev)
            CALL json%add('output.Q.K'//TRIM(my_label_k)//'.sigmac_eks.re', &
            & REAL(sigma_sc_eks(1:n_bands,iks)*rytoev,KIND=DP))
            CALL json%add('output.Q.K'//TRIM(my_label_k)//'.sigmac_eks.im', &
            & AIMAG(sigma_sc_eks(1:n_bands,iks)*rytoev))
            CALL json%add('output.Q.K'//TRIM(my_label_k)//'.sigmac_eqpLin.re', &
            & REAL(sigma_sc_eqplin(1:n_bands,iks)*rytoev,KIND=DP))
            CALL json%add('output.Q.K'//TRIM(my_label_k)//'.sigmac_eqpLin.im', &
            & AIMAG(sigma_sc_eqplin(1:n_bands,iks)*rytoev))
            CALL json%add('output.Q.K'//TRIM(my_label_k)//'.sigmac_eqpSec.re', &
            & REAL(sigma_sc_eqpsec(1:n_bands,iks)*rytoev,KIND=DP))
            CALL json%add('output.Q.K'//TRIM(my_label_k)//'.sigmac_eqpSec.im', &
            & AIMAG(sigma_sc_eqpsec(1:n_bands,iks)*rytoev))
            CALL json%add('output.Q.K'//TRIM(my_label_k)//'.sigma_diff', sigma_diff(1:n_bands,iks)*rytoev)
            IF(l_enable_off_diagonal) THEN
               CALL json%add('output.Q.K'//TRIM(my_label_k)//'.sigmax_full', &
               & sigma_exx_full(1:n_pairs,iks)*rytoev)
               CALL json%add('output.Q.K'//TRIM(my_label_k)//'.vxcl_full', &
               & sigma_vxcl_full(1:n_pairs,iks)*rytoev)
               CALL json%add('output.Q.K'//TRIM(my_label_k)//'.vxcnl_full', &
               & sigma_vxcnl_full(1:n_pairs,iks)*rytoev)
               CALL json%add('output.Q.K'//TRIM(my_label_k)//'.sigmac_full.re', &
               & DBLE(sigma_corr_full(1:n_pairs,iks)*rytoev))
               CALL json%add('output.Q.K'//TRIM(my_label_k)//'.sigmac_full.im', &
               & AIMAG(sigma_corr_full(1:n_pairs,iks)*rytoev))
            ENDIF
            !
            IF( l_generate_plot ) THEN
               DO ib = 1, n_bands
                  WRITE(my_label_b,'(i6.6)') ib
                  CALL json%add('output.P.K'//TRIM(my_label_k)//'.B'//TRIM(my_label_b)//'.sigmac.re',&
                  &REAL(sigma_spectralf(1:n_spectralf,ib,iks),KIND=DP)*rytoev)
                  CALL json%add('output.P.K'//TRIM(my_label_k)//'.B'//TRIM(my_label_b)//'.sigmac.im',&
                  &AIMAG(sigma_spectralf(1:n_spectralf,ib,iks))*rytoev)
               ENDDO
            ENDIF
            !
            IF( l_optics) THEN
               CALL json%add('output.O',"optics.json")
            ENDIF
            !
         ENDDO
         !
         OPEN( NEWUNIT=iunit, FILE=TRIM( logfile ) )
         CALL json%print( iunit )
         CLOSE( iunit )
         CALL json%destroy()
         !
      ENDIF
      !
      ! MPI BARRIER
      !
      CALL mp_barrier( world_comm )
      !
      ! TIMING
      !
      time_spent(2)=get_clock('wfreq_db')
      CALL stop_clock('wfreq_db')
      !
      WRITE(stdout,'(  5x," ")')
      CALL io_push_bar()
      WRITE(stdout, "(5x, 'SAVE written in ',a20)") human_readable_time(time_spent(2)-time_spent(1))
      WRITE(stdout, "(5x, 'In location : ',a)") TRIM( wfreq_save_dir )
      CALL io_push_bar()
      !
    END SUBROUTINE
    !
    !------------------------------------------------------------------------
    SUBROUTINE qdet_db_write( )
      !------------------------------------------------------------------------
      !
      USE mp,                   ONLY : mp_barrier
      USE mp_world,             ONLY : mpime,root,world_comm
      USE io_global,            ONLY : stdout
      USE westcom,              ONLY : wfreq_save_dir,qp_bands,n_bands,wfreq_calculation,&
                                     & l_enable_off_diagonal,n_pairs,h1e,eri,logfile
      USE pwcom,                ONLY : et,nspin
      USE io_push,              ONLY : io_push_bar
      USE json_module,          ONLY : json_file
      USE constants,            ONLY : rytoev
      USE types_bz_grid,        ONLY : k_grid
      !
      IMPLICIT NONE
      !
      REAL(DP), EXTERNAL    :: GET_CLOCK
      REAL(DP) :: time_spent(2)
      CHARACTER(20),EXTERNAL :: human_readable_time
      INTEGER :: iks, jks, ib
      CHARACTER(LEN=6) :: my_label_ik, my_label_jk, my_label_b, my_label_ipair
      !
      TYPE(json_file) :: json
      INTEGER :: iunit, i, ipair
      INTEGER,ALLOCATABLE :: ilist(:)
      LOGICAL :: l_generate_plot, l_optics
      !
      ! MPI BARRIER
      !
      CALL mp_barrier(world_comm)
      !
      ! TIMING
      !
      CALL start_clock('qdet_db')
      time_spent(1)=get_clock('qdet_db')
      !
      IF ( mpime == root ) THEN
         !
         CALL json%initialize()
         !
         ALLOCATE(ilist(n_bands))
         DO ib = 1,n_bands
            ilist(ib) = qp_bands(ib)
         ENDDO
         CALL json%add('qdet.bandmap',ilist(1:n_bands))
         DEALLOCATE(ilist)
         !
         ! ALLOCATE( h1e(n_pairs,nspin) )
         ! h1e = 0._DP
         ! !
         ! DO iks = 1, nspin
         !    !
         !    WRITE(my_label_ik,'(i6.6)') iks
         !    !
         !    IF(l_enable_off_diagonal) THEN
         !       CALL json%add('qdet.h1e.K'//TRIM(my_label_ik), &
         !       & h1e(1:n_pairs,iks)*rytoev)
         !    ENDIF
         !    !
         ! ENDDO
         !
         DO iks = 1, nspin
            !
            DO jks = 1, nspin
               !
               WRITE(my_label_ik,'(i6.6)') iks
               !
               WRITE(my_label_jk,'(i6.6)') jks
               !
               IF(l_enable_off_diagonal) THEN
                  DO ipair = 1, n_pairs
                     !
                     WRITE(my_label_ipair,'(i6.6)') ipair
                     !
                     CALL json%add('qdet.eri.K'//TRIM(my_label_ik)//'.K'// &
                     & TRIM(my_label_jk)//'.pair'//TRIM(my_label_ipair), &
                     & eri(ipair,1:n_pairs,iks,jks)*rytoev)
                  ENDDO
               ENDIF
               !
            ENDDO
            !
         ENDDO
         !
         OPEN( NEWUNIT=iunit, FILE='qdet.json' )
         CALL json%print( iunit )
         CLOSE( iunit )
         CALL json%destroy()
         !
      ENDIF
      !
      ! MPI BARRIER
      !
      CALL mp_barrier( world_comm )
      !
      ! TIMING
      !
      time_spent(2)=get_clock('qdet_db')
      CALL stop_clock('qdet_db')
      !
      WRITE(stdout,'(  5x," ")')
      CALL io_push_bar()
      WRITE(stdout, "(5x, 'SAVE written in ',a20)") human_readable_time(time_spent(2)-time_spent(1))
      WRITE(stdout, "(5x, 'In location : ',a)") TRIM( wfreq_save_dir )
      CALL io_push_bar()
      !
    END SUBROUTINE
    !
END MODULE
