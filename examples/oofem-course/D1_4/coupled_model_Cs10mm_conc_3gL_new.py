# -*- coding: utf-8 -*-
import sys,os
#sys.path.append('/home/ravi/ownCloud/codes/GeoFiPy')
sys.path.append('../GeoFiPy')
import GeoFiPy
import numpy as np
#sys.path.append("/mnt/hgfs/switchdrive/codes/oofem/optimized")
#sys.path.append("/home/ravi/Documents/oofem/oofem/optimized")
#sys.path.append("/home/ravi/oofem/optimized/")
import oofempy
import shutil
from tvtk.api import write_data
from scipy.interpolate import LinearNDInterpolator
from scipy.integrate import odeint
from multiprocessing import Pool
#%% Compositional input parameters
#wcRatio = 0.55 #water cement ratio
#DegHyd = 0.88 #degree of hydration
AggVolFracTotal=0.5643214482459008 #tol volume fraction of aggregate
AggVolFracResolved=0.24161981788830625#resovled aggregate volume fraction in mesomodel
#%%material dependent input parameters
D0 = 1.2e-9 # diffusivity of sulphate ions in pure water
kett  =   6e-9# reaction rate range()
krat = 0.07
alpha_s = 1.39e-4 # range()
alpha_s_ch=4.19e-5
q=2.794
C_C3A_paste=273.404
C_CH_paste = 2827.275708
cb = 21.1#boundary sulfate concentration
f_csh= 0.0
f_cap= .06
f_crack = 1
CSH_frac=0.4343
f_small_cap = 0.0
kgyp =  kett * krat
f_phi = 0.15# (f_csh * phi_csh  + f_cap* phi_cap)/(phi_cap+phi_csh)
#%%porosities of cement paste computed from jennings and tennings model
phi_csh_cp=0.0975
phi_cap_cp= 0.276
dvf_csh = 0.1
dfrac_small_cap = 0.
#%%
Tf = 365
 #final simulation time in days
dTCoupling =1#output time and coupling transfer time in days
dt_fipy=0.1*86400
#%%Input file paths
FiPyMeshPath='MesoFiPyCs10mm.msh'
FiPyOutPutPath = 'FiPyResults_Cs10mm_3gL/'
OOFEMInPutPath = 'Meso_oofem_Cs10mm_3gL.in'
OOFEMOutPutPath='oofemResults_Cs10mm_3gL/'
if os.path.isdir(FiPyOutPutPath):
    print("removing existing fipy output dir...")
    shutil.rmtree(FiPyOutPutPath, ignore_errors=True)
os.mkdir(FiPyOutPutPath)
#if os.path.isdir(OOFEMOutPutPath):
    #print("removing existing oofem output dir...")
    #os.system("rm -rf %s"%OOFEMOutPutPath)
#os.mkdir(OOFEMOutPutPath)
#%%
M_ett =1.2551  # ettringite molar mass (kg/mol)
#%% Mix Info of the composition
AggVolFrac= AggVolFracTotal-AggVolFracResolved #unresolved agg volume fraction
CementPasteVolFrac= 1 -AggVolFrac
#VwByVc = wcRatio *(rho_clk/rho_water)
#CementVolFrac= CementPasteVolFrac/(1+VwByVc)
C3AInitConc = CementPasteVolFrac * C_C3A_paste #mol/m3
CHInitConc =  CementPasteVolFrac * C_CH_paste
phiInit = CementPasteVolFrac *(phi_cap_cp+ phi_csh_cp)
phi_csh = CementPasteVolFrac * phi_csh_cp
phi_cap = CementPasteVolFrac * phi_cap_cp
de_csh = (1/400)*D0*CementPasteVolFrac*CSH_frac
max_gyp  = 0.5 * CHInitConc
#%%
#%%
print ('----key parameters deduced from cement composition -----')
print('AggVolFrac (not resolved): %s'%AggVolFrac)
print('C3AConc: %s mol/m3'%C3AInitConc )
print('Mortar total porosity: %s'%phiInit)
print ('--------------------------------------------------------')
#%%Constitutive model computation functions for RT model
def phi_t(C3AConc,CHConc):
    """
    function calculates change in porosity with respect to time
    """
    global C3AInitConc,CHInitConc, phiInit,alpha_s, alpha_s_ch
    C3A_reac =  C3AInitConc-C3AConc
    CH_reac = CHInitConc - CHConc
    return phiInit - alpha_s*C3A_reac  - alpha_s_ch  * CH_reac
#%% diffusion coefficient model
# in terms of damage variable
def De_damage_parameter_based(phi_mortar,Damage=0):
    """
    function calculates diffusivity with respect to porosity
    """
    global AggVolFrac,D0
    phi = phi_mortar/(1-AggVolFrac)
    de_t = (1-AggVolFrac)*D0 * phi**6
    if type(Damage).__name__=='ndarray':
        Damage[Damage>1]=1
        Damage[Damage<0]=0
    else:
        if Damage<0:Damage=0
        if Damage>1:Damage=1
    de_t = (1-Damage) * de_t + phi_mortar*Damage*D0
    return de_t
#in terms of crack width 
def De_crack_width_based(phi_mortar,w=0.,wmin=20,wcr=100):
    global AggVolFrac,D0,lmean_fipy,de_csh
    phi = phi_mortar/(1-AggVolFrac)
    de_intact = (1-AggVolFrac)*D0 * phi**6
    if (type(de_intact).__name__) == 'ndarray':
        de_intact[de_intact<de_csh] = de_csh
    else:
        de_intact = min(de_intact,de_csh)
    de_lin = de_intact + (w-wmin)/(wcr-wmin) * (D0-de_intact)
    if type(w).__name__ == 'ndarray':w[w <=0]=0
    de_cr = (de_intact *(w<wmin) + 
            de_lin *(w>=wmin)*(w<=wcr) +
            D0 *(w>wcr))
    phi = w/(lmean_fipy*1e6)
    phi[phi>1] = 1
    phi[phi<0] = 0 
    de_t = de_cr * (phi) + de_intact * (1-phi)
    return de_t
#%%
def get_dt(vcell,Decell,phi):
    """
    function to get stable explicit time step
    """
    return 40*min(phi*vcell/Decell)
#%%
def volchange_old(C3AConc,CHConc,cwidth):
    """
    function to calcuate change in volume from current C3Aconc
    """
    global C3AInitConc,phiInit,alpha_s_ch,alpha_s,CHInitConc,f_crack, lmean_fipy
    print(np.min(cwidth),np.max(cwidth))
    C3A_reac =  C3AInitConc-C3AConc 
    CH_reac = CHInitConc - CHConc
    cwidth[cwidth <=0]=0
    v_change= alpha_s*C3A_reac +alpha_s_ch  * CH_reac - f_phi*phi_cap - f_crack * (cwidth/(lmean_fipy*1e6)) 
    v_change[v_change<=0 ]=0
    return v_change
#%%
def volchange(C3AConc,CHConc,cwidth):
    """
    New model to compute volume change dividing pore space into c-s-h and medium and large capillary pores
    """

    global phi_csh, phi_cap, f_csh, f_cap,alpha_s_ch,alpha_s,CHInitConc, dvf_csh
    
    C3A_reac =  C3AInitConc-C3AConc 
    CH_reac = CHInitConc - CHConc
    dvAl = alpha_s * C3A_reac 
    dvCH = alpha_s_ch  * CH_reac
    dv1 = dvCH - phi_csh*f_csh
    dv1[dv1<=0]=0
    dv2 = dvAl - phi_cap*f_cap * (1-dfrac_small_cap) - phi_cap*f_small_cap *dfrac_small_cap- f_crack * (cwidth/(lmean_fipy*1e6)) 
    dv2[dv2<=0]=0
    dv= dv1+dv2
    return dv
#%%reaction kinetics implementation
def reactEuler(aq0,ch0,al0):    
    global dt_fipy,q,CHInitConc, max_gyp
    aq =aq0 + (- kgyp * aq0  * ch0 * (1-((CHInitConc-ch0)/max_gyp))  -kett * aq0 * al0/q)*dt_fipy
    ch =ch0 + (- kgyp * aq0  * ch0 * (1-((CHInitConc-ch0)/max_gyp))) *dt_fipy
    al =al0 +(-kett * aq0 * al0)*dt_fipy
    return aq,ch,al
#%%FiPy model initialization
# domain and mesh
m=GeoFiPy.Gmsh2D(FiPyMeshPath)
lmean_fipy =m.cellVolumes**0.5
print(np.min(lmean_fipy)*1e6,np.max(lmean_fipy)*1e6)
# physics defination 
dp = {'D':De_crack_width_based(phiInit),'c':0.,'phi_w':phi_t(C3AInitConc,CHInitConc)}
C3AConc = GeoFiPy.CellVariable(mesh=m,value = C3AInitConc,name='Solid_Aluminates')
CHConc = GeoFiPy.CellVariable(mesh=m,value = CHInitConc,name='CH')
C3AConc = C3AConc.value
CHConc = CHConc.value
sp = {'intg_type':'implicit'}
cSulf = GeoFiPy.physics.Diffusion(m,dp,sp)
cSulf.set_drilichet_bc(cb,m.facesLeft)
cSulf.set_drilichet_bc(cb,m.facesTop)
cSulf.set_drilichet_bc(cb,m.facesRight)
cSulf.set_drilichet_bc(cb,m.facesBottom)
# dt_fipy = get_dt(m.cellVolumes,cSulf.D.value,phiInit)
cell_centres_fipy = m.cellCenters.value.T
#%%OOFEM model initialization
dr = oofempy.OOFEMTXTDataReader(OOFEMInPutPath)
oofem_problem = oofempy.InstanciateProblem(dr, oofempy.problemMode.processor, 0, None, False)
domain = oofem_problem.giveDomain(1)
nElem = domain.giveNumberOfElements()
nDoFs = domain.giveNumberOfDofManagers()
#initiate field for volumetric strain and register it    
f = oofempy.DofManValueField(oofempy.FieldType.FT_Temperature,nDoFs,nElem,"transienttransport","heattransfer")
node_coords_oofem=[]
for i in range(1,nDoFs+1):#Nodes
    node = domain.giveDofManager(i)
    coords = node.giveCoordinates()
    f.addNode(node.giveNumber(), coords)
    node_coords_oofem.append([coords[0],coords[1]])
node_coords_oofem = np.array(node_coords_oofem)
for i in range(1,nElem+1):#Elements
    elem = domain.giveElement(i)
    geomType = elem.giveGeometryType()
    nodes = elem.giveDofManArray()
    f.addElement(elem.giveNumber(), "tr1ht", nodes)
#register field in oofem
context = oofem_problem.giveContext()
field_man = context.giveFieldManager()
field_man.registerField(f, oofempy.FieldType.FT_Temperature)
oofem_problem.checkProblemConsistency()
oofem_problem.init()
oofem_problem.postInitialize()
oofem_problem.solveYourself()
#exit(0)

oofem_problem.giveTimer().startTimer(oofempy.EngngModelTimerType.EMTT_AnalysisTimer)
activeMStep = oofem_problem.giveMetaStep(1)
oofem_problem.initMetaStepAttributes(activeMStep)
oofem_problem.setRenumberFlag()
oofempy.vtkxml(1, oofem_problem)
vtkxml = oofempy.vtkxml(1, oofem_problem, domain_all=True, tstep_all=True, dofman_all=True, element_all=True, vars=(1, 2, 52,90), primvars=(1,), stype=2, pythonExport=1)
#%%kernel
t_global = 0.
t_fipy = 0.
cwidth=0. * lmean_fipy

TotalLastStrain=[0. for i in range (nDoFs+1) ] #FCMV

while t_global < Tf:
    #%%run fipy
    t_global+=dTCoupling
    while t_fipy < t_global:
        t_fipy =cSulf.time/(3600*24)
        cSulf.advance(dt=dt_fipy,cache=False)
        Cso4 = cSulf.c.value
        Cso4,CHConc,C3AConc=reactEuler(Cso4,CHConc,C3AConc) 
        cSulf.set_value('c',Cso4)
        phi = phi_t(C3AConc,CHConc)
        D = De_crack_width_based(phi,cwidth)
        cSulf.set_value('D',D)
        cSulf.set_value('phi_w',phi)
        # dt_fipy = get_dt(m.cellVolumes,D,phi)
#%% compute dv
    dv = volchange(C3AConc,CHConc,cwidth)
    #%%write paraview output for fipy
    x= m.VTKCellDataSet
    x.cell_data.scalars=cSulf.c.value
    x.cell_data.scalars.name='c_S04'
    x.cell_data.add_array(dv)
    x.cell_data.get_array(1).name = 'VolChange'
    x.cell_data.update() 
    x.cell_data.add_array(C3AConc)
    x.cell_data.get_array(2).name = 'c_C3A'
    x.cell_data.update() 
    x.cell_data.add_array(C3AInitConc-C3AConc) 
    x.cell_data.get_array(3).name = 'Ettringite'
    x.cell_data.update() 
    x.cell_data.add_array(phi)
    x.cell_data.get_array(4).name='porosity'   
    x.cell_data.update() 
    x.cell_data.add_array(CHConc)
    x.cell_data.get_array(5).name='c_CH'   
    x.cell_data.update()      
    write_data(x,os.path.join(FiPyOutPutPath,'FiPyModel.%s.vtu'%int(t_global)))
    #%%transfer dv to linear strains in oofem
    # if np.any(dv!=0):
    dVinterpolator = LinearNDInterpolator(cell_centres_fipy,dv) 
    dvatNodes = dVinterpolator(node_coords_oofem)
    dvatNodes[np.isnan(dvatNodes)]= 0.
    EvatNodes = (1./3.)*dvatNodes
    for i in range(1,nDoFs+1):#Nodes
        increment = EvatNodes[i-1] - TotalLastStrain[i] #FCMV
        f.setDofManValue(i, (increment,))#FCMV
        #f.setDofManValue(i, (EvatNodes[i-1],))#FCMV
        TotalLastStrain[i] = EvatNodes[i-1]#FCMV
    #%%run oofem
    oofem_problem.preInitializeNextStep()
    oofem_problem.giveNextStep()
    currentStep = oofem_problem.giveCurrentStep()
    currentStep.setTargetTime(float(t_global))
    oofem_problem.initializeYourself(currentStep)
    oofem_problem.solveYourselfAt(currentStep)
    oofem_problem.updateYourself( currentStep )
    oofem_problem.terminate( currentStep )        
    #%%transfer damage to fipy
    oofemDamageVar = vtkxml.getInternalVars()['IST_CrackWidth']
    cwidthAtNodes = []
    for i in range(nDoFs):#Nodes
        cwidthAtNodes.append(oofemDamageVar[i][0])
    cwidthAtNodes = np.array(cwidthAtNodes)*1e6
    damageinterpolator = LinearNDInterpolator(node_coords_oofem,cwidthAtNodes) 
    cwidth= damageinterpolator(cell_centres_fipy)
    #%% print something
    print("current time: %s"%t_global)
#%%terminate oofem analysis
oofem_problem.terminateAnalysis()
