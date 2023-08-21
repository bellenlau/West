import numpy as np
import json
import pytest
from xml.etree import ElementTree as ET

######################
# REUSABLE FUNCTIONS #
######################


def read_total_energy(fileName):
    """
    Reads the PW total energy from file
    """

    xmlData = ET.parse(fileName)
    total_energy = np.array([(xmlData.find('output').find('total_energy').find('etot').text)],dtype='f8')

    return total_energy


def read_and_test_total_energies(fileA,fileB,tol):
    """
    Reads and tests the total energies
    """

    test_energy = read_total_energy(fileA)
    ref_energy = read_total_energy(fileB)

    maxDiff = np.amax(np.abs(test_energy-ref_energy))
    print(f'Total energy (pwscf) max diff: {maxDiff}')

    assert np.allclose(test_energy,ref_energy,rtol=0,atol=tol),'Total energies changed'


def read_wstat_eigenvalues(fileName):
    """
    Reads the eigenvalues in wstat
    """

    with open(fileName,'r') as f:
        data = json.load(f)

    pdep_eig = {}
    if 'Q1' in data['exec']['davitr']:
        for iq in data['exec']['davitr']:
            pdep_eig[iq] = np.array(data['exec']['davitr'][iq][-1]['ev'],dtype='f8')
    else:
        pdep_eig['Q1'] = np.array(data['exec']['davitr'][-1]['ev'],dtype='f8')

    return pdep_eig


def read_and_test_wstat_eigenvalues(fileA,fileB,tol):
    """
    Reads and tests PDEP eigenvalues
    """

    test_pdep_eig = read_wstat_eigenvalues(fileA)
    ref_pdep_eig = read_wstat_eigenvalues(fileB)

    maxDiff = 0.0
    for iq in ref_pdep_eig:
        maxDiff = max(maxDiff,np.amax(np.abs(test_pdep_eig[iq]-ref_pdep_eig[iq])))
    print(f'PDEP eigenvalues (wstat) max diff: {maxDiff}')

    for iq in ref_pdep_eig:
        assert np.allclose(test_pdep_eig[iq],ref_pdep_eig[iq],rtol=0,atol=tol),f'PDEP eigenvalues changed, iq {iq}'


def read_wfreq_energies(fileName):
    """
    Reads the energies in wfreq
    """

    with open(fileName,'r') as f:
        data = json.load(f)

    en = {}
    for ik in range(1,data['system']['electron']['nkstot']+1):
        kindex = f'K{ik:06d}'
        en[ik] = {}
        for key in data['output']['Q'][kindex]:
            if 'im' in data['output']['Q'][kindex][key] and 're' in data['output']['Q'][kindex][key]:
                en[ik][key] = np.array(data['output']['Q'][kindex][key]['re'],dtype='c16')
                en[ik][key] += 1j * np.array(data['output']['Q'][kindex][key]['im'],dtype='c16')
            else:
                if key != 'occupation':
                    en[ik][key] = np.array(data['output']['Q'][kindex][key],dtype='f8')

    return en


def read_and_test_wfreq_energies(fileA,fileB,tol):
    """
    Reads and tests single-particle energies
    """

    test_en = read_wfreq_energies(fileA)
    ref_en = read_wfreq_energies(fileB)

    maxDiff = 0.0
    for ik in ref_en:
        for key in ref_en[ik]:
            maxDiff = max(maxDiff,np.amax(np.abs(np.abs(test_en[ik][key])-np.abs(ref_en[ik][key]))))
    print(f'Single-particle energy (wfreq) max diff: {maxDiff}')

    for ik in ref_en:
        for key in ref_en[ik]:
            assert np.allclose(np.abs(test_en[ik][key]),np.abs(ref_en[ik][key]),rtol=0,atol=tol),f'Single-particle energies changed, ik {ik}, field {key}'


def read_wbse_davidson(fileName):
    """
    Reads the eigenvalues in wbse
    """

    with open(fileName,'r') as f:
        data = json.load(f)

    return np.array(data['exec']['davitr'][-1]['ev'],dtype='f8')


def read_and_test_wbse_davidson(fileA,fileB,tol):
    """
    Reads and tests wbse eigenvalues
    """

    test_wbse_eig = read_wbse_davidson(fileA)
    ref_wbse_eig = read_wbse_davidson(fileB)

    maxDiff = np.amax(np.abs(test_wbse_eig-ref_wbse_eig))
    print(f'BSE/TDDFT eigenvalues (wbse) max diff: {maxDiff}')

    assert np.allclose(test_wbse_eig,ref_wbse_eig,rtol=0,atol=tol),'BSE/TDDFT eigenvalues changed'


def read_wbse_lanczos(fileName):
    """
    Reads the beta and zeta values in wbse
    """

    with open(fileName,'r') as f:
        data = json.load(f)

    beta = np.array(data['output']['lanczos']['K000001']['XX']['beta'],dtype='f8')
    zeta = np.array(data['output']['lanczos']['K000001']['XX']['zeta'],dtype='f8')

    return beta,zeta


def read_and_test_wbse_lanczos(fileA,fileB,tol):
    """
    Reads and tests BSE/TDDFT Lanczos
    """

    test_beta,test_zeta = read_wbse_lanczos(fileA)
    ref_beta,ref_zeta = read_wbse_lanczos(fileB)

    maxDiff = np.amax(np.abs(test_beta-ref_beta))
    print(f'BSE/TDDFT beta (wbse) max diff: {maxDiff}')

    assert np.allclose(test_beta,ref_beta,rtol=0,atol=tol),'BSE/TDDFT beta changed'

    maxDiff = np.amax(np.abs(test_zeta-ref_zeta))
    print(f'BSE/TDDFT zeta (wbse) max diff: {maxDiff}')

    assert np.allclose(test_zeta,ref_zeta,rtol=0,atol=tol),'BSE/TDDFT zeta changed'


def read_wbse_forces(fileName):
    """
    Reads the forces in wbse
    """

    with open(fileName,'r') as f:
        data = json.load(f)

    forces = {}
    for key in data['exec']['forces']:
        forces[key] = np.array(data['exec']['forces'][key],dtype='f8')

    return forces


def read_and_test_wbse_forces(fileA,fileB,tol):
    """
    Reads and tests TDDFT forces
    """

    test_f = read_wbse_forces(fileA)
    ref_f = read_wbse_forces(fileB)

    maxDiff = 0.0
    for key in ref_f:
        maxDiff = max(maxDiff,np.amax(np.abs(test_f[key]-ref_f[key])))
    print(f'TDDFT forces (wbse) max diff: {maxDiff}')

    for key in ref_f:
        assert np.allclose(test_f[key],ref_f[key],rtol=0,atol=tol),f'TDDFT forces changed, field {key}'


#########
# TESTS #
#########


@pytest.mark.parametrize('testdir',['test001','test002','test003','test004','test005','test006','test007','test008','test009','test010','test011','test012','test013','test014','test015','test016','test017','test018','test019','test020','test021','test022','test023','test024','test025','test026','test027','test028'])
def test_totalEnergy(testdir):
    with open('parameters.json','r') as f:
        parameters = json.load(f)
    read_and_test_total_energies(testdir+'/test.save/data-file-schema.xml',testdir+'/ref/pw.xml',float(parameters['tolerance']['total_energy']))


@pytest.mark.parametrize('testdir',['test001','test002','test003','test004','test005','test006','test007','test009','test010','test011','test012','test013','test014','test016','test017','test020'])
def test_pdepEigen(testdir):
    with open('parameters.json','r') as f:
        parameters = json.load(f)
    read_and_test_wstat_eigenvalues(testdir+'/test.wstat.save/wstat.json',testdir+'/ref/wstat.json',float(parameters['tolerance']['pdep_eigenvalue']))


@pytest.mark.parametrize('testdir',['test001','test002','test003','test004','test006','test007','test009','test010','test011','test012','test013','test014','test020'])
def test_singleparticleEnergy(testdir):
    with open('parameters.json','r') as f:
        parameters = json.load(f)
    read_and_test_wfreq_energies(testdir+'/test.wfreq.save/wfreq.json',testdir+'/ref/wfreq.json',float(parameters['tolerance']['singleparticle_energy']))


@pytest.mark.parametrize('testdir',['test016','test018'])
def test_bseSpectrum(testdir):
    with open('parameters.json','r') as f:
        parameters = json.load(f)
    read_and_test_wbse_lanczos(testdir+'/test.wbse.save/wbse.json',testdir+'/ref/wbse.json',float(parameters['tolerance']['bse']))


@pytest.mark.parametrize('testdir',['test017','test019','test021','test022','test023','test024','test025','test026','test027','test028'])
def test_bseEigen(testdir):
    with open('parameters.json','r') as f:
        parameters = json.load(f)
    read_and_test_wbse_davidson(testdir+'/test.wbse.save/wbse.json',testdir+'/ref/wbse.json',float(parameters['tolerance']['bse']))


@pytest.mark.parametrize('testdir',['test022','test023','test024','test025','test026','test027','test028'])
def test_tddftForces(testdir):
    with open('parameters.json','r') as f:
        parameters = json.load(f)
    read_and_test_wbse_forces(testdir+'/test.wbse.save/wbse.json',testdir+'/ref/wbse.json',float(parameters['tolerance']['forces']))
