!
! Copyright (C) 2015-2017 M. Govoni 
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
MODULE pdep_db
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
    ! PDEP WRITE
    ! *****************************
    !
    !------------------------------------------------------------------------
    SUBROUTINE pdep_db_write( iq )
      !------------------------------------------------------------------------
      !
      USE mp,                   ONLY : mp_bcast,mp_barrier
      USE mp_world,             ONLY : mpime,root,world_comm
      USE mp_global,            ONLY : my_image_id
      USE io_global,            ONLY : stdout 
      USE westcom,              ONLY : wstat_calculation,n_pdep_times,n_pdep_eigen,n_pdep_maxiter,n_dfpt_maxiter, &
                                     & n_steps_write_restart,n_pdep_restart_from_itr,n_pdep_read_from_file,trev_pdep, &
                                     & tr2_dfpt,l_deflate,l_kinetic_only,ev,dvg,west_prefix,trev_pdep_rel, &
                                     & l_minimize_exx_if_active,l_use_ecutrho,wstat_save_dir,logfile 
      USE pdep_io,              ONLY : pdep_merge_and_write_G 
      USE io_push,              ONLY : io_push_bar
      USE distribution_center,  ONLY : pert 
      USE json_module,          ONLY : json_file 
      !
      !
      IMPLICIT NONE
      !
      INTEGER, INTENT(IN), OPTIONAL :: iq
      !
      CHARACTER(LEN=512)    :: fname
      CHARACTER(LEN=6)      :: my_label
      CHARACTER(LEN=5)      :: my_label_q
      REAL(DP), EXTERNAL    :: GET_CLOCK
      REAL(DP) :: time_spent(2)
      CHARACTER(20),EXTERNAL :: human_readable_time
      INTEGER :: iunout,global_j,local_j
      INTEGER :: ierr
      CHARACTER(20) :: eigenpot_filename(n_pdep_eigen)
      !
      TYPE(json_file) :: json 
      INTEGER :: iunit      
      !
      ! MPI BARRIER
      !
      CALL mp_barrier(world_comm)
      !
      ! SET FILENAMES
      !
      DO global_j = 1, n_pdep_eigen
         IF ( PRESENT(iq) ) THEN
            WRITE(my_label,'(i6.6)') global_j
            WRITE(my_label_q,'(i5.5)') iq
            eigenpot_filename(global_j) = "EQ"//TRIM(ADJUSTL(my_label_q))//"_"//TRIM(ADJUSTL(my_label))//".json" 
         ELSE
            WRITE(my_label,'(i6.6)') global_j
            eigenpot_filename(global_j) = "E"//TRIM(ADJUSTL(my_label))//".json" 
         ENDIF
      ENDDO
      !
      ! TIMING
      !
      CALL start_clock('pdep_db')
      time_spent(1)=get_clock('pdep_db')
      !
      IF ( mpime == root ) THEN
         !
         CALL json%initialize()
         !
         CALL json%load_file(filename=TRIM(logfile))
         ! 
         IF (PRESENT(iq)) THEN
            CALL json%add('output.Q'//TRIM(my_label_q)//'.eigenval',ev(1:n_pdep_eigen))
            CALL json%add('output.Q'//TRIM(my_label_q)//'.eigenpot',eigenpot_filename(1:n_pdep_eigen))
         ELSE
            CALL json%add('output.eigenval',ev(1:n_pdep_eigen))
            CALL json%add('output.eigenpot',eigenpot_filename(1:n_pdep_eigen))
         ENDIF
         !
         OPEN( NEWUNIT=iunit, FILE=TRIM( logfile ) )
         CALL json%print_file( iunit )
         CLOSE( iunit )
         CALL json%destroy()
         !
      ENDIF
      !
      ! 3) CREATE THE EIGENVECTOR FILES
      !
      DO local_j=1,pert%nloc
         !
         ! local -> global
         !
         global_j = pert%l2g(local_j)
         IF(global_j>n_pdep_eigen) CYCLE
         ! 
         fname = TRIM( wstat_save_dir ) // "/"//TRIM(eigenpot_filename(global_j))
         IF ( PRESENT(iq) ) THEN
            CALL pdep_merge_and_write_G(fname,dvg(:,local_j),iq)
         ELSE
            CALL pdep_merge_and_write_G(fname,dvg(:,local_j))
         ENDIF
         !
      ENDDO
      !
      ! MPI BARRIER
      !
      CALL mp_barrier( world_comm )
      !
      ! TIMING
      !
      time_spent(2)=get_clock('pdep_db')
      CALL stop_clock('pdep_db')
      !
      WRITE(stdout,'(  5x," ")')
      CALL io_push_bar()
      WRITE(stdout, "(5x, 'SAVE written in ',a20)") human_readable_time(time_spent(2)-time_spent(1)) 
      WRITE(stdout, "(5x, 'In location : ',a)") TRIM( wstat_save_dir )  
      CALL io_push_bar()
      !
    END SUBROUTINE
    !
    !
    ! *****************************
    ! PDEP READ
    ! *****************************
    !
    !------------------------------------------------------------------------
    SUBROUTINE pdep_db_read( nglob_to_be_read, iq_to_be_read, l_print_readin_info )
      !------------------------------------------------------------------------
      !
      USE westcom,             ONLY : n_pdep_eigen,ev,dvg,west_prefix,npwqx,wstat_save_dir
      USE io_global,           ONLY : stdout 
      USE mp,                  ONLY : mp_bcast,mp_barrier
      USE mp_world,            ONLY : world_comm,mpime,root
      USE mp_global,           ONLY : my_image_id
      USE pdep_io,             ONLY : pdep_read_G_and_distribute
      USE io_push,             ONLY : io_push_bar
      USE distribution_center, ONLY : pert
      USE json_module,         ONLY : json_file 
      !
      IMPLICIT NONE
      !
      INTEGER, INTENT(IN) :: nglob_to_be_read
      INTEGER, INTENT(IN), OPTIONAL :: iq_to_be_read
      LOGICAL, INTENT(IN), OPTIONAL :: l_print_readin_info
      !
      CHARACTER(LEN=512) :: fname
      CHARACTER(LEN=6)      :: my_label
      CHARACTER(LEN=5)      :: my_label_q
      REAL(DP), EXTERNAL    :: GET_CLOCK
      REAL(DP) :: time_spent(2)
      CHARACTER(20),EXTERNAL :: human_readable_time
      INTEGER :: ierr, n_eigen_to_get
      INTEGER :: tmp_n_pdep_eigen
      INTEGER :: dime, iun, global_j, local_j
      REAL(DP),ALLOCATABLE :: tmp_ev(:)
      LOGICAL :: found
      TYPE(json_file) :: json
      CHARACTER(20),ALLOCATABLE :: eigenpot_filename(:) 
      LOGICAL :: l_print_message
      !
      ! MPI BARRIER
      !
      CALL mp_barrier(world_comm)
      !
      CALL start_clock('pdep_db')
      !
      ! TIMING
      !
      time_spent(1)=get_clock('pdep_db')
      !
      ! 1)  READ THE INPUT FILE
      !
      !
      IF ( mpime == root ) THEN
         !
         CALL json%initialize()
         CALL json%load_file( filename = TRIM( wstat_save_dir ) // '/' // TRIM('wstat.json') )
         ! 
         CALL json%get('input.wstat_control.n_pdep_eigen', tmp_n_pdep_eigen, found) 
         IF (PRESENT(iq_to_be_read)) THEN
            WRITE(my_label_q,'(i5.5)') iq_to_be_read
            CALL json%get('output.Q'//TRIM(my_label_q)//'.eigenval',tmp_ev, found)
            CALL json%get('output.Q'//TRIM(my_label_q)//'.eigenpot', eigenpot_filename, found)
         ELSE
            CALL json%get('output.eigenval', tmp_ev, found)
            CALL json%get('output.eigenpot', eigenpot_filename, found) 
         ENDIF
         !
         CALL json%destroy()
         !
      ENDIF
      !
      CALL mp_bcast( tmp_n_pdep_eigen, root, world_comm )
      !
      ! In case nglob_to_be_read is 0, overwrite it with the read value 
      !
      IF (nglob_to_be_read==0) THEN 
         n_eigen_to_get = tmp_n_pdep_eigen
         n_pdep_eigen=tmp_n_pdep_eigen
      ELSE
         n_eigen_to_get = MIN(tmp_n_pdep_eigen,nglob_to_be_read)
      ENDIF
      !
      ! 2)  READ THE EIGENVALUES FILE
      !
      IF(.NOT.ALLOCATED(ev)) ALLOCATE(ev(n_eigen_to_get))
      IF ( mpime==root ) ev(1:nglob_to_be_read) = tmp_ev(1:nglob_to_be_read)
      CALL mp_bcast( ev, root, world_comm )
      !
      IF( mpime /= root ) THEN 
         ALLOCATE( eigenpot_filename(1:tmp_n_pdep_eigen) )
      ENDIF
      CALL mp_bcast(eigenpot_filename,root,world_comm)
      !
      ! 3)  READ THE EIGENVECTOR FILES
      !
      IF(.NOT.ALLOCATED(dvg)) THEN
         ALLOCATE(dvg(npwqx,pert%nlocx))
         dvg = 0._DP
      ENDIF
      !
      DO local_j=1,pert%nloc
         !
         ! local -> global
         !
         global_j = pert%l2g(local_j)
         IF(global_j>n_eigen_to_get) CYCLE
         ! 
         fname = TRIM( wstat_save_dir ) // "/"//TRIM(eigenpot_filename(global_j))
         IF ( PRESENT(iq_to_be_read) ) THEN
            CALL pdep_read_G_and_distribute(fname,dvg(:,local_j),iq_to_be_read)
         ELSE
            CALL pdep_read_G_and_distribute(fname,dvg(:,local_j))
         ENDIF
         !
      ENDDO
      !
      ! MPI BARRIER
      !
      CALL mp_barrier( world_comm )
      DEALLOCATE( eigenpot_filename ) 
      !
      ! TIMING
      !
      time_spent(2)=get_clock('pdep_db')
      CALL stop_clock('pdep_db')
      !
      IF (PRESENT(l_print_readin_info)) THEN
         l_print_message = l_print_readin_info
      ELSE
         l_print_message = .TRUE.
      ENDIF
      !
      IF (l_print_message) THEN
         WRITE(stdout,'(  5x," ")')
         CALL io_push_bar()
         WRITE(stdout, "(5x, 'SAVE read in ',a20)") human_readable_time(time_spent(2)-time_spent(1)) 
         WRITE(stdout, "(5x, 'In location : ',a)") TRIM( wstat_save_dir )  
         WRITE(stdout, "(5x, 'Eigen. found : ',i12)") n_eigen_to_get
         CALL io_push_bar()
      ENDIF
      !
    END SUBROUTINE
    !
END MODULE
