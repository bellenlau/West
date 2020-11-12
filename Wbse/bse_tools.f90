!
! Copyright (C) 2015-2016 M. Govoni
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
SUBROUTINE read_bse_pots_g2g( rhog, fixed_band_i, fixed_band_j, ispin, single_only)
     !
     ! ... this routine writes the pot-density in xml format
     !
     USE kinds,          ONLY : DP
     USE control_flags,  ONLY : gamma_only
     USE fft_base,       ONLY : dfftp, dffts
     USE io_global,      ONLY : ionode, stdout
     USE pdep_io,        ONLY : pdep_read_G_and_distribute
     USE fft_at_gamma,   ONLY : single_invfft_gamma
     USE fft_at_k,       ONLY : single_invfft_k
     USE westcom,        ONLY : savedir
     USE pwcom,          ONLY : npwx
     !
     IMPLICIT NONE
     !
     COMPLEX(DP), INTENT(INOUT) :: rhog(npwx)
     INTEGER, INTENT(IN) :: fixed_band_i, fixed_band_j, ispin
     LOGICAL, INTENT(IN) :: single_only
     !
     ! local variables
     !
     LOGICAL :: bse_kernel_from_cp
     LOGICAL :: bse_kernel_from_pwscf
     LOGICAL :: bse_kernel_from_qbox
     INTEGER             :: band_i, band_j
     CHARACTER(LEN=6)    :: my_labeli
     CHARACTER(LEN=6)    :: my_labelj
     CHARACTER(LEN=6)    :: my_spin
     CHARACTER(LEN=256)  :: file_base
     CHARACTER(LEN=256)  :: which_bse_kernel
     !
     which_bse_kernel = 'PWSCF'
     !
     !dirname = TRIM( tmp_dir ) // TRIM( west_prefix ) // '.wbse.init.save'
     !
     IF (fixed_band_j .lt. fixed_band_i) THEN
        !
        ! p_31 -> p_13
        !
        band_i = fixed_band_j
        !
        band_j = fixed_band_i
        !
     ELSE
        !
        band_i = fixed_band_i
        !
        band_j = fixed_band_j
        !
     ENDIF
     !
     write (my_labeli,'(i6.6)') band_i
     write (my_labelj,'(i6.6)') band_j
     write (my_spin,  '(i1)') ispin
     !
     rhog = (0.0_DP, 0.0_DP)
     !
     file_base = TRIM(savedir)//'/E'//TRIM(ADJUSTL(my_labeli))//"_"//TRIM(ADJUSTL(my_labelj))//"_"//TRIM(ADJUSTL(my_spin))//".dat"
     CALL pdep_read_G_and_distribute(file_base, rhog(:))
     !
     RETURN
     !
END SUBROUTINE read_bse_pots_g2g

SUBROUTINE read_bse_pots_g2r( rho_all, fixed_band_i, fixed_band_j, ispin, single_only)
     !
     ! ... this routine writes the pot-density in xml format
     !
     USE kinds,          ONLY : DP
     USE control_flags,  ONLY : gamma_only
     USE fft_base,       ONLY : dfftp, dffts
     USE io_global,      ONLY : ionode, stdout
     USE xml_io_base,    ONLY : read_rho_xml
     USE pdep_io,        ONLY : pdep_read_G_and_distribute
     USE gvect,          ONLY : ngm, ngmx
     USE fft_at_gamma,   ONLY : single_invfft_gamma
     USE fft_at_k,       ONLY : single_invfft_k
     USE westcom,        ONLY : savedir
     !
     IMPLICIT NONE
     !
     COMPLEX(DP), INTENT(INOUT) :: rho_all(dfftp%nnr)
     INTEGER, INTENT(IN) :: fixed_band_i, fixed_band_j, ispin
     LOGICAL, INTENT(IN) :: single_only
     !
     ! local variables
     !
     LOGICAL :: bse_kernel_from_cp
     LOGICAL :: bse_kernel_from_pwscf
     LOGICAL :: bse_kernel_from_qbox
     INTEGER             :: band_i, band_j
     REAL(DP)            :: rhoaux1(dfftp%nnr)
     REAL(DP)            :: rhoaux2(dfftp%nnr)
     COMPLEX(DP), ALLOCATABLE :: aux_g(:), aux_r(:)
     CHARACTER(LEN=6)    :: my_labeli
     CHARACTER(LEN=6)    :: my_labelj
     CHARACTER(LEN=6)    :: my_spin
     CHARACTER(LEN=256)  :: file_base, dirname
     CHARACTER(LEN=256) ::  which_bse_kernel
     !
     which_bse_kernel = 'PWSCF'
     bse_kernel_from_cp   = .false.
     bse_kernel_from_pwscf = .false.
     bse_kernel_from_qbox = .false.
     !
     SELECT CASE( trim( which_bse_kernel ) )
     CASE( 'CP' )
        !
        bse_kernel_from_cp   = .true.
        bse_kernel_from_pwscf = .false.
        bse_kernel_from_qbox = .false.
        !
     CASE( 'PWSCF' )
        !
        bse_kernel_from_cp   = .false.
        bse_kernel_from_pwscf = .true.
        bse_kernel_from_qbox = .false.
        !
     CASE( 'QBOX' )
        !
        CALL errore (' iobse', 'qbox bse ketnel not supported', 1)
        !
     CASE DEFAULT
        !
        CALL errore ( 'iobse ', 'a index needs to be supported',1)
        !
     END SELECT
     !
     ALLOCATE (aux_g(ngmx), aux_r(dfftp%nnr))
     !
     rhoaux1(:) = 0.0_DP
     rhoaux2(:) = 0.0_DP
     !
     !dirname = TRIM( tmp_dir ) // TRIM( west_prefix ) // '.wbse.init.save'
     !
     IF (fixed_band_j .lt. fixed_band_i) THEN
        !
        ! p_31 -> p_13
        !
        band_i = fixed_band_j
        !
        band_j = fixed_band_i
        !
     ELSE
        !
        band_i = fixed_band_i
        !
        band_j = fixed_band_j
        !
     ENDIF
     !
     IF (bse_kernel_from_cp) THEN
        !
        write (my_labeli,'(i6.6)') band_i
        write (my_labelj,'(i6.6)') band_j
        write (my_spin,  '(i1)') ispin
        !
        file_base = TRIM(savedir)//'/CP'//TRIM(my_labeli)//'_'//TRIM(my_labelj)//'_'//TRIM(my_spin)//".dat"
        !
        CALL read_rho_xml ( file_base, dfftp%nr1, dfftp%nr2, dfftp%nr3, &
                   dfftp%nr1x, dfftp%nr2x, dfftp%ipp, dfftp%npp, rhoaux1(:) )
        !
     ENDIF
     !
     IF (bse_kernel_from_pwscf) THEN
        !
        write (my_labeli,'(i6.6)') band_i
        write (my_labelj,'(i6.6)') band_j
        write (my_spin,  '(i1)') ispin
        !
        aux_g = (0.0_DP, 0.0_DP)
        !
        file_base = TRIM(savedir)//'/E'//TRIM(ADJUSTL(my_labeli))//&
                    "_"//TRIM(ADJUSTL(my_labelj))//"_"//TRIM(ADJUSTL(my_spin))//".dat"
        CALL pdep_read_G_and_distribute(file_base, aux_g(:))
        !
        ! G -> R
        !
        aux_r = (0.0_DP, 0.0_DP)
        !
        IF (gamma_only) THEN
           !
           CALL single_invfft_gamma(dffts,ngm,ngmx,aux_g,aux_r,'Dense')
           !
        ELSE
           !
           CALL single_invfft_k(dffts,ngm,ngmx,aux_g,aux_r,'Dense') ! no igk
           !
        ENDIF
        !
        rhoaux1(:) = DBLE(aux_r(:))
        !
     ENDIF
     !
     if (.not. single_only) then
        !
        if (fixed_band_j .lt. (fixed_band_i+1)) then
           !
           ! p_21 -> p_12
           !
           band_i = fixed_band_j
           !
           band_j = fixed_band_i+1
           !
        else
           !
           band_i = fixed_band_i+1
           !
           band_j = fixed_band_j
           !
        endif
        !
        IF (bse_kernel_from_cp) THEN
           !
           write (my_labeli,'(i6.6)')  band_i
           write (my_labelj,'(i6.6)')  band_j
           write (my_spin,  '(i1)') ispin
           !
           file_base = TRIM(savedir)//'/CP'//TRIM(my_labeli)//'_'//TRIM(my_labelj)//'_'//TRIM(my_spin)//".dat"
           !
           CALL read_rho_xml ( file_base, dfftp%nr1, dfftp%nr2, dfftp%nr3, &
                   dfftp%nr1x, dfftp%nr2x, dfftp%ipp, dfftp%npp, rhoaux2(:) )
           !
        ENDIF
        !
        IF (bse_kernel_from_pwscf) THEN
           !
           write (my_labeli,'(i6.6)') band_i
           write (my_labelj,'(i6.6)') band_j
           write (my_spin,  '(i1)') ispin
           !
           aux_g = (0.0_DP, 0.0_DP)
           !
           file_base = TRIM(savedir)//'/E'//TRIM(ADJUSTL(my_labeli))//&
                      "_"//TRIM(ADJUSTL(my_labelj))//"_"//TRIM(ADJUSTL(my_spin))//".dat"
           CALL pdep_read_G_and_distribute(file_base,aux_g(:))
           !
           ! G -> R
           !
           aux_r = (0.0_DP, 0.0_DP)
           !
           IF (gamma_only) THEN
              !
              CALL single_invfft_gamma(dffts,ngm,ngmx,aux_g,aux_r,'Dense')
              !
           ELSE
              !
              CALL single_invfft_k(dffts,ngm,ngmx,aux_g,aux_r,'Dense') ! no igk
              !
           ENDIF
           !
           rhoaux2(:) = DBLE(aux_r(:))
           !
        ENDIF
        !
     endif
     !
     ! total : rho(:) = [rho_ij, rho_i+1,j]
     !
     rho_all(:) = (0.0_DP, 0.0_DP)
     !
     rho_all(:) = CMPLX (rhoaux1(:), rhoaux2(:))
     !
     DEALLOCATE (aux_g, aux_r)
     !
     RETURN
     !
END SUBROUTINE read_bse_pots_g2r
!
!
SUBROUTINE read_umatrix_and_ovl_matrix(num_wan)
  !
  !
  ! ...   This subroutine writes orbs to unit emptyunitc0
  !
  USE kinds,              ONLY: DP
  USE io_global,          ONLY: ionode, ionode_id, stdout
  USE mp_images,          ONLY: intra_image_comm
  USE io_files,           ONLY: tmp_dir
  USE mp,                 ONLY: mp_bcast
  USE lsda_mod,           ONLY: nspin
  USE bse_module,         ONLY: u_matrix,ovl_matrix
  USE westcom,            ONLY: savedir
  !
  IMPLICIT NONE
  !
  INTEGER,       INTENT(IN) :: num_wan
  !
  LOGICAL :: exst
  INTEGER :: iw, jw, emptyunit, is
  CHARACTER(LEN=256) :: fileempty
  CHARACTER(LEN=4)   :: my_spin
  !
  ! ... Subroutine Body
  !
  !dirname  = TRIM( tmp_dir ) // TRIM( west_prefix ) // '.wbse.init.save'
  !
  DO is = 1, nspin
     !
     ! u_matrix
     !
     u_matrix(:,:,is) = (0.0_DP, 0.0_DP)
     !
     WRITE(my_spin,'(i1)') is
     fileempty = TRIM(savedir)//'/u_matrix.wan.occ.'//TRIM(my_spin)//'.dat'
     WRITE(stdout,'(/,5X,"Reading U matrix from ", A256 )') fileempty
     !
     emptyunit = 100
     !
     IF ( ionode ) THEN
        !
        INQUIRE( FILE = TRIM(fileempty), EXIST = EXST )
        !
        IF ( EXST ) THEN
           !
           OPEN( UNIT=emptyunit, FILE=TRIM(fileempty), STATUS='OLD', FORM='UNFORMATTED' )
           !
           READ(emptyunit) (( u_matrix(iw,jw,is), iw=1, num_wan), jw=1, num_wan )
           !
        ENDIF
        !
     ENDIF
     !
     CALL mp_bcast(u_matrix(:,:,is), ionode_id, intra_image_comm)
     !
     IF ( ionode ) CLOSE ( emptyunit )
     !
     ! ovl_matrix
     !
     ovl_matrix(:,:,is) = 0.0_DP
     !
     WRITE(my_spin,'(i1)') is
     fileempty = TRIM(savedir)//'/overlap_matrix.wan.occ.'//TRIM(my_spin)//'.dat'
     WRITE(stdout,'(/,5X,"Reading overlap matrix from ", A256 )') fileempty
     !
     emptyunit = 100
     !
     IF ( ionode ) THEN
        !
        INQUIRE( FILE = TRIM(fileempty), EXIST = EXST )
        !
        IF ( EXST ) THEN
           !
           OPEN( UNIT=emptyunit, FILE=TRIM(fileempty), STATUS='OLD', FORM='UNFORMATTED' )
           !
           READ(emptyunit) (( ovl_matrix(iw,jw,is), iw=1, num_wan), jw=1, num_wan )
           !
        ENDIF
        !
     ENDIF
     !
     CALL mp_bcast(ovl_matrix (:,:,is), ionode_id, intra_image_comm)
     !
     IF ( ionode ) CLOSE ( emptyunit )
     !
  ENDDO
  !
  RETURN
  !
ENDSUBROUTINE
!
!
!
subroutine write_matrix (num_wan,ispin,u_matrix,ovl_matrix)
  !
  ! ...   This subroutine writes orbs to unit emptyunitc0
  !
  USE kinds,              ONLY: DP
  USE io_global,          ONLY: ionode, stdout
  USE io_files,           ONLY: tmp_dir
  USE westcom,            ONLY : savedir
  !
  IMPLICIT NONE
  !
  integer,           intent(in) :: num_wan,ispin
  complex(DP),       intent(in) :: u_matrix(num_wan,num_wan)
  real(DP),          intent(in) :: ovl_matrix(num_wan,num_wan)
  !
  INTEGER            :: iw, jw, emptyunit
  character(len=256) :: fileempty
  character(len=4)   :: my_spin
  !
  ! ... Subroutine Body
  !
  !dirname  = TRIM( tmp_dir ) // TRIM( west_prefix ) // '.wbse.init.save/'
  !
  WRITE(my_spin,'(i1)') ispin
  fileempty = TRIM(savedir)//'/u_matrix.wan.occ.'//TRIM(my_spin)//'.dat'
  WRITE(stdout,'(/,5X,"Writing U matrix to file ", A256 )') fileempty
  !
  emptyunit = 100
  !
  IF ( ionode ) THEN
     !
     !
     OPEN( UNIT = emptyunit, FILE = TRIM(fileempty), status = 'unknown', FORM = 'UNFORMATTED' )
     !
     REWIND( emptyunit )
     !
     WRITE ( emptyunit ) (( u_matrix(iw,jw), iw=1, num_wan), jw=1, num_wan )
     !
  ENDIF
  !
  IF ( ionode ) CLOSE ( emptyunit )
  !
  WRITE(my_spin,'(i1)') ispin
  fileempty = TRIM(savedir)//'/u_matrix.wan.occ.formated.'//TRIM(my_spin)//'.dat'
  WRITE(stdout,'(/,5X,"Writing formatted U matrix to file ", A256 )') fileempty
  !
  emptyunit = 100
  !
  IF ( ionode ) THEN
     !
     OPEN( UNIT = emptyunit, FILE = TRIM(fileempty), status = 'unknown', FORM = 'FORMATTED' )
     !

     REWIND( emptyunit )
     !
     DO iw = 1, num_wan
        DO jw = 1, num_wan
           WRITE ( emptyunit, *) iw, jw, u_matrix(iw,jw)
        ENDDO
     ENDDO
     !
  ENDIF
  !
  IF ( ionode ) CLOSE ( emptyunit )
  !
  WRITE(my_spin,'(i1)') ispin
  fileempty = TRIM(savedir)//'/overlap_matrix.wan.occ.'//TRIM(my_spin)//'.dat'
  WRITE(stdout,'(/,5X,"Writing overlap matrix to file ", A256 )') fileempty
  !
  emptyunit = 100
  !
  IF ( ionode ) THEN
     !
     !
     OPEN( UNIT = emptyunit, FILE = TRIM(fileempty), status = 'unknown', FORM = 'UNFORMATTED' )
     !
     REWIND( emptyunit )
     !
     WRITE ( emptyunit ) (( ovl_matrix(iw,jw), iw=1, num_wan), jw=1, num_wan )
     !
  ENDIF
  !
  IF ( ionode ) CLOSE ( emptyunit )
  !
  WRITE(my_spin,'(i1)') ispin
  fileempty = TRIM(savedir)//'/overlap_matrix.wan.occ.formated.'//TRIM(my_spin)//'.dat'
  WRITE(stdout,'(/,5X,"Writing format overlap matrix to file ", A256 )') fileempty
  !
  emptyunit = 100
  !
  IF ( ionode ) THEN
     !
     !
     OPEN( UNIT = emptyunit, FILE = TRIM(fileempty), status = 'unknown', FORM = 'FORMATTED' )
     !
     REWIND( emptyunit )
     !
     DO iw = 1, num_wan
        DO jw = 1, num_wan
           WRITE ( emptyunit, *) iw, jw, ovl_matrix(iw,jw)
        ENDDO
     ENDDO
     !
  ENDIF
  !
  IF ( ionode ) CLOSE ( emptyunit )
  !
  RETURN
  !
ENDSUBROUTINE
!
!
SUBROUTINE write_umatrix_and_omatrix (oumat_dim,ispin,umatrix,omatrix)
  !
  ! ...   This subroutine writes orbs to unit emptyunitc0
  !
  USE kinds,                ONLY : DP
  USE iotk_module
  USE mp_world,             ONLY : root,world_comm
  USE io_global,            ONLY : ionode,stdout
  USE mp,                   ONLY : mp_barrier,mp_bcast,mp_get
  USE mp_global,            ONLY : intra_image_comm,my_pool_id,my_bgrp_id,&
                                   me_bgrp,root_bgrp,inter_bgrp_comm,inter_pool_comm
  USE distribution_center,  ONLY : bseparal
  USE westcom,              ONLY : savedir
  !
  IMPLICIT NONE
  !
  ! I/O
  !
  INTEGER,           INTENT(IN)   :: oumat_dim,ispin
  REAL(DP),          INTENT(IN)   :: omatrix(oumat_dim,oumat_dim)
  COMPLEX(DP),       INTENT(IN)   :: umatrix(oumat_dim,oumat_dim)
  !
  ! Workspace
  !
  INTEGER :: ierr, iunout
  CHARACTER(LEN=256)  :: filename
  CHARACTER(LEN=4)    :: my_spin
  !
  ! BARRIER
  !
  CALL mp_barrier(world_comm)
  !
  WRITE(my_spin,'(i1)') ispin
  filename =  TRIM(savedir) // 'u_matrix.wan.occ.' // TRIM(my_spin) // ".dat"
  !
  WRITE(stdout,'(/,5X,"Writing Omatrix & Umatrix to ", A256 )') filename
  !
  IF(my_pool_id.NE.0) RETURN
  IF(my_bgrp_id.NE.0) RETURN
  !
  ! Resume all components
  !
  IF (me_bgrp==root_bgrp) THEN
     !
     ! ... open XML descriptor
     !
     CALL iotk_free_unit(iunout,ierr)
     CALL iotk_open_write( iunout, FILE = filename, BINARY = .False., IERR = ierr )
     !
     CALL iotk_write_begin(iunout,"OUMATRIX_SIZE")
     CALL iotk_write_dat(iunout,"oumat_dim", oumat_dim)
     CALL iotk_write_end(iunout,"OUMATRIX_SIZE")
     !
     CALL iotk_write_begin(iunout, "UMATRIX_ELE")
     CALL iotk_write_dat(iunout, "umat_ele", umatrix(:,:))
     CALL iotk_write_end(iunout, "UMATRIX_ELE")
     !
     CALL iotk_write_begin(iunout, "OMATRIX_ELE")
     CALL iotk_write_dat(iunout, "omat_ele", omatrix(:,:))
     CALL iotk_write_end(iunout, "OMATRIX_ELE")
     !
     CALL iotk_close_write(iunout)
     !
  ENDIF
  !
  ! BARRIER
  !
  CALL mp_barrier(world_comm)
  !
  RETURN
  !
END SUBROUTINE
!
SUBROUTINE read_umatrix_and_omatrix (oumat_dim,ispin,umatrix,omatrix)
  !
  USE kinds,                ONLY : DP
  USE iotk_module
  USE io_global,            ONLY : stdout,ionode
  USE mp_world,             ONLY : world_comm,root
  USE mp,                   ONLY : mp_bcast,mp_barrier
  USE mp_global,            ONLY : intra_image_comm
  USE westcom,              ONLY : savedir
  !
  IMPLICIT NONE
  !
  ! I/O
  !
  INTEGER,           INTENT(IN)   :: oumat_dim,ispin
  REAL(DP),          INTENT(INOUT):: omatrix(oumat_dim,oumat_dim)
  COMPLEX(DP),       INTENT(INOUT):: umatrix(oumat_dim,oumat_dim)
  !
  ! Workspace
  !
  INTEGER :: ierr,iunout
  INTEGER :: oumat_dim_tmp
  CHARACTER(LEN=256)  :: filename
  CHARACTER(LEN=4)    :: my_spin
  REAL(DP),    ALLOCATABLE :: omatrix_tmp(:,:)
  COMPLEX(DP), ALLOCATABLE :: umatrix_tmp(:,:)
  !
  !
  ! BARRIER
  !
  CALL mp_barrier(world_comm)
  !
  !dirname  = TRIM( tmp_dir ) // TRIM( west_prefix ) // '.wbse.init.save'
  WRITE(my_spin,'(i1)') ispin
  filename = TRIM(savedir)//'/u_matrix.wan.occ.'//TRIM(my_spin)//'.dat'
  !
  WRITE(stdout,'(/,5X,"Reading Omatrix & Umatrix from ", A256 )') filename
  !
  ierr = 0
  IF ( ionode ) THEN
     CALL iotk_free_unit( iunout, ierr )
     CALL iotk_open_read( iunout, FILE = TRIM( filename ), BINARY = .False., IERR = ierr )
  ENDIF
  !
  CALL mp_bcast( ierr, root, world_comm )
  !
  IF ( ierr /=0 ) CALL errore( 'write_umatrix_and_ovl_matrix', 'cannot open file for reading', ierr )
  !
  IF ( ionode ) THEN
     !
     CALL iotk_scan_begin(iunout, "OUMATRIX_SIZE" )
     CALL iotk_scan_dat(  iunout, "oumat_dim", oumat_dim_tmp)
     CALL iotk_scan_end(  iunout, "OUMATRIX_SIZE" )
     !
  ENDIF
  !
  CALL mp_bcast( oumat_dim_tmp, 0, intra_image_comm )
  !
  ALLOCATE(umatrix_tmp(oumat_dim_tmp,oumat_dim_tmp))
  ALLOCATE(omatrix_tmp(oumat_dim_tmp,oumat_dim_tmp))
  !
  IF ( ionode ) THEN
     !
     CALL iotk_scan_begin(iunout, "UMATRIX_ELE")
     CALL iotk_scan_dat(  iunout, "umat_ele", umatrix_tmp(:,:))
     CALL iotk_scan_end(  iunout, "UMATRIX_ELE")
     !
  ENDIF
  !
  IF ( ionode ) THEN
     !
     CALL iotk_scan_begin(iunout, "OMATRIX_ELE")
     CALL iotk_scan_dat(  iunout, "omat_ele", omatrix_tmp(:,:))
     CALL iotk_scan_end(  iunout, "OMATRIX_ELE")
     !
  ENDIF
  !
  IF ( ionode ) CALL iotk_close_read( iunout )
  !
  CALL mp_bcast( umatrix_tmp, 0 , intra_image_comm )
  CALL mp_bcast( omatrix_tmp, 0 , intra_image_comm )
  !
  umatrix(:,:) = 0.0
  omatrix(:,:) = 0.0
  umatrix(1:oumat_dim_tmp,1:oumat_dim_tmp) = umatrix_tmp(1:oumat_dim_tmp,1:oumat_dim_tmp)
  omatrix(1:oumat_dim_tmp,1:oumat_dim_tmp) = omatrix_tmp(1:oumat_dim_tmp,1:oumat_dim_tmp)
  !
  DEALLOCATE(umatrix_tmp)
  DEALLOCATE(omatrix_tmp)
  !
  RETURN
  !
END SUBROUTINE
!
subroutine read_pwscf_wannier_orbs ( ne, npw, c_emp, filename )
  !
  ! ... This subroutine reads wannier orbital from unit emptyunit
  !
  USE kinds,              ONLY: DP
  USE iotk_module
  USE io_global,          ONLY: stdout
  USE gvect,              ONLY: ig_l2g
  USE mp_wave,            ONLY: splitwf
  USE mp,                 ONLY: mp_get,mp_size,mp_rank,mp_bcast,mp_max
  USE mp_global,          ONLY: me_bgrp,root_bgrp,nproc_bgrp,intra_bgrp_comm, &
                                my_pool_id,my_bgrp_id,inter_bgrp_comm,inter_pool_comm
  USE klist,              ONLY: ngk, igk_k
  USE wvfct,              ONLY: npwx
  !
  IMPLICIT NONE
  !
  INTEGER,     INTENT (IN)   :: npw,ne
  COMPLEX(DP), INTENT(INOUT) :: c_emp(npw,ne)
  CHARACTER(LEN=*),INTENT(IN):: filename
  !
  LOGICAL :: exst
  INTEGER :: ierr, iun, ig, i, iss, is
  INTEGER :: ngw_rd, ne_rd, ngw_l, ngw_g
  !
  CHARACTER(LEN=256)       :: fileempty
  COMPLEX(DP), ALLOCATABLE :: ctmp(:)
  INTEGER, ALLOCATABLE     :: igk_l2g(:)
  !
  ! ... Subroutine Body
  !
  ALLOCATE ( igk_l2g( npwx ) )
  !
  ! ... the igk_l2g_kdip local-to-global map is needed to read wfcs
  !
  igk_l2g = 0
  DO ig = 1, ngk(1)
     igk_l2g(ig) = ig_l2g(igk_k(ig,1))
  ENDDO
  !
  fileempty = TRIM(filename)
  !
  WRITE(stdout,'(/,5X,"Reading pwscf wannier orbs from ", A8 )') fileempty
  !
  ngw_l    = npw!MAXVAL(igk_l2g(:))
  ngw_g    = MAXVAL(igk_l2g(:))
  CALL mp_max(ngw_g,intra_bgrp_comm)
  !
  ALLOCATE( ctmp(ngw_g) )
  !
  IF (my_pool_id==0.AND.my_bgrp_id==0) THEN
     !
     ! ONLY ROOT W/IN BGRP READS
     !
     IF (me_bgrp==root_bgrp) THEN
        !
        CALL iotk_free_unit( iun, ierr )
        CALL iotk_open_read( iun, FILE = TRIM(fileempty), BINARY = .TRUE., IERR = ierr)
        !
     ENDIF
     !
  ENDIF
  !
  CALL mp_bcast(ierr,0,inter_bgrp_comm)
  !
  IF (my_pool_id==0.AND.my_bgrp_id==0) THEN
     !
     ! ONLY ROOT W/IN BGRP READS
     !
     IF (me_bgrp==root_bgrp) THEN
        !
        CALL iotk_scan_begin( iun, 'WANWFC_GSPACE' )
        !
     ENDIF
     !
  ENDIF
  !
  DO i = 1, ne
     !
     IF (my_pool_id==0.AND.my_bgrp_id==0) THEN
        !
        ! ONLY ROOT W/IN BGRP READS
        !
        IF (me_bgrp==root_bgrp) THEN
           !
           CALL iotk_scan_dat( iun, &
                             "wfc" // iotk_index(i), ctmp(:))
           !
        ENDIF
        !
        CALL splitwf( c_emp(:,i), ctmp, ngw_l, igk_l2g, &
                         me_bgrp, nproc_bgrp, root_bgrp, intra_bgrp_comm)
        !
     ENDIF
     !
  ENDDO
  !
  IF (my_pool_id==0.AND.my_bgrp_id==0) THEN
     !
     ! ONLY ROOT W/IN BGRP READS
     !
     IF (me_bgrp==root_bgrp) THEN
        !
        CALL iotk_scan_end( iun, 'WANWFC_GSPACE' )
        CALL iotk_close_read( iun )
        !
     ENDIF
     !
  ENDIF
  !
  DEALLOCATE(ctmp, igk_l2g)
  !
  CALL mp_bcast(c_emp,0,inter_bgrp_comm)
  CALL mp_bcast(c_emp,0,inter_pool_comm)
  !
  RETURN
  !
END SUBROUTINE read_pwscf_wannier_orbs
