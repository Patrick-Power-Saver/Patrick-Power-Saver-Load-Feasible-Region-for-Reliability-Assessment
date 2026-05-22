function [baseMVA,bus,busPmax,busPmin,busQmax,busQmin,busPG,busQG,gen,branch, PBase ,PFBase,busLoadImportant,w_gen]= RTS79_1
%RBTS_Reliability_Test_System   Defines the reliability test system data of the RBTS
%   [baseMVA, bus,busPmax,busPmin,busQmax,busQmin,gen,branch, PBase ,FBase] = RBTS_Reliability_Test_System
%Ref.<<A Reliability Test System For Educational Purposes-Basic Data>>
%IEEE Transactions on Power System,Vol.4,N0.3,August 1989
%PBase:The Probability of All component in normal state
%PFBase:The Sum of the failure rate of all the component

%   Bus Data Format
%       1   bus number (1 to 29997)
%       2   bus type
%               PQ bus          = 1
%               PV bus          = 2
%               reference bus   = 3
%       3   Pd, real power demand (MW)
%       4   Qd, reactive power demand (MVAR)
%       5   Gs, shunt conductance (MW (demanded?) at V = 1.0 p.u.)
%       6   Bs, shunt susceptance (MVAR (injected?) at V = 1.0 p.u.)
%       7   area number, 1-100
%       8   Vm, voltage magnitude (p.u.)
%       9   Va, voltage angle (degrees)
%       10  baseKV, base voltage (kV)
%       11  maxVm, maximum voltage magnitude (p.u.)
%       12  minVm, minimum voltage magnitude (p.u.)


%       13  PGMax, maximum active power wthich can be ejected into the net by the generator installed on this bus
%       14  PGMin, minimum active power wthich can be ejected into the net by the generator installed on this bus
%       15  QGMax, maximum reactive power wthich can be ejected into the net by the generator installed on this bus
%       16  QGMin, minimum reactive power wthich can be ejected into the net by the generator installed on this bus
%       17  PG, actual active power wthich is ejected into the net by the generator installed on this bus
%       18  QG, actusl reactive power wthich is ejected into the net by the generator installed on this bus
%       19  LOLP, Loss of Load Probability
%       20  LOLE, Loss of Load Expection
%       21  LOLF, Loss of Load Frequency
%       22  LOLD, Loss of Load Duration
%       23  EDNS, Expected Demand Not Supplied
%       24  EENS, Expected Energy Not Supplied
%       25  LAM_P, %% Lagrange multiplier on real power mismatch 
%       26  LAM_Q, %% Lagrange multiplier on reactive power mismatch
%       27  MU_VMAX, %% Kuhn-Tucker multiplier on upper voltage limit
%       28  MU_VMIN, %% Kuhn-Tucker multiplier on lower voltage limit
%       29  MU_PMAX, %% Kuhn-Tucker multiplier on upper Pg limit
%       30  MU_PMIN, %% Kuhn-Tucker multiplier on lower Pg limit
%       31  MU_QMAX, %% Kuhn-Tucker multiplier on upper Qg limit
%       32  MU_QMIN, %% Kuhn-Tucker multiplier on lower Qg limit
       
%       Note:the bus data used between numner 13 and number 32 is set by the programe dynamically


%
%   Generator Data Format
%       1   bus number
%       2   Pmax, maximum real power output (MW)
%       3   Pmin, minimum real power output (MW)
%       4   Qmax, maximum reactive power output (MVAR)
%       5   Qmin, minimum reactive power output (MVAR)
%       6   status, 1 - machine in service, 0 - machine out of service
%       7   Lamda, Failure Rate
%       8   MTTF, Repair duration
%       9   PG,original real power output (MW)
%       10  QG,original reactive power output (MVAR)

%       11   PFailure, Probability of Failure
%       Note:the generator data used between numner 9 and number 9 is caculated by the programme
%       
%
%% branch data
%   Branch Data Format
%       1   f, from bus number
%       2   t, to bus number
%       3   r, resistance (p.u.)
%       4   x, reactance (p.u.)
%       5   b, total line charging susceptance (p.u.)
%       6   rate, MVA rating 
%       7   ratio, transformer off nominal turns ratio ( = 0 for lines )
%           (taps at 'from' bus, impedance at 'to' bus, i.e. ratio = Vf / Vt)
%       8   angle, transformer phase shift angle (degrees)
%       9   branch status, 1 - in service, 0 - out of service
%       10  Lamda, Failure Rate
%       11  MTTF, Repair duration
%       12  TCSC setting

%       13  PFailure, Probability of Failure
%       14  PF, active power injected at "from" bus end (MW)		(not in PTI format)
%       15  QF, reactive power injected at "from" bus end (MVAR)	(not in PTI format)
%       16  PT, active power injected at "to" bus end (MW)			(not in PTI format)
%       17  QT, reactive power injected at "to" bus end (MVAR)	(not in PTI format)
%       18  MU_SF, Kuhn-Tucker multiplier on MVA limit at "from" bus (u/MVA)
%       19  MU_ST, Kuhn-Tucker multiplier on MVA limit at "to" bus (u/MVA)
%       20  KT_MAXANGLE_TPST, Kuhn-Tucker multiplier on shifting transformer angle upper limit 
%       21  KT_MINANGLE_TPST, Kuhn-Tucker multiplier on shifting transformer angle lower limit 
%       22  KT_MAXANGLE_TCSC, Kuhn-Tucker multiplier on TSCS Xc upper  limit
%       23  KT_MINANGLE_TCSC, Kuhn-Tucker multiplier on TCSC Xc lower  limit
[PQ, PV, REF, BUS_I, BUS_TYPE, PD, QD, GS, BS, BUS_AREA, VM, ...
	VA, BASE_KV, VMAX, VMIN, PGMAX,PGMIN,QGMAX,QGMIN,PG,QG,LOLP,LOLE,LOLF,LOLD,EDNS,EENS,...
    LAM_P,LAM_Q,MU_VMAX,MU_VMIN,MU_PMAX,MU_PMIN,MU_QMAX,MU_QMIN] = idx_bus;
[GEN_BUS, GEN_PMAX, GEN_PMIN, GEN_QMAX, GEN_QMIN, GEN_STATUS, ...
	GEN_LAMDA,GEN_MTTF,GEN_PG,GEN_QG,GEN_PFAILURE] = idx_gen;
[F_BUS, T_BUS, BR_R, BR_X, BR_B, RATE, TAP, SHIFT_ANGLE, BR_STATUS, BR_LAMDA,...
        BR_MTTF,TCSC_X, BR_PFAILURE, PF, QF, PT, QT, MU_SF, MU_ST, KT_MAXANGLE_TPST,KT_MINANGLE_TPST,KT_MAX_X_TCSC,KT_MIN_X_TCSC] = idx_brch;
[NEWTON,FDFP_XB,FDFP_BX,DCPF] = idx_powerflow;


%% system MVA base  
baseMVA = 100.0000;

%% bus data

%   Bus Data Format
%       1   bus number (1 to 29997)
%       2   bus type
%               PQ bus          = 1
%               PV bus          = 2
%               reference bus   = 3
%       3   Pd, real power demand (MW)
%       4   Qd, reactive power demand (MVAR)
%       5   Gs, shunt conductance (MW (demanded?) at V = 1.0 p.u.)
%       6   Bs, shunt susceptance (MVAR (injected?) at V = 1.0 p.u.)
%       7   area number, 1-100
%       8   Vm, voltage magnitude (p.u.)
%       9   Va, voltage angle (degrees)
%       10  baseKV, base voltage (kV)
%       11  maxVm, maximum voltage magnitude (p.u.)
%       12  minVm, minimum voltage magnitude (p.u.)

bus = [
	1	2	108.000	22.0000	0.00000	0.00000	1	1.0350	0.0000	138.0000	1.1500	0.9000;
	2	2	97.0000	20.0000	0.00000	0.00000	1	1.0350	0.0000	138.0000	1.1500	0.9000;
	3	1	180.000	37.0000	0.00000	0.00000	1	1.0000	0.0000	138.0000	1.1500	0.9000;
	4	1	74.0000	15.0000	0.00000	0.00000	1	1.0000	0.0000	138.0000	1.1500	0.9000;
	5	1	71.0000	14.0000	0.00000	0.00000	1	1.0000	0.0000	138.0000	1.1500	0.9000;
	6	1	136.000	28.0000	0.00000	-100.00	1	1.0000	0.0000	138.0000	1.1500	0.9000;
    7	2	125.000	25.0000	0.00000	0.00000	1	1.0250	0.0000	138.0000	1.1500	0.9000;
    8	1	171.000	35.0000	0.00000	0.00000	1	1.0000	0.0000	138.0000	1.1500	0.9000;
    9	1	175.000	36.0000	0.00000	0.00000	1	1.0000	0.0000	138.0000	1.1500	0.9000;
    10	1	195.000	40.0000	0.00000	0.00000	1	1.0000	0.0000	138.0000	1.1500	0.9000;
    11	1	0.00000	0.00000	0.00000	0.00000	1	1.0000	0.0000	230.0000	1.1500	0.9000;
    12	1	0.00000	0.00000	0.00000	0.00000	1	1.0000	0.0000	230.0000	1.1500	0.9000;
    13	3	265.000	54.0000	0.00000	0.00000	1	1.0200	0.0000	230.0000	1.1500	0.9000;
    14	2	194.000	39.0000	0.00000	0.00000	1	0.9800	0.0000	230.0000	1.1500	0.9000;
    15	2	317.000	64.0000	0.00000	0.00000	1	1.0140	0.0000	230.0000	1.1500	0.9000;
    16	2	100.000	20.0000	0.00000	0.00000	1	1.0170	0.0000	230.0000	1.1500	0.9000;
    17	1	0.00000	0.00000	0.00000	0.00000	1	1.0000	0.0000	230.0000	1.1500	0.9000;
    18	2	333.000	68.0000	0.00000	0.00000	1	1.0500	0.0000	230.0000	1.1500	0.9000;
    19	1	181.000	37.0000	0.00000	0.00000	1	1.0000	0.0000	230.0000	1.1500	0.9000;
    20	1	128.000	26.0000	0.00000	0.00000	1	1.0000	0.0000	230.0000	1.1500	0.9000;
    21	2	0.00000	0.00000	0.00000	0.00000	1	1.0500	0.0000	230.0000	1.1500	0.9000;
    22	2	0.00000	0.00000	0.00000	0.00000	1	1.0500	0.0000	230.0000	1.1500	0.9000;
    23	2	0.00000	0.00000	0.00000	0.00000	1	1.0500	0.0000	230.0000	1.1500	0.9000;
    24	1	0.00000	0.00000	0.00000	0.00000	1	1.0000	0.0000	230.0000	1.1500	0.9000;
];

%   Bus Load Importantnce Data
%       1   bus number (1 to 29997)
%       2   weighting factor for bus LOADI:20%*PD
%       3   weighting factor for bus LOADII:20%*PD
%       4   weighting factor for bus LOADIII:60%*PD
busLoadImportant = [
	1   1.0000  1.0000  1.0000;
	2	1.0000  1.0000  1.0000;
	3	1.0000  1.0000  1.0000;
	4	1.0000  1.0000  1.0000;
	5	1.0000  1.0000  1.0000;
	6	1.0000  1.0000  1.0000;
    7   1.0000  1.0000  1.0000;
	8	1.0000  1.0000  1.0000;
	9	1.0000  1.0000  1.0000;
	10	1.0000  1.0000  1.0000;
	11	0.0000  0.0000  0.0000;
	12	0.0000  0.0000  0.0000;
    13  1.0000  1.0000  1.0000;
	14	1.0000  1.0000  1.0000;
	15	1.0000  1.0000  1.0000;
	16	1.0000  1.0000  1.0000;
	17	0.0000  0.0000  0.0000;
	18	1.0000  1.0000  1.0000;
    19  1.0000  1.0000  1.0000;
	20	1.0000  1.0000  1.0000;
	21	0.0000  0.0000  0.0000;
	22	0.0000  0.0000  0.0000;
	23	0.0000  0.0000  0.0000;
	24	0.0000  0.0000  0.0000;
];

%% generator data
%       1   bus number
%       2   Pmax, maximum real power output (MW)
%       3   Pmin, minimum real power output (MW)
%       4   Qmax, maximum reactive power output (MVAR)
%       5   Qmin, minimum reactive power output (MVAR)
%       6   status, 1 - machine in service, 0 - machine out of service
%       7   Tor, Failure Rate
%       8   MTTF, Repair duration
%       9   PG,original real power output (MW)
%       10  QG,original reactive power output (MVAR)
%       11   PFailure, Probability of Failure

gen = [
     13  197.0000	0.0000	80.0000	0.00000	1	9.22110	50.00000    95.10000    40.7000;
     16  155.0000	0.0000	80.0000 -50.000	1	9.12500	40.00000    155.0000    25.2200;	
    
    18  400.0000	0.0000	200.000	-50.000	1	7.96360	150.0000    400.0000    137.400;	
    21  400.0000	0.0000	200.000	-50.000	1	7.96360	150.0000    400.0000    108.200;
    22  50.00000	0.0000	16.0000	-10.000	1	4.42420	20.00000    50.00000    -4.9600;
    
    23  155.0000	0.0000	80.0000 -50.000	1	9.12500	40.00000    155.0000    31.7900;	
   
    15  12.00000	0.0000	6.00000	0.00000	1	2.97960	60.00000    12.00000    0.00000;	
    1   20.00000	0.0000	10.0000	0.00000	1	19.4467	50.00000    10.00000    0.00000;
    2   76.00000	0.0000	30.0000	-25.000	1	4.46940	40.00000    76.00000    7.00000;
    7   100.0000	0.0000	60.0000	0.00000	1	7.30000	50.00000    80.00000    17.2000;
    1   20.00000	0.0000	10.0000	0.00000	1	19.4467	50.00000    10.00000    0.00000;
    1   76.00000	0.0000	30.0000	-25.000	1	4.46940	40.00000    76.00000    14.1000;	
    1   76.00000	0.0000	30.0000	-25.000	1	4.46940	40.00000    76.00000    14.1000;	
    2   20.00000	0.0000	10.0000	0.00000	1	19.4467	50.00000    10.00000    0.00000;	
    2   20.00000	0.0000	10.0000	0.00000	1	19.4467	50.00000    10.00000    0.00000;	
    2   76.00000	0.0000	30.0000	-25.000	1	4.46940	40.00000    76.00000    7.00000;
    7   100.0000	0.0000	60.0000	0.00000	1	7.30000	50.00000    80.00000    17.2000;	
    13  197.0000	0.0000	80.0000	0.00000	1	9.22110	50.00000    95.10000    40.7000;	
    13  197.0000	0.0000	80.0000	0.00000	1	9.22110	50.00000    95.10000    40.7000;
    15  12.00000	0.0000	6.00000	0.00000	1	2.97960	60.00000    12.00000    0.00000;	
    15  12.00000	0.0000	6.00000	0.00000	1	2.97960	60.00000    12.00000    0.00000;	
    15  12.00000	0.0000	6.00000	0.00000	1	2.97960	60.00000    12.00000    0.00000;	
    15  12.00000	0.0000	6.00000	0.00000	1	2.97960	60.00000    12.00000    0.00000;	
    15  155.0000	0.0000	80.0000 -50.000	1	9.12500	40.00000    155.0000    0.05000;
    22  50.00000	0.0000	16.0000	-10.000	1	4.42420	20.00000    50.00000    -4.9600;
    22  50.00000	0.0000	16.0000	-10.000	1	4.42420	20.00000    50.00000    -4.9600;
    22  50.00000	0.0000	16.0000	-10.000	1	4.42420	20.00000    50.00000    -4.9600;
    22  50.00000	0.0000	16.0000	-10.000	1	4.42420	20.00000    50.00000    -4.9600;
    22  50.00000	0.0000	16.0000	-10.000	1	4.42420	20.00000    50.00000    -4.9600;
    23  155.0000	0.0000	80.0000 -50.000	1	9.12500	40.00000    155.0000    31.7900;	
    23  350.0000	0.0000	150.000	-25.000	1	7.61740	100.0000    350.0000    71.7800;
    7   100.0000	0.0000	60.0000	0.00000	1	7.30000	50.00000    80.00000    17.2000;
%     14  0.000000    0.0000  200.000 -50.000 1   0.00001 1.000000    0.000000    13.6800;   %把无功功率补偿器放在最后，之前它的故障率和修复率都为零的，为了计算方便，均赋值很小的值
];


 


%**********************************GEN备份**************************************************/
% gen = [
%     14  0.000000    0.0000  200.000 -50.000 1   0.00000 0.000000    0.000000    13.6800;
%     18  400.0000	0.0000	200.000	-50.000	1	7.96360	150.0000    400.0000    137.400;	
%     21  400.0000	0.0000	200.000	-50.000	1	7.96360	150.0000    400.0000    108.200;
%     22  50.00000	0.0000	16.0000	-10.000	1	4.42420	20.00000    50.00000    -4.9600;
%     16  155.0000	0.0000	80.0000 -50.000	1	9.12500	40.00000    155.0000    25.2200;	
%     23  155.0000	0.0000	80.0000 -50.000	1	9.12500	40.00000    155.0000    31.7900;	
%     13  197.0000	0.0000	80.0000	0.00000	1	9.22110	50.00000    95.10000    40.7000;
%     15  12.00000	0.0000	6.00000	0.00000	1	2.97960	60.00000    12.00000    0.00000;	
%     1   20.00000	0.0000	10.0000	0.00000	1	19.4467	50.00000    10.00000    0.00000;
%     2   76.00000	0.0000	30.0000	-25.000	1	4.46940	40.00000    76.00000    7.00000;
%     7   100.0000	0.0000	60.0000	0.00000	1	7.30000	50.00000    80.00000    17.2000;
%     1   20.00000	0.0000	10.0000	0.00000	1	19.4467	50.00000    10.00000    0.00000;
%     1   76.00000	0.0000	30.0000	-25.000	1	4.46940	40.00000    76.00000    14.1000;	
%     1   76.00000	0.0000	30.0000	-25.000	1	4.46940	40.00000    76.00000    14.1000;	
%     2   20.00000	0.0000	10.0000	0.00000	1	19.4467	50.00000    10.00000    0.00000;	
%     2   20.00000	0.0000	10.0000	0.00000	1	19.4467	50.00000    10.00000    0.00000;	
%     2   76.00000	0.0000	30.0000	-25.000	1	4.46940	40.00000    76.00000    7.00000;
%     7   100.0000	0.0000	60.0000	0.00000	1	7.30000	50.00000    80.00000    17.2000;	
%     13  197.0000	0.0000	80.0000	0.00000	1	9.22110	50.00000    95.10000    40.7000;	
%     13  197.0000	0.0000	80.0000	0.00000	1	9.22110	50.00000    95.10000    40.7000;
%     15  12.00000	0.0000	6.00000	0.00000	1	2.97960	60.00000    12.00000    0.00000;	
%     15  12.00000	0.0000	6.00000	0.00000	1	2.97960	60.00000    12.00000    0.00000;	
%     15  12.00000	0.0000	6.00000	0.00000	1	2.97960	60.00000    12.00000    0.00000;	
%     15  12.00000	0.0000	6.00000	0.00000	1	2.97960	60.00000    12.00000    0.00000;	
%     15  155.0000	0.0000	80.0000 -50.000	1	9.12500	40.00000    155.0000    0.05000;
%     22  50.00000	0.0000	16.0000	-10.000	1	4.42420	20.00000    50.00000    -4.9600;
%     22  50.00000	0.0000	16.0000	-10.000	1	4.42420	20.00000    50.00000    -4.9600;
%     22  50.00000	0.0000	16.0000	-10.000	1	4.42420	20.00000    50.00000    -4.9600;
%     22  50.00000	0.0000	16.0000	-10.000	1	4.42420	20.00000    50.00000    -4.9600;
%     22  50.00000	0.0000	16.0000	-10.000	1	4.42420	20.00000    50.00000    -4.9600;
%     23  155.0000	0.0000	80.0000 -50.000	1	9.12500	40.00000    155.0000    31.7900;	
%     23  350.0000	0.0000	150.000	-25.000	1	7.61740	100.0000    350.0000    71.7800;
%     7   100.0000	0.0000	60.0000	0.00000	1	7.30000	50.00000    80.00000    17.2000;	
% ];


%% branch data
%       1   f, from bus number
%       2   t, to bus number
%       3   r, resistance (p.u.)
%       4   x, reactance (p.u.)
%       5   b, total line charging susceptance (p.u.)
%       6   rate, MVA rating 
%       7   ratio, transformer off nominal turns ratio ( = 0 for lines )
%           (taps at 'from' bus, impedance at 'to' bus, i.e. ratio = Vf / Vt)
%       8   angle, transformer phase shift angle (degrees)
%       9   branch status, 1 - in service, 0 - out of service
%       10  Lamda, Failure Rate
%       11  MTTF, Repair duration
%       12  TCSC setting

%       13  PFailure, Probability of Failure
%       14  PF, active power injected at "from" bus end (MW)		(not in PTI format)
%       15  QF, reactive power injected at "from" bus end (MVAR)	(not in PTI format)
%       16  PT, active power injected at "to" bus end (MW)			(not in PTI format)
%       17  QT, reactive power injected at "to" bus end (MVAR)	(not in PTI format)
%       18  MU_SF, Kuhn-Tucker multiplier on MVA limit at "from" bus (u/MVA)
%       19  MU_ST, Kuhn-Tucker multiplier on MVA limit at "to" bus (u/MVA)
%       20  KT_MAXANGLE_TPST, Kuhn-Tucker multiplier on shifting transformer angle upper limit 
%       21  KT_MINANGLE_TPST, Kuhn-Tucker multiplier on shifting transformer angle lower limit 
%       22  KT_MAXANGLE_TCSC, Kuhn-Tucker multiplier on TSCS Xc upper  limit
%       23  KT_MINANGLE_TCSC, Kuhn-Tucker multiplier on TCSC Xc lower  limit

branch = [
    1	3	0.0546	0.2112	0.0572	220.0000	0.000000	0.000000   	1	0.5100	10  0.000000;
    2	6	0.0497	0.1920	0.0520	220.0000	0.000000	0.000000	1	0.4800	10  0.000000;
    15	21	0.0063	0.0490	0.1030	525.0000	0.000000	0.000000	1	0.4100	11  0.000000; 
    
    15	24	0.0067	0.0519	0.1091	525.0000	0.000000	0.000000	1	0.4100	11  0.000000;
    

    18	21	0.0033	0.0259	0.0545	625.0000	0.000000	0.000000	1	0.3500	11  0.000000;
    18	21	0.0033	0.0259	0.0545	625.0000	0.000000	0.000000	1	0.3500	11  0.000000;
    17	18	0.0018	0.0144	0.0303	525.0000	0.000000	0.000000	1	0.3200	11  0.000000;
    21	22	0.0087	0.0678	0.1424	525.0000	0.000000	0.000000	1	0.4500	11  0.000000;
    17	22	0.0135  0.1053	0.2212	625.0000	0.000000	0.000000	1	0.5400	11  0.000000;
    16	17	0.0033	0.0259	0.0545	525.0000	0.000000	0.000000	1	0.3500	11  0.000000;
    16	19	0.0030	0.0231	0.0485	525.0000	0.000000	0.000000	1	0.3400	11  0.000000;
    19	20	0.0051	0.0396	0.0833	525.0000	0.000000	0.000000	1	0.3800	11  0.000000;
    19	20	0.0051	0.0396	0.0833	525.0000	0.000000	0.000000	1   0.3800	11  0.000000;
    20	23	0.0028	0.0216	0.0455	525.0000	0.000000	0.000000	1	0.3400	11  0.000000;
    20	23	0.0028	0.0216	0.0455	525.0000	0.000000	0.000000	1	0.3400	11  0.000000;
    15	16	0.0022	0.0173	0.0364	625.0000	0.000000	0.000000	1	0.3300	11  0.000000;
    15	21	0.0063	0.0490	0.1030	525.0000	0.000000	0.000000	1	0.4100	11  0.000000;
       
    14	16  0.0050	0.0389  0.0818	625.0000	0.000000	0.000000	1	0.3800	11  0.000000;    
    12	23	0.0124	0.0966	0.2030	525.0000	0.000000	0.000000	1	0.5200	11  0.000000;  
    12	13	0.0061	0.0476	0.0999	525.0000	0.000000	0.000000	1	0.4000	11  0.000000;
    11	13	0.0061	0.0476	0.0999	625.0000	0.000000	0.000000	1	0.4000	11  0.000000;
    11	14	0.0054	0.0418	0.0879	625.0000	0.000000	0.000000	1	0.3900	11  0.000000;
    
    
	2	4	0.0328	0.1267	0.0343	220.0000	0.000000	0.000000	1	0.3900	10  0.000000;    
    1	5	0.0218	0.0845	0.0229	220.0000	0.000000	0.000000	1	0.3300	10  0.000000;
    1	2	0.0026	0.0139	0.4611	200.0000	0.000000	0.000000	1	0.2400	16  0.000000;
   	5	10	0.0228	0.0883	0.0239	220.0000	0.000000	0.000000	1	0.3400	10  0.000000;
    8	10	0.0427	0.1651	0.0477	220.0000	0.000000	0.000000	1	0.4400	10  0.000000;    
    7	8	0.0159	0.0614	0.0166	220.0000	0.000000	0.000000	1	0.3000	10  0.000000; 
    6	10	0.0139	0.0605	2.4590	200.0000	0.000000	0.000000	1	0.3300	35  0.000000;
	
    13	23	0.0111	0.0865	0.1818	525.0000	0.000000	0.000000	1	0.4900	11  0.000000;
    3	9	0.0308	0.1190	0.0322	220.0000	0.000000	0.000000	1	0.3800	10  0.000000;
    4	9	0.0268	0.1037	0.0281	220.0000	0.000000	0.000000	1	0.3600	10  0.000000;
    8	9	0.0427  0.1651	0.0477	220.0000	0.000000	0.000000	1	0.4400	10  0.000000;
	3	24	0.0023	0.0839	0.0000	600.0000	1.020000	0.000000	1	0.0200	768 0.000000;
    10	12	0.0023	0.0839	0.0000	600.0000	0.000000	0.000000	1	0.0200	768 0.000000;
    9	11	0.0023	0.0839	0.0000	600.0000	0.950000	0.000000	1	0.0200	768 0.000000;
    10	11	0.0023	0.0839	0.0000	600.0000	0.000000	0.000000	1	0.0200	768 0.000000;
    9	12	0.0023	0.0839	0.0000	600.0000	0.000000	0.000000	1	0.0200	768 0.000000;
];




rate = 1.00;
bus(:,3) = rate.*bus(:,3);
bus(:,4) = rate.*bus(:,4);
gen(:,2) = rate.*gen(:,2);
gen(:,3) = rate.*gen(:,3);
gen(:,9) = rate.*gen(:,9);
gen(:,4) = rate.*gen(:,4);
gen(:,5) = rate.*gen(:,5);
gen(:,10) = rate.*gen(:,10);


bus(:,13:32) = 0; 
busPmax = zeros(size(bus,1),1);
busPmin = zeros(size(bus,1),1);
busPG = zeros(size(bus,1),1);
busQmax = zeros(size(bus,1),1);
busQmin = zeros(size(bus,1),1);
busQG = zeros(size(bus,1),1);
ref = find(bus(:,2) == 3);
pv = find(bus(:,2) == 2);
pq = find(bus(:,2) == 1);


gen(:,11) = 1-8760./(gen(:,7).*gen(:,8)+8760);

for i=1:size(bus,1)
    genindex = find(gen(:,1) == i);
    if(isempty(genindex) ~= 1)
        busPmax(i) = sum(gen(genindex,2));
        busPmin(i) = sum(gen(genindex,3));
        busPG(i)   = sum(gen(genindex,9));
        busQmax(i) = sum(gen(genindex,4));
        busQmin(i) = sum(gen(genindex,5));%%because the Qmin of the generator can be negative
        busQG(i)   = sum(gen(genindex,10));
    else
        busPmax(i) = 0;
        busPmin(i) = 0;
        busQmax(i) = 0;
        busQmin(i) = 0;
        busPG(i) = 0;
        busQG(i) = 0;
    end       
end   

bus(:,13) = busPmax;
bus(:,14) = busPmin;
bus(:,15) = busQmax;
bus(:,16) = busQmin;
bus(:,17) = busPG;
bus(:,18) = busQG;


branch(:,13) = 1-8760./(branch(:,10).*branch(:,11)+8760);
branch(:,14:23) = 0.0;
PBase = prod(1-gen(:,11));
PBase = PBase * prod(1-branch(:,13));
PFBase = sum(gen(:,7));
PFBase = PFBase + sum(branch(:,10));
bus(:,3)=bus(:,3)*0.9;
iw=[1,6,7,8,10,11,12,13,21,25,26,27,28,30];
gen(iw(1:7),2)=gen(iw(1:7),2)*0.7;  
gen(iw(8:14),2)=gen(iw(8:14),2)*0.7;
% bus(:,3) = bus(:,3)*0.6;
% iw=[1,6,7,8,10,11,12,13,21,25,26,27,28,30];
% gen(iw,GEN_PFAILURE)=0;  
% gen(iw(1:7),2)=gen(iw(1:7),2)*0.6;  
% gen(iw(8:14),2)=gen(iw(8:14),2)*0.8;
% branch(1:19,6)=branch(1:19,6)*0.5;
% branch(20:38,6)=branch(20:38,6)*0.6;

% wind_gen = gen([1,6,7,15,17,18],:);
% gen([1,6,7,15,17,18],:)=[];
%%Calulate the initial power flow of the test system
%%Sbus = makeSbus(baseMVA, bus);
%%V0	= bus(:, VM) .* exp(sqrt(-1) * pi/180 * bus(:, VA));
%%[Ybus, Yf, Yt] = makeYbus(baseMVA, bus, branch);
%%[V, success, iterations] = newtonpf(Ybus, Sbus, V0, ref, pv, pq);
%%if success == 0
%%    error('fail to calaculate the initial power flow of the power system');
%%end        
%%[bus, gen, branch] = pfsoln(baseMVA, bus, gen, branch, Ybus, Yf, Yt, V, ref, pv, pq,NEWTON);
%%InitialLinePowerFlow = branch(:,[PF QF PT QT]);

%%[Bp, Bpp] = makeB(baseMVA, bus, branch, FDFP_BX);
%%[V, success, iterations] = fdpf(Ybus, Sbus, V0, Bp, Bpp, ref, pv, pq);

%%B = makeDC_B(baseMVA, bus, branch);
%%V = dcpowerflow( Sbus, V0, B, ref, pv, pq);






%AllreadyProcessBus = zeros(size(bus,1),1);
%AllreadyProcessBranch = 1-branch(:,BR_STATUS); 

%while isempty(find(AllreadyProcessBus == 0)) == 0
%    [nodehao,branchhao] = AnalylizedSepartedNet(bus,branch,AllreadyProcessBus,AllreadyProcessBranch);
%    fprintf(1,'\n');
%    fprintf(1,'NODE:%d\n',bus(nodehao,BUS_I)');
%    if(isempty(branchhao) == 0)
%        fprintf(1,'STARTNODE ENDNODE\n');
%        fprintf(1,'%d          %d\n',[branch(branchhao,F_BUS) branch(branchhao,T_BUS)]');
%    else
%        fprintf(1,'No Line');
%    end        
%    AllreadyProcessBus(nodehao) = 1; 
%end
%return;



%bus = UpdateBusPQmaxPQmin(bus,gen,busPmax,busPmin,busQmax,busQmin);




%genfaultrank = 2;
%linefaultrank = 3;
%Total = ComputeTotalEnumerationEventSum(gen, branch,genfaultrank,linefaultrank);



